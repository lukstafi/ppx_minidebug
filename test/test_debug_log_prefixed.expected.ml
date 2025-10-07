let _get_local_debug_runtime =
  let rt = Minidebug_db.debug_db_file "debugger_log_prefixed" in fun () -> rt
;;()
let rec loop_exceeded (x : int) =
  let module Debug_runtime = (val _get_local_debug_runtime ()) in
    (let __entry_id = Debug_runtime.get_entry_id () in
     (Debug_runtime.open_log ~fname:"test_debug_log_prefixed.ml"
        ~start_lnum:8 ~start_colnum:33 ~end_lnum:14 ~end_colnum:55
        ~message:"loop_exceeded" ~entry_id:__entry_id ~log_level:1 `Diagn;
      ());
     ();
     (match let z =
              Debug_runtime.log_value_show ?descr:None ~entry_id:__entry_id
                ~log_level:2 ~is_result:false
                (lazy (([%show : (string * int)]) ("inside loop", (x : int))));
              ();
              (x - 1) / 2 in
            if x <= 0 then 0 else z + (loop_exceeded (z + (x / 2)))
      with
      | __res ->
          (();
           Debug_runtime.close_log ~fname:"test_debug_log_prefixed.ml"
             ~start_lnum:8 ~entry_id:__entry_id;
           __res)
      | exception e ->
          (Debug_runtime.close_log ~fname:"test_debug_log_prefixed.ml"
             ~start_lnum:8 ~entry_id:__entry_id;
           raise e)) : int)
let () =
  try print_endline @@ (Int.to_string @@ (loop_exceeded 7))
  with | _ -> print_endline "Raised exception."
let bar () =
  let module Debug_runtime = (val _get_local_debug_runtime ()) in
    (let __entry_id = Debug_runtime.get_entry_id () in
     Debug_runtime.open_log ~fname:"test_debug_log_prefixed.ml"
       ~start_lnum:21 ~start_colnum:19 ~end_lnum:26 ~end_colnum:6
       ~message:"bar" ~entry_id:__entry_id ~log_level:1 `Track;
     ();
     (match let __entry_id = Debug_runtime.get_entry_id () in
            Debug_runtime.open_log ~fname:"test_debug_log_prefixed.ml"
              ~start_lnum:22 ~start_colnum:2 ~end_lnum:26 ~end_colnum:6
              ~message:"for:test_debug_log_prefixed:22" ~entry_id:__entry_id
              ~log_level:1 `Track;
            (match for i = 0 to 10 do
                     let __entry_id = Debug_runtime.get_entry_id () in
                     Debug_runtime.open_log
                       ~fname:"test_debug_log_prefixed.ml" ~start_lnum:22
                       ~start_colnum:6 ~end_lnum:22 ~end_colnum:7
                       ~message:"<for i>" ~entry_id:__entry_id ~log_level:1
                       `Track;
                     Debug_runtime.log_value_show ?descr:(Some "i")
                       ~entry_id:__entry_id ~log_level:1 ~is_result:false
                       (lazy (([%show : int]) i));
                     (match let _baz =
                              let __entry_id = Debug_runtime.get_entry_id () in
                              Debug_runtime.open_log
                                ~fname:"test_debug_log_prefixed.ml"
                                ~start_lnum:23 ~start_colnum:8 ~end_lnum:23
                                ~end_colnum:12 ~message:"_baz"
                                ~entry_id:__entry_id ~log_level:1 `Track;
                              ();
                              (match i * 2 with
                               | _baz as __res ->
                                   ((();
                                     Debug_runtime.log_value_show
                                       ?descr:(Some "_baz")
                                       ~entry_id:__entry_id ~log_level:1
                                       ~is_result:true
                                       (lazy (([%show : int]) _baz)));
                                    Debug_runtime.close_log
                                      ~fname:"test_debug_log_prefixed.ml"
                                      ~start_lnum:23 ~entry_id:__entry_id;
                                    __res)
                               | exception e ->
                                   (Debug_runtime.close_log
                                      ~fname:"test_debug_log_prefixed.ml"
                                      ~start_lnum:23 ~entry_id:__entry_id;
                                    raise e)) in
                            Debug_runtime.log_value_show ?descr:None
                              ~entry_id:__entry_id ~log_level:2
                              ~is_result:false
                              (lazy
                                 (([%show : (string * int * string * int)])
                                    ("loop step", (i : int), "value",
                                      (_baz : int))));
                            ()
                      with
                      | () ->
                          (();
                           Debug_runtime.close_log
                             ~fname:"test_debug_log_prefixed.ml"
                             ~start_lnum:23 ~entry_id:__entry_id;
                           ())
                      | exception e ->
                          (Debug_runtime.close_log
                             ~fname:"test_debug_log_prefixed.ml"
                             ~start_lnum:23 ~entry_id:__entry_id;
                           raise e))
                   done
             with
             | () ->
                 Debug_runtime.close_log ~fname:"test_debug_log_prefixed.ml"
                   ~start_lnum:22 ~entry_id:__entry_id
             | exception e ->
                 (Debug_runtime.close_log ~fname:"test_debug_log_prefixed.ml"
                    ~start_lnum:22 ~entry_id:__entry_id;
                  raise e))
      with
      | __res ->
          (Debug_runtime.log_value_show ?descr:(Some "bar")
             ~entry_id:__entry_id ~log_level:1 ~is_result:true
             (lazy (([%show : unit]) __res));
           Debug_runtime.close_log ~fname:"test_debug_log_prefixed.ml"
             ~start_lnum:21 ~entry_id:__entry_id;
           __res)
      | exception e ->
          (Debug_runtime.close_log ~fname:"test_debug_log_prefixed.ml"
             ~start_lnum:21 ~entry_id:__entry_id;
           raise e)) : unit)
let () = try bar () with | _ -> print_endline "Raised exception."
