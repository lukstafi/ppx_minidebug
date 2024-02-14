module Debug_runtime = (Minidebug_runtime.Flushing)((val
  Minidebug_runtime.debug_ch "debugger_show_log_prefixed.log"))
;;()
let rec loop_exceeded (x : int) =
  (let __entry_id = Debug_runtime.get_entry_id () in
   ();
   (Debug_runtime.open_log_preamble_full ~fname:"test_debug_log_prefixed.ml"
      ~start_lnum:7 ~start_colnum:33 ~end_lnum:12 ~end_colnum:55
      ~message:"loop_exceeded" ~entry_id:__entry_id;
    ());
   (match let z : int =
            let __entry_id = Debug_runtime.get_entry_id () in
            ();
            Debug_runtime.open_log_preamble_brief
              ~fname:"test_debug_log_prefixed.ml" ~pos_lnum:8 ~pos_colnum:6
              ~message:"z" ~entry_id:__entry_id;
            (match Debug_runtime.log_value_show ?descr:None
                     ~entry_id:__entry_id ~is_result:false
                     (([%show : (string * int)])
                        ("INFO: inside loop", (x : int)));
                   (x - 1) / 2
             with
             | _z as __res -> (((); ()); Debug_runtime.close_log (); __res)
             | exception e -> (Debug_runtime.close_log (); raise e)) in
          if x <= 0 then 0 else z + (loop_exceeded (z + (x / 2)))
    with
    | __res -> ((); Debug_runtime.close_log (); __res)
    | exception e -> (Debug_runtime.close_log (); raise e)) : int)
let () =
  try print_endline @@ (Int.to_string @@ (loop_exceeded 17))
  with | _ -> print_endline "Raised exception."
let bar () =
  (let __entry_id = Debug_runtime.get_entry_id () in
   ();
   Debug_runtime.open_log_preamble_full ~fname:"test_debug_log_prefixed.ml"
     ~start_lnum:18 ~start_colnum:19 ~end_lnum:22 ~end_colnum:6
     ~message:"bar" ~entry_id:__entry_id;
   (match let __entry_id = Debug_runtime.get_entry_id () in
          Debug_runtime.open_log_preamble_brief
            ~fname:"test_debug_log_prefixed.ml" ~pos_lnum:19 ~pos_colnum:2
            ~message:"<for loop>" ~entry_id:__entry_id;
          (match for i = 0 to 100 do
                   let __entry_id = Debug_runtime.get_entry_id () in
                   ();
                   Debug_runtime.open_log_preamble_brief
                     ~fname:"test_debug_log_prefixed.ml" ~pos_lnum:19
                     ~pos_colnum:6 ~message:"<for i>" ~entry_id:__entry_id;
                   (match let _baz : int = i * 2 in
                          Debug_runtime.log_value_show ?descr:None
                            ~entry_id:__entry_id ~is_result:false
                            (([%show : (string * int * string * int)])
                               ("INFO: loop step", (i : int), "value",
                                 (_baz : int)))
                    with
                    | () -> ((); Debug_runtime.close_log (); ())
                    | exception e -> (Debug_runtime.close_log (); raise e))
                 done
           with
           | () -> Debug_runtime.close_log ()
           | exception e -> (Debug_runtime.close_log (); raise e))
    with
    | __res -> ((); Debug_runtime.close_log (); __res)
    | exception e -> (Debug_runtime.close_log (); raise e)) : unit)
let () = try bar () with | _ -> print_endline "Raised exception."
