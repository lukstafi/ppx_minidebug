open Ppxlib
module A = Ast_builder.Default
(* module H = Ast_helper *)

type log_value = Sexp | Show | Pp

type log_level =
  | Nothing
  | Prefixed of string array
  | Prefixed_or_result of string array
  | Nonempty_entries
  | Everything

let no_results = function Nothing | Prefixed _ -> true | _ -> false
let is_prefixed_or_result = function Prefixed_or_result _ -> true | _ -> false

type toplevel_opt_arg = Nested | Toplevel_no_arg | Generic | PrintBox

let global_log_count = ref 0

type context = {
  log_value : log_value;
  track_branches : bool;
  output_type_info : bool;
  interrupts : bool;
  log_level : log_level;
  toplevel_opt_arg : toplevel_opt_arg;
}

let init_context =
  ref
    {
      log_value = Sexp;
      track_branches = false;
      output_type_info = false;
      interrupts = false;
      log_level = Everything;
      toplevel_opt_arg = Toplevel_no_arg;
    }

let parse_log_level ll =
  let exception Error of expression in
  let parse_prefixes exp =
    match exp.pexp_desc with
    | Pexp_array ps ->
        Array.of_list
        @@ List.map
             (function
               | { pexp_desc = Pexp_constant (Pconst_string (s, _, _)); _ } -> s
               | p ->
                   let loc = p.pexp_loc in
                   raise
                   @@ Error
                        (A.pexp_extension ~loc
                        @@ Location.error_extensionf ~loc
                             "ppx_minidebug: expected a string literal with a log level \
                              prefix"))
             ps
    | _ ->
        let loc = exp.pexp_loc in
        raise
        @@ Error
             (A.pexp_extension ~loc
             @@ Location.error_extensionf ~loc
                  "ppx_minidebug: expected an array literal with log level prefixes")
  in
  match ll with
  | [%expr Nothing] -> Either.Left Nothing
  | [%expr Prefixed [%e? prefixes]] -> (
      try Left (Prefixed (parse_prefixes prefixes)) with Error e -> Right e)
  | [%expr Prefixed_or_result [%e? prefixes]] -> (
      try Left (Prefixed_or_result (parse_prefixes prefixes)) with Error e -> Right e)
  | [%expr Nonempty_entries] -> Left Nonempty_entries
  | [%expr Everything] -> Left Everything
  | _ ->
      let loc = ll.pexp_loc in
      Right
        (A.pexp_extension ~loc
        @@ Location.error_extensionf ~loc
             "ppx_minidebug: expected one of: Nothing, Prefixed [|...|], \
              Prefixed_or_result [|...|], Nonempty_entries, Everything")

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

let open_log ?(message = "") ~loc () =
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
        ~message:[%e A.estring ~loc message] ~entry_id:__entry_id]

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

let check_prefix prefixes exp =
  let rec loop = function
    | { pexp_desc = Pexp_tuple (exp :: _); _ }
    | [%expr [%e? exp] :: [%e? _]]
    | { pexp_desc = Pexp_array (exp :: _); _ } ->
        loop exp
    | { pexp_desc = Pexp_constant (Pconst_string (s, _, _)); _ } ->
        Array.exists (fun prefix -> String.starts_with ~prefix s) prefixes
    | _ -> false
  in
  loop exp

let check_log_level context ~is_explicit ~is_result exp thunk =
  let loc = exp.pexp_loc in
  match context.log_level with
  | Nothing -> [%expr ()]
  | Prefixed [||] -> if is_explicit then thunk () else [%expr ()]
  | Prefixed_or_result [||] -> if is_explicit || is_result then thunk () else [%expr ()]
  | Prefixed prefixes when not (check_prefix prefixes exp) -> [%expr ()]
  | Prefixed_or_result prefixes when not (is_result || check_prefix prefixes exp) ->
      [%expr ()]
  | _ -> thunk ()

(* *** The sexplib-based variant. *** *)
let log_value_sexp context ~loc ~typ ?descr_loc ~is_explicit ~is_result exp =
  check_log_level context ~is_explicit ~is_result exp @@ fun () ->
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
      (* [%sexp_of: typ] does not work with `Ptyp_poly`. Misleading error "Let with no bindings". *)
      incr global_log_count;
      [%expr
        Debug_runtime.log_value_sexp
          ?descr:[%e to_descr context ~loc ~descr_loc typ]
          ~entry_id:__entry_id ~is_result:[%e A.ebool ~loc is_result]
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

let log_value_pp context ~loc ~typ ?descr_loc ~is_explicit ~is_result exp =
  check_log_level context ~is_explicit ~is_result exp @@ fun () ->
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
          ~entry_id:__entry_id ~pp:[%e converter] ~is_result:[%e A.ebool ~loc is_result]
          [%e exp]]
  | _ ->
      A.pexp_extension ~loc
      @@ Location.error_extensionf ~loc
           "ppx_minidebug: cannot find a concrete type to _pp log this value: try _show \
            or _sexp"

(* *** The deriving.show string-based variant. *** *)
let log_value_show context ~loc ~typ ?descr_loc ~is_explicit ~is_result exp =
  check_log_level context ~is_explicit ~is_result exp @@ fun () ->
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
          ~entry_id:__entry_id ~is_result:[%e A.ebool ~loc is_result]
          ([%show: [%t typ]] [%e exp])]

let log_value context =
  match context.log_value with
  | Sexp -> log_value_sexp context
  | Show -> log_value_show context
  | Pp -> log_value_pp context

(* *** The sexplib-based variant. *** *)
let log_value_printbox context ~loc exp =
  check_log_level context ~is_explicit:true ~is_result:false exp @@ fun () ->
  incr global_log_count;
  [%expr Debug_runtime.log_value_printbox ~entry_id:__entry_id [%e exp]]

let log_string ~loc ~descr_loc s =
  if String.contains descr_loc.txt '\n' then
    A.pexp_extension ~loc
    @@ Location.error_extensionf ~loc
         {|ppx_minidebug: unexpected multiline internal message: "%s"|} descr_loc.txt
  else
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
      pexp_desc = Pexp_fun (arg_label, default, pat, body);
      pexp_loc;
      pexp_loc_stack;
      pexp_attributes;
    } ->
      collect_fun
        (Pexp_fun_arg (arg_label, default, pat, pexp_loc, pexp_loc_stack, pexp_attributes)
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
  | Ptyp_extension _ -> alt_or_typ
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

let entry_with_interrupts context ~loc ~descr_loc ~log_count_before ?header ~preamble
    ~entry ~result ~log_result () =
  if context.log_level <> Everything && log_count_before = !global_log_count then entry
  else
    let header = match header with Some h -> h | None -> [%expr ()] in
    if context.interrupts then
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

let debug_body context callback ~loc ~message ~descr_loc ~log_count_before ~arg_logs typ
    body =
  let message =
    match typ with
    | Some t when context.output_type_info -> message ^ " : " ^ typ2str t
    | _ -> message
  in
  let preamble = open_log ~message ~loc () in
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
    | Some typ ->
        log_value context ~loc ~typ ~descr_loc ~is_explicit:false ~is_result:true
          (pat2expr result)
  in
  entry_with_interrupts context ~loc ~descr_loc ~log_count_before ~preamble
    ~entry:(callback context body) ~result ~log_result ()

let rec collect_fun_typs arg_typs typ =
  match typ.ptyp_desc with
  | Ptyp_alias (typ, _) | Ptyp_poly (_, typ) -> collect_fun_typs arg_typs typ
  | Ptyp_arrow (_, arg_typ, typ) -> collect_fun_typs (arg_typ :: arg_typs) typ
  | _ -> (List.rev arg_typs, typ)

let pass_runtime toplevel_opt_arg exp =
  let loc = exp.pexp_loc in
  (* Only pass runtime to functions. *)
  match (toplevel_opt_arg, exp) with
  | Generic, { pexp_desc = Pexp_newtype _ | Pexp_fun _ | Pexp_function _; _ } ->
      [%expr fun (_debug_runtime : (module Minidebug_runtime.Debug_runtime)) -> [%e exp]]
  | PrintBox, { pexp_desc = Pexp_newtype _ | Pexp_fun _ | Pexp_function _; _ } ->
      [%expr
        fun (_debug_runtime : (module Minidebug_runtime.PrintBox_runtime)) -> [%e exp]]
  | _ -> exp

let unpack_runtime toplevel_opt_arg exp =
  let loc = exp.pexp_loc in
  match toplevel_opt_arg with
  | Nested | Toplevel_no_arg -> exp
  | Generic | PrintBox ->
      [%expr
        let module Debug_runtime = (val _debug_runtime) in
        [%e exp]]

let has_runtime_arg = function
  | { toplevel_opt_arg = Nested | Toplevel_no_arg; _ } -> false
  | _ -> true

let loc_to_name loc =
  let fname = Filename.basename loc.loc_start.pos_fname |> Filename.remove_extension in
  fname ^ ":" ^ Int.to_string loc.loc_start.pos_lnum

let debug_fun context callback ?typ ?ret_descr ?ret_typ exp =
  let log_count_before = !global_log_count in
  let args, body, ret_typ2 = collect_fun [] exp in
  let nested = { context with toplevel_opt_arg = Nested } in
  let no_change_exp () =
    let body = callback nested body in
    let body =
      match ret_typ2 with
      | Some typ ->
          let loc = body.pexp_loc in
          [%expr ([%e body] : [%t typ])]
      | None -> body
    in
    pass_runtime context.toplevel_opt_arg @@ expand_fun body args
  in
  if context.log_level = Nothing then no_change_exp ()
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
      (not context.track_branches)
      && (context.toplevel_opt_arg = Nested || ret_descr = None)
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
            Pexp_fun_arg
              (_arg_label, _opt_val, pat, pexp_loc, _pexp_loc_stack, _pexp_attributes)
            :: args ) ->
            let _, bound = bound_patterns ~alt_typ:(Some alt_typ) pat in
            List.map
              (fun (descr_loc, pat, typ) ->
                log_value context ~loc:pexp_loc ~typ ~descr_loc ~is_explicit:false
                  ~is_result:false (pat2expr pat))
              bound
            @ arg_log (arg_typs, args)
        | ( [],
            Pexp_fun_arg
              (_arg_label, _opt_val, pat, pexp_loc, _pexp_loc_stack, _pexp_attributes)
            :: args ) ->
            let _, bound = bound_patterns ~alt_typ:None pat in
            List.map
              (fun (descr_loc, pat, typ) ->
                log_value context ~loc:pexp_loc ~typ ~descr_loc ~is_explicit:false
                  ~is_result:false (pat2expr pat))
              bound
            @ arg_log ([], args)
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
      let exp = expand_fun (unpack_runtime context.toplevel_opt_arg body) args in
      pass_runtime context.toplevel_opt_arg exp

let debug_case context callback ?ret_descr ?ret_typ ?arg_typ kind i
    { pc_lhs; pc_guard; pc_rhs } =
  let log_count_before = !global_log_count in
  let pc_guard = Option.map (callback context) pc_guard in
  let loc = pc_lhs.ppat_loc in
  let _, bound = bound_patterns ~alt_typ:arg_typ pc_lhs in
  let arg_logs =
    List.map
      (fun (descr_loc, pat, typ) ->
        log_value context ~loc ~typ ~descr_loc ~is_explicit:false ~is_result:false
          (pat2expr pat))
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
  { pc_lhs; pc_guard; pc_rhs }

let debug_function context callback ~loc ?ret_descr ?ret_typ ?arg_typ cases =
  let nested = { context with toplevel_opt_arg = Nested } in
  let exp =
    A.pexp_function ~loc
      (List.mapi
         (debug_case nested callback ?ret_descr ?ret_typ ?arg_typ "function")
         cases)
  in
  match context.toplevel_opt_arg with
  | Nested | Toplevel_no_arg -> exp
  | Generic ->
      [%expr
        fun (_debug_runtime : (module Minidebug_runtime.Debug_runtime)) ->
          let module Debug_runtime = (val _debug_runtime) in
          [%e exp]]
  | PrintBox ->
      [%expr
        fun (_debug_runtime : (module Minidebug_runtime.PrintBox_runtime)) ->
          let module Debug_runtime = (val _debug_runtime) in
          [%e exp]]

let debug_binding context callback vb =
  let nested = { context with toplevel_opt_arg = Nested } in
  let pvb_pat =
    (* FIXME(#18): restoring a modified type constraint breaks typing. *)
    match (vb.pvb_pat, context.toplevel_opt_arg) with
    | [%pat? ([%p? pat] : [%t? _typ])], Generic ->
        pat
        (* [%pat? ([%p pat] : (module Minidebug_runtime.Debug_runtime) -> [%t typ])] *)
    | [%pat? ([%p? pat] : [%t? _typ])], PrintBox ->
        pat
        (* [%pat? ([%p pat] : (module Minidebug_runtime.PrintBox_runtime) -> [%t typ])] *)
    | _ -> vb.pvb_pat
  in
  if context.log_level = Nothing then
    {
      vb with
      pvb_pat;
      pvb_expr = pass_runtime context.toplevel_opt_arg @@ callback nested vb.pvb_expr;
    }
  else
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
          (* [debug_fun] handles the runtime passing configuration. *)
          debug_fun context callback ?typ ?ret_descr exp
      | { pexp_desc = Pexp_function cases; _ } ->
          debug_function context callback ~loc:vb.pvb_expr.pexp_loc ?ret_descr ?ret_typ
            ?arg_typ cases
      | _ when context.toplevel_opt_arg = Nested && no_results context.log_level ->
          callback nested exp
      | _ ->
          let result, bound = bound_patterns ~alt_typ:typ pat in
          if bound = [] && context.toplevel_opt_arg = Nested then callback nested exp
          else
            let log_count_before = !global_log_count in
            let descr_loc = pat2descr ~default:"__val" pat in
            let log_result =
              List.map
                (fun (descr_loc, pat, typ) ->
                  log_value context ~loc:vb.pvb_expr.pexp_loc ~typ ~descr_loc
                    ~is_explicit:false ~is_result:true (pat2expr pat))
                bound
              |> List.fold_left
                   (fun e1 e2 ->
                     [%expr
                       [%e e1];
                       [%e e2]])
                   [%expr ()]
            in
            let preamble =
              open_log ~message:descr_loc.txt ~loc:descr_loc.loc ()
            in
            entry_with_interrupts context ~loc ~descr_loc ~log_count_before ~preamble
              ~entry:(callback nested exp) ~result ~log_result ()
    in
    let pvb_expr =
      match (typ2, context.toplevel_opt_arg) with
      | None, (Nested | Toplevel_no_arg) -> exp
      | Some typ, (Nested | Toplevel_no_arg) -> [%expr ([%e exp] : [%t typ])]
      | Some typ, Generic ->
          [%expr ([%e exp] : (module Minidebug_runtime.Debug_runtime) -> [%t typ])]
      | Some typ, PrintBox ->
          [%expr ([%e exp] : (module Minidebug_runtime.PrintBox_runtime) -> [%t typ])]
      | None, Generic ->
          [%expr ([%e exp] : (module Minidebug_runtime.Debug_runtime) -> _)]
      | None, PrintBox ->
          [%expr ([%e exp] : (module Minidebug_runtime.PrintBox_runtime) -> _)]
    in
    { vb with pvb_expr; pvb_pat }

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
    | Some { ptyp_desc = Ptyp_any | Ptyp_var _ | Ptyp_extension _; _ }, _ ->
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
  track_branches : bool;
  toplevel_opt_arg : toplevel_opt_arg;
  expander : [ `Debug | `Debug_this | `Str ];
  restrict_to_explicit : bool;
  log_value : log_value;
}

let rules =
  List.concat
  @@ List.map
       (fun track_or_explicit ->
         List.concat
         @@ List.map
              (fun toplevel_opt_arg ->
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
                             match expander with
                             | `Debug_this -> "_this"
                             | `Debug | `Str -> ""
                           in
                           let ext_point =
                             match toplevel_opt_arg with
                             | Nested -> assert false
                             | Toplevel_no_arg -> ext_point
                             | Generic -> ext_point ^ "_rt"
                             | PrintBox -> ext_point ^ "_rtb"
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
                             track_branches = track_or_explicit = `Track;
                             toplevel_opt_arg;
                             expander;
                             restrict_to_explicit = track_or_explicit = `Diagn;
                             log_value;
                           })
                         [ Pp; Sexp; Show ])
                     [ `Debug; `Debug_this; `Str ])
              [ Toplevel_no_arg; Generic; PrintBox ])
       [ `Track; `Debug; `Diagn ]

let is_ext_point =
  let points = List.map (fun r -> Re.str r.ext_point) rules in
  let regex = Re.(compile @@ seq [ start; alt points; stop ]) in
  Re.execp regex

let traverse_expression =
  object (self)
    inherit [context] Ast_traverse.map_with_context as super

    method! expression context exp =
      let callback context e = self#expression context e in
      let restrict_to_explicit =
        match context.log_level with Nothing | Prefixed _ -> true | _ -> false
      in
      let track_cases ?ret_descr ?ret_typ ?arg_typ kind =
        List.mapi (debug_case context callback ?ret_descr ?ret_typ ?arg_typ kind)
      in
      let exp, ret_typ =
        match exp with
        | [%expr ([%e? exp] : [%t? typ])] -> (exp, Some typ)
        | _ -> (exp, None)
      in
      let loc = exp.pexp_loc in
      let exp =
        match exp.pexp_desc with
        | Pexp_let (rec_flag, bindings, body)
          when context.toplevel_opt_arg <> Nested || not restrict_to_explicit ->
            let bindings = List.map (debug_binding context callback) bindings in
            {
              exp with
              pexp_desc =
                Pexp_let
                  ( rec_flag,
                    bindings,
                    callback { context with toplevel_opt_arg = Nested } body );
            }
        | Pexp_extension ({ loc = _; txt }, PStr [%str [%e? body]]) when is_ext_point txt
          ->
            let prefix_pos = String.index txt '_' in
            let track_branches, log_level =
              match (String.sub txt 0 prefix_pos, context.log_level) with
              | "debug", _ -> (false, context.log_level)
              | "track", _ -> (true, context.log_level)
              | "diagn", Nothing -> (false, Nothing)
              | "diagn", Prefixed prefixes | "diagn", Prefixed_or_result prefixes ->
                  (false, Prefixed prefixes)
              | "diagn", _ -> (false, Prefixed [||])
              | _ -> (context.track_branches, context.log_level)
            in
            let suffix_pos = String.rindex txt '_' in
            let log_value =
              match String.sub txt suffix_pos (String.length txt - suffix_pos) with
              | "_pp" -> Pp
              | "_show" -> Show
              | "_sexp" -> Sexp
              | _ -> context.log_value
            in
            let toplevel_opt_arg =
              if String.length txt > 9 && String.sub txt 5 4 = "_rt_" then Generic
              else if String.length txt > 10 && String.sub txt 5 5 = "_rtb_" then PrintBox
              else Toplevel_no_arg
            in
            self#expression
              { context with log_value; track_branches; toplevel_opt_arg; log_level }
              body
        | Pexp_extension ({ loc = _; txt = "debug_notrace" }, PStr [%str [%e? body]]) ->
            callback { context with track_branches = false } body
        | Pexp_extension
            ( { loc = _; txt = "log_level" },
              PStr
                [%str
                  [%e? level];
                  [%e? body]] ) -> (
            match parse_log_level level with
            | Right error -> error
            | Left log_level -> callback { context with log_level } body)
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
        | Pexp_extension ({ loc = _; txt = "log" }, PStr [%str [%e? body]]) ->
            let typ = extract_type ~alt_typ:ret_typ body in
            log_value context ~loc ~typ ~is_explicit:true ~is_result:false body
        | Pexp_extension ({ loc = _; txt = "log_result" }, PStr [%str [%e? body]]) ->
            let typ = extract_type ~alt_typ:ret_typ body in
            log_value context ~loc ~typ ~is_explicit:true ~is_result:true body
        | Pexp_extension ({ loc = _; txt = "log_printbox" }, PStr [%str [%e? body]]) ->
            log_value_printbox context ~loc body
        | (Pexp_newtype _ | Pexp_fun _)
          when context.toplevel_opt_arg <> Nested || not restrict_to_explicit ->
            debug_fun context callback ?typ:ret_typ exp
        | Pexp_match ([%expr ([%e? expr] : [%t? arg_typ])], cases)
          when context.track_branches && context.log_level <> Nothing ->
            {
              exp with
              pexp_desc =
                Pexp_match
                  (callback context expr, track_cases ~arg_typ ?ret_typ "match" cases);
            }
        | Pexp_match (expr, cases)
          when context.track_branches && context.log_level <> Nothing ->
            {
              exp with
              pexp_desc =
                Pexp_match (callback context expr, track_cases ?ret_typ "match" cases);
            }
        | Pexp_function cases when context.track_branches && context.log_level <> Nothing
          ->
            let arg_typ, ret_typ =
              match ret_typ with
              | Some { ptyp_desc = Ptyp_arrow (_, arg, ret); _ } -> (Some arg, Some ret)
              | _ -> (None, None)
            in
            debug_function context callback ~loc:exp.pexp_loc ?arg_typ ?ret_typ cases
        | Pexp_ifthenelse (if_, then_, else_)
          when context.track_branches && context.log_level <> Nothing ->
            let then_ =
              let log_count_before = !global_log_count in
              let loc = then_.pexp_loc in
              let message = "then:" ^ loc_to_name loc in
              let then_ = callback context then_ in
              let then_' =
                [%expr
                  let __entry_id = Debug_runtime.get_entry_id () in
                  [%e open_log ~message ~loc ()];
                  match [%e then_] with
                  | if_then__result ->
                      Debug_runtime.close_log ();
                      if_then__result
                  | exception e ->
                      Debug_runtime.close_log ();
                      raise e]
              in
              if context.log_level <> Everything && log_count_before = !global_log_count
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
                    [%expr
                      let __entry_id = Debug_runtime.get_entry_id () in
                      [%e open_log ~message ~loc ()];
                      match [%e else_] with
                      | if_else__result ->
                          Debug_runtime.close_log ();
                          if_else__result
                      | exception e ->
                          Debug_runtime.close_log ();
                          raise e])
                  else_
              in
              if context.log_level <> Everything && log_count_before = !global_log_count
              then else_
              else else_'
            in
            { exp with pexp_desc = Pexp_ifthenelse (callback context if_, then_, else_) }
        | Pexp_for (pat, from, to_, dir, body)
          when context.track_branches && context.log_level <> Nothing ->
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
                  ~loc:descr_loc.loc ()
              in
              let header =
                log_value context ~loc ~typ ~descr_loc ~is_explicit:false ~is_result:false
                  (pat2expr pat)
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
              [%expr
                let __entry_id = Debug_runtime.get_entry_id () in
                [%e open_log ~message ~loc ()];
                match [%e { exp with pexp_desc }] with
                | () -> Debug_runtime.close_log ()
                | exception e ->
                    Debug_runtime.close_log ();
                    raise e]
            in
            if context.log_level <> Everything && log_count_before = !global_log_count
            then { exp with pexp_desc }
            else transformed
        | Pexp_while (cond, body)
          when context.track_branches && context.log_level <> Nothing ->
            let log_count_before = !global_log_count in
            let message = "while:" ^ loc_to_name loc in
            let body =
              let loc = body.pexp_loc in
              let descr_loc = { txt = "<while body>"; loc } in
              let preamble =
                open_log ~message:"<while loop>" ~loc:descr_loc.loc
                  ()
              in
              entry_with_interrupts context ~loc ~descr_loc ~log_count_before ~preamble
                ~entry:(callback context body)
                ~result:[%pat? ()]
                ~log_result:[%expr ()] ()
            in
            let loc = exp.pexp_loc in
            let pexp_desc = Pexp_while (cond, body) in
            let transformed =
              [%expr
                let __entry_id = Debug_runtime.get_entry_id () in
                [%e open_log ~message ~loc ()];
                match [%e { exp with pexp_desc }] with
                | () -> Debug_runtime.close_log ()
                | exception e ->
                    Debug_runtime.close_log ();
                    raise e]
            in
            if context.log_level <> Everything && log_count_before = !global_log_count
            then { exp with pexp_desc }
            else transformed
        | _ -> super#expression { context with toplevel_opt_arg = Nested } exp
      in
      match ret_typ with None -> exp | Some typ -> [%expr ([%e exp] : [%t typ])]

    method! structure_item context si =
      (* Do not use for an entry_point, because it ignores the toplevel_opt_arg field! *)
      let callback context e = self#expression context e in
      let nested = { context with toplevel_opt_arg = Nested } in
      match si with
      | { pstr_desc = Pstr_value (rec_flag, bindings); pstr_loc = _; _ } ->
          let bindings = List.map (debug_binding nested callback) bindings in
          { si with pstr_desc = Pstr_value (rec_flag, bindings) }
      | _ -> super#structure_item nested si
  end

let debug_this_expander context payload =
  let callback context e = traverse_expression#expression context e in
  match payload with
  | { pexp_desc = Pexp_let (recflag, bindings, body); _ } ->
      (* This is the [let%debug_this ... in] use-case: do not debug the whole body. *)
      let bindings = List.map (debug_binding context callback) bindings in
      { payload with pexp_desc = Pexp_let (recflag, bindings, body) }
  | expr -> expr

let debug_expander context payload = traverse_expression#expression context payload

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
        | [ { pstr_desc = Pstr_eval (exp, attrs); _ } ] -> (
            match parse_log_level exp with
            | Left log_level ->
                init_context := { !init_context with log_level };
                A.pstr_eval ~loc [%expr ()] attrs
            | Right error -> A.pstr_eval ~loc error attrs)
        | _ ->
            A.pstr_eval ~loc
              (A.pexp_extension ~loc
              @@ Location.error_extensionf ~loc
                   "ppx_minidebug: bad syntax, expacted [%%%%global_debug_log_level \
                    Level]")
              [])
  in
  Ppxlib.Context_free.Rule.extension declaration

let global_log_level_from_env_var =
  let declaration =
    Extension.V3.declare "global_debug_log_level_from_env_var"
      Extension.Context.structure_item
      Ast_pattern.(pstr __)
      (fun ~ctxt ->
        let loc = Expansion_context.Extension.extension_point_loc ctxt in
        function
        | [
            {
              pstr_desc =
                Pstr_eval
                  ( { pexp_desc = Pexp_constant (Pconst_string (env_n, _s_loc, _)); _ },
                    attrs );
              _;
            };
          ] -> (
            let noop = A.pstr_eval ~loc [%expr ()] attrs in
            let update log_level =
              init_context := { !init_context with log_level };
              noop
            in
            match String.lowercase_ascii @@ Sys.getenv env_n with
            | "nothing" -> update Nothing
            | "prefixed_error" -> update @@ Prefixed [| "ERROR" |]
            | "prefixed_warn_error" -> update @@ Prefixed [| "WARN"; "ERROR" |]
            | "prefixed_info_warn_error" ->
                update @@ Prefixed [| "INFO"; "WARN"; "ERROR" |]
            | "explicit_logs" -> update @@ Prefixed [||]
            | "nonempty_entries" -> update @@ Nonempty_entries
            | "everything" -> update @@ Everything
            | "" -> noop
            | s ->
                A.pstr_eval ~loc
                  (A.pexp_extension ~loc
                  @@ Location.error_extensionf ~loc
                       "environment variable %s setting should be empty or one of: \
                        nothing, prefixed_error, prefixed_warn_error, \
                        prefixed_info_warn_error, explicit_logs, nonempty_entries, \
                        everything; found: %s"
                       env_n s)
                  attrs
            | exception Not_found -> noop)
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
  noop_for_testing :: global_log_level_from_env_var :: global_log_level
  :: global_output_type_info :: global_interrupts
  :: List.map
       (fun {
              ext_point;
              track_branches;
              toplevel_opt_arg;
              expander;
              restrict_to_explicit;
              log_value;
            } ->
         let declaration =
           match expander with
           | `Debug ->
               Extension.V3.declare ext_point Extension.Context.expression
                 Ast_pattern.(single_expr_payload __)
                 (fun ~ctxt:_ ->
                   let log_level =
                     match (restrict_to_explicit, !init_context.log_level) with
                     | _, Nothing -> Nothing
                     | true, Prefixed prefixes | true, Prefixed_or_result prefixes ->
                         Prefixed prefixes
                     | true, _ -> Prefixed [||]
                     | false, level -> level
                   in
                   debug_expander
                     {
                       !init_context with
                       toplevel_opt_arg;
                       track_branches;
                       log_level;
                       log_value;
                     })
           | `Debug_this ->
               Extension.V3.declare ext_point Extension.Context.expression
                 Ast_pattern.(single_expr_payload __)
                 (fun ~ctxt:_ ->
                   let log_level =
                     if restrict_to_explicit && !init_context.log_level <> Nothing then
                       Prefixed [||]
                     else !init_context.log_level
                   in
                   debug_this_expander
                     {
                       !init_context with
                       toplevel_opt_arg;
                       track_branches;
                       log_level;
                       log_value;
                     })
           | `Str ->
               Extension.V3.declare ext_point Extension.Context.structure_item
                 Ast_pattern.(pstr __)
                 (fun ~ctxt ->
                   let log_level =
                     if restrict_to_explicit && !init_context.log_level <> Nothing then
                       Prefixed [||]
                     else !init_context.log_level
                   in
                   str_expander
                     {
                       !init_context with
                       toplevel_opt_arg;
                       track_branches;
                       log_level;
                       log_value;
                     }
                     ~loc:(Expansion_context.Extension.extension_point_loc ctxt))
         in
         Ppxlib.Context_free.Rule.extension declaration)
       rules

let () = Driver.register_transformation ~rules "ppx_minidebug"
