module Debug_runtime = (val
  Minidebug_runtime.debug_flushing ~filename:"debugger_show_log_prefixed" ())
;;()
let rec loop_exceeded (x : int) =
  (let __entry_id = Debug_runtime.get_entry_id () in
   ();
   (Debug_runtime.open_log_preamble_full ~fname:"test_debug_log_prefixed.ml"
      ~start_lnum:6 ~start_colnum:33 ~end_lnum:11 ~end_colnum:55
      ~message:"loop_exceeded" ~entry_id:__entry_id;
    ());
   (match let z : int =
            Debug_runtime.log_value_show ?descr:None ~entry_id:__entry_id
              ~is_result:false
              (([%show : (string * int)]) ("INFO: inside loop", (x : int)));
            (x - 1) / 2 in
          if x <= 0 then 0 else z + (loop_exceeded (z + (x / 2)))
    with
    | __res -> ((); Debug_runtime.close_log (); __res)
    | exception e -> (Debug_runtime.close_log (); raise e)) : int)
let () =
  try print_endline @@ (Int.to_string @@ (loop_exceeded 7))
  with | _ -> print_endline "Raised exception."
let bar () =
  (let __entry_id = Debug_runtime.get_entry_id () in
   ();
   Debug_runtime.open_log_preamble_full ~fname:"test_debug_log_prefixed.ml"
     ~start_lnum:17 ~start_colnum:19 ~end_lnum:21 ~end_colnum:6
     ~message:"bar" ~entry_id:__entry_id;
   (match let __entry_id = Debug_runtime.get_entry_id () in
          Debug_runtime.open_log_preamble_brief
            ~fname:"test_debug_log_prefixed.ml" ~pos_lnum:18 ~pos_colnum:2
            ~message:"for:test_debug_log_prefixed:18" ~entry_id:__entry_id;
          (match for i = 0 to 10 do
                   let __entry_id = Debug_runtime.get_entry_id () in
                   ();
                   Debug_runtime.open_log_preamble_brief
                     ~fname:"test_debug_log_prefixed.ml" ~pos_lnum:18
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
