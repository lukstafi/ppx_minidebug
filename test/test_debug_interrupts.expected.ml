module Debug_runtime = (Minidebug_runtime.Flushing)((val
  Minidebug_runtime.debug_ch "debugger_show_interrupts.log"))
;;Debug_runtime.max_nesting_depth := (Some 5);
  Debug_runtime.max_num_children := (Some 10)
;;()
let rec loop_exceeded (x : int) =
  (let __entry_id = Debug_runtime.get_entry_id () in
   ();
   if Debug_runtime.exceeds_max_children ()
   then
     (Debug_runtime.log_value_show ~descr:"loop_exceeded"
        ~entry_id:__entry_id ~is_result:false "<max_num_children exceeded>";
      failwith "ppx_minidebug: max_num_children exceeded")
   else
     ((Debug_runtime.open_log_preamble_full ~fname:"test_debug_interrupts.ml"
         ~start_lnum:9 ~start_colnum:33 ~end_lnum:11 ~end_colnum:55
         ~message:"loop_exceeded : int" ~entry_id:__entry_id;
       Debug_runtime.log_value_show ?descr:(Some "x : int")
         ~entry_id:__entry_id ~is_result:false (([%show : int]) x));
      if Debug_runtime.exceeds_max_nesting ()
      then
        (Debug_runtime.log_value_show ~descr:"loop_exceeded"
           ~entry_id:__entry_id ~is_result:false
           "<max_nesting_depth exceeded>";
         Debug_runtime.close_log ();
         failwith "ppx_minidebug: max_nesting_depth exceeded")
      else
        (match let z : int =
                 let __entry_id = Debug_runtime.get_entry_id () in
                 ();
                 if Debug_runtime.exceeds_max_children ()
                 then
                   (Debug_runtime.log_value_show ~descr:"z"
                      ~entry_id:__entry_id ~is_result:false
                      "<max_num_children exceeded>";
                    failwith "ppx_minidebug: max_num_children exceeded")
                 else
                   (Debug_runtime.open_log_preamble_brief
                      ~fname:"test_debug_interrupts.ml" ~pos_lnum:10
                      ~pos_colnum:6 ~message:"z" ~entry_id:__entry_id;
                    if Debug_runtime.exceeds_max_nesting ()
                    then
                      (Debug_runtime.log_value_show ~descr:"z"
                         ~entry_id:__entry_id ~is_result:false
                         "<max_nesting_depth exceeded>";
                       Debug_runtime.close_log ();
                       failwith "ppx_minidebug: max_nesting_depth exceeded")
                    else
                      (match (x - 1) / 2 with
                       | z as __res ->
                           ((();
                             Debug_runtime.log_value_show
                               ?descr:(Some "z : int") ~entry_id:__entry_id
                               ~is_result:true (([%show : int]) z));
                            Debug_runtime.close_log ();
                            __res)
                       | exception e -> (Debug_runtime.close_log (); raise e))) in
               if x <= 0 then 0 else z + (loop_exceeded (z + (x / 2)))
         with
         | __res ->
             (Debug_runtime.log_value_show
                ?descr:(Some "loop_exceeded : int") ~entry_id:__entry_id
                ~is_result:true (([%show : int]) __res);
              Debug_runtime.close_log ();
              __res)
         | exception e -> (Debug_runtime.close_log (); raise e))) : int)
let () =
  try print_endline @@ (Int.to_string @@ (loop_exceeded 17))
  with | _ -> print_endline "Raised exception."
let bar () =
  (let __entry_id = Debug_runtime.get_entry_id () in
   ();
   if Debug_runtime.exceeds_max_children ()
   then
     (Debug_runtime.log_value_show ~descr:"bar" ~entry_id:__entry_id
        ~is_result:false "<max_num_children exceeded>";
      failwith "ppx_minidebug: max_num_children exceeded")
   else
     (Debug_runtime.open_log_preamble_full ~fname:"test_debug_interrupts.ml"
        ~start_lnum:17 ~start_colnum:19 ~end_lnum:21 ~end_colnum:6
        ~message:"bar : unit" ~entry_id:__entry_id;
      if Debug_runtime.exceeds_max_nesting ()
      then
        (Debug_runtime.log_value_show ~descr:"bar" ~entry_id:__entry_id
           ~is_result:false "<max_nesting_depth exceeded>";
         Debug_runtime.close_log ();
         failwith "ppx_minidebug: max_nesting_depth exceeded")
      else
        (match let __entry_id = Debug_runtime.get_entry_id () in
               Debug_runtime.open_log_preamble_brief
                 ~fname:"test_debug_interrupts.ml" ~pos_lnum:18 ~pos_colnum:2
                 ~message:"<for loop>" ~entry_id:__entry_id;
               (match for i = 0 to 100 do
                        let __entry_id = Debug_runtime.get_entry_id () in
                        Debug_runtime.log_value_show ?descr:(Some "i : int")
                          ~entry_id:__entry_id ~is_result:false
                          (([%show : int]) i);
                        if Debug_runtime.exceeds_max_children ()
                        then
                          (Debug_runtime.log_value_show ~descr:"i"
                             ~entry_id:__entry_id ~is_result:false
                             "<max_num_children exceeded>";
                           failwith
                             "ppx_minidebug: max_num_children exceeded")
                        else
                          (Debug_runtime.open_log_preamble_brief
                             ~fname:"test_debug_interrupts.ml" ~pos_lnum:18
                             ~pos_colnum:6 ~message:"<for i>"
                             ~entry_id:__entry_id;
                           if Debug_runtime.exceeds_max_nesting ()
                           then
                             (Debug_runtime.log_value_show ~descr:"i"
                                ~entry_id:__entry_id ~is_result:false
                                "<max_nesting_depth exceeded>";
                              Debug_runtime.close_log ();
                              failwith
                                "ppx_minidebug: max_nesting_depth exceeded")
                           else
                             (match let _baz : int =
                                      let __entry_id =
                                        Debug_runtime.get_entry_id () in
                                      ();
                                      if
                                        Debug_runtime.exceeds_max_children ()
                                      then
                                        (Debug_runtime.log_value_show
                                           ~descr:"_baz" ~entry_id:__entry_id
                                           ~is_result:false
                                           "<max_num_children exceeded>";
                                         failwith
                                           "ppx_minidebug: max_num_children exceeded")
                                      else
                                        (Debug_runtime.open_log_preamble_brief
                                           ~fname:"test_debug_interrupts.ml"
                                           ~pos_lnum:19 ~pos_colnum:8
                                           ~message:"_baz"
                                           ~entry_id:__entry_id;
                                         if
                                           Debug_runtime.exceeds_max_nesting
                                             ()
                                         then
                                           (Debug_runtime.log_value_show
                                              ~descr:"_baz"
                                              ~entry_id:__entry_id
                                              ~is_result:false
                                              "<max_nesting_depth exceeded>";
                                            Debug_runtime.close_log ();
                                            failwith
                                              "ppx_minidebug: max_nesting_depth exceeded")
                                         else
                                           (match i * 2 with
                                            | _baz as __res ->
                                                ((();
                                                  Debug_runtime.log_value_show
                                                    ?descr:(Some "_baz : int")
                                                    ~entry_id:__entry_id
                                                    ~is_result:true
                                                    (([%show : int]) _baz));
                                                 Debug_runtime.close_log ();
                                                 __res)
                                            | exception e ->
                                                (Debug_runtime.close_log ();
                                                 raise e))) in
                                    ()
                              with
                              | () -> ((); Debug_runtime.close_log (); ())
                              | exception e ->
                                  (Debug_runtime.close_log (); raise e)))
                      done
                with
                | () -> Debug_runtime.close_log ()
                | exception e -> (Debug_runtime.close_log (); raise e))
         with
         | __res ->
             (Debug_runtime.log_value_show ?descr:(Some "bar : unit")
                ~entry_id:__entry_id ~is_result:true (([%show : unit]) __res);
              Debug_runtime.close_log ();
              __res)
         | exception e -> (Debug_runtime.close_log (); raise e))) : unit)
let () = try bar () with | _ -> print_endline "Raised exception."
