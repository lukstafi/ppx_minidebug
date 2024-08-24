[@@@ocaml.ppx.context
  {
    tool_name = "ppx_driver";
    include_dirs = [];
    hidden_include_dirs = [];
    load_path = ([], []);
    open_modules = [];
    for_package = None;
    debug = false;
    use_threads = false;
    use_vmthreads = false;
    recursive_types = false;
    principal = false;
    transparent_modules = false;
    unboxed_types = false;
    unsafe_string = false;
    cookies = []
  }]
module Debug_runtime = (val
  Minidebug_runtime.debug_flushing ~filename:"debugger_show_log_prefixed" ())
;;()
let rec loop_exceeded (x : int) : int=
  let __entry_id = Debug_runtime.get_entry_id () in
  ();
  (Debug_runtime.open_log ~fname:"test/test_debug_log_prefixed.ml"
     ~start_lnum:6 ~start_colnum:33 ~end_lnum:12 ~end_colnum:55
     ~message:"loop_exceeded" ~entry_id:__entry_id ~log_level:1;
   Debug_runtime.log_value_show ?descr:(Some "x") ~entry_id:__entry_id
     ~is_result:false
     (((let open! ((Ppx_deriving_runtime)[@ocaml.warning "-A"]) in
          fun x ->
            Ppx_deriving_runtime.Format.asprintf "%a"
              (fun fmt -> Ppx_deriving_runtime.Format.fprintf fmt "%d") x)
        [@ocaml.warning "-39"][@ocaml.warning "-A"]) x));
  (match let z : int =
           let __entry_id = Debug_runtime.get_entry_id () in
           ();
           Debug_runtime.open_log ~fname:"test/test_debug_log_prefixed.ml"
             ~start_lnum:7 ~start_colnum:6 ~end_lnum:7 ~end_colnum:7
             ~message:"z" ~entry_id:__entry_id ~log_level:1;
           (match Debug_runtime.log_value_show ?descr:None
                    ~entry_id:__entry_id ~is_result:false
                    (((let open! ((Ppx_deriving_runtime)[@ocaml.warning "-A"]) in
                         fun x ->
                           Ppx_deriving_runtime.Format.asprintf "%a"
                             (fun fmt (a0, a1) ->
                                Ppx_deriving_runtime.Format.fprintf fmt "(@[";
                                ((Ppx_deriving_runtime.Format.fprintf fmt
                                    "%S") a0;
                                 Ppx_deriving_runtime.Format.fprintf fmt
                                   ",@ ";
                                 (Ppx_deriving_runtime.Format.fprintf fmt
                                    "%d") a1);
                                Ppx_deriving_runtime.Format.fprintf fmt "@])")
                             x)[@ocaml.warning "-39"][@ocaml.warning "-A"])
                       ("inside loop", (x : int)));
                  ();
                  (x - 1) / 2
            with
            | z as __res ->
                ((();
                  Debug_runtime.log_value_show ?descr:(Some "z")
                    ~entry_id:__entry_id ~is_result:true
                    (((let open! ((Ppx_deriving_runtime)[@ocaml.warning "-A"]) in
                         fun x ->
                           Ppx_deriving_runtime.Format.asprintf "%a"
                             (fun fmt ->
                                Ppx_deriving_runtime.Format.fprintf fmt "%d")
                             x)[@ocaml.warning "-39"][@ocaml.warning "-A"]) z));
                 Debug_runtime.close_log
                   ~fname:"test/test_debug_log_prefixed.ml" ~start_lnum:7
                   ~entry_id:__entry_id;
                 __res)
            | exception e ->
                (Debug_runtime.close_log
                   ~fname:"test/test_debug_log_prefixed.ml" ~start_lnum:7
                   ~entry_id:__entry_id;
                 raise e)) in
         if x <= 0 then 0 else z + (loop_exceeded (z + (x / 2)))
   with
   | __res ->
       (Debug_runtime.log_value_show ?descr:(Some "loop_exceeded")
          ~entry_id:__entry_id ~is_result:true
          (((let open! ((Ppx_deriving_runtime)[@ocaml.warning "-A"]) in
               fun x ->
                 Ppx_deriving_runtime.Format.asprintf "%a"
                   (fun fmt -> Ppx_deriving_runtime.Format.fprintf fmt "%d")
                   x)[@ocaml.warning "-39"][@ocaml.warning "-A"]) __res);
        Debug_runtime.close_log ~fname:"test/test_debug_log_prefixed.ml"
          ~start_lnum:6 ~entry_id:__entry_id;
        __res)
   | exception e ->
       (Debug_runtime.close_log ~fname:"test/test_debug_log_prefixed.ml"
          ~start_lnum:6 ~entry_id:__entry_id;
        raise e))
let () =
  try print_endline @@ (Int.to_string @@ (loop_exceeded 7))
  with | _ -> print_endline "Raised exception."
let bar () : unit=
  let __entry_id = Debug_runtime.get_entry_id () in
  ();
  Debug_runtime.open_log ~fname:"test/test_debug_log_prefixed.ml"
    ~start_lnum:18 ~start_colnum:19 ~end_lnum:23 ~end_colnum:6 ~message:"bar"
    ~entry_id:__entry_id ~log_level:1;
  (match let __entry_id = Debug_runtime.get_entry_id () in
         Debug_runtime.open_log ~fname:"test/test_debug_log_prefixed.ml"
           ~start_lnum:19 ~start_colnum:2 ~end_lnum:23 ~end_colnum:6
           ~message:"for:test_debug_log_prefixed:19" ~entry_id:__entry_id
           ~log_level:1;
         (match for i = 0 to 10 do
                  let __entry_id = Debug_runtime.get_entry_id () in
                  Debug_runtime.log_value_show ?descr:(Some "i")
                    ~entry_id:__entry_id ~is_result:false
                    (((let open! ((Ppx_deriving_runtime)[@ocaml.warning "-A"]) in
                         fun x ->
                           Ppx_deriving_runtime.Format.asprintf "%a"
                             (fun fmt ->
                                Ppx_deriving_runtime.Format.fprintf fmt "%d")
                             x)[@ocaml.warning "-39"][@ocaml.warning "-A"]) i);
                  Debug_runtime.open_log
                    ~fname:"test/test_debug_log_prefixed.ml" ~start_lnum:19
                    ~start_colnum:6 ~end_lnum:19 ~end_colnum:7
                    ~message:"<for i>" ~entry_id:__entry_id ~log_level:1;
                  (match let _baz : int =
                           let __entry_id = Debug_runtime.get_entry_id () in
                           ();
                           Debug_runtime.open_log
                             ~fname:"test/test_debug_log_prefixed.ml"
                             ~start_lnum:20 ~start_colnum:8 ~end_lnum:20
                             ~end_colnum:12 ~message:"_baz"
                             ~entry_id:__entry_id ~log_level:1;
                           (match i * 2 with
                            | _baz as __res ->
                                ((();
                                  Debug_runtime.log_value_show
                                    ?descr:(Some "_baz") ~entry_id:__entry_id
                                    ~is_result:true
                                    (((let open! ((Ppx_deriving_runtime)
                                         [@ocaml.warning "-A"]) in
                                         fun x ->
                                           Ppx_deriving_runtime.Format.asprintf
                                             "%a"
                                             (fun fmt ->
                                                Ppx_deriving_runtime.Format.fprintf
                                                  fmt "%d") x)
                                       [@ocaml.warning "-39"][@ocaml.warning
                                                               "-A"]) _baz));
                                 Debug_runtime.close_log
                                   ~fname:"test/test_debug_log_prefixed.ml"
                                   ~start_lnum:20 ~entry_id:__entry_id;
                                 __res)
                            | exception e ->
                                (Debug_runtime.close_log
                                   ~fname:"test/test_debug_log_prefixed.ml"
                                   ~start_lnum:20 ~entry_id:__entry_id;
                                 raise e)) in
                         Debug_runtime.log_value_show ?descr:None
                           ~entry_id:__entry_id ~is_result:false
                           (((let open! ((Ppx_deriving_runtime)[@ocaml.warning
                                                                 "-A"]) in
                                fun x ->
                                  Ppx_deriving_runtime.Format.asprintf "%a"
                                    (fun fmt (a0, a1, a2, a3) ->
                                       Ppx_deriving_runtime.Format.fprintf
                                         fmt "(@[";
                                       ((((Ppx_deriving_runtime.Format.fprintf
                                             fmt "%S") a0;
                                          Ppx_deriving_runtime.Format.fprintf
                                            fmt ",@ ";
                                          (Ppx_deriving_runtime.Format.fprintf
                                             fmt "%d") a1);
                                         Ppx_deriving_runtime.Format.fprintf
                                           fmt ",@ ";
                                         (Ppx_deriving_runtime.Format.fprintf
                                            fmt "%S") a2);
                                        Ppx_deriving_runtime.Format.fprintf
                                          fmt ",@ ";
                                        (Ppx_deriving_runtime.Format.fprintf
                                           fmt "%d") a3);
                                       Ppx_deriving_runtime.Format.fprintf
                                         fmt "@])") x)
                              [@ocaml.warning "-39"][@ocaml.warning "-A"])
                              ("loop step", (i : int), "value", (_baz : int)));
                         ()
                   with
                   | () ->
                       (();
                        Debug_runtime.close_log
                          ~fname:"test/test_debug_log_prefixed.ml"
                          ~start_lnum:20 ~entry_id:__entry_id;
                        ())
                   | exception e ->
                       (Debug_runtime.close_log
                          ~fname:"test/test_debug_log_prefixed.ml"
                          ~start_lnum:20 ~entry_id:__entry_id;
                        raise e))
                done
          with
          | () ->
              Debug_runtime.close_log
                ~fname:"test/test_debug_log_prefixed.ml" ~start_lnum:19
                ~entry_id:__entry_id
          | exception e ->
              (Debug_runtime.close_log
                 ~fname:"test/test_debug_log_prefixed.ml" ~start_lnum:19
                 ~entry_id:__entry_id;
               raise e))
   with
   | __res ->
       (Debug_runtime.log_value_show ?descr:(Some "bar") ~entry_id:__entry_id
          ~is_result:true
          (((let open! ((Ppx_deriving_runtime)[@ocaml.warning "-A"]) in
               fun x ->
                 Ppx_deriving_runtime.Format.asprintf "%a"
                   (fun fmt () ->
                      Ppx_deriving_runtime.Format.pp_print_string fmt "()") x)
             [@ocaml.warning "-39"][@ocaml.warning "-A"]) __res);
        Debug_runtime.close_log ~fname:"test/test_debug_log_prefixed.ml"
          ~start_lnum:18 ~entry_id:__entry_id;
        __res)
   | exception e ->
       (Debug_runtime.close_log ~fname:"test/test_debug_log_prefixed.ml"
          ~start_lnum:18 ~entry_id:__entry_id;
        raise e))
let () = try bar () with | _ -> print_endline "Raised exception."
[1mFile "_none_", line 1[0m:
[1;35mWarning[0m 53 [misplaced-attribute]: the "ocaml.warning" attribute cannot appear in this context
