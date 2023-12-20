open Ppxlib
module A = Ast_builder.Default

let rec pat2expr pat =
  let loc = pat.ppat_loc in
  match pat.ppat_desc with
  | Ppat_constraint (pat', typ) ->
      Ast_builder.Default.pexp_constraint ~loc (pat2expr pat') typ
  | Ppat_alias (_, ident) | Ppat_var ident ->
      Ast_builder.Default.pexp_ident ~loc { ident with txt = Lident ident.txt }
  | _ ->
      Ast_builder.Default.pexp_extension ~loc
      @@ Location.error_extensionf ~loc
           "ppx_minidebug requires a pattern identifier here: try using an `as` alias."

let rec pat2pat_res pat =
  let loc = pat.ppat_loc in
  match pat.ppat_desc with
  | Ppat_constraint (pat', _) -> pat2pat_res pat'
  | Ppat_alias (_, ident) | Ppat_var ident ->
      Ast_builder.Default.ppat_var ~loc { ident with txt = ident.txt ^ "__res" }
  | _ ->
      Ast_builder.Default.ppat_extension ~loc
      @@ Location.error_extensionf ~loc
           "ppx_minidebug requires a pattern identifier here: try using an `as` alias."

let open_log_preamble ?(brief = false) ?(message = "") ~loc () =
  if brief then
    [%expr
      Debug_runtime.open_log_preamble_brief
        ~fname:[%e A.estring ~loc loc.loc_start.pos_fname]
        ~pos_lnum:[%e A.eint ~loc loc.loc_start.pos_lnum]
        ~pos_colnum:[%e A.eint ~loc (loc.loc_start.pos_cnum - loc.loc_start.pos_bol)]
        ~message:[%e A.estring ~loc message]]
  else
    [%expr
      Debug_runtime.open_log_preamble_full
        ~fname:[%e A.estring ~loc loc.loc_start.pos_fname]
        ~start_lnum:[%e A.eint ~loc loc.loc_start.pos_lnum]
        ~start_colnum:[%e A.eint ~loc (loc.loc_start.pos_cnum - loc.loc_start.pos_bol)]
        ~end_lnum:[%e A.eint ~loc loc.loc_end.pos_lnum]
        ~end_colnum:[%e A.eint ~loc (loc.loc_end.pos_cnum - loc.loc_end.pos_bol)]
        ~message:[%e A.estring ~loc message]]

exception Not_transforming

(* *** The sexplib-based variant. *** *)
let log_value_sexp ~loc ~typ ~descr_loc exp =
  (* [%sexp_of: typ] does not work with `Ptyp_poly`. Misleading error "Let with no bindings". *)
  let typ =
    match typ with { ptyp_desc = Ptyp_poly (_, ctyp); _ } -> ctyp | ctyp -> ctyp
  in
  [%expr
    Debug_runtime.log_value_sexp
      ~descr:[%e A.estring ~loc:descr_loc.loc descr_loc.txt]
      ~sexp:([%sexp_of: [%t typ]] [%e exp])]

(* *** The deriving.show pp-based variant. *** *)
let rec splice_lident ~id_prefix ident =
  let splice id =
    if String.equal id_prefix "pp_" && String.equal id "t" then "pp" else id_prefix ^ id
  in
  match ident with
  | Lident id -> Lident (splice id)
  | Ldot (path, id) -> Ldot (path, splice id)
  | Lapply (f, a) -> Lapply (splice_lident ~id_prefix f, a)

let log_value_pp ~loc ~typ ~descr_loc exp =
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
    Debug_runtime.log_value_pp
      ~descr:[%e A.estring ~loc:descr_loc.loc descr_loc.txt]
      ~pp:[%e converter] ~v:[%e exp]]

(* *** The deriving.show string-based variant. *** *)
let log_value_show ~loc ~typ ~descr_loc exp =
  (* Defensive (TODO: check it doesn't work with Ptyp_poly). *)
  let typ =
    match typ with { ptyp_desc = Ptyp_poly (_, ctyp); _ } -> ctyp | ctyp -> ctyp
  in
  [%expr
    Debug_runtime.log_value_show
      ~descr:[%e A.estring ~loc:descr_loc.loc descr_loc.txt]
      ~v:([%show: [%t typ]] [%e exp])]

let log_value = ref log_value_sexp

let log_string ~loc ~descr_loc s =
  [%expr
    Debug_runtime.log_value_show
      ~descr:[%e A.estring ~loc:descr_loc.loc descr_loc.txt]
      ~v:[%e A.estring ~loc s]]

let rec collect_fun accu = function
  | {
      pexp_desc = Pexp_fun (arg_label, arg, opt_val, body);
      pexp_loc;
      pexp_loc_stack;
      pexp_attributes;
    } ->
      collect_fun
        ((arg_label, arg, opt_val, pexp_loc, pexp_loc_stack, pexp_attributes) :: accu)
        body
  | [%expr ([%e? body] : [%t? typ])] -> (List.rev accu, body, Some typ)
  | body -> (List.rev accu, body, None)

let rec expand_fun body = function
  | [] -> body
  | (arg_label, arg, opt_val, pexp_loc, pexp_loc_stack, pexp_attributes) :: args ->
      {
        pexp_desc = Pexp_fun (arg_label, arg, opt_val, expand_fun body args);
        pexp_loc;
        pexp_loc_stack;
        pexp_attributes;
      }

let debug_fun callback bind descr_loc typ_opt1 exp =
  let args, body, typ_opt2 = collect_fun [] exp in
  let loc = exp.pexp_loc in
  let typ =
    match (typ_opt1, typ_opt2) with
    | Some typ, _ | None, Some typ -> typ
    | None, None -> raise Not_transforming
  in
  let arg_logs =
    List.filter_map
      (function
        | ( _arg_label,
            _opt_val,
            [%pat?
              ([%p?
                 { ppat_desc = Ppat_var descr_loc | Ppat_alias (_, descr_loc); _ } as pat] :
                [%t? typ])],
            pexp_loc,
            _pexp_loc_stack,
            _pexp_attributes ) ->
            Some (!log_value ~loc:pexp_loc ~typ ~descr_loc (pat2expr pat))
        | _ -> None)
      args
  in
  let preamble = open_log_preamble ~message:descr_loc.txt ~loc () in
  let arg_logs =
    List.fold_left
      (fun e1 e2 ->
        [%expr
          [%e e1];
          [%e e2]])
      preamble arg_logs
  in
  let result = pat2pat_res bind in
  let body =
    [%expr
      if Debug_runtime.exceeds_max_children () then (
        [%e log_string ~loc ~descr_loc "<max_num_children exceeded>"];
        failwith "ppx_minidebug: max_num_children exceeded")
      else (
        [%e arg_logs];
        if Debug_runtime.exceeds_max_nesting () then (
          [%e log_string ~loc ~descr_loc "<max_nesting_depth exceeded>"];
          Debug_runtime.close_log ();
          failwith "ppx_minidebug: max_nesting_depth exceeded")
        else
          match [%e callback body] with
          | [%p result] ->
              [%e !log_value ~loc ~typ ~descr_loc (pat2expr result)];
              Debug_runtime.close_log ();
              [%e pat2expr result]
          | exception e ->
              Debug_runtime.close_log ();
              raise e)]
  in
  let body =
    match typ_opt2 with None -> body | Some typ -> [%expr ([%e body] : [%t typ])]
  in
  expand_fun body args

let debug_binding callback vb =
  let pat = vb.pvb_pat in
  let loc = vb.pvb_loc in
  let descr_loc, typ_opt =
    match (vb.pvb_pat, vb.pvb_expr) with
    | ( [%pat?
          ([%p? { ppat_desc = Ppat_var descr_loc | Ppat_alias (_, descr_loc); _ }] :
            [%t? typ])],
        _ ) ->
        (descr_loc, Some typ)
    | ( { ppat_desc = Ppat_var descr_loc | Ppat_alias (_, descr_loc); _ },
        [%expr ([%e? _exp] : [%t? typ])] ) ->
        (descr_loc, Some typ)
    | { ppat_desc = Ppat_var descr_loc | Ppat_alias (_, descr_loc); _ }, _ ->
        (descr_loc, None)
    | _ -> raise Not_transforming
  in
  match (vb.pvb_expr.pexp_desc, typ_opt) with
  | Pexp_fun _, _ ->
      { vb with pvb_expr = debug_fun callback vb.pvb_pat descr_loc typ_opt vb.pvb_expr }
  | _, Some typ ->
      let result = pat2pat_res pat in
      let exp =
        [%expr
          if Debug_runtime.exceeds_max_children () then (
            [%e log_string ~loc ~descr_loc "<max_num_children exceeded>"];
            failwith "ppx_minidebug: max_num_children exceeded")
          else (
            [%e open_log_preamble ~brief:true ~message:" " ~loc:descr_loc.loc ()];
            if Debug_runtime.exceeds_max_nesting () then (
              [%e log_string ~loc ~descr_loc "<max_nesting_depth exceeded>"];
              Debug_runtime.close_log ();
              failwith "ppx_minidebug: max_nesting_depth exceeded")
            else
              match [%e callback vb.pvb_expr] with
              | [%p result] ->
                  [%e !log_value ~loc ~typ ~descr_loc (pat2expr result)];
                  Debug_runtime.close_log ();
                  [%e pat2expr result]
              | exception e ->
                  Debug_runtime.close_log ();
                  raise e)]
      in
      { vb with pvb_expr = exp }
  | _ -> raise Not_transforming

let traverse =
  object (self)
    inherit Ast_traverse.map as super

    method! expression e =
      let callback e = self#expression e in
      match e with
      | { pexp_desc = Pexp_let (rec_flag, bindings, body); pexp_loc = _; _ } ->
          let bindings =
            List.map
              (fun vb ->
                try debug_binding callback vb
                with Not_transforming ->
                  { vb with pvb_expr = super#expression vb.pvb_expr })
              bindings
          in
          let body = callback body in
          { e with pexp_desc = Pexp_let (rec_flag, bindings, body) }
      | _ -> super#expression e

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
      let bindings = List.map (debug_binding callback) bindings in
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

let debug_this_expander_sexp ~ctxt:_ payload =
  log_value := log_value_sexp;
  debug_this_expander payload

let debug_expander_sexp ~ctxt:_ payload =
  log_value := log_value_sexp;
  debug_expander payload

let str_expander_sexp ~loc ~path:_ payload =
  log_value := log_value_sexp;
  str_expander ~loc payload

let debug_this_expander_pp ~ctxt:_ payload =
  log_value := log_value_pp;
  debug_this_expander payload

let debug_expander_pp ~ctxt:_ payload =
  log_value := log_value_pp;
  debug_expander payload

let str_expander_pp ~loc ~path:_ payload =
  log_value := log_value_pp;
  str_expander ~loc payload

let debug_this_expander_show ~ctxt:_ payload =
  log_value := log_value_show;
  debug_this_expander payload

let debug_expander_show ~ctxt:_ payload =
  log_value := log_value_show;
  debug_expander payload

let str_expander_show ~loc ~path:_ payload =
  log_value := log_value_show;
  str_expander ~loc payload

let rules =
  [
    Ppxlib.Context_free.Rule.extension
    @@ Extension.V3.declare "debug_sexp" Extension.Context.expression
         Ast_pattern.(single_expr_payload __)
         debug_expander_sexp;
    Ppxlib.Context_free.Rule.extension
    @@ Extension.V3.declare "debug_this_sexp" Extension.Context.expression
         Ast_pattern.(single_expr_payload __)
         debug_this_expander_sexp;
    Ppxlib.Context_free.Rule.extension
    @@ Extension.declare "debug_sexp" Extension.Context.structure_item
         Ast_pattern.(pstr __)
         str_expander_sexp;
    Ppxlib.Context_free.Rule.extension
    @@ Extension.V3.declare "debug_pp" Extension.Context.expression
         Ast_pattern.(single_expr_payload __)
         debug_expander_pp;
    Ppxlib.Context_free.Rule.extension
    @@ Extension.V3.declare "debug_this_pp" Extension.Context.expression
         Ast_pattern.(single_expr_payload __)
         debug_this_expander_pp;
    Ppxlib.Context_free.Rule.extension
    @@ Extension.declare "debug_pp" Extension.Context.structure_item
         Ast_pattern.(pstr __)
         str_expander_pp;
    Ppxlib.Context_free.Rule.extension
    @@ Extension.V3.declare "debug_show" Extension.Context.expression
         Ast_pattern.(single_expr_payload __)
         debug_expander_show;
    Ppxlib.Context_free.Rule.extension
    @@ Extension.V3.declare "debug_this_show" Extension.Context.expression
         Ast_pattern.(single_expr_payload __)
         debug_this_expander_show;
    Ppxlib.Context_free.Rule.extension
    @@ Extension.declare "debug_show" Extension.Context.structure_item
         Ast_pattern.(pstr __)
         str_expander_show;
  ]

let () = Driver.register_transformation ~rules "ppx_minidebug"
