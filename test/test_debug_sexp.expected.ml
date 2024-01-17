open Sexplib0.Sexp_conv
module Debug_runtime = (Minidebug_runtime.PrintBox)((val
  Minidebug_runtime.debug_ch "debugger_sexp_printbox.log"))
let foo (x : int) =
  (if Debug_runtime.exceeds_max_children ()
   then
     (Debug_runtime.log_value_show ~descr:"foo"
        ~v:"<max_num_children exceeded>";
      failwith "ppx_minidebug: max_num_children exceeded")
   else
     ((Debug_runtime.open_log_preamble_full ~fname:"test_debug_sexp.ml"
         ~start_lnum:7 ~start_colnum:19 ~end_lnum:9 ~end_colnum:17
         ~message:"foo";
       Debug_runtime.log_value_sexp ~descr:"x" ~sexp:(([%sexp_of : int]) x));
      if Debug_runtime.exceeds_max_nesting ()
      then
        (Debug_runtime.log_value_show ~descr:"foo"
           ~v:"<max_nesting_depth exceeded>";
         Debug_runtime.close_log ();
         failwith "ppx_minidebug: max_nesting_depth exceeded")
      else
        (match let y : int =
                 if Debug_runtime.exceeds_max_children ()
                 then
                   (Debug_runtime.log_value_show ~descr:"y"
                      ~v:"<max_num_children exceeded>";
                    failwith "ppx_minidebug: max_num_children exceeded")
                 else
                   (Debug_runtime.open_log_preamble_brief
                      ~fname:"test_debug_sexp.ml" ~pos_lnum:8 ~pos_colnum:6
                      ~message:"y";
                    if Debug_runtime.exceeds_max_nesting ()
                    then
                      (Debug_runtime.log_value_show ~descr:"y"
                         ~v:"<max_nesting_depth exceeded>";
                       Debug_runtime.close_log ();
                       failwith "ppx_minidebug: max_nesting_depth exceeded")
                    else
                      (match (x + 1 : int) with
                       | y__res ->
                           (Debug_runtime.log_value_sexp ~descr:"y"
                              ~sexp:(([%sexp_of : int]) y__res);
                            Debug_runtime.close_log ();
                            y__res)
                       | exception e -> (Debug_runtime.close_log (); raise e))) in
               [x; y; 2 * y]
         with
         | foo__res ->
             (Debug_runtime.log_value_sexp ~descr:"foo"
                ~sexp:(([%sexp_of : int list]) foo__res);
              Debug_runtime.close_log ();
              foo__res)
         | exception e -> (Debug_runtime.close_log (); raise e))) : int list)
let () = ignore @@ (List.hd @@ (foo 7))
type t = {
  first: int ;
  second: int }[@@deriving sexp]
let bar (x : t) =
  (if Debug_runtime.exceeds_max_children ()
   then
     (Debug_runtime.log_value_show ~descr:"bar"
        ~v:"<max_num_children exceeded>";
      failwith "ppx_minidebug: max_num_children exceeded")
   else
     ((Debug_runtime.open_log_preamble_full ~fname:"test_debug_sexp.ml"
         ~start_lnum:15 ~start_colnum:19 ~end_lnum:17 ~end_colnum:14
         ~message:"bar";
       Debug_runtime.log_value_sexp ~descr:"x" ~sexp:(([%sexp_of : t]) x));
      if Debug_runtime.exceeds_max_nesting ()
      then
        (Debug_runtime.log_value_show ~descr:"bar"
           ~v:"<max_nesting_depth exceeded>";
         Debug_runtime.close_log ();
         failwith "ppx_minidebug: max_nesting_depth exceeded")
      else
        (match let y : int =
                 if Debug_runtime.exceeds_max_children ()
                 then
                   (Debug_runtime.log_value_show ~descr:"y"
                      ~v:"<max_num_children exceeded>";
                    failwith "ppx_minidebug: max_num_children exceeded")
                 else
                   (Debug_runtime.open_log_preamble_brief
                      ~fname:"test_debug_sexp.ml" ~pos_lnum:16 ~pos_colnum:6
                      ~message:"y";
                    if Debug_runtime.exceeds_max_nesting ()
                    then
                      (Debug_runtime.log_value_show ~descr:"y"
                         ~v:"<max_nesting_depth exceeded>";
                       Debug_runtime.close_log ();
                       failwith "ppx_minidebug: max_nesting_depth exceeded")
                    else
                      (match (x.first + 1 : int) with
                       | y__res ->
                           (Debug_runtime.log_value_sexp ~descr:"y"
                              ~sexp:(([%sexp_of : int]) y__res);
                            Debug_runtime.close_log ();
                            y__res)
                       | exception e -> (Debug_runtime.close_log (); raise e))) in
               x.second * y
         with
         | bar__res ->
             (Debug_runtime.log_value_sexp ~descr:"bar"
                ~sexp:(([%sexp_of : int]) bar__res);
              Debug_runtime.close_log ();
              bar__res)
         | exception e -> (Debug_runtime.close_log (); raise e))) : int)
let () = ignore @@ (bar { first = 7; second = 42 })
let baz (x : t) =
  (if Debug_runtime.exceeds_max_children ()
   then
     (Debug_runtime.log_value_show ~descr:"baz"
        ~v:"<max_num_children exceeded>";
      failwith "ppx_minidebug: max_num_children exceeded")
   else
     ((Debug_runtime.open_log_preamble_full ~fname:"test_debug_sexp.ml"
         ~start_lnum:21 ~start_colnum:19 ~end_lnum:24 ~end_colnum:28
         ~message:"baz";
       Debug_runtime.log_value_sexp ~descr:"x" ~sexp:(([%sexp_of : t]) x));
      if Debug_runtime.exceeds_max_nesting ()
      then
        (Debug_runtime.log_value_show ~descr:"baz"
           ~v:"<max_nesting_depth exceeded>";
         Debug_runtime.close_log ();
         failwith "ppx_minidebug: max_nesting_depth exceeded")
      else
        (match let (((y, z) as _yz) : (int * int)) =
                 if Debug_runtime.exceeds_max_children ()
                 then
                   (Debug_runtime.log_value_show ~descr:"_yz"
                      ~v:"<max_num_children exceeded>";
                    failwith "ppx_minidebug: max_num_children exceeded")
                 else
                   (Debug_runtime.open_log_preamble_brief
                      ~fname:"test_debug_sexp.ml" ~pos_lnum:22 ~pos_colnum:17
                      ~message:"_yz";
                    if Debug_runtime.exceeds_max_nesting ()
                    then
                      (Debug_runtime.log_value_show ~descr:"_yz"
                         ~v:"<max_nesting_depth exceeded>";
                       Debug_runtime.close_log ();
                       failwith "ppx_minidebug: max_nesting_depth exceeded")
                    else
                      (match ((x.first + 1), 3) with
                       | _yz__res ->
                           (Debug_runtime.log_value_sexp ~descr:"_yz"
                              ~sexp:(([%sexp_of : (int * int)]) _yz__res);
                            Debug_runtime.close_log ();
                            _yz__res)
                       | exception e -> (Debug_runtime.close_log (); raise e))) in
               let (((u, w) as _uw) : (int * int)) =
                 if Debug_runtime.exceeds_max_children ()
                 then
                   (Debug_runtime.log_value_show ~descr:"_uw"
                      ~v:"<max_num_children exceeded>";
                    failwith "ppx_minidebug: max_num_children exceeded")
                 else
                   (Debug_runtime.open_log_preamble_brief
                      ~fname:"test_debug_sexp.ml" ~pos_lnum:23 ~pos_colnum:17
                      ~message:"_uw";
                    if Debug_runtime.exceeds_max_nesting ()
                    then
                      (Debug_runtime.log_value_show ~descr:"_uw"
                         ~v:"<max_nesting_depth exceeded>";
                       Debug_runtime.close_log ();
                       failwith "ppx_minidebug: max_nesting_depth exceeded")
                    else
                      (match (7, 13) with
                       | _uw__res ->
                           (Debug_runtime.log_value_sexp ~descr:"_uw"
                              ~sexp:(([%sexp_of : (int * int)]) _uw__res);
                            Debug_runtime.close_log ();
                            _uw__res)
                       | exception e -> (Debug_runtime.close_log (); raise e))) in
               (((x.second * y) + z) + u) + w
         with
         | baz__res ->
             (Debug_runtime.log_value_sexp ~descr:"baz"
                ~sexp:(([%sexp_of : int]) baz__res);
              Debug_runtime.close_log ();
              baz__res)
         | exception e -> (Debug_runtime.close_log (); raise e))) : int)
let () = ignore @@ (baz { first = 7; second = 42 })
let lab ~x:(x : int)  =
  (if Debug_runtime.exceeds_max_children ()
   then
     (Debug_runtime.log_value_show ~descr:"lab"
        ~v:"<max_num_children exceeded>";
      failwith "ppx_minidebug: max_num_children exceeded")
   else
     ((Debug_runtime.open_log_preamble_full ~fname:"test_debug_sexp.ml"
         ~start_lnum:28 ~start_colnum:19 ~end_lnum:30 ~end_colnum:17
         ~message:"lab";
       Debug_runtime.log_value_sexp ~descr:"x" ~sexp:(([%sexp_of : int]) x));
      if Debug_runtime.exceeds_max_nesting ()
      then
        (Debug_runtime.log_value_show ~descr:"lab"
           ~v:"<max_nesting_depth exceeded>";
         Debug_runtime.close_log ();
         failwith "ppx_minidebug: max_nesting_depth exceeded")
      else
        (match let y : int =
                 if Debug_runtime.exceeds_max_children ()
                 then
                   (Debug_runtime.log_value_show ~descr:"y"
                      ~v:"<max_num_children exceeded>";
                    failwith "ppx_minidebug: max_num_children exceeded")
                 else
                   (Debug_runtime.open_log_preamble_brief
                      ~fname:"test_debug_sexp.ml" ~pos_lnum:29 ~pos_colnum:6
                      ~message:"y";
                    if Debug_runtime.exceeds_max_nesting ()
                    then
                      (Debug_runtime.log_value_show ~descr:"y"
                         ~v:"<max_nesting_depth exceeded>";
                       Debug_runtime.close_log ();
                       failwith "ppx_minidebug: max_nesting_depth exceeded")
                    else
                      (match (x + 1 : int) with
                       | y__res ->
                           (Debug_runtime.log_value_sexp ~descr:"y"
                              ~sexp:(([%sexp_of : int]) y__res);
                            Debug_runtime.close_log ();
                            y__res)
                       | exception e -> (Debug_runtime.close_log (); raise e))) in
               [x; y; 2 * y]
         with
         | lab__res ->
             (Debug_runtime.log_value_sexp ~descr:"lab"
                ~sexp:(([%sexp_of : int list]) lab__res);
              Debug_runtime.close_log ();
              lab__res)
         | exception e -> (Debug_runtime.close_log (); raise e))) : int list)
let () = ignore @@ (List.hd @@ (lab ~x:7))
let rec loop (depth : int) (x : t) =
  (if Debug_runtime.exceeds_max_children ()
   then
     (Debug_runtime.log_value_show ~descr:"loop"
        ~v:"<max_num_children exceeded>";
      failwith "ppx_minidebug: max_num_children exceeded")
   else
     (((Debug_runtime.open_log_preamble_full ~fname:"test_debug_sexp.ml"
          ~start_lnum:34 ~start_colnum:24 ~end_lnum:40 ~end_colnum:9
          ~message:"loop";
        Debug_runtime.log_value_sexp ~descr:"depth"
          ~sexp:(([%sexp_of : int]) depth));
       Debug_runtime.log_value_sexp ~descr:"x" ~sexp:(([%sexp_of : t]) x));
      if Debug_runtime.exceeds_max_nesting ()
      then
        (Debug_runtime.log_value_show ~descr:"loop"
           ~v:"<max_nesting_depth exceeded>";
         Debug_runtime.close_log ();
         failwith "ppx_minidebug: max_nesting_depth exceeded")
      else
        (match if depth > 4
               then x.first + x.second
               else
                 if depth > 1
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
                           ~fname:"test_debug_sexp.ml" ~pos_lnum:38
                           ~pos_colnum:8 ~message:"y";
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
                                (Debug_runtime.log_value_sexp ~descr:"y"
                                   ~sexp:(([%sexp_of : int]) y__res);
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
                           ~fname:"test_debug_sexp.ml" ~pos_lnum:39
                           ~pos_colnum:8 ~message:"z";
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
                                (Debug_runtime.log_value_sexp ~descr:"z"
                                   ~sexp:(([%sexp_of : int]) z__res);
                                 Debug_runtime.close_log ();
                                 z__res)
                            | exception e ->
                                (Debug_runtime.close_log (); raise e))) in
                    z + 7)
         with
         | loop__res ->
             (Debug_runtime.log_value_sexp ~descr:"loop"
                ~sexp:(([%sexp_of : int]) loop__res);
              Debug_runtime.close_log ();
              loop__res)
         | exception e -> (Debug_runtime.close_log (); raise e))) : int)
let () = ignore @@ (loop 0 { first = 7; second = 42 })
