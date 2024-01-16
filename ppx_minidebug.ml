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
let track_branches = ref false

let log_string ~loc ~descr_loc s =
  [%expr
    Debug_runtime.log_value_show
      ~descr:[%e A.estring ~loc:descr_loc.loc descr_loc.txt]
      ~v:[%e A.estring ~loc s]]

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

let debug_fun callback ?bind ?descr_loc ?typ_opt exp =
  let args, body, typ_opt2 = collect_fun [] exp in
  let loc = exp.pexp_loc in
  let typ =
    match (typ_opt, typ_opt2) with
    | Some typ, _ | None, Some typ -> Some typ
    | None, None when !track_branches -> None
    | None, None -> raise Not_transforming
  in
  let descr_loc =
    match descr_loc with
    | None when !track_branches -> { txt = "__fun"; loc }
    | None -> raise Not_transforming
    | Some descr_loc -> descr_loc
  in
  let bind =
    match bind with
    | None -> pat2pat_res (Ast_builder.Default.ppat_var ~loc descr_loc)
    | Some bind -> bind
  in
  let arg_logs =
    List.filter_map
      (function
        | Pexp_fun_arg
            ( _arg_label,
              _opt_val,
              [%pat?
                ([%p?
                   { ppat_desc = Ppat_var descr_loc | Ppat_alias (_, descr_loc); _ } as
                   pat] :
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
              [%e
                match typ with
                | None -> [%expr ()]
                | Some typ -> !log_value ~loc ~typ ~descr_loc (pat2expr result)];
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
  | Pexp_newtype _, _ | Pexp_fun _, _ ->
      {
        vb with
        pvb_expr = debug_fun callback ~bind:vb.pvb_pat ~descr_loc ?typ_opt vb.pvb_expr;
      }
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

    method! expression e =
      let callback e = self#expression e in
      match e with
      | { pexp_desc = Pexp_let (rec_flag, bindings, body); _ } ->
          let bindings =
            List.map
              (fun vb ->
                try debug_binding callback vb
                with Not_transforming ->
                  { vb with pvb_expr = super#expression vb.pvb_expr })
              bindings
          in
          { e with pexp_desc = Pexp_let (rec_flag, bindings, callback body) }
      | { pexp_desc = Pexp_extension ({ loc = _; txt }, PStr [%str [%e? body]]); _ }
        when is_ext_point txt ->
          callback body
      | {
       pexp_desc =
         Pexp_extension ({ loc = _; txt = "debug_notrace" }, PStr [%str [%e? body]]);
       _;
      } -> (
          let old_track_branches = !track_branches in
          track_branches := false;
          match callback body with
          | result ->
              track_branches := old_track_branches;
              result
          | exception e ->
              track_branches := old_track_branches;
              raise e)
      | { pexp_desc = Pexp_newtype (type_label, exp); _ } -> (
          try debug_fun callback e
          with Not_transforming ->
            { e with pexp_desc = Pexp_newtype (type_label, self#expression exp) })
      | { pexp_desc = Pexp_fun (arg_label, guard, pat, exp); _ } -> (
          try debug_fun callback e
          with Not_transforming ->
            { e with pexp_desc = Pexp_fun (arg_label, guard, pat, self#expression exp) })
      | { pexp_desc = Pexp_match (expr, cases); _ } when !track_branches ->
          let cases =
            List.mapi
              (fun i { pc_lhs; pc_guard; pc_rhs } ->
                let pc_guard = Option.map callback pc_guard in
                let loc = pc_rhs.pexp_loc in
                let i = string_of_int i in
                let pc_rhs =
                  [%expr
                    [%e
                      open_log_preamble ~brief:true
                        ~message:(" <match -- branch " ^ i ^ ">")
                        ~loc:pc_lhs.ppat_loc ()];
                    match [%e callback pc_rhs] with
                    | match__result ->
                        Debug_runtime.close_log ();
                        match__result
                    | exception e ->
                        Debug_runtime.close_log ();
                        raise e]
                in
                { pc_lhs; pc_guard; pc_rhs })
              cases
          in
          { e with pexp_desc = Pexp_match (callback expr, cases) }
      | { pexp_desc = Pexp_ifthenelse (if_, then_, else_); _ } when !track_branches ->
          let then_ =
            let loc = then_.pexp_loc in
            [%expr
              [%e open_log_preamble ~brief:true ~message:" <if -- then branch>" ~loc ()];
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
                  [%e
                    open_log_preamble ~brief:true ~message:" <if -- else branch>" ~loc ()];
                  match [%e callback else_] with
                  | if_else__result ->
                      Debug_runtime.close_log ();
                      if_else__result
                  | exception e ->
                      Debug_runtime.close_log ();
                      raise e])
              else_
          in
          { e with pexp_desc = Pexp_ifthenelse (callback if_, then_, else_) }
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

let rules =
  List.map
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
