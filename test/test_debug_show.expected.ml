module Debug_runtime = (Minidebug_runtime.Flushing)((val
  Minidebug_runtime.debug_ch "debugger_show_flushing.log"))
let foo (x : int) =
  (let __entry_id = Debug_runtime.get_entry_id () in
   ();
   if Debug_runtime.exceeds_max_children ()
   then
     (Debug_runtime.log_value_show ~descr:"foo" ~entry_id:__entry_id
        ~v:"<max_num_children exceeded>";
      failwith "ppx_minidebug: max_num_children exceeded")
   else
     ((Debug_runtime.open_log_preamble_full ~fname:"test_debug_show.ml"
         ~start_lnum:5 ~start_colnum:19 ~end_lnum:7 ~end_colnum:17
         ~message:"foo" ~entry_id:__entry_id;
       Debug_runtime.log_value_show ~descr:"x" ~entry_id:__entry_id
         ~v:(([%show : int]) x));
      if Debug_runtime.exceeds_max_nesting ()
      then
        (Debug_runtime.log_value_show ~descr:"foo" ~entry_id:__entry_id
           ~v:"<max_nesting_depth exceeded>";
         Debug_runtime.close_log ();
         failwith "ppx_minidebug: max_nesting_depth exceeded")
      else
        (match let y : int =
                 let __entry_id = Debug_runtime.get_entry_id () in
                 ();
                 if Debug_runtime.exceeds_max_children ()
                 then
                   (Debug_runtime.log_value_show ~descr:"y"
                      ~entry_id:__entry_id ~v:"<max_num_children exceeded>";
                    failwith "ppx_minidebug: max_num_children exceeded")
                 else
                   (Debug_runtime.open_log_preamble_brief
                      ~fname:"test_debug_show.ml" ~pos_lnum:6 ~pos_colnum:6
                      ~message:"y" ~entry_id:__entry_id;
                    if Debug_runtime.exceeds_max_nesting ()
                    then
                      (Debug_runtime.log_value_show ~descr:"y"
                         ~entry_id:__entry_id
                         ~v:"<max_nesting_depth exceeded>";
                       Debug_runtime.close_log ();
                       failwith "ppx_minidebug: max_nesting_depth exceeded")
                    else
                      (match x + 1 with
                       | y as __res ->
                           ((();
                             Debug_runtime.log_value_show ~descr:"y"
                               ~entry_id:__entry_id ~v:(([%show : int]) y));
                            Debug_runtime.close_log ();
                            __res)
                       | exception e -> (Debug_runtime.close_log (); raise e))) in
               [x; y; 2 * y]
         with
         | __res ->
             (Debug_runtime.log_value_show ~descr:"foo" ~entry_id:__entry_id
                ~v:(([%show : int list]) __res);
              Debug_runtime.close_log ();
              __res)
         | exception e -> (Debug_runtime.close_log (); raise e))) : int list)
let () = ignore @@ (List.hd @@ (foo 7))
type t = {
  first: int ;
  second: int }[@@deriving show]
let bar (x : t) =
  (let __entry_id = Debug_runtime.get_entry_id () in
   ();
   if Debug_runtime.exceeds_max_children ()
   then
     (Debug_runtime.log_value_show ~descr:"bar" ~entry_id:__entry_id
        ~v:"<max_num_children exceeded>";
      failwith "ppx_minidebug: max_num_children exceeded")
   else
     ((Debug_runtime.open_log_preamble_full ~fname:"test_debug_show.ml"
         ~start_lnum:13 ~start_colnum:19 ~end_lnum:15 ~end_colnum:14
         ~message:"bar" ~entry_id:__entry_id;
       Debug_runtime.log_value_show ~descr:"x" ~entry_id:__entry_id
         ~v:(([%show : t]) x));
      if Debug_runtime.exceeds_max_nesting ()
      then
        (Debug_runtime.log_value_show ~descr:"bar" ~entry_id:__entry_id
           ~v:"<max_nesting_depth exceeded>";
         Debug_runtime.close_log ();
         failwith "ppx_minidebug: max_nesting_depth exceeded")
      else
        (match let y : int =
                 let __entry_id = Debug_runtime.get_entry_id () in
                 ();
                 if Debug_runtime.exceeds_max_children ()
                 then
                   (Debug_runtime.log_value_show ~descr:"y"
                      ~entry_id:__entry_id ~v:"<max_num_children exceeded>";
                    failwith "ppx_minidebug: max_num_children exceeded")
                 else
                   (Debug_runtime.open_log_preamble_brief
                      ~fname:"test_debug_show.ml" ~pos_lnum:14 ~pos_colnum:6
                      ~message:"y" ~entry_id:__entry_id;
                    if Debug_runtime.exceeds_max_nesting ()
                    then
                      (Debug_runtime.log_value_show ~descr:"y"
                         ~entry_id:__entry_id
                         ~v:"<max_nesting_depth exceeded>";
                       Debug_runtime.close_log ();
                       failwith "ppx_minidebug: max_nesting_depth exceeded")
                    else
                      (match x.first + 1 with
                       | y as __res ->
                           ((();
                             Debug_runtime.log_value_show ~descr:"y"
                               ~entry_id:__entry_id ~v:(([%show : int]) y));
                            Debug_runtime.close_log ();
                            __res)
                       | exception e -> (Debug_runtime.close_log (); raise e))) in
               x.second * y
         with
         | __res ->
             (Debug_runtime.log_value_show ~descr:"bar" ~entry_id:__entry_id
                ~v:(([%show : int]) __res);
              Debug_runtime.close_log ();
              __res)
         | exception e -> (Debug_runtime.close_log (); raise e))) : int)
let () = ignore @@ (bar { first = 7; second = 42 })
let baz (x : t) =
  (let __entry_id = Debug_runtime.get_entry_id () in
   ();
   if Debug_runtime.exceeds_max_children ()
   then
     (Debug_runtime.log_value_show ~descr:"baz" ~entry_id:__entry_id
        ~v:"<max_num_children exceeded>";
      failwith "ppx_minidebug: max_num_children exceeded")
   else
     ((Debug_runtime.open_log_preamble_full ~fname:"test_debug_show.ml"
         ~start_lnum:19 ~start_colnum:19 ~end_lnum:21 ~end_colnum:20
         ~message:"baz" ~entry_id:__entry_id;
       Debug_runtime.log_value_show ~descr:"x" ~entry_id:__entry_id
         ~v:(([%show : t]) x));
      if Debug_runtime.exceeds_max_nesting ()
      then
        (Debug_runtime.log_value_show ~descr:"baz" ~entry_id:__entry_id
           ~v:"<max_nesting_depth exceeded>";
         Debug_runtime.close_log ();
         failwith "ppx_minidebug: max_nesting_depth exceeded")
      else
        (match let (((y, z) as _yz) : (int * int)) =
                 let __entry_id = Debug_runtime.get_entry_id () in
                 ();
                 if Debug_runtime.exceeds_max_children ()
                 then
                   (Debug_runtime.log_value_show ~descr:"_yz"
                      ~entry_id:__entry_id ~v:"<max_num_children exceeded>";
                    failwith "ppx_minidebug: max_num_children exceeded")
                 else
                   (Debug_runtime.open_log_preamble_brief
                      ~fname:"test_debug_show.ml" ~pos_lnum:20 ~pos_colnum:17
                      ~message:"_yz" ~entry_id:__entry_id;
                    if Debug_runtime.exceeds_max_nesting ()
                    then
                      (Debug_runtime.log_value_show ~descr:"_yz"
                         ~entry_id:__entry_id
                         ~v:"<max_nesting_depth exceeded>";
                       Debug_runtime.close_log ();
                       failwith "ppx_minidebug: max_nesting_depth exceeded")
                    else
                      (match ((x.first + 1), 3) with
                       | _yz as __res ->
                           ((();
                             Debug_runtime.log_value_show ~descr:"_yz"
                               ~entry_id:__entry_id
                               ~v:(([%show : (int * int)]) _yz));
                            Debug_runtime.close_log ();
                            __res)
                       | exception e -> (Debug_runtime.close_log (); raise e))) in
               (x.second * y) + z
         with
         | __res ->
             (Debug_runtime.log_value_show ~descr:"baz" ~entry_id:__entry_id
                ~v:(([%show : int]) __res);
              Debug_runtime.close_log ();
              __res)
         | exception e -> (Debug_runtime.close_log (); raise e))) : int)
let () = ignore @@ (baz { first = 7; second = 42 })
let rec loop (depth : int) (x : t) =
  (let __entry_id = Debug_runtime.get_entry_id () in
   ();
   if Debug_runtime.exceeds_max_children ()
   then
     (Debug_runtime.log_value_show ~descr:"loop" ~entry_id:__entry_id
        ~v:"<max_num_children exceeded>";
      failwith "ppx_minidebug: max_num_children exceeded")
   else
     (((Debug_runtime.open_log_preamble_full ~fname:"test_debug_show.ml"
          ~start_lnum:25 ~start_colnum:24 ~end_lnum:31 ~end_colnum:9
          ~message:"loop" ~entry_id:__entry_id;
        Debug_runtime.log_value_show ~descr:"depth" ~entry_id:__entry_id
          ~v:(([%show : int]) depth));
       Debug_runtime.log_value_show ~descr:"x" ~entry_id:__entry_id
         ~v:(([%show : t]) x));
      if Debug_runtime.exceeds_max_nesting ()
      then
        (Debug_runtime.log_value_show ~descr:"loop" ~entry_id:__entry_id
           ~v:"<max_nesting_depth exceeded>";
         Debug_runtime.close_log ();
         failwith "ppx_minidebug: max_nesting_depth exceeded")
      else
        (match if depth > 6
               then x.first + x.second
               else
                 if depth > 3
                 then
                   loop (depth + 1)
                     { first = (x.second + 1); second = (x.first / 2) }
                 else
                   (let y : int =
                      let __entry_id = Debug_runtime.get_entry_id () in
                      ();
                      if Debug_runtime.exceeds_max_children ()
                      then
                        (Debug_runtime.log_value_show ~descr:"y"
                           ~entry_id:__entry_id
                           ~v:"<max_num_children exceeded>";
                         failwith "ppx_minidebug: max_num_children exceeded")
                      else
                        (Debug_runtime.open_log_preamble_brief
                           ~fname:"test_debug_show.ml" ~pos_lnum:29
                           ~pos_colnum:8 ~message:"y" ~entry_id:__entry_id;
                         if Debug_runtime.exceeds_max_nesting ()
                         then
                           (Debug_runtime.log_value_show ~descr:"y"
                              ~entry_id:__entry_id
                              ~v:"<max_nesting_depth exceeded>";
                            Debug_runtime.close_log ();
                            failwith
                              "ppx_minidebug: max_nesting_depth exceeded")
                         else
                           (match loop (depth + 1)
                                    {
                                      first = (x.second - 1);
                                      second = (x.first + 2)
                                    }
                            with
                            | y as __res ->
                                ((();
                                  Debug_runtime.log_value_show ~descr:"y"
                                    ~entry_id:__entry_id
                                    ~v:(([%show : int]) y));
                                 Debug_runtime.close_log ();
                                 __res)
                            | exception e ->
                                (Debug_runtime.close_log (); raise e))) in
                    let z : int =
                      let __entry_id = Debug_runtime.get_entry_id () in
                      ();
                      if Debug_runtime.exceeds_max_children ()
                      then
                        (Debug_runtime.log_value_show ~descr:"z"
                           ~entry_id:__entry_id
                           ~v:"<max_num_children exceeded>";
                         failwith "ppx_minidebug: max_num_children exceeded")
                      else
                        (Debug_runtime.open_log_preamble_brief
                           ~fname:"test_debug_show.ml" ~pos_lnum:30
                           ~pos_colnum:8 ~message:"z" ~entry_id:__entry_id;
                         if Debug_runtime.exceeds_max_nesting ()
                         then
                           (Debug_runtime.log_value_show ~descr:"z"
                              ~entry_id:__entry_id
                              ~v:"<max_nesting_depth exceeded>";
                            Debug_runtime.close_log ();
                            failwith
                              "ppx_minidebug: max_nesting_depth exceeded")
                         else
                           (match loop (depth + 1)
                                    { first = (x.second + 1); second = y }
                            with
                            | z as __res ->
                                ((();
                                  Debug_runtime.log_value_show ~descr:"z"
                                    ~entry_id:__entry_id
                                    ~v:(([%show : int]) z));
                                 Debug_runtime.close_log ();
                                 __res)
                            | exception e ->
                                (Debug_runtime.close_log (); raise e))) in
                    z + 7)
         with
         | __res ->
             (Debug_runtime.log_value_show ~descr:"loop" ~entry_id:__entry_id
                ~v:(([%show : int]) __res);
              Debug_runtime.close_log ();
              __res)
         | exception e -> (Debug_runtime.close_log (); raise e))) : int)
let () = ignore @@ (loop 0 { first = 7; second = 42 })
