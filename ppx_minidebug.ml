open Ppxlib
module A = Ast_builder.Default

(* module H = Ast_helper *)
let track_branches = ref false
let output_type_info = ref false
let interrupts = ref false

let rec last_ident = function
  | Lident id -> id
  | Ldot (_, id) -> id
  | Lapply (_, lid) -> last_ident lid

let rec typ2str typ =
  match typ.ptyp_desc with
  | Ptyp_any -> "_"
  | Ptyp_var x -> "'" ^ x
  | Ptyp_arrow (_, a, b) -> typ2str a ^ " -> " ^ typ2str b
  | Ptyp_tuple typs -> "(" ^ String.concat " * " (List.map typ2str typs) ^ ")"
  | Ptyp_constr (lid, []) -> last_ident lid.txt
  | Ptyp_constr (lid, typs) ->
      last_ident lid.txt ^ "(" ^ String.concat " * " (List.map typ2str typs) ^ ")"
  | Ptyp_object (_, _) -> "<object>"
  | Ptyp_class (_, _) -> "<class>"
  | Ptyp_alias (typ, x) -> typ2str typ ^ " as '" ^ x
  | Ptyp_variant (_, _, _) -> "<poly-variant>"
  | Ptyp_poly (vs, typ) ->
      String.concat " " (List.map (fun v -> "'" ^ v.txt) vs) ^ "." ^ typ2str typ
  | Ptyp_package _ -> "<module val>"
  | Ptyp_extension _ -> "<extension>"

let rec pat2descr ~default pat =
  let loc = pat.ppat_loc in
  match pat.ppat_desc with
  | Ppat_constraint (pat', _) -> pat2descr ~default pat'
  | Ppat_alias (_, ident) | Ppat_var ident -> ident
  | Ppat_tuple tups ->
      let dscrs = List.map (fun p -> (pat2descr ~default:"_" p).txt) tups in
      { txt = "(" ^ String.concat ", " dscrs ^ ")"; loc }
  | Ppat_record (fields, _) ->
      let dscrs =
        List.map
          (fun (id, p) ->
            let label = last_ident id.txt in
            let pat = (pat2descr ~default:"_" p).txt in
            if String.equal label pat then pat else label ^ "=" ^ pat)
          fields
      in
      { txt = "{" ^ String.concat "; " dscrs ^ "}"; loc }
  | Ppat_construct (lid, None) -> { txt = last_ident lid.txt; loc }
  | Ppat_construct (lid, Some (_abs_tys, pat)) ->
      let dscr = pat2descr ~default pat in
      { txt = last_ident lid.txt ^ " " ^ dscr.txt; loc }
  | Ppat_variant (lid, None) -> { txt = lid; loc }
  | Ppat_variant (lid, Some pat) ->
      let dscr = pat2descr ~default pat in
      { txt = lid ^ " " ^ dscr.txt; loc }
  | Ppat_array tups ->
      let dscrs = List.map (fun p -> (pat2descr ~default:"_" p).txt) tups in
      { txt = "[|" ^ String.concat ", " dscrs ^ "|]"; loc }
  | Ppat_or (pat1, pat2) ->
      let dscr1 = pat2descr ~default pat1 in
      let dscr2 = pat2descr ~default pat2 in
      { txt = dscr1.txt ^ "|" ^ dscr2.txt; loc }
  | Ppat_exception pat ->
      let dscr = pat2descr ~default pat in
      { txt = "exception " ^ dscr.txt; loc }
  | Ppat_lazy pat ->
      let dscr = pat2descr ~default pat in
      { txt = "lazy " ^ dscr.txt; loc }
  | Ppat_open (_, pat) -> pat2descr ~default pat
  | Ppat_type _ | Ppat_extension _ | Ppat_unpack _ | Ppat_any | Ppat_constant _
  | Ppat_interval _ ->
      { txt = default; loc }

let rec pat2expr pat =
  let loc = pat.ppat_loc in
  match pat with
  | [%pat? ()] -> [%expr ()]
  | { ppat_desc = Ppat_constraint (pat', typ); _ } ->
      A.pexp_constraint ~loc (pat2expr pat') typ
  | { ppat_desc = Ppat_alias (_, ident) | Ppat_var ident; _ } ->
      A.pexp_ident ~loc { ident with txt = Lident ident.txt }
  | _ ->
      A.pexp_extension ~loc
      @@ Location.error_extensionf ~loc
           "ppx_minidebug requires a pattern identifier here: try using an `as` alias."

let open_log_preamble ?(brief = false) ?(message = "") ~loc () =
  if brief then
    [%expr
      Debug_runtime.open_log_preamble_brief
        ~fname:[%e A.estring ~loc loc.loc_start.pos_fname]
        ~pos_lnum:[%e A.eint ~loc loc.loc_start.pos_lnum]
        ~pos_colnum:[%e A.eint ~loc (loc.loc_start.pos_cnum - loc.loc_start.pos_bol)]
        ~message:[%e A.estring ~loc message] ~entry_id:__entry_id]
  else
    [%expr
      Debug_runtime.open_log_preamble_full
        ~fname:[%e A.estring ~loc loc.loc_start.pos_fname]
        ~start_lnum:[%e A.eint ~loc loc.loc_start.pos_lnum]
        ~start_colnum:[%e A.eint ~loc (loc.loc_start.pos_cnum - loc.loc_start.pos_bol)]
        ~end_lnum:[%e A.eint ~loc loc.loc_end.pos_lnum]
        ~end_colnum:[%e A.eint ~loc (loc.loc_end.pos_cnum - loc.loc_end.pos_bol)]
        ~message:[%e A.estring ~loc message] ~entry_id:__entry_id]

exception Not_transforming

let to_descr ~descr_loc typ =
  let descr =
    if !output_type_info then descr_loc.txt ^ " : " ^ typ2str typ else descr_loc.txt
  in
  A.estring ~loc:descr_loc.loc descr

(* *** The sexplib-based variant. *** *)
let log_value_sexp ~loc ~typ ~descr_loc ~is_result exp =
  (* [%sexp_of: typ] does not work with `Ptyp_poly`. Misleading error "Let with no bindings". *)
  let typ =
    match typ with { ptyp_desc = Ptyp_poly (_, ctyp); _ } -> ctyp | ctyp -> ctyp
  in
  [%expr
    Debug_runtime.log_value_sexp ~descr:[%e to_descr ~descr_loc typ] ~entry_id:__entry_id
      ~is_result:[%e A.ebool ~loc is_result]
      ([%sexp_of: [%t typ]] [%e exp])]

(* *** The deriving.show pp-based variant. *** *)
let rec splice_lident ~id_prefix ident =
  let splice id =
    if String.equal id_prefix "pp_" && String.equal id "t" then "pp" else id_prefix ^ id
  in
  match ident with
  | Lident id -> Lident (splice id)
  | Ldot (path, id) -> Ldot (path, splice id)
  | Lapply (f, a) -> Lapply (splice_lident ~id_prefix f, a)

let log_value_pp ~loc ~typ ~descr_loc ~is_result exp =
  let t_lident_loc =
    match typ with
    | {
     ptyp_desc =
       ( Ptyp_constr (t_lident_loc, [])
       | Ptyp_poly (_, { ptyp_desc = Ptyp_constr (t_lident_loc, []); _ }) );
     _;
    } ->
        t_lident_loc
    | _ -> raise Not_transforming
  in
  let converter =
    A.pexp_ident ~loc
      { t_lident_loc with txt = splice_lident ~id_prefix:"pp_" t_lident_loc.txt }
  in
  [%expr
    Debug_runtime.log_value_pp ~descr:[%e to_descr ~descr_loc typ] ~entry_id:__entry_id
      ~pp:[%e converter] ~is_result:[%e A.ebool ~loc is_result] [%e exp]]

(* *** The deriving.show string-based variant. *** *)
let log_value_show ~loc ~typ ~descr_loc ~is_result exp =
  (* Defensive (TODO: check it doesn't work with Ptyp_poly). *)
  let typ =
    match typ with { ptyp_desc = Ptyp_poly (_, ctyp); _ } -> ctyp | ctyp -> ctyp
  in
  [%expr
    Debug_runtime.log_value_show ~descr:[%e to_descr ~descr_loc typ] ~entry_id:__entry_id
      ~is_result:[%e A.ebool ~loc is_result]
      ([%show: [%t typ]] [%e exp])]

let log_value = ref log_value_sexp

let log_string ~loc ~descr_loc s =
  [%expr
    Debug_runtime.log_value_show
      ~descr:[%e A.estring ~loc:descr_loc.loc descr_loc.txt]
      ~entry_id:__entry_id ~is_result:false [%e A.estring ~loc s]]

type fun_arg =
  | Pexp_fun_arg of
      arg_label * expression option * pattern * location * location_stack * attributes
  | Pexp_newtype_arg of label loc * location * location_stack * attributes

let rec collect_fun accu = function
  | {
      pexp_desc = Pexp_fun (arg_label, arg, opt_val, body);
      pexp_loc;
      pexp_loc_stack;
      pexp_attributes;
    } ->
      collect_fun
        (Pexp_fun_arg (arg_label, arg, opt_val, pexp_loc, pexp_loc_stack, pexp_attributes)
        :: accu)
        body
  | {
      pexp_desc = Pexp_newtype (type_label, body);
      pexp_loc;
      pexp_loc_stack;
      pexp_attributes;
    } ->
      collect_fun
        (Pexp_newtype_arg (type_label, pexp_loc, pexp_loc_stack, pexp_attributes) :: accu)
        body
  | [%expr ([%e? body] : [%t? typ])] -> (List.rev accu, body, Some typ)
  | body -> (List.rev accu, body, None)

let rec expand_fun body = function
  | [] -> body
  | Pexp_fun_arg (arg_label, arg, opt_val, pexp_loc, pexp_loc_stack, pexp_attributes)
    :: args ->
      {
        pexp_desc = Pexp_fun (arg_label, arg, opt_val, expand_fun body args);
        pexp_loc;
        pexp_loc_stack;
        pexp_attributes;
      }
  | Pexp_newtype_arg (type_label, pexp_loc, pexp_loc_stack, pexp_attributes) :: args ->
      {
        pexp_desc = Pexp_newtype (type_label, expand_fun body args);
        pexp_loc;
        pexp_loc_stack;
        pexp_attributes;
      }

let rec pick ~typ ?alt_typ () =
  let rec deref typ =
    match typ.ptyp_desc with
    | Ptyp_alias (typ, _) | Ptyp_poly (_, typ) -> deref typ
    | _ -> typ
  in
  let typ = deref typ
  and alt_typ = match alt_typ with None -> None | Some t -> Some (deref t) in
  let alt_or_typ = match alt_typ with None -> typ | Some t -> t in
  let loc = typ.ptyp_loc in
  match typ.ptyp_desc with
  | Ptyp_any -> alt_or_typ
  | Ptyp_var _ -> alt_or_typ
  | Ptyp_arrow (_, arg, ret) -> (
      match alt_typ with
      | Some { ptyp_desc = Ptyp_arrow (_, arg2, ret2); _ } ->
          let arg = pick ~typ:arg ~alt_typ:arg2 () in
          let ret = pick ~typ:ret ~alt_typ:ret2 () in
          A.ptyp_arrow ~loc Nolabel arg ret
      | _ -> typ)
  | Ptyp_tuple args -> (
      match alt_typ with
      | Some { ptyp_desc = Ptyp_tuple args2; _ } when List.length args = List.length args2
        ->
          let args = List.map2 (fun typ alt_typ -> pick ~typ ~alt_typ ()) args args2 in
          A.ptyp_tuple ~loc args
      | _ -> typ)
  | Ptyp_constr (c, args) -> (
      match alt_typ with
      | Some { ptyp_desc = Ptyp_constr (c2, args2); _ }
        when String.equal (last_ident c.txt) (last_ident c2.txt)
             && List.length args = List.length args2 ->
          let args = List.map2 (fun typ alt_typ -> pick ~typ ~alt_typ ()) args args2 in
          A.ptyp_constr ~loc c args
      | _ -> typ)
  | _ -> typ

let bound_patterns ~alt_typ pat =
  let rec loop ?alt_typ pat =
    let loc = pat.ppat_loc in
    let typ, pat =
      match pat with
      | [%pat? ([%p? pat] : [%t? typ])] -> (Some (pick ~typ ?alt_typ ()), pat)
      | _ -> (alt_typ, pat)
    in
    match (typ, pat) with
    | ( Some { ptyp_desc = Ptyp_any | Ptyp_var _ | Ptyp_package _ | Ptyp_extension _; _ },
        { ppat_desc = Ppat_var _ | Ppat_alias (_, _); _ } ) ->
        (* Skip abstract types and types unlikely to have derivable printers. *)
        (A.ppat_any ~loc, [])
    | Some typ, ({ ppat_desc = Ppat_var descr_loc | Ppat_alias (_, descr_loc); _ } as pat)
      ->
        (A.ppat_var ~loc descr_loc, [ (descr_loc, pat, typ) ])
    | ( Some { ptyp_desc = Ptyp_tuple typs; _ },
        { ppat_desc = Ppat_tuple pats; ppat_loc; _ } ) ->
        let pats, bindings =
          List.split @@ List.map2 (fun pat typ -> loop ~alt_typ:typ pat) pats typs
        in
        (A.ppat_tuple ~loc:ppat_loc pats, List.concat bindings)
    | _, { ppat_desc = Ppat_tuple pats; ppat_loc; _ } ->
        let pats, bindings = List.split @@ List.map (fun pat -> loop pat) pats in
        (A.ppat_tuple ~loc:ppat_loc pats, List.concat bindings)
    | _, { ppat_desc = Ppat_record (fields, closed); ppat_loc; _ } ->
        let pats, bindings = List.split @@ List.map (fun (_, pat) -> loop pat) fields in
        let fields = List.map2 (fun (id, _) pat -> (id, pat)) fields pats in
        (A.ppat_record ~loc:ppat_loc fields closed, List.concat bindings)
    | Some [%type: [%t? alt_typ] option], [%pat? Some [%p? pat]] ->
        let pat, bindings = loop ~alt_typ pat in
        ([%pat? Some [%p pat]], bindings)
    | Some [%type: [%t? alt_typ] list], [%pat? [%p? hd] :: [%p? tl]] ->
        let hd, bindings1 = loop ~alt_typ hd in
        let tl, bindings2 = loop ?alt_typ:typ tl in
        ([%pat? [%p hd] :: [%p tl]], bindings1 @ bindings2)
    | _, { ppat_desc = Ppat_construct (_lid, None); _ } -> (pat, [])
    | _, { ppat_desc = Ppat_construct (lid, Some (_abs_tys, pat)); _ } ->
        let pat, bindings = loop pat in
        (A.ppat_construct ~loc lid (Some pat), bindings)
    | _, { ppat_desc = Ppat_variant (_lid, None); _ } -> (pat, [])
    | _, { ppat_desc = Ppat_variant (lid, Some pat); _ } ->
        let pat, bindings = loop pat in
        (A.ppat_variant ~loc lid (Some pat), bindings)
    | Some [%type: [%t? alt_typ] array], { ppat_desc = Ppat_array pats; ppat_loc; _ } ->
        let pats, bindings = List.split @@ List.map (fun pat -> loop ~alt_typ pat) pats in
        (A.ppat_array ~loc:ppat_loc pats, List.concat bindings)
    | _, { ppat_desc = Ppat_array pats; ppat_loc; _ } ->
        let pats, bindings = List.split @@ List.map (fun pat -> loop pat) pats in
        (A.ppat_array ~loc:ppat_loc pats, List.concat bindings)
    | _, { ppat_desc = Ppat_or (pat1, pat2); _ } ->
        let pat1, binds1 = loop ?alt_typ:typ pat1 in
        let binds1 =
          List.map (fun (({ txt = descr; _ }, _, _) as b) -> (descr, b)) binds1
        in
        let pat2, binds2 = loop ?alt_typ:typ pat2 in
        let binds2 =
          List.map (fun (({ txt = descr; _ }, _, _) as b) -> (descr, b)) binds2
        in
        let bindings =
          List.sort_uniq (fun (k1, _) (k2, _) -> String.compare k1 k2) @@ binds1 @ binds2
        in
        (A.ppat_or ~loc pat1 pat2, List.map snd bindings)
    | _, { ppat_desc = Ppat_exception pat; _ } ->
        let pat, bindings = loop pat in
        (A.ppat_exception ~loc pat, bindings)
    | Some [%type: [%t? alt_typ] Lazy.t], { ppat_desc = Ppat_lazy pat; _ } ->
        let pat, bindings = loop ~alt_typ pat in
        (A.ppat_lazy ~loc pat, bindings)
    | _, { ppat_desc = Ppat_lazy pat; _ } ->
        let pat, bindings = loop pat in
        (A.ppat_lazy ~loc pat, bindings)
    | _, { ppat_desc = Ppat_open (m, pat); _ } ->
        let pat, bindings = loop ?alt_typ:typ pat in
        (A.ppat_open ~loc m pat, bindings)
    | _, { ppat_desc = Ppat_constraint (_, _); _ } -> assert false
    | ( _,
        {
          ppat_desc =
            ( Ppat_var _
            | Ppat_alias (_, _)
            | Ppat_type _ | Ppat_extension _ | Ppat_unpack _ | Ppat_any | Ppat_constant _
            | Ppat_interval _ );
          _;
        } ) ->
        (* The pattern is only used to bind values that will be logged. *)
        (A.ppat_any ~loc, [])
  in
  let bind_pat, bound = loop ?alt_typ pat in
  let loc = pat.ppat_loc in
  (A.ppat_alias ~loc bind_pat { txt = "__res"; loc }, bound)

let entry_with_interrupts ~loc ~descr_loc ?header ~preamble ~entry ~result ~log_result ()
    =
  let header = match header with Some h -> h | None -> [%expr ()] in
  if !interrupts then
    [%expr
      let __entry_id = Debug_runtime.get_entry_id () in
      [%e header];
      if Debug_runtime.exceeds_max_children () then (
        [%e log_string ~loc ~descr_loc "<max_num_children exceeded>"];
        failwith "ppx_minidebug: max_num_children exceeded")
      else (
        [%e preamble];
        if Debug_runtime.exceeds_max_nesting () then (
          [%e log_string ~loc ~descr_loc "<max_nesting_depth exceeded>"];
          Debug_runtime.close_log ();
          failwith "ppx_minidebug: max_nesting_depth exceeded")
        else
          match [%e entry] with
          | [%p result] ->
              [%e log_result];
              Debug_runtime.close_log ();
              [%e pat2expr result]
          | exception e ->
              Debug_runtime.close_log ();
              raise e)]
  else
    [%expr
      let __entry_id = Debug_runtime.get_entry_id () in
      [%e header];
      [%e preamble];
      match [%e entry] with
      | [%p result] ->
          [%e log_result];
          Debug_runtime.close_log ();
          [%e pat2expr result]
      | exception e ->
          Debug_runtime.close_log ();
          raise e]

let debug_body callback ~loc ~message ~descr_loc ~arg_logs typ body =
  let message =
    match typ with
    | Some t when !output_type_info -> message ^ " : " ^ typ2str t
    | _ -> message
  in
  let preamble = open_log_preamble ~message ~loc () in
  let preamble =
    List.fold_left
      (fun e1 e2 ->
        [%expr
          [%e e1];
          [%e e2]])
      preamble arg_logs
  in
  let result =
    let loc = descr_loc.loc in
    A.ppat_var ~loc { loc; txt = "__res" }
  in
  let log_result =
    match typ with
    | None -> [%expr ()]
    | Some typ -> !log_value ~loc ~typ ~descr_loc ~is_result:true (pat2expr result)
  in
  entry_with_interrupts ~loc ~descr_loc ~preamble ~entry:(callback body) ~result
    ~log_result ()

let rec collect_fun_typs arg_typs typ =
  match typ.ptyp_desc with
  | Ptyp_alias (typ, _) | Ptyp_poly (_, typ) -> collect_fun_typs arg_typs typ
  | Ptyp_arrow (_, arg_typ, typ) -> collect_fun_typs (arg_typ :: arg_typs) typ
  | _ -> (List.rev arg_typs, typ)

let debug_fun callback ?typ ?ret_descr ?ret_typ exp =
  let args, body, ret_typ2 = collect_fun [] exp in
  let arg_typs, ret_typ3 =
    match typ with
    | None -> ([], None)
    | Some typ ->
        let arg_typs, ret_typ = collect_fun_typs [] typ in
        (arg_typs, Some ret_typ)
  in
  let loc = exp.pexp_loc in
  let typ =
    match (ret_typ, ret_typ2, ret_typ3) with
    | _, Some typ, _ ->
        Some (pick ~typ:(pick ~typ ?alt_typ:ret_typ ()) ?alt_typ:ret_typ3 ())
    | _, None, None -> ret_typ
    | None, None, Some t -> Some t
    | Some typ, None, _ -> Some (pick ~typ ?alt_typ:ret_typ3 ())
  in
  if (not !track_branches) && Option.is_none typ then raise Not_transforming;
  let ret_descr =
    match ret_descr with
    | None when !track_branches -> { txt = "__fun"; loc }
    | None -> raise Not_transforming
    | Some descr -> descr
  in
  let rec arg_log = function
    | arg_typs, Pexp_newtype_arg _ :: args -> arg_log (arg_typs, args)
    | ( alt_typ :: arg_typs,
        Pexp_fun_arg
          (_arg_label, _opt_val, pat, pexp_loc, _pexp_loc_stack, _pexp_attributes)
        :: args ) ->
        let _, bound = bound_patterns ~alt_typ:(Some alt_typ) pat in
        List.map
          (fun (descr_loc, pat, typ) ->
            !log_value ~loc:pexp_loc ~typ ~descr_loc ~is_result:false (pat2expr pat))
          bound
        @ arg_log (arg_typs, args)
    | ( [],
        Pexp_fun_arg
          (_arg_label, _opt_val, pat, pexp_loc, _pexp_loc_stack, _pexp_attributes)
        :: args ) ->
        let _, bound = bound_patterns ~alt_typ:None pat in
        List.map
          (fun (descr_loc, pat, typ) ->
            !log_value ~loc:pexp_loc ~typ ~descr_loc ~is_result:false (pat2expr pat))
          bound
        @ arg_log ([], args)
    | _, [] -> []
  in
  let arg_logs = arg_log (arg_typs, args) in
  let body =
    debug_body callback ~loc ~message:ret_descr.txt ~descr_loc:ret_descr ~arg_logs typ
      body
  in
  let body =
    match ret_typ2 with None -> body | Some typ -> [%expr ([%e body] : [%t typ])]
  in
  expand_fun body args

let debug_case callback ?ret_descr ?ret_typ ?arg_typ kind i { pc_lhs; pc_guard; pc_rhs } =
  let pc_guard = Option.map callback pc_guard in
  let loc = pc_lhs.ppat_loc in
  let _, bound = bound_patterns ~alt_typ:arg_typ pc_lhs in
  let arg_logs =
    List.map
      (fun (descr_loc, pat, typ) ->
        !log_value ~loc ~typ ~descr_loc ~is_result:false (pat2expr pat))
      bound
  in
  let message = pat2descr ~default:"_" pc_lhs in
  let message = if String.equal message.txt "_" then "" else " " ^ message.txt in
  let message = "<" ^ kind ^ " -- branch " ^ string_of_int i ^ ">" ^ message in
  let ret_descr =
    match ret_descr with
    | None -> { loc = pc_rhs.pexp_loc; txt = kind ^ "__res" }
    | Some ret -> ret
  in
  let pc_rhs =
    debug_body callback ~loc:pc_rhs.pexp_loc ~message ~descr_loc:ret_descr ~arg_logs
      ret_typ pc_rhs
  in
  { pc_lhs; pc_guard; pc_rhs }

let debug_binding callback vb =
  let loc = vb.pvb_loc in
  let pat, ret_descr, typ =
    match vb.pvb_pat with
    | [%pat?
        ([%p? { ppat_desc = Ppat_var descr_loc | Ppat_alias (_, descr_loc); _ } as pat] :
          [%t? typ])] ->
        (pat, Some descr_loc, Some typ)
    | { ppat_desc = Ppat_var descr_loc | Ppat_alias (_, descr_loc); _ } as pat ->
        (pat, Some descr_loc, None)
    | pat -> (pat, None, None)
  in
  let exp, typ2 =
    match vb.pvb_expr with
    | [%expr ([%e? exp] : [%t? typ])] -> (exp, Some typ)
    | exp -> (exp, None)
  in
  let typ =
    match typ with Some typ -> Some (pick ~typ ?alt_typ:typ2 ()) | None -> typ2
  in
  let arg_typ, ret_typ =
    match typ with
    | Some { ptyp_desc = Ptyp_arrow (_, arg_typ, ret_typ); _ } ->
        (Some arg_typ, Some ret_typ)
    | _ -> (None, None)
  in
  let exp =
    match exp with
    | { pexp_desc = Pexp_newtype _ | Pexp_fun _; _ } ->
        (* [ret_typ] is not the return type if the function has more arguments. *)
        debug_fun callback ?typ ?ret_descr exp
    | { pexp_desc = Pexp_function cases; _ } ->
        A.pexp_function ~loc:vb.pvb_expr.pexp_loc
          (List.mapi (debug_case callback ?ret_descr ?ret_typ ?arg_typ "function") cases)
    | _ ->
        let result, bound = bound_patterns ~alt_typ:typ pat in
        if bound = [] then raise Not_transforming;
        let descr_loc = pat2descr ~default:"__val" pat in
        let log_result =
          List.map
            (fun (descr_loc, pat, typ) ->
              !log_value ~loc:vb.pvb_expr.pexp_loc ~typ ~descr_loc ~is_result:true
                (pat2expr pat))
            bound
          |> List.fold_left
               (fun e1 e2 ->
                 [%expr
                   [%e e1];
                   [%e e2]])
               [%expr ()]
        in
        let preamble =
          open_log_preamble ~brief:true ~message:descr_loc.txt ~loc:descr_loc.loc ()
        in
        entry_with_interrupts ~loc ~descr_loc ~preamble ~entry:(callback exp) ~result
          ~log_result ()
  in
  match typ2 with
  | None -> { vb with pvb_expr = exp }
  | Some typ -> { vb with pvb_expr = [%expr ([%e exp] : [%t typ])] }

type rule = {
  ext_point : string;
  tracking : bool;
  expander : [ `Debug | `Debug_this | `Str ];
  printer : [ `Pp | `Sexp | `Show ];
}

let rules =
  List.concat
  @@ List.map
       (fun tracking ->
         List.concat
         @@ List.map
              (fun expander ->
                List.map
                  (fun printer ->
                    let ext_point = if tracking then "track" else "debug" in
                    let ext_point =
                      ext_point
                      ^ match expander with `Debug_this -> "_this" | `Debug | `Str -> ""
                    in
                    let ext_point =
                      ext_point ^ "_"
                      ^
                      match printer with `Pp -> "pp" | `Sexp -> "sexp" | `Show -> "show"
                    in
                    { ext_point; tracking; expander; printer })
                  [ `Pp; `Sexp; `Show ])
              [ `Debug; `Debug_this; `Str ])
       [ false; true ]

let is_ext_point =
  let points = List.map (fun r -> Re.str r.ext_point) rules in
  let regex = Re.(compile @@ seq [ start; alt points; stop ]) in
  Re.execp regex

let traverse =
  object (self)
    inherit Ast_traverse.map as super

    method! expression exp =
      let callback e = self#expression e in
      let track_cases ?ret_descr ?ret_typ ?arg_typ kind =
        List.mapi (debug_case callback ?ret_descr ?ret_typ ?arg_typ kind)
      in
      let loc = exp.pexp_loc in
      let exp, ret_typ =
        match exp with
        | [%expr ([%e? exp] : [%t? typ])] -> (exp, Some typ)
        | _ -> (exp, None)
      in
      let pexp_desc =
        match exp.pexp_desc with
        | Pexp_let (rec_flag, bindings, body) ->
            let bindings =
              List.map
                (fun vb ->
                  try debug_binding callback vb
                  with Not_transforming ->
                    { vb with pvb_expr = super#expression vb.pvb_expr })
                bindings
            in
            Pexp_let (rec_flag, bindings, callback body)
        | Pexp_extension ({ loc = _; txt }, PStr [%str [%e? body]]) when is_ext_point txt
          ->
            (callback body).pexp_desc
        | Pexp_extension ({ loc = _; txt = "debug_notrace" }, PStr [%str [%e? body]]) -> (
            let old_track_branches = !track_branches in
            track_branches := false;
            match callback body with
            | result ->
                track_branches := old_track_branches;
                result.pexp_desc
            | exception e ->
                track_branches := old_track_branches;
                raise e)
        | Pexp_extension
            ( { loc = _; txt = "debug_interrupts" },
              PStr
                [%str
                  {
                    max_nesting_depth = [%e? max_nesting_depth];
                    max_num_children = [%e? max_num_children];
                  };
                  [%e? body]] ) -> (
            let old_interrupts = !interrupts in
            interrupts := true;
            match callback body with
            | result ->
                interrupts := old_interrupts;
                [%expr
                  Debug_runtime.max_nesting_depth := Some [%e max_nesting_depth];
                  Debug_runtime.max_num_children := Some [%e max_num_children];
                  [%e result]]
                  .pexp_desc
            | exception e ->
                interrupts := old_interrupts;
                raise e)
        | Pexp_extension ({ loc = _; txt = "debug_interrupts" }, PStr [%str [%e? _]]) ->
            (A.pexp_extension ~loc
            @@ Location.error_extensionf ~loc
                 "ppx_minidebug: bad syntax, expacted [%%debug_interrupts \
                  {max_nesting_depth=N;max_num_children=M}; BODY]")
              .pexp_desc
        | Pexp_extension ({ loc = _; txt = "debug_type_info" }, PStr [%str [%e? body]])
          -> (
            let old_output_type_info = !output_type_info in
            output_type_info := true;
            match callback body with
            | result ->
                output_type_info := old_output_type_info;
                result.pexp_desc
            | exception e ->
                output_type_info := old_output_type_info;
                raise e)
        | Pexp_newtype (type_label, subexp) -> (
            try (debug_fun callback ?typ:ret_typ exp).pexp_desc
            with Not_transforming -> Pexp_newtype (type_label, self#expression subexp))
        | Pexp_fun (arg_label, guard, pat, subexp) -> (
            try (debug_fun callback ?typ:ret_typ exp).pexp_desc
            with Not_transforming ->
              Pexp_fun (arg_label, guard, pat, self#expression subexp))
        | Pexp_match ([%expr ([%e? expr] : [%t? arg_typ])], cases) when !track_branches ->
            Pexp_match (callback expr, track_cases ~arg_typ ?ret_typ "match" cases)
        | Pexp_match (expr, cases) when !track_branches ->
            Pexp_match (callback expr, track_cases ?ret_typ "match" cases)
        | Pexp_function cases when !track_branches ->
            let arg_typ, ret_typ =
              match ret_typ with
              | Some { ptyp_desc = Ptyp_arrow (_, arg, ret); _ } -> (Some arg, Some ret)
              | _ -> (None, None)
            in
            Pexp_function (track_cases ?arg_typ ?ret_typ "function" cases)
        | Pexp_ifthenelse (if_, then_, else_) when !track_branches ->
            let then_ =
              let loc = then_.pexp_loc in
              [%expr
                let __entry_id = Debug_runtime.get_entry_id () in
                [%e open_log_preamble ~brief:true ~message:"<if -- then branch>" ~loc ()];
                match [%e callback then_] with
                | if_then__result ->
                    Debug_runtime.close_log ();
                    if_then__result
                | exception e ->
                    Debug_runtime.close_log ();
                    raise e]
            in
            let else_ =
              Option.map
                (fun else_ ->
                  let loc = else_.pexp_loc in
                  [%expr
                    let __entry_id = Debug_runtime.get_entry_id () in
                    [%e
                      open_log_preamble ~brief:true ~message:"<if -- else branch>" ~loc ()];
                    match [%e callback else_] with
                    | if_else__result ->
                        Debug_runtime.close_log ();
                        if_else__result
                    | exception e ->
                        Debug_runtime.close_log ();
                        raise e])
                else_
            in
            Pexp_ifthenelse (callback if_, then_, else_)
        | Pexp_for (pat, from, to_, dir, body) when !track_branches ->
            let body =
              let loc = body.pexp_loc in
              let descr_loc = pat2descr ~default:"__for_index" pat in
              let typ =
                A.ptyp_constr ~loc:pat.ppat_loc
                  { txt = Lident "int"; loc = pat.ppat_loc }
                  []
              in
              let preamble =
                open_log_preamble ~brief:true
                  ~message:("<for " ^ descr_loc.txt ^ ">")
                  ~loc:descr_loc.loc ()
              in
              let header = !log_value ~loc ~typ ~descr_loc ~is_result:false (pat2expr pat) in
              entry_with_interrupts ~loc ~descr_loc ~header ~preamble
                ~entry:(callback body)
                ~result:[%pat? ()]
                ~log_result:[%expr ()] ()
            in
            let loc = exp.pexp_loc in
            [%expr
              let __entry_id = Debug_runtime.get_entry_id () in
              [%e open_log_preamble ~brief:true ~message:"<for loop>" ~loc ()];
              match
                [%e { exp with pexp_desc = Pexp_for (pat, from, to_, dir, body) }]
              with
              | () -> Debug_runtime.close_log ()
              | exception e ->
                  Debug_runtime.close_log ();
                  raise e]
              .pexp_desc
        | Pexp_while (cond, body) when !track_branches ->
            let body =
              let loc = body.pexp_loc in
              let descr_loc = { txt = "<while body>"; loc } in
              let preamble =
                open_log_preamble ~brief:true ~message:"<while loop>" ~loc:descr_loc.loc
                  ()
              in
              entry_with_interrupts ~loc ~descr_loc ~preamble ~entry:(callback body)
                ~result:[%pat? ()]
                ~log_result:[%expr ()] ()
            in
            let loc = exp.pexp_loc in
            [%expr
              let __entry_id = Debug_runtime.get_entry_id () in
              [%e open_log_preamble ~brief:true ~message:"<while loop>" ~loc ()];
              match [%e { exp with pexp_desc = Pexp_while (cond, body) }] with
              | () -> Debug_runtime.close_log ()
              | exception e ->
                  Debug_runtime.close_log ();
                  raise e]
              .pexp_desc
        | _ -> (super#expression exp).pexp_desc
      in
      let exp = { exp with pexp_desc } in
      match ret_typ with None -> exp | Some typ -> [%expr ([%e exp] : [%t typ])]

    method! structure_item si =
      let callback e = self#expression e in
      match si with
      | { pstr_desc = Pstr_value (rec_flag, bindings); pstr_loc = _; _ } ->
          let bindings =
            List.map
              (fun vb ->
                try debug_binding callback vb
                with Not_transforming ->
                  { vb with pvb_expr = super#expression vb.pvb_expr })
              bindings
          in
          { si with pstr_desc = Pstr_value (rec_flag, bindings) }
      | _ -> super#structure_item si
  end

let debug_this_expander payload =
  let callback e = traverse#expression e in
  match payload with
  | { pexp_desc = Pexp_let (recflag, bindings, body); _ } ->
      (* This is the [let%debug_this ... in] use-case: do not debug the whole body. *)
      let bindings =
        List.map
          (fun vb ->
            try debug_binding callback vb
            with Not_transforming ->
              { vb with pvb_expr = traverse#expression vb.pvb_expr })
          bindings
      in
      { payload with pexp_desc = Pexp_let (recflag, bindings, body) }
  | expr -> expr

let debug_expander payload = traverse#expression payload

let str_expander ~loc payload =
  match List.map (fun si -> traverse#structure_item si) payload with
  | [ item ] -> item
  | items ->
      Ast_helper.Str.include_
        {
          pincl_mod = Ast_helper.Mod.structure items;
          pincl_loc = loc;
          pincl_attributes = [];
        }

let global_output_type_info =
  let expanderf expander =
    output_type_info := true;
    expander
  in
  let declaration =
    Extension.V3.declare "global_debug_type_info" Extension.Context.structure_item
      Ast_pattern.(pstr __)
      (fun ~ctxt ->
        expanderf
          (str_expander ~loc:(Expansion_context.Extension.extension_point_loc ctxt)))
  in
  Ppxlib.Context_free.Rule.extension declaration

let global_interrupts =
  let declaration =
    Extension.V3.declare "global_debug_interrupts" Extension.Context.structure_item
      Ast_pattern.(pstr __)
      (fun ~ctxt ->
        let loc = Expansion_context.Extension.extension_point_loc ctxt in
        function
        | [
            {
              pstr_desc =
                Pstr_eval
                  ( [%expr
                      {
                        max_nesting_depth = [%e? max_nesting_depth];
                        max_num_children = [%e? max_num_children];
                      }],
                    attrs );
              _;
            };
          ] ->
            interrupts := true;
            A.pstr_eval ~loc
              [%expr
                Debug_runtime.max_nesting_depth := Some [%e max_nesting_depth];
                Debug_runtime.max_num_children := Some [%e max_num_children]]
              attrs
        | _ ->
            A.pstr_eval ~loc
              (A.pexp_extension ~loc
              @@ Location.error_extensionf ~loc
                   "ppx_minidebug: bad syntax, expacted [%%%%global_debug_interrupts \
                    {max_nesting_depth=N;max_num_children=M}]")
              [])
  in
  Ppxlib.Context_free.Rule.extension declaration

let rules =
  global_output_type_info :: global_interrupts
  :: List.map
       (fun { ext_point; tracking; expander; printer } ->
         let logf =
           match printer with
           | `Show -> log_value_show
           | `Pp -> log_value_pp
           | `Sexp -> log_value_sexp
         in
         let expanderf expander =
           log_value := logf;
           track_branches := tracking;
           expander
         in
         let declaration =
           match expander with
           | `Debug ->
               Extension.V3.declare ext_point Extension.Context.expression
                 Ast_pattern.(single_expr_payload __)
                 (fun ~ctxt:_ -> expanderf debug_expander)
           | `Debug_this ->
               Extension.V3.declare ext_point Extension.Context.expression
                 Ast_pattern.(single_expr_payload __)
                 (fun ~ctxt:_ -> expanderf debug_this_expander)
           | `Str ->
               Extension.V3.declare ext_point Extension.Context.structure_item
                 Ast_pattern.(pstr __)
                 (fun ~ctxt ->
                   expanderf
                     (str_expander
                        ~loc:(Expansion_context.Extension.extension_point_loc ctxt)))
         in
         Ppxlib.Context_free.Rule.extension declaration)
       rules

let () = Driver.register_transformation ~rules "ppx_minidebug"
