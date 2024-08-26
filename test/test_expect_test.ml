type t = { first : int; second : int } [@@deriving show]

let sexp_of_string s = Sexplib0.Sexp.Atom s
let sexp_of_list f l = Sexplib0.Sexp.List (List.map f l)
let sexp_of_unit () = Sexplib0.Sexp.List []
let sexp_of_int i = Sexplib0.Sexp.Atom (string_of_int i)
let sexp_of_float n = Sexplib0.Sexp.Atom (string_of_float n)

let%expect_test "%debug_show flushing to a file" =
  let module Debug_runtime =
    (val Minidebug_runtime.debug_flushing
           ~filename:"../../../debugger_expect_show_flushing" ())
  in
  let%debug_show rec loop (depth : int) (x : t) : int =
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
  let module Debug_runtime = (val Minidebug_runtime.debug_flushing ~time_tagged:Clock ())
  in
  let%debug_show bar (x : t) : int =
    let y : int = x.first + 1 in
    x.second * y
  in
  let () = print_endline @@ Int.to_string @@ bar { first = 7; second = 42 } in
  let%debug_show baz (x : t) : int =
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
    baz begin "test/test_expect_test.ml":33:21: YYYY-MM-DD HH:MM:SS.NNNNNN
     x = { Test_expect_test.first = 7; second = 42 }
     _yz begin "test/test_expect_test.ml":34:19: YYYY-MM-DD HH:MM:SS.NNNNNN
      _yz = (8, 3)
     YYYY-MM-DD HH:MM:SS.NNNNNN - _yz end
     baz = 339
    YYYY-MM-DD HH:MM:SS.NNNNNN - baz end
    339
    |}]

let%expect_test "%debug_show flushing to stdout" =
  let module Debug_runtime =
    (val Minidebug_runtime.debug_flushing ~time_tagged:Elapsed ())
  in
  let%debug_show bar (x : t) : int =
    let y : int = x.first + 1 in
    x.second * y
  in
  let () = print_endline @@ Int.to_string @@ bar { first = 7; second = 42 } in
  let%debug_show baz (x : t) : int =
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
  let output =
    Str.global_replace
      (Str.regexp {|[0-9]+\(\.[0-9]+\)?.?s / [0-9]+ns|})
      "NNN.NNxs / NNNNNNNns" output
  in
  print_endline output;
  [%expect
    {|
    BEGIN DEBUG SESSION at elapsed NNN.NNxs / NNNNNNNns, corresponding to time YYYY-MM-DD HH:MM:SS.NNNNNN
    bar begin "test/test_expect_test.ml":71:21: NNN.NNxs / NNNNNNNns
     x = { Test_expect_test.first = 7; second = 42 }
     y begin "test/test_expect_test.ml":72:8: NNN.NNxs / NNNNNNNns
      y = 8
     NNN.NNxs / NNNNNNNns - y end
     bar = 336
    NNN.NNxs / NNNNNNNns - bar end
    336
    baz begin "test/test_expect_test.ml":76:21: NNN.NNxs / NNNNNNNns
     x = { Test_expect_test.first = 7; second = 42 }
     _yz begin "test/test_expect_test.ml":77:19: NNN.NNxs / NNNNNNNns
      _yz = (8, 3)
     NNN.NNxs / NNNNNNNns - _yz end
     baz = 339
    NNN.NNxs / NNNNNNNns - baz end
    339
    |}]

let%expect_test "%debug_show flushing to stdout, time spans" =
  let module Debug_runtime =
    (val Minidebug_runtime.debug_flushing ~elapsed_times:Microseconds ())
  in
  let%debug_show bar (x : t) : int =
    let y : int = x.first + 1 in
    x.second * y
  in
  let () = print_endline @@ Int.to_string @@ bar { first = 7; second = 42 } in
  let%debug_show baz (x : t) : int =
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
    bar begin "test/test_expect_test.ml":119:21:
     x = { Test_expect_test.first = 7; second = 42 }
     y begin "test/test_expect_test.ml":120:8:
      y = 8
     <N.NNμs> y end
     bar = 336
    <N.NNμs> bar end
    336
    baz begin "test/test_expect_test.ml":124:21:
     x = { Test_expect_test.first = 7; second = 42 }
     _yz begin "test/test_expect_test.ml":125:19:
      _yz = (8, 3)
     <N.NNμs> _yz end
     baz = 339
    <N.NNμs> baz end
    339
    |}]

let%expect_test "%debug_show flushing with global prefix" =
  let module Debug_runtime =
    (val Minidebug_runtime.debug_flushing ~time_tagged:Not_tagged ~global_prefix:"test-51"
           ())
  in
  let%debug_show bar (x : t) : int =
    let y : int = x.first + 1 in
    x.second * y
  in
  let () = print_endline @@ Int.to_string @@ bar { first = 7; second = 42 } in
  let%debug_show baz (x : t) : int =
    let ((y, z) as _yz) : int * int = (x.first + 1, 3) in
    (x.second * y) + z
  in
  let () = print_endline @@ Int.to_string @@ baz { first = 7; second = 42 } in
  let output = [%expect.output] in
  print_endline output;
  [%expect
    {|
    BEGIN DEBUG SESSION test-51
    test-51 bar begin "test/test_expect_test.ml":160:21:
     x = { Test_expect_test.first = 7; second = 42 }
     test-51 y begin "test/test_expect_test.ml":161:8:
      y = 8
     test-51 y end
     bar = 336
    test-51 bar end
    336
    test-51 baz begin "test/test_expect_test.ml":165:21:
     x = { Test_expect_test.first = 7; second = 42 }
     test-51 _yz begin "test/test_expect_test.ml":166:19:
      _yz = (8, 3)
     test-51 _yz end
     baz = 339
    test-51 baz end
    339
    |}]

let%expect_test "%debug_show disabled subtree" =
  let module Debug_runtime = (val Minidebug_runtime.debug ()) in
  let%debug_show rec loop_complete (x : int) : int =
    let z : int = (x - 1) / 2 in
    if x <= 0 then 0 else z + loop_complete (z + (x / 2))
  in
  let () = print_endline @@ Int.to_string @@ loop_complete 7 in
  [%expect
    {|
    BEGIN DEBUG SESSION
    "test/test_expect_test.ml":195:35: loop_complete
    ├─x = 7
    ├─"test/test_expect_test.ml":196:8: z
    │ └─z = 3
    ├─"test/test_expect_test.ml":195:35: loop_complete
    │ ├─x = 6
    │ ├─"test/test_expect_test.ml":196:8: z
    │ │ └─z = 2
    │ ├─"test/test_expect_test.ml":195:35: loop_complete
    │ │ ├─x = 5
    │ │ ├─"test/test_expect_test.ml":196:8: z
    │ │ │ └─z = 2
    │ │ ├─"test/test_expect_test.ml":195:35: loop_complete
    │ │ │ ├─x = 4
    │ │ │ ├─"test/test_expect_test.ml":196:8: z
    │ │ │ │ └─z = 1
    │ │ │ ├─"test/test_expect_test.ml":195:35: loop_complete
    │ │ │ │ ├─x = 3
    │ │ │ │ ├─"test/test_expect_test.ml":196:8: z
    │ │ │ │ │ └─z = 1
    │ │ │ │ ├─"test/test_expect_test.ml":195:35: loop_complete
    │ │ │ │ │ ├─x = 2
    │ │ │ │ │ ├─"test/test_expect_test.ml":196:8: z
    │ │ │ │ │ │ └─z = 0
    │ │ │ │ │ ├─"test/test_expect_test.ml":195:35: loop_complete
    │ │ │ │ │ │ ├─x = 1
    │ │ │ │ │ │ ├─"test/test_expect_test.ml":196:8: z
    │ │ │ │ │ │ │ └─z = 0
    │ │ │ │ │ │ ├─"test/test_expect_test.ml":195:35: loop_complete
    │ │ │ │ │ │ │ ├─x = 0
    │ │ │ │ │ │ │ ├─"test/test_expect_test.ml":196:8: z
    │ │ │ │ │ │ │ │ └─z = 0
    │ │ │ │ │ │ │ └─loop_complete = 0
    │ │ │ │ │ │ └─loop_complete = 0
    │ │ │ │ │ └─loop_complete = 0
    │ │ │ │ └─loop_complete = 1
    │ │ │ └─loop_complete = 2
    │ │ └─loop_complete = 4
    │ └─loop_complete = 6
    └─loop_complete = 9
    9
    |}];
  let%debug_show rec loop_changes (x : int) : int =
    let z : int = (x - 1) / 2 in
    (* The call [x = 2] is not printed because it is a descendant of the no-debug call [x
       = 4]. *)
    Debug_runtime.no_debug_if (x <> 6 && x <> 2 && (z + 1) * 2 = x);
    if x <= 0 then 0 else z + loop_changes (z + (x / 2))
  in
  let () = print_endline @@ Int.to_string @@ loop_changes 7 in
  [%expect
    {|
    "test/test_expect_test.ml":245:34: loop_changes
    ├─x = 7
    ├─"test/test_expect_test.ml":246:8: z
    │ └─z = 3
    ├─"test/test_expect_test.ml":245:34: loop_changes
    │ ├─x = 6
    │ ├─"test/test_expect_test.ml":246:8: z
    │ │ └─z = 2
    │ ├─"test/test_expect_test.ml":245:34: loop_changes
    │ │ ├─x = 5
    │ │ ├─"test/test_expect_test.ml":246:8: z
    │ │ │ └─z = 2
    │ │ └─loop_changes = 4
    │ └─loop_changes = 6
    └─loop_changes = 9
    9
    |}]

let%expect_test "%debug_show with exception" =
  let module Debug_runtime = (val Minidebug_runtime.debug ()) in
  let%debug_show rec loop_truncated (x : int) : int =
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
    "test/test_expect_test.ml":275:36: loop_truncated
    ├─x = 7
    ├─"test/test_expect_test.ml":276:8: z
    │ └─z = 3
    └─"test/test_expect_test.ml":275:36: loop_truncated
      ├─x = 6
      ├─"test/test_expect_test.ml":276:8: z
      │ └─z = 2
      └─"test/test_expect_test.ml":275:36: loop_truncated
        ├─x = 5
        ├─"test/test_expect_test.ml":276:8: z
        │ └─z = 2
        └─"test/test_expect_test.ml":275:36: loop_truncated
          ├─x = 4
          ├─"test/test_expect_test.ml":276:8: z
          │ └─z = 1
          └─"test/test_expect_test.ml":275:36: loop_truncated
            ├─x = 3
            ├─"test/test_expect_test.ml":276:8: z
            │ └─z = 1
            └─"test/test_expect_test.ml":275:36: loop_truncated
              ├─x = 2
              ├─"test/test_expect_test.ml":276:8: z
              │ └─z = 0
              └─"test/test_expect_test.ml":275:36: loop_truncated
                ├─x = 1
                ├─"test/test_expect_test.ml":276:8: z
                │ └─z = 0
                └─"test/test_expect_test.ml":275:36: loop_truncated
                  ├─x = 0
                  └─"test/test_expect_test.ml":276:8: z
                    └─z = 0
    Raised exception.
    |}]

let%expect_test "%debug_show depth exceeded" =
  let module Debug_runtime = (val Minidebug_runtime.debug ()) in
  let%debug_show rec loop_exceeded (x : int) : int =
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
    "test/test_expect_test.ml":324:35: loop_exceeded
    ├─x = 7
    ├─"test/test_expect_test.ml":327:10: z
    │ └─z = 3
    └─"test/test_expect_test.ml":324:35: loop_exceeded
      ├─x = 6
      ├─"test/test_expect_test.ml":327:10: z
      │ └─z = 2
      └─"test/test_expect_test.ml":324:35: loop_exceeded
        ├─x = 5
        ├─"test/test_expect_test.ml":327:10: z
        │ └─z = 2
        └─"test/test_expect_test.ml":324:35: loop_exceeded
          ├─x = 4
          ├─"test/test_expect_test.ml":327:10: z
          │ └─z = 1
          └─"test/test_expect_test.ml":324:35: loop_exceeded
            ├─x = 3
            └─"test/test_expect_test.ml":327:10: z
              └─z = <max_nesting_depth exceeded>
    Raised exception.
    |}]

let%expect_test "%debug_show num children exceeded linear" =
  let module Debug_runtime = (val Minidebug_runtime.debug ()) in
  let () =
    try
      let%debug_show _bar : unit =
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
    "test/test_expect_test.ml":364:21: _bar
    ├─"test/test_expect_test.ml":368:16: _baz
    │ └─_baz = 0
    ├─"test/test_expect_test.ml":368:16: _baz
    │ └─_baz = 2
    ├─"test/test_expect_test.ml":368:16: _baz
    │ └─_baz = 4
    ├─"test/test_expect_test.ml":368:16: _baz
    │ └─_baz = 6
    ├─"test/test_expect_test.ml":368:16: _baz
    │ └─_baz = 8
    ├─"test/test_expect_test.ml":368:16: _baz
    │ └─_baz = 10
    ├─"test/test_expect_test.ml":368:16: _baz
    │ └─_baz = 12
    ├─"test/test_expect_test.ml":368:16: _baz
    │ └─_baz = 14
    ├─"test/test_expect_test.ml":368:16: _baz
    │ └─_baz = 16
    ├─"test/test_expect_test.ml":368:16: _baz
    │ └─_baz = 18
    ├─"test/test_expect_test.ml":368:16: _baz
    │ └─_baz = 20
    └─_baz = <max_num_children exceeded>
    Raised exception: ppx_minidebug: max_num_children exceeded
    |}]

let%expect_test "%debug_show truncated children linear" =
  let module Debug_runtime = (val Minidebug_runtime.debug ~truncate_children:10 ()) in
  let () =
    try
      let%debug_show _bar : unit =
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
    "test/test_expect_test.ml":409:21: _bar
    ├─<earlier entries truncated>
    ├─"test/test_expect_test.ml":411:14: _baz
    │ └─_baz = 44
    ├─"test/test_expect_test.ml":411:14: _baz
    │ └─_baz = 46
    ├─"test/test_expect_test.ml":411:14: _baz
    │ └─_baz = 48
    ├─"test/test_expect_test.ml":411:14: _baz
    │ └─_baz = 50
    ├─"test/test_expect_test.ml":411:14: _baz
    │ └─_baz = 52
    ├─"test/test_expect_test.ml":411:14: _baz
    │ └─_baz = 54
    ├─"test/test_expect_test.ml":411:14: _baz
    │ └─_baz = 56
    ├─"test/test_expect_test.ml":411:14: _baz
    │ └─_baz = 58
    ├─"test/test_expect_test.ml":411:14: _baz
    │ └─_baz = 60
    └─_bar = ()
    |}]

let%expect_test "%track_show track for-loop num children exceeded" =
  let module Debug_runtime = (val Minidebug_runtime.debug ()) in
  let () =
    try
      let%track_show _bar : unit =
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
    "test/test_expect_test.ml":448:21: _bar
    └─"test/test_expect_test.ml":451:10: for:test_expect_test:451
      ├─i = 0
      ├─"test/test_expect_test.ml":451:14: <for i>
      │ └─"test/test_expect_test.ml":452:16: _baz
      │   └─_baz = 0
      ├─i = 1
      ├─"test/test_expect_test.ml":451:14: <for i>
      │ └─"test/test_expect_test.ml":452:16: _baz
      │   └─_baz = 2
      ├─i = 2
      ├─"test/test_expect_test.ml":451:14: <for i>
      │ └─"test/test_expect_test.ml":452:16: _baz
      │   └─_baz = 4
      ├─i = 3
      ├─"test/test_expect_test.ml":451:14: <for i>
      │ └─"test/test_expect_test.ml":452:16: _baz
      │   └─_baz = 6
      ├─i = 4
      ├─"test/test_expect_test.ml":451:14: <for i>
      │ └─"test/test_expect_test.ml":452:16: _baz
      │   └─_baz = 8
      ├─i = 5
      └─i = <max_num_children exceeded>
    Raised exception: ppx_minidebug: max_num_children exceeded
    |}]

let%expect_test "%track_show track for-loop truncated children" =
  let module Debug_runtime = (val Minidebug_runtime.debug ~truncate_children:10 ()) in
  let () =
    try
      let%track_show _bar : unit =
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
    "test/test_expect_test.ml":493:21: _bar
    ├─"test/test_expect_test.ml":494:8: for:test_expect_test:494
    │ ├─<earlier entries truncated>
    │ ├─i = 26
    │ ├─"test/test_expect_test.ml":494:12: <for i>
    │ │ └─"test/test_expect_test.ml":495:14: _baz
    │ │   └─_baz = 52
    │ ├─i = 27
    │ ├─"test/test_expect_test.ml":494:12: <for i>
    │ │ └─"test/test_expect_test.ml":495:14: _baz
    │ │   └─_baz = 54
    │ ├─i = 28
    │ ├─"test/test_expect_test.ml":494:12: <for i>
    │ │ └─"test/test_expect_test.ml":495:14: _baz
    │ │   └─_baz = 56
    │ ├─i = 29
    │ ├─"test/test_expect_test.ml":494:12: <for i>
    │ │ └─"test/test_expect_test.ml":495:14: _baz
    │ │   └─_baz = 58
    │ ├─i = 30
    │ └─"test/test_expect_test.ml":494:12: <for i>
    │   └─"test/test_expect_test.ml":495:14: _baz
    │     └─_baz = 60
    └─_bar = ()
    |}]

let%expect_test "%track_show track for-loop" =
  let module Debug_runtime = (val Minidebug_runtime.debug ()) in
  let () =
    try
      let%track_show _bar : unit =
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
    "test/test_expect_test.ml":535:21: _bar
    ├─"test/test_expect_test.ml":538:10: for:test_expect_test:538
    │ ├─i = 0
    │ ├─"test/test_expect_test.ml":538:14: <for i>
    │ │ └─"test/test_expect_test.ml":539:16: _baz
    │ │   └─_baz = 0
    │ ├─i = 1
    │ ├─"test/test_expect_test.ml":538:14: <for i>
    │ │ └─"test/test_expect_test.ml":539:16: _baz
    │ │   └─_baz = 2
    │ ├─i = 2
    │ ├─"test/test_expect_test.ml":538:14: <for i>
    │ │ └─"test/test_expect_test.ml":539:16: _baz
    │ │   └─_baz = 4
    │ ├─i = 3
    │ ├─"test/test_expect_test.ml":538:14: <for i>
    │ │ └─"test/test_expect_test.ml":539:16: _baz
    │ │   └─_baz = 6
    │ ├─i = 4
    │ ├─"test/test_expect_test.ml":538:14: <for i>
    │ │ └─"test/test_expect_test.ml":539:16: _baz
    │ │   └─_baz = 8
    │ ├─i = 5
    │ ├─"test/test_expect_test.ml":538:14: <for i>
    │ │ └─"test/test_expect_test.ml":539:16: _baz
    │ │   └─_baz = 10
    │ ├─i = 6
    │ └─"test/test_expect_test.ml":538:14: <for i>
    │   └─"test/test_expect_test.ml":539:16: _baz
    │     └─_baz = 12
    └─_bar = ()
    |}]

let%expect_test "%track_show track for-loop, time spans" =
  let module Debug_runtime = (val Minidebug_runtime.debug ~elapsed_times:Microseconds ())
  in
  let () =
    try
      let%track_show _bar : unit =
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
    "test/test_expect_test.ml":587:21: _bar <N.NNμs>
    ├─"test/test_expect_test.ml":590:10: for:test_expect_test:590 <N.NNμs>
    │ ├─i = 0
    │ ├─"test/test_expect_test.ml":590:14: <for i> <N.NNμs>
    │ │ └─"test/test_expect_test.ml":591:16: _baz <N.NNμs>
    │ │   └─_baz = 0
    │ ├─i = 1
    │ ├─"test/test_expect_test.ml":590:14: <for i> <N.NNμs>
    │ │ └─"test/test_expect_test.ml":591:16: _baz <N.NNμs>
    │ │   └─_baz = 2
    │ ├─i = 2
    │ ├─"test/test_expect_test.ml":590:14: <for i> <N.NNμs>
    │ │ └─"test/test_expect_test.ml":591:16: _baz <N.NNμs>
    │ │   └─_baz = 4
    │ ├─i = 3
    │ ├─"test/test_expect_test.ml":590:14: <for i> <N.NNμs>
    │ │ └─"test/test_expect_test.ml":591:16: _baz <N.NNμs>
    │ │   └─_baz = 6
    │ ├─i = 4
    │ ├─"test/test_expect_test.ml":590:14: <for i> <N.NNμs>
    │ │ └─"test/test_expect_test.ml":591:16: _baz <N.NNμs>
    │ │   └─_baz = 8
    │ ├─i = 5
    │ ├─"test/test_expect_test.ml":590:14: <for i> <N.NNμs>
    │ │ └─"test/test_expect_test.ml":591:16: _baz <N.NNμs>
    │ │   └─_baz = 10
    │ ├─i = 6
    │ └─"test/test_expect_test.ml":590:14: <for i> <N.NNμs>
    │   └─"test/test_expect_test.ml":591:16: _baz <N.NNμs>
    │     └─_baz = 12
    └─_bar = ()
    |}]

let%expect_test "%track_show track while-loop" =
  let module Debug_runtime = (val Minidebug_runtime.debug ()) in
  let () =
    try
      let%track_show _bar : unit =
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
    "test/test_expect_test.ml":643:21: _bar
    ├─"test/test_expect_test.ml":645:8: while:test_expect_test:645
    │ ├─"test/test_expect_test.ml":646:10: <while loop>
    │ │ └─"test/test_expect_test.ml":646:14: _baz
    │ │   └─_baz = 0
    │ ├─"test/test_expect_test.ml":646:10: <while loop>
    │ │ └─"test/test_expect_test.ml":646:14: _baz
    │ │   └─_baz = 2
    │ ├─"test/test_expect_test.ml":646:10: <while loop>
    │ │ └─"test/test_expect_test.ml":646:14: _baz
    │ │   └─_baz = 4
    │ ├─"test/test_expect_test.ml":646:10: <while loop>
    │ │ └─"test/test_expect_test.ml":646:14: _baz
    │ │   └─_baz = 6
    │ ├─"test/test_expect_test.ml":646:10: <while loop>
    │ │ └─"test/test_expect_test.ml":646:14: _baz
    │ │   └─_baz = 8
    │ └─"test/test_expect_test.ml":646:10: <while loop>
    │   └─"test/test_expect_test.ml":646:14: _baz
    │     └─_baz = 10
    └─_bar = ()
    |}]

let%expect_test "%debug_show num children exceeded nested" =
  let module Debug_runtime = (val Minidebug_runtime.debug ()) in
  let%debug_show rec loop_exceeded (x : int) : int =
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
    "test/test_expect_test.ml":681:35: loop_exceeded
    ├─x = 3
    ├─"test/test_expect_test.ml":688:17: z
    │ └─z = 1
    └─"test/test_expect_test.ml":681:35: loop_exceeded
      ├─x = 2
      ├─"test/test_expect_test.ml":688:17: z
      │ └─z = 0
      └─"test/test_expect_test.ml":681:35: loop_exceeded
        ├─x = 1
        ├─"test/test_expect_test.ml":688:17: z
        │ └─z = 0
        └─"test/test_expect_test.ml":681:35: loop_exceeded
          ├─x = 0
          ├─"test/test_expect_test.ml":688:17: z
          │ └─z = 0
          ├─"test/test_expect_test.ml":688:17: z
          │ └─z = 1
          ├─"test/test_expect_test.ml":688:17: z
          │ └─z = 2
          ├─"test/test_expect_test.ml":688:17: z
          │ └─z = 3
          ├─"test/test_expect_test.ml":688:17: z
          │ └─z = 4
          ├─"test/test_expect_test.ml":688:17: z
          │ └─z = 5
          ├─"test/test_expect_test.ml":688:17: z
          │ └─z = 6
          ├─"test/test_expect_test.ml":688:17: z
          │ └─z = 7
          ├─"test/test_expect_test.ml":688:17: z
          │ └─z = 8
          ├─"test/test_expect_test.ml":688:17: z
          │ └─z = 9
          └─z = <max_num_children exceeded>
    Raised exception: ppx_minidebug: max_num_children exceeded
    |}]

let%expect_test "%debug_show truncated children nested" =
  let module Debug_runtime = (val Minidebug_runtime.debug ~truncate_children:4 ()) in
  let%debug_show rec loop_exceeded (x : int) : int =
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
    "test/test_expect_test.ml":738:35: loop_exceeded
    ├─<earlier entries truncated>
    ├─"test/test_expect_test.ml":738:35: loop_exceeded
    │ ├─<earlier entries truncated>
    │ ├─"test/test_expect_test.ml":738:35: loop_exceeded
    │ │ ├─<earlier entries truncated>
    │ │ ├─"test/test_expect_test.ml":738:35: loop_exceeded
    │ │ │ ├─<earlier entries truncated>
    │ │ │ ├─"test/test_expect_test.ml":743:15: z
    │ │ │ │ └─z = 17
    │ │ │ ├─"test/test_expect_test.ml":743:15: z
    │ │ │ │ └─z = 18
    │ │ │ ├─"test/test_expect_test.ml":743:15: z
    │ │ │ │ └─z = 19
    │ │ │ └─loop_exceeded = 190
    │ │ ├─"test/test_expect_test.ml":743:15: z
    │ │ │ └─z = 9
    │ │ ├─"test/test_expect_test.ml":738:35: loop_exceeded
    │ │ │ ├─<earlier entries truncated>
    │ │ │ ├─"test/test_expect_test.ml":743:15: z
    │ │ │ │ └─z = 17
    │ │ │ ├─"test/test_expect_test.ml":743:15: z
    │ │ │ │ └─z = 18
    │ │ │ ├─"test/test_expect_test.ml":743:15: z
    │ │ │ │ └─z = 19
    │ │ │ └─loop_exceeded = 190
    │ │ └─loop_exceeded = 1945
    │ ├─"test/test_expect_test.ml":743:15: z
    │ │ └─z = 5
    │ ├─"test/test_expect_test.ml":738:35: loop_exceeded
    │ │ ├─<earlier entries truncated>
    │ │ ├─"test/test_expect_test.ml":738:35: loop_exceeded
    │ │ │ ├─<earlier entries truncated>
    │ │ │ ├─"test/test_expect_test.ml":743:15: z
    │ │ │ │ └─z = 17
    │ │ │ ├─"test/test_expect_test.ml":743:15: z
    │ │ │ │ └─z = 18
    │ │ │ ├─"test/test_expect_test.ml":743:15: z
    │ │ │ │ └─z = 19
    │ │ │ └─loop_exceeded = 190
    │ │ ├─"test/test_expect_test.ml":743:15: z
    │ │ │ └─z = 9
    │ │ ├─"test/test_expect_test.ml":738:35: loop_exceeded
    │ │ │ ├─<earlier entries truncated>
    │ │ │ ├─"test/test_expect_test.ml":743:15: z
    │ │ │ │ └─z = 17
    │ │ │ ├─"test/test_expect_test.ml":743:15: z
    │ │ │ │ └─z = 18
    │ │ │ ├─"test/test_expect_test.ml":743:15: z
    │ │ │ │ └─z = 19
    │ │ │ └─loop_exceeded = 190
    │ │ └─loop_exceeded = 1945
    │ └─loop_exceeded = 11685
    ├─"test/test_expect_test.ml":743:15: z
    │ └─z = 5
    ├─"test/test_expect_test.ml":738:35: loop_exceeded
    │ ├─<earlier entries truncated>
    │ ├─"test/test_expect_test.ml":738:35: loop_exceeded
    │ │ ├─<earlier entries truncated>
    │ │ ├─"test/test_expect_test.ml":738:35: loop_exceeded
    │ │ │ ├─<earlier entries truncated>
    │ │ │ ├─"test/test_expect_test.ml":743:15: z
    │ │ │ │ └─z = 17
    │ │ │ ├─"test/test_expect_test.ml":743:15: z
    │ │ │ │ └─z = 18
    │ │ │ ├─"test/test_expect_test.ml":743:15: z
    │ │ │ │ └─z = 19
    │ │ │ └─loop_exceeded = 190
    │ │ ├─"test/test_expect_test.ml":743:15: z
    │ │ │ └─z = 9
    │ │ ├─"test/test_expect_test.ml":738:35: loop_exceeded
    │ │ │ ├─<earlier entries truncated>
    │ │ │ ├─"test/test_expect_test.ml":743:15: z
    │ │ │ │ └─z = 17
    │ │ │ ├─"test/test_expect_test.ml":743:15: z
    │ │ │ │ └─z = 18
    │ │ │ ├─"test/test_expect_test.ml":743:15: z
    │ │ │ │ └─z = 19
    │ │ │ └─loop_exceeded = 190
    │ │ └─loop_exceeded = 1945
    │ ├─"test/test_expect_test.ml":743:15: z
    │ │ └─z = 5
    │ ├─"test/test_expect_test.ml":738:35: loop_exceeded
    │ │ ├─<earlier entries truncated>
    │ │ ├─"test/test_expect_test.ml":738:35: loop_exceeded
    │ │ │ ├─<earlier entries truncated>
    │ │ │ ├─"test/test_expect_test.ml":743:15: z
    │ │ │ │ └─z = 17
    │ │ │ ├─"test/test_expect_test.ml":743:15: z
    │ │ │ │ └─z = 18
    │ │ │ ├─"test/test_expect_test.ml":743:15: z
    │ │ │ │ └─z = 19
    │ │ │ └─loop_exceeded = 190
    │ │ ├─"test/test_expect_test.ml":743:15: z
    │ │ │ └─z = 9
    │ │ ├─"test/test_expect_test.ml":738:35: loop_exceeded
    │ │ │ ├─<earlier entries truncated>
    │ │ │ ├─"test/test_expect_test.ml":743:15: z
    │ │ │ │ └─z = 17
    │ │ │ ├─"test/test_expect_test.ml":743:15: z
    │ │ │ │ └─z = 18
    │ │ │ ├─"test/test_expect_test.ml":743:15: z
    │ │ │ │ └─z = 19
    │ │ │ └─loop_exceeded = 190
    │ │ └─loop_exceeded = 1945
    │ └─loop_exceeded = 11685
    └─loop_exceeded = 58435
    58435
    |}]

let%expect_test "%track_show highlight" =
  let module Debug_runtime =
    (val Minidebug_runtime.debug ~highlight_terms:(Re.str "3") ())
  in
  let%debug_show rec loop_highlight (x : int) : int =
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
    │"test/test_expect_test.ml":867:36: loop_highlight│
    ├─────────────────────────────────────────────────┘
    ├─x = 7
    ├─┬────────────────────────────────────┐
    │ │"test/test_expect_test.ml":870:10: z│
    │ ├────────────────────────────────────┘
    │ └─┬─────┐
    │   │z = 3│
    │   └─────┘
    ├─┬─────────────────────────────────────────────────┐
    │ │"test/test_expect_test.ml":867:36: loop_highlight│
    │ ├─────────────────────────────────────────────────┘
    │ ├─x = 6
    │ ├─"test/test_expect_test.ml":870:10: z
    │ │ └─z = 2
    │ ├─┬─────────────────────────────────────────────────┐
    │ │ │"test/test_expect_test.ml":867:36: loop_highlight│
    │ │ ├─────────────────────────────────────────────────┘
    │ │ ├─x = 5
    │ │ ├─"test/test_expect_test.ml":870:10: z
    │ │ │ └─z = 2
    │ │ ├─┬─────────────────────────────────────────────────┐
    │ │ │ │"test/test_expect_test.ml":867:36: loop_highlight│
    │ │ │ ├─────────────────────────────────────────────────┘
    │ │ │ ├─x = 4
    │ │ │ ├─"test/test_expect_test.ml":870:10: z
    │ │ │ │ └─z = 1
    │ │ │ ├─┬─────────────────────────────────────────────────┐
    │ │ │ │ │"test/test_expect_test.ml":867:36: loop_highlight│
    │ │ │ │ ├─────────────────────────────────────────────────┘
    │ │ │ │ ├─┬─────┐
    │ │ │ │ │ │x = 3│
    │ │ │ │ │ └─────┘
    │ │ │ │ ├─"test/test_expect_test.ml":870:10: z
    │ │ │ │ │ └─z = 1
    │ │ │ │ ├─"test/test_expect_test.ml":867:36: loop_highlight
    │ │ │ │ │ ├─x = 2
    │ │ │ │ │ ├─"test/test_expect_test.ml":870:10: z
    │ │ │ │ │ │ └─z = 0
    │ │ │ │ │ ├─"test/test_expect_test.ml":867:36: loop_highlight
    │ │ │ │ │ │ ├─x = 1
    │ │ │ │ │ │ ├─"test/test_expect_test.ml":870:10: z
    │ │ │ │ │ │ │ └─z = 0
    │ │ │ │ │ │ ├─"test/test_expect_test.ml":867:36: loop_highlight
    │ │ │ │ │ │ │ ├─x = 0
    │ │ │ │ │ │ │ ├─"test/test_expect_test.ml":870:10: z
    │ │ │ │ │ │ │ │ └─z = 0
    │ │ │ │ │ │ │ └─loop_highlight = 0
    │ │ │ │ │ │ └─loop_highlight = 0
    │ │ │ │ │ └─loop_highlight = 0
    │ │ │ │ └─loop_highlight = 1
    │ │ │ └─loop_highlight = 2
    │ │ └─loop_highlight = 4
    │ └─loop_highlight = 6
    └─loop_highlight = 9
    9
    |}]

let%expect_test "%track_show PrintBox tracking" =
  let module Debug_runtime = (val Minidebug_runtime.debug ()) in
  let%track_show track_branches (x : int) : int =
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
    "test/test_expect_test.ml":938:32: track_branches
    ├─x = 7
    ├─"test/test_expect_test.ml":940:9: else:test_expect_test:940
    │ └─"test/test_expect_test.ml":940:36: <match -- branch 1>
    └─track_branches = 4
    4
    "test/test_expect_test.ml":938:32: track_branches
    ├─x = 3
    ├─"test/test_expect_test.ml":939:18: then:test_expect_test:939
    │ └─"test/test_expect_test.ml":939:54: <match -- branch 2>
    └─track_branches = -3
    -3
    |}]

let%expect_test "%track_show PrintBox tracking <function>" =
  let module Debug_runtime = (val Minidebug_runtime.debug ()) in
  let%track_show track_branches = function
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
    "test/test_expect_test.ml":971:11: <function -- branch 3>
    4
    "test/test_expect_test.ml":973:11: <function -- branch 5> x
    -3
    |}]

let%expect_test "%track_show PrintBox tracking with debug_notrace" =
  let module Debug_runtime = (val Minidebug_runtime.debug ()) in
  let%track_show track_branches (x : int) : int =
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
    "test/test_expect_test.ml":992:32: track_branches
    ├─x = 8
    ├─"test/test_expect_test.ml":1001:6: else:test_expect_test:1001
    │ └─"test/test_expect_test.ml":1005:10: <match -- branch 2>
    │   └─"test/test_expect_test.ml":1005:14: result
    │     ├─"test/test_expect_test.ml":1005:44: then:test_expect_test:1005
    │     └─result = 8
    └─track_branches = 8
    8
    "test/test_expect_test.ml":992:32: track_branches
    ├─x = 3
    ├─"test/test_expect_test.ml":994:6: then:test_expect_test:994
    │ └─"test/test_expect_test.ml":998:14: result
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
    "test/test_expect_test.ml":1038:27: track_foo
    ├─x = 8
    ├─"test/test_expect_test.ml":1041:4: fun:test_expect_test:1041
    │ └─z = 8
    └─track_foo = 8
    8
    |}]

let%expect_test "respect scope of nested extension points" =
  let module Debug_runtime = (val Minidebug_runtime.debug ()) in
  let%track_show track_branches (x : int) : int =
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
    "test/test_expect_test.ml":1061:32: track_branches
    ├─x = 8
    ├─"test/test_expect_test.ml":1070:6: else:test_expect_test:1070
    │ └─"test/test_expect_test.ml":1074:25: result
    │   ├─"test/test_expect_test.ml":1074:55: then:test_expect_test:1074
    │   └─result = 8
    └─track_branches = 8
    8
    "test/test_expect_test.ml":1061:32: track_branches
    ├─x = 3
    ├─"test/test_expect_test.ml":1063:6: then:test_expect_test:1063
    │ └─"test/test_expect_test.ml":1067:25: result
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
    "test/test_expect_test.ml":1105:27: anonymous
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
    "test/test_expect_test.ml":1130:25: wrapper
    "test/test_expect_test.ml":1131:29: anonymous
    └─"We do log this function"
    6
    6
    |}]

let%expect_test "%track_show no return type anonymous fun" =
  let module Debug_runtime = (val Minidebug_runtime.debug ()) in
  let%debug_show anonymous (x : int) =
    Array.fold_left ( + ) 0 @@ Array.init (x + 1) (fun (i : int) -> i)
  in
  let () =
    try print_endline @@ Int.to_string @@ anonymous 3
    with Failure s -> print_endline @@ "Raised exception: " ^ s
  in
  [%expect
    {|
    BEGIN DEBUG SESSION
    "test/test_expect_test.ml":1159:27: anonymous
    └─x = 3
    6
    |}];
  let%track_show anonymous (x : int) =
    Array.fold_left ( + ) 0 @@ Array.init (x + 1) (fun (i : int) -> i)
  in
  let () =
    try print_endline @@ Int.to_string @@ anonymous 3
    with Failure s -> print_endline @@ "Raised exception: " ^ s
  in
  [%expect
    {|
    "test/test_expect_test.ml":1173:27: anonymous
    ├─x = 3
    ├─"test/test_expect_test.ml":1174:50: fun:test_expect_test:1174
    │ └─i = 0
    ├─"test/test_expect_test.ml":1174:50: fun:test_expect_test:1174
    │ └─i = 1
    ├─"test/test_expect_test.ml":1174:50: fun:test_expect_test:1174
    │ └─i = 2
    └─"test/test_expect_test.ml":1174:50: fun:test_expect_test:1174
      └─i = 3
    6
    |}]

let%expect_test "%track_show anonymous fun, num children exceeded" =
  let module Debug_runtime = (val Minidebug_runtime.debug ()) in
  let%track_show rec loop_exceeded (x : int) : int =
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
    "test/test_expect_test.ml":1197:35: loop_exceeded
    ├─x = 3
    └─"test/test_expect_test.ml":1203:11: fun:test_expect_test:1203
      ├─i = 0
      ├─"test/test_expect_test.ml":1204:17: z
      │ └─z = 1
      └─"test/test_expect_test.ml":1205:35: else:test_expect_test:1205
        └─"test/test_expect_test.ml":1197:35: loop_exceeded
          ├─x = 2
          └─"test/test_expect_test.ml":1203:11: fun:test_expect_test:1203
            ├─i = 0
            ├─"test/test_expect_test.ml":1204:17: z
            │ └─z = 0
            └─"test/test_expect_test.ml":1205:35: else:test_expect_test:1205
              └─"test/test_expect_test.ml":1197:35: loop_exceeded
                ├─x = 1
                └─"test/test_expect_test.ml":1203:11: fun:test_expect_test:1203
                  ├─i = 0
                  ├─"test/test_expect_test.ml":1204:17: z
                  │ └─z = 0
                  └─"test/test_expect_test.ml":1205:35: else:test_expect_test:1205
                    └─"test/test_expect_test.ml":1197:35: loop_exceeded
                      ├─x = 0
                      ├─"test/test_expect_test.ml":1203:11: fun:test_expect_test:1203
                      │ ├─i = 0
                      │ ├─"test/test_expect_test.ml":1204:17: z
                      │ │ └─z = 0
                      │ └─"test/test_expect_test.ml":1205:28: then:test_expect_test:1205
                      ├─"test/test_expect_test.ml":1203:11: fun:test_expect_test:1203
                      │ ├─i = 1
                      │ ├─"test/test_expect_test.ml":1204:17: z
                      │ │ └─z = 1
                      │ └─"test/test_expect_test.ml":1205:28: then:test_expect_test:1205
                      ├─"test/test_expect_test.ml":1203:11: fun:test_expect_test:1203
                      │ ├─i = 2
                      │ ├─"test/test_expect_test.ml":1204:17: z
                      │ │ └─z = 2
                      │ └─"test/test_expect_test.ml":1205:28: then:test_expect_test:1205
                      ├─"test/test_expect_test.ml":1203:11: fun:test_expect_test:1203
                      │ ├─i = 3
                      │ ├─"test/test_expect_test.ml":1204:17: z
                      │ │ └─z = 3
                      │ └─"test/test_expect_test.ml":1205:28: then:test_expect_test:1205
                      ├─"test/test_expect_test.ml":1203:11: fun:test_expect_test:1203
                      │ ├─i = 4
                      │ ├─"test/test_expect_test.ml":1204:17: z
                      │ │ └─z = 4
                      │ └─"test/test_expect_test.ml":1205:28: then:test_expect_test:1205
                      ├─"test/test_expect_test.ml":1203:11: fun:test_expect_test:1203
                      │ ├─i = 5
                      │ ├─"test/test_expect_test.ml":1204:17: z
                      │ │ └─z = 5
                      │ └─"test/test_expect_test.ml":1205:28: then:test_expect_test:1205
                      ├─"test/test_expect_test.ml":1203:11: fun:test_expect_test:1203
                      │ ├─i = 6
                      │ ├─"test/test_expect_test.ml":1204:17: z
                      │ │ └─z = 6
                      │ └─"test/test_expect_test.ml":1205:28: then:test_expect_test:1205
                      ├─"test/test_expect_test.ml":1203:11: fun:test_expect_test:1203
                      │ ├─i = 7
                      │ ├─"test/test_expect_test.ml":1204:17: z
                      │ │ └─z = 7
                      │ └─"test/test_expect_test.ml":1205:28: then:test_expect_test:1205
                      ├─"test/test_expect_test.ml":1203:11: fun:test_expect_test:1203
                      │ ├─i = 8
                      │ ├─"test/test_expect_test.ml":1204:17: z
                      │ │ └─z = 8
                      │ └─"test/test_expect_test.ml":1205:28: then:test_expect_test:1205
                      ├─"test/test_expect_test.ml":1203:11: fun:test_expect_test:1203
                      │ ├─i = 9
                      │ ├─"test/test_expect_test.ml":1204:17: z
                      │ │ └─z = 9
                      │ └─"test/test_expect_test.ml":1205:28: then:test_expect_test:1205
                      └─fun:test_expect_test:1203 = <max_num_children exceeded>
    Raised exception: ppx_minidebug: max_num_children exceeded
    |}]

let%expect_test "%track_show anonymous fun, truncated children" =
  let module Debug_runtime = (val Minidebug_runtime.debug ~truncate_children:2 ()) in
  let%track_show rec loop_exceeded (x : int) : int =
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
    "test/test_expect_test.ml":1293:35: loop_exceeded
    ├─<earlier entries truncated>
    ├─"test/test_expect_test.ml":1297:9: fun:test_expect_test:1297
    │ ├─<earlier entries truncated>
    │ ├─"test/test_expect_test.ml":1298:15: z
    │ │ └─z = 7
    │ └─"test/test_expect_test.ml":1299:33: else:test_expect_test:1299
    │   └─"test/test_expect_test.ml":1293:35: loop_exceeded
    │     ├─<earlier entries truncated>
    │     ├─"test/test_expect_test.ml":1297:9: fun:test_expect_test:1297
    │     │ ├─<earlier entries truncated>
    │     │ ├─"test/test_expect_test.ml":1298:15: z
    │     │ │ └─z = 9
    │     │ └─"test/test_expect_test.ml":1299:33: else:test_expect_test:1299
    │     │   └─"test/test_expect_test.ml":1293:35: loop_exceeded
    │     │     ├─<earlier entries truncated>
    │     │     ├─"test/test_expect_test.ml":1297:9: fun:test_expect_test:1297
    │     │     │ ├─<earlier entries truncated>
    │     │     │ ├─"test/test_expect_test.ml":1298:15: z
    │     │     │ │ └─z = 14
    │     │     │ └─"test/test_expect_test.ml":1299:33: else:test_expect_test:1299
    │     │     │   └─"test/test_expect_test.ml":1293:35: loop_exceeded
    │     │     │     ├─<earlier entries truncated>
    │     │     │     ├─"test/test_expect_test.ml":1297:9: fun:test_expect_test:1297
    │     │     │     │ ├─<earlier entries truncated>
    │     │     │     │ ├─"test/test_expect_test.ml":1298:15: z
    │     │     │     │ │ └─z = 29
    │     │     │     │ └─"test/test_expect_test.ml":1299:26: then:test_expect_test:1299
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

let%expect_test "%debug_show function with abstract type" =
  let module Debug_runtime = (val Minidebug_runtime.debug ()) in
  let%debug_show foo (type d) (module D : T with type c = d) ~a (c : int) : int =
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
    "test/test_expect_test.ml":1351:21: foo
    ├─c = 1
    └─foo = 2
    2
    |}]

let%expect_test "%debug_show PrintBox values_first_mode to stdout with exception" =
  let module Debug_runtime = (val Minidebug_runtime.debug ~values_first_mode:true ()) in
  let%debug_show rec loop_truncated (x : int) : int =
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
    ├─"test/test_expect_test.ml":1377:36
    ├─x = 7
    ├─z = 3
    │ └─"test/test_expect_test.ml":1378:8
    └─loop_truncated
      ├─"test/test_expect_test.ml":1377:36
      ├─x = 6
      ├─z = 2
      │ └─"test/test_expect_test.ml":1378:8
      └─loop_truncated
        ├─"test/test_expect_test.ml":1377:36
        ├─x = 5
        ├─z = 2
        │ └─"test/test_expect_test.ml":1378:8
        └─loop_truncated
          ├─"test/test_expect_test.ml":1377:36
          ├─x = 4
          ├─z = 1
          │ └─"test/test_expect_test.ml":1378:8
          └─loop_truncated
            ├─"test/test_expect_test.ml":1377:36
            ├─x = 3
            ├─z = 1
            │ └─"test/test_expect_test.ml":1378:8
            └─loop_truncated
              ├─"test/test_expect_test.ml":1377:36
              ├─x = 2
              ├─z = 0
              │ └─"test/test_expect_test.ml":1378:8
              └─loop_truncated
                ├─"test/test_expect_test.ml":1377:36
                ├─x = 1
                ├─z = 0
                │ └─"test/test_expect_test.ml":1378:8
                └─loop_truncated
                  ├─"test/test_expect_test.ml":1377:36
                  ├─x = 0
                  └─z = 0
                    └─"test/test_expect_test.ml":1378:8
    Raised exception.
    |}]

let%expect_test "%debug_show PrintBox values_first_mode to stdout num children exceeded \
                 linear" =
  let module Debug_runtime = (val Minidebug_runtime.debug ~values_first_mode:true ()) in
  let () =
    try
      let%debug_show _bar : unit =
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
    ├─"test/test_expect_test.ml":1437:21
    ├─_baz = 0
    │ └─"test/test_expect_test.ml":1441:16
    ├─_baz = 2
    │ └─"test/test_expect_test.ml":1441:16
    ├─_baz = 4
    │ └─"test/test_expect_test.ml":1441:16
    ├─_baz = 6
    │ └─"test/test_expect_test.ml":1441:16
    ├─_baz = 8
    │ └─"test/test_expect_test.ml":1441:16
    ├─_baz = 10
    │ └─"test/test_expect_test.ml":1441:16
    ├─_baz = 12
    │ └─"test/test_expect_test.ml":1441:16
    ├─_baz = 14
    │ └─"test/test_expect_test.ml":1441:16
    ├─_baz = 16
    │ └─"test/test_expect_test.ml":1441:16
    ├─_baz = 18
    │ └─"test/test_expect_test.ml":1441:16
    ├─_baz = 20
    │ └─"test/test_expect_test.ml":1441:16
    └─_baz = <max_num_children exceeded>
    Raised exception: ppx_minidebug: max_num_children exceeded
    |}]

let%expect_test "%track_show PrintBox values_first_mode to stdout track for-loop" =
  let module Debug_runtime = (val Minidebug_runtime.debug ~values_first_mode:true ()) in
  let () =
    try
      let%track_show _bar : unit =
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
    ├─"test/test_expect_test.ml":1483:21
    └─for:test_expect_test:1486
      ├─"test/test_expect_test.ml":1486:10
      ├─i = 0
      ├─<for i>
      │ ├─"test/test_expect_test.ml":1486:14
      │ └─_baz = 0
      │   └─"test/test_expect_test.ml":1487:16
      ├─i = 1
      ├─<for i>
      │ ├─"test/test_expect_test.ml":1486:14
      │ └─_baz = 2
      │   └─"test/test_expect_test.ml":1487:16
      ├─i = 2
      ├─<for i>
      │ ├─"test/test_expect_test.ml":1486:14
      │ └─_baz = 4
      │   └─"test/test_expect_test.ml":1487:16
      ├─i = 3
      ├─<for i>
      │ ├─"test/test_expect_test.ml":1486:14
      │ └─_baz = 6
      │   └─"test/test_expect_test.ml":1487:16
      ├─i = 4
      ├─<for i>
      │ ├─"test/test_expect_test.ml":1486:14
      │ └─_baz = 8
      │   └─"test/test_expect_test.ml":1487:16
      ├─i = 5
      ├─<for i>
      │ ├─"test/test_expect_test.ml":1486:14
      │ └─_baz = 10
      │   └─"test/test_expect_test.ml":1487:16
      ├─i = 6
      └─<for i>
        ├─"test/test_expect_test.ml":1486:14
        └─_baz = 12
          └─"test/test_expect_test.ml":1487:16
    |}]

let%expect_test "%debug_show PrintBox values_first_mode to stdout num children exceeded \
                 nested" =
  let module Debug_runtime = (val Minidebug_runtime.debug ~values_first_mode:true ()) in
  let%debug_show rec loop_exceeded (x : int) : int =
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
    ├─"test/test_expect_test.ml":1541:35
    ├─x = 3
    ├─z = 1
    │ └─"test/test_expect_test.ml":1548:17
    └─loop_exceeded
      ├─"test/test_expect_test.ml":1541:35
      ├─x = 2
      ├─z = 0
      │ └─"test/test_expect_test.ml":1548:17
      └─loop_exceeded
        ├─"test/test_expect_test.ml":1541:35
        ├─x = 1
        ├─z = 0
        │ └─"test/test_expect_test.ml":1548:17
        └─loop_exceeded
          ├─"test/test_expect_test.ml":1541:35
          ├─x = 0
          ├─z = 0
          │ └─"test/test_expect_test.ml":1548:17
          ├─z = 1
          │ └─"test/test_expect_test.ml":1548:17
          ├─z = 2
          │ └─"test/test_expect_test.ml":1548:17
          ├─z = 3
          │ └─"test/test_expect_test.ml":1548:17
          ├─z = 4
          │ └─"test/test_expect_test.ml":1548:17
          ├─z = 5
          │ └─"test/test_expect_test.ml":1548:17
          ├─z = 6
          │ └─"test/test_expect_test.ml":1548:17
          ├─z = 7
          │ └─"test/test_expect_test.ml":1548:17
          ├─z = 8
          │ └─"test/test_expect_test.ml":1548:17
          ├─z = 9
          │ └─"test/test_expect_test.ml":1548:17
          └─z = <max_num_children exceeded>
    Raised exception: ppx_minidebug: max_num_children exceeded
    |}]

let%expect_test "%debug_show elapsed times PrintBox values_first_mode to stdout nested, \
                 truncated children" =
  let module Debug_runtime =
    (val Minidebug_runtime.debug ~elapsed_times:Microseconds ~values_first_mode:true
           ~truncate_children:4 ())
  in
  let%debug_show rec loop_exceeded (x : int) : int =
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
    ├─"test/test_expect_test.ml":1606:35
    ├─<earlier entries truncated>
    ├─z = 4 <N.NNμs>
    │ └─"test/test_expect_test.ml":1611:15
    ├─loop_exceeded = 11685 <N.NNμs>
    │ ├─"test/test_expect_test.ml":1606:35
    │ ├─<earlier entries truncated>
    │ ├─z = 4 <N.NNμs>
    │ │ └─"test/test_expect_test.ml":1611:15
    │ ├─loop_exceeded = 1945 <N.NNμs>
    │ │ ├─"test/test_expect_test.ml":1606:35
    │ │ ├─<earlier entries truncated>
    │ │ ├─z = 8 <N.NNμs>
    │ │ │ └─"test/test_expect_test.ml":1611:15
    │ │ ├─loop_exceeded = 190 <N.NNμs>
    │ │ │ ├─"test/test_expect_test.ml":1606:35
    │ │ │ ├─<earlier entries truncated>
    │ │ │ ├─z = 16 <N.NNμs>
    │ │ │ │ └─"test/test_expect_test.ml":1611:15
    │ │ │ ├─z = 17 <N.NNμs>
    │ │ │ │ └─"test/test_expect_test.ml":1611:15
    │ │ │ ├─z = 18 <N.NNμs>
    │ │ │ │ └─"test/test_expect_test.ml":1611:15
    │ │ │ └─z = 19 <N.NNμs>
    │ │ │   └─"test/test_expect_test.ml":1611:15
    │ │ ├─z = 9 <N.NNμs>
    │ │ │ └─"test/test_expect_test.ml":1611:15
    │ │ └─loop_exceeded = 190 <N.NNμs>
    │ │   ├─"test/test_expect_test.ml":1606:35
    │ │   ├─<earlier entries truncated>
    │ │   ├─z = 16 <N.NNμs>
    │ │   │ └─"test/test_expect_test.ml":1611:15
    │ │   ├─z = 17 <N.NNμs>
    │ │   │ └─"test/test_expect_test.ml":1611:15
    │ │   ├─z = 18 <N.NNμs>
    │ │   │ └─"test/test_expect_test.ml":1611:15
    │ │   └─z = 19 <N.NNμs>
    │ │     └─"test/test_expect_test.ml":1611:15
    │ ├─z = 5 <N.NNμs>
    │ │ └─"test/test_expect_test.ml":1611:15
    │ └─loop_exceeded = 1945 <N.NNμs>
    │   ├─"test/test_expect_test.ml":1606:35
    │   ├─<earlier entries truncated>
    │   ├─z = 8 <N.NNμs>
    │   │ └─"test/test_expect_test.ml":1611:15
    │   ├─loop_exceeded = 190 <N.NNμs>
    │   │ ├─"test/test_expect_test.ml":1606:35
    │   │ ├─<earlier entries truncated>
    │   │ ├─z = 16 <N.NNμs>
    │   │ │ └─"test/test_expect_test.ml":1611:15
    │   │ ├─z = 17 <N.NNμs>
    │   │ │ └─"test/test_expect_test.ml":1611:15
    │   │ ├─z = 18 <N.NNμs>
    │   │ │ └─"test/test_expect_test.ml":1611:15
    │   │ └─z = 19 <N.NNμs>
    │   │   └─"test/test_expect_test.ml":1611:15
    │   ├─z = 9 <N.NNμs>
    │   │ └─"test/test_expect_test.ml":1611:15
    │   └─loop_exceeded = 190 <N.NNμs>
    │     ├─"test/test_expect_test.ml":1606:35
    │     ├─<earlier entries truncated>
    │     ├─z = 16 <N.NNμs>
    │     │ └─"test/test_expect_test.ml":1611:15
    │     ├─z = 17 <N.NNμs>
    │     │ └─"test/test_expect_test.ml":1611:15
    │     ├─z = 18 <N.NNμs>
    │     │ └─"test/test_expect_test.ml":1611:15
    │     └─z = 19 <N.NNμs>
    │       └─"test/test_expect_test.ml":1611:15
    ├─z = 5 <N.NNμs>
    │ └─"test/test_expect_test.ml":1611:15
    └─loop_exceeded = 11685 <N.NNμs>
      ├─"test/test_expect_test.ml":1606:35
      ├─<earlier entries truncated>
      ├─z = 4 <N.NNμs>
      │ └─"test/test_expect_test.ml":1611:15
      ├─loop_exceeded = 1945 <N.NNμs>
      │ ├─"test/test_expect_test.ml":1606:35
      │ ├─<earlier entries truncated>
      │ ├─z = 8 <N.NNμs>
      │ │ └─"test/test_expect_test.ml":1611:15
      │ ├─loop_exceeded = 190 <N.NNμs>
      │ │ ├─"test/test_expect_test.ml":1606:35
      │ │ ├─<earlier entries truncated>
      │ │ ├─z = 16 <N.NNμs>
      │ │ │ └─"test/test_expect_test.ml":1611:15
      │ │ ├─z = 17 <N.NNμs>
      │ │ │ └─"test/test_expect_test.ml":1611:15
      │ │ ├─z = 18 <N.NNμs>
      │ │ │ └─"test/test_expect_test.ml":1611:15
      │ │ └─z = 19 <N.NNμs>
      │ │   └─"test/test_expect_test.ml":1611:15
      │ ├─z = 9 <N.NNμs>
      │ │ └─"test/test_expect_test.ml":1611:15
      │ └─loop_exceeded = 190 <N.NNμs>
      │   ├─"test/test_expect_test.ml":1606:35
      │   ├─<earlier entries truncated>
      │   ├─z = 16 <N.NNμs>
      │   │ └─"test/test_expect_test.ml":1611:15
      │   ├─z = 17 <N.NNμs>
      │   │ └─"test/test_expect_test.ml":1611:15
      │   ├─z = 18 <N.NNμs>
      │   │ └─"test/test_expect_test.ml":1611:15
      │   └─z = 19 <N.NNμs>
      │     └─"test/test_expect_test.ml":1611:15
      ├─z = 5 <N.NNμs>
      │ └─"test/test_expect_test.ml":1611:15
      └─loop_exceeded = 1945 <N.NNμs>
        ├─"test/test_expect_test.ml":1606:35
        ├─<earlier entries truncated>
        ├─z = 8 <N.NNμs>
        │ └─"test/test_expect_test.ml":1611:15
        ├─loop_exceeded = 190 <N.NNμs>
        │ ├─"test/test_expect_test.ml":1606:35
        │ ├─<earlier entries truncated>
        │ ├─z = 16 <N.NNμs>
        │ │ └─"test/test_expect_test.ml":1611:15
        │ ├─z = 17 <N.NNμs>
        │ │ └─"test/test_expect_test.ml":1611:15
        │ ├─z = 18 <N.NNμs>
        │ │ └─"test/test_expect_test.ml":1611:15
        │ └─z = 19 <N.NNμs>
        │   └─"test/test_expect_test.ml":1611:15
        ├─z = 9 <N.NNμs>
        │ └─"test/test_expect_test.ml":1611:15
        └─loop_exceeded = 190 <N.NNμs>
          ├─"test/test_expect_test.ml":1606:35
          ├─<earlier entries truncated>
          ├─z = 16 <N.NNμs>
          │ └─"test/test_expect_test.ml":1611:15
          ├─z = 17 <N.NNμs>
          │ └─"test/test_expect_test.ml":1611:15
          ├─z = 18 <N.NNμs>
          │ └─"test/test_expect_test.ml":1611:15
          └─z = 19 <N.NNμs>
            └─"test/test_expect_test.ml":1611:15
    58435
    |}]

let%expect_test "%debug_show PrintBox values_first_mode to stdout highlight" =
  let module Debug_runtime =
    (val Minidebug_runtime.debug ~highlight_terms:(Re.str "3") ~values_first_mode:true ())
  in
  let%debug_show rec loop_highlight (x : int) : int =
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
    ├─"test/test_expect_test.ml":1770:36
    ├─x = 7
    ├─┬─────┐
    │ │z = 3│
    │ ├─────┘
    │ └─"test/test_expect_test.ml":1771:8
    └─┬──────────────────┐
      │loop_highlight = 6│
      ├──────────────────┘
      ├─"test/test_expect_test.ml":1770:36
      ├─x = 6
      ├─z = 2
      │ └─"test/test_expect_test.ml":1771:8
      └─┬──────────────────┐
        │loop_highlight = 4│
        ├──────────────────┘
        ├─"test/test_expect_test.ml":1770:36
        ├─x = 5
        ├─z = 2
        │ └─"test/test_expect_test.ml":1771:8
        └─┬──────────────────┐
          │loop_highlight = 2│
          ├──────────────────┘
          ├─"test/test_expect_test.ml":1770:36
          ├─x = 4
          ├─z = 1
          │ └─"test/test_expect_test.ml":1771:8
          └─┬──────────────────┐
            │loop_highlight = 1│
            ├──────────────────┘
            ├─"test/test_expect_test.ml":1770:36
            ├─┬─────┐
            │ │x = 3│
            │ └─────┘
            ├─z = 1
            │ └─"test/test_expect_test.ml":1771:8
            └─loop_highlight = 0
              ├─"test/test_expect_test.ml":1770:36
              ├─x = 2
              ├─z = 0
              │ └─"test/test_expect_test.ml":1771:8
              └─loop_highlight = 0
                ├─"test/test_expect_test.ml":1770:36
                ├─x = 1
                ├─z = 0
                │ └─"test/test_expect_test.ml":1771:8
                └─loop_highlight = 0
                  ├─"test/test_expect_test.ml":1770:36
                  ├─x = 0
                  └─z = 0
                    └─"test/test_expect_test.ml":1771:8
    9
    |}]

let%expect_test "%track_show PrintBox values_first_mode tracking" =
  let module Debug_runtime = (val Minidebug_runtime.debug ~values_first_mode:true ()) in
  let%track_show track_branches (x : int) : int =
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
    ├─"test/test_expect_test.ml":1837:32
    ├─x = 7
    └─else:test_expect_test:1839
      ├─"test/test_expect_test.ml":1839:9
      └─<match -- branch 1>
        └─"test/test_expect_test.ml":1839:36
    4
    track_branches = -3
    ├─"test/test_expect_test.ml":1837:32
    ├─x = 3
    └─then:test_expect_test:1838
      ├─"test/test_expect_test.ml":1838:18
      └─<match -- branch 2>
        └─"test/test_expect_test.ml":1838:54
    -3
    |}]

let%expect_test "%track_show PrintBox values_first_mode to stdout no return type \
                 anonymous fun" =
  let module Debug_runtime = (val Minidebug_runtime.debug ~values_first_mode:true ()) in
  let%track_show anonymous (x : int) =
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
    ├─"test/test_expect_test.ml":1871:27
    ├─x = 3
    ├─fun:test_expect_test:1872
    │ ├─"test/test_expect_test.ml":1872:50
    │ └─i = 0
    ├─fun:test_expect_test:1872
    │ ├─"test/test_expect_test.ml":1872:50
    │ └─i = 1
    ├─fun:test_expect_test:1872
    │ ├─"test/test_expect_test.ml":1872:50
    │ └─i = 2
    └─fun:test_expect_test:1872
      ├─"test/test_expect_test.ml":1872:50
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
  let%debug_show baz { first : int; second : int } : int =
    let { first : int; second : int } = { first = first + 1; second = second + 3 } in
    (first * first) + second
  in
  let () = print_endline @@ Int.to_string @@ baz { first = 7; second = 42 } in
  [%expect
    {|
    BEGIN DEBUG SESSION
    "test/test_expect_test.ml":1901:21: bar
    ├─first = 7
    ├─second = 42
    ├─"test/test_expect_test.ml":1902:8: {first=a; second=b}
    │ ├─a = 7
    │ └─b = 45
    ├─"test/test_expect_test.ml":1903:8: y
    │ └─y = 8
    └─bar = 336
    336
    "test/test_expect_test.ml":1907:21: baz
    ├─first = 7
    ├─second = 42
    ├─"test/test_expect_test.ml":1908:8: {first; second}
    │ ├─first = 8
    │ └─second = 45
    └─baz = 109
    109
    |}]

let%expect_test "%debug_show tuples" =
  let module Debug_runtime = (val Minidebug_runtime.debug ~values_first_mode:false ()) in
  let%debug_show bar ((first : int), (second : int)) : int =
    let y : int = first + 1 in
    second * y
  in
  let () = print_endline @@ Int.to_string @@ bar (7, 42) in
  let%debug_show baz ((first, second) : int * int) : int * int =
    let (y, z) : int * int = (first + 1, 3) in
    let (a : int), (b : int) = (first + 1, second + 3) in
    ((second * y) + z, (a * a) + b)
  in
  let%debug_show r1, r2 = (baz (7, 42) : int * int) in
  let () = print_endline @@ Int.to_string r1 in
  let () = print_endline @@ Int.to_string r2 in
  [%expect
    {|
    BEGIN DEBUG SESSION
    "test/test_expect_test.ml":1937:21: bar
    ├─first = 7
    ├─second = 42
    ├─"test/test_expect_test.ml":1938:8: y
    │ └─y = 8
    └─bar = 336
    336
    "test/test_expect_test.ml":1947:17: (r1, r2)
    ├─"test/test_expect_test.ml":1942:21: baz
    │ ├─first = 7
    │ ├─second = 42
    │ ├─"test/test_expect_test.ml":1943:8: (y, z)
    │ │ ├─y = 8
    │ │ └─z = 3
    │ ├─"test/test_expect_test.ml":1944:8: (a, b)
    │ │ ├─a = 8
    │ │ └─b = 45
    │ └─baz = (339, 109)
    ├─r1 = 339
    └─r2 = 109
    339
    109
    |}]

let%expect_test "%debug_show records values_first_mode" =
  let module Debug_runtime = (val Minidebug_runtime.debug ~values_first_mode:true ()) in
  let%debug_show bar { first : int; second : int } : int =
    let { first : int = a; second : int = b } = { first; second = second + 3 } in
    let y : int = a + 1 in
    (b - 3) * y
  in
  let () = print_endline @@ Int.to_string @@ bar { first = 7; second = 42 } in
  let%debug_show baz { first : int; second : int } : int =
    let { first : int; second : int } = { first = first + 1; second = second + 3 } in
    (first * first) + second
  in
  let () = print_endline @@ Int.to_string @@ baz { first = 7; second = 42 } in
  [%expect
    {|
    BEGIN DEBUG SESSION
    bar = 336
    ├─"test/test_expect_test.ml":1979:21
    ├─first = 7
    ├─second = 42
    ├─{first=a; second=b}
    │ ├─"test/test_expect_test.ml":1980:8
    │ └─<values>
    │   ├─a = 7
    │   └─b = 45
    └─y = 8
      └─"test/test_expect_test.ml":1981:8
    336
    baz = 109
    ├─"test/test_expect_test.ml":1985:21
    ├─first = 7
    ├─second = 42
    └─{first; second}
      ├─"test/test_expect_test.ml":1986:8
      └─<values>
        ├─first = 8
        └─second = 45
    109
    |}]

let%expect_test "%debug_show tuples values_first_mode" =
  let module Debug_runtime = (val Minidebug_runtime.debug ~values_first_mode:true ()) in
  let%debug_show bar ((first : int), (second : int)) : int =
    let y : int = first + 1 in
    second * y
  in
  let () = print_endline @@ Int.to_string @@ bar (7, 42) in
  let%debug_show baz ((first, second) : int * int) : int * int =
    let (y, z) : int * int = (first + 1, 3) in
    let (a : int), (b : int) = (first + 1, second + 3) in
    ((second * y) + z, (a * a) + b)
  in
  let%debug_show r1, r2 = (baz (7, 42) : int * int) in
  let () = print_endline @@ Int.to_string r1 in
  let () = print_endline @@ Int.to_string r2 in
  [%expect
    {|
    BEGIN DEBUG SESSION
    bar = 336
    ├─"test/test_expect_test.ml":2019:21
    ├─first = 7
    ├─second = 42
    └─y = 8
      └─"test/test_expect_test.ml":2020:8
    336
    (r1, r2)
    ├─"test/test_expect_test.ml":2029:17
    ├─<returns>
    │ ├─r1 = 339
    │ └─r2 = 109
    └─baz = (339, 109)
      ├─"test/test_expect_test.ml":2024:21
      ├─first = 7
      ├─second = 42
      ├─(y, z)
      │ ├─"test/test_expect_test.ml":2025:8
      │ └─<values>
      │   ├─y = 8
      │   └─z = 3
      └─(a, b)
        ├─"test/test_expect_test.ml":2026:8
        └─<values>
          ├─a = 8
          └─b = 45
    339
    109
    |}]

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
  let%track_show baz : 'a -> int = function
    | Left (x : int) -> x + 1
    | Right (Two (y : int)) -> y * 2
    | _ -> 3
  in
  let%track_show foo x : int =
    match x with Left (x : int) -> x + 1 | Right (Two (y : int)) -> y * 2 | _ -> 3
  in
  let () = print_endline @@ Int.to_string @@ baz (Left 4) in
  let () = print_endline @@ Int.to_string @@ baz (Right (Two 3)) in
  let () = print_endline @@ Int.to_string @@ foo (Right (Three 0)) in
  [%expect
    {|
    BEGIN DEBUG SESSION
    bar = 16
    ├─"test/test_expect_test.ml":2071:21
    ├─x = 7
    └─y = 8
      └─"test/test_expect_test.ml":2072:8
    16
    baz = 5
    ├─"test/test_expect_test.ml":2077:24
    ├─<function -- branch 0> Left x
    └─x = 4
    5
    baz = 6
    ├─"test/test_expect_test.ml":2078:31
    ├─<function -- branch 1> Right Two y
    └─y = 3
    6
    foo = 3
    ├─"test/test_expect_test.ml":2081:21
    └─<match -- branch 2>
      └─"test/test_expect_test.ml":2082:81
    3
    |}]

let%expect_test "%debug_show tuples merge type info" =
  let module Debug_runtime = (val Minidebug_runtime.debug ~values_first_mode:true ()) in
  let%debug_show baz (((first : int), (second : 'a)) : 'b * int) : int * int =
    let ((y : 'c), (z : int)) : int * 'd = (first + 1, 3) in
    let (a : int), b = (first + 1, (second + 3 : int)) in
    ((second * y) + z, (a * a) + b)
  in
  let%debug_show (r1 : 'e), (r2 : int) = (baz (7, 42) : int * 'f) in
  let () = print_endline @@ Int.to_string r1 in
  let () = print_endline @@ Int.to_string r2 in
  (* Note the missing value of [b]: the nested-in-expression type is not propagated. *)
  [%expect
    {|
    BEGIN DEBUG SESSION
    (r1, r2)
    ├─"test/test_expect_test.ml":2120:17
    ├─<returns>
    │ ├─r1 = 339
    │ └─r2 = 109
    └─baz = (339, 109)
      ├─"test/test_expect_test.ml":2115:21
      ├─first = 7
      ├─second = 42
      ├─(y, z)
      │ ├─"test/test_expect_test.ml":2116:8
      │ └─<values>
      │   ├─y = 8
      │   └─z = 3
      └─a = 8
        └─"test/test_expect_test.ml":2117:8
    339
    109
    |}]

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
    ├─"test/test_expect_test.ml":2149:44
    └─b = 6
    7
    g = 12
    ├─"test/test_expect_test.ml":2150:56
    └─b = 6
    12
    |}]

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
    ├─"test/test_expect_test.ml":2170:37
    ├─f : int
    └─b : int = 6
    7
    g : int = 12
    ├─"test/test_expect_test.ml":2171:49
    ├─g : int
    └─b : int = 6
    12
    |}]

let%expect_test "%track_show options values_first_mode" =
  let module Debug_runtime = (val Minidebug_runtime.debug ~values_first_mode:true ()) in
  let%track_show foo l : int =
    match (l : int option) with None -> 7 | Some y -> y * 2
  in
  let () = print_endline @@ Int.to_string @@ foo (Some 7) in
  let%track_show bar (l : int option) : int =
    match l with None -> 7 | Some y -> y * 2
  in
  let () = print_endline @@ Int.to_string @@ bar (Some 7) in
  let%track_show baz : int option -> int = function None -> 7 | Some y -> y * 2 in
  let () = print_endline @@ Int.to_string @@ baz (Some 4) in
  let%track_show zoo : (int * int) option -> int = function
    | None -> 7
    | Some (y, z) -> y + z
  in
  let () = print_endline @@ Int.to_string @@ zoo (Some (4, 5)) in
  [%expect
    {|
    BEGIN DEBUG SESSION
    foo = 14
    ├─"test/test_expect_test.ml":2191:21
    └─<match -- branch 1> Some y
      ├─"test/test_expect_test.ml":2192:54
      └─y = 7
    14
    bar = 14
    ├─"test/test_expect_test.ml":2195:21
    ├─l = (Some 7)
    └─<match -- branch 1> Some y
      └─"test/test_expect_test.ml":2196:39
    14
    baz = 8
    ├─"test/test_expect_test.ml":2199:74
    ├─<function -- branch 1> Some y
    └─y = 4
    8
    zoo = 9
    ├─"test/test_expect_test.ml":2203:21
    ├─<function -- branch 1> Some (y, z)
    ├─y = 4
    └─z = 5
    9
    |}]

let%expect_test "%track_show list values_first_mode" =
  let module Debug_runtime = (val Minidebug_runtime.debug ~values_first_mode:true ()) in
  let%track_show foo l : int = match (l : int list) with [] -> 7 | y :: _ -> y * 2 in
  let () = print_endline @@ Int.to_string @@ foo [ 7 ] in
  let%track_show bar (l : int list) : int = match l with [] -> 7 | y :: _ -> y * 2 in
  let () = print_endline @@ Int.to_string @@ bar [ 7 ] in
  let%track_show baz : int list -> int = function
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
    ├─"test/test_expect_test.ml":2236:21
    └─<match -- branch 1> :: (y, _)
      ├─"test/test_expect_test.ml":2236:77
      └─y = 7
    14
    bar = 14
    ├─"test/test_expect_test.ml":2238:21
    ├─l = [7]
    └─<match -- branch 1> :: (y, _)
      └─"test/test_expect_test.ml":2238:77
    14
    baz = 8
    ├─"test/test_expect_test.ml":2242:15
    ├─<function -- branch 1> :: (y, [])
    └─y = 4
    8
    baz = 9
    ├─"test/test_expect_test.ml":2243:18
    ├─<function -- branch 2> :: (y, :: (z, []))
    ├─y = 4
    └─z = 5
    9
    baz = 10
    ├─"test/test_expect_test.ml":2244:21
    ├─<function -- branch 3> :: (y, :: (z, _))
    ├─y = 4
    └─z = 5
    10
    |}]

let%expect_test "%track_rt_show list runtime passing" =
  let%track_rt_show foo l : int = match (l : int list) with [] -> 7 | y :: _ -> y * 2 in
  let () =
    print_endline @@ Int.to_string
    @@ foo
         Minidebug_runtime.(
           forget_printbox @@ debug ~global_prefix:"foo-1" ~values_first_mode:true ())
         [ 7 ]
  in
  let%track_rt_show baz : int list -> int = function
    | [] -> 7
    | [ y ] -> y * 2
    | [ y; z ] -> y + z
    | y :: z :: _ -> y + z + 1
  in
  let () =
    print_endline @@ Int.to_string
    @@ baz
         Minidebug_runtime.(
           forget_printbox @@ debug ~global_prefix:"baz-1" ~values_first_mode:true ())
         [ 4 ]
  in
  let () =
    print_endline @@ Int.to_string
    @@ baz
         Minidebug_runtime.(
           forget_printbox @@ debug ~global_prefix:"baz-2" ~values_first_mode:true ())
         [ 4; 5; 6 ]
  in
  [%expect
    {|
    BEGIN DEBUG SESSION foo-1
    foo = 14
    ├─"test/test_expect_test.ml":2284:24
    └─foo-1 <match -- branch 1> :: (y, _)
      ├─"test/test_expect_test.ml":2284:80
      └─y = 7
    14

    BEGIN DEBUG SESSION baz-1
    baz = 8
    ├─"test/test_expect_test.ml":2294:15
    ├─baz-1 <function -- branch 1> :: (y, [])
    └─y = 4
    8

    BEGIN DEBUG SESSION baz-2
    baz = 10
    ├─"test/test_expect_test.ml":2296:21
    ├─baz-2 <function -- branch 3> :: (y, :: (z, _))
    ├─y = 4
    └─z = 5
    10
    |}]

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
    bar-1 bar begin "test/test_expect_test.ml":2339:24:
     bar-1 fun:test_expect_test:2339 begin "test/test_expect_test.ml":2339:29:
     bar-1 fun:test_expect_test:2339 end
    bar-1 bar end

    BEGIN DEBUG SESSION bar-2
    bar-2 bar begin "test/test_expect_test.ml":2339:24:
     bar-2 fun:test_expect_test:2339 begin "test/test_expect_test.ml":2339:29:
     bar-2 fun:test_expect_test:2339 end
    bar-2 bar end

    BEGIN DEBUG SESSION foo-1
    foo-1 foo begin "test/test_expect_test.ml":2342:24:
    foo-1 foo end

    BEGIN DEBUG SESSION foo-2
    foo-2 foo begin "test/test_expect_test.ml":2342:24:
    foo-2 foo end
    |}]

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

    BEGIN DEBUG SESSION foo-1
    foo-1 foo begin "test/test_expect_test.ml":2375:26:
    foo-1 foo end

    BEGIN DEBUG SESSION foo-2
    foo-2 foo begin "test/test_expect_test.ml":2375:26:
    foo-2 foo end

    BEGIN DEBUG SESSION bar-1
    bar-1 bar begin "test/test_expect_test.ml":2374:26:
     bar-1 fun:test_expect_test:2374 begin "test/test_expect_test.ml":2374:31:
     bar-1 fun:test_expect_test:2374 end
    bar-1 bar end

    BEGIN DEBUG SESSION bar-2
    bar-2 bar begin "test/test_expect_test.ml":2374:26:
     bar-2 fun:test_expect_test:2374 begin "test/test_expect_test.ml":2374:31:
     bar-2 fun:test_expect_test:2374 end
    bar-2 bar end
    |}]

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
    ├─"test/test_expect_test.ml":2413:21
    ├─"This is the first log line"
    ├─["This is the"; "2"; "log line"]
    └─("This is the", 3, "or", 3.14, "log line")
    bar
    ├─"test/test_expect_test.ml":2420:21
    ├─This is the first log line
    ├─This is the
    │ ├─2
    │ └─log line
    └─This is the
      ├─3
      ├─or
      ├─3.14
      └─log line
    |}]

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
    ├─"test/test_expect_test.ml":2452:21
    ├─("This is like", 3, "or", 3.14, "above")
    ├─("tau =", 6.28)
    ├─[4; 1; 2; 3]
    ├─[3; 1; 2; 3]
    └─[3; 1; 2; 3]
    |}]

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
    ├─"test/test_expect_test.ml":2478:21
    ├─"2*3"
    ├─("This is like", "3", "or", "3.14", "above")
    ├─("tau =", "2*3.14")
    └─[("2*3", 0); ("1", 1); ("2", 2); ("3", 3)]
    |}]

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
    "test/test_expect_test.ml":2501:17: result
    └─"test/test_expect_test.ml":2504:4: while:test_expect_test:2504
      ├─"test/test_expect_test.ml":2505:6: <while loop>
      │ ├─(1 i= 0)
      │ ├─(2 i= 1)
      │ └─(3 j= 1)
      ├─"test/test_expect_test.ml":2505:6: <while loop>
      │ ├─(1 i= 1)
      │ ├─(2 i= 2)
      │ └─(3 j= 3)
      ├─"test/test_expect_test.ml":2505:6: <while loop>
      │ ├─(1 i= 2)
      │ ├─(2 i= 3)
      │ └─(3 j= 6)
      ├─"test/test_expect_test.ml":2505:6: <while loop>
      │ ├─(1 i= 3)
      │ ├─(2 i= 4)
      │ └─(3 j= 10)
      ├─"test/test_expect_test.ml":2505:6: <while loop>
      │ ├─(1 i= 4)
      │ ├─(2 i= 5)
      │ └─(3 j= 15)
      └─"test/test_expect_test.ml":2505:6: <while loop>
        ├─(1 i= 5)
        ├─(2 i= 6)
        └─(3 j= 21)
    21
    |}]

let%expect_test "%log runtime log levels while-loop" =
  let%track_rt_sexp result () : int =
    let i = ref 0 in
    let j = ref 0 in
    while !i < 6 do
      (* Intentional empty but not omitted else-branch. *)
      if !i < 2 then [%log1 "ERROR:", 1, "i=", (!i : int)] else ();
      incr i;
      [%log2 "WARNING:", 2, "i=", (!i : int)];
      j := (fun { contents } -> !j + contents) i;
      [%log3 "INFO:", 3, "j=", (!j : int)]
    done;
    !j
  in
  print_endline
  @@ Int.to_string
       (result
          Minidebug_runtime.(forget_printbox @@ debug ~global_prefix:"Everything" ())
          ());
  print_endline
  @@ Int.to_string
       (result
          Minidebug_runtime.(
            forget_printbox
            @@ debug ~values_first_mode:true ~log_level:0 ~global_prefix:"Nothing" ())
          ());
  print_endline
  @@ Int.to_string
       (result
          Minidebug_runtime.(
            forget_printbox
            @@ debug ~values_first_mode:true ~log_level:1 ~global_prefix:"Error" ())
          ());
  print_endline
  @@ Int.to_string
       (result
          Minidebug_runtime.(
            forget_printbox
            @@ debug ~values_first_mode:true ~log_level:2 ~global_prefix:"Warning" ())
          ());
  [%expect
    {|
    BEGIN DEBUG SESSION Everything
    "test/test_expect_test.ml":2547:27: Everything result
    ├─"test/test_expect_test.ml":2550:4: Everything while:test_expect_test:2550
    │ ├─"test/test_expect_test.ml":2552:6: Everything <while loop>
    │ │ ├─"test/test_expect_test.ml":2552:21: Everything then:test_expect_test:2552
    │ │ │ └─(ERROR: 1 i= 0)
    │ │ ├─(WARNING: 2 i= 1)
    │ │ ├─"test/test_expect_test.ml":2555:11: Everything fun:test_expect_test:2555
    │ │ └─(INFO: 3 j= 1)
    │ ├─"test/test_expect_test.ml":2552:6: Everything <while loop>
    │ │ ├─"test/test_expect_test.ml":2552:21: Everything then:test_expect_test:2552
    │ │ │ └─(ERROR: 1 i= 1)
    │ │ ├─(WARNING: 2 i= 2)
    │ │ ├─"test/test_expect_test.ml":2555:11: Everything fun:test_expect_test:2555
    │ │ └─(INFO: 3 j= 3)
    │ ├─"test/test_expect_test.ml":2552:6: Everything <while loop>
    │ │ ├─"test/test_expect_test.ml":2552:64: Everything else:test_expect_test:2552
    │ │ ├─(WARNING: 2 i= 3)
    │ │ ├─"test/test_expect_test.ml":2555:11: Everything fun:test_expect_test:2555
    │ │ └─(INFO: 3 j= 6)
    │ ├─"test/test_expect_test.ml":2552:6: Everything <while loop>
    │ │ ├─"test/test_expect_test.ml":2552:64: Everything else:test_expect_test:2552
    │ │ ├─(WARNING: 2 i= 4)
    │ │ ├─"test/test_expect_test.ml":2555:11: Everything fun:test_expect_test:2555
    │ │ └─(INFO: 3 j= 10)
    │ ├─"test/test_expect_test.ml":2552:6: Everything <while loop>
    │ │ ├─"test/test_expect_test.ml":2552:64: Everything else:test_expect_test:2552
    │ │ ├─(WARNING: 2 i= 5)
    │ │ ├─"test/test_expect_test.ml":2555:11: Everything fun:test_expect_test:2555
    │ │ └─(INFO: 3 j= 15)
    │ └─"test/test_expect_test.ml":2552:6: Everything <while loop>
    │   ├─"test/test_expect_test.ml":2552:64: Everything else:test_expect_test:2552
    │   ├─(WARNING: 2 i= 6)
    │   ├─"test/test_expect_test.ml":2555:11: Everything fun:test_expect_test:2555
    │   └─(INFO: 3 j= 21)
    └─result = 21
    21

    BEGIN DEBUG SESSION Nothing
    21

    BEGIN DEBUG SESSION Error
    result = 21
    ├─"test/test_expect_test.ml":2547:27
    └─Error while:test_expect_test:2550
      ├─"test/test_expect_test.ml":2550:4
      ├─Error <while loop>
      │ ├─"test/test_expect_test.ml":2552:6
      │ ├─Error then:test_expect_test:2552
      │ │ ├─"test/test_expect_test.ml":2552:21
      │ │ └─(ERROR: 1 i= 0)
      │ └─Error fun:test_expect_test:2555
      │   └─"test/test_expect_test.ml":2555:11
      ├─Error <while loop>
      │ ├─"test/test_expect_test.ml":2552:6
      │ ├─Error then:test_expect_test:2552
      │ │ ├─"test/test_expect_test.ml":2552:21
      │ │ └─(ERROR: 1 i= 1)
      │ └─Error fun:test_expect_test:2555
      │   └─"test/test_expect_test.ml":2555:11
      ├─Error <while loop>
      │ ├─"test/test_expect_test.ml":2552:6
      │ ├─Error else:test_expect_test:2552
      │ │ └─"test/test_expect_test.ml":2552:64
      │ └─Error fun:test_expect_test:2555
      │   └─"test/test_expect_test.ml":2555:11
      ├─Error <while loop>
      │ ├─"test/test_expect_test.ml":2552:6
      │ ├─Error else:test_expect_test:2552
      │ │ └─"test/test_expect_test.ml":2552:64
      │ └─Error fun:test_expect_test:2555
      │   └─"test/test_expect_test.ml":2555:11
      ├─Error <while loop>
      │ ├─"test/test_expect_test.ml":2552:6
      │ ├─Error else:test_expect_test:2552
      │ │ └─"test/test_expect_test.ml":2552:64
      │ └─Error fun:test_expect_test:2555
      │   └─"test/test_expect_test.ml":2555:11
      └─Error <while loop>
        ├─"test/test_expect_test.ml":2552:6
        ├─Error else:test_expect_test:2552
        │ └─"test/test_expect_test.ml":2552:64
        └─Error fun:test_expect_test:2555
          └─"test/test_expect_test.ml":2555:11
    21

    BEGIN DEBUG SESSION Warning
    result = 21
    ├─"test/test_expect_test.ml":2547:27
    └─Warning while:test_expect_test:2550
      ├─"test/test_expect_test.ml":2550:4
      ├─Warning <while loop>
      │ ├─"test/test_expect_test.ml":2552:6
      │ ├─Warning then:test_expect_test:2552
      │ │ ├─"test/test_expect_test.ml":2552:21
      │ │ └─(ERROR: 1 i= 0)
      │ ├─(WARNING: 2 i= 1)
      │ └─Warning fun:test_expect_test:2555
      │   └─"test/test_expect_test.ml":2555:11
      ├─Warning <while loop>
      │ ├─"test/test_expect_test.ml":2552:6
      │ ├─Warning then:test_expect_test:2552
      │ │ ├─"test/test_expect_test.ml":2552:21
      │ │ └─(ERROR: 1 i= 1)
      │ ├─(WARNING: 2 i= 2)
      │ └─Warning fun:test_expect_test:2555
      │   └─"test/test_expect_test.ml":2555:11
      ├─Warning <while loop>
      │ ├─"test/test_expect_test.ml":2552:6
      │ ├─Warning else:test_expect_test:2552
      │ │ └─"test/test_expect_test.ml":2552:64
      │ ├─(WARNING: 2 i= 3)
      │ └─Warning fun:test_expect_test:2555
      │   └─"test/test_expect_test.ml":2555:11
      ├─Warning <while loop>
      │ ├─"test/test_expect_test.ml":2552:6
      │ ├─Warning else:test_expect_test:2552
      │ │ └─"test/test_expect_test.ml":2552:64
      │ ├─(WARNING: 2 i= 4)
      │ └─Warning fun:test_expect_test:2555
      │   └─"test/test_expect_test.ml":2555:11
      ├─Warning <while loop>
      │ ├─"test/test_expect_test.ml":2552:6
      │ ├─Warning else:test_expect_test:2552
      │ │ └─"test/test_expect_test.ml":2552:64
      │ ├─(WARNING: 2 i= 5)
      │ └─Warning fun:test_expect_test:2555
      │   └─"test/test_expect_test.ml":2555:11
      └─Warning <while loop>
        ├─"test/test_expect_test.ml":2552:6
        ├─Warning else:test_expect_test:2552
        │ └─"test/test_expect_test.ml":2552:64
        ├─(WARNING: 2 i= 6)
        └─Warning fun:test_expect_test:2555
          └─"test/test_expect_test.ml":2555:11
    21
    |}]

let%expect_test "%log compile time log levels while-loop" =
  let module Debug_runtime = (val Minidebug_runtime.debug ~values_first_mode:true ()) in
  let%track_sexp everything () : int =
    [%log_level
      9;
      let i = ref 0 in
      let j = ref 0 in
      while !i < 6 do
        (* Intentional empty but not omitted else-branch. *)
        if !i < 2 then [%log1 "ERROR:", 1, "i=", (!i : int)] else ();
        incr i;
        [%log2 "WARNING:", 2, "i=", (!i : int)];
        j := (fun { contents } -> !j + contents) i;
        [%log3 "INFO:", 3, "j=", (!j : int)]
      done;
      !j]
  in
  let%track_sexp nothing () : int =
    (* The result is still logged, because the binding is outside of %log_level. *)
    [%log_level
      0;
      let i = ref 0 in
      let j = ref 0 in
      while !i < 6 do
        (* Intentional empty but not omitted else-branch. *)
        if !i < 2 then [%log1 "ERROR:", 1, "i=", (!i : int)] else ();
        incr i;
        [%log2 "WARNING:", 2, "i=", (!i : int)];
        j := (fun { contents } -> !j + contents) i;
        [%log3 "INFO:", 3, "j=", (!j : int)]
      done;
      !j]
  in
  let%track_sexp warning () : int =
    [%log_level
      2;
      let i = ref 0 in
      let j = ref 0 in
      while !i < 6 do
        (* Reduce the debugging noise. *)
        [%diagn_sexp
          (* Intentional empty but not omitted else-branch. *)
          if !i < 2 then [%log1 "ERROR:", 1, "i=", (!i : int)] else ();
          incr i;
          [%log2 "WARNING:", 2, "i=", (!i : int)];
          j := (fun { contents } -> !j + contents) i;
          [%log3 "INFO:", 3, "j=", (!j : int)]]
      done;
      !j]
  in
  print_endline @@ Int.to_string @@ everything ();
  print_endline @@ Int.to_string @@ nothing ();
  print_endline @@ Int.to_string @@ warning ();
  [%expect
    {|
    BEGIN DEBUG SESSION
    everything = 21
    ├─"test/test_expect_test.ml":2728:28
    └─while:test_expect_test:2733
      ├─"test/test_expect_test.ml":2733:6
      ├─<while loop>
      │ ├─"test/test_expect_test.ml":2735:8
      │ ├─then:test_expect_test:2735
      │ │ ├─"test/test_expect_test.ml":2735:23
      │ │ └─(ERROR: 1 i= 0)
      │ ├─(WARNING: 2 i= 1)
      │ ├─fun:test_expect_test:2738
      │ │ └─"test/test_expect_test.ml":2738:13
      │ └─(INFO: 3 j= 1)
      ├─<while loop>
      │ ├─"test/test_expect_test.ml":2735:8
      │ ├─then:test_expect_test:2735
      │ │ ├─"test/test_expect_test.ml":2735:23
      │ │ └─(ERROR: 1 i= 1)
      │ ├─(WARNING: 2 i= 2)
      │ ├─fun:test_expect_test:2738
      │ │ └─"test/test_expect_test.ml":2738:13
      │ └─(INFO: 3 j= 3)
      ├─<while loop>
      │ ├─"test/test_expect_test.ml":2735:8
      │ ├─else:test_expect_test:2735
      │ │ └─"test/test_expect_test.ml":2735:66
      │ ├─(WARNING: 2 i= 3)
      │ ├─fun:test_expect_test:2738
      │ │ └─"test/test_expect_test.ml":2738:13
      │ └─(INFO: 3 j= 6)
      ├─<while loop>
      │ ├─"test/test_expect_test.ml":2735:8
      │ ├─else:test_expect_test:2735
      │ │ └─"test/test_expect_test.ml":2735:66
      │ ├─(WARNING: 2 i= 4)
      │ ├─fun:test_expect_test:2738
      │ │ └─"test/test_expect_test.ml":2738:13
      │ └─(INFO: 3 j= 10)
      ├─<while loop>
      │ ├─"test/test_expect_test.ml":2735:8
      │ ├─else:test_expect_test:2735
      │ │ └─"test/test_expect_test.ml":2735:66
      │ ├─(WARNING: 2 i= 5)
      │ ├─fun:test_expect_test:2738
      │ │ └─"test/test_expect_test.ml":2738:13
      │ └─(INFO: 3 j= 15)
      └─<while loop>
        ├─"test/test_expect_test.ml":2735:8
        ├─else:test_expect_test:2735
        │ └─"test/test_expect_test.ml":2735:66
        ├─(WARNING: 2 i= 6)
        ├─fun:test_expect_test:2738
        │ └─"test/test_expect_test.ml":2738:13
        └─(INFO: 3 j= 21)
    21
    nothing = 21
    └─"test/test_expect_test.ml":2743:25
    21
    warning = 21
    ├─"test/test_expect_test.ml":2759:25
    └─while:test_expect_test:2764
      ├─"test/test_expect_test.ml":2764:6
      ├─<while loop>
      │ ├─"test/test_expect_test.ml":2766:8
      │ ├─(ERROR: 1 i= 0)
      │ └─(WARNING: 2 i= 1)
      ├─<while loop>
      │ ├─"test/test_expect_test.ml":2766:8
      │ ├─(ERROR: 1 i= 1)
      │ └─(WARNING: 2 i= 2)
      ├─<while loop>
      │ ├─"test/test_expect_test.ml":2766:8
      │ └─(WARNING: 2 i= 3)
      ├─<while loop>
      │ ├─"test/test_expect_test.ml":2766:8
      │ └─(WARNING: 2 i= 4)
      ├─<while loop>
      │ ├─"test/test_expect_test.ml":2766:8
      │ └─(WARNING: 2 i= 5)
      └─<while loop>
        ├─"test/test_expect_test.ml":2766:8
        └─(WARNING: 2 i= 6)
    21
    |}]

let%expect_test "%log compile time log levels runtime-passing while-loop" =
  let module Debug_runtime =
    (val Minidebug_runtime.debug ~global_prefix:"TOPLEVEL" ~values_first_mode:true ())
  in
  (* Compile-time log level restrictions cannot be undone, since the logging code is not
     generated. *)
  let%debug_sexp () =
    ([%log_level
       0;
       let%track_rt_sexp nothing () : int =
         let i = ref 0 in
         let j = ref 0 in
         while !i < 6 do
           (* Intentional empty but not omitted else-branch. *)
           if !i < 2 then [%log1 "ERROR:", 1, "i=", (!i : int)] else ();
           incr i;
           [%log2 "WARNING:", 2, "i=", (!i : int)];
           j := (fun { contents } -> !j + contents) i;
           [%log3 "INFO:", 3, "j=", (!j : int)]
         done;
         !j
       in
       print_endline @@ Int.to_string
       @@ nothing
            Minidebug_runtime.(
              forget_printbox @@ debug ~global_prefix:"nothing" ~values_first_mode:true ())
            ()]);
    [%log_level
      2;
      let%track_rt_sexp warning () : int =
        let i = ref 0 in
        let j = ref 0 in
        while !i < 6 do
          (* Reduce the debugging noise. *)
          [%diagn_sexp
            (* Intentional empty but not omitted else-branch. *)
            if !i < 2 then [%log1 "ERROR:", 1, "i=", (!i : int)] else ();
            incr i;
            [%log2 "WARNING:", 2, "i=", (!i : int)];
            j := (fun { contents } -> !j + contents) i;
            [%log3 "INFO:", 3, "j=", (!j : int)]]
        done;
        !j
      in
      print_endline @@ Int.to_string
      @@ warning
           Minidebug_runtime.(
             forget_printbox @@ debug ~global_prefix:"warning" ~values_first_mode:true ())
           ()]
  in
  [%expect
    {|
    BEGIN DEBUG SESSION TOPLEVEL

    BEGIN DEBUG SESSION nothing
    21

    BEGIN DEBUG SESSION warning
    warning = 21
    ├─"test/test_expect_test.ml":2896:32
    └─warning while:test_expect_test:2899
      ├─"test/test_expect_test.ml":2899:8
      ├─warning <while loop>
      │ ├─"test/test_expect_test.ml":2901:10
      │ ├─(ERROR: 1 i= 0)
      │ └─(WARNING: 2 i= 1)
      ├─warning <while loop>
      │ ├─"test/test_expect_test.ml":2901:10
      │ ├─(ERROR: 1 i= 1)
      │ └─(WARNING: 2 i= 2)
      ├─warning <while loop>
      │ ├─"test/test_expect_test.ml":2901:10
      │ └─(WARNING: 2 i= 3)
      ├─warning <while loop>
      │ ├─"test/test_expect_test.ml":2901:10
      │ └─(WARNING: 2 i= 4)
      ├─warning <while loop>
      │ ├─"test/test_expect_test.ml":2901:10
      │ └─(WARNING: 2 i= 5)
      └─warning <while loop>
        ├─"test/test_expect_test.ml":2901:10
        └─(WARNING: 2 i= 6)
    21
    TOPLEVEL ()
    └─"test/test_expect_test.ml":2873:17
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
    ├─"test/test_expect_test.ml":2956:17
    └─while:test_expect_test:2959
      ├─"test/test_expect_test.ml":2959:4
      ├─(3 j= 1)
      │ ├─"test/test_expect_test.ml":2960:6
      │ ├─<while loop>
      │ ├─(1 i= 0)
      │ └─(2 i= 1)
      ├─(3 j= 3)
      │ ├─"test/test_expect_test.ml":2960:6
      │ ├─<while loop>
      │ ├─(1 i= 1)
      │ └─(2 i= 2)
      ├─(3 j= 6)
      │ ├─"test/test_expect_test.ml":2960:6
      │ ├─<while loop>
      │ ├─(1 i= 2)
      │ └─(2 i= 3)
      ├─(3 j= 10)
      │ ├─"test/test_expect_test.ml":2960:6
      │ ├─<while loop>
      │ ├─(1 i= 3)
      │ └─(2 i= 4)
      ├─(3 j= 15)
      │ ├─"test/test_expect_test.ml":2960:6
      │ ├─<while loop>
      │ ├─(1 i= 4)
      │ └─(2 i= 5)
      └─(3 j= 21)
        ├─"test/test_expect_test.ml":2960:6
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
  (* Orphaned logs are often prevented by the typechecker complaining about missing
     __entry_id. But they can happen with closures and other complex ways to interleave
     uses of a runtime. *)
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
    "test/test_expect_test.ml":3019:17: _bar {#1}
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
    └─[3; 1; 2; 3]
    |}]

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
    └─"test/test_expect_test.ml":3054:17 {#1}
    ("This is like", 3, "or", 3.14, "above")
    └─{orphaned from #1}
    ("tau =", 6.28)
    └─{orphaned from #1}
    [4; 1; 2; 3]
    └─{orphaned from #1}
    [3; 1; 2; 3]
    └─{orphaned from #1}
    [3; 1; 2; 3]
    └─{orphaned from #1}
    |}]

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
    └─"test/test_expect_test.ml":3091:21 {#1}
    baz = ()
    └─"test/test_expect_test.ml":3098:21 {#2}
    bar = ()
    └─"test/test_expect_test.ml":3091:21 {#3}
    _foobar = ()
    ├─"test/test_expect_test.ml":3110:17 {#4}
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
    └─{orphaned from #1}
    |}]

let%expect_test "%log with print_entry_ids, verbose_entry_ids in HTML, values_first_mode"
    =
  let module Debug_runtime =
    (val Minidebug_runtime.debug ~print_entry_ids:true ~verbose_entry_ids:true
           ~values_first_mode:true ())
  in
  Debug_runtime.config.backend <- `Html PrintBox_html.Config.default;
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
    <div><div><table class="non-framed"><tr><td><a id="1"></a></td><td><pre style="font-family: monospace">{#1} bar = ()</pre></td></tr></table><ul><li><table class="non-framed"><tr><td><div>&quot;test/test_expect_test.ml&quot;:3152:21</div></td><td><div><a href="#1"><div>{#1}</div></a></div></td></tr></table></li></ul></div></div>

    <div><div><table class="non-framed"><tr><td><a id="2"></a></td><td><pre style="font-family: monospace">{#2} baz = ()</pre></td></tr></table><ul><li><table class="non-framed"><tr><td><div>&quot;test/test_expect_test.ml&quot;:3159:21</div></td><td><div><a href="#2"><div>{#2}</div></a></div></td></tr></table></li></ul></div></div>

    <div><div><table class="non-framed"><tr><td><a id="3"></a></td><td><pre style="font-family: monospace">{#3} bar = ()</pre></td></tr></table><ul><li><table class="non-framed"><tr><td><div>&quot;test/test_expect_test.ml&quot;:3152:21</div></td><td><div><a href="#3"><div>{#3}</div></a></div></td></tr></table></li></ul></div></div>

    <div><div><table class="non-framed"><tr><td><a id="4"></a></td><td><pre style="font-family: monospace">{#4} _foobar = ()</pre></td></tr></table><ul><li><table class="non-framed"><tr><td><div>&quot;test/test_expect_test.ml&quot;:3171:17</div></td><td><div><a href="#4"><div>{#4}</div></a></div></td></tr></table></li><li><pre style="font-family: monospace">{#3} (&quot;This is like&quot;, 3, &quot;or&quot;, 3.14, &quot;above&quot;)</pre></li><li><pre style="font-family: monospace">{#3} (&quot;tau =&quot;, 6.28)</pre></li><li><pre style="font-family: monospace">{#2} [3; 1; 2; 3]</pre></li><li><pre style="font-family: monospace">{#2} [3; 1; 2; 3]</pre></li><li><pre style="font-family: monospace">{#1} (&quot;This is like&quot;, 3, &quot;or&quot;, 3.14, &quot;above&quot;)</pre></li><li><pre style="font-family: monospace">{#1} (&quot;tau =&quot;, 6.28)</pre></li></ul></div></div>

    <div><div><table class="non-framed"><tr><td><div></div></td><td><pre style="font-family: monospace">{#2} [3; 1; 2; 3]</pre></td></tr></table><ul><li><div>{orphaned from #2}</div></li></ul></div></div>

    <div><div><table class="non-framed"><tr><td><div></div></td><td><pre style="font-family: monospace">{#2} [3; 1; 2; 3]</pre></td></tr></table><ul><li><div>{orphaned from #2}</div></li></ul></div></div>

    <div><div><table class="non-framed"><tr><td><div></div></td><td><pre style="font-family: monospace">{#1} (&quot;This is like&quot;, 3, &quot;or&quot;, 3.14, &quot;above&quot;)</pre></td></tr></table><ul><li><div>{orphaned from #1}</div></li></ul></div></div>

    <div><div><table class="non-framed"><tr><td><div></div></td><td><pre style="font-family: monospace">{#1} (&quot;tau =&quot;, 6.28)</pre></td></tr></table><ul><li><div>{orphaned from #1}</div></li></ul></div></div>
    |}]

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
    ├─"test/test_expect_test.ml":3195:17
    ├─("for bar, b-3", 42)
    └─("for baz, f squared", 64)
    |}]

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
    ├─"test/test_expect_test.ml":3224:21
    └─("for bar, b-3", 42)
    336
    baz
    ├─"test/test_expect_test.ml":3231:21
    └─("foo baz, f squared", 49)
    91
    |}]

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
    91
    |}]

let%expect_test "%debug_show log level compile time" =
  let module Debug_runtime = (val Minidebug_runtime.debug ~values_first_mode:true ()) in
  let%debug3_show () =
    [%log_level
      2;
      let foo { first : int; second : int } : int =
        let { first : int = a; second : int = b } = { first; second = second + 3 } in
        let y : int = a + 1 in
        [%log "for foo, b-3", (b - 3 : int)];
        (b - 3) * y
      in
      let bar { first : int; second : int } : int =
        let { first : int = a; second : int = b } = { first; second = second + 3 } in
        let y : int = a + 1 in
        [%log1 "for bar, b-3", (b - 3 : int)];
        (b - 3) * y
      in
      (* FIXME: _ is broken, once we get rid of it swap the order of baz and bar to
         verify. *)
      let%debug2_show baz { first : int; second : int } : int =
        let { first : int; second : int } = { first = first + 1; second = second + 3 } in
        [%log "for baz, f squared", (first * first : int)];
        (first * first) + second
      in
      print_endline @@ Int.to_string @@ foo { first = 7; second = 42 };
      print_endline @@ Int.to_string @@ bar { first = 7; second = 42 };
      print_endline @@ Int.to_string @@ baz { first = 7; second = 42 }]
  in
  [%expect
    {|
    BEGIN DEBUG SESSION
    336
    336
    109
    ()
    ├─"test/test_expect_test.ml":3273:18
    ├─bar
    │ ├─"test/test_expect_test.ml":3282:14
    │ └─("for bar, b-3", 42)
    └─baz = 109
      ├─"test/test_expect_test.ml":3290:26
      ├─first = 7
      ├─second = 42
      ├─{first; second}
      │ ├─"test/test_expect_test.ml":3291:12
      │ └─<values>
      │   ├─first = 8
      │   └─second = 45
      └─("for baz, f squared", 64)
    |}]

let%expect_test "%debug_show log level runtime" =
  let module Debug_runtime =
    (val Minidebug_runtime.debug ~values_first_mode:true ~log_level:2 ())
  in
  let%debug3_show () =
    let foo { first : int; second : int } : int =
      let { first : int = a; second : int = b } = { first; second = second + 3 } in
      let y : int = a + 1 in
      [%log "for foo, b-3", (b - 3 : int)];
      (b - 3) * y
    in
    let bar { first : int; second : int } : int =
      let { first : int = a; second : int = b } = { first; second = second + 3 } in
      let y : int = a + 1 in
      [%log1 "for bar, b-3", (b - 3 : int)];
      (b - 3) * y
    in
    (* FIXME: _ is broken, once we get rid of it swap the order of baz and bar to
       verify. *)
    let%debug2_show baz { first : int; second : int } : int =
      let { first : int; second : int } = { first = first + 1; second = second + 3 } in
      [%log "for baz, f squared", (first * first : int)];
      (first * first) + second
    in
    print_endline @@ Int.to_string @@ foo { first = 7; second = 42 };
    print_endline @@ Int.to_string @@ bar { first = 7; second = 42 };
    print_endline @@ Int.to_string @@ baz { first = 7; second = 42 }
  in
  [%expect
    {|
    BEGIN DEBUG SESSION
    336
    ("for bar, b-3", 42)
    └─{orphaned from #5}
    336
    baz = 109
    ├─"test/test_expect_test.ml":3341:24
    ├─first = 7
    ├─second = 42
    ├─{first; second}
    │ ├─"test/test_expect_test.ml":3342:10
    │ └─<values>
    │   ├─first = 8
    │   └─second = 45
    └─("for baz, f squared", 64)
    109
    |}]

let%expect_test "%debug_show PrintBox snapshot" =
  let module Debug_runtime = (val Minidebug_runtime.debug ~values_first_mode:true ()) in
  let%debug_show rec loop_highlight (x : int) : int =
    let z : int = (x - 1) / 2 in
    if z = 3 || x = 3 then Debug_runtime.snapshot ();
    if x <= 0 then 0 else z + loop_highlight (z + (x / 2))
  in
  print_endline @@ Int.to_string @@ loop_highlight 7;
  [%expect
    {|
    BEGIN DEBUG SESSION
    loop_highlight
    ├─"test/test_expect_test.ml":3372:36
    ├─x = 7
    └─z = 3
      └─"test/test_expect_test.ml":3373:8
    [2J[1;1Hloop_highlight
    ├─"test/test_expect_test.ml":3372:36
    ├─x = 7
    ├─z = 3
    │ └─"test/test_expect_test.ml":3373:8
    └─loop_highlight
      ├─"test/test_expect_test.ml":3372:36
      ├─x = 6
      ├─z = 2
      │ └─"test/test_expect_test.ml":3373:8
      └─loop_highlight
        ├─"test/test_expect_test.ml":3372:36
        ├─x = 5
        ├─z = 2
        │ └─"test/test_expect_test.ml":3373:8
        └─loop_highlight
          ├─"test/test_expect_test.ml":3372:36
          ├─x = 4
          ├─z = 1
          │ └─"test/test_expect_test.ml":3373:8
          └─loop_highlight
            ├─"test/test_expect_test.ml":3372:36
            ├─x = 3
            └─z = 1
              └─"test/test_expect_test.ml":3373:8
    [2J[1;1Hloop_highlight = 9
    ├─"test/test_expect_test.ml":3372:36
    ├─x = 7
    ├─z = 3
    │ └─"test/test_expect_test.ml":3373:8
    └─loop_highlight = 6
      ├─"test/test_expect_test.ml":3372:36
      ├─x = 6
      ├─z = 2
      │ └─"test/test_expect_test.ml":3373:8
      └─loop_highlight = 4
        ├─"test/test_expect_test.ml":3372:36
        ├─x = 5
        ├─z = 2
        │ └─"test/test_expect_test.ml":3373:8
        └─loop_highlight = 2
          ├─"test/test_expect_test.ml":3372:36
          ├─x = 4
          ├─z = 1
          │ └─"test/test_expect_test.ml":3373:8
          └─loop_highlight = 1
            ├─"test/test_expect_test.ml":3372:36
            ├─x = 3
            ├─z = 1
            │ └─"test/test_expect_test.ml":3373:8
            └─loop_highlight = 0
              ├─"test/test_expect_test.ml":3372:36
              ├─x = 2
              ├─z = 0
              │ └─"test/test_expect_test.ml":3373:8
              └─loop_highlight = 0
                ├─"test/test_expect_test.ml":3372:36
                ├─x = 1
                ├─z = 0
                │ └─"test/test_expect_test.ml":3373:8
                └─loop_highlight = 0
                  ├─"test/test_expect_test.ml":3372:36
                  ├─x = 0
                  └─z = 0
                    └─"test/test_expect_test.ml":3373:8
    9
    |}]

let%expect_test "%track_show don't show unannotated non-function bindings" =
  let module Debug_runtime =
    (val Minidebug_runtime.debug ~values_first_mode:true ~log_level:3 ())
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
    ├─"test/test_expect_test.ml":3472:21
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
      └───┴───┴───┴───┴───┘
    |}]

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
    foo begin "test/test_expect_test.ml":3534:21:
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
     bar begin "test/test_expect_test.ml":3543:12:
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
    foo end
    |}]

let%expect_test "%log_entry" =
  let module Debug_runtime = (val Minidebug_runtime.debug ()) in
  let%diagn_show _logging_logic : unit =
    let rec loop logs =
      match logs with
      | "start" :: header :: tl ->
          let more =
            [%log_entry
              header;
              loop tl]
          in
          loop more
      | "end" :: tl -> tl
      | msg :: tl ->
          [%log msg];
          loop tl
      | [] -> []
    in
    ignore
    @@ loop
         [
           "preamble";
           "start";
           "header 1";
           "log 1";
           "start";
           "nested header";
           "log 2";
           "end";
           "log 3";
           "end";
           "start";
           "header 2";
           "log 4";
           "end";
           "postscript";
         ]
  in
  [%expect
    {|
      BEGIN DEBUG SESSION
      "test/test_expect_test.ml":3603:17: _logging_logic
      ├─"preamble"
      ├─header 1
      │ ├─"log 1"
      │ ├─nested header
      │ │ └─"log 2"
      │ └─"log 3"
      ├─header 2
      │ └─"log 4"
      └─"postscript"
      |}]

let%expect_test "flame graph" =
  let module Debug_runtime =
    (val Minidebug_runtime.debug_file ~hyperlink:"../" ~toc_specific_hyperlink:"./"
           ~toc_flame_graph:true
           ~backend:(`Html PrintBox_html.Config.(tree_summary true default))
           "test_expect_test_flame_graph")
  in
  let%debug_show rec loop (depth : int) (x : t) : int =
    if depth > 4 then x.first + x.second
    else if depth > 1 then loop (depth + 1) { first = x.second + 1; second = x.first / 2 }
    else
      let y : int = loop (depth + 1) { first = x.second - 1; second = x.first + 2 } in
      let z : int = loop (depth + 1) { first = x.second + 1; second = y } in
      z + 7
  in
  let () = ignore @@ loop 0 { first = 7; second = 42 } in
  let file = open_in "test_expect_test_flame_graph-toc.html" in
  (try
     while true do
       print_endline @@ input_line file
     done
   with End_of_file -> ());
  close_in file;
  let output = [%expect.output] in
  let output = Str.global_replace (Str.regexp {|[0-9]+\.[0-9]*%|}) "N.NNNN%" output in
  print_endline output;
  [%expect
    {|
                    <div style="position: relative; height: 0px;"><div style="position: relative; top: 0%; width: 100%; height: 100%;"><div style="position: relative; top: 0px; left: 0px; width: 100%; background: #a3b8d2;"><div><div><a href="./test_expect_test_flame_graph.html#1"><div>&quot;test/test_expect_test.ml&quot;:3661:26: loop</div></a></div></div>
    </div><div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0%; width: 100%; height: 100%;"><div style="position: relative; top: 0px; left: 0px; width: 100%; background: #a7a1eb;"><div><div><a href="./test_expect_test_flame_graph.html#2"><div>&quot;test/test_expect_test.ml&quot;:3665:10: y</div></a></div></div>
    </div><div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0%; width: 100%; height: 100%;"><div style="position: relative; top: 0px; left: 0px; width: 100%; background: #b88f91;"><div><div><a href="./test_expect_test_flame_graph.html#3"><div>&quot;test/test_expect_test.ml&quot;:3661:26: loop</div></a></div></div>
    </div><div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0%; width: 100%; height: 100%;"><div style="position: relative; top: 0px; left: 0px; width: 100%; background: #bfadb3;"><div><div><a href="./test_expect_test_flame_graph.html#4"><div>&quot;test/test_expect_test.ml&quot;:3665:10: y</div></a></div></div>
    </div><div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0%; width: 100%; height: 100%;"><div style="position: relative; top: 0px; left: 0px; width: 100%; background: #c5c7ed;"><div><div><a href="./test_expect_test_flame_graph.html#5"><div>&quot;test/test_expect_test.ml&quot;:3661:26: loop</div></a></div></div>
    </div><div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0%; width: 100%; height: 100%;"><div style="position: relative; top: 0px; left: 0px; width: 100%; background: #ebdf9d;"><div><div><a href="./test_expect_test_flame_graph.html#6"><div>&quot;test/test_expect_test.ml&quot;:3661:26: loop</div></a></div></div>
    </div><div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0%; width: 100%; height: 100%;"><div style="position: relative; top: 0px; left: 0px; width: 100%; background: #bfbbe7;"><div><div><a href="./test_expect_test_flame_graph.html#7"><div>&quot;test/test_expect_test.ml&quot;:3661:26: loop</div></a></div></div>
    </div><div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0px; left: 0px; width: 100%; background: #ebebd3;"><div><div><a href="./test_expect_test_flame_graph.html#8"><div>&quot;test/test_expect_test.ml&quot;:3661:26: loop</div></a></div></div>
    </div></div>
           </div></div>
           </div></div>
           </div></div>
           </div></div>
           <div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0%; width: 100%; height: 100%;"><div style="position: relative; top: 0px; left: 0px; width: 100%; background: #9994b2;"><div><div><a href="./test_expect_test_flame_graph.html#9"><div>&quot;test/test_expect_test.ml&quot;:3666:10: z</div></a></div></div>
    </div><div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0%; width: 100%; height: 100%;"><div style="position: relative; top: 0px; left: 0px; width: 100%; background: #c4efdd;"><div><div><a href="./test_expect_test_flame_graph.html#10"><div>&quot;test/test_expect_test.ml&quot;:3661:26: loop</div></a></div></div>
    </div><div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0%; width: 100%; height: 100%;"><div style="position: relative; top: 0px; left: 0px; width: 100%; background: #d8eeca;"><div><div><a href="./test_expect_test_flame_graph.html#11"><div>&quot;test/test_expect_test.ml&quot;:3661:26: loop</div></a></div></div>
    </div><div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0%; width: 100%; height: 100%;"><div style="position: relative; top: 0px; left: 0px; width: 100%; background: #bea2e0;"><div><div><a href="./test_expect_test_flame_graph.html#12"><div>&quot;test/test_expect_test.ml&quot;:3661:26: loop</div></a></div></div>
    </div><div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0px; left: 0px; width: 100%; background: #9192c4;"><div><div><a href="./test_expect_test_flame_graph.html#13"><div>&quot;test/test_expect_test.ml&quot;:3661:26: loop</div></a></div></div>
    </div></div>
           </div></div>
           </div></div>
           </div></div>
           </div></div>
           </div></div>
           </div></div>
           <div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0%; width: 100%; height: 100%;"><div style="position: relative; top: 0px; left: 0px; width: 100%; background: #bb8f91;"><div><div><a href="./test_expect_test_flame_graph.html#14"><div>&quot;test/test_expect_test.ml&quot;:3666:10: z</div></a></div></div>
    </div><div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0%; width: 100%; height: 100%;"><div style="position: relative; top: 0px; left: 0px; width: 100%; background: #bd8fef;"><div><div><a href="./test_expect_test_flame_graph.html#15"><div>&quot;test/test_expect_test.ml&quot;:3661:26: loop</div></a></div></div>
    </div><div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0%; width: 100%; height: 100%;"><div style="position: relative; top: 0px; left: 0px; width: 100%; background: #d7decc;"><div><div><a href="./test_expect_test_flame_graph.html#16"><div>&quot;test/test_expect_test.ml&quot;:3665:10: y</div></a></div></div>
    </div><div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0%; width: 100%; height: 100%;"><div style="position: relative; top: 0px; left: 0px; width: 100%; background: #9fbbbd;"><div><div><a href="./test_expect_test_flame_graph.html#17"><div>&quot;test/test_expect_test.ml&quot;:3661:26: loop</div></a></div></div>
    </div><div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0%; width: 100%; height: 100%;"><div style="position: relative; top: 0px; left: 0px; width: 100%; background: #e2e7d3;"><div><div><a href="./test_expect_test_flame_graph.html#18"><div>&quot;test/test_expect_test.ml&quot;:3661:26: loop</div></a></div></div>
    </div><div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0%; width: 100%; height: 100%;"><div style="position: relative; top: 0px; left: 0px; width: 100%; background: #a0b0f0;"><div><div><a href="./test_expect_test_flame_graph.html#19"><div>&quot;test/test_expect_test.ml&quot;:3661:26: loop</div></a></div></div>
    </div><div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0px; left: 0px; width: 100%; background: #a39abc;"><div><div><a href="./test_expect_test_flame_graph.html#20"><div>&quot;test/test_expect_test.ml&quot;:3661:26: loop</div></a></div></div>
    </div></div>
           </div></div>
           </div></div>
           </div></div>
           </div></div>
           <div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0%; width: 100%; height: 100%;"><div style="position: relative; top: 0px; left: 0px; width: 100%; background: #b1a1b5;"><div><div><a href="./test_expect_test_flame_graph.html#21"><div>&quot;test/test_expect_test.ml&quot;:3666:10: z</div></a></div></div>
    </div><div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0%; width: 100%; height: 100%;"><div style="position: relative; top: 0px; left: 0px; width: 100%; background: #d7efa5;"><div><div><a href="./test_expect_test_flame_graph.html#22"><div>&quot;test/test_expect_test.ml&quot;:3661:26: loop</div></a></div></div>
    </div><div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0%; width: 100%; height: 100%;"><div style="position: relative; top: 0px; left: 0px; width: 100%; background: #f1e7a3;"><div><div><a href="./test_expect_test_flame_graph.html#23"><div>&quot;test/test_expect_test.ml&quot;:3661:26: loop</div></a></div></div>
    </div><div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0%; width: 100%; height: 100%;"><div style="position: relative; top: 0px; left: 0px; width: 100%; background: #9295dd;"><div><div><a href="./test_expect_test_flame_graph.html#24"><div>&quot;test/test_expect_test.ml&quot;:3661:26: loop</div></a></div></div>
    </div><div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0px; left: 0px; width: 100%; background: #d6dcaa;"><div><div><a href="./test_expect_test_flame_graph.html#25"><div>&quot;test/test_expect_test.ml&quot;:3661:26: loop</div></a></div></div>
    </div></div>
           </div></div>
           </div></div>
           </div></div>
           </div></div>
           </div></div>
           </div></div>
           </div></div><div style="height: 320px;"></div>
    |}]

let%expect_test "flame graph reduced ToC" =
  let module Debug_runtime =
    (val Minidebug_runtime.debug_file ~hyperlink:"../" ~toc_specific_hyperlink:"./"
           ~toc_flame_graph:true ~toc_entry:(Minidebug_runtime.Minimal_depth 1)
           ~backend:(`Html PrintBox_html.Config.(tree_summary true default))
           "test_expect_test_flame_graph")
  in
  let%debug_show rec loop (depth : int) (x : t) : int =
    if depth > 4 then x.first + x.second
    else if depth > 1 then loop (depth + 1) { first = x.second + 1; second = x.first / 2 }
    else
      let y : int = loop (depth + 1) { first = x.second - 1; second = x.first + 2 } in
      let z : int = loop (depth + 1) { first = x.second + 1; second = y } in
      z + 7
  in
  let () = ignore @@ loop 0 { first = 7; second = 42 } in
  let file = open_in "test_expect_test_flame_graph-toc.html" in
  (try
     while true do
       print_endline @@ input_line file
     done
   with End_of_file -> ());
  close_in file;
  let output = [%expect.output] in
  let output = Str.global_replace (Str.regexp {|[0-9]+\.[0-9]*%|}) "N.NNNN%" output in
  print_endline output;
  [%expect
    {|
                    <div style="position: relative; height: 0px;"><div style="position: relative; top: 0%; width: 100%; height: 100%;"><div style="position: relative; top: 0px; left: 0px; width: 100%; background: #d7efa5;"><div><div><a href="./test_expect_test_flame_graph.html#1"><div>&quot;test/test_expect_test.ml&quot;:3765:26: loop</div></a></div></div>
    </div><div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0%; width: 100%; height: 100%;"><div style="position: relative; top: 0px; left: 0px; width: 100%; background: #9994b2;"><div><div><a href="./test_expect_test_flame_graph.html#2"><div>&quot;test/test_expect_test.ml&quot;:3769:10: y</div></a></div></div>
    </div><div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0%; width: 100%; height: 100%;"><div style="position: relative; top: 0px; left: 0px; width: 100%; background: #c4efdd;"><div><div><a href="./test_expect_test_flame_graph.html#3"><div>&quot;test/test_expect_test.ml&quot;:3765:26: loop</div></a></div></div>
    </div><div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0%; width: 100%; height: 100%;"><div style="position: relative; top: 0px; left: 0px; width: 100%; background: #c5c7ed;"><div><div><a href="./test_expect_test_flame_graph.html#4"><div>&quot;test/test_expect_test.ml&quot;:3769:10: y</div></a></div></div>
    </div><div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0%; width: 100%; height: 100%;"><div style="position: relative; top: 0px; left: 0px; width: 100%; background: #ebdf9d;"><div><div><a href="./test_expect_test_flame_graph.html#5"><div>&quot;test/test_expect_test.ml&quot;:3765:26: loop</div></a></div></div>
    </div><div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0%; width: 100%; height: 100%;"><div style="position: relative; top: 0px; left: 0px; width: 100%; background: #bfbbe7;"><div><div><a href="./test_expect_test_flame_graph.html#6"><div>&quot;test/test_expect_test.ml&quot;:3765:26: loop</div></a></div></div>
    </div><div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0px; left: 0px; width: 100%; background: #ebebd3;"><div><div><a href="./test_expect_test_flame_graph.html#7"><div>&quot;test/test_expect_test.ml&quot;:3765:26: loop</div></a></div></div>
    </div></div>
           </div></div>
           </div></div>
           </div></div>
           <div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0%; width: 100%; height: 100%;"><div style="position: relative; top: 0px; left: 0px; width: 100%; background: #d8eeca;"><div><div><a href="./test_expect_test_flame_graph.html#9"><div>&quot;test/test_expect_test.ml&quot;:3770:10: z</div></a></div></div>
    </div><div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0%; width: 100%; height: 100%;"><div style="position: relative; top: 0px; left: 0px; width: 100%; background: #bea2e0;"><div><div><a href="./test_expect_test_flame_graph.html#10"><div>&quot;test/test_expect_test.ml&quot;:3765:26: loop</div></a></div></div>
    </div><div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0%; width: 100%; height: 100%;"><div style="position: relative; top: 0px; left: 0px; width: 100%; background: #9192c4;"><div><div><a href="./test_expect_test_flame_graph.html#11"><div>&quot;test/test_expect_test.ml&quot;:3765:26: loop</div></a></div></div>
    </div><div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0px; left: 0px; width: 100%; background: #bfadb3;"><div><div><a href="./test_expect_test_flame_graph.html#12"><div>&quot;test/test_expect_test.ml&quot;:3765:26: loop</div></a></div></div>
    </div></div>
           </div></div>
           </div></div>
           </div></div>
           </div></div>
           </div></div>
           <div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0%; width: 100%; height: 100%;"><div style="position: relative; top: 0px; left: 0px; width: 100%; background: #f1e7a3;"><div><div><a href="./test_expect_test_flame_graph.html#14"><div>&quot;test/test_expect_test.ml&quot;:3770:10: z</div></a></div></div>
    </div><div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0%; width: 100%; height: 100%;"><div style="position: relative; top: 0px; left: 0px; width: 100%; background: #9295dd;"><div><div><a href="./test_expect_test_flame_graph.html#15"><div>&quot;test/test_expect_test.ml&quot;:3765:26: loop</div></a></div></div>
    </div><div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0%; width: 100%; height: 100%;"><div style="position: relative; top: 0px; left: 0px; width: 100%; background: #a0b0f0;"><div><div><a href="./test_expect_test_flame_graph.html#16"><div>&quot;test/test_expect_test.ml&quot;:3769:10: y</div></a></div></div>
    </div><div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0%; width: 100%; height: 100%;"><div style="position: relative; top: 0px; left: 0px; width: 100%; background: #a39abc;"><div><div><a href="./test_expect_test_flame_graph.html#17"><div>&quot;test/test_expect_test.ml&quot;:3765:26: loop</div></a></div></div>
    </div><div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0%; width: 100%; height: 100%;"><div style="position: relative; top: 0px; left: 0px; width: 100%; background: #a7a1eb;"><div><div><a href="./test_expect_test_flame_graph.html#18"><div>&quot;test/test_expect_test.ml&quot;:3765:26: loop</div></a></div></div>
    </div><div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0px; left: 0px; width: 100%; background: #b88f91;"><div><div><a href="./test_expect_test_flame_graph.html#19"><div>&quot;test/test_expect_test.ml&quot;:3765:26: loop</div></a></div></div>
    </div></div>
           </div></div>
           </div></div>
           </div></div>
           <div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0%; width: 100%; height: 100%;"><div style="position: relative; top: 0px; left: 0px; width: 100%; background: #d6dcaa;"><div><div><a href="./test_expect_test_flame_graph.html#21"><div>&quot;test/test_expect_test.ml&quot;:3770:10: z</div></a></div></div>
    </div><div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0%; width: 100%; height: 100%;"><div style="position: relative; top: 0px; left: 0px; width: 100%; background: #d7decc;"><div><div><a href="./test_expect_test_flame_graph.html#22"><div>&quot;test/test_expect_test.ml&quot;:3765:26: loop</div></a></div></div>
    </div><div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0%; width: 100%; height: 100%;"><div style="position: relative; top: 0px; left: 0px; width: 100%; background: #9fbbbd;"><div><div><a href="./test_expect_test_flame_graph.html#23"><div>&quot;test/test_expect_test.ml&quot;:3765:26: loop</div></a></div></div>
    </div><div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0px; left: 0px; width: 100%; background: #e2e7d3;"><div><div><a href="./test_expect_test_flame_graph.html#24"><div>&quot;test/test_expect_test.ml&quot;:3765:26: loop</div></a></div></div>
    </div></div>
           </div></div>
           </div></div>
           </div></div>
           </div></div>
           </div></div>
           </div></div><div style="height: 280px;"></div>
    |}]

let%expect_test "%debug_show skip module bindings" =
  let optional v thunk = match v with Some v -> v | None -> thunk () in
  let module Debug_runtime = (val Minidebug_runtime.debug ~values_first_mode:true ()) in
  let%track_sexp bar ?(rt : (module Minidebug_runtime.Debug_runtime) option) (x : int) :
      int =
    let y : int = x + 1 in
    let module Debug_runtime =
      (val optional rt (fun () ->
               (module Debug_runtime : Minidebug_runtime.Debug_runtime)))
    in
    let z = y * 2 in
    z - 1
  in
  let () = print_endline @@ Int.to_string @@ bar ~rt:(module Debug_runtime) 7 in
  [%expect
    {|
    BEGIN DEBUG SESSION
    bar = 15
    ├─"test/test_expect_test.ml":3853:21
    ├─x = 7
    └─y = 8
      └─"test/test_expect_test.ml":3855:8
    15
    |}]

let%expect_test "%track_l_show procedure runtime passing" =
  let i = ref 0 in
  let _get_local_debug_runtime () =
    Minidebug_runtime.debug_flushing ~global_prefix:("foo-" ^ string_of_int !i) ()
  in
  let%track_l_show foo () =
    let () = () in
    [%log "inside foo"]
  in
  let%track_l_show bar = function
    | () ->
        let () = () in
        [%log "inside bar"]
  in
  while !i < 5 do
    incr i;
    foo ();
    bar ()
  done;
  [%expect
    {|
    BEGIN DEBUG SESSION foo-1
    foo-1 foo begin "test/test_expect_test.ml":3880:23:
     "inside foo"
    foo-1 foo end

    BEGIN DEBUG SESSION foo-1
    foo-1 <function -- branch 0> () begin "test/test_expect_test.ml":3886:8:
     "inside bar"
    foo-1 <function -- branch 0> () end

    BEGIN DEBUG SESSION foo-2
    foo-2 foo begin "test/test_expect_test.ml":3880:23:
     "inside foo"
    foo-2 foo end

    BEGIN DEBUG SESSION foo-2
    foo-2 <function -- branch 0> () begin "test/test_expect_test.ml":3886:8:
     "inside bar"
    foo-2 <function -- branch 0> () end

    BEGIN DEBUG SESSION foo-3
    foo-3 foo begin "test/test_expect_test.ml":3880:23:
     "inside foo"
    foo-3 foo end

    BEGIN DEBUG SESSION foo-3
    foo-3 <function -- branch 0> () begin "test/test_expect_test.ml":3886:8:
     "inside bar"
    foo-3 <function -- branch 0> () end

    BEGIN DEBUG SESSION foo-4
    foo-4 foo begin "test/test_expect_test.ml":3880:23:
     "inside foo"
    foo-4 foo end

    BEGIN DEBUG SESSION foo-4
    foo-4 <function -- branch 0> () begin "test/test_expect_test.ml":3886:8:
     "inside bar"
    foo-4 <function -- branch 0> () end

    BEGIN DEBUG SESSION foo-5
    foo-5 foo begin "test/test_expect_test.ml":3880:23:
     "inside foo"
    foo-5 foo end

    BEGIN DEBUG SESSION foo-5
    foo-5 <function -- branch 0> () begin "test/test_expect_test.ml":3886:8:
     "inside bar"
    foo-5 <function -- branch 0> () end
    |}]

let%expect_test "%track_rt_show expression runtime passing" =
  [%track_rt_show
    [%log_block
      "test A";
      [%log "line A"]]]
    (Minidebug_runtime.debug_flushing ~global_prefix:"t1" ());
  [%track_rt_show
    [%log_block
      "test B";
      [%log "line B"]]]
    (Minidebug_runtime.debug_flushing ~global_prefix:"t2" ());
  [%track_rt_show
    [%log_block
      "test C";
      [%log "line C"]]]
    Minidebug_runtime.(forget_printbox @@ debug ~global_prefix:"t3" ~log_level:0 ());
  [%expect
    {|
    BEGIN DEBUG SESSION t1
    t1 test A begin
     "line A"
    t1 test A end

    BEGIN DEBUG SESSION t2
    t2 test B begin
     "line B"
    t2 test B end

    BEGIN DEBUG SESSION t3 |}]

let%expect_test "%debug_show tuples values_first_mode highlighted" =
  let module Debug_runtime =
    (val Minidebug_runtime.debug
           ~highlight_terms:Re.(alt [ str "339"; str "8" ])
           ~values_first_mode:true ())
  in
  let%debug_show bar ((first : int), (second : int)) : int =
    let y : int = first + 1 in
    second * y
  in
  let () = print_endline @@ Int.to_string @@ bar (7, 42) in
  let%debug_show baz ((first, second) : int * int) : int * int =
    let (y, z) : int * int = (first + 1, 3) in
    let (a : int), (b : int) = (first + 1, second + 3) in
    ((second * y) + z, (a * a) + b)
  in
  let%debug_show r1, r2 = (baz (7, 42) : int * int) in
  let () = print_endline @@ Int.to_string r1 in
  let () = print_endline @@ Int.to_string r2 in
  [%expect
    {|
    BEGIN DEBUG SESSION
    ┌─────────┐
    │bar = 336│
    ├─────────┘
    ├─"test/test_expect_test.ml":3983:21
    ├─first = 7
    ├─second = 42
    └─┬─────┐
      │y = 8│
      ├─────┘
      └─"test/test_expect_test.ml":3984:8
    336
    ┌────────┐
    │(r1, r2)│
    ├────────┘
    ├─"test/test_expect_test.ml":3993:17
    ├─┬─────────┐
    │ │<returns>│
    │ ├─────────┘
    │ ├─┬────────┐
    │ │ │r1 = 339│
    │ │ └────────┘
    │ └─r2 = 109
    └─┬────────────────┐
      │baz = (339, 109)│
      ├────────────────┘
      ├─"test/test_expect_test.ml":3988:21
      ├─first = 7
      ├─second = 42
      ├─┬──────┐
      │ │(y, z)│
      │ ├──────┘
      │ ├─"test/test_expect_test.ml":3989:8
      │ └─┬────────┐
      │   │<values>│
      │   ├────────┘
      │   ├─┬─────┐
      │   │ │y = 8│
      │   │ └─────┘
      │   └─z = 3
      └─┬──────┐
        │(a, b)│
        ├──────┘
        ├─"test/test_expect_test.ml":3990:8
        └─┬────────┐
          │<values>│
          ├────────┘
          ├─┬─────┐
          │ │a = 8│
          │ └─────┘
          └─b = 45
    339
    109
    |}]

let%expect_test "%logN_block runtime log levels" =
  let%track_rt_sexp result ~for_log_level : int =
    let i = ref 0 in
    let j = ref 0 in
    while !i < 6 do
      incr i;
      [%logN_block
        for_log_level ("i=" ^ string_of_int !i);
        if !i < 3 then [%log "ERROR:", 1, "i=", (!i : int)] else ();
        [%log "WARNING:", 2, "i=", (!i : int)];
        j := (fun { contents } -> !j + contents) i;
        [%log3 "INFO:", 3, "j=", (!j : int)]]
    done;
    !j
  in
  print_endline
  @@ Int.to_string
       (result
          Minidebug_runtime.(
            forget_printbox @@ debug ~global_prefix:"for=2,with=default" ())
          ~for_log_level:2);
  print_endline
  @@ Int.to_string
       (result
          Minidebug_runtime.(
            forget_printbox
            @@ debug ~values_first_mode:true ~log_level:0 ~global_prefix:"for=1,with=0" ())
          ~for_log_level:1);
  print_endline
  @@ Int.to_string
       (result
          Minidebug_runtime.(
            forget_printbox
            @@ debug ~values_first_mode:true ~log_level:1 ~global_prefix:"for=2,with=1" ())
          ~for_log_level:2);
  print_endline
  @@ Int.to_string
       (result
          Minidebug_runtime.(
            forget_printbox
            @@ debug ~values_first_mode:true ~log_level:2 ~global_prefix:"for=1,with=2" ())
          ~for_log_level:1);
  print_endline
  @@ Int.to_string
       (result
          Minidebug_runtime.(
            forget_printbox
            @@ debug ~values_first_mode:true ~log_level:3 ~global_prefix:"for=3,with=3" ())
          ~for_log_level:3);
  (* Unlike with other constructs, INFO should not be printed in "for=4,with=3", because
     log_block filters out the whole body by the log level. *)
  print_endline
  @@ Int.to_string
       (result
          Minidebug_runtime.(
            forget_printbox
            @@ debug ~values_first_mode:true ~log_level:3 ~global_prefix:"for=4,with=3" ())
          ~for_log_level:4);
  [%expect
    {|
    BEGIN DEBUG SESSION for=2,with=default
    "test/test_expect_test.ml":4054:27: for=2,with=default result
    ├─"test/test_expect_test.ml":4057:4: for=2,with=default while:test_expect_test:4057
    │ ├─"test/test_expect_test.ml":4058:6: for=2,with=default <while loop>
    │ │ └─for=2,with=default i=1
    │ │   ├─"test/test_expect_test.ml":4061:23: for=2,with=default then:test_expect_test:4061
    │ │   │ └─(ERROR: 1 i= 1)
    │ │   ├─(WARNING: 2 i= 1)
    │ │   ├─"test/test_expect_test.ml":4063:13: for=2,with=default fun:test_expect_test:4063
    │ │   └─(INFO: 3 j= 1)
    │ ├─"test/test_expect_test.ml":4058:6: for=2,with=default <while loop>
    │ │ └─for=2,with=default i=2
    │ │   ├─"test/test_expect_test.ml":4061:23: for=2,with=default then:test_expect_test:4061
    │ │   │ └─(ERROR: 1 i= 2)
    │ │   ├─(WARNING: 2 i= 2)
    │ │   ├─"test/test_expect_test.ml":4063:13: for=2,with=default fun:test_expect_test:4063
    │ │   └─(INFO: 3 j= 3)
    │ ├─"test/test_expect_test.ml":4058:6: for=2,with=default <while loop>
    │ │ └─for=2,with=default i=3
    │ │   ├─"test/test_expect_test.ml":4061:65: for=2,with=default else:test_expect_test:4061
    │ │   ├─(WARNING: 2 i= 3)
    │ │   ├─"test/test_expect_test.ml":4063:13: for=2,with=default fun:test_expect_test:4063
    │ │   └─(INFO: 3 j= 6)
    │ ├─"test/test_expect_test.ml":4058:6: for=2,with=default <while loop>
    │ │ └─for=2,with=default i=4
    │ │   ├─"test/test_expect_test.ml":4061:65: for=2,with=default else:test_expect_test:4061
    │ │   ├─(WARNING: 2 i= 4)
    │ │   ├─"test/test_expect_test.ml":4063:13: for=2,with=default fun:test_expect_test:4063
    │ │   └─(INFO: 3 j= 10)
    │ ├─"test/test_expect_test.ml":4058:6: for=2,with=default <while loop>
    │ │ └─for=2,with=default i=5
    │ │   ├─"test/test_expect_test.ml":4061:65: for=2,with=default else:test_expect_test:4061
    │ │   ├─(WARNING: 2 i= 5)
    │ │   ├─"test/test_expect_test.ml":4063:13: for=2,with=default fun:test_expect_test:4063
    │ │   └─(INFO: 3 j= 15)
    │ └─"test/test_expect_test.ml":4058:6: for=2,with=default <while loop>
    │   └─for=2,with=default i=6
    │     ├─"test/test_expect_test.ml":4061:65: for=2,with=default else:test_expect_test:4061
    │     ├─(WARNING: 2 i= 6)
    │     ├─"test/test_expect_test.ml":4063:13: for=2,with=default fun:test_expect_test:4063
    │     └─(INFO: 3 j= 21)
    └─result = 21
    21

    BEGIN DEBUG SESSION for=1,with=0
    0

    BEGIN DEBUG SESSION for=2,with=1
    result = 0
    ├─"test/test_expect_test.ml":4054:27
    ├─for=2,with=1 result
    └─for=2,with=1 while:test_expect_test:4057
      ├─"test/test_expect_test.ml":4057:4
      ├─for=2,with=1 <while loop>
      │ └─"test/test_expect_test.ml":4058:6
      ├─for=2,with=1 <while loop>
      │ └─"test/test_expect_test.ml":4058:6
      ├─for=2,with=1 <while loop>
      │ └─"test/test_expect_test.ml":4058:6
      ├─for=2,with=1 <while loop>
      │ └─"test/test_expect_test.ml":4058:6
      ├─for=2,with=1 <while loop>
      │ └─"test/test_expect_test.ml":4058:6
      └─for=2,with=1 <while loop>
        └─"test/test_expect_test.ml":4058:6
    0

    BEGIN DEBUG SESSION for=1,with=2
    result = 21
    ├─"test/test_expect_test.ml":4054:27
    ├─for=1,with=2 result
    └─for=1,with=2 while:test_expect_test:4057
      ├─"test/test_expect_test.ml":4057:4
      ├─for=1,with=2 <while loop>
      │ ├─"test/test_expect_test.ml":4058:6
      │ └─for=1,with=2 i=1
      │   ├─for=1,with=2 then:test_expect_test:4061
      │   │ ├─"test/test_expect_test.ml":4061:23
      │   │ └─(ERROR: 1 i= 1)
      │   ├─(WARNING: 2 i= 1)
      │   └─for=1,with=2 fun:test_expect_test:4063
      │     └─"test/test_expect_test.ml":4063:13
      ├─for=1,with=2 <while loop>
      │ ├─"test/test_expect_test.ml":4058:6
      │ └─for=1,with=2 i=2
      │   ├─for=1,with=2 then:test_expect_test:4061
      │   │ ├─"test/test_expect_test.ml":4061:23
      │   │ └─(ERROR: 1 i= 2)
      │   ├─(WARNING: 2 i= 2)
      │   └─for=1,with=2 fun:test_expect_test:4063
      │     └─"test/test_expect_test.ml":4063:13
      ├─for=1,with=2 <while loop>
      │ ├─"test/test_expect_test.ml":4058:6
      │ └─for=1,with=2 i=3
      │   ├─for=1,with=2 else:test_expect_test:4061
      │   │ └─"test/test_expect_test.ml":4061:65
      │   ├─(WARNING: 2 i= 3)
      │   └─for=1,with=2 fun:test_expect_test:4063
      │     └─"test/test_expect_test.ml":4063:13
      ├─for=1,with=2 <while loop>
      │ ├─"test/test_expect_test.ml":4058:6
      │ └─for=1,with=2 i=4
      │   ├─for=1,with=2 else:test_expect_test:4061
      │   │ └─"test/test_expect_test.ml":4061:65
      │   ├─(WARNING: 2 i= 4)
      │   └─for=1,with=2 fun:test_expect_test:4063
      │     └─"test/test_expect_test.ml":4063:13
      ├─for=1,with=2 <while loop>
      │ ├─"test/test_expect_test.ml":4058:6
      │ └─for=1,with=2 i=5
      │   ├─for=1,with=2 else:test_expect_test:4061
      │   │ └─"test/test_expect_test.ml":4061:65
      │   ├─(WARNING: 2 i= 5)
      │   └─for=1,with=2 fun:test_expect_test:4063
      │     └─"test/test_expect_test.ml":4063:13
      └─for=1,with=2 <while loop>
        ├─"test/test_expect_test.ml":4058:6
        └─for=1,with=2 i=6
          ├─for=1,with=2 else:test_expect_test:4061
          │ └─"test/test_expect_test.ml":4061:65
          ├─(WARNING: 2 i= 6)
          └─for=1,with=2 fun:test_expect_test:4063
            └─"test/test_expect_test.ml":4063:13
    21

    BEGIN DEBUG SESSION for=3,with=3
    result = 21
    ├─"test/test_expect_test.ml":4054:27
    ├─for=3,with=3 result
    └─for=3,with=3 while:test_expect_test:4057
      ├─"test/test_expect_test.ml":4057:4
      ├─for=3,with=3 <while loop>
      │ ├─"test/test_expect_test.ml":4058:6
      │ └─for=3,with=3 i=1
      │   ├─for=3,with=3 then:test_expect_test:4061
      │   │ ├─"test/test_expect_test.ml":4061:23
      │   │ └─(ERROR: 1 i= 1)
      │   ├─(WARNING: 2 i= 1)
      │   ├─for=3,with=3 fun:test_expect_test:4063
      │   │ └─"test/test_expect_test.ml":4063:13
      │   └─(INFO: 3 j= 1)
      ├─for=3,with=3 <while loop>
      │ ├─"test/test_expect_test.ml":4058:6
      │ └─for=3,with=3 i=2
      │   ├─for=3,with=3 then:test_expect_test:4061
      │   │ ├─"test/test_expect_test.ml":4061:23
      │   │ └─(ERROR: 1 i= 2)
      │   ├─(WARNING: 2 i= 2)
      │   ├─for=3,with=3 fun:test_expect_test:4063
      │   │ └─"test/test_expect_test.ml":4063:13
      │   └─(INFO: 3 j= 3)
      ├─for=3,with=3 <while loop>
      │ ├─"test/test_expect_test.ml":4058:6
      │ └─for=3,with=3 i=3
      │   ├─for=3,with=3 else:test_expect_test:4061
      │   │ └─"test/test_expect_test.ml":4061:65
      │   ├─(WARNING: 2 i= 3)
      │   ├─for=3,with=3 fun:test_expect_test:4063
      │   │ └─"test/test_expect_test.ml":4063:13
      │   └─(INFO: 3 j= 6)
      ├─for=3,with=3 <while loop>
      │ ├─"test/test_expect_test.ml":4058:6
      │ └─for=3,with=3 i=4
      │   ├─for=3,with=3 else:test_expect_test:4061
      │   │ └─"test/test_expect_test.ml":4061:65
      │   ├─(WARNING: 2 i= 4)
      │   ├─for=3,with=3 fun:test_expect_test:4063
      │   │ └─"test/test_expect_test.ml":4063:13
      │   └─(INFO: 3 j= 10)
      ├─for=3,with=3 <while loop>
      │ ├─"test/test_expect_test.ml":4058:6
      │ └─for=3,with=3 i=5
      │   ├─for=3,with=3 else:test_expect_test:4061
      │   │ └─"test/test_expect_test.ml":4061:65
      │   ├─(WARNING: 2 i= 5)
      │   ├─for=3,with=3 fun:test_expect_test:4063
      │   │ └─"test/test_expect_test.ml":4063:13
      │   └─(INFO: 3 j= 15)
      └─for=3,with=3 <while loop>
        ├─"test/test_expect_test.ml":4058:6
        └─for=3,with=3 i=6
          ├─for=3,with=3 else:test_expect_test:4061
          │ └─"test/test_expect_test.ml":4061:65
          ├─(WARNING: 2 i= 6)
          ├─for=3,with=3 fun:test_expect_test:4063
          │ └─"test/test_expect_test.ml":4063:13
          └─(INFO: 3 j= 21)
    21

    BEGIN DEBUG SESSION for=4,with=3
    result = 0
    ├─"test/test_expect_test.ml":4054:27
    ├─for=4,with=3 result
    └─for=4,with=3 while:test_expect_test:4057
      ├─"test/test_expect_test.ml":4057:4
      ├─for=4,with=3 <while loop>
      │ └─"test/test_expect_test.ml":4058:6
      ├─for=4,with=3 <while loop>
      │ └─"test/test_expect_test.ml":4058:6
      ├─for=4,with=3 <while loop>
      │ └─"test/test_expect_test.ml":4058:6
      ├─for=4,with=3 <while loop>
      │ └─"test/test_expect_test.ml":4058:6
      ├─for=4,with=3 <while loop>
      │ └─"test/test_expect_test.ml":4058:6
      └─for=4,with=3 <while loop>
        └─"test/test_expect_test.ml":4058:6
    0
    |}]

let%expect_test "%log_block compile-time nothing" =
  let module Debug_runtime = (val Minidebug_runtime.debug ()) in
  let%diagn_show _logging_logic : unit =
    [%log_level
      0;
      let logify _logs =
        [%log_block
          "logs";
          let rec loop logs =
            match logs with
            | "start" :: header :: tl ->
                let more =
                  [%log_entry
                    header;
                    loop tl]
                in
                loop more
            | "end" :: tl -> tl
            | msg :: tl ->
                [%log msg];
                loop tl
            | [] -> []
          in
          ignore (loop _logs)]
      in
      logify
        [
          "preamble";
          "start";
          "header 1";
          "log 1";
          "start";
          "nested header";
          "log 2";
          "end";
          "log 3";
          "end";
          "start";
          "header 2";
          "log 4";
          "end";
          "postscript";
        ]]
  in
  [%expect {| BEGIN DEBUG SESSION |}]
