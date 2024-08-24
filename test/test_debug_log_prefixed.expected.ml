module Debug_runtime = (val
  Minidebug_runtime.debug_flushing ~filename:"debugger_show_log_prefixed" ())
;;()
let rec loop_exceeded (x : int) =
  (let __entry_id = Debug_runtime.get_entry_id () in
   ();
   (Debug_runtime.open_log ~fname:"test_debug_log_prefixed.ml" ~start_lnum:6
      ~start_colnum:33 ~end_lnum:12 ~end_colnum:55 ~message:"loop_exceeded"
      ~entry_id:__entry_id ~log_level:1;
    ());
   (match let z : int =
            Debug_runtime.log_value_show ?descr:None ~entry_id:__entry_id
              ~log_level:2 ~is_result:false
              (([%show : (string * int)]) ("inside loop", (x : int)));
            ();
            (x - 1) / 2 in
          if x <= 0 then 0 else z + (loop_exceeded (z + (x / 2)))
    with
    | __res ->
        (();
         Debug_runtime.close_log ~fname:"test_debug_log_prefixed.ml"
           ~start_lnum:6 ~entry_id:__entry_id;
         __res)
    | exception e ->
        (Debug_runtime.close_log ~fname:"test_debug_log_prefixed.ml"
           ~start_lnum:6 ~entry_id:__entry_id;
         raise e)) : int)
let () =
  try print_endline @@ (Int.to_string @@ (loop_exceeded 7))
  with | _ -> print_endline "Raised exception."
let bar () =
  (let __entry_id = Debug_runtime.get_entry_id () in
   ();
   Debug_runtime.open_log ~fname:"test_debug_log_prefixed.ml" ~start_lnum:18
     ~start_colnum:19 ~end_lnum:23 ~end_colnum:6 ~message:"bar"
     ~entry_id:__entry_id ~log_level:1;
   (match let __entry_id = Debug_runtime.get_entry_id () in
          Debug_runtime.open_log ~fname:"test_debug_log_prefixed.ml"
            ~start_lnum:19 ~start_colnum:2 ~end_lnum:23 ~end_colnum:6
            ~message:"for:test_debug_log_prefixed:19" ~entry_id:__entry_id
            ~log_level:1;
          (match for i = 0 to 10 do
                   let __entry_id = Debug_runtime.get_entry_id () in
                   Debug_runtime.log_value_show ?descr:(Some "i")
                     ~entry_id:__entry_id ~log_level:1 ~is_result:false
                     (([%show : int]) i);
                   Debug_runtime.open_log ~fname:"test_debug_log_prefixed.ml"
                     ~start_lnum:19 ~start_colnum:6 ~end_lnum:19
                     ~end_colnum:7 ~message:"<for i>" ~entry_id:__entry_id
                     ~log_level:1;
                   (match let _baz : int =
                            let __entry_id = Debug_runtime.get_entry_id () in
                            ();
                            Debug_runtime.open_log
                              ~fname:"test_debug_log_prefixed.ml"
                              ~start_lnum:20 ~start_colnum:8 ~end_lnum:20
                              ~end_colnum:12 ~message:"_baz"
                              ~entry_id:__entry_id ~log_level:1;
                            (match i * 2 with
                             | _baz as __res ->
                                 ((();
                                   Debug_runtime.log_value_show
                                     ?descr:(Some "_baz")
                                     ~entry_id:__entry_id ~log_level:1
                                     ~is_result:true (([%show : int]) _baz));
                                  Debug_runtime.close_log
                                    ~fname:"test_debug_log_prefixed.ml"
                                    ~start_lnum:20 ~entry_id:__entry_id;
                                  __res)
                             | exception e ->
                                 (Debug_runtime.close_log
                                    ~fname:"test_debug_log_prefixed.ml"
                                    ~start_lnum:20 ~entry_id:__entry_id;
                                  raise e)) in
                          Debug_runtime.log_value_show ?descr:None
                            ~entry_id:__entry_id ~log_level:2
                            ~is_result:false
                            (([%show : (string * int * string * int)])
                               ("loop step", (i : int), "value",
                                 (_baz : int)));
                          ()
                    with
                    | () ->
                        (();
                         Debug_runtime.close_log
                           ~fname:"test_debug_log_prefixed.ml" ~start_lnum:20
                           ~entry_id:__entry_id;
                         ())
                    | exception e ->
                        (Debug_runtime.close_log
                           ~fname:"test_debug_log_prefixed.ml" ~start_lnum:20
                           ~entry_id:__entry_id;
                         raise e))
                 done
           with
           | () ->
               Debug_runtime.close_log ~fname:"test_debug_log_prefixed.ml"
                 ~start_lnum:19 ~entry_id:__entry_id
           | exception e ->
               (Debug_runtime.close_log ~fname:"test_debug_log_prefixed.ml"
                  ~start_lnum:19 ~entry_id:__entry_id;
                raise e))
    with
    | __res ->
        (Debug_runtime.log_value_show ?descr:(Some "bar")
           ~entry_id:__entry_id ~log_level:1 ~is_result:true
           (([%show : unit]) __res);
         Debug_runtime.close_log ~fname:"test_debug_log_prefixed.ml"
           ~start_lnum:18 ~entry_id:__entry_id;
         __res)
    | exception e ->
        (Debug_runtime.close_log ~fname:"test_debug_log_prefixed.ml"
           ~start_lnum:18 ~entry_id:__entry_id;
         raise e)) : unit)
let () = try bar () with | _ -> print_endline "Raised exception."
