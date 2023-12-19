module Debug_runtime = (Minidebug_runtime.Flushing)((val
  Minidebug_runtime.debug_ch "debugger_show_flushing.log"))
let foo (x : int) =
  ((Debug_runtime.open_log_preamble_full ~fname:"test_debug_show.ml"
      ~start_lnum:5 ~start_colnum:19 ~end_lnum:7 ~end_colnum:17
      ~message:"foo";
    Debug_runtime.log_value_show ~descr:"x" ~v:(([%show : int]) x));
   if Debug_runtime.exceeds_max_nesting ()
   then
     (Debug_runtime.log_value_show ~descr:"foo"
        ~v:"<max_nesting_depth exceeded>";
      Debug_runtime.close_log ();
      failwith "ppx_minidebug: max_nesting_depth exceeded")
   else
     if Debug_runtime.exceeds_max_children ()
     then
       (Debug_runtime.log_value_show ~descr:"foo"
          ~v:"<max_num_children exceeded>";
        Debug_runtime.close_log ();
        failwith "ppx_minidebug: max_num_children exceeded")
     else
       (match let y : int =
                if Debug_runtime.exceeds_max_children ()
                then
                  (Debug_runtime.log_value_show ~descr:"y"
                     ~v:"<max_num_children exceeded>";
                   failwith "ppx_minidebug: max_num_children exceeded")
                else
                  (Debug_runtime.open_log_preamble_brief
                     ~fname:"test_debug_show.ml" ~pos_lnum:6 ~pos_colnum:6
                     ~message:" ";
                   if Debug_runtime.exceeds_max_nesting ()
                   then
                     (Debug_runtime.log_value_show ~descr:"y"
                        ~v:"<max_nesting_depth exceeded>";
                      Debug_runtime.close_log ();
                      failwith "ppx_minidebug: max_nesting_depth exceeded")
                   else
                     (match (x + 1 : int) with
                      | y__res ->
                          (Debug_runtime.log_value_show ~descr:"y"
                             ~v:(([%show : int]) y__res);
                           Debug_runtime.close_log ();
                           y__res)
                      | exception e -> (Debug_runtime.close_log (); raise e))) in
              [x; y; 2 * y]
        with
        | foo__res ->
            (Debug_runtime.log_value_show ~descr:"foo"
               ~v:(([%show : int list]) foo__res);
             Debug_runtime.close_log ();
             foo__res)
        | exception e -> (Debug_runtime.close_log (); raise e)) : int list)
let () = ignore @@ (List.hd @@ (foo 7))
type t = {
  first: int ;
  second: int }[@@deriving show]
let bar (x : t) =
  ((Debug_runtime.open_log_preamble_full ~fname:"test_debug_show.ml"
      ~start_lnum:13 ~start_colnum:19 ~end_lnum:15 ~end_colnum:14
      ~message:"bar";
    Debug_runtime.log_value_show ~descr:"x" ~v:(([%show : t]) x));
   if Debug_runtime.exceeds_max_nesting ()
   then
     (Debug_runtime.log_value_show ~descr:"bar"
        ~v:"<max_nesting_depth exceeded>";
      Debug_runtime.close_log ();
      failwith "ppx_minidebug: max_nesting_depth exceeded")
   else
     if Debug_runtime.exceeds_max_children ()
     then
       (Debug_runtime.log_value_show ~descr:"bar"
          ~v:"<max_num_children exceeded>";
        Debug_runtime.close_log ();
        failwith "ppx_minidebug: max_num_children exceeded")
     else
       (match let y : int =
                if Debug_runtime.exceeds_max_children ()
                then
                  (Debug_runtime.log_value_show ~descr:"y"
                     ~v:"<max_num_children exceeded>";
                   failwith "ppx_minidebug: max_num_children exceeded")
                else
                  (Debug_runtime.open_log_preamble_brief
                     ~fname:"test_debug_show.ml" ~pos_lnum:14 ~pos_colnum:6
                     ~message:" ";
                   if Debug_runtime.exceeds_max_nesting ()
                   then
                     (Debug_runtime.log_value_show ~descr:"y"
                        ~v:"<max_nesting_depth exceeded>";
                      Debug_runtime.close_log ();
                      failwith "ppx_minidebug: max_nesting_depth exceeded")
                   else
                     (match (x.first + 1 : int) with
                      | y__res ->
                          (Debug_runtime.log_value_show ~descr:"y"
                             ~v:(([%show : int]) y__res);
                           Debug_runtime.close_log ();
                           y__res)
                      | exception e -> (Debug_runtime.close_log (); raise e))) in
              x.second * y
        with
        | bar__res ->
            (Debug_runtime.log_value_show ~descr:"bar"
               ~v:(([%show : int]) bar__res);
             Debug_runtime.close_log ();
             bar__res)
        | exception e -> (Debug_runtime.close_log (); raise e)) : int)
let () = ignore @@ (bar { first = 7; second = 42 })
let baz (x : t) =
  ((Debug_runtime.open_log_preamble_full ~fname:"test_debug_show.ml"
      ~start_lnum:19 ~start_colnum:19 ~end_lnum:21 ~end_colnum:20
      ~message:"baz";
    Debug_runtime.log_value_show ~descr:"x" ~v:(([%show : t]) x));
   if Debug_runtime.exceeds_max_nesting ()
   then
     (Debug_runtime.log_value_show ~descr:"baz"
        ~v:"<max_nesting_depth exceeded>";
      Debug_runtime.close_log ();
      failwith "ppx_minidebug: max_nesting_depth exceeded")
   else
     if Debug_runtime.exceeds_max_children ()
     then
       (Debug_runtime.log_value_show ~descr:"baz"
          ~v:"<max_num_children exceeded>";
        Debug_runtime.close_log ();
        failwith "ppx_minidebug: max_num_children exceeded")
     else
       (match let (((y, z) as _yz) : (int * int)) =
                if Debug_runtime.exceeds_max_children ()
                then
                  (Debug_runtime.log_value_show ~descr:"_yz"
                     ~v:"<max_num_children exceeded>";
                   failwith "ppx_minidebug: max_num_children exceeded")
                else
                  (Debug_runtime.open_log_preamble_brief
                     ~fname:"test_debug_show.ml" ~pos_lnum:20 ~pos_colnum:17
                     ~message:" ";
                   if Debug_runtime.exceeds_max_nesting ()
                   then
                     (Debug_runtime.log_value_show ~descr:"_yz"
                        ~v:"<max_nesting_depth exceeded>";
                      Debug_runtime.close_log ();
                      failwith "ppx_minidebug: max_nesting_depth exceeded")
                   else
                     (match ((x.first + 1), 3) with
                      | _yz__res ->
                          (Debug_runtime.log_value_show ~descr:"_yz"
                             ~v:(([%show : (int * int)]) _yz__res);
                           Debug_runtime.close_log ();
                           _yz__res)
                      | exception e -> (Debug_runtime.close_log (); raise e))) in
              (x.second * y) + z
        with
        | baz__res ->
            (Debug_runtime.log_value_show ~descr:"baz"
               ~v:(([%show : int]) baz__res);
             Debug_runtime.close_log ();
             baz__res)
        | exception e -> (Debug_runtime.close_log (); raise e)) : int)
let () = ignore @@ (baz { first = 7; second = 42 })
let rec loop (depth : int) (x : t) =
  (((Debug_runtime.open_log_preamble_full ~fname:"test_debug_show.ml"
       ~start_lnum:25 ~start_colnum:24 ~end_lnum:31 ~end_colnum:9
       ~message:"loop";
     Debug_runtime.log_value_show ~descr:"depth" ~v:(([%show : int]) depth));
    Debug_runtime.log_value_show ~descr:"x" ~v:(([%show : t]) x));
   if Debug_runtime.exceeds_max_nesting ()
   then
     (Debug_runtime.log_value_show ~descr:"loop"
        ~v:"<max_nesting_depth exceeded>";
      Debug_runtime.close_log ();
      failwith "ppx_minidebug: max_nesting_depth exceeded")
   else
     if Debug_runtime.exceeds_max_children ()
     then
       (Debug_runtime.log_value_show ~descr:"loop"
          ~v:"<max_num_children exceeded>";
        Debug_runtime.close_log ();
        failwith "ppx_minidebug: max_num_children exceeded")
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
                     if Debug_runtime.exceeds_max_children ()
                     then
                       (Debug_runtime.log_value_show ~descr:"y"
                          ~v:"<max_num_children exceeded>";
                        failwith "ppx_minidebug: max_num_children exceeded")
                     else
                       (Debug_runtime.open_log_preamble_brief
                          ~fname:"test_debug_show.ml" ~pos_lnum:29
                          ~pos_colnum:8 ~message:" ";
                        if Debug_runtime.exceeds_max_nesting ()
                        then
                          (Debug_runtime.log_value_show ~descr:"y"
                             ~v:"<max_nesting_depth exceeded>";
                           Debug_runtime.close_log ();
                           failwith
                             "ppx_minidebug: max_nesting_depth exceeded")
                        else
                          (match (loop (depth + 1)
                                    {
                                      first = (x.second - 1);
                                      second = (x.first + 2)
                                    } : int)
                           with
                           | y__res ->
                               (Debug_runtime.log_value_show ~descr:"y"
                                  ~v:(([%show : int]) y__res);
                                Debug_runtime.close_log ();
                                y__res)
                           | exception e ->
                               (Debug_runtime.close_log (); raise e))) in
                   let z : int =
                     if Debug_runtime.exceeds_max_children ()
                     then
                       (Debug_runtime.log_value_show ~descr:"z"
                          ~v:"<max_num_children exceeded>";
                        failwith "ppx_minidebug: max_num_children exceeded")
                     else
                       (Debug_runtime.open_log_preamble_brief
                          ~fname:"test_debug_show.ml" ~pos_lnum:30
                          ~pos_colnum:8 ~message:" ";
                        if Debug_runtime.exceeds_max_nesting ()
                        then
                          (Debug_runtime.log_value_show ~descr:"z"
                             ~v:"<max_nesting_depth exceeded>";
                           Debug_runtime.close_log ();
                           failwith
                             "ppx_minidebug: max_nesting_depth exceeded")
                        else
                          (match (loop (depth + 1)
                                    { first = (x.second + 1); second = y } : 
                             int)
                           with
                           | z__res ->
                               (Debug_runtime.log_value_show ~descr:"z"
                                  ~v:(([%show : int]) z__res);
                                Debug_runtime.close_log ();
                                z__res)
                           | exception e ->
                               (Debug_runtime.close_log (); raise e))) in
                   z + 7)
        with
        | loop__res ->
            (Debug_runtime.log_value_show ~descr:"loop"
               ~v:(([%show : int]) loop__res);
             Debug_runtime.close_log ();
             loop__res)
        | exception e -> (Debug_runtime.close_log (); raise e)) : int)
let () = ignore @@ (loop 0 { first = 7; second = 42 })
