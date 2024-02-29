type t = { first : int; second : int } [@@deriving show]

let sexp_of_string s = Sexplib0.Sexp.Atom s
let sexp_of_list f l = Sexplib0.Sexp.List (List.map f l)
let sexp_of_unit () = Sexplib0.Sexp.List []
let sexp_of_int i = Sexplib0.Sexp.Atom (string_of_int i)
let sexp_of_float n = Sexplib0.Sexp.Atom (string_of_float n)

let%expect_test "%debug_this_show flushing to a file" =
  let module Debug_runtime =
    (val Minidebug_runtime.debug_flushing
           ~filename:"../../../debugger_expect_show_flushing" ())
  in
  let%debug_this_show rec loop (depth : int) (x : t) : int =
    if depth > 6 then x.first + x.second
    else if depth > 3 then loop (depth + 1) { first = x.second + 1; second = x.first / 2 }
    else
      let y : int = loop (depth + 1) { first = x.second - 1; second = x.first + 2 } in
      let z : int = loop (depth + 1) { first = x.second + 1; second = y } in
      z + 7
  in
  print_endline @@ Int.to_string @@ loop 0 { first = 7; second = 42 };
  [%expect {| 56 |}]

let%expect_test "%debug_show flushing to stdout" =
  let module Debug_runtime = (val Minidebug_runtime.debug_flushing ~time_tagged:`Clock ())
  in
  let%debug_show bar (x : t) : int =
    let y : int = x.first + 1 in
    x.second * y
  in
  let () = print_endline @@ Int.to_string @@ bar { first = 7; second = 42 } in
  let baz (x : t) : int =
    let ((y, z) as _yz) : int * int = (x.first + 1, 3) in
    (x.second * y) + z
  in
  let () = print_endline @@ Int.to_string @@ baz { first = 7; second = 42 } in
  let output = [%expect.output] in
  let output =
    Str.global_replace
      (Str.regexp
         {|[0-9]+-[0-9]+-[0-9]+ [0-9]+:[0-9]+:[0-9]+\.[0-9]+\( \+[0-9]+:[0-9]+\)?|})
      "YYYY-MM-DD HH:MM:SS.NNNNNN" output
  in
  print_endline output;
  [%expect
    {|
    BEGIN DEBUG SESSION at time YYYY-MM-DD HH:MM:SS.NNNNNN
    bar begin "test/test_expect_test.ml":28:21: YYYY-MM-DD HH:MM:SS.NNNNNN
     x = { Test_expect_test.first = 7; second = 42 }
     y begin "test/test_expect_test.ml":29:8: YYYY-MM-DD HH:MM:SS.NNNNNN
      y = 8
     YYYY-MM-DD HH:MM:SS.NNNNNN - y end
     bar = 336
    YYYY-MM-DD HH:MM:SS.NNNNNN - bar end
    336
    baz begin "test/test_expect_test.ml":33:10: YYYY-MM-DD HH:MM:SS.NNNNNN
     x = { Test_expect_test.first = 7; second = 42 }
     _yz begin "test/test_expect_test.ml":34:19: YYYY-MM-DD HH:MM:SS.NNNNNN
      _yz = (8, 3)
     YYYY-MM-DD HH:MM:SS.NNNNNN - _yz end
     baz = 339
    YYYY-MM-DD HH:MM:SS.NNNNNN - baz end
    339 |}]

let%expect_test "%debug_show flushing to stdout, time spans" =
  let module Debug_runtime =
    (val Minidebug_runtime.debug_flushing ~elapsed_times:Microseconds ())
  in
  let%debug_show bar (x : t) : int =
    let y : int = x.first + 1 in
    x.second * y
  in
  let () = print_endline @@ Int.to_string @@ bar { first = 7; second = 42 } in
  let baz (x : t) : int =
    let ((y, z) as _yz) : int * int = (x.first + 1, 3) in
    (x.second * y) + z
  in
  let () = print_endline @@ Int.to_string @@ baz { first = 7; second = 42 } in
  let output = [%expect.output] in
  let output =
    Str.global_replace (Str.regexp {|[0-9]+?[0-9]+.[0-9]+[0-9]+μs|}) "N.NNμs" output
  in
  print_endline output;
  [%expect
    {|
    BEGIN DEBUG SESSION
    bar begin "test/test_expect_test.ml":70:21:
     x = { Test_expect_test.first = 7; second = 42 }
     y begin "test/test_expect_test.ml":71:8:
      y = 8
     <N.NNμs> y end
     bar = 336
    <N.NNμs> bar end
    336
    baz begin "test/test_expect_test.ml":75:10:
     x = { Test_expect_test.first = 7; second = 42 }
     _yz begin "test/test_expect_test.ml":76:19:
      _yz = (8, 3)
     <N.NNμs> _yz end
     baz = 339
    <N.NNμs> baz end
    339 |}]

let%expect_test "%debug_show flushing with global prefix" =
  let module Debug_runtime =
    (val Minidebug_runtime.debug_flushing ~time_tagged:`None ~global_prefix:"test-51" ())
  in
  let%debug_show bar (x : t) : int =
    let y : int = x.first + 1 in
    x.second * y
  in
  let () = print_endline @@ Int.to_string @@ bar { first = 7; second = 42 } in
  let baz (x : t) : int =
    let ((y, z) as _yz) : int * int = (x.first + 1, 3) in
    (x.second * y) + z
  in
  let () = print_endline @@ Int.to_string @@ baz { first = 7; second = 42 } in
  let output = [%expect.output] in
  print_endline output;
  [%expect
    {|
    BEGIN DEBUG SESSION test-51
    test-51 bar begin "test/test_expect_test.ml":109:21:
     x = { Test_expect_test.first = 7; second = 42 }
     test-51 y begin "test/test_expect_test.ml":110:8:
      y = 8
     test-51 y end
     bar = 336
    test-51 bar end
    336
    test-51 baz begin "test/test_expect_test.ml":114:10:
     x = { Test_expect_test.first = 7; second = 42 }
     test-51 _yz begin "test/test_expect_test.ml":115:19:
      _yz = (8, 3)
     test-51 _yz end
     baz = 339
    test-51 baz end
    339 |}]

let%expect_test "%debug_this_show disabled subtree" =
  let module Debug_runtime = (val Minidebug_runtime.debug ()) in
  let%debug_this_show rec loop_complete (x : int) : int =
    let z : int = (x - 1) / 2 in
    if x <= 0 then 0 else z + loop_complete (z + (x / 2))
  in
  let () = print_endline @@ Int.to_string @@ loop_complete 7 in
  [%expect
    {|
    BEGIN DEBUG SESSION
    "test/test_expect_test.ml":143:40: loop_complete
    ├─x = 7
    ├─"test/test_expect_test.ml":144:8: z
    │ └─z = 3
    ├─"test/test_expect_test.ml":143:40: loop_complete
    │ ├─x = 6
    │ ├─"test/test_expect_test.ml":144:8: z
    │ │ └─z = 2
    │ ├─"test/test_expect_test.ml":143:40: loop_complete
    │ │ ├─x = 5
    │ │ ├─"test/test_expect_test.ml":144:8: z
    │ │ │ └─z = 2
    │ │ ├─"test/test_expect_test.ml":143:40: loop_complete
    │ │ │ ├─x = 4
    │ │ │ ├─"test/test_expect_test.ml":144:8: z
    │ │ │ │ └─z = 1
    │ │ │ ├─"test/test_expect_test.ml":143:40: loop_complete
    │ │ │ │ ├─x = 3
    │ │ │ │ ├─"test/test_expect_test.ml":144:8: z
    │ │ │ │ │ └─z = 1
    │ │ │ │ ├─"test/test_expect_test.ml":143:40: loop_complete
    │ │ │ │ │ ├─x = 2
    │ │ │ │ │ ├─"test/test_expect_test.ml":144:8: z
    │ │ │ │ │ │ └─z = 0
    │ │ │ │ │ ├─"test/test_expect_test.ml":143:40: loop_complete
    │ │ │ │ │ │ ├─x = 1
    │ │ │ │ │ │ ├─"test/test_expect_test.ml":144:8: z
    │ │ │ │ │ │ │ └─z = 0
    │ │ │ │ │ │ ├─"test/test_expect_test.ml":143:40: loop_complete
    │ │ │ │ │ │ │ ├─x = 0
    │ │ │ │ │ │ │ ├─"test/test_expect_test.ml":144:8: z
    │ │ │ │ │ │ │ │ └─z = 0
    │ │ │ │ │ │ │ └─loop_complete = 0
    │ │ │ │ │ │ └─loop_complete = 0
    │ │ │ │ │ └─loop_complete = 0
    │ │ │ │ └─loop_complete = 1
    │ │ │ └─loop_complete = 2
    │ │ └─loop_complete = 4
    │ └─loop_complete = 6
    └─loop_complete = 9
    9 |}];
  let%debug_this_show rec loop_changes (x : int) : int =
    let z : int = (x - 1) / 2 in
    (* The call [x = 2] is not printed because it is a descendant of the no-debug call [x = 4]. *)
    Debug_runtime.no_debug_if (x <> 6 && x <> 2 && (z + 1) * 2 = x);
    if x <= 0 then 0 else z + loop_changes (z + (x / 2))
  in
  let () = print_endline @@ Int.to_string @@ loop_changes 7 in
  [%expect
    {|
  "test/test_expect_test.ml":192:39: loop_changes
  ├─x = 7
  ├─"test/test_expect_test.ml":193:8: z
  │ └─z = 3
  ├─"test/test_expect_test.ml":192:39: loop_changes
  │ ├─x = 6
  │ ├─"test/test_expect_test.ml":193:8: z
  │ │ └─z = 2
  │ ├─"test/test_expect_test.ml":192:39: loop_changes
  │ │ ├─x = 5
  │ │ ├─"test/test_expect_test.ml":193:8: z
  │ │ │ └─z = 2
  │ │ └─loop_changes = 4
  │ └─loop_changes = 6
  └─loop_changes = 9
  9 |}]

let%expect_test "%debug_this_show with exception" =
  let module Debug_runtime = (val Minidebug_runtime.debug ()) in
  let%debug_this_show rec loop_truncated (x : int) : int =
    let z : int = (x - 1) / 2 in
    if x <= 0 then failwith "the log as for loop_complete but without return values";
    z + loop_truncated (z + (x / 2))
  in
  let () =
    try print_endline @@ Int.to_string @@ loop_truncated 7
    with _ -> print_endline "Raised exception."
  in
  [%expect
    {|
    BEGIN DEBUG SESSION
    "test/test_expect_test.ml":220:41: loop_truncated
    ├─x = 7
    ├─"test/test_expect_test.ml":221:8: z
    │ └─z = 3
    └─"test/test_expect_test.ml":220:41: loop_truncated
      ├─x = 6
      ├─"test/test_expect_test.ml":221:8: z
      │ └─z = 2
      └─"test/test_expect_test.ml":220:41: loop_truncated
        ├─x = 5
        ├─"test/test_expect_test.ml":221:8: z
        │ └─z = 2
        └─"test/test_expect_test.ml":220:41: loop_truncated
          ├─x = 4
          ├─"test/test_expect_test.ml":221:8: z
          │ └─z = 1
          └─"test/test_expect_test.ml":220:41: loop_truncated
            ├─x = 3
            ├─"test/test_expect_test.ml":221:8: z
            │ └─z = 1
            └─"test/test_expect_test.ml":220:41: loop_truncated
              ├─x = 2
              ├─"test/test_expect_test.ml":221:8: z
              │ └─z = 0
              └─"test/test_expect_test.ml":220:41: loop_truncated
                ├─x = 1
                ├─"test/test_expect_test.ml":221:8: z
                │ └─z = 0
                └─"test/test_expect_test.ml":220:41: loop_truncated
                  ├─x = 0
                  └─"test/test_expect_test.ml":221:8: z
                    └─z = 0
    Raised exception. |}]

let%expect_test "%debug_this_show depth exceeded" =
  let module Debug_runtime = (val Minidebug_runtime.debug ()) in
  let%debug_this_show rec loop_exceeded (x : int) : int =
    [%debug_interrupts
      { max_nesting_depth = 5; max_num_children = 1000 };
      let z : int = (x - 1) / 2 in
      if x <= 0 then 0 else z + loop_exceeded (z + (x / 2))]
  in
  let () =
    try print_endline @@ Int.to_string @@ loop_exceeded 7
    with _ -> print_endline "Raised exception."
  in
  [%expect
    {|
      BEGIN DEBUG SESSION
      "test/test_expect_test.ml":268:40: loop_exceeded
      ├─x = 7
      ├─"test/test_expect_test.ml":271:10: z
      │ └─z = 3
      └─"test/test_expect_test.ml":268:40: loop_exceeded
        ├─x = 6
        ├─"test/test_expect_test.ml":271:10: z
        │ └─z = 2
        └─"test/test_expect_test.ml":268:40: loop_exceeded
          ├─x = 5
          ├─"test/test_expect_test.ml":271:10: z
          │ └─z = 2
          └─"test/test_expect_test.ml":268:40: loop_exceeded
            ├─x = 4
            ├─"test/test_expect_test.ml":271:10: z
            │ └─z = 1
            └─"test/test_expect_test.ml":268:40: loop_exceeded
              ├─x = 3
              └─"test/test_expect_test.ml":271:10: z
                └─z = <max_nesting_depth exceeded>
      Raised exception. |}]

let%expect_test "%debug_this_show num children exceeded linear" =
  let module Debug_runtime = (val Minidebug_runtime.debug ()) in
  let () =
    try
      let%debug_this_show _bar : unit =
        [%debug_interrupts
          { max_nesting_depth = 1000; max_num_children = 10 };
          for i = 0 to 100 do
            let _baz : int = i * 2 in
            ()
          done]
      in
      ()
    with Failure s -> print_endline @@ "Raised exception: " ^ s
  in
  [%expect
    {|
    BEGIN DEBUG SESSION
    "test/test_expect_test.ml":307:26: _bar
    ├─"test/test_expect_test.ml":311:16: _baz
    │ └─_baz = 0
    ├─"test/test_expect_test.ml":311:16: _baz
    │ └─_baz = 2
    ├─"test/test_expect_test.ml":311:16: _baz
    │ └─_baz = 4
    ├─"test/test_expect_test.ml":311:16: _baz
    │ └─_baz = 6
    ├─"test/test_expect_test.ml":311:16: _baz
    │ └─_baz = 8
    ├─"test/test_expect_test.ml":311:16: _baz
    │ └─_baz = 10
    ├─"test/test_expect_test.ml":311:16: _baz
    │ └─_baz = 12
    ├─"test/test_expect_test.ml":311:16: _baz
    │ └─_baz = 14
    ├─"test/test_expect_test.ml":311:16: _baz
    │ └─_baz = 16
    ├─"test/test_expect_test.ml":311:16: _baz
    │ └─_baz = 18
    ├─"test/test_expect_test.ml":311:16: _baz
    │ └─_baz = 20
    └─_baz = <max_num_children exceeded>
    Raised exception: ppx_minidebug: max_num_children exceeded |}]

let%expect_test "%debug_this_show truncated children linear" =
  let module Debug_runtime = (val Minidebug_runtime.debug ~truncate_children:10 ()) in
  let () =
    try
      let%debug_this_show _bar : unit =
        for i = 0 to 30 do
          let _baz : int = i * 2 in
          ()
        done
      in
      ()
    with Failure s -> print_endline @@ "Raised exception: " ^ s
  in
  [%expect
    {|
    BEGIN DEBUG SESSION
    "test/test_expect_test.ml":351:26: _bar
    ├─<earlier entries truncated>
    ├─"test/test_expect_test.ml":353:14: _baz
    │ └─_baz = 44
    ├─"test/test_expect_test.ml":353:14: _baz
    │ └─_baz = 46
    ├─"test/test_expect_test.ml":353:14: _baz
    │ └─_baz = 48
    ├─"test/test_expect_test.ml":353:14: _baz
    │ └─_baz = 50
    ├─"test/test_expect_test.ml":353:14: _baz
    │ └─_baz = 52
    ├─"test/test_expect_test.ml":353:14: _baz
    │ └─_baz = 54
    ├─"test/test_expect_test.ml":353:14: _baz
    │ └─_baz = 56
    ├─"test/test_expect_test.ml":353:14: _baz
    │ └─_baz = 58
    ├─"test/test_expect_test.ml":353:14: _baz
    │ └─_baz = 60
    └─_bar = () |}]

let%expect_test "%track_this_show track for-loop num children exceeded" =
  let module Debug_runtime = (val Minidebug_runtime.debug ()) in
  let () =
    try
      let%track_this_show _bar : unit =
        [%debug_interrupts
          { max_nesting_depth = 1000; max_num_children = 10 };
          for i = 0 to 100 do
            let _baz : int = i * 2 in
            ()
          done]
      in
      ()
    with Failure s -> print_endline @@ "Raised exception: " ^ s
  in
  [%expect
    {|
    BEGIN DEBUG SESSION
    "test/test_expect_test.ml":389:26: _bar
    └─"test/test_expect_test.ml":392:10: for:test_expect_test:392
      ├─i = 0
      ├─"test/test_expect_test.ml":392:14: <for i>
      │ └─"test/test_expect_test.ml":393:16: _baz
      │   └─_baz = 0
      ├─i = 1
      ├─"test/test_expect_test.ml":392:14: <for i>
      │ └─"test/test_expect_test.ml":393:16: _baz
      │   └─_baz = 2
      ├─i = 2
      ├─"test/test_expect_test.ml":392:14: <for i>
      │ └─"test/test_expect_test.ml":393:16: _baz
      │   └─_baz = 4
      ├─i = 3
      ├─"test/test_expect_test.ml":392:14: <for i>
      │ └─"test/test_expect_test.ml":393:16: _baz
      │   └─_baz = 6
      ├─i = 4
      ├─"test/test_expect_test.ml":392:14: <for i>
      │ └─"test/test_expect_test.ml":393:16: _baz
      │   └─_baz = 8
      ├─i = 5
      └─i = <max_num_children exceeded>
    Raised exception: ppx_minidebug: max_num_children exceeded |}]

let%expect_test "%track_this_show track for-loop truncated children" =
  let module Debug_runtime = (val Minidebug_runtime.debug ~truncate_children:10 ()) in
  let () =
    try
      let%track_this_show _bar : unit =
        for i = 0 to 30 do
          let _baz : int = i * 2 in
          ()
        done
      in
      ()
    with Failure s -> print_endline @@ "Raised exception: " ^ s
  in
  [%expect
    {|
    BEGIN DEBUG SESSION
    "test/test_expect_test.ml":433:26: _bar
    ├─"test/test_expect_test.ml":434:8: for:test_expect_test:434
    │ ├─<earlier entries truncated>
    │ ├─i = 26
    │ ├─"test/test_expect_test.ml":434:12: <for i>
    │ │ └─"test/test_expect_test.ml":435:14: _baz
    │ │   └─_baz = 52
    │ ├─i = 27
    │ ├─"test/test_expect_test.ml":434:12: <for i>
    │ │ └─"test/test_expect_test.ml":435:14: _baz
    │ │   └─_baz = 54
    │ ├─i = 28
    │ ├─"test/test_expect_test.ml":434:12: <for i>
    │ │ └─"test/test_expect_test.ml":435:14: _baz
    │ │   └─_baz = 56
    │ ├─i = 29
    │ ├─"test/test_expect_test.ml":434:12: <for i>
    │ │ └─"test/test_expect_test.ml":435:14: _baz
    │ │   └─_baz = 58
    │ ├─i = 30
    │ └─"test/test_expect_test.ml":434:12: <for i>
    │   └─"test/test_expect_test.ml":435:14: _baz
    │     └─_baz = 60
    └─_bar = () |}]

let%expect_test "%track_this_show track for-loop" =
  let module Debug_runtime = (val Minidebug_runtime.debug ()) in
  let () =
    try
      let%track_this_show _bar : unit =
        [%debug_interrupts
          { max_nesting_depth = 1000; max_num_children = 1000 };
          for i = 0 to 6 do
            let _baz : int = i * 2 in
            ()
          done]
      in
      ()
    with Failure s -> print_endline @@ "Raised exception: " ^ s
  in
  [%expect
    {|
      BEGIN DEBUG SESSION
      "test/test_expect_test.ml":474:26: _bar
      ├─"test/test_expect_test.ml":477:10: for:test_expect_test:477
      │ ├─i = 0
      │ ├─"test/test_expect_test.ml":477:14: <for i>
      │ │ └─"test/test_expect_test.ml":478:16: _baz
      │ │   └─_baz = 0
      │ ├─i = 1
      │ ├─"test/test_expect_test.ml":477:14: <for i>
      │ │ └─"test/test_expect_test.ml":478:16: _baz
      │ │   └─_baz = 2
      │ ├─i = 2
      │ ├─"test/test_expect_test.ml":477:14: <for i>
      │ │ └─"test/test_expect_test.ml":478:16: _baz
      │ │   └─_baz = 4
      │ ├─i = 3
      │ ├─"test/test_expect_test.ml":477:14: <for i>
      │ │ └─"test/test_expect_test.ml":478:16: _baz
      │ │   └─_baz = 6
      │ ├─i = 4
      │ ├─"test/test_expect_test.ml":477:14: <for i>
      │ │ └─"test/test_expect_test.ml":478:16: _baz
      │ │   └─_baz = 8
      │ ├─i = 5
      │ ├─"test/test_expect_test.ml":477:14: <for i>
      │ │ └─"test/test_expect_test.ml":478:16: _baz
      │ │   └─_baz = 10
      │ ├─i = 6
      │ └─"test/test_expect_test.ml":477:14: <for i>
      │   └─"test/test_expect_test.ml":478:16: _baz
      │     └─_baz = 12
      └─_bar = () |}]

let%expect_test "%track_this_show track for-loop, time spans" =
  let module Debug_runtime = (val Minidebug_runtime.debug ~elapsed_times:Microseconds ())
  in
  let () =
    try
      let%track_this_show _bar : unit =
        [%debug_interrupts
          { max_nesting_depth = 1000; max_num_children = 1000 };
          for i = 0 to 6 do
            let _baz : int = i * 2 in
            ()
          done]
      in
      ()
    with Failure s -> print_endline @@ "Raised exception: " ^ s
  in
  let output = [%expect.output] in
  let output =
    Str.global_replace (Str.regexp {|[0-9]+?[0-9]+.[0-9]+[0-9]+μs|}) "N.NNμs" output
  in
  print_endline output;
  [%expect
    {|
      BEGIN DEBUG SESSION
      "test/test_expect_test.ml":525:26: _bar <N.NNμs>
      ├─"test/test_expect_test.ml":528:10: for:test_expect_test:528 <N.NNμs>
      │ ├─i = 0
      │ ├─"test/test_expect_test.ml":528:14: <for i> <N.NNμs>
      │ │ └─"test/test_expect_test.ml":529:16: _baz <N.NNμs>
      │ │   └─_baz = 0
      │ ├─i = 1
      │ ├─"test/test_expect_test.ml":528:14: <for i> <N.NNμs>
      │ │ └─"test/test_expect_test.ml":529:16: _baz <N.NNμs>
      │ │   └─_baz = 2
      │ ├─i = 2
      │ ├─"test/test_expect_test.ml":528:14: <for i> <N.NNμs>
      │ │ └─"test/test_expect_test.ml":529:16: _baz <N.NNμs>
      │ │   └─_baz = 4
      │ ├─i = 3
      │ ├─"test/test_expect_test.ml":528:14: <for i> <N.NNμs>
      │ │ └─"test/test_expect_test.ml":529:16: _baz <N.NNμs>
      │ │   └─_baz = 6
      │ ├─i = 4
      │ ├─"test/test_expect_test.ml":528:14: <for i> <N.NNμs>
      │ │ └─"test/test_expect_test.ml":529:16: _baz <N.NNμs>
      │ │   └─_baz = 8
      │ ├─i = 5
      │ ├─"test/test_expect_test.ml":528:14: <for i> <N.NNμs>
      │ │ └─"test/test_expect_test.ml":529:16: _baz <N.NNμs>
      │ │   └─_baz = 10
      │ ├─i = 6
      │ └─"test/test_expect_test.ml":528:14: <for i> <N.NNμs>
      │   └─"test/test_expect_test.ml":529:16: _baz <N.NNμs>
      │     └─_baz = 12
      └─_bar = () |}]

let%expect_test "%track_this_show track while-loop" =
  let module Debug_runtime = (val Minidebug_runtime.debug ()) in
  let () =
    try
      let%track_this_show _bar : unit =
        let i = ref 0 in
        while !i < 6 do
          let _baz : int = !i * 2 in
          incr i
        done
      in
      ()
    with Failure s -> print_endline @@ "Raised exception: " ^ s
  in
  [%expect
    {|
    BEGIN DEBUG SESSION
    "test/test_expect_test.ml":580:26: _bar
    ├─"test/test_expect_test.ml":582:8: while:test_expect_test:582
    │ ├─"test/test_expect_test.ml":583:10: <while loop>
    │ │ └─"test/test_expect_test.ml":583:14: _baz
    │ │   └─_baz = 0
    │ ├─"test/test_expect_test.ml":583:10: <while loop>
    │ │ └─"test/test_expect_test.ml":583:14: _baz
    │ │   └─_baz = 2
    │ ├─"test/test_expect_test.ml":583:10: <while loop>
    │ │ └─"test/test_expect_test.ml":583:14: _baz
    │ │   └─_baz = 4
    │ ├─"test/test_expect_test.ml":583:10: <while loop>
    │ │ └─"test/test_expect_test.ml":583:14: _baz
    │ │   └─_baz = 6
    │ ├─"test/test_expect_test.ml":583:10: <while loop>
    │ │ └─"test/test_expect_test.ml":583:14: _baz
    │ │   └─_baz = 8
    │ └─"test/test_expect_test.ml":583:10: <while loop>
    │   └─"test/test_expect_test.ml":583:14: _baz
    │     └─_baz = 10
    └─_bar = ()
        |}]

let%expect_test "%debug_this_show num children exceeded nested" =
  let module Debug_runtime = (val Minidebug_runtime.debug ()) in
  let%debug_this_show rec loop_exceeded (x : int) : int =
    [%debug_interrupts
      { max_nesting_depth = 1000; max_num_children = 10 };
      Array.fold_left ( + ) 0
      @@ Array.init
           (100 / (x + 1))
           (fun i ->
             let z : int = i + ((x - 1) / 2) in
             if x <= 0 then i else i + loop_exceeded (z + (x / 2) - i))]
  in
  let () =
    try print_endline @@ Int.to_string @@ loop_exceeded 3
    with Failure s -> print_endline @@ "Raised exception: " ^ s
  in
  [%expect
    {|
      BEGIN DEBUG SESSION
      "test/test_expect_test.ml":618:40: loop_exceeded
      ├─x = 3
      ├─"test/test_expect_test.ml":625:17: z
      │ └─z = 1
      └─"test/test_expect_test.ml":618:40: loop_exceeded
        ├─x = 2
        ├─"test/test_expect_test.ml":625:17: z
        │ └─z = 0
        └─"test/test_expect_test.ml":618:40: loop_exceeded
          ├─x = 1
          ├─"test/test_expect_test.ml":625:17: z
          │ └─z = 0
          └─"test/test_expect_test.ml":618:40: loop_exceeded
            ├─x = 0
            ├─"test/test_expect_test.ml":625:17: z
            │ └─z = 0
            ├─"test/test_expect_test.ml":625:17: z
            │ └─z = 1
            ├─"test/test_expect_test.ml":625:17: z
            │ └─z = 2
            ├─"test/test_expect_test.ml":625:17: z
            │ └─z = 3
            ├─"test/test_expect_test.ml":625:17: z
            │ └─z = 4
            ├─"test/test_expect_test.ml":625:17: z
            │ └─z = 5
            ├─"test/test_expect_test.ml":625:17: z
            │ └─z = 6
            ├─"test/test_expect_test.ml":625:17: z
            │ └─z = 7
            ├─"test/test_expect_test.ml":625:17: z
            │ └─z = 8
            ├─"test/test_expect_test.ml":625:17: z
            │ └─z = 9
            └─z = <max_num_children exceeded>
      Raised exception: ppx_minidebug: max_num_children exceeded |}]

let%expect_test "%debug_this_show truncated children nested" =
  let module Debug_runtime = (val Minidebug_runtime.debug ~truncate_children:4 ()) in
  let%debug_this_show rec loop_exceeded (x : int) : int =
    Array.fold_left ( + ) 0
    @@ Array.init
         (20 / (x + 1))
         (fun i ->
           let z : int = i + ((x - 1) / 2) in
           if x <= 0 then i else i + loop_exceeded (z + (x / 2) - i))
  in
  let () =
    try print_endline @@ Int.to_string @@ loop_exceeded 3
    with Failure s -> print_endline @@ "Raised exception: " ^ s
  in
  [%expect
    {|
      BEGIN DEBUG SESSION
      "test/test_expect_test.ml":674:40: loop_exceeded
      ├─<earlier entries truncated>
      ├─"test/test_expect_test.ml":674:40: loop_exceeded
      │ ├─<earlier entries truncated>
      │ ├─"test/test_expect_test.ml":674:40: loop_exceeded
      │ │ ├─<earlier entries truncated>
      │ │ ├─"test/test_expect_test.ml":674:40: loop_exceeded
      │ │ │ ├─<earlier entries truncated>
      │ │ │ ├─"test/test_expect_test.ml":679:15: z
      │ │ │ │ └─z = 17
      │ │ │ ├─"test/test_expect_test.ml":679:15: z
      │ │ │ │ └─z = 18
      │ │ │ ├─"test/test_expect_test.ml":679:15: z
      │ │ │ │ └─z = 19
      │ │ │ └─loop_exceeded = 190
      │ │ ├─"test/test_expect_test.ml":679:15: z
      │ │ │ └─z = 9
      │ │ ├─"test/test_expect_test.ml":674:40: loop_exceeded
      │ │ │ ├─<earlier entries truncated>
      │ │ │ ├─"test/test_expect_test.ml":679:15: z
      │ │ │ │ └─z = 17
      │ │ │ ├─"test/test_expect_test.ml":679:15: z
      │ │ │ │ └─z = 18
      │ │ │ ├─"test/test_expect_test.ml":679:15: z
      │ │ │ │ └─z = 19
      │ │ │ └─loop_exceeded = 190
      │ │ └─loop_exceeded = 1945
      │ ├─"test/test_expect_test.ml":679:15: z
      │ │ └─z = 5
      │ ├─"test/test_expect_test.ml":674:40: loop_exceeded
      │ │ ├─<earlier entries truncated>
      │ │ ├─"test/test_expect_test.ml":674:40: loop_exceeded
      │ │ │ ├─<earlier entries truncated>
      │ │ │ ├─"test/test_expect_test.ml":679:15: z
      │ │ │ │ └─z = 17
      │ │ │ ├─"test/test_expect_test.ml":679:15: z
      │ │ │ │ └─z = 18
      │ │ │ ├─"test/test_expect_test.ml":679:15: z
      │ │ │ │ └─z = 19
      │ │ │ └─loop_exceeded = 190
      │ │ ├─"test/test_expect_test.ml":679:15: z
      │ │ │ └─z = 9
      │ │ ├─"test/test_expect_test.ml":674:40: loop_exceeded
      │ │ │ ├─<earlier entries truncated>
      │ │ │ ├─"test/test_expect_test.ml":679:15: z
      │ │ │ │ └─z = 17
      │ │ │ ├─"test/test_expect_test.ml":679:15: z
      │ │ │ │ └─z = 18
      │ │ │ ├─"test/test_expect_test.ml":679:15: z
      │ │ │ │ └─z = 19
      │ │ │ └─loop_exceeded = 190
      │ │ └─loop_exceeded = 1945
      │ └─loop_exceeded = 11685
      ├─"test/test_expect_test.ml":679:15: z
      │ └─z = 5
      ├─"test/test_expect_test.ml":674:40: loop_exceeded
      │ ├─<earlier entries truncated>
      │ ├─"test/test_expect_test.ml":674:40: loop_exceeded
      │ │ ├─<earlier entries truncated>
      │ │ ├─"test/test_expect_test.ml":674:40: loop_exceeded
      │ │ │ ├─<earlier entries truncated>
      │ │ │ ├─"test/test_expect_test.ml":679:15: z
      │ │ │ │ └─z = 17
      │ │ │ ├─"test/test_expect_test.ml":679:15: z
      │ │ │ │ └─z = 18
      │ │ │ ├─"test/test_expect_test.ml":679:15: z
      │ │ │ │ └─z = 19
      │ │ │ └─loop_exceeded = 190
      │ │ ├─"test/test_expect_test.ml":679:15: z
      │ │ │ └─z = 9
      │ │ ├─"test/test_expect_test.ml":674:40: loop_exceeded
      │ │ │ ├─<earlier entries truncated>
      │ │ │ ├─"test/test_expect_test.ml":679:15: z
      │ │ │ │ └─z = 17
      │ │ │ ├─"test/test_expect_test.ml":679:15: z
      │ │ │ │ └─z = 18
      │ │ │ ├─"test/test_expect_test.ml":679:15: z
      │ │ │ │ └─z = 19
      │ │ │ └─loop_exceeded = 190
      │ │ └─loop_exceeded = 1945
      │ ├─"test/test_expect_test.ml":679:15: z
      │ │ └─z = 5
      │ ├─"test/test_expect_test.ml":674:40: loop_exceeded
      │ │ ├─<earlier entries truncated>
      │ │ ├─"test/test_expect_test.ml":674:40: loop_exceeded
      │ │ │ ├─<earlier entries truncated>
      │ │ │ ├─"test/test_expect_test.ml":679:15: z
      │ │ │ │ └─z = 17
      │ │ │ ├─"test/test_expect_test.ml":679:15: z
      │ │ │ │ └─z = 18
      │ │ │ ├─"test/test_expect_test.ml":679:15: z
      │ │ │ │ └─z = 19
      │ │ │ └─loop_exceeded = 190
      │ │ ├─"test/test_expect_test.ml":679:15: z
      │ │ │ └─z = 9
      │ │ ├─"test/test_expect_test.ml":674:40: loop_exceeded
      │ │ │ ├─<earlier entries truncated>
      │ │ │ ├─"test/test_expect_test.ml":679:15: z
      │ │ │ │ └─z = 17
      │ │ │ ├─"test/test_expect_test.ml":679:15: z
      │ │ │ │ └─z = 18
      │ │ │ ├─"test/test_expect_test.ml":679:15: z
      │ │ │ │ └─z = 19
      │ │ │ └─loop_exceeded = 190
      │ │ └─loop_exceeded = 1945
      │ └─loop_exceeded = 11685
      └─loop_exceeded = 58435
      58435 |}]

let%expect_test "%track_this_show highlight" =
  let module Debug_runtime =
    (val Minidebug_runtime.debug ~highlight_terms:(Re.str "3") ())
  in
  let%debug_this_show rec loop_highlight (x : int) : int =
    [%debug_interrupts
      { max_nesting_depth = 1000; max_num_children = 1000 };
      let z : int = (x - 1) / 2 in
      if x <= 0 then 0 else z + loop_highlight (z + (x / 2))]
  in
  print_endline @@ Int.to_string @@ loop_highlight 7;
  [%expect
    {|
      BEGIN DEBUG SESSION
      ┌─────────────────────────────────────────────────┐
      │"test/test_expect_test.ml":802:41: loop_highlight│
      ├─────────────────────────────────────────────────┘
      ├─x = 7
      ├─┬────────────────────────────────────┐
      │ │"test/test_expect_test.ml":805:10: z│
      │ ├────────────────────────────────────┘
      │ └─┬─────┐
      │   │z = 3│
      │   └─────┘
      ├─┬─────────────────────────────────────────────────┐
      │ │"test/test_expect_test.ml":802:41: loop_highlight│
      │ ├─────────────────────────────────────────────────┘
      │ ├─x = 6
      │ ├─"test/test_expect_test.ml":805:10: z
      │ │ └─z = 2
      │ ├─┬─────────────────────────────────────────────────┐
      │ │ │"test/test_expect_test.ml":802:41: loop_highlight│
      │ │ ├─────────────────────────────────────────────────┘
      │ │ ├─x = 5
      │ │ ├─"test/test_expect_test.ml":805:10: z
      │ │ │ └─z = 2
      │ │ ├─┬─────────────────────────────────────────────────┐
      │ │ │ │"test/test_expect_test.ml":802:41: loop_highlight│
      │ │ │ ├─────────────────────────────────────────────────┘
      │ │ │ ├─x = 4
      │ │ │ ├─"test/test_expect_test.ml":805:10: z
      │ │ │ │ └─z = 1
      │ │ │ ├─┬─────────────────────────────────────────────────┐
      │ │ │ │ │"test/test_expect_test.ml":802:41: loop_highlight│
      │ │ │ │ ├─────────────────────────────────────────────────┘
      │ │ │ │ ├─┬─────┐
      │ │ │ │ │ │x = 3│
      │ │ │ │ │ └─────┘
      │ │ │ │ ├─"test/test_expect_test.ml":805:10: z
      │ │ │ │ │ └─z = 1
      │ │ │ │ ├─"test/test_expect_test.ml":802:41: loop_highlight
      │ │ │ │ │ ├─x = 2
      │ │ │ │ │ ├─"test/test_expect_test.ml":805:10: z
      │ │ │ │ │ │ └─z = 0
      │ │ │ │ │ ├─"test/test_expect_test.ml":802:41: loop_highlight
      │ │ │ │ │ │ ├─x = 1
      │ │ │ │ │ │ ├─"test/test_expect_test.ml":805:10: z
      │ │ │ │ │ │ │ └─z = 0
      │ │ │ │ │ │ ├─"test/test_expect_test.ml":802:41: loop_highlight
      │ │ │ │ │ │ │ ├─x = 0
      │ │ │ │ │ │ │ ├─"test/test_expect_test.ml":805:10: z
      │ │ │ │ │ │ │ │ └─z = 0
      │ │ │ │ │ │ │ └─loop_highlight = 0
      │ │ │ │ │ │ └─loop_highlight = 0
      │ │ │ │ │ └─loop_highlight = 0
      │ │ │ │ └─loop_highlight = 1
      │ │ │ └─loop_highlight = 2
      │ │ └─loop_highlight = 4
      │ └─loop_highlight = 6
      └─loop_highlight = 9
      9 |}]

let%expect_test "%track_this_show PrintBox tracking" =
  let module Debug_runtime = (val Minidebug_runtime.debug ()) in
  let%track_this_show track_branches (x : int) : int =
    if x < 6 then match x with 0 -> 1 | 1 -> 0 | _ -> ~-x
    else match x with 6 -> 5 | 7 -> 4 | _ -> x
  in
  let () =
    try
      print_endline @@ Int.to_string @@ track_branches 7;
      print_endline @@ Int.to_string @@ track_branches 3
    with _ -> print_endline "Raised exception."
  in
  [%expect
    {|
      BEGIN DEBUG SESSION
      "test/test_expect_test.ml":872:37: track_branches
      ├─x = 7
      ├─"test/test_expect_test.ml":874:9: else:test_expect_test:874
      │ └─"test/test_expect_test.ml":874:36: <match -- branch 1>
      └─track_branches = 4
      4
      "test/test_expect_test.ml":872:37: track_branches
      ├─x = 3
      ├─"test/test_expect_test.ml":873:18: then:test_expect_test:873
      │ └─"test/test_expect_test.ml":873:54: <match -- branch 2>
      └─track_branches = -3
      -3
    |}]

let%expect_test "%track_this_show PrintBox tracking <function>" =
  let module Debug_runtime = (val Minidebug_runtime.debug ()) in
  let%track_this_show track_branches = function
    | 0 -> 1
    | 1 -> 0
    | 6 -> 5
    | 7 -> 4
    | 2 -> 2
    | x -> ~-x
  in
  let () =
    try
      print_endline @@ Int.to_string @@ track_branches 7;
      print_endline @@ Int.to_string @@ track_branches 3
    with _ -> print_endline "Raised exception."
  in
  [%expect
    {|
      BEGIN DEBUG SESSION
      "test/test_expect_test.ml":905:11: <function -- branch 3>
      4
      "test/test_expect_test.ml":907:11: <function -- branch 5> x
      -3
    |}]

let%expect_test "%track_this_show PrintBox tracking with debug_notrace" =
  let module Debug_runtime = (val Minidebug_runtime.debug ()) in
  let%track_this_show track_branches (x : int) : int =
    if x < 6 then
      match%debug_notrace x with
      | 0 -> 1
      | 1 -> 0
      | _ ->
          let result : int = if x > 2 then x else ~-x in
          result
    else
      match x with
      | 6 -> 5
      | 7 -> 4
      | _ ->
          let result : int = if x < 10 then x else ~-x in
          result
  in
  let () =
    try
      print_endline @@ Int.to_string @@ track_branches 8;
      print_endline @@ Int.to_string @@ track_branches 3
    with _ -> print_endline "Raised exception."
  in
  [%expect
    {|
      BEGIN DEBUG SESSION
      "test/test_expect_test.ml":926:37: track_branches
      ├─x = 8
      ├─"test/test_expect_test.ml":935:6: else:test_expect_test:935
      │ └─"test/test_expect_test.ml":939:10: <match -- branch 2>
      │   └─"test/test_expect_test.ml":939:14: result
      │     ├─"test/test_expect_test.ml":939:44: then:test_expect_test:939
      │     └─result = 8
      └─track_branches = 8
      8
      "test/test_expect_test.ml":926:37: track_branches
      ├─x = 3
      ├─"test/test_expect_test.ml":928:6: then:test_expect_test:928
      │ └─"test/test_expect_test.ml":932:14: result
      │   └─result = 3
      └─track_branches = 3
      3
    |}]

let%expect_test "%track_show PrintBox not tracking anonymous functions with debug_notrace"
    =
  let module Debug_runtime = (val Minidebug_runtime.debug ()) in
  let%track_show track_foo (x : int) : int =
    [%debug_notrace (fun (y : int) -> ignore y) x];
    let w = [%debug_notrace (fun (v : int) -> v) x] in
    (fun (z : int) -> ignore z) x;
    w
  in
  let () =
    try print_endline @@ Int.to_string @@ track_foo 8
    with _ -> print_endline "Raised exception."
  in
  [%expect
    {|
    BEGIN DEBUG SESSION
    "test/test_expect_test.ml":972:27: track_foo
    ├─x = 8
    ├─"test/test_expect_test.ml":975:4: fun:test_expect_test:975
    │ └─z = 8
    └─track_foo = 8
    8 |}]

let%expect_test "respect scope of nested extension points" =
  let module Debug_runtime = (val Minidebug_runtime.debug ()) in
  let%track_this_show track_branches (x : int) : int =
    if x < 6 then
      match%debug_notrace x with
      | 0 -> 1
      | 1 -> 0
      | _ ->
          let%debug_show result : int = if x > 2 then x else ~-x in
          result
    else
      match%debug_pp x with
      | 6 -> 5
      | 7 -> 4
      | _ ->
          let%track_show result : int = if x < 10 then x else ~-x in
          result
  in
  let () =
    try
      print_endline @@ Int.to_string @@ track_branches 8;
      print_endline @@ Int.to_string @@ track_branches 3
    with _ -> print_endline "Raised exception."
  in
  [%expect
    {|
      BEGIN DEBUG SESSION
      "test/test_expect_test.ml":994:37: track_branches
      ├─x = 8
      ├─"test/test_expect_test.ml":1003:6: else:test_expect_test:1003
      │ └─"test/test_expect_test.ml":1007:25: result
      │   ├─"test/test_expect_test.ml":1007:55: then:test_expect_test:1007
      │   └─result = 8
      └─track_branches = 8
      8
      "test/test_expect_test.ml":994:37: track_branches
      ├─x = 3
      ├─"test/test_expect_test.ml":996:6: then:test_expect_test:996
      │ └─"test/test_expect_test.ml":1000:25: result
      │   └─result = 3
      └─track_branches = 3
      3
    |}]

let%expect_test "%debug_show un-annotated toplevel fun" =
  let module Debug_runtime = (val Minidebug_runtime.debug ()) in
  let%debug_show anonymous x =
    let nested y = y + 1 in
    [%log "We do log this function"];
    Array.fold_left ( + ) 0 @@ Array.init (nested x) (fun (i : int) -> i)
  in
  let followup x =
    let nested y = y + 1 in
    (* [%log "We don't log this function so this would not compile"]; *)
    Array.fold_left ( + ) 0 @@ Array.init (nested x) (fun (i : int) -> i)
  in
  let () =
    print_endline @@ Int.to_string @@ anonymous 3;
    print_endline @@ Int.to_string @@ followup 3
  in
  [%expect
    {|
    BEGIN DEBUG SESSION
    "test/test_expect_test.ml":1038:27: anonymous
    └─"We do log this function"
    6
    6
  |}]

let%expect_test "%debug_show nested un-annotated toplevel fun" =
  let module Debug_runtime = (val Minidebug_runtime.debug ()) in
  let%debug_show wrapper () =
    let%debug_show anonymous x =
      let nested y = y + 1 in
      [%log "We do log this function"];
      Array.fold_left ( + ) 0 @@ Array.init (nested x) (fun (i : int) -> i)
    in
    let followup x =
      let nested y = y + 1 in
      Array.fold_left ( + ) 0 @@ Array.init (nested x) (fun (i : int) -> i)
    in
    (anonymous, followup)
  in
  let anonymous, followup = wrapper () in
  let () =
    print_endline @@ Int.to_string @@ anonymous 3;
    print_endline @@ Int.to_string @@ followup 3
  in
  [%expect
    {|
    BEGIN DEBUG SESSION
    "test/test_expect_test.ml":1063:25: wrapper
    "test/test_expect_test.ml":1064:29: anonymous
    └─"We do log this function"
    6
    6
  |}]

let%expect_test "%track_this_show no return type anonymous fun" =
  let module Debug_runtime = (val Minidebug_runtime.debug ()) in
  let%debug_this_show anonymous (x : int) =
    Array.fold_left ( + ) 0 @@ Array.init (x + 1) (fun (i : int) -> i)
  in
  let () =
    try print_endline @@ Int.to_string @@ anonymous 3
    with Failure s -> print_endline @@ "Raised exception: " ^ s
  in
  [%expect
    {|
    BEGIN DEBUG SESSION
    "test/test_expect_test.ml":1092:32: anonymous
    └─x = 3
    6
  |}];
  let%track_this_show anonymous (x : int) =
    Array.fold_left ( + ) 0 @@ Array.init (x + 1) (fun (i : int) -> i)
  in
  let () =
    try print_endline @@ Int.to_string @@ anonymous 3
    with Failure s -> print_endline @@ "Raised exception: " ^ s
  in
  [%expect
    {|
      "test/test_expect_test.ml":1106:32: anonymous
      ├─x = 3
      ├─"test/test_expect_test.ml":1107:50: fun:test_expect_test:1107
      │ └─i = 0
      ├─"test/test_expect_test.ml":1107:50: fun:test_expect_test:1107
      │ └─i = 1
      ├─"test/test_expect_test.ml":1107:50: fun:test_expect_test:1107
      │ └─i = 2
      └─"test/test_expect_test.ml":1107:50: fun:test_expect_test:1107
        └─i = 3
      6
    |}]

let%expect_test "%track_this_show anonymous fun, num children exceeded" =
  let module Debug_runtime = (val Minidebug_runtime.debug ()) in
  let%track_this_show rec loop_exceeded (x : int) : int =
    [%debug_interrupts
      { max_nesting_depth = 1000; max_num_children = 10 };
      Array.fold_left ( + ) 0
      @@ Array.init
           (100 / (x + 1))
           (fun (i : int) ->
             let z : int = i + ((x - 1) / 2) in
             if x <= 0 then i else i + loop_exceeded (z + (x / 2) - i))]
  in
  let () =
    try print_endline @@ Int.to_string @@ loop_exceeded 3
    with Failure s -> print_endline @@ "Raised exception: " ^ s
  in
  [%expect
    {|
      BEGIN DEBUG SESSION
      "test/test_expect_test.ml":1130:40: loop_exceeded
      ├─x = 3
      └─"test/test_expect_test.ml":1136:11: fun:test_expect_test:1136
        ├─i = 0
        ├─"test/test_expect_test.ml":1137:17: z
        │ └─z = 1
        └─"test/test_expect_test.ml":1138:35: else:test_expect_test:1138
          └─"test/test_expect_test.ml":1130:40: loop_exceeded
            ├─x = 2
            └─"test/test_expect_test.ml":1136:11: fun:test_expect_test:1136
              ├─i = 0
              ├─"test/test_expect_test.ml":1137:17: z
              │ └─z = 0
              └─"test/test_expect_test.ml":1138:35: else:test_expect_test:1138
                └─"test/test_expect_test.ml":1130:40: loop_exceeded
                  ├─x = 1
                  └─"test/test_expect_test.ml":1136:11: fun:test_expect_test:1136
                    ├─i = 0
                    ├─"test/test_expect_test.ml":1137:17: z
                    │ └─z = 0
                    └─"test/test_expect_test.ml":1138:35: else:test_expect_test:1138
                      └─"test/test_expect_test.ml":1130:40: loop_exceeded
                        ├─x = 0
                        ├─"test/test_expect_test.ml":1136:11: fun:test_expect_test:1136
                        │ ├─i = 0
                        │ ├─"test/test_expect_test.ml":1137:17: z
                        │ │ └─z = 0
                        │ └─"test/test_expect_test.ml":1138:28: then:test_expect_test:1138
                        ├─"test/test_expect_test.ml":1136:11: fun:test_expect_test:1136
                        │ ├─i = 1
                        │ ├─"test/test_expect_test.ml":1137:17: z
                        │ │ └─z = 1
                        │ └─"test/test_expect_test.ml":1138:28: then:test_expect_test:1138
                        ├─"test/test_expect_test.ml":1136:11: fun:test_expect_test:1136
                        │ ├─i = 2
                        │ ├─"test/test_expect_test.ml":1137:17: z
                        │ │ └─z = 2
                        │ └─"test/test_expect_test.ml":1138:28: then:test_expect_test:1138
                        ├─"test/test_expect_test.ml":1136:11: fun:test_expect_test:1136
                        │ ├─i = 3
                        │ ├─"test/test_expect_test.ml":1137:17: z
                        │ │ └─z = 3
                        │ └─"test/test_expect_test.ml":1138:28: then:test_expect_test:1138
                        ├─"test/test_expect_test.ml":1136:11: fun:test_expect_test:1136
                        │ ├─i = 4
                        │ ├─"test/test_expect_test.ml":1137:17: z
                        │ │ └─z = 4
                        │ └─"test/test_expect_test.ml":1138:28: then:test_expect_test:1138
                        ├─"test/test_expect_test.ml":1136:11: fun:test_expect_test:1136
                        │ ├─i = 5
                        │ ├─"test/test_expect_test.ml":1137:17: z
                        │ │ └─z = 5
                        │ └─"test/test_expect_test.ml":1138:28: then:test_expect_test:1138
                        ├─"test/test_expect_test.ml":1136:11: fun:test_expect_test:1136
                        │ ├─i = 6
                        │ ├─"test/test_expect_test.ml":1137:17: z
                        │ │ └─z = 6
                        │ └─"test/test_expect_test.ml":1138:28: then:test_expect_test:1138
                        ├─"test/test_expect_test.ml":1136:11: fun:test_expect_test:1136
                        │ ├─i = 7
                        │ ├─"test/test_expect_test.ml":1137:17: z
                        │ │ └─z = 7
                        │ └─"test/test_expect_test.ml":1138:28: then:test_expect_test:1138
                        ├─"test/test_expect_test.ml":1136:11: fun:test_expect_test:1136
                        │ ├─i = 8
                        │ ├─"test/test_expect_test.ml":1137:17: z
                        │ │ └─z = 8
                        │ └─"test/test_expect_test.ml":1138:28: then:test_expect_test:1138
                        ├─"test/test_expect_test.ml":1136:11: fun:test_expect_test:1136
                        │ ├─i = 9
                        │ ├─"test/test_expect_test.ml":1137:17: z
                        │ │ └─z = 9
                        │ └─"test/test_expect_test.ml":1138:28: then:test_expect_test:1138
                        └─fun:test_expect_test:1136 = <max_num_children exceeded>
      Raised exception: ppx_minidebug: max_num_children exceeded
    |}]

let%expect_test "%track_this_show anonymous fun, truncated children" =
  let module Debug_runtime = (val Minidebug_runtime.debug ~truncate_children:2 ()) in
  let%track_this_show rec loop_exceeded (x : int) : int =
    Array.fold_left ( + ) 0
    @@ Array.init
         (30 / (x + 1))
         (fun (i : int) ->
           let z : int = i + ((x - 1) / 2) in
           if x <= 0 then i else i + loop_exceeded (z + (x / 2) - i))
  in
  let () =
    try print_endline @@ Int.to_string @@ loop_exceeded 3
    with Failure s -> print_endline @@ "Raised exception: " ^ s
  in
  [%expect
    {|
      BEGIN DEBUG SESSION
      "test/test_expect_test.ml":1226:40: loop_exceeded
      ├─<earlier entries truncated>
      ├─"test/test_expect_test.ml":1230:9: fun:test_expect_test:1230
      │ ├─<earlier entries truncated>
      │ ├─"test/test_expect_test.ml":1231:15: z
      │ │ └─z = 7
      │ └─"test/test_expect_test.ml":1232:33: else:test_expect_test:1232
      │   └─"test/test_expect_test.ml":1226:40: loop_exceeded
      │     ├─<earlier entries truncated>
      │     ├─"test/test_expect_test.ml":1230:9: fun:test_expect_test:1230
      │     │ ├─<earlier entries truncated>
      │     │ ├─"test/test_expect_test.ml":1231:15: z
      │     │ │ └─z = 9
      │     │ └─"test/test_expect_test.ml":1232:33: else:test_expect_test:1232
      │     │   └─"test/test_expect_test.ml":1226:40: loop_exceeded
      │     │     ├─<earlier entries truncated>
      │     │     ├─"test/test_expect_test.ml":1230:9: fun:test_expect_test:1230
      │     │     │ ├─<earlier entries truncated>
      │     │     │ ├─"test/test_expect_test.ml":1231:15: z
      │     │     │ │ └─z = 14
      │     │     │ └─"test/test_expect_test.ml":1232:33: else:test_expect_test:1232
      │     │     │   └─"test/test_expect_test.ml":1226:40: loop_exceeded
      │     │     │     ├─<earlier entries truncated>
      │     │     │     ├─"test/test_expect_test.ml":1230:9: fun:test_expect_test:1230
      │     │     │     │ ├─<earlier entries truncated>
      │     │     │     │ ├─"test/test_expect_test.ml":1231:15: z
      │     │     │     │ │ └─z = 29
      │     │     │     │ └─"test/test_expect_test.ml":1232:26: then:test_expect_test:1232
      │     │     │     └─loop_exceeded = 435
      │     │     └─loop_exceeded = 6630
      │     └─loop_exceeded = 66345
      └─loop_exceeded = 464436
      464436
    |}]

module type T = sig
  type c

  val c : c
end

let%expect_test "%debug_this_show function with abstract type" =
  let module Debug_runtime = (val Minidebug_runtime.debug ()) in
  let%debug_this_show foo (type d) (module D : T with type c = d) ~a (c : int) : int =
    if c = 0 then 0 else List.length [ a; D.c ]
  in
  let () =
    try
      print_endline @@ Int.to_string
      @@ foo
           (module struct
             type c = int

             let c = 7
           end)
           ~a:3 1
    with Failure s -> print_endline @@ "Raised exception: " ^ s
  in
  [%expect
    {|
      BEGIN DEBUG SESSION
      "test/test_expect_test.ml":1284:26: foo
      ├─c = 1
      └─foo = 2
      2
    |}]

let%expect_test "%debug_this_show PrintBox values_first_mode to stdout with exception" =
  let module Debug_runtime = (val Minidebug_runtime.debug ~values_first_mode:true ()) in
  let%debug_this_show rec loop_truncated (x : int) : int =
    let z : int = (x - 1) / 2 in
    if x <= 0 then failwith "the log as for loop_complete but without return values";
    z + loop_truncated (z + (x / 2))
  in
  let () =
    try print_endline @@ Int.to_string @@ loop_truncated 7
    with _ -> print_endline "Raised exception."
  in
  [%expect
    {|
  BEGIN DEBUG SESSION
  loop_truncated
  ├─"test/test_expect_test.ml":1310:41
  ├─x = 7
  ├─z = 3
  │ └─"test/test_expect_test.ml":1311:8
  └─loop_truncated
    ├─"test/test_expect_test.ml":1310:41
    ├─x = 6
    ├─z = 2
    │ └─"test/test_expect_test.ml":1311:8
    └─loop_truncated
      ├─"test/test_expect_test.ml":1310:41
      ├─x = 5
      ├─z = 2
      │ └─"test/test_expect_test.ml":1311:8
      └─loop_truncated
        ├─"test/test_expect_test.ml":1310:41
        ├─x = 4
        ├─z = 1
        │ └─"test/test_expect_test.ml":1311:8
        └─loop_truncated
          ├─"test/test_expect_test.ml":1310:41
          ├─x = 3
          ├─z = 1
          │ └─"test/test_expect_test.ml":1311:8
          └─loop_truncated
            ├─"test/test_expect_test.ml":1310:41
            ├─x = 2
            ├─z = 0
            │ └─"test/test_expect_test.ml":1311:8
            └─loop_truncated
              ├─"test/test_expect_test.ml":1310:41
              ├─x = 1
              ├─z = 0
              │ └─"test/test_expect_test.ml":1311:8
              └─loop_truncated
                ├─"test/test_expect_test.ml":1310:41
                ├─x = 0
                └─z = 0
                  └─"test/test_expect_test.ml":1311:8
  Raised exception. |}]

let%expect_test "%debug_this_show PrintBox values_first_mode to stdout num children \
                 exceeded linear" =
  let module Debug_runtime = (val Minidebug_runtime.debug ~values_first_mode:true ()) in
  let () =
    try
      let%debug_this_show _bar : unit =
        [%debug_interrupts
          { max_nesting_depth = 1000; max_num_children = 10 };
          for i = 0 to 100 do
            let _baz : int = i * 2 in
            ()
          done]
      in
      ()
    with Failure s -> print_endline @@ "Raised exception: " ^ s
  in
  [%expect
    {|
    BEGIN DEBUG SESSION
    _bar
    ├─"test/test_expect_test.ml":1369:26
    ├─_baz = 0
    │ └─"test/test_expect_test.ml":1373:16
    ├─_baz = 2
    │ └─"test/test_expect_test.ml":1373:16
    ├─_baz = 4
    │ └─"test/test_expect_test.ml":1373:16
    ├─_baz = 6
    │ └─"test/test_expect_test.ml":1373:16
    ├─_baz = 8
    │ └─"test/test_expect_test.ml":1373:16
    ├─_baz = 10
    │ └─"test/test_expect_test.ml":1373:16
    ├─_baz = 12
    │ └─"test/test_expect_test.ml":1373:16
    ├─_baz = 14
    │ └─"test/test_expect_test.ml":1373:16
    ├─_baz = 16
    │ └─"test/test_expect_test.ml":1373:16
    ├─_baz = 18
    │ └─"test/test_expect_test.ml":1373:16
    ├─_baz = 20
    │ └─"test/test_expect_test.ml":1373:16
    └─_baz = <max_num_children exceeded>
    Raised exception: ppx_minidebug: max_num_children exceeded |}]

let%expect_test "%track_this_show PrintBox values_first_mode to stdout track for-loop" =
  let module Debug_runtime = (val Minidebug_runtime.debug ~values_first_mode:true ()) in
  let () =
    try
      let%track_this_show _bar : unit =
        [%debug_interrupts
          { max_nesting_depth = 1000; max_num_children = 1000 };
          for i = 0 to 6 do
            let _baz : int = i * 2 in
            ()
          done]
      in
      ()
    with Failure s -> print_endline @@ "Raised exception: " ^ s
  in
  [%expect
    {|
      BEGIN DEBUG SESSION
      _bar = ()
      ├─"test/test_expect_test.ml":1414:26
      └─for:test_expect_test:1417
        ├─"test/test_expect_test.ml":1417:10
        ├─i = 0
        ├─<for i>
        │ ├─"test/test_expect_test.ml":1417:14
        │ └─_baz = 0
        │   └─"test/test_expect_test.ml":1418:16
        ├─i = 1
        ├─<for i>
        │ ├─"test/test_expect_test.ml":1417:14
        │ └─_baz = 2
        │   └─"test/test_expect_test.ml":1418:16
        ├─i = 2
        ├─<for i>
        │ ├─"test/test_expect_test.ml":1417:14
        │ └─_baz = 4
        │   └─"test/test_expect_test.ml":1418:16
        ├─i = 3
        ├─<for i>
        │ ├─"test/test_expect_test.ml":1417:14
        │ └─_baz = 6
        │   └─"test/test_expect_test.ml":1418:16
        ├─i = 4
        ├─<for i>
        │ ├─"test/test_expect_test.ml":1417:14
        │ └─_baz = 8
        │   └─"test/test_expect_test.ml":1418:16
        ├─i = 5
        ├─<for i>
        │ ├─"test/test_expect_test.ml":1417:14
        │ └─_baz = 10
        │   └─"test/test_expect_test.ml":1418:16
        ├─i = 6
        └─<for i>
          ├─"test/test_expect_test.ml":1417:14
          └─_baz = 12
            └─"test/test_expect_test.ml":1418:16 |}]

let%expect_test "%debug_show PrintBox values_first_mode to stdout num children exceeded \
                 nested" =
  let module Debug_runtime = (val Minidebug_runtime.debug ~values_first_mode:true ()) in
  let%debug_this_show rec loop_exceeded (x : int) : int =
    [%debug_interrupts
      { max_nesting_depth = 1000; max_num_children = 10 };
      Array.fold_left ( + ) 0
      @@ Array.init
           (100 / (x + 1))
           (fun i ->
             let z : int = i + ((x - 1) / 2) in
             if x <= 0 then i else i + loop_exceeded (z + (x / 2) - i))]
  in
  let () =
    try print_endline @@ Int.to_string @@ loop_exceeded 3
    with Failure s -> print_endline @@ "Raised exception: " ^ s
  in
  [%expect
    {|
      BEGIN DEBUG SESSION
      loop_exceeded
      ├─"test/test_expect_test.ml":1471:40
      ├─x = 3
      ├─z = 1
      │ └─"test/test_expect_test.ml":1478:17
      └─loop_exceeded
        ├─"test/test_expect_test.ml":1471:40
        ├─x = 2
        ├─z = 0
        │ └─"test/test_expect_test.ml":1478:17
        └─loop_exceeded
          ├─"test/test_expect_test.ml":1471:40
          ├─x = 1
          ├─z = 0
          │ └─"test/test_expect_test.ml":1478:17
          └─loop_exceeded
            ├─"test/test_expect_test.ml":1471:40
            ├─x = 0
            ├─z = 0
            │ └─"test/test_expect_test.ml":1478:17
            ├─z = 1
            │ └─"test/test_expect_test.ml":1478:17
            ├─z = 2
            │ └─"test/test_expect_test.ml":1478:17
            ├─z = 3
            │ └─"test/test_expect_test.ml":1478:17
            ├─z = 4
            │ └─"test/test_expect_test.ml":1478:17
            ├─z = 5
            │ └─"test/test_expect_test.ml":1478:17
            ├─z = 6
            │ └─"test/test_expect_test.ml":1478:17
            ├─z = 7
            │ └─"test/test_expect_test.ml":1478:17
            ├─z = 8
            │ └─"test/test_expect_test.ml":1478:17
            ├─z = 9
            │ └─"test/test_expect_test.ml":1478:17
            └─z = <max_num_children exceeded>
      Raised exception: ppx_minidebug: max_num_children exceeded |}]

let%expect_test "%debug_this_show elapsed times PrintBox values_first_mode to stdout \
                 nested, truncated children" =
  let module Debug_runtime =
    (val Minidebug_runtime.debug ~elapsed_times:Microseconds ~values_first_mode:true
           ~truncate_children:4 ())
  in
  let%debug_this_show rec loop_exceeded (x : int) : int =
    Array.fold_left ( + ) 0
    @@ Array.init
         (20 / (x + 1))
         (fun i ->
           let z : int = i + ((x - 1) / 2) in
           if x <= 0 then i else i + loop_exceeded (z + (x / 2) - i))
  in
  let () =
    try print_endline @@ Int.to_string @@ loop_exceeded 3
    with Failure s -> print_endline @@ "Raised exception: " ^ s
  in
  let output = [%expect.output] in
  let output =
    Str.global_replace (Str.regexp {|[0-9]+?[0-9]+.[0-9]+[0-9]+μs|}) "N.NNμs" output
  in
  print_endline output;
  [%expect
    {|
      BEGIN DEBUG SESSION
      loop_exceeded = 58435 <N.NNμs>
      ├─"test/test_expect_test.ml":1535:40
      ├─<earlier entries truncated>
      ├─z = 4 <N.NNμs>
      │ └─"test/test_expect_test.ml":1540:15
      ├─loop_exceeded = 11685 <N.NNμs>
      │ ├─"test/test_expect_test.ml":1535:40
      │ ├─<earlier entries truncated>
      │ ├─z = 4 <N.NNμs>
      │ │ └─"test/test_expect_test.ml":1540:15
      │ ├─loop_exceeded = 1945 <N.NNμs>
      │ │ ├─"test/test_expect_test.ml":1535:40
      │ │ ├─<earlier entries truncated>
      │ │ ├─z = 8 <N.NNμs>
      │ │ │ └─"test/test_expect_test.ml":1540:15
      │ │ ├─loop_exceeded = 190 <N.NNμs>
      │ │ │ ├─"test/test_expect_test.ml":1535:40
      │ │ │ ├─<earlier entries truncated>
      │ │ │ ├─z = 16 <N.NNμs>
      │ │ │ │ └─"test/test_expect_test.ml":1540:15
      │ │ │ ├─z = 17 <N.NNμs>
      │ │ │ │ └─"test/test_expect_test.ml":1540:15
      │ │ │ ├─z = 18 <N.NNμs>
      │ │ │ │ └─"test/test_expect_test.ml":1540:15
      │ │ │ └─z = 19 <N.NNμs>
      │ │ │   └─"test/test_expect_test.ml":1540:15
      │ │ ├─z = 9 <N.NNμs>
      │ │ │ └─"test/test_expect_test.ml":1540:15
      │ │ └─loop_exceeded = 190 <N.NNμs>
      │ │   ├─"test/test_expect_test.ml":1535:40
      │ │   ├─<earlier entries truncated>
      │ │   ├─z = 16 <N.NNμs>
      │ │   │ └─"test/test_expect_test.ml":1540:15
      │ │   ├─z = 17 <N.NNμs>
      │ │   │ └─"test/test_expect_test.ml":1540:15
      │ │   ├─z = 18 <N.NNμs>
      │ │   │ └─"test/test_expect_test.ml":1540:15
      │ │   └─z = 19 <N.NNμs>
      │ │     └─"test/test_expect_test.ml":1540:15
      │ ├─z = 5 <N.NNμs>
      │ │ └─"test/test_expect_test.ml":1540:15
      │ └─loop_exceeded = 1945 <N.NNμs>
      │   ├─"test/test_expect_test.ml":1535:40
      │   ├─<earlier entries truncated>
      │   ├─z = 8 <N.NNμs>
      │   │ └─"test/test_expect_test.ml":1540:15
      │   ├─loop_exceeded = 190 <N.NNμs>
      │   │ ├─"test/test_expect_test.ml":1535:40
      │   │ ├─<earlier entries truncated>
      │   │ ├─z = 16 <N.NNμs>
      │   │ │ └─"test/test_expect_test.ml":1540:15
      │   │ ├─z = 17 <N.NNμs>
      │   │ │ └─"test/test_expect_test.ml":1540:15
      │   │ ├─z = 18 <N.NNμs>
      │   │ │ └─"test/test_expect_test.ml":1540:15
      │   │ └─z = 19 <N.NNμs>
      │   │   └─"test/test_expect_test.ml":1540:15
      │   ├─z = 9 <N.NNμs>
      │   │ └─"test/test_expect_test.ml":1540:15
      │   └─loop_exceeded = 190 <N.NNμs>
      │     ├─"test/test_expect_test.ml":1535:40
      │     ├─<earlier entries truncated>
      │     ├─z = 16 <N.NNμs>
      │     │ └─"test/test_expect_test.ml":1540:15
      │     ├─z = 17 <N.NNμs>
      │     │ └─"test/test_expect_test.ml":1540:15
      │     ├─z = 18 <N.NNμs>
      │     │ └─"test/test_expect_test.ml":1540:15
      │     └─z = 19 <N.NNμs>
      │       └─"test/test_expect_test.ml":1540:15
      ├─z = 5 <N.NNμs>
      │ └─"test/test_expect_test.ml":1540:15
      └─loop_exceeded = 11685 <N.NNμs>
        ├─"test/test_expect_test.ml":1535:40
        ├─<earlier entries truncated>
        ├─z = 4 <N.NNμs>
        │ └─"test/test_expect_test.ml":1540:15
        ├─loop_exceeded = 1945 <N.NNμs>
        │ ├─"test/test_expect_test.ml":1535:40
        │ ├─<earlier entries truncated>
        │ ├─z = 8 <N.NNμs>
        │ │ └─"test/test_expect_test.ml":1540:15
        │ ├─loop_exceeded = 190 <N.NNμs>
        │ │ ├─"test/test_expect_test.ml":1535:40
        │ │ ├─<earlier entries truncated>
        │ │ ├─z = 16 <N.NNμs>
        │ │ │ └─"test/test_expect_test.ml":1540:15
        │ │ ├─z = 17 <N.NNμs>
        │ │ │ └─"test/test_expect_test.ml":1540:15
        │ │ ├─z = 18 <N.NNμs>
        │ │ │ └─"test/test_expect_test.ml":1540:15
        │ │ └─z = 19 <N.NNμs>
        │ │   └─"test/test_expect_test.ml":1540:15
        │ ├─z = 9 <N.NNμs>
        │ │ └─"test/test_expect_test.ml":1540:15
        │ └─loop_exceeded = 190 <N.NNμs>
        │   ├─"test/test_expect_test.ml":1535:40
        │   ├─<earlier entries truncated>
        │   ├─z = 16 <N.NNμs>
        │   │ └─"test/test_expect_test.ml":1540:15
        │   ├─z = 17 <N.NNμs>
        │   │ └─"test/test_expect_test.ml":1540:15
        │   ├─z = 18 <N.NNμs>
        │   │ └─"test/test_expect_test.ml":1540:15
        │   └─z = 19 <N.NNμs>
        │     └─"test/test_expect_test.ml":1540:15
        ├─z = 5 <N.NNμs>
        │ └─"test/test_expect_test.ml":1540:15
        └─loop_exceeded = 1945 <N.NNμs>
          ├─"test/test_expect_test.ml":1535:40
          ├─<earlier entries truncated>
          ├─z = 8 <N.NNμs>
          │ └─"test/test_expect_test.ml":1540:15
          ├─loop_exceeded = 190 <N.NNμs>
          │ ├─"test/test_expect_test.ml":1535:40
          │ ├─<earlier entries truncated>
          │ ├─z = 16 <N.NNμs>
          │ │ └─"test/test_expect_test.ml":1540:15
          │ ├─z = 17 <N.NNμs>
          │ │ └─"test/test_expect_test.ml":1540:15
          │ ├─z = 18 <N.NNμs>
          │ │ └─"test/test_expect_test.ml":1540:15
          │ └─z = 19 <N.NNμs>
          │   └─"test/test_expect_test.ml":1540:15
          ├─z = 9 <N.NNμs>
          │ └─"test/test_expect_test.ml":1540:15
          └─loop_exceeded = 190 <N.NNμs>
            ├─"test/test_expect_test.ml":1535:40
            ├─<earlier entries truncated>
            ├─z = 16 <N.NNμs>
            │ └─"test/test_expect_test.ml":1540:15
            ├─z = 17 <N.NNμs>
            │ └─"test/test_expect_test.ml":1540:15
            ├─z = 18 <N.NNμs>
            │ └─"test/test_expect_test.ml":1540:15
            └─z = 19 <N.NNμs>
              └─"test/test_expect_test.ml":1540:15
      58435 |}]

let%expect_test "%debug_this_show PrintBox values_first_mode to stdout highlight" =
  let module Debug_runtime =
    (val Minidebug_runtime.debug ~highlight_terms:(Re.str "3") ~values_first_mode:true ())
  in
  let%debug_this_show rec loop_highlight (x : int) : int =
    let z : int = (x - 1) / 2 in
    if x <= 0 then 0 else z + loop_highlight (z + (x / 2))
  in
  print_endline @@ Int.to_string @@ loop_highlight 7;
  [%expect
    {|
      BEGIN DEBUG SESSION
      ┌──────────────────┐
      │loop_highlight = 9│
      ├──────────────────┘
      ├─"test/test_expect_test.ml":1698:41
      ├─x = 7
      ├─┬─────┐
      │ │z = 3│
      │ ├─────┘
      │ └─"test/test_expect_test.ml":1699:8
      └─┬──────────────────┐
        │loop_highlight = 6│
        ├──────────────────┘
        ├─"test/test_expect_test.ml":1698:41
        ├─x = 6
        ├─z = 2
        │ └─"test/test_expect_test.ml":1699:8
        └─┬──────────────────┐
          │loop_highlight = 4│
          ├──────────────────┘
          ├─"test/test_expect_test.ml":1698:41
          ├─x = 5
          ├─z = 2
          │ └─"test/test_expect_test.ml":1699:8
          └─┬──────────────────┐
            │loop_highlight = 2│
            ├──────────────────┘
            ├─"test/test_expect_test.ml":1698:41
            ├─x = 4
            ├─z = 1
            │ └─"test/test_expect_test.ml":1699:8
            └─┬──────────────────┐
              │loop_highlight = 1│
              ├──────────────────┘
              ├─"test/test_expect_test.ml":1698:41
              ├─┬─────┐
              │ │x = 3│
              │ └─────┘
              ├─z = 1
              │ └─"test/test_expect_test.ml":1699:8
              └─loop_highlight = 0
                ├─"test/test_expect_test.ml":1698:41
                ├─x = 2
                ├─z = 0
                │ └─"test/test_expect_test.ml":1699:8
                └─loop_highlight = 0
                  ├─"test/test_expect_test.ml":1698:41
                  ├─x = 1
                  ├─z = 0
                  │ └─"test/test_expect_test.ml":1699:8
                  └─loop_highlight = 0
                    ├─"test/test_expect_test.ml":1698:41
                    ├─x = 0
                    └─z = 0
                      └─"test/test_expect_test.ml":1699:8
      9 |}]

let%expect_test "%track_this_show PrintBox values_first_mode tracking" =
  let module Debug_runtime = (val Minidebug_runtime.debug ~values_first_mode:true ()) in
  let%track_this_show track_branches (x : int) : int =
    if x < 6 then match x with 0 -> 1 | 1 -> 0 | _ -> ~-x
    else match x with 6 -> 5 | 7 -> 4 | _ -> x
  in
  let () =
    try
      print_endline @@ Int.to_string @@ track_branches 7;
      print_endline @@ Int.to_string @@ track_branches 3
    with _ -> print_endline "Raised exception."
  in
  [%expect
    {|
      BEGIN DEBUG SESSION
      track_branches = 4
      ├─"test/test_expect_test.ml":1764:37
      ├─x = 7
      └─else:test_expect_test:1766
        ├─"test/test_expect_test.ml":1766:9
        └─<match -- branch 1>
          └─"test/test_expect_test.ml":1766:36
      4
      track_branches = -3
      ├─"test/test_expect_test.ml":1764:37
      ├─x = 3
      └─then:test_expect_test:1765
        ├─"test/test_expect_test.ml":1765:18
        └─<match -- branch 2>
          └─"test/test_expect_test.ml":1765:54
      -3
    |}]

let%expect_test "%track_show PrintBox values_first_mode to stdout no return type \
                 anonymous fun" =
  let module Debug_runtime = (val Minidebug_runtime.debug ~values_first_mode:true ()) in
  let%track_this_show anonymous (x : int) =
    Array.fold_left ( + ) 0 @@ Array.init (x + 1) (fun (i : int) -> i)
  in
  let () =
    try print_endline @@ Int.to_string @@ anonymous 3
    with Failure s -> print_endline @@ "Raised exception: " ^ s
  in
  [%expect
    {|
      BEGIN DEBUG SESSION
      anonymous
      ├─"test/test_expect_test.ml":1798:32
      ├─x = 3
      ├─fun:test_expect_test:1799
      │ ├─"test/test_expect_test.ml":1799:50
      │ └─i = 0
      ├─fun:test_expect_test:1799
      │ ├─"test/test_expect_test.ml":1799:50
      │ └─i = 1
      ├─fun:test_expect_test:1799
      │ ├─"test/test_expect_test.ml":1799:50
      │ └─i = 2
      └─fun:test_expect_test:1799
        ├─"test/test_expect_test.ml":1799:50
        └─i = 3
      6
    |}]

let%expect_test "%debug_show records" =
  let module Debug_runtime = (val Minidebug_runtime.debug ~values_first_mode:false ()) in
  let%debug_show bar { first : int; second : int } : int =
    let { first : int = a; second : int = b } = { first; second = second + 3 } in
    let y : int = a + 1 in
    (b - 3) * y
  in
  let () = print_endline @@ Int.to_string @@ bar { first = 7; second = 42 } in
  let baz { first : int; second : int } : int =
    let { first : int; second : int } = { first = first + 1; second = second + 3 } in
    (first * first) + second
  in
  let () = print_endline @@ Int.to_string @@ baz { first = 7; second = 42 } in
  [%expect
    {|
    BEGIN DEBUG SESSION
    "test/test_expect_test.ml":1828:21: bar
    ├─first = 7
    ├─second = 42
    ├─"test/test_expect_test.ml":1829:8: {first=a; second=b}
    │ ├─a = 7
    │ └─b = 45
    ├─"test/test_expect_test.ml":1830:8: y
    │ └─y = 8
    └─bar = 336
    336
    "test/test_expect_test.ml":1834:10: baz
    ├─first = 7
    ├─second = 42
    ├─"test/test_expect_test.ml":1835:8: {first; second}
    │ ├─first = 8
    │ └─second = 45
    └─baz = 109
    109 |}]

let%expect_test "%debug_show tuples" =
  let module Debug_runtime = (val Minidebug_runtime.debug ~values_first_mode:false ()) in
  let%debug_show bar ((first : int), (second : int)) : int =
    let y : int = first + 1 in
    second * y
  in
  let () = print_endline @@ Int.to_string @@ bar (7, 42) in
  let baz ((first, second) : int * int) : int * int =
    let (y, z) : int * int = (first + 1, 3) in
    let (a : int), (b : int) = (first + 1, second + 3) in
    ((second * y) + z, (a * a) + b)
  in
  let r1, r2 = (baz (7, 42) : int * int) in
  let () = print_endline @@ Int.to_string r1 in
  let () = print_endline @@ Int.to_string r2 in
  [%expect
    {|
    BEGIN DEBUG SESSION
    "test/test_expect_test.ml":1863:21: bar
    ├─first = 7
    ├─second = 42
    ├─"test/test_expect_test.ml":1864:8: y
    │ └─y = 8
    └─bar = 336
    336
    "test/test_expect_test.ml":1873:6: (r1, r2)
    ├─"test/test_expect_test.ml":1868:10: baz
    │ ├─first = 7
    │ ├─second = 42
    │ ├─"test/test_expect_test.ml":1869:8: (y, z)
    │ │ ├─y = 8
    │ │ └─z = 3
    │ ├─"test/test_expect_test.ml":1870:8: (a, b)
    │ │ ├─a = 8
    │ │ └─b = 45
    │ └─baz = (339, 109)
    ├─r1 = 339
    └─r2 = 109
    339
    109 |}]

let%expect_test "%debug_show records values_first_mode" =
  let module Debug_runtime = (val Minidebug_runtime.debug ~values_first_mode:true ()) in
  let%debug_show bar { first : int; second : int } : int =
    let { first : int = a; second : int = b } = { first; second = second + 3 } in
    let y : int = a + 1 in
    (b - 3) * y
  in
  let () = print_endline @@ Int.to_string @@ bar { first = 7; second = 42 } in
  let baz { first : int; second : int } : int =
    let { first : int; second : int } = { first = first + 1; second = second + 3 } in
    (first * first) + second
  in
  let () = print_endline @@ Int.to_string @@ baz { first = 7; second = 42 } in
  [%expect
    {|
      BEGIN DEBUG SESSION
      bar = 336
      ├─"test/test_expect_test.ml":1904:21
      ├─first = 7
      ├─second = 42
      ├─{first=a; second=b}
      │ ├─"test/test_expect_test.ml":1905:8
      │ └─<values>
      │   ├─a = 7
      │   └─b = 45
      └─y = 8
        └─"test/test_expect_test.ml":1906:8
      336
      baz = 109
      ├─"test/test_expect_test.ml":1910:10
      ├─first = 7
      ├─second = 42
      └─{first; second}
        ├─"test/test_expect_test.ml":1911:8
        └─<values>
          ├─first = 8
          └─second = 45
      109 |}]

let%expect_test "%debug_show tuples values_first_mode" =
  let module Debug_runtime = (val Minidebug_runtime.debug ~values_first_mode:true ()) in
  let%debug_show bar ((first : int), (second : int)) : int =
    let y : int = first + 1 in
    second * y
  in
  let () = print_endline @@ Int.to_string @@ bar (7, 42) in
  let baz ((first, second) : int * int) : int * int =
    let (y, z) : int * int = (first + 1, 3) in
    let (a : int), (b : int) = (first + 1, second + 3) in
    ((second * y) + z, (a * a) + b)
  in
  let r1, r2 = (baz (7, 42) : int * int) in
  let () = print_endline @@ Int.to_string r1 in
  let () = print_endline @@ Int.to_string r2 in
  [%expect
    {|
    BEGIN DEBUG SESSION
    bar = 336
    ├─"test/test_expect_test.ml":1943:21
    ├─first = 7
    ├─second = 42
    └─y = 8
      └─"test/test_expect_test.ml":1944:8
    336
    (r1, r2)
    ├─"test/test_expect_test.ml":1953:6
    ├─<returns>
    │ ├─r1 = 339
    │ └─r2 = 109
    └─baz = (339, 109)
      ├─"test/test_expect_test.ml":1948:10
      ├─first = 7
      ├─second = 42
      ├─(y, z)
      │ ├─"test/test_expect_test.ml":1949:8
      │ └─<values>
      │   ├─y = 8
      │   └─z = 3
      └─(a, b)
        ├─"test/test_expect_test.ml":1950:8
        └─<values>
          ├─a = 8
          └─b = 45
    339
    109 |}]

type 'a irrefutable = Zero of 'a
type ('a, 'b) left_right = Left of 'a | Right of 'b
type ('a, 'b, 'c) one_two_three = One of 'a | Two of 'b | Three of 'c

let%expect_test "%track_show variants values_first_mode" =
  let module Debug_runtime = (val Minidebug_runtime.debug ~values_first_mode:true ()) in
  let%track_show bar (Zero (x : int)) : int =
    let y = (x + 1 : int) in
    2 * y
  in
  let () = print_endline @@ Int.to_string @@ bar (Zero 7) in
  let baz : 'a -> int = function
    | Left (x : int) -> x + 1
    | Right (Two (y : int)) -> y * 2
    | _ -> 3
  in
  let foo x : int =
    match x with Left (x : int) -> x + 1 | Right (Two (y : int)) -> y * 2 | _ -> 3
  in
  let () = print_endline @@ Int.to_string @@ baz (Left 4) in
  let () = print_endline @@ Int.to_string @@ baz (Right (Two 3)) in
  let () = print_endline @@ Int.to_string @@ foo (Right (Three 0)) in
  [%expect
    {|
      BEGIN DEBUG SESSION
      bar = 16
      ├─"test/test_expect_test.ml":1994:21
      ├─x = 7
      └─y = 8
        └─"test/test_expect_test.ml":1995:8
      16
      baz = 5
      ├─"test/test_expect_test.ml":2000:24
      ├─<function -- branch 0> Left x
      └─x = 4
      5
      baz = 6
      ├─"test/test_expect_test.ml":2001:31
      ├─<function -- branch 1> Right Two y
      └─y = 3
      6
      foo = 3
      ├─"test/test_expect_test.ml":2004:10
      └─<match -- branch 2>
        └─"test/test_expect_test.ml":2005:81
      3 |}]

let%expect_test "%debug_show tuples merge type info" =
  let module Debug_runtime = (val Minidebug_runtime.debug ~values_first_mode:true ()) in
  let%debug_show baz (((first : int), (second : 'a)) : 'b * int) : int * int =
    let ((y : 'c), (z : int)) : int * 'd = (first + 1, 3) in
    let (a : int), b = (first + 1, (second + 3 : int)) in
    ((second * y) + z, (a * a) + b)
  in
  let (r1 : 'e), (r2 : int) = (baz (7, 42) : int * 'f) in
  let () = print_endline @@ Int.to_string r1 in
  let () = print_endline @@ Int.to_string r2 in
  (* Note the missing value of [b]: the nested-in-expression type is not propagated. *)
  [%expect
    {|
    BEGIN DEBUG SESSION
    (r1, r2)
    ├─"test/test_expect_test.ml":2042:6
    ├─<returns>
    │ ├─r1 = 339
    │ └─r2 = 109
    └─baz = (339, 109)
      ├─"test/test_expect_test.ml":2037:21
      ├─first = 7
      ├─second = 42
      ├─(y, z)
      │ ├─"test/test_expect_test.ml":2038:8
      │ └─<values>
      │   ├─y = 8
      │   └─z = 3
      └─a = 8
        └─"test/test_expect_test.ml":2039:8
    339
    109 |}]

let%expect_test "%debug_show decompose multi-argument function type" =
  let module Debug_runtime = (val Minidebug_runtime.debug ~values_first_mode:true ()) in
  let%debug_show f : 'a. 'a -> int -> int = fun _a b -> b + 1 in
  let%debug_show g : 'a. 'a -> int -> 'a -> 'a -> int = fun _a b _c _d -> b * 2 in
  let () = print_endline @@ Int.to_string @@ f 'a' 6 in
  let () = print_endline @@ Int.to_string @@ g 'a' 6 'b' 'c' in
  [%expect
    {|
    BEGIN DEBUG SESSION
    f = 7
    ├─"test/test_expect_test.ml":2070:44
    └─b = 6
    7
    g = 12
    ├─"test/test_expect_test.ml":2071:56
    └─b = 6
    12 |}]

let%expect_test "%debug_show debug type info" =
  let module Debug_runtime = (val Minidebug_runtime.debug ~values_first_mode:true ()) in
  [%debug_show
    [%debug_type_info
      let f : 'a. 'a -> int -> int = fun _a b -> b + 1 in
      let g : 'a. 'a -> int -> 'a -> 'a -> int = fun _a b _c _d -> b * 2 in
      let () = print_endline @@ Int.to_string @@ f 'a' 6 in
      print_endline @@ Int.to_string @@ g 'a' 6 'b' 'c']];
  [%expect
    {|
      BEGIN DEBUG SESSION
      f : int = 7
      ├─"test/test_expect_test.ml":2090:37
      ├─f : int
      └─b : int = 6
      7
      g : int = 12
      ├─"test/test_expect_test.ml":2091:49
      ├─g : int
      └─b : int = 6
      12 |}]

let%expect_test "%track_show options values_first_mode" =
  let module Debug_runtime = (val Minidebug_runtime.debug ~values_first_mode:true ()) in
  let%track_show foo l : int =
    match (l : int option) with None -> 7 | Some y -> y * 2
  in
  let () = print_endline @@ Int.to_string @@ foo (Some 7) in
  let bar (l : int option) : int = match l with None -> 7 | Some y -> y * 2 in
  let () = print_endline @@ Int.to_string @@ bar (Some 7) in
  let baz : int option -> int = function None -> 7 | Some y -> y * 2 in
  let () = print_endline @@ Int.to_string @@ baz (Some 4) in
  let zoo : (int * int) option -> int = function None -> 7 | Some (y, z) -> y + z in
  let () = print_endline @@ Int.to_string @@ zoo (Some (4, 5)) in
  [%expect
    {|
      BEGIN DEBUG SESSION
      foo = 14
      ├─"test/test_expect_test.ml":2110:21
      └─<match -- branch 1> Some y
        ├─"test/test_expect_test.ml":2111:54
        └─y = 7
      14
      bar = 14
      ├─"test/test_expect_test.ml":2114:10
      ├─l = (Some 7)
      └─<match -- branch 1> Some y
        └─"test/test_expect_test.ml":2114:70
      14
      baz = 8
      ├─"test/test_expect_test.ml":2116:63
      ├─<function -- branch 1> Some y
      └─y = 4
      8
      zoo = 9
      ├─"test/test_expect_test.ml":2118:76
      ├─<function -- branch 1> Some (y, z)
      ├─y = 4
      └─z = 5
      9 |}]

let%expect_test "%track_show list values_first_mode" =
  let module Debug_runtime = (val Minidebug_runtime.debug ~values_first_mode:true ()) in
  let%track_show foo l : int = match (l : int list) with [] -> 7 | y :: _ -> y * 2 in
  let () = print_endline @@ Int.to_string @@ foo [ 7 ] in
  let bar (l : int list) : int = match l with [] -> 7 | y :: _ -> y * 2 in
  let () = print_endline @@ Int.to_string @@ bar [ 7 ] in
  let baz : int list -> int = function
    | [] -> 7
    | [ y ] -> y * 2
    | [ y; z ] -> y + z
    | y :: z :: _ -> y + z + 1
  in
  let () = print_endline @@ Int.to_string @@ baz [ 4 ] in
  let () = print_endline @@ Int.to_string @@ baz [ 4; 5 ] in
  let () = print_endline @@ Int.to_string @@ baz [ 4; 5; 6 ] in
  [%expect
    {|
      BEGIN DEBUG SESSION
      foo = 14
      ├─"test/test_expect_test.ml":2149:21
      └─<match -- branch 1> :: (y, _)
        ├─"test/test_expect_test.ml":2149:77
        └─y = 7
      14
      bar = 14
      ├─"test/test_expect_test.ml":2151:10
      ├─l = [7]
      └─<match -- branch 1> :: (y, _)
        └─"test/test_expect_test.ml":2151:66
      14
      baz = 8
      ├─"test/test_expect_test.ml":2155:15
      ├─<function -- branch 1> :: (y, [])
      └─y = 4
      8
      baz = 9
      ├─"test/test_expect_test.ml":2156:18
      ├─<function -- branch 2> :: (y, :: (z, []))
      ├─y = 4
      └─z = 5
      9
      baz = 10
      ├─"test/test_expect_test.ml":2157:21
      ├─<function -- branch 3> :: (y, :: (z, _))
      ├─y = 4
      └─z = 5
      10 |}]

let%expect_test "%track_rtb_show list runtime passing" =
  let%track_rtb_show foo l : int =
    match (l : int list) with [] -> 7 | y :: _ -> y * 2
  in
  let () =
    print_endline @@ Int.to_string
    @@ foo
         (Minidebug_runtime.debug ~global_prefix:"foo-1" ~values_first_mode:true ())
         [ 7 ]
  in
  let%track_rtb_show baz : int list -> int = function
    | [] -> 7
    | [ y ] -> y * 2
    | [ y; z ] -> y + z
    | y :: z :: _ -> y + z + 1
  in
  let () =
    print_endline @@ Int.to_string
    @@ baz
         (Minidebug_runtime.debug ~global_prefix:"baz-1" ~values_first_mode:true ())
         [ 4 ]
  in
  let () =
    print_endline @@ Int.to_string
    @@ baz
         (Minidebug_runtime.debug ~global_prefix:"baz-2" ~values_first_mode:true ())
         [ 4; 5; 6 ]
  in
  [%expect
    {|
      BEGIN DEBUG SESSION foo-1
      foo = 14
      ├─"test/test_expect_test.ml":2196:25
      └─foo-1 <match -- branch 1> :: (y, _)
        ├─"test/test_expect_test.ml":2197:50
        └─y = 7
      14

      BEGIN DEBUG SESSION baz-1
      baz = 8
      ├─"test/test_expect_test.ml":2207:15
      ├─baz-1 <function -- branch 1> :: (y, [])
      └─y = 4
      8

      BEGIN DEBUG SESSION baz-2
      baz = 10
      ├─"test/test_expect_test.ml":2209:21
      ├─baz-2 <function -- branch 3> :: (y, :: (z, _))
      ├─y = 4
      └─z = 5
      10 |}]

let%expect_test "%track_rt_show procedure runtime passing" =
  let%track_rt_show bar () = (fun () -> ()) () in
  let () = bar (Minidebug_runtime.debug_flushing ~global_prefix:"bar-1" ()) () in
  let () = bar (Minidebug_runtime.debug_flushing ~global_prefix:"bar-2" ()) () in
  let%track_rt_show foo () =
    let () = () in
    ()
  in
  let () = foo (Minidebug_runtime.debug_flushing ~global_prefix:"foo-1" ()) () in
  let () = foo (Minidebug_runtime.debug_flushing ~global_prefix:"foo-2" ()) () in
  [%expect
    {|
      BEGIN DEBUG SESSION bar-1
      bar-1 bar begin "test/test_expect_test.ml":2249:24:
       bar-1 fun:test_expect_test:2249 begin "test/test_expect_test.ml":2249:29:
       bar-1 fun:test_expect_test:2249 end
      bar-1 bar end

      BEGIN DEBUG SESSION bar-2
      bar-2 bar begin "test/test_expect_test.ml":2249:24:
       bar-2 fun:test_expect_test:2249 begin "test/test_expect_test.ml":2249:29:
       bar-2 fun:test_expect_test:2249 end
      bar-2 bar end

      BEGIN DEBUG SESSION foo-1
      foo-1 foo begin "test/test_expect_test.ml":2252:24:
      foo-1 foo end

      BEGIN DEBUG SESSION foo-2
      foo-2 foo begin "test/test_expect_test.ml":2252:24:
      foo-2 foo end |}]

let%expect_test "%track_rt_show nested procedure runtime passing" =
  let module Debug_runtime = (val Minidebug_runtime.debug ~values_first_mode:true ()) in
  let%debug_show rt_test () =
    let%track_rt_show bar () = (fun () -> ()) () in
    let%track_rt_show foo () =
      let () = () in
      ()
    in
    (foo, bar)
  in
  let foo, bar = rt_test () in
  let () = foo (Minidebug_runtime.debug_flushing ~global_prefix:"foo-1" ()) () in
  let () = foo (Minidebug_runtime.debug_flushing ~global_prefix:"foo-2" ()) () in
  let () = bar (Minidebug_runtime.debug_flushing ~global_prefix:"bar-1" ()) () in
  let () = bar (Minidebug_runtime.debug_flushing ~global_prefix:"bar-2" ()) () in
  [%expect
    {|
      BEGIN DEBUG SESSION
      rt_test
      └─"test/test_expect_test.ml":2282:25

      BEGIN DEBUG SESSION foo-1
      foo-1 foo begin "test/test_expect_test.ml":2284:26:
      foo-1 foo end

      BEGIN DEBUG SESSION foo-2
      foo-2 foo begin "test/test_expect_test.ml":2284:26:
      foo-2 foo end

      BEGIN DEBUG SESSION bar-1
      bar-1 bar begin "test/test_expect_test.ml":2283:26:
       bar-1 fun:test_expect_test:2283 begin "test/test_expect_test.ml":2283:31:
       bar-1 fun:test_expect_test:2283 end
      bar-1 bar end

      BEGIN DEBUG SESSION bar-2
      bar-2 bar begin "test/test_expect_test.ml":2283:26:
       bar-2 fun:test_expect_test:2283 begin "test/test_expect_test.ml":2283:31:
       bar-2 fun:test_expect_test:2283 end
      bar-2 bar end |}]

let%expect_test "%log constant entries" =
  let module Debug_runtime = (val Minidebug_runtime.debug ~values_first_mode:true ()) in
  let%debug_show foo () : unit =
    [%log "This is the first log line"];
    [%log [ "This is the"; "2"; "log line" ]];
    [%log "This is the", 3, "or", 3.14, "log line"]
  in
  let () = foo () in
  Debug_runtime.config.boxify_sexp_from_size <- 2;
  let%debug_sexp bar () : unit =
    [%log "This is the first log line"];
    [%log [ "This is the"; "2"; "log line" ]];
    [%log "This is the", 3, "or", 3.14, "log line"]
  in
  let () = bar () in
  [%expect
    {|
      BEGIN DEBUG SESSION
      foo = ()
      ├─"test/test_expect_test.ml":2323:21
      ├─"This is the first log line"
      ├─["This is the"; "2"; "log line"]
      └─("This is the", 3, "or", 3.14, "log line")
      bar
      ├─"test/test_expect_test.ml":2330:21
      ├─This is the first log line
      ├─This is the
      │ ├─2
      │ └─log line
      └─This is the
        ├─3
        ├─or
        ├─3.14
        └─log line |}]

let%expect_test "%log with type annotations" =
  let module Debug_runtime = (val Minidebug_runtime.debug ~values_first_mode:true ()) in
  let i = 3 in
  let pi = 3.14 in
  let l = [ 1; 2; 3 ] in
  let%debug_show foo () : unit =
    [%log "This is like", (i : int), "or", (pi : float), "above"];
    [%log "tau =", (pi *. 2. : float)];
    [%log 4 :: l];
    [%log i :: (l : int list)];
    [%log (i : int) :: l]
  in
  let () = foo () in
  [%expect
    {|
          BEGIN DEBUG SESSION
          foo = ()
          ├─"test/test_expect_test.ml":2361:21
          ├─("This is like", 3, "or", 3.14, "above")
          ├─("tau =", 6.28)
          ├─[4; 1; 2; 3]
          ├─[3; 1; 2; 3]
          └─[3; 1; 2; 3] |}]

let%expect_test "%log with default type assumption" =
  let module Debug_runtime = (val Minidebug_runtime.debug ~values_first_mode:true ()) in
  let s = "3" in
  let pi = "3.14" in
  let x2 s = "2*" ^ s in
  let l = [ ("1", 1); ("2", 2); ("3", 3) ] in
  let%debug_show foo () : unit =
    [%log x2 s];
    [%log "This is like", s, "or", pi, "above"];
    [%log "tau =", x2 pi];
    (* Does not work with lists or arrays: *)
    (* [%log s :: l]; *)
    (* But works for tuples even if nested: *)
    [%log (x2 s, 0) :: l]
  in
  let () = foo () in
  [%expect
    {|
          BEGIN DEBUG SESSION
          foo = ()
          ├─"test/test_expect_test.ml":2386:21
          ├─"2*3"
          ├─("This is like", "3", "or", "3.14", "above")
          ├─("tau =", "2*3.14")
          └─[("2*3", 0); ("1", 1); ("2", 2); ("3", 3)] |}]

let%expect_test "%log track while-loop" =
  let module Debug_runtime = (val Minidebug_runtime.debug ()) in
  let%track_sexp result =
    let i = ref 0 in
    let j = ref 0 in
    while !i < 6 do
      [%log 1, "i=", (!i : int)];
      incr i;
      [%log 2, "i=", (!i : int)];
      j := !j + !i;
      [%log 3, "j=", (!j : int)]
    done;
    !j
  in
  print_endline @@ Int.to_string result;
  [%expect
    {|
    BEGIN DEBUG SESSION
    "test/test_expect_test.ml":2408:17: result
    └─"test/test_expect_test.ml":2411:4: while:test_expect_test:2411
      ├─"test/test_expect_test.ml":2412:6: <while loop>
      │ ├─(1 i= 0)
      │ ├─(2 i= 1)
      │ └─(3 j= 1)
      ├─"test/test_expect_test.ml":2412:6: <while loop>
      │ ├─(1 i= 1)
      │ ├─(2 i= 2)
      │ └─(3 j= 3)
      ├─"test/test_expect_test.ml":2412:6: <while loop>
      │ ├─(1 i= 2)
      │ ├─(2 i= 3)
      │ └─(3 j= 6)
      ├─"test/test_expect_test.ml":2412:6: <while loop>
      │ ├─(1 i= 3)
      │ ├─(2 i= 4)
      │ └─(3 j= 10)
      ├─"test/test_expect_test.ml":2412:6: <while loop>
      │ ├─(1 i= 4)
      │ ├─(2 i= 5)
      │ └─(3 j= 15)
      └─"test/test_expect_test.ml":2412:6: <while loop>
        ├─(1 i= 5)
        ├─(2 i= 6)
        └─(3 j= 21)
    21
        |}]

let%expect_test "%log runtime log levels while-loop" =
  let%track_rtb_sexp result () : int =
    let i = ref 0 in
    let j = ref 0 in
    while !i < 6 do
      (* Intentional empty but not omitted else-branch. *)
      if !i < 2 then [%log "ERROR:", 1, "i=", (!i : int)] else ();
      incr i;
      [%log "WARNING:", 2, "i=", (!i : int)];
      j := (fun { contents } -> !j + contents) i;
      [%log "INFO:", 3, "j=", (!j : int)]
    done;
    !j
  in
  print_endline
  @@ Int.to_string (result (Minidebug_runtime.debug ~global_prefix:"Everything" ()) ());
  print_endline
  @@ Int.to_string
       (result
          (Minidebug_runtime.debug ~values_first_mode:true ~log_level:Nothing
             ~global_prefix:"Nothing" ())
          ());
  print_endline
  @@ Int.to_string
       (result
          (Minidebug_runtime.debug ~values_first_mode:true ~log_level:Nonempty_entries
             ~global_prefix:"Nonempty" ())
          ());
  print_endline
  @@ Int.to_string
       (result
          (Minidebug_runtime.debug ~values_first_mode:true
             ~log_level:(Prefixed [| "ERROR"; "WARN" |])
             ~global_prefix:"Prefixed" ())
          ());
  print_endline
  @@ Int.to_string
       (result
          (Minidebug_runtime.debug ~values_first_mode:true
             ~log_level:(Prefixed_or_result [| "ERROR"; "WARN" |])
             ~global_prefix:"Prefixed_or_result" ())
          ());
  [%expect
    {|
  BEGIN DEBUG SESSION Everything
  "test/test_expect_test.ml":2454:28: Everything result
  ├─"test/test_expect_test.ml":2457:4: Everything while:test_expect_test:2457
  │ ├─"test/test_expect_test.ml":2459:6: Everything <while loop>
  │ │ ├─"test/test_expect_test.ml":2459:21: Everything then:test_expect_test:2459
  │ │ │ └─(ERROR: 1 i= 0)
  │ │ ├─(WARNING: 2 i= 1)
  │ │ ├─"test/test_expect_test.ml":2462:11: Everything fun:test_expect_test:2462
  │ │ └─(INFO: 3 j= 1)
  │ ├─"test/test_expect_test.ml":2459:6: Everything <while loop>
  │ │ ├─"test/test_expect_test.ml":2459:21: Everything then:test_expect_test:2459
  │ │ │ └─(ERROR: 1 i= 1)
  │ │ ├─(WARNING: 2 i= 2)
  │ │ ├─"test/test_expect_test.ml":2462:11: Everything fun:test_expect_test:2462
  │ │ └─(INFO: 3 j= 3)
  │ ├─"test/test_expect_test.ml":2459:6: Everything <while loop>
  │ │ ├─"test/test_expect_test.ml":2459:63: Everything else:test_expect_test:2459
  │ │ ├─(WARNING: 2 i= 3)
  │ │ ├─"test/test_expect_test.ml":2462:11: Everything fun:test_expect_test:2462
  │ │ └─(INFO: 3 j= 6)
  │ ├─"test/test_expect_test.ml":2459:6: Everything <while loop>
  │ │ ├─"test/test_expect_test.ml":2459:63: Everything else:test_expect_test:2459
  │ │ ├─(WARNING: 2 i= 4)
  │ │ ├─"test/test_expect_test.ml":2462:11: Everything fun:test_expect_test:2462
  │ │ └─(INFO: 3 j= 10)
  │ ├─"test/test_expect_test.ml":2459:6: Everything <while loop>
  │ │ ├─"test/test_expect_test.ml":2459:63: Everything else:test_expect_test:2459
  │ │ ├─(WARNING: 2 i= 5)
  │ │ ├─"test/test_expect_test.ml":2462:11: Everything fun:test_expect_test:2462
  │ │ └─(INFO: 3 j= 15)
  │ └─"test/test_expect_test.ml":2459:6: Everything <while loop>
  │   ├─"test/test_expect_test.ml":2459:63: Everything else:test_expect_test:2459
  │   ├─(WARNING: 2 i= 6)
  │   ├─"test/test_expect_test.ml":2462:11: Everything fun:test_expect_test:2462
  │   └─(INFO: 3 j= 21)
  └─result = 21
  21

  BEGIN DEBUG SESSION Nothing
  21

  BEGIN DEBUG SESSION Nonempty
  result = 21
  ├─"test/test_expect_test.ml":2454:28
  └─Nonempty while:test_expect_test:2457
    ├─"test/test_expect_test.ml":2457:4
    ├─Nonempty <while loop>
    │ ├─"test/test_expect_test.ml":2459:6
    │ ├─Nonempty then:test_expect_test:2459
    │ │ ├─"test/test_expect_test.ml":2459:21
    │ │ └─(ERROR: 1 i= 0)
    │ ├─(WARNING: 2 i= 1)
    │ └─(INFO: 3 j= 1)
    ├─Nonempty <while loop>
    │ ├─"test/test_expect_test.ml":2459:6
    │ ├─Nonempty then:test_expect_test:2459
    │ │ ├─"test/test_expect_test.ml":2459:21
    │ │ └─(ERROR: 1 i= 1)
    │ ├─(WARNING: 2 i= 2)
    │ └─(INFO: 3 j= 3)
    ├─Nonempty <while loop>
    │ ├─"test/test_expect_test.ml":2459:6
    │ ├─(WARNING: 2 i= 3)
    │ └─(INFO: 3 j= 6)
    ├─Nonempty <while loop>
    │ ├─"test/test_expect_test.ml":2459:6
    │ ├─(WARNING: 2 i= 4)
    │ └─(INFO: 3 j= 10)
    ├─Nonempty <while loop>
    │ ├─"test/test_expect_test.ml":2459:6
    │ ├─(WARNING: 2 i= 5)
    │ └─(INFO: 3 j= 15)
    └─Nonempty <while loop>
      ├─"test/test_expect_test.ml":2459:6
      ├─(WARNING: 2 i= 6)
      └─(INFO: 3 j= 21)
  21

  BEGIN DEBUG SESSION Prefixed
  Prefixed result
  ├─"test/test_expect_test.ml":2454:28
  └─Prefixed while:test_expect_test:2457
    ├─"test/test_expect_test.ml":2457:4
    ├─Prefixed <while loop>
    │ ├─"test/test_expect_test.ml":2459:6
    │ ├─Prefixed then:test_expect_test:2459
    │ │ ├─"test/test_expect_test.ml":2459:21
    │ │ └─(ERROR: 1 i= 0)
    │ └─(WARNING: 2 i= 1)
    ├─Prefixed <while loop>
    │ ├─"test/test_expect_test.ml":2459:6
    │ ├─Prefixed then:test_expect_test:2459
    │ │ ├─"test/test_expect_test.ml":2459:21
    │ │ └─(ERROR: 1 i= 1)
    │ └─(WARNING: 2 i= 2)
    ├─Prefixed <while loop>
    │ ├─"test/test_expect_test.ml":2459:6
    │ └─(WARNING: 2 i= 3)
    ├─Prefixed <while loop>
    │ ├─"test/test_expect_test.ml":2459:6
    │ └─(WARNING: 2 i= 4)
    ├─Prefixed <while loop>
    │ ├─"test/test_expect_test.ml":2459:6
    │ └─(WARNING: 2 i= 5)
    └─Prefixed <while loop>
      ├─"test/test_expect_test.ml":2459:6
      └─(WARNING: 2 i= 6)
  21

  BEGIN DEBUG SESSION Prefixed_or_result
  result = 21
  ├─"test/test_expect_test.ml":2454:28
  └─Prefixed_or_result while:test_expect_test:2457
    ├─"test/test_expect_test.ml":2457:4
    ├─Prefixed_or_result <while loop>
    │ ├─"test/test_expect_test.ml":2459:6
    │ ├─Prefixed_or_result then:test_expect_test:2459
    │ │ ├─"test/test_expect_test.ml":2459:21
    │ │ └─(ERROR: 1 i= 0)
    │ └─(WARNING: 2 i= 1)
    ├─Prefixed_or_result <while loop>
    │ ├─"test/test_expect_test.ml":2459:6
    │ ├─Prefixed_or_result then:test_expect_test:2459
    │ │ ├─"test/test_expect_test.ml":2459:21
    │ │ └─(ERROR: 1 i= 1)
    │ └─(WARNING: 2 i= 2)
    ├─Prefixed_or_result <while loop>
    │ ├─"test/test_expect_test.ml":2459:6
    │ └─(WARNING: 2 i= 3)
    ├─Prefixed_or_result <while loop>
    │ ├─"test/test_expect_test.ml":2459:6
    │ └─(WARNING: 2 i= 4)
    ├─Prefixed_or_result <while loop>
    │ ├─"test/test_expect_test.ml":2459:6
    │ └─(WARNING: 2 i= 5)
    └─Prefixed_or_result <while loop>
      ├─"test/test_expect_test.ml":2459:6
      └─(WARNING: 2 i= 6)
  21
      |}]

let%expect_test "%log compile time log levels while-loop" =
  let module Debug_runtime = (val Minidebug_runtime.debug ~values_first_mode:true ()) in
  let%track_sexp everything () : int =
    [%log_level
      Everything;
      let i = ref 0 in
      let j = ref 0 in
      while !i < 6 do
        (* Intentional empty but not omitted else-branch. *)
        if !i < 2 then [%log "ERROR:", 1, "i=", (!i : int)] else ();
        incr i;
        [%log "WARNING:", 2, "i=", (!i : int)];
        j := (fun { contents } -> !j + contents) i;
        [%log "INFO:", 3, "j=", (!j : int)]
      done;
      !j]
  in
  let%track_sexp nothing () : int =
    (* The result is still logged, because the binding is outside of %log_level. *)
    [%log_level
      Nothing;
      let i = ref 0 in
      let j = ref 0 in
      while !i < 6 do
        (* Intentional empty but not omitted else-branch. *)
        if !i < 2 then [%log "ERROR:", 1, "i=", (!i : int)] else ();
        incr i;
        [%log "WARNING:", 2, "i=", (!i : int)];
        j := (fun { contents } -> !j + contents) i;
        [%log "INFO:", 3, "j=", (!j : int)]
      done;
      !j]
  in
  let%track_sexp prefixed () : int =
    [%log_level
      Prefixed_or_result [| "WARN"; "ERROR" |];
      let i = ref 0 in
      let j = ref 0 in
      while !i < 6 do
        (* Intentional empty but not omitted else-branch. *)
        if !i < 2 then [%log "ERROR:", 1, "i=", (!i : int)] else ();
        incr i;
        [%log "WARNING:", 2, "i=", (!i : int)];
        j := (fun { contents } -> !j + contents) i;
        [%log "INFO:", 3, "j=", (!j : int)]
      done;
      !j]
  in
  print_endline @@ Int.to_string @@ everything ();
  print_endline @@ Int.to_string @@ nothing ();
  print_endline @@ Int.to_string @@ prefixed ();
  [%expect
    {|
  BEGIN DEBUG SESSION
  everything = 21
  ├─"test/test_expect_test.ml":2640:28
  └─while:test_expect_test:2645
    ├─"test/test_expect_test.ml":2645:6
    ├─<while loop>
    │ ├─"test/test_expect_test.ml":2647:8
    │ ├─then:test_expect_test:2647
    │ │ ├─"test/test_expect_test.ml":2647:23
    │ │ └─(ERROR: 1 i= 0)
    │ ├─(WARNING: 2 i= 1)
    │ ├─fun:test_expect_test:2650
    │ │ └─"test/test_expect_test.ml":2650:13
    │ └─(INFO: 3 j= 1)
    ├─<while loop>
    │ ├─"test/test_expect_test.ml":2647:8
    │ ├─then:test_expect_test:2647
    │ │ ├─"test/test_expect_test.ml":2647:23
    │ │ └─(ERROR: 1 i= 1)
    │ ├─(WARNING: 2 i= 2)
    │ ├─fun:test_expect_test:2650
    │ │ └─"test/test_expect_test.ml":2650:13
    │ └─(INFO: 3 j= 3)
    ├─<while loop>
    │ ├─"test/test_expect_test.ml":2647:8
    │ ├─else:test_expect_test:2647
    │ │ └─"test/test_expect_test.ml":2647:65
    │ ├─(WARNING: 2 i= 3)
    │ ├─fun:test_expect_test:2650
    │ │ └─"test/test_expect_test.ml":2650:13
    │ └─(INFO: 3 j= 6)
    ├─<while loop>
    │ ├─"test/test_expect_test.ml":2647:8
    │ ├─else:test_expect_test:2647
    │ │ └─"test/test_expect_test.ml":2647:65
    │ ├─(WARNING: 2 i= 4)
    │ ├─fun:test_expect_test:2650
    │ │ └─"test/test_expect_test.ml":2650:13
    │ └─(INFO: 3 j= 10)
    ├─<while loop>
    │ ├─"test/test_expect_test.ml":2647:8
    │ ├─else:test_expect_test:2647
    │ │ └─"test/test_expect_test.ml":2647:65
    │ ├─(WARNING: 2 i= 5)
    │ ├─fun:test_expect_test:2650
    │ │ └─"test/test_expect_test.ml":2650:13
    │ └─(INFO: 3 j= 15)
    └─<while loop>
      ├─"test/test_expect_test.ml":2647:8
      ├─else:test_expect_test:2647
      │ └─"test/test_expect_test.ml":2647:65
      ├─(WARNING: 2 i= 6)
      ├─fun:test_expect_test:2650
      │ └─"test/test_expect_test.ml":2650:13
      └─(INFO: 3 j= 21)
  21
  nothing = 21
  └─"test/test_expect_test.ml":2655:25
  21
  prefixed = 21
  ├─"test/test_expect_test.ml":2671:26
  └─while:test_expect_test:2676
    ├─"test/test_expect_test.ml":2676:6
    ├─<while loop>
    │ ├─"test/test_expect_test.ml":2678:8
    │ ├─then:test_expect_test:2678
    │ │ ├─"test/test_expect_test.ml":2678:23
    │ │ └─(ERROR: 1 i= 0)
    │ └─(WARNING: 2 i= 1)
    ├─<while loop>
    │ ├─"test/test_expect_test.ml":2678:8
    │ ├─then:test_expect_test:2678
    │ │ ├─"test/test_expect_test.ml":2678:23
    │ │ └─(ERROR: 1 i= 1)
    │ └─(WARNING: 2 i= 2)
    ├─<while loop>
    │ ├─"test/test_expect_test.ml":2678:8
    │ └─(WARNING: 2 i= 3)
    ├─<while loop>
    │ ├─"test/test_expect_test.ml":2678:8
    │ └─(WARNING: 2 i= 4)
    ├─<while loop>
    │ ├─"test/test_expect_test.ml":2678:8
    │ └─(WARNING: 2 i= 5)
    └─<while loop>
      ├─"test/test_expect_test.ml":2678:8
      └─(WARNING: 2 i= 6)
  21
      |}]

let%expect_test "%log compile time log levels runtime-passing while-loop" =
  let module Debug_runtime =
    (val Minidebug_runtime.debug ~global_prefix:"TOPLEVEL" ~values_first_mode:true ())
  in
  let%debug_sexp () =
    ([%log_level
       Nothing;
       let%track_rtb_sexp nothing () : int =
         let i = ref 0 in
         let j = ref 0 in
         while !i < 6 do
           (* Intentional empty but not omitted else-branch. *)
           if !i < 2 then [%log "ERROR:", 1, "i=", (!i : int)] else ();
           incr i;
           [%log "WARNING:", 2, "i=", (!i : int)];
           j := (fun { contents } -> !j + contents) i;
           [%log "INFO:", 3, "j=", (!j : int)]
         done;
         !j
       in
       print_endline @@ Int.to_string
       @@ nothing
            (Minidebug_runtime.debug ~global_prefix:"nothing" ~values_first_mode:true ())
            ()]);
    [%log_level
      Prefixed_or_result [| "WARN"; "ERROR" |];
      let%track_rtb_sexp prefixed () : int =
        let i = ref 0 in
        let j = ref 0 in
        while !i < 6 do
          (* Intentional empty but not omitted else-branch. *)
          if !i < 2 then [%log "ERROR:", 1, "i=", (!i : int)] else ();
          incr i;
          [%log "WARNING:", 2, "i=", (!i : int)];
          j := (fun { contents } -> !j + contents) i;
          [%log "INFO:", 3, "j=", (!j : int)]
        done;
        !j
      in
      print_endline @@ Int.to_string
      @@ prefixed
           (Minidebug_runtime.debug ~global_prefix:"prefixed" ~values_first_mode:true ())
           ()]
  in
  [%expect
    {|
  BEGIN DEBUG SESSION TOPLEVEL

  BEGIN DEBUG SESSION nothing
  21

  BEGIN DEBUG SESSION prefixed
  prefixed = 21
  ├─"test/test_expect_test.ml":2807:34
  └─prefixed while:test_expect_test:2810
    ├─"test/test_expect_test.ml":2810:8
    ├─prefixed <while loop>
    │ ├─"test/test_expect_test.ml":2812:10
    │ ├─prefixed then:test_expect_test:2812
    │ │ ├─"test/test_expect_test.ml":2812:25
    │ │ └─(ERROR: 1 i= 0)
    │ └─(WARNING: 2 i= 1)
    ├─prefixed <while loop>
    │ ├─"test/test_expect_test.ml":2812:10
    │ ├─prefixed then:test_expect_test:2812
    │ │ ├─"test/test_expect_test.ml":2812:25
    │ │ └─(ERROR: 1 i= 1)
    │ └─(WARNING: 2 i= 2)
    ├─prefixed <while loop>
    │ ├─"test/test_expect_test.ml":2812:10
    │ └─(WARNING: 2 i= 3)
    ├─prefixed <while loop>
    │ ├─"test/test_expect_test.ml":2812:10
    │ └─(WARNING: 2 i= 4)
    ├─prefixed <while loop>
    │ ├─"test/test_expect_test.ml":2812:10
    │ └─(WARNING: 2 i= 5)
    └─prefixed <while loop>
      ├─"test/test_expect_test.ml":2812:10
      └─(WARNING: 2 i= 6)
  21
  TOPLEVEL ()
  └─"test/test_expect_test.ml":2785:17
      |}]

let%expect_test "%log track while-loop result" =
  let module Debug_runtime = (val Minidebug_runtime.debug ~values_first_mode:true ()) in
  let%track_sexp result =
    let i = ref 0 in
    let j = ref 0 in
    while !i < 6 do
      [%log 1, "i=", (!i : int)];
      incr i;
      [%log 2, "i=", (!i : int)];
      j := !j + !i;
      [%log_result 3, "j=", (!j : int)]
    done;
    [%log_result (!j : int)];
    !j
  in
  print_endline @@ Int.to_string result;
  [%expect
    {|
    BEGIN DEBUG SESSION
    21
    ├─"test/test_expect_test.ml":2868:17
    └─while:test_expect_test:2871
      ├─"test/test_expect_test.ml":2871:4
      ├─(3 j= 1)
      │ ├─"test/test_expect_test.ml":2872:6
      │ ├─<while loop>
      │ ├─(1 i= 0)
      │ └─(2 i= 1)
      ├─(3 j= 3)
      │ ├─"test/test_expect_test.ml":2872:6
      │ ├─<while loop>
      │ ├─(1 i= 1)
      │ └─(2 i= 2)
      ├─(3 j= 6)
      │ ├─"test/test_expect_test.ml":2872:6
      │ ├─<while loop>
      │ ├─(1 i= 2)
      │ └─(2 i= 3)
      ├─(3 j= 10)
      │ ├─"test/test_expect_test.ml":2872:6
      │ ├─<while loop>
      │ ├─(1 i= 3)
      │ └─(2 i= 4)
      ├─(3 j= 15)
      │ ├─"test/test_expect_test.ml":2872:6
      │ ├─<while loop>
      │ ├─(1 i= 4)
      │ └─(2 i= 5)
      └─(3 j= 21)
        ├─"test/test_expect_test.ml":2872:6
        ├─<while loop>
        ├─(1 i= 5)
        └─(2 i= 6)
    21
        |}]

let%expect_test "%log without scope" =
  let module Debug_runtime = (val Minidebug_runtime.debug ~print_entry_ids:true ()) in
  let i = 3 in
  let pi = 3.14 in
  let l = [ 1; 2; 3 ] in
  (* Orphaned logs are often prevented by the typechecker complaining about missing __entry_id.
     But they can happen with closures and other complex ways to interleave uses of a runtime. *)
  let foo = ref @@ fun () -> () in
  let%debug_show _bar : unit =
    foo :=
      fun () ->
        [%log "This is like", (i : int), "or", (pi : float), "above"];
        [%log "tau =", (pi *. 2. : float)];
        [%log 4 :: l];
        [%log i :: (l : int list)];
        [%log (i : int) :: l]
  in
  let () = !foo () in
  [%expect
    {|
          BEGIN DEBUG SESSION
          "test/test_expect_test.ml":2930:17: {#1} _bar
          └─_bar = ()
          {orphaned from #1}
          └─("This is like", 3, "or", 3.14, "above")
          {orphaned from #1}
          └─("tau =", 6.28)
          {orphaned from #1}
          └─[4; 1; 2; 3]
          {orphaned from #1}
          └─[3; 1; 2; 3]
          {orphaned from #1}
          └─[3; 1; 2; 3] |}]

let%expect_test "%log without scope values_first_mode" =
  let module Debug_runtime =
    (val Minidebug_runtime.debug ~print_entry_ids:true ~values_first_mode:true ())
  in
  let i = 3 in
  let pi = 3.14 in
  let l = [ 1; 2; 3 ] in
  let foo = ref @@ fun () -> () in
  let%debug_show _bar : unit =
    foo :=
      fun () ->
        [%log "This is like", (i : int), "or", (pi : float), "above"];
        [%log "tau =", (pi *. 2. : float)];
        [%log 4 :: l];
        [%log i :: (l : int list)];
        [%log (i : int) :: l]
  in
  let () = !foo () in
  [%expect
    {|
          BEGIN DEBUG SESSION
          _bar = ()
          └─"test/test_expect_test.ml":2964:17: {#1}
          ("This is like", 3, "or", 3.14, "above")
          └─{orphaned from #1}
          ("tau =", 6.28)
          └─{orphaned from #1}
          [4; 1; 2; 3]
          └─{orphaned from #1}
          [3; 1; 2; 3]
          └─{orphaned from #1}
          [3; 1; 2; 3]
          └─{orphaned from #1} |}]

let%expect_test "%log with print_entry_ids, mixed up scopes" =
  let module Debug_runtime =
    (val Minidebug_runtime.debug ~print_entry_ids:true ~values_first_mode:true ())
  in
  let i = 3 in
  let pi = 3.14 in
  let l = [ 1; 2; 3 ] in
  (* Messing with the structure of the logs might lead to confusing output. *)
  let foo1 = ref @@ fun () -> () in
  let foo2 = ref @@ fun () -> () in
  let%debug_show bar callback : unit =
    foo1 :=
      fun () ->
        [%log "This is like", (i : int), "or", (pi : float), "above"];
        [%log "tau =", (pi *. 2. : float)];
        callback ()
  in
  let%debug_show baz callback : unit =
    foo2 :=
      fun () ->
        [%log i :: (l : int list)];
        [%log (i : int) :: l];
        callback ()
  in
  let () =
    bar !foo2;
    baz !foo1;
    bar !foo2
  in
  let%debug_show _foobar : unit = !foo1 () in
  let () = !foo2 () in
  [%expect
    {|
          BEGIN DEBUG SESSION
          bar = ()
          └─"test/test_expect_test.ml":3000:21: {#1}
          baz = ()
          └─"test/test_expect_test.ml":3007:21: {#2}
          bar = ()
          └─"test/test_expect_test.ml":3000:21: {#3}
          _foobar = ()
          ├─"test/test_expect_test.ml":3019:17: {#4}
          ├─("This is like", 3, "or", 3.14, "above")
          ├─("tau =", 6.28)
          ├─[3; 1; 2; 3]
          ├─[3; 1; 2; 3]
          ├─("This is like", 3, "or", 3.14, "above")
          └─("tau =", 6.28)
          [3; 1; 2; 3]
          └─{orphaned from #2}
          [3; 1; 2; 3]
          └─{orphaned from #2}
          ("This is like", 3, "or", 3.14, "above")
          └─{orphaned from #1}
          ("tau =", 6.28)
          └─{orphaned from #1} |}]

let%expect_test "%diagn_show ignores type annots" =
  let module Debug_runtime = (val Minidebug_runtime.debug ~values_first_mode:true ()) in
  let%diagn_show toplevel =
    let bar { first : int; second : int } : int =
      let { first : int = a; second : int = b } = { first; second = second + 3 } in
      let y : int = a + 1 in
      [%log "for bar, b-3", (b - 3 : int)];
      (b - 3) * y
    in
    let () = print_endline @@ Int.to_string @@ bar { first = 7; second = 42 } in
    let baz { first : int; second : int } : int =
      let { first : int; second : int } = { first = first + 1; second = second + 3 } in
      [%log "for baz, f squared", (first * first : int)];
      (first * first) + second
    in
    print_endline @@ Int.to_string @@ baz { first = 7; second = 42 }
  in
  ignore toplevel;
  [%expect
    {|
      BEGIN DEBUG SESSION
      336
      109
      toplevel
      ├─"test/test_expect_test.ml":3049:17
      ├─("for bar, b-3", 42)
      └─("for baz, f squared", 64) |}]

let%expect_test "%diagn_show ignores non-empty bindings" =
  let module Debug_runtime = (val Minidebug_runtime.debug ~values_first_mode:true ()) in
  let%diagn_show bar { first : int; second : int } : int =
    let { first : int = a; second : int = b } = { first; second = second + 3 } in
    let y : int = a + 1 in
    [%log "for bar, b-3", (b - 3 : int)];
    (b - 3) * y
  in
  let () = print_endline @@ Int.to_string @@ bar { first = 7; second = 42 } in
  let%diagn_show baz { first : int; second : int } : int =
    let foo { first : int; second : int } : int =
      [%log "foo baz, f squared", (first * first : int)];
      (first * first) + second
    in
    foo { first; second }
  in
  let () = print_endline @@ Int.to_string @@ baz { first = 7; second = 42 } in
  [%expect
    {|
      BEGIN DEBUG SESSION
      bar
      ├─"test/test_expect_test.ml":3077:21
      └─("for bar, b-3", 42)
      336
      baz
      ├─"test/test_expect_test.ml":3084:21
      └─("foo baz, f squared", 49)
      91 |}]

let%expect_test "%diagn_show no logs" =
  let module Debug_runtime = (val Minidebug_runtime.debug ~values_first_mode:true ()) in
  let%diagn_show bar { first : int; second : int } : int =
    let { first : int = a; second : int = b } = { first; second = second + 3 } in
    let y : int = a + 1 in
    (b - 3) * y
  in
  let () = print_endline @@ Int.to_string @@ bar { first = 7; second = 42 } in
  let%diagn_show baz { first : int; second : int } : int =
    let foo { first : int; second : int } : int = (first * first) + second in
    foo { first; second }
  in
  let () = print_endline @@ Int.to_string @@ baz { first = 7; second = 42 } in
  [%expect {|
      BEGIN DEBUG SESSION
      336
      91 |}]

let%expect_test "%debug_show log level Prefixed_or_result [||]" =
  let module Debug_runtime = (val Minidebug_runtime.debug ~values_first_mode:true ()) in
  let%debug_show () =
    [%log_level
      Prefixed_or_result [||];
      let bar { first : int; second : int } : int =
        let { first : int = a; second : int = b } = { first; second = second + 3 } in
        let y : int = a + 1 in
        [%log "for bar, b-3", (b - 3 : int)];
        (b - 3) * y
      in
      let baz { first : int; second : int } : int =
        let { first : int; second : int } = { first = first + 1; second = second + 3 } in
        [%log "for baz, f squared", (first * first : int)];
        (first * first) + second
      in
      print_endline @@ Int.to_string @@ bar { first = 7; second = 42 };
      print_endline @@ Int.to_string @@ baz { first = 7; second = 42 }]
  in
  [%expect
    {|
      BEGIN DEBUG SESSION
      336
      109
      ()
      ├─"test/test_expect_test.ml":3124:17
      ├─bar = 336
      │ ├─"test/test_expect_test.ml":3127:14
      │ ├─{first=a; second=b}
      │ │ ├─"test/test_expect_test.ml":3128:12
      │ │ └─<values>
      │ │   ├─a = 7
      │ │   └─b = 45
      │ ├─y = 8
      │ │ └─"test/test_expect_test.ml":3129:12
      │ └─("for bar, b-3", 42)
      └─baz = 109
        ├─"test/test_expect_test.ml":3133:14
        ├─{first; second}
        │ ├─"test/test_expect_test.ml":3134:12
        │ └─<values>
        │   ├─first = 8
        │   └─second = 45
        └─("for baz, f squared", 64) |}]
(* Compare to:
    {|
    BEGIN DEBUG SESSION
    bar = 336
    ├─"test/test_expect_test.ml":1898:21-1901:15
    ├─first = 7
    ├─second = 42
    ├─{first=a; second=b}
    │ ├─"test/test_expect_test.ml":1899:8
    │ └─<values>
    │   ├─a = 7
    │   └─b = 45
    └─y = 8
      └─"test/test_expect_test.ml":1900:8
    336
    baz = 109
    ├─"test/test_expect_test.ml":1904:10-1906:28
    ├─first = 7
    ├─second = 42
    └─{first; second}
      ├─"test/test_expect_test.ml":1905:8
      └─<values>
        ├─first = 8
        └─second = 45
    109 |} *)

let%expect_test "%debug_show log level Prefixed_or_result [||] compile+runtime" =
  let module Debug_runtime =
    (val Minidebug_runtime.debug ~values_first_mode:true
           ~log_level:(Prefixed_or_result [||]) ())
  in
  let%debug_show () =
    [%log_level
      Prefixed_or_result [||];
      let bar { first : int; second : int } : int =
        let { first : int = a; second : int = b } = { first; second = second + 3 } in
        let y : int = a + 1 in
        [%log "for bar, b-3", (b - 3 : int)];
        (b - 3) * y
      in
      let baz { first : int; second : int } : int =
        let { first : int; second : int } = { first = first + 1; second = second + 3 } in
        [%log "for baz, f squared", (first * first : int)];
        (first * first) + second
      in
      print_endline @@ Int.to_string @@ bar { first = 7; second = 42 };
      print_endline @@ Int.to_string @@ baz { first = 7; second = 42 }]
  in
  [%expect
    {|
        BEGIN DEBUG SESSION
        336
        109
        ()
        ├─"test/test_expect_test.ml":3197:17
        ├─bar = 336
        │ ├─"test/test_expect_test.ml":3200:14
        │ └─("for bar, b-3", 42)
        └─baz = 109
          ├─"test/test_expect_test.ml":3206:14
          └─("for baz, f squared", 64) |}]

let%expect_test "%debug_this_show PrintBox snapshot" =
  let module Debug_runtime = (val Minidebug_runtime.debug ~values_first_mode:true ()) in
  let%debug_this_show rec loop_highlight (x : int) : int =
    let z : int = (x - 1) / 2 in
    if z = 3 || x = 3 then Debug_runtime.snapshot ();
    if x <= 0 then 0 else z + loop_highlight (z + (x / 2))
  in
  print_endline @@ Int.to_string @@ loop_highlight 7;
  [%expect
    {|
      BEGIN DEBUG SESSION
      loop_highlight
      ├─"test/test_expect_test.ml":3230:41
      ├─x = 7
      └─z = 3
        └─"test/test_expect_test.ml":3231:8
      [2J[1;1Hloop_highlight
      ├─"test/test_expect_test.ml":3230:41
      ├─x = 7
      ├─z = 3
      │ └─"test/test_expect_test.ml":3231:8
      └─loop_highlight
        ├─"test/test_expect_test.ml":3230:41
        ├─x = 6
        ├─z = 2
        │ └─"test/test_expect_test.ml":3231:8
        └─loop_highlight
          ├─"test/test_expect_test.ml":3230:41
          ├─x = 5
          ├─z = 2
          │ └─"test/test_expect_test.ml":3231:8
          └─loop_highlight
            ├─"test/test_expect_test.ml":3230:41
            ├─x = 4
            ├─z = 1
            │ └─"test/test_expect_test.ml":3231:8
            └─loop_highlight
              ├─"test/test_expect_test.ml":3230:41
              ├─x = 3
              └─z = 1
                └─"test/test_expect_test.ml":3231:8
      [2J[1;1Hloop_highlight = 9
      ├─"test/test_expect_test.ml":3230:41
      ├─x = 7
      ├─z = 3
      │ └─"test/test_expect_test.ml":3231:8
      └─loop_highlight = 6
        ├─"test/test_expect_test.ml":3230:41
        ├─x = 6
        ├─z = 2
        │ └─"test/test_expect_test.ml":3231:8
        └─loop_highlight = 4
          ├─"test/test_expect_test.ml":3230:41
          ├─x = 5
          ├─z = 2
          │ └─"test/test_expect_test.ml":3231:8
          └─loop_highlight = 2
            ├─"test/test_expect_test.ml":3230:41
            ├─x = 4
            ├─z = 1
            │ └─"test/test_expect_test.ml":3231:8
            └─loop_highlight = 1
              ├─"test/test_expect_test.ml":3230:41
              ├─x = 3
              ├─z = 1
              │ └─"test/test_expect_test.ml":3231:8
              └─loop_highlight = 0
                ├─"test/test_expect_test.ml":3230:41
                ├─x = 2
                ├─z = 0
                │ └─"test/test_expect_test.ml":3231:8
                └─loop_highlight = 0
                  ├─"test/test_expect_test.ml":3230:41
                  ├─x = 1
                  ├─z = 0
                  │ └─"test/test_expect_test.ml":3231:8
                  └─loop_highlight = 0
                    ├─"test/test_expect_test.ml":3230:41
                    ├─x = 0
                    └─z = 0
                      └─"test/test_expect_test.ml":3231:8
      9 |}]

let%expect_test "%track_show don't show unannotated non-function bindings" =
  let module Debug_runtime =
    (val Minidebug_runtime.debug ~values_first_mode:true
           ~log_level:(Prefixed_or_result [||]) ())
  in
  let result =
    [%track_show
      let%ppx_minidebug_noop_for_testing point =
        let open! Minidebug_runtime in
        (1, 2)
      in
      ignore point]
  in
  ignore result;
  [%expect {|
        BEGIN DEBUG SESSION |}]

let%expect_test "%log_printbox" =
  let module Debug_runtime = (val Minidebug_runtime.debug ~values_first_mode:true ()) in
  let%debug_show foo () : unit =
    [%log_printbox
      PrintBox.init_grid ~line:5 ~col:5 (fun ~line ~col ->
          PrintBox.sprintf "%d/%d" line col)];
    [%log "No bars but pad:"];
    [%log_printbox
      PrintBox.(
        init_grid ~bars:false ~line:5 ~col:5 (fun ~line ~col ->
            pad @@ sprintf "%d/%d" line col))];
    [%log "Now with a frame:"];
    [%log_printbox
      PrintBox.(
        frame
        @@ init_grid ~line:5 ~col:5 (fun ~line ~col -> PrintBox.sprintf "%d/%d" line col))]
  in
  let () = foo () in
  [%expect
    {|
      BEGIN DEBUG SESSION
      foo = ()
      ├─"test/test_expect_test.ml":3330:21
      ├─0/0│0/1│0/2│0/3│0/4
      │ ───┼───┼───┼───┼───
      │ 1/0│1/1│1/2│1/3│1/4
      │ ───┼───┼───┼───┼───
      │ 2/0│2/1│2/2│2/3│2/4
      │ ───┼───┼───┼───┼───
      │ 3/0│3/1│3/2│3/3│3/4
      │ ───┼───┼───┼───┼───
      │ 4/0│4/1│4/2│4/3│4/4
      ├─"No bars but pad:"
      ├─
      │  0/0  0/1  0/2  0/3  0/4
      │
      │
      │  1/0  1/1  1/2  1/3  1/4
      │
      │
      │  2/0  2/1  2/2  2/3  2/4
      │
      │
      │  3/0  3/1  3/2  3/3  3/4
      │
      │
      │  4/0  4/1  4/2  4/3  4/4
      │
      ├─"Now with a frame:"
      └─┬───┬───┬───┬───┬───┐
        │0/0│0/1│0/2│0/3│0/4│
        ├───┼───┼───┼───┼───┤
        │1/0│1/1│1/2│1/3│1/4│
        ├───┼───┼───┼───┼───┤
        │2/0│2/1│2/2│2/3│2/4│
        ├───┼───┼───┼───┼───┤
        │3/0│3/1│3/2│3/3│3/4│
        ├───┼───┼───┼───┼───┤
        │4/0│4/1│4/2│4/3│4/4│
        └───┴───┴───┴───┴───┘ |}]

let%expect_test "%log_printbox flushing" =
  let module Debug_runtime = (val Minidebug_runtime.debug_flushing ()) in
  let%debug_show foo () : unit =
    [%log_printbox
      PrintBox.init_grid ~line:5 ~col:5 (fun ~line ~col ->
          PrintBox.sprintf "%d/%d" line col)];
    [%log "No bars but pad:"];
    [%log_printbox
      PrintBox.(
        init_grid ~bars:false ~line:5 ~col:5 (fun ~line ~col ->
            pad @@ sprintf "%d/%d" line col))];
    let bar () : unit =
      [%log "Now with a frame:"];
      [%log_printbox
        PrintBox.(
          frame
          @@ init_grid ~line:5 ~col:5 (fun ~line ~col ->
                 PrintBox.sprintf "%d/%d" line col))]
    in
    bar ()
  in
  let () = foo () in
  [%expect
    {|
      BEGIN DEBUG SESSION
      foo begin "test/test_expect_test.ml":3391:21:
       0/0│0/1│0/2│0/3│0/4
       ───┼───┼───┼───┼───
       1/0│1/1│1/2│1/3│1/4
       ───┼───┼───┼───┼───
       2/0│2/1│2/2│2/3│2/4
       ───┼───┼───┼───┼───
       3/0│3/1│3/2│3/3│3/4
       ───┼───┼───┼───┼───
       4/0│4/1│4/2│4/3│4/4
       "No bars but pad:"

        0/0  0/1  0/2  0/3  0/4


        1/0  1/1  1/2  1/3  1/4


        2/0  2/1  2/2  2/3  2/4


        3/0  3/1  3/2  3/3  3/4


        4/0  4/1  4/2  4/3  4/4
       bar begin "test/test_expect_test.ml":3400:12:
        "Now with a frame:"
        ┌───┬───┬───┬───┬───┐
        │0/0│0/1│0/2│0/3│0/4│
        ├───┼───┼───┼───┼───┤
        │1/0│1/1│1/2│1/3│1/4│
        ├───┼───┼───┼───┼───┤
        │2/0│2/1│2/2│2/3│2/4│
        ├───┼───┼───┼───┼───┤
        │3/0│3/1│3/2│3/3│3/4│
        ├───┼───┼───┼───┼───┤
        │4/0│4/1│4/2│4/3│4/4│
        └───┴───┴───┴───┴───┘
        bar = ()
       bar end
       foo = ()
      foo end |}]
