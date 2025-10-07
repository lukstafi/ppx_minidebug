open Ppxlib
module A = Ast_builder.Default
(* module H = Ast_helper *)

type log_value = Sexp | Show | Pp
type toplevel_kind = Nested | Runtime_outer | Runtime_passing | Runtime_local

let is_local_debug_runtime = function Runtime_local -> true | _ -> false
let global_log_count = ref 0

type log_level = Comptime of int | Runtime of expression

type context = {
  log_value : log_value;
  track_or_explicit : [ `Diagn | `Debug | `Track ];
  output_type_info : bool;
  interrupts : bool;
  log_level : log_level;
  entry_log_level : log_level;
  hidden : bool;
  toplevel_kind : toplevel_kind;
}

let init_context =
  let default =
    try Sys.getenv "PPX_MINIDEBUG_DEFAULT_COMPILE_LOG_LEVEL" with Not_found -> ""
  in
  let default =
    try int_of_string (if default = "" then "9" else default)
    with Failure f ->
      failwith
      @@ "ppx_minidebug: MINIDEBUG_DEFAULT_LOG_LEVEL must be an integer, got error: " ^ f
  in
  ref
    {
      log_value = Sexp;
      track_or_explicit = `Debug;
      output_type_info = false;
      interrupts = false;
      log_level = Comptime default;
      entry_log_level = Comptime 1;
      hidden = false;
      toplevel_kind = Runtime_local;
    }

let parse_log_level = function
  | { pexp_desc = Pexp_constant (Pconst_integer (i, None)); _ } ->
      Comptime (int_of_string i)
  | ll -> Runtime ll

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
  | Ptyp_alias (typ, x) -> typ2str typ ^ " as '" ^ x.txt
  | Ptyp_variant (_, _, _) -> "<poly-variant>"
  | Ptyp_poly (vs, typ) ->
      String.concat " " (List.map (fun v -> "'" ^ v.txt) vs) ^ "." ^ typ2str typ
  | Ptyp_package _ -> "<module val>"
  | Ptyp_extension _ -> "<extension>"
  | Ptyp_open (_, typ) -> typ2str typ

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

let lift_track_or_explicit ~loc = function
  | `Diagn -> [%expr `Diagn]
  | `Debug -> [%expr `Debug]
  | `Track -> [%expr `Track]

let ll_to_expr ~digit_loc = function
  | Comptime ll -> A.eint ~loc:digit_loc ll
  | Runtime e -> e

let open_log ?(message = "") ~loc ~log_level track_or_explicit =
  if String.contains message '\n' then
    A.pexp_extension ~loc
    @@ Location.error_extensionf ~loc
         {|ppx_minidebug: multiline messages in log entry headers not allowed, found: "%s"|}
         message
  else
    [%expr
      Debug_runtime.open_log
        ~fname:[%e A.estring ~loc loc.loc_start.pos_fname]
        ~start_lnum:[%e A.eint ~loc loc.loc_start.pos_lnum]
        ~start_colnum:[%e A.eint ~loc (loc.loc_start.pos_cnum - loc.loc_start.pos_bol)]
        ~end_lnum:[%e A.eint ~loc loc.loc_end.pos_lnum]
        ~end_colnum:[%e A.eint ~loc (loc.loc_end.pos_cnum - loc.loc_end.pos_bol)]
        ~message:[%e A.estring ~loc message] ~entry_id:__entry_id
        ~log_level:[%e ll_to_expr ~digit_loc:loc log_level]
        [%e lift_track_or_explicit ~loc track_or_explicit]]

let open_log_no_source ~message ~loc ~log_level track_or_explicit =
  [%expr
    Debug_runtime.open_log_no_source ~message:[%e message] ~entry_id:__entry_id
      ~log_level:[%e ll_to_expr ~digit_loc:loc log_level]
      [%e lift_track_or_explicit ~loc track_or_explicit]]

let close_log ~loc =
  [%expr
    Debug_runtime.close_log
      ~fname:[%e A.estring ~loc loc.loc_start.pos_fname]
      ~start_lnum:[%e A.eint ~loc loc.loc_start.pos_lnum]
      ~entry_id:__entry_id]

let to_descr context ~loc ~descr_loc typ =
  match descr_loc with
  | None -> [%expr None]
  | Some descr_loc ->
      let descr =
        if context.output_type_info then descr_loc.txt ^ " : " ^ typ2str typ
        else descr_loc.txt
      in
      let loc = descr_loc.loc in
      if String.contains descr '\n' then
        A.pexp_extension ~loc
        @@ Location.error_extensionf ~loc
             {|ppx_minidebug: multiline log descriptions not allowed, found: "%s"|} descr
      else [%expr Some [%e A.estring ~loc:descr_loc.loc descr]]

let check_comptime_log_level context ~is_explicit ~is_result:_ ~log_level exp thunk =
  let loc = exp.pexp_loc in
  match (context.track_or_explicit, context.log_level, log_level) with
  | `Diagn, _, _ when not is_explicit -> [%expr ()]
  | _, Comptime c_ll, Comptime e_ll when c_ll < e_ll -> [%expr ()]
  | _ -> thunk ()

(* *** The sexplib-based variant. *** *)
let log_value_sexp context ~loc ~typ ?descr_loc ~is_explicit ~is_result ~log_level exp =
  check_comptime_log_level context ~is_explicit ~is_result ~log_level exp @@ fun () ->
  match typ with
  | {
      ptyp_desc = Ptyp_poly (_, { ptyp_desc = Ptyp_extension ext; _ });
      ptyp_loc = loc;
      _;
    }
  | { ptyp_desc = Ptyp_extension ext; ptyp_loc = loc; _ } ->
      (* Propagate error if the type could not be found. *)
      A.pexp_extension ~loc ext
  | { ptyp_desc = Ptyp_poly (_, typ); _ } | typ ->
      (* [%sexp_of: typ] does not work with `Ptyp_poly`. Misleading error "Let with no
         bindings". *)
      incr global_log_count;
      [%expr
        Debug_runtime.log_value_sexp
          ?descr:[%e to_descr context ~loc ~descr_loc typ]
          ~entry_id:__entry_id
          ~log_level:[%e ll_to_expr ~digit_loc:loc log_level]
          ~is_result:[%e A.ebool ~loc is_result]
          (lazy ([%sexp_of: [%t typ]] [%e exp]))]

(* *** The deriving.show pp-based variant. *** *)
let rec splice_lident ~id_prefix ident =
  let splice id =
    if String.equal id_prefix "pp_" && String.equal id "t" then "pp" else id_prefix ^ id
  in
  match ident with
  | Lident id -> Lident (splice id)
  | Ldot (path, id) -> Ldot (path, splice id)
  | Lapply (f, a) -> Lapply (splice_lident ~id_prefix f, a)

let log_value_pp context ~loc ~typ ?descr_loc ~is_explicit ~is_result ~log_level exp =
  check_comptime_log_level context ~is_explicit ~is_result ~log_level exp @@ fun () ->
  match typ with
  | {
   ptyp_desc =
     ( Ptyp_constr (t_lident_loc, [])
     | Ptyp_poly (_, { ptyp_desc = Ptyp_constr (t_lident_loc, []); _ }) );
   _;
  } ->
      let converter =
        A.pexp_ident ~loc
          { t_lident_loc with txt = splice_lident ~id_prefix:"pp_" t_lident_loc.txt }
      in
      incr global_log_count;
      [%expr
        Debug_runtime.log_value_pp
          ?descr:[%e to_descr context ~loc ~descr_loc typ]
          ~entry_id:__entry_id
          ~log_level:[%e ll_to_expr ~digit_loc:loc log_level]
          ~pp:[%e converter] ~is_result:[%e A.ebool ~loc is_result]
          (lazy [%e exp])]
  | _ ->
      A.pexp_extension ~loc
      @@ Location.error_extensionf ~loc
           "ppx_minidebug: cannot find a concrete type to _pp log this value: try _show \
            or _sexp"

(* *** The deriving.show string-based variant. *** *)
let log_value_show context ~loc ~typ ?descr_loc ~is_explicit ~is_result ~log_level exp =
  check_comptime_log_level context ~is_explicit ~is_result ~log_level exp @@ fun () ->
  match typ with
  | {
      ptyp_desc = Ptyp_poly (_, { ptyp_desc = Ptyp_extension ext; _ });
      ptyp_loc = loc;
      _;
    }
  | { ptyp_desc = Ptyp_extension ext; ptyp_loc = loc; _ } ->
      (* Propagate error if the type could not be found. *)
      A.pexp_extension ~loc ext
  | { ptyp_desc = Ptyp_poly (_, typ); _ } | typ ->
      (* Defensive in case there's problems with poly types. *)
      incr global_log_count;
      [%expr
        Debug_runtime.log_value_show
          ?descr:[%e to_descr context ~loc ~descr_loc typ]
          ~entry_id:__entry_id
          ~log_level:[%e ll_to_expr ~digit_loc:loc log_level]
          ~is_result:[%e A.ebool ~loc is_result]
          (lazy ([%show: [%t typ]] [%e exp]))]

let log_value context =
  match context.log_value with
  | Sexp -> log_value_sexp context
  | Show -> log_value_show context
  | Pp -> log_value_pp context

(* *** The sexplib-based variant. *** *)
let log_value_printbox context ~loc ~log_level exp =
  check_comptime_log_level context ~is_explicit:true ~is_result:false ~log_level exp
  @@ fun () ->
  incr global_log_count;
  [%expr
    Debug_runtime.log_value_printbox ~entry_id:__entry_id
      ~log_level:[%e ll_to_expr ~digit_loc:loc log_level]
      [%e exp]]

let log_string ~loc ~descr_loc ~log_level s =
  if String.contains descr_loc.txt '\n' then
    A.pexp_extension ~loc
    @@ Location.error_extensionf ~loc
         {|ppx_minidebug: unexpected multiline internal message: "%s"|} descr_loc.txt
  else
    [%expr
      Debug_runtime.log_value_show
        ~descr:[%e A.estring ~loc:descr_loc.loc descr_loc.txt]
        ~entry_id:__entry_id
        ~log_level:[%e ll_to_expr ~digit_loc:loc log_level]
        ~is_result:false
        (lazy [%e A.estring ~loc s])]

let log_string_with_descr ~loc ~message ~log_level s =
  [%expr
    Debug_runtime.log_value_show ~descr:[%e message] ~entry_id:__entry_id
      ~log_level:[%e ll_to_expr ~digit_loc:loc log_level]
      ~is_result:false
      (lazy [%e A.estring ~loc s])]

type fun_arg =
  | Pfunction_param of function_param
  | Pexp_newtype_arg of label loc * location * location_stack * attributes

let rec collect_fun_typs ?to_drop arg_typs typ =
  match (typ.ptyp_desc, to_drop) with
  | Ptyp_alias (typ, _), _ | Ptyp_poly (_, typ), _ -> collect_fun_typs arg_typs typ
  | Ptyp_arrow (_, arg_typ, typ), None -> collect_fun_typs (arg_typ :: arg_typs) typ
  | Ptyp_arrow (_, arg_typ, typ), Some (_ :: rest) ->
      collect_fun_typs ~to_drop:rest (arg_typ :: arg_typs) typ
  | _ -> (List.rev arg_typs, typ)

let rec pick ~typ ?alt_typ () =
  let rec deref typ =
    match typ.ptyp_desc with
    | Ptyp_alias (typ, _) | Ptyp_poly (_, typ) -> deref typ
    | _ -> typ
  in
  let typ = deref typ
  and alt_typ = match alt_typ with None -> None | Some t -> Some (deref t) in
  match alt_typ with
  | None -> typ
  | Some alt_typ -> (
      let loc = typ.ptyp_loc in
      match typ.ptyp_desc with
      | Ptyp_any -> alt_typ
      | Ptyp_var _ -> alt_typ
      | Ptyp_extension _ -> alt_typ
      | Ptyp_arrow (_, arg, ret) -> (
          match alt_typ with
          | { ptyp_desc = Ptyp_arrow (_, arg2, ret2); _ } ->
              let arg = pick ~typ:arg ~alt_typ:arg2 () in
              let ret = pick ~typ:ret ~alt_typ:ret2 () in
              A.ptyp_arrow ~loc Nolabel arg ret
          | _ -> typ)
      | Ptyp_tuple args -> (
          match alt_typ with
          | { ptyp_desc = Ptyp_tuple args2; _ } when List.length args = List.length args2
            ->
              let args =
                List.map2 (fun typ alt_typ -> pick ~typ ~alt_typ ()) args args2
              in
              A.ptyp_tuple ~loc args
          | _ -> typ)
      | Ptyp_constr (c, args) -> (
          match alt_typ with
          | { ptyp_desc = Ptyp_constr (c2, args2); _ }
            when String.equal (last_ident c.txt) (last_ident c2.txt)
                 && List.length args = List.length args2 ->
              let args =
                List.map2 (fun typ alt_typ -> pick ~typ ~alt_typ ()) args args2
              in
              A.ptyp_constr ~loc c args
          | _ -> typ)
      | _ -> typ)

let typ_of_constraint constr =
  match constr with
  | Some (Pconstraint typ) -> Some (pick ~typ ())
  | Some (Pcoerce (alt_typ, typ)) -> Some (pick ~typ ?alt_typ ())
  | None -> None

let rec collect_fun accu = function
  | {
      pexp_desc = Pexp_function (params, constraint_, body);
      pexp_loc;
      pexp_loc_stack;
      pexp_attributes;
    }
    when params <> [] -> (
      let params = List.map (fun p -> Pfunction_param p) params in
      let accu = List.rev_append params accu in
      let alt_typ = typ_of_constraint constraint_ in
      match body with
      | Pfunction_body body_exp -> (
          let args, body, ret_typ = collect_fun accu body_exp in
          (* The constraint_ on this Pexp_function node represents the return type after
             applying all params in this node. We should only drop arrows for params
             collected from inner nodes (i.e., args that are not in params). *)
          let inner_args =
            let num_params = List.length params in
            let num_args = List.length args in
            if num_args > num_params then
              List.filteri (fun i _ -> i < num_args - num_params) args
            else []
          in
          let alt_typ =
            Option.map
              (fun typ -> snd @@ collect_fun_typs ~to_drop:inner_args [] typ)
              alt_typ
          in
          ( args,
            body,
            match ret_typ with
            | Some ret_typ -> Some (pick ~typ:ret_typ ?alt_typ ())
            | None -> alt_typ ))
      | Pfunction_cases (cases, loc, attrs) ->
          ( List.rev accu,
            {
              pexp_desc =
                Pexp_function ([], constraint_, Pfunction_cases (cases, loc, attrs));
              pexp_loc;
              pexp_loc_stack;
              pexp_attributes;
            },
            (* Note: this is not the return type of the pexp_desc function above. *)
            alt_typ ))
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
  | Pfunction_param param :: args ->
      (* Collect all consecutive function parameters *)
      let rec collect_params acc = function
        | Pfunction_param p :: rest -> collect_params (p :: acc) rest
        | rest -> (List.rev acc, rest)
      in
      let params, remaining = collect_params [ param ] args in
      let body_fun = expand_fun body remaining in
      {
        pexp_desc = Pexp_function (params, None, Pfunction_body body_fun);
        pexp_loc = param.pparam_loc;
        pexp_loc_stack = [];
        pexp_attributes = [];
      }
  | Pexp_newtype_arg (type_label, pexp_loc, pexp_loc_stack, pexp_attributes) :: args ->
      {
        pexp_desc = Pexp_newtype (type_label, expand_fun body args);
        pexp_loc;
        pexp_loc_stack;
        pexp_attributes;
      }

let rec has_unprintable_type typ =
  match typ.ptyp_desc with
  | Ptyp_alias (typ, _) | Ptyp_poly (_, typ) -> has_unprintable_type typ
  | Ptyp_any | Ptyp_var _ | Ptyp_package _ | Ptyp_extension _ -> true
  | Ptyp_arrow (_, arg, ret) ->
      (* TODO: maybe add Ptyp_object, Ptyp_class? *)
      has_unprintable_type arg || has_unprintable_type ret
  | Ptyp_tuple args | Ptyp_constr (_, args) -> List.exists has_unprintable_type args
  | _ -> false

let bound_patterns ~alt_typ pat =
  let rec loop ?alt_typ pat =
    let loc = pat.ppat_loc in
    let typ, pat =
      match pat with
      | [%pat? ([%p? pat] : [%t? typ])] -> (Some (pick ~typ ?alt_typ ()), pat)
      | _ -> (alt_typ, pat)
    in
    match (typ, pat) with
    | Some t, { ppat_desc = Ppat_var _ | Ppat_alias (_, _); _ }
      when has_unprintable_type t ->
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

let entry_with_interrupts context ~loc ?descr_loc ?message ~log_count_before ?header
    ~preamble ~entry ~result ~log_result () =
  let log_string =
    match (descr_loc, message) with
    | Some descr_loc, None -> log_string ~loc ~descr_loc
    | None, Some message -> log_string_with_descr ~loc ~message
    | _ -> assert false
  in
  if
    context.track_or_explicit <> `Track
    && log_count_before = !global_log_count
    && message = None
  then entry
  else
    let header = match header with Some h -> h | None -> [%expr ()] in
    let log_close = close_log ~loc in
    let ghost_loc = { loc with loc_ghost = true } in
    let body =
      if context.interrupts then
        [%expr
          if Debug_runtime.exceeds_max_children () then (
            [%e preamble];
            [%e header];
            [%e
              log_string ~log_level:context.entry_log_level "<max_num_children exceeded>"];
            [%e log_close];
            failwith "ppx_minidebug: max_num_children exceeded")
          else if Debug_runtime.exceeds_max_nesting () then (
            [%e preamble];
            [%e header];
            [%e
              log_string ~log_level:context.entry_log_level "<max_nesting_depth exceeded>"];
            [%e log_close];
            failwith "ppx_minidebug: max_nesting_depth exceeded")
          else (
            [%e preamble];
            [%e header];
            match [%e entry] with
            | [%p result] ->
                [%e log_result];
                [%e log_close];
                [%e pat2expr result]
            | exception e ->
                [%e log_close];
                raise e)]
      else
        [%expr
          [%e preamble];
          [%e header];
          match [%e entry] with
          | [%p result] ->
              [%e log_result];
              [%e log_close];
              [%e pat2expr result]
          | exception e ->
              [%e log_close];
              raise e]
    in
    let expr =
      let loc = ghost_loc in
      [%expr Debug_runtime.get_entry_id ()]
    in
    A.pexp_let ~loc Nonrecursive
      [ A.value_binding ~loc:ghost_loc ~pat:(A.pvar ~loc:ghost_loc "__entry_id") ~expr ]
      body

let debug_body context callback ~loc ~message ~descr_loc ~log_count_before ~arg_logs typ
    body =
  let message =
    match typ with
    | Some t when context.output_type_info -> message ^ " : " ^ typ2str t
    | _ -> message
  in
  let preamble =
    open_log ~message ~loc ~log_level:context.entry_log_level context.track_or_explicit
  in
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
  let body, log_result =
    match typ with
    | None -> (body, [%expr ()])
    | Some ({ ptyp_desc = Ptyp_package _; _ } as typ) ->
        (* Restore an obligatory type annotation. *)
        ([%expr ([%e body] : [%t typ])], [%expr ()])
    | Some typ when has_unprintable_type typ -> (body, [%expr ()])
    | Some typ ->
        ( body,
          log_value context ~loc ~typ ~descr_loc ~is_explicit:false ~is_result:true
            ~log_level:context.entry_log_level (pat2expr result) )
  in
  entry_with_interrupts context ~loc ~descr_loc ~log_count_before ~preamble
    ~entry:(callback context body) ~result ~log_result ()

let pass_runtime ?(always = false) toplevel_opt_arg exp =
  let loc = exp.pexp_loc in
  let exp' = match exp with [%expr ([%e? exp] : [%t? _typ])] -> exp | exp -> exp in
  (* Only pass runtime to functions. *)
  match (always, toplevel_opt_arg, exp') with
  | true, Runtime_passing, _
  | _, Runtime_passing, { pexp_desc = Pexp_newtype _ | Pexp_function _; _ } ->
      [%expr fun (_debug_runtime : (module Minidebug_runtime.Debug_runtime)) -> [%e exp]]
  | _ -> exp

let unpack_runtime toplevel_opt_arg exp =
  let loc = exp.pexp_loc in
  let result =
    match toplevel_opt_arg with
    | Nested | Runtime_outer -> exp
    | Runtime_local ->
        [%expr
          let module Debug_runtime = (val _get_local_debug_runtime ()) in
          [%e exp]]
    | Runtime_passing ->
        [%expr
          let module Debug_runtime = (val _debug_runtime) in
          [%e exp]]
  in
  result

let has_runtime_arg = function
  | { toplevel_kind = Runtime_passing; _ } -> true
  | _ -> false

let loc_to_name loc =
  let fname = Filename.basename loc.loc_start.pos_fname |> Filename.remove_extension in
  fname ^ ":" ^ Int.to_string loc.loc_start.pos_lnum

let is_comptime_nothing context =
  match context.log_level with Comptime i when i <= 0 -> true | _ -> false

let debug_fun context callback ?typ ?ret_descr ?ret_typ exp =
  let log_count_before = !global_log_count in
  let args, body, ret_typ2 = collect_fun [] exp in
  let nested = { context with toplevel_kind = Nested } in
  let no_change_exp () =
    let body = callback nested body in
    let body =
      match ret_typ2 with
      | Some typ ->
          let loc = body.pexp_loc in
          [%expr ([%e body] : [%t typ])]
      | None -> body
    in
    pass_runtime context.toplevel_kind @@ expand_fun body args
  in
  if is_comptime_nothing context then no_change_exp ()
  else
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
    if
      (not (context.track_or_explicit = `Track))
      && (context.toplevel_kind = Nested || ret_descr = None)
      && Option.is_none typ
    then no_change_exp ()
    else
      let ret_descr =
        match ret_descr with
        | None (* when context.track_branches *) ->
            let txt = "fun:" ^ loc_to_name loc in
            { txt; loc }
        | Some descr -> descr
      in
      let rec arg_log = function
        | arg_typs, Pexp_newtype_arg _ :: args -> arg_log (arg_typs, args)
        | ( alt_typ :: arg_typs,
            Pfunction_param
              {
                pparam_desc = Pparam_val (_arg_label, _opt_val, pat);
                pparam_loc = pexp_loc;
                _;
              }
            :: args ) ->
            let _, bound = bound_patterns ~alt_typ:(Some alt_typ) pat in
            List.map
              (fun (descr_loc, pat, typ) ->
                log_value context ~loc:pexp_loc ~typ ~descr_loc ~is_explicit:false
                  ~is_result:false ~log_level:context.entry_log_level (pat2expr pat))
              bound
            @ arg_log (arg_typs, args)
        | ( [],
            Pfunction_param
              {
                pparam_desc = Pparam_val (_arg_label, _opt_val, pat);
                pparam_loc = pexp_loc;
                _;
              }
            :: args ) ->
            let _, bound = bound_patterns ~alt_typ:None pat in
            List.map
              (fun (descr_loc, pat, typ) ->
                log_value context ~loc:pexp_loc ~typ ~descr_loc ~is_explicit:false
                  ~is_result:false ~log_level:context.entry_log_level (pat2expr pat))
              bound
            @ arg_log ([], args)
        | _, Pfunction_param { pparam_desc = Pparam_newtype _; _ } :: args ->
            arg_log (arg_typs, args)
        | _, [] -> []
      in
      let arg_logs = arg_log (arg_typs, args) in
      let body =
        debug_body nested callback ~loc ~message:ret_descr.txt ~descr_loc:ret_descr
          ~log_count_before ~arg_logs typ body
      in
      let body =
        match ret_typ2 with None -> body | Some typ -> [%expr ([%e body] : [%t typ])]
      in
      let exp = expand_fun (unpack_runtime context.toplevel_kind body) args in
      pass_runtime context.toplevel_kind exp

let debug_case ?(unpack_context = Nested) context callback ?ret_descr ?ret_typ ?arg_typ
    kind i { pc_lhs; pc_guard; pc_rhs } =
  let log_count_before = !global_log_count in
  let pc_guard = Option.map (callback context) pc_guard in
  let loc = pc_lhs.ppat_loc in
  let _, bound = bound_patterns ~alt_typ:arg_typ pc_lhs in
  let arg_logs =
    List.map
      (fun (descr_loc, pat, typ) ->
        log_value context ~loc ~typ ~descr_loc ~is_explicit:false ~is_result:false
          ~log_level:context.entry_log_level (pat2expr pat))
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
    debug_body context callback ~loc:pc_rhs.pexp_loc ~message ~descr_loc:ret_descr
      ~log_count_before ~arg_logs ret_typ pc_rhs
  in
  let pc_rhs =
    if is_local_debug_runtime unpack_context then unpack_runtime unpack_context pc_rhs
    else if is_local_debug_runtime context.toplevel_kind then
      unpack_runtime context.toplevel_kind pc_rhs
    else pc_rhs
  in
  { pc_lhs; pc_guard; pc_rhs }

let debug_function ?unpack_context context callback ~loc ?constr ?ret_descr ?ret_typ
    ?arg_typ cases =
  let unpack_context =
    match unpack_context with None -> context.toplevel_kind | Some ctx -> ctx
  in
  let nested = { context with toplevel_kind = Nested } in
  let cases =
    List.mapi
      (debug_case ~unpack_context nested callback ?ret_descr ?ret_typ ?arg_typ "function")
      cases
  in
  let exp =
    {
      pexp_desc = Pexp_function ([], constr, Pfunction_cases (cases, loc, []));
      pexp_loc = loc;
      pexp_loc_stack = [];
      pexp_attributes = [];
    }
  in
  match context.toplevel_kind with
  | Nested | Runtime_outer | Runtime_local -> exp
  | Runtime_passing ->
      [%expr
        fun (_debug_runtime : (module Minidebug_runtime.Debug_runtime)) ->
          let module Debug_runtime = (val _debug_runtime) in
          [%e exp]]

let debug_binding context callback vb =
  let nested = { context with toplevel_kind = Nested } in
  let pat, typ_p, pvb_pat =
    match (vb.pvb_pat, context.toplevel_kind) with
    | [%pat? ([%p? pat] : [%t? typ])], Runtime_passing ->
        let loc = vb.pvb_loc in
        ( pat,
          Some (pick ~typ ()),
          [%pat? ([%p pat] : (module Minidebug_runtime.Debug_runtime) -> [%t typ])] )
    | [%pat? ([%p? pat] : [%t? typ])], _ -> (pat, Some typ, vb.pvb_pat)
    | _ -> (vb.pvb_pat, None, vb.pvb_pat)
  in
  let typ_b, pvb_constraint =
    let loc = vb.pvb_loc in
    match (vb.pvb_constraint, context.toplevel_kind) with
    | Some (Pvc_constraint ct), Runtime_passing ->
        ( Some (pick ~typ:ct.typ ()),
          Some
            (Pvc_constraint
               {
                 ct with
                 typ = [%type: (module Minidebug_runtime.Debug_runtime) -> [%t ct.typ]];
               }) )
    | Some (Pvc_coercion { ground = Some typ; coercion }), Runtime_passing ->
        ( Some (pick ~typ ()),
          Some
            (Pvc_coercion
               {
                 ground =
                   Some [%type: (module Minidebug_runtime.Debug_runtime) -> [%t typ]];
                 coercion =
                   [%type: (module Minidebug_runtime.Debug_runtime) -> [%t coercion]];
               }) )
    | Some (Pvc_coercion { ground = None; coercion }), Runtime_passing ->
        ( Some (pick ~typ:coercion ()),
          Some
            (Pvc_coercion
               {
                 ground = None;
                 coercion =
                   [%type: (module Minidebug_runtime.Debug_runtime) -> [%t coercion]];
               }) )
    | (Some (Pvc_constraint { typ; _ }) as pvc), _ -> (Some typ, pvc)
    | (Some (Pvc_coercion { ground = Some typ; _ }) as pvc), _ -> (Some typ, pvc)
    | (Some (Pvc_coercion { ground = None; coercion; _ }) as pvc), _ ->
        (Some coercion, pvc)
    | None, _ -> (None, None)
  in
  if is_comptime_nothing context then
    {
      vb with
      pvb_pat;
      pvb_constraint;
      pvb_expr = pass_runtime context.toplevel_kind @@ callback nested vb.pvb_expr;
    }
  else
    let loc = vb.pvb_loc in
    let ret_descr =
      match pat with
      | { ppat_desc = Ppat_var descr_loc | Ppat_alias (_, descr_loc); _ } ->
          Some descr_loc
      | _ -> None
    in
    let exp, typ_e =
      match vb.pvb_expr with
      | [%expr ([%e? exp] : [%t? typ])] -> (exp, Some (pick ~typ ()))
      | exp -> (exp, None)
    in
    let typ =
      match typ_p with Some typ -> Some (pick ~typ ?alt_typ:typ_e ()) | None -> typ_e
    in
    let typ =
      match typ with Some typ -> Some (pick ~typ ?alt_typ:typ_b ()) | None -> typ_b
    in
    let arg_typ, ret_typ =
      match typ with
      | Some { ptyp_desc = Ptyp_arrow (_, arg_typ, ret_typ); _ } ->
          (Some arg_typ, Some ret_typ)
      | _ -> (None, None)
    in
    let exp =
      match exp with
      | { pexp_desc = Pexp_newtype _; _ } ->
          (* [debug_fun] handles the runtime passing configuration. *)
          debug_fun context callback ?typ ?ret_descr exp
      | { pexp_desc = Pexp_function (_ :: _, constr, _); _ } ->
          (* [ret_typ] is not the return type if the function has more arguments. *)
          let ret_typ = typ_of_constraint constr in
          debug_fun context callback ?typ ?ret_descr ?ret_typ exp
      | { pexp_desc = Pexp_function ([], constr, Pfunction_cases (cases, _, _)); _ } ->
          let ret_typ =
            match ret_typ with
            | Some ret_typ ->
                Some (pick ~typ:ret_typ ?alt_typ:(typ_of_constraint constr) ())
            | None -> typ_of_constraint constr
          in
          debug_function context callback ~loc:vb.pvb_expr.pexp_loc ?constr ?ret_descr
            ?ret_typ ?arg_typ cases
      | { pexp_desc = Pexp_function ([], _, _); _ } -> assert false
      | _
        when context.toplevel_kind = Nested
             && (is_comptime_nothing context || context.track_or_explicit = `Diagn) ->
          callback nested exp
      | _ ->
          let alt_typ = Option.map (fun typ -> pick ~typ ?alt_typ:typ_b ()) typ in
          let result, bound = bound_patterns ~alt_typ pat in
          if bound = [] && context.toplevel_kind = Nested then callback nested exp
          else
            let log_count_before = !global_log_count in
            let descr_loc = pat2descr ~default:"__val" pat in
            let log_result =
              List.map
                (fun (descr_loc, pat, typ) ->
                  log_value context ~loc:vb.pvb_expr.pexp_loc ~typ ~descr_loc
                    ~is_explicit:false ~is_result:true ~log_level:context.entry_log_level
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
              open_log ~message:descr_loc.txt ~loc:descr_loc.loc
                ~log_level:context.entry_log_level context.track_or_explicit
            in
            unpack_runtime context.toplevel_kind
              (entry_with_interrupts context ~loc ~descr_loc ~log_count_before ~preamble
                 ~entry:(callback nested exp) ~result ~log_result ())
    in
    let pvb_expr =
      match (typ_e, context.toplevel_kind) with
      | None, (Nested | Runtime_outer | Runtime_local) -> exp
      | Some typ, (Nested | Runtime_outer | Runtime_local) ->
          [%expr ([%e exp] : [%t typ])]
      | Some typ, Runtime_passing ->
          [%expr ([%e exp] : (module Minidebug_runtime.Debug_runtime) -> [%t typ])]
      | None, Runtime_passing ->
          [%expr ([%e exp] : (module Minidebug_runtime.Debug_runtime) -> _)]
    in
    { vb with pvb_expr; pvb_pat; pvb_constraint }

let extract_type ?default ~alt_typ exp =
  let default =
    let loc = exp.pexp_loc in
    match default with None -> [%type: string] | Some typ -> typ
  in
  let exception Not_transforming in
  let rec loop ~use_default ?alt_typ exp =
    let loc = exp.pexp_loc in
    let typ, exp =
      match exp with
      | [%expr ([%e? exp] : [%t? typ])] -> (Some (pick ~typ ?alt_typ ()), exp)
      | _ -> (alt_typ, exp)
    in
    match (typ, exp) with
    | ( Some { ptyp_desc = Ptyp_tuple typs; _ },
        { pexp_desc = Pexp_tuple exps; pexp_loc; _ } ) ->
        let typs =
          List.map2 (fun exp typ -> loop ~use_default:true ~alt_typ:typ exp) exps typs
        in
        A.ptyp_tuple ~loc:pexp_loc typs
    | _, { pexp_desc = Pexp_tuple exps; pexp_loc; _ } -> (
        try
          let typs = List.map (fun exp -> loop ~use_default:true exp) exps in
          A.ptyp_tuple ~loc:pexp_loc typs
        with Not_transforming -> (
          match typ with Some typ -> typ | None -> raise Not_transforming))
    | Some [%type: [%t? alt_typ] list], [%expr [%e? hd] :: [%e? tl]] -> (
        let typ =
          try Some (loop ~use_default:false ~alt_typ hd) with Not_transforming -> None
        in
        let typl =
          try Some (loop ~use_default:false ?alt_typ:typ tl)
          with Not_transforming -> None
        in
        match (typ, typl) with
        | Some typ, _ -> pick ~typ:[%type: [%t typ] list] ?alt_typ:typl ()
        | None, Some typl -> typl
        | None, None -> raise Not_transforming)
    | _, [%expr [%e? hd] :: [%e? tl]] -> (
        let alt_typ =
          try Some (loop ~use_default:false hd) with Not_transforming -> None
        in
        let typl =
          try Some (loop ~use_default:false ?alt_typ tl) with Not_transforming -> None
        in
        match (alt_typ, typl, typ) with
        | Some typ, _, _ -> pick ~typ:[%type: [%t typ] list] ?alt_typ:typl ()
        | None, Some typl, _ -> typl
        | None, None, Some typ -> typ
        | None, None, None -> raise Not_transforming)
    | Some typ, [%expr []] -> typ
    | None, [%expr []] -> [%type: _ list]
    | Some [%type: [%t? alt_typ] array], { pexp_desc = Pexp_array exps; _ } ->
        let typs =
          List.filter_map
            (fun exp ->
              try Some (loop ~use_default:false ~alt_typ exp)
              with Not_transforming -> None)
            exps
        in
        List.fold_left (fun typ alt_typ -> pick ~typ ~alt_typ ()) alt_typ typs
    | _, { pexp_desc = Pexp_array exps; _ } -> (
        try
          let typs =
            List.filter_map
              (fun exp ->
                try Some (loop ~use_default:false exp) with Not_transforming -> None)
              exps
          in
          match typs with
          | [] -> raise Not_transforming
          | typ :: typs ->
              let typ =
                List.fold_left (fun typ alt_typ -> pick ~typ ~alt_typ ()) typ typs
              in
              [%type: [%t typ] array]
        with Not_transforming -> (
          match typ with Some typ -> typ | None -> raise Not_transforming))
    | _, { pexp_desc = Pexp_constant (Pconst_integer _); _ } -> [%type: int]
    | _, { pexp_desc = Pexp_constant (Pconst_char _); _ } -> [%type: char]
    | _, { pexp_desc = Pexp_constant (Pconst_float _); _ } -> [%type: float]
    | _, { pexp_desc = Pexp_constant (Pconst_string _); _ } -> [%type: string]
    | Some [%type: [%t? alt_typ] Lazy.t], { pexp_desc = Pexp_lazy exp; _ } ->
        let typ = loop ~use_default:false ~alt_typ exp in
        [%type: [%t typ] Lazy.t]
    | _, { pexp_desc = Pexp_lazy exp; _ } -> (
        try
          let typ = loop ~use_default:false exp in
          [%type: [%t typ] Lazy.t]
        with Not_transforming -> (
          match typ with Some typ -> typ | None -> raise Not_transforming))
    | Some { ptyp_desc = Ptyp_any | Ptyp_var _ | Ptyp_package _ | Ptyp_extension _; _ }, _
      ->
        raise Not_transforming
    | Some typ, _ -> typ
    | None, _ when use_default ->
        { default with ptyp_loc = exp.pexp_loc; ptyp_loc_stack = exp.pexp_loc_stack }
    | None, _ -> raise Not_transforming
  in
  try loop ~use_default:true ?alt_typ exp
  with Not_transforming ->
    let loc = exp.pexp_loc in
    A.ptyp_extension ~loc
    @@ Location.error_extensionf ~loc
         "ppx_minidebug: cannot find a type to log this value"

type rule = {
  ext_point : string;
  track_or_explicit : [ `Diagn | `Debug | `Track ];
  toplevel_kind : toplevel_kind;
  expander : [ `Debug | `Str ];
  log_value : log_value;
  entry_log_level : log_level option;
}

let rules =
  List.concat
  @@ List.map
       (fun track_or_explicit ->
         List.concat
         @@ List.map
              (fun log_level ->
                List.concat
                @@ List.map
                     (fun toplevel_kind ->
                       List.concat
                       @@ List.map
                            (fun expander ->
                              List.map
                                (fun log_value ->
                                  let ext_point =
                                    match track_or_explicit with
                                    | `Debug -> "debug"
                                    | `Track -> "track"
                                    | `Diagn -> "diagn"
                                  in
                                  let ext_point =
                                    ext_point
                                    ^
                                    if log_level <= 0 then "" else string_of_int log_level
                                  in
                                  (* The expander currently does not affect the extension
                                     point name. *)
                                  let ext_point =
                                    match toplevel_kind with
                                    | Nested -> assert false
                                    | Runtime_outer -> ext_point ^ "_o"
                                    | Runtime_passing -> ext_point ^ "_rt"
                                    | Runtime_local -> ext_point
                                  in
                                  let ext_point =
                                    ext_point ^ "_"
                                    ^
                                    match log_value with
                                    | Pp -> "pp"
                                    | Sexp -> "sexp"
                                    | Show -> "show"
                                  in
                                  {
                                    ext_point;
                                    track_or_explicit;
                                    toplevel_kind;
                                    expander;
                                    log_value;
                                    entry_log_level =
                                      (if log_level <= 0 then None
                                       else Some (Comptime log_level));
                                  })
                                [ Pp; Sexp; Show ])
                            [ `Debug; `Str ])
                     [ Runtime_outer; Runtime_passing; Runtime_local ])
              [ 0; 1; 2; 3; 4; 5; 6; 7; 8; 9 ])
       [ `Track; `Debug; `Diagn ]

let entry_rules =
  Hashtbl.of_seq @@ List.to_seq
  @@ List.map (fun ({ ext_point; _ } as r) -> (ext_point, r)) rules

let with_opt_digit ~prefix ~suffix txt =
  String.starts_with ~prefix txt
  && String.ends_with ~suffix txt
  &&
  let plen = String.length prefix in
  let slen = String.length suffix in
  match String.sub txt plen (String.length txt - plen - slen) with
  | "" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9" -> true
  | _ -> false

let get_opt_digit ~prefix ~suffix txt =
  let plen = String.length prefix in
  let slen = String.length suffix in
  match String.sub txt plen (String.length txt - plen - slen) with
  | "" -> None
  | s -> Some (Comptime (int_of_string s))

let traverse_expression =
  object (self)
    inherit [context] Ast_traverse.map_with_context as super

    method! expression context orig_exp =
      let callback context e = self#expression context e in
      let track_cases ?ret_descr ?ret_typ ?arg_typ kind =
        List.mapi (debug_case context callback ?ret_descr ?ret_typ ?arg_typ kind)
      in
      let orig_exp, ret_typ =
        match orig_exp with
        | [%expr ([%e? exp] : [%t? typ])] -> (exp, Some typ)
        | _ -> (orig_exp, None)
      in
      let loc = orig_exp.pexp_loc in
      let ghost_loc = { loc with loc_ghost = true } in
      let log_close = close_log ~loc in
      let exp = orig_exp in
      let log_block_impl ~entry_log_level ~message ~entry =
        check_comptime_log_level context ~is_explicit:true ~is_result:false
          ~log_level:entry_log_level exp
        @@ fun () ->
        let preamble =
          open_log_no_source ~message ~loc ~log_level:entry_log_level
            context.track_or_explicit
        in
        let context = { context with entry_log_level } in
        let entry = callback { context with toplevel_kind = Nested } entry in
        let result =
          let body =
            [%expr
              [%e preamble];
              try
                let __val = [%e entry] in
                [%e log_close];
                __val
              with e ->
                [%e log_close];
                raise e]
          in
          let expr =
            let loc = ghost_loc in
            [%expr Debug_runtime.get_entry_id ()]
          in
          A.pexp_let ~loc Nonrecursive
            [
              A.value_binding ~loc:ghost_loc
                ~pat:(A.pvar ~loc:ghost_loc "__entry_id")
                ~expr;
            ]
            body
        in
        [%expr
          if !Debug_runtime.log_level >= [%e ll_to_expr ~digit_loc:loc entry_log_level]
          then [%e result]]
      in
      let exp =
        match exp.pexp_desc with
        | Pexp_let (rec_flag, bindings, body)
          when context.toplevel_kind <> Nested || not (context.track_or_explicit = `Diagn)
          ->
            let bindings = List.map (debug_binding context callback) bindings in
            {
              exp with
              pexp_desc =
                Pexp_let
                  ( rec_flag,
                    bindings,
                    callback { context with toplevel_kind = Nested } body );
            }
        | Pexp_extension ({ loc = _; txt }, PStr [%str [%e? body]])
          when Hashtbl.mem entry_rules txt ->
            let r = Hashtbl.find entry_rules txt in
            let entry_log_level =
              match r.entry_log_level with
              | None -> context.entry_log_level
              | Some ll -> ll
            in
            self#expression
              {
                context with
                log_value = r.log_value;
                track_or_explicit = r.track_or_explicit;
                toplevel_kind = r.toplevel_kind;
                entry_log_level;
              }
              body
        | Pexp_extension ({ loc = _; txt = "debug_notrace" }, PStr [%str [%e? body]]) ->
            callback
              {
                context with
                track_or_explicit =
                  (if context.track_or_explicit = `Diagn then `Diagn else `Debug);
              }
              body
        | Pexp_extension
            ( { loc = _; txt = "log_level" },
              PStr
                [%str
                  [%e? level];
                  [%e? body]] ) -> (
            let log_level = parse_log_level level in
            let new_context = { context with log_level } in
            match (context.log_level, log_level) with
            | Comptime c_ll, Comptime e_ll when c_ll = e_ll -> callback new_context body
            | _ ->
                [%expr
                  let __old_log_level = !Debug_runtime.log_level in
                  try
                    Debug_runtime.log_level := [%e level];
                    let __res = [%e callback new_context body] in
                    Debug_runtime.log_level := __old_log_level;
                    __res
                  with e ->
                    Debug_runtime.log_level := __old_log_level;
                    raise e])
        | Pexp_extension
            ( { loc = _; txt = "at_log_level" },
              PStr
                [%str
                  [%e? level];
                  [%e? body]] ) ->
            callback { context with entry_log_level = parse_log_level level } body
        | Pexp_extension
            ( { loc = _; txt = "debug_interrupts" },
              PStr
                [%str
                  {
                    max_nesting_depth = [%e? max_nesting_depth];
                    max_num_children = [%e? max_num_children];
                  };
                  [%e? body]] ) ->
            [%expr
              Debug_runtime.max_nesting_depth := Some [%e max_nesting_depth];
              Debug_runtime.max_num_children := Some [%e max_num_children];
              [%e callback { context with interrupts = true } body]]
        | Pexp_extension ({ loc = _; txt = "debug_interrupts" }, PStr [%str [%e? _]]) ->
            A.pexp_extension ~loc
            @@ Location.error_extensionf ~loc
                 "ppx_minidebug: bad syntax, expacted [%%debug_interrupts \
                  {max_nesting_depth=N;max_num_children=M}; <BODY>]"
        | Pexp_extension ({ loc = _; txt = "debug_type_info" }, PStr [%str [%e? body]]) ->
            callback { context with output_type_info = true } body
        | Pexp_extension
            ( { loc = _; txt = "logN" },
              PStr
                [%str
                  [%e? at_log_level];
                  [%e? body]] ) ->
            let typ = extract_type ~alt_typ:ret_typ body in
            let log_level = parse_log_level at_log_level in
            log_value context ~loc ~typ ~is_explicit:true ~is_result:false ~log_level body
        | Pexp_extension ({ loc = _; txt }, PStr [%str [%e? body]])
          when with_opt_digit ~prefix:"log" ~suffix:"" txt ->
            let typ = extract_type ~alt_typ:ret_typ body in
            let log_level =
              Option.value ~default:context.entry_log_level
              @@ get_opt_digit ~prefix:"log" ~suffix:"" txt
            in
            log_value context ~loc ~typ ~is_explicit:true ~is_result:false ~log_level body
        | Pexp_extension
            ( { loc = _; txt = "logN_result" },
              PStr
                [%str
                  [%e? at_log_level];
                  [%e? body]] ) ->
            let typ = extract_type ~alt_typ:ret_typ body in
            let log_level = parse_log_level at_log_level in
            log_value context ~loc ~typ ~is_explicit:true ~is_result:true ~log_level body
        | Pexp_extension ({ loc = _; txt }, PStr [%str [%e? body]])
          when with_opt_digit ~prefix:"log" ~suffix:"_result" txt ->
            let typ = extract_type ~alt_typ:ret_typ body in
            let log_level =
              Option.value ~default:context.entry_log_level
              @@ get_opt_digit ~prefix:"log" ~suffix:"_result" txt
            in
            log_value context ~loc ~typ ~is_explicit:true ~is_result:true ~log_level body
        | Pexp_extension
            ( { loc = _; txt = "logN_printbox" },
              PStr
                [%str
                  [%e? at_log_level];
                  [%e? body]] ) ->
            let log_level = parse_log_level at_log_level in
            log_value_printbox context ~loc ~log_level body
        | Pexp_extension ({ loc = _; txt }, PStr [%str [%e? body]])
          when with_opt_digit ~prefix:"log" ~suffix:"_printbox" txt ->
            let log_level =
              Option.value ~default:context.entry_log_level
              @@ get_opt_digit ~prefix:"log" ~suffix:"_printbox" txt
            in
            log_value_printbox context ~loc ~log_level body
        | Pexp_extension
            ( { loc = _; txt = "logN_block" },
              PStr
                [%str
                  [%e? runtime_log_level] [%e? message];
                  [%e? entry]] ) ->
            let entry_log_level = Runtime runtime_log_level in
            log_block_impl ~entry_log_level ~message ~entry
        | Pexp_extension
            ( { loc = _; txt },
              PStr
                [%str
                  [%e? message];
                  [%e? entry]] )
          when with_opt_digit ~prefix:"log" ~suffix:"_block" txt ->
            let entry_log_level =
              Option.value ~default:context.entry_log_level
              @@ get_opt_digit ~prefix:"log" ~suffix:"_entry" txt
            in
            log_block_impl ~entry_log_level ~message ~entry
        | Pexp_extension ({ loc = _; txt = "log_block" }, PStr [%str [%e? _entry]]) ->
            A.pexp_extension ~loc
            @@ Location.error_extensionf ~loc
                 "ppx_minidebug: bad syntax, expacted [%%log_block <HEADER MESSAGE>; \
                  <BODY>]"
        | Pexp_extension
            ( { loc = _; txt },
              PStr
                [%str
                  [%e? message];
                  [%e? entry]] )
          when with_opt_digit ~prefix:"log" ~suffix:"_entry" txt ->
            if is_comptime_nothing context then
              callback { context with toplevel_kind = Nested } entry
            else
              let entry_log_level =
                Option.value ~default:context.entry_log_level
                @@ get_opt_digit ~prefix:"log" ~suffix:"_entry" txt
              in
              let log_count_before = !global_log_count in
              let preamble =
                open_log_no_source ~message ~loc ~log_level:context.entry_log_level
                  context.track_or_explicit
              in
              let result = A.ppat_var ~loc { loc; txt = "__res" } in
              let context = { context with entry_log_level } in
              let entry = callback { context with toplevel_kind = Nested } entry in
              let log_result = [%expr ()] in
              entry_with_interrupts context ~loc ~message ~log_count_before ~preamble
                ~entry ~result ~log_result ()
        | Pexp_extension ({ loc = _; txt = "log_entry" }, PStr [%str [%e? _entry]]) ->
            A.pexp_extension ~loc
            @@ Location.error_extensionf ~loc
                 "ppx_minidebug: bad syntax, expacted [%%log_entry <HEADER MESSAGE>; \
                  <BODY>]"
        | (Pexp_newtype _ | Pexp_function (_ :: _, _, _))
          when context.toplevel_kind <> Nested || not (context.track_or_explicit = `Diagn)
          ->
            debug_fun context callback ?typ:ret_typ exp
        | Pexp_match ([%expr ([%e? expr] : [%t? arg_typ])], cases)
          when context.track_or_explicit = `Track && (not @@ is_comptime_nothing context)
          ->
            {
              exp with
              pexp_desc =
                Pexp_match
                  (callback context expr, track_cases ~arg_typ ?ret_typ "match" cases);
            }
        | Pexp_match (expr, cases)
          when context.track_or_explicit = `Track && (not @@ is_comptime_nothing context)
          ->
            {
              exp with
              pexp_desc =
                Pexp_match (callback context expr, track_cases ?ret_typ "match" cases);
            }
        | Pexp_function ([], constr, Pfunction_cases (cases, _, _))
          when context.track_or_explicit = `Track && (not @@ is_comptime_nothing context)
          ->
            let arg_typ, ret_typ =
              match ret_typ with
              | Some { ptyp_desc = Ptyp_arrow (_, arg, ret); _ } ->
                  (Some arg, Some (pick ~typ:ret ?alt_typ:(typ_of_constraint constr) ()))
              | _ -> (None, typ_of_constraint constr)
            in
            debug_function context callback ~loc:exp.pexp_loc ?constr ?arg_typ ?ret_typ
              cases
        | Pexp_function ([], constr, Pfunction_cases (cases, _, _))
        (* We need this case to unpack the runtime. *)
          when is_local_debug_runtime context.toplevel_kind
               && (not @@ is_comptime_nothing context) ->
            let arg_typ, ret_typ =
              match ret_typ with
              | Some { ptyp_desc = Ptyp_arrow (_, arg, ret); _ } ->
                  (Some arg, Some (pick ~typ:ret ?alt_typ:(typ_of_constraint constr) ()))
              | _ -> (None, typ_of_constraint constr)
            in
            debug_function context callback ~loc:exp.pexp_loc ?constr ?arg_typ ?ret_typ
              cases
        | Pexp_ifthenelse (if_, then_, else_)
          when context.track_or_explicit = `Track && (not @@ is_comptime_nothing context)
          ->
            let then_ =
              let log_count_before = !global_log_count in
              let loc = then_.pexp_loc in
              let message = "then:" ^ loc_to_name loc in
              let then_ = callback context then_ in
              let then_' =
                let log_open =
                  open_log ~message ~loc ~log_level:context.entry_log_level
                    context.track_or_explicit
                in
                let log_close = close_log ~loc in
                let ghost_loc = { loc with loc_ghost = true } in
                let body =
                  [%expr
                    [%e log_open];
                    match [%e then_] with
                    | if_then__result ->
                        [%e log_close];
                        if_then__result
                    | exception e ->
                        [%e log_close];
                        raise e]
                in
                let expr =
                  let loc = ghost_loc in
                  [%expr Debug_runtime.get_entry_id ()]
                in
                A.pexp_let ~loc Nonrecursive
                  [
                    A.value_binding ~loc:ghost_loc
                      ~pat:(A.pvar ~loc:ghost_loc "__entry_id")
                      ~expr;
                  ]
                  body
              in
              if
                context.track_or_explicit = `Diagn && log_count_before = !global_log_count
              then then_
              else then_'
            in
            let else_ =
              let log_count_before = !global_log_count in
              let else_ = Option.map (callback context) else_ in
              let else_' =
                Option.map
                  (fun else_ ->
                    let loc = else_.pexp_loc in
                    let message = "else:" ^ loc_to_name loc in
                    let log_open =
                      open_log ~message ~loc ~log_level:context.entry_log_level
                        context.track_or_explicit
                    in
                    let log_close = close_log ~loc in
                    let ghost_loc = { loc with loc_ghost = true } in
                    let body =
                      [%expr
                        [%e log_open];
                        match [%e else_] with
                        | if_else__result ->
                            [%e log_close];
                            if_else__result
                        | exception e ->
                            [%e log_close];
                            raise e]
                    in
                    let expr =
                      let loc = ghost_loc in
                      [%expr Debug_runtime.get_entry_id ()]
                    in
                    A.pexp_let ~loc Nonrecursive
                      [
                        A.value_binding ~loc:ghost_loc
                          ~pat:(A.pvar ~loc:ghost_loc "__entry_id")
                          ~expr;
                      ]
                      body)
                  else_
              in
              if
                context.track_or_explicit = `Diagn && log_count_before = !global_log_count
              then else_
              else else_'
            in
            { exp with pexp_desc = Pexp_ifthenelse (callback context if_, then_, else_) }
        | Pexp_for (pat, from, to_, dir, body)
          when context.track_or_explicit = `Track && (not @@ is_comptime_nothing context)
          ->
            let log_count_before = !global_log_count in
            let body =
              let loc = body.pexp_loc in
              let descr_loc = pat2descr ~default:"__for_index" pat in
              let typ =
                A.ptyp_constr ~loc:pat.ppat_loc
                  { txt = Lident "int"; loc = pat.ppat_loc }
                  []
              in
              let preamble =
                open_log
                  ~message:("<for " ^ descr_loc.txt ^ ">")
                  ~loc:descr_loc.loc ~log_level:context.entry_log_level
                  context.track_or_explicit
              in
              let header =
                log_value context ~loc ~typ ~descr_loc ~is_explicit:false ~is_result:false
                  ~log_level:context.entry_log_level (pat2expr pat)
              in
              entry_with_interrupts context ~loc ~descr_loc ~log_count_before ~header
                ~preamble ~entry:(callback context body)
                ~result:[%pat? ()]
                ~log_result:[%expr ()] ()
            in
            let loc = exp.pexp_loc in
            let pexp_desc = Pexp_for (pat, from, to_, dir, body) in
            let message = "for:" ^ loc_to_name loc in
            let transformed =
              let log_open =
                open_log ~message ~loc ~log_level:context.entry_log_level
                  context.track_or_explicit
              in
              let log_close = close_log ~loc in
              let ghost_loc = { loc with loc_ghost = true } in
              let body =
                [%expr
                  [%e log_open];
                  match [%e { exp with pexp_desc }] with
                  | () -> [%e log_close]
                  | exception e ->
                      [%e log_close];
                      raise e]
              in
              let expr =
                let loc = ghost_loc in
                [%expr Debug_runtime.get_entry_id ()]
              in
              A.pexp_let ~loc Nonrecursive
                [
                  A.value_binding ~loc:ghost_loc
                    ~pat:(A.pvar ~loc:ghost_loc "__entry_id")
                    ~expr;
                ]
                body
            in
            if context.track_or_explicit = `Diagn && log_count_before = !global_log_count
            then { exp with pexp_desc }
            else transformed
        | Pexp_while (cond, body)
          when context.track_or_explicit = `Track && (not @@ is_comptime_nothing context)
          ->
            let log_count_before = !global_log_count in
            let message = "while:" ^ loc_to_name loc in
            let body =
              let loc = body.pexp_loc in
              let descr_loc = { txt = "<while body>"; loc } in
              let preamble =
                open_log ~message:"<while loop>" ~loc:descr_loc.loc
                  ~log_level:context.entry_log_level context.track_or_explicit
              in
              entry_with_interrupts context ~loc ~descr_loc ~log_count_before ~preamble
                ~entry:(callback context body)
                ~result:[%pat? ()]
                ~log_result:[%expr ()] ()
            in
            let loc = exp.pexp_loc in
            let pexp_desc = Pexp_while (cond, body) in
            let transformed =
              let log_open =
                open_log ~message ~loc ~log_level:context.entry_log_level
                  context.track_or_explicit
              in
              let log_close = close_log ~loc in
              let ghost_loc = { loc with loc_ghost = true } in
              let body =
                [%expr
                  [%e log_open];
                  match [%e { exp with pexp_desc }] with
                  | () -> [%e log_close]
                  | exception e ->
                      [%e log_close];
                      raise e]
              in
              let expr =
                let loc = ghost_loc in
                [%expr Debug_runtime.get_entry_id ()]
              in
              A.pexp_let ~loc Nonrecursive
                [
                  A.value_binding ~loc:ghost_loc
                    ~pat:(A.pvar ~loc:ghost_loc "__entry_id")
                    ~expr;
                ]
                body
            in
            if context.track_or_explicit = `Diagn && log_count_before = !global_log_count
            then { exp with pexp_desc }
            else transformed
        | _ -> super#expression { context with toplevel_kind = Nested } exp
      in
      let unpacked_runtime, exp =
        match (orig_exp.pexp_desc, context.toplevel_kind) with
        | ( Pexp_let
              ( _,
                [ { pvb_expr = { pexp_desc = Pexp_function _ | Pexp_newtype _; _ }; _ } ],
                _ ),
            _ )
        | Pexp_function _, _
        | Pexp_newtype _, _
        | _, Nested
        | _, Runtime_outer ->
            (false, exp)
        | _ -> (true, unpack_runtime context.toplevel_kind exp)
      in
      let exp =
        match ret_typ with None -> exp | Some typ -> [%expr ([%e exp] : [%t typ])]
      in
      match (unpacked_runtime, context.toplevel_kind) with
      | true, Runtime_passing -> pass_runtime ~always:true context.toplevel_kind exp
      | _ -> exp

    method! structure_item context si =
      (* Do not use for an entry_point, because it ignores the toplevel_opt_arg field! *)
      let callback context e = self#expression context e in
      let nested = { context with toplevel_kind = Nested } in
      match si with
      | { pstr_desc = Pstr_value (rec_flag, bindings); pstr_loc = _; _ } ->
          let bindings = List.map (debug_binding nested callback) bindings in
          { si with pstr_desc = Pstr_value (rec_flag, bindings) }
      | _ -> super#structure_item nested si
  end

let debug_expander context payload =
  let callback context e = traverse_expression#expression context e in
  match payload with
  | { pexp_desc = Pexp_let (recflag, bindings, body); _ } ->
      (* This is the [let%debug_ ... in] toplevel expression: do not debug the whole
         body. *)
      let bindings = List.map (debug_binding context callback) bindings in
      { payload with pexp_desc = Pexp_let (recflag, bindings, body) }
  | expr -> traverse_expression#expression context expr

let str_expander context ~loc payload =
  let callback context e = traverse_expression#expression context e in
  match
    List.map
      (fun si ->
        match si with
        | { pstr_desc = Pstr_value (rec_flag, bindings); pstr_loc = _; _ } ->
            let bindings = List.map (debug_binding context callback) bindings in
            { si with pstr_desc = Pstr_value (rec_flag, bindings) }
        | _ -> traverse_expression#structure_item context si)
      payload
  with
  | [ item ] -> item
  | items ->
      Ast_helper.Str.include_
        {
          pincl_mod = Ast_helper.Mod.structure items;
          pincl_loc = loc;
          pincl_attributes = [];
        }

let global_output_type_info =
  let declaration =
    Extension.V3.declare "global_debug_type_info" Extension.Context.structure_item
      Ast_pattern.(pstr __)
      (fun ~ctxt ->
        let loc = Expansion_context.Extension.extension_point_loc ctxt in
        function
        | [ { pstr_desc = Pstr_eval ([%expr true], attrs); _ } ] ->
            init_context := { !init_context with output_type_info = true };
            A.pstr_eval ~loc [%expr ()] attrs
        | [ { pstr_desc = Pstr_eval ([%expr false], attrs); _ } ] ->
            init_context := { !init_context with output_type_info = false };
            A.pstr_eval ~loc [%expr ()] attrs
        | _ ->
            A.pstr_eval ~loc
              (A.pexp_extension ~loc
              @@ Location.error_extensionf ~loc
                   "ppx_minidebug: bad syntax, expacted [%%%%global_debug_type_info \
                    true] or [%%%%global_debug_type_info false]")
              [])
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
            init_context := { !init_context with interrupts = true };
            A.pstr_eval ~loc
              [%expr
                let module Debug_runtime = (val _get_local_debug_runtime ()) in
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

let global_log_level =
  let declaration =
    Extension.V3.declare "global_debug_log_level" Extension.Context.structure_item
      Ast_pattern.(pstr __)
      (fun ~ctxt ->
        let loc = Expansion_context.Extension.extension_point_loc ctxt in
        function
        | [ { pstr_desc = Pstr_eval (exp, attrs); _ } ] ->
            init_context := { !init_context with log_level = parse_log_level exp };
            A.pstr_eval ~loc [%expr ()] attrs
        | _ ->
            A.pstr_eval ~loc
              (A.pexp_extension ~loc
              @@ Location.error_extensionf ~loc
                   "ppx_minidebug: bad syntax, expacted [%%%%global_debug_log_level \
                    <integer>]")
              [])
  in
  Ppxlib.Context_free.Rule.extension declaration

let global_log_level_from_env_var ~check_consistency =
  let declaration =
    Extension.V3.declare
      (if check_consistency then "global_debug_log_level_from_env_var"
       else "global_debug_log_level_from_env_var_unsafe")
      Extension.Context.structure_item
      Ast_pattern.(pstr __)
      (fun ~ctxt ->
        let loc = Expansion_context.Extension.extension_point_loc ctxt in
        function
        | [
            {
              pstr_desc =
                Pstr_eval
                  ( { pexp_desc = Pexp_constant (Pconst_string (env_n, s_loc, _)); _ },
                    attrs );
              _;
            };
          ] -> (
            let noop = A.pstr_eval ~loc [%expr ()] attrs in
            let update log_level_string comptime_log_level =
              init_context :=
                { !init_context with log_level = Comptime comptime_log_level };
              if check_consistency then
                let lifted_log_level =
                  Ast_helper.Exp.constant ~loc
                  @@ Ast_helper.Const.string ~loc log_level_string
                in
                A.pstr_eval ~loc
                  [%expr
                    try
                      let runtime_log_level =
                        Stdlib.String.lowercase_ascii
                        @@ Stdlib.Sys.getenv
                             [%e
                               Ast_helper.Exp.constant ~loc:s_loc
                               @@ Ast_helper.Const.string ~loc:s_loc env_n]
                      in
                      (* TODO(#53): instead of equality, for verbosity log levels, check
                         that the compile time level is greater-or-equal to the runtime
                         level. *)
                      if
                        (not (Stdlib.String.equal "" runtime_log_level))
                        && not
                             (Stdlib.String.equal [%e lifted_log_level] runtime_log_level)
                      then
                        failwith
                          ("ppx_minidebug: compile-time vs. runtime log level mismatch, \
                            found '" ^ [%e lifted_log_level] ^ "' at compile time, '"
                         ^ runtime_log_level ^ "' at runtime")
                    with Stdlib.Not_found -> ()]
                  attrs
              else noop
            in
            try
              let log_level_string = Sys.getenv env_n in
              if log_level_string = "" then noop
              else
                match int_of_string_opt log_level_string with
                | Some log_level -> update log_level_string log_level
                | None ->
                    A.pstr_eval ~loc
                      (A.pexp_extension ~loc
                      @@ Location.error_extensionf ~loc
                           "environment variable %s should be empty or an integer; \
                            found: %s"
                           env_n log_level_string)
                      attrs
            with Not_found -> noop)
        | _ ->
            A.pstr_eval ~loc
              (A.pexp_extension ~loc
              @@ Location.error_extensionf ~loc
                   "ppx_minidebug: bad syntax, expacted \
                    [%%%%global_debug_log_level_from_env_var \
                    \"string_with_environment_variable_name\"]")
              [])
  in
  Ppxlib.Context_free.Rule.extension declaration

let noop_for_testing =
  Ppxlib.Context_free.Rule.extension
  @@ Extension.declare "ppx_minidebug_noop_for_testing" Extension.Context.expression
       Ast_pattern.(single_expr_payload __)
       (fun ~loc:_ ~path:_ payload -> payload)

let rules =
  noop_for_testing
  :: global_log_level_from_env_var ~check_consistency:true
  :: global_log_level_from_env_var ~check_consistency:false
  :: global_log_level :: global_output_type_info :: global_interrupts
  :: List.map
       (fun {
              ext_point;
              track_or_explicit;
              toplevel_kind;
              expander;
              log_value;
              entry_log_level;
            } ->
         let declaration =
           match expander with
           | `Debug ->
               Extension.V3.declare ext_point Extension.Context.expression
                 Ast_pattern.(single_expr_payload __)
                 (fun ~ctxt:_ ->
                   debug_expander
                     {
                       !init_context with
                       toplevel_kind;
                       track_or_explicit;
                       entry_log_level =
                         Option.value entry_log_level ~default:(Comptime 1);
                       log_value;
                     })
           | `Str ->
               Extension.V3.declare ext_point Extension.Context.structure_item
                 Ast_pattern.(pstr __)
                 (fun ~ctxt ->
                   str_expander
                     {
                       !init_context with
                       toplevel_kind;
                       track_or_explicit;
                       entry_log_level =
                         Option.value entry_log_level ~default:(Comptime 1);
                       log_value;
                     }
                     ~loc:(Expansion_context.Extension.extension_point_loc ctxt))
         in
         Ppxlib.Context_free.Rule.extension declaration)
       rules

let () = Driver.register_transformation ~rules "ppx_minidebug"
