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
open Sexplib0.Sexp_conv
let _get_local_debug_runtime =
  Minidebug_runtime.local_runtime "path/to/debugger_printbox.log" ()
let rec foo : int list -> int =
  function
  | [] ->
      let module Debug_runtime = (val _get_local_debug_runtime ()) in
        let __entry_id = Debug_runtime.get_entry_id () in
        (();
         Debug_runtime.open_log ~fname:"doc/sync_to_md.ml" ~start_lnum:6
           ~start_colnum:10 ~end_lnum:6 ~end_colnum:11
           ~message:"<function -- branch 0> []" ~entry_id:__entry_id
           ~log_level:1 `Debug;
         (match 0 with
          | __res ->
              (Debug_runtime.log_value_sexp ?descr:(Some "foo")
                 ~entry_id:__entry_id ~log_level:1 ~is_result:true
                 (((sexp_of_int)[@merlin.hide ]) __res);
               Debug_runtime.close_log ~fname:"doc/sync_to_md.ml"
                 ~start_lnum:6 ~entry_id:__entry_id;
               __res)
          | exception e ->
              (Debug_runtime.close_log ~fname:"doc/sync_to_md.ml"
                 ~start_lnum:6 ~entry_id:__entry_id;
               raise e)))
  | x::xs ->
      let module Debug_runtime = (val _get_local_debug_runtime ()) in
        let __entry_id = Debug_runtime.get_entry_id () in
        (();
         ((Debug_runtime.open_log ~fname:"doc/sync_to_md.ml" ~start_lnum:7
             ~start_colnum:15 ~end_lnum:7 ~end_colnum:25
             ~message:"<function -- branch 1> :: (x, xs)"
             ~entry_id:__entry_id ~log_level:1 `Debug;
           Debug_runtime.log_value_sexp ?descr:(Some "x")
             ~entry_id:__entry_id ~log_level:1 ~is_result:false
             (((sexp_of_int)[@merlin.hide ]) x));
          Debug_runtime.log_value_sexp ?descr:(Some "xs")
            ~entry_id:__entry_id ~log_level:1 ~is_result:false
            (((fun x__001_ -> sexp_of_list sexp_of_int x__001_)
               [@merlin.hide ]) xs));
         (match x + (foo xs) with
          | __res ->
              (Debug_runtime.log_value_sexp ?descr:(Some "foo")
                 ~entry_id:__entry_id ~log_level:1 ~is_result:true
                 (((sexp_of_int)[@merlin.hide ]) __res);
               Debug_runtime.close_log ~fname:"doc/sync_to_md.ml"
                 ~start_lnum:7 ~entry_id:__entry_id;
               __res)
          | exception e ->
              (Debug_runtime.close_log ~fname:"doc/sync_to_md.ml"
                 ~start_lnum:7 ~entry_id:__entry_id;
               raise e)))
let () = foo [1; 2; 3]
