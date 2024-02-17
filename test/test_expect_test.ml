type t = { first : int; second : int } [@@deriving show]

let sexp_of_string s = Sexplib0.Sexp.Atom s
let sexp_of_list f l = Sexplib0.Sexp.List (List.map f l)
let sexp_of_unit () = Sexplib0.Sexp.List []
let sexp_of_int i = Sexplib0.Sexp.Atom (string_of_int i)
let sexp_of_float n = Sexplib0.Sexp.Atom (string_of_float n)

let%expect_test "%debug_this_show flushing to a file" =
  let module Debug_runtime =
    Minidebug_runtime.Flushing
      ((val Minidebug_runtime.debug_ch ~time_tagged:true
              "../../../debugger_expect_show_flushing.log")) in
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
  let module Debug_runtime = (val Minidebug_runtime.debug_flushing ~time_tagged:true ())
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
    YYYY-MM-DD HH:MM:SS.NNNNNN - bar begin "test/test_expect_test.ml":28:21-30:16
     x = { Test_expect_test.first = 7; second = 42 }
      "test/test_expect_test.ml":29:8: y
      y = 8
     bar = 336
    YYYY-MM-DD HH:MM:SS.NNNNNN - bar end
    336
    YYYY-MM-DD HH:MM:SS.NNNNNN - baz begin "test/test_expect_test.ml":33:10-35:22
     x = { Test_expect_test.first = 7; second = 42 }
      "test/test_expect_test.ml":34:19: _yz
      _yz = (8, 3)
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
    bar begin "test/test_expect_test.ml":68:21-70:16
     x = { Test_expect_test.first = 7; second = 42 }
      "test/test_expect_test.ml":69:8: y
      y = 8
     bar = 336
    <N.NNμs> bar end
    336
    baz begin "test/test_expect_test.ml":73:10-75:22
     x = { Test_expect_test.first = 7; second = 42 }
      "test/test_expect_test.ml":74:19: _yz
      _yz = (8, 3)
     baz = 339
    <N.NNμs> baz end
    339 |}]

let%expect_test "%debug_show flushing with global prefix" =
  let module Debug_runtime =
    (val Minidebug_runtime.debug_flushing ~time_tagged:false ~global_prefix:"test-51" ())
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
    test-51 bar begin "test/test_expect_test.ml":105:21-107:16
     x = { Test_expect_test.first = 7; second = 42 }
      "test/test_expect_test.ml":106:8: test-51 y
      y = 8
     bar = 336
    test-51 bar end
    336
    test-51 baz begin "test/test_expect_test.ml":110:10-112:22
     x = { Test_expect_test.first = 7; second = 42 }
      "test/test_expect_test.ml":111:19: test-51 _yz
      _yz = (8, 3)
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
    "test/test_expect_test.ml":137:40-139:57: loop_complete
    ├─x = 7
    ├─"test/test_expect_test.ml":138:8: z
    │ └─z = 3
    ├─"test/test_expect_test.ml":137:40-139:57: loop_complete
    │ ├─x = 6
    │ ├─"test/test_expect_test.ml":138:8: z
    │ │ └─z = 2
    │ ├─"test/test_expect_test.ml":137:40-139:57: loop_complete
    │ │ ├─x = 5
    │ │ ├─"test/test_expect_test.ml":138:8: z
    │ │ │ └─z = 2
    │ │ ├─"test/test_expect_test.ml":137:40-139:57: loop_complete
    │ │ │ ├─x = 4
    │ │ │ ├─"test/test_expect_test.ml":138:8: z
    │ │ │ │ └─z = 1
    │ │ │ ├─"test/test_expect_test.ml":137:40-139:57: loop_complete
    │ │ │ │ ├─x = 3
    │ │ │ │ ├─"test/test_expect_test.ml":138:8: z
    │ │ │ │ │ └─z = 1
    │ │ │ │ ├─"test/test_expect_test.ml":137:40-139:57: loop_complete
    │ │ │ │ │ ├─x = 2
    │ │ │ │ │ ├─"test/test_expect_test.ml":138:8: z
    │ │ │ │ │ │ └─z = 0
    │ │ │ │ │ ├─"test/test_expect_test.ml":137:40-139:57: loop_complete
    │ │ │ │ │ │ ├─x = 1
    │ │ │ │ │ │ ├─"test/test_expect_test.ml":138:8: z
    │ │ │ │ │ │ │ └─z = 0
    │ │ │ │ │ │ ├─"test/test_expect_test.ml":137:40-139:57: loop_complete
    │ │ │ │ │ │ │ ├─x = 0
    │ │ │ │ │ │ │ ├─"test/test_expect_test.ml":138:8: z
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
  "test/test_expect_test.ml":186:39-190:56: loop_changes
  ├─x = 7
  ├─"test/test_expect_test.ml":187:8: z
  │ └─z = 3
  ├─"test/test_expect_test.ml":186:39-190:56: loop_changes
  │ ├─x = 6
  │ ├─"test/test_expect_test.ml":187:8: z
  │ │ └─z = 2
  │ ├─"test/test_expect_test.ml":186:39-190:56: loop_changes
  │ │ ├─x = 5
  │ │ ├─"test/test_expect_test.ml":187:8: z
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
    "test/test_expect_test.ml":214:41-217:36: loop_truncated
    ├─x = 7
    ├─"test/test_expect_test.ml":215:8: z
    │ └─z = 3
    └─"test/test_expect_test.ml":214:41-217:36: loop_truncated
      ├─x = 6
      ├─"test/test_expect_test.ml":215:8: z
      │ └─z = 2
      └─"test/test_expect_test.ml":214:41-217:36: loop_truncated
        ├─x = 5
        ├─"test/test_expect_test.ml":215:8: z
        │ └─z = 2
        └─"test/test_expect_test.ml":214:41-217:36: loop_truncated
          ├─x = 4
          ├─"test/test_expect_test.ml":215:8: z
          │ └─z = 1
          └─"test/test_expect_test.ml":214:41-217:36: loop_truncated
            ├─x = 3
            ├─"test/test_expect_test.ml":215:8: z
            │ └─z = 1
            └─"test/test_expect_test.ml":214:41-217:36: loop_truncated
              ├─x = 2
              ├─"test/test_expect_test.ml":215:8: z
              │ └─z = 0
              └─"test/test_expect_test.ml":214:41-217:36: loop_truncated
                ├─x = 1
                ├─"test/test_expect_test.ml":215:8: z
                │ └─z = 0
                └─"test/test_expect_test.ml":214:41-217:36: loop_truncated
                  ├─x = 0
                  └─"test/test_expect_test.ml":215:8: z
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
      "test/test_expect_test.ml":262:40-266:60: loop_exceeded
      ├─x = 7
      ├─"test/test_expect_test.ml":265:10: z
      │ └─z = 3
      └─"test/test_expect_test.ml":262:40-266:60: loop_exceeded
        ├─x = 6
        ├─"test/test_expect_test.ml":265:10: z
        │ └─z = 2
        └─"test/test_expect_test.ml":262:40-266:60: loop_exceeded
          ├─x = 5
          ├─"test/test_expect_test.ml":265:10: z
          │ └─z = 2
          └─"test/test_expect_test.ml":262:40-266:60: loop_exceeded
            ├─x = 4
            ├─"test/test_expect_test.ml":265:10: z
            │ └─z = 1
            └─"test/test_expect_test.ml":262:40-266:60: loop_exceeded
              ├─x = 3
              └─"test/test_expect_test.ml":265:10: z
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
    "test/test_expect_test.ml":301:26: _bar
    ├─"test/test_expect_test.ml":305:16: _baz
    │ └─_baz = 0
    ├─"test/test_expect_test.ml":305:16: _baz
    │ └─_baz = 2
    ├─"test/test_expect_test.ml":305:16: _baz
    │ └─_baz = 4
    ├─"test/test_expect_test.ml":305:16: _baz
    │ └─_baz = 6
    ├─"test/test_expect_test.ml":305:16: _baz
    │ └─_baz = 8
    ├─"test/test_expect_test.ml":305:16: _baz
    │ └─_baz = 10
    ├─"test/test_expect_test.ml":305:16: _baz
    │ └─_baz = 12
    ├─"test/test_expect_test.ml":305:16: _baz
    │ └─_baz = 14
    ├─"test/test_expect_test.ml":305:16: _baz
    │ └─_baz = 16
    ├─"test/test_expect_test.ml":305:16: _baz
    │ └─_baz = 18
    ├─"test/test_expect_test.ml":305:16: _baz
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
    "test/test_expect_test.ml":345:26: _bar
    ├─<earlier entries truncated>
    ├─"test/test_expect_test.ml":347:14: _baz
    │ └─_baz = 44
    ├─"test/test_expect_test.ml":347:14: _baz
    │ └─_baz = 46
    ├─"test/test_expect_test.ml":347:14: _baz
    │ └─_baz = 48
    ├─"test/test_expect_test.ml":347:14: _baz
    │ └─_baz = 50
    ├─"test/test_expect_test.ml":347:14: _baz
    │ └─_baz = 52
    ├─"test/test_expect_test.ml":347:14: _baz
    │ └─_baz = 54
    ├─"test/test_expect_test.ml":347:14: _baz
    │ └─_baz = 56
    ├─"test/test_expect_test.ml":347:14: _baz
    │ └─_baz = 58
    ├─"test/test_expect_test.ml":347:14: _baz
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
    "test/test_expect_test.ml":383:26: _bar
    └─"test/test_expect_test.ml":386:10: <for loop>
      ├─i = 0
      ├─"test/test_expect_test.ml":386:14: <for i>
      │ └─"test/test_expect_test.ml":387:16: _baz
      │   └─_baz = 0
      ├─i = 1
      ├─"test/test_expect_test.ml":386:14: <for i>
      │ └─"test/test_expect_test.ml":387:16: _baz
      │   └─_baz = 2
      ├─i = 2
      ├─"test/test_expect_test.ml":386:14: <for i>
      │ └─"test/test_expect_test.ml":387:16: _baz
      │   └─_baz = 4
      ├─i = 3
      ├─"test/test_expect_test.ml":386:14: <for i>
      │ └─"test/test_expect_test.ml":387:16: _baz
      │   └─_baz = 6
      ├─i = 4
      ├─"test/test_expect_test.ml":386:14: <for i>
      │ └─"test/test_expect_test.ml":387:16: _baz
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
    "test/test_expect_test.ml":427:26: _bar
    ├─"test/test_expect_test.ml":428:8: <for loop>
    │ ├─<earlier entries truncated>
    │ ├─i = 26
    │ ├─"test/test_expect_test.ml":428:12: <for i>
    │ │ └─"test/test_expect_test.ml":429:14: _baz
    │ │   └─_baz = 52
    │ ├─i = 27
    │ ├─"test/test_expect_test.ml":428:12: <for i>
    │ │ └─"test/test_expect_test.ml":429:14: _baz
    │ │   └─_baz = 54
    │ ├─i = 28
    │ ├─"test/test_expect_test.ml":428:12: <for i>
    │ │ └─"test/test_expect_test.ml":429:14: _baz
    │ │   └─_baz = 56
    │ ├─i = 29
    │ ├─"test/test_expect_test.ml":428:12: <for i>
    │ │ └─"test/test_expect_test.ml":429:14: _baz
    │ │   └─_baz = 58
    │ ├─i = 30
    │ └─"test/test_expect_test.ml":428:12: <for i>
    │   └─"test/test_expect_test.ml":429:14: _baz
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
      "test/test_expect_test.ml":468:26: _bar
      ├─"test/test_expect_test.ml":471:10: <for loop>
      │ ├─i = 0
      │ ├─"test/test_expect_test.ml":471:14: <for i>
      │ │ └─"test/test_expect_test.ml":472:16: _baz
      │ │   └─_baz = 0
      │ ├─i = 1
      │ ├─"test/test_expect_test.ml":471:14: <for i>
      │ │ └─"test/test_expect_test.ml":472:16: _baz
      │ │   └─_baz = 2
      │ ├─i = 2
      │ ├─"test/test_expect_test.ml":471:14: <for i>
      │ │ └─"test/test_expect_test.ml":472:16: _baz
      │ │   └─_baz = 4
      │ ├─i = 3
      │ ├─"test/test_expect_test.ml":471:14: <for i>
      │ │ └─"test/test_expect_test.ml":472:16: _baz
      │ │   └─_baz = 6
      │ ├─i = 4
      │ ├─"test/test_expect_test.ml":471:14: <for i>
      │ │ └─"test/test_expect_test.ml":472:16: _baz
      │ │   └─_baz = 8
      │ ├─i = 5
      │ ├─"test/test_expect_test.ml":471:14: <for i>
      │ │ └─"test/test_expect_test.ml":472:16: _baz
      │ │   └─_baz = 10
      │ ├─i = 6
      │ └─"test/test_expect_test.ml":471:14: <for i>
      │   └─"test/test_expect_test.ml":472:16: _baz
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
      "test/test_expect_test.ml":519:26: _bar <N.NNμs>
      ├─"test/test_expect_test.ml":522:10: <for loop> <N.NNμs>
      │ ├─i = 0
      │ ├─"test/test_expect_test.ml":522:14: <for i> <N.NNμs>
      │ │ └─"test/test_expect_test.ml":523:16: _baz <N.NNμs>
      │ │   └─_baz = 0
      │ ├─i = 1
      │ ├─"test/test_expect_test.ml":522:14: <for i> <N.NNμs>
      │ │ └─"test/test_expect_test.ml":523:16: _baz <N.NNμs>
      │ │   └─_baz = 2
      │ ├─i = 2
      │ ├─"test/test_expect_test.ml":522:14: <for i> <N.NNμs>
      │ │ └─"test/test_expect_test.ml":523:16: _baz <N.NNμs>
      │ │   └─_baz = 4
      │ ├─i = 3
      │ ├─"test/test_expect_test.ml":522:14: <for i> <N.NNμs>
      │ │ └─"test/test_expect_test.ml":523:16: _baz <N.NNμs>
      │ │   └─_baz = 6
      │ ├─i = 4
      │ ├─"test/test_expect_test.ml":522:14: <for i> <N.NNμs>
      │ │ └─"test/test_expect_test.ml":523:16: _baz <N.NNμs>
      │ │   └─_baz = 8
      │ ├─i = 5
      │ ├─"test/test_expect_test.ml":522:14: <for i> <N.NNμs>
      │ │ └─"test/test_expect_test.ml":523:16: _baz <N.NNμs>
      │ │   └─_baz = 10
      │ ├─i = 6
      │ └─"test/test_expect_test.ml":522:14: <for i> <N.NNμs>
      │   └─"test/test_expect_test.ml":523:16: _baz <N.NNμs>
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
    "test/test_expect_test.ml":574:26: _bar
    ├─"test/test_expect_test.ml":576:8: <while loop>
    │ ├─"test/test_expect_test.ml":577:10: <while loop>
    │ │ └─"test/test_expect_test.ml":577:14: _baz
    │ │   └─_baz = 0
    │ ├─"test/test_expect_test.ml":577:10: <while loop>
    │ │ └─"test/test_expect_test.ml":577:14: _baz
    │ │   └─_baz = 2
    │ ├─"test/test_expect_test.ml":577:10: <while loop>
    │ │ └─"test/test_expect_test.ml":577:14: _baz
    │ │   └─_baz = 4
    │ ├─"test/test_expect_test.ml":577:10: <while loop>
    │ │ └─"test/test_expect_test.ml":577:14: _baz
    │ │   └─_baz = 6
    │ ├─"test/test_expect_test.ml":577:10: <while loop>
    │ │ └─"test/test_expect_test.ml":577:14: _baz
    │ │   └─_baz = 8
    │ └─"test/test_expect_test.ml":577:10: <while loop>
    │   └─"test/test_expect_test.ml":577:14: _baz
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
      "test/test_expect_test.ml":612:40-620:72: loop_exceeded
      ├─x = 3
      ├─"test/test_expect_test.ml":619:17: z
      │ └─z = 1
      └─"test/test_expect_test.ml":612:40-620:72: loop_exceeded
        ├─x = 2
        ├─"test/test_expect_test.ml":619:17: z
        │ └─z = 0
        └─"test/test_expect_test.ml":612:40-620:72: loop_exceeded
          ├─x = 1
          ├─"test/test_expect_test.ml":619:17: z
          │ └─z = 0
          └─"test/test_expect_test.ml":612:40-620:72: loop_exceeded
            ├─x = 0
            ├─"test/test_expect_test.ml":619:17: z
            │ └─z = 0
            ├─"test/test_expect_test.ml":619:17: z
            │ └─z = 1
            ├─"test/test_expect_test.ml":619:17: z
            │ └─z = 2
            ├─"test/test_expect_test.ml":619:17: z
            │ └─z = 3
            ├─"test/test_expect_test.ml":619:17: z
            │ └─z = 4
            ├─"test/test_expect_test.ml":619:17: z
            │ └─z = 5
            ├─"test/test_expect_test.ml":619:17: z
            │ └─z = 6
            ├─"test/test_expect_test.ml":619:17: z
            │ └─z = 7
            ├─"test/test_expect_test.ml":619:17: z
            │ └─z = 8
            ├─"test/test_expect_test.ml":619:17: z
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
      "test/test_expect_test.ml":668:40-674:69: loop_exceeded
      ├─<earlier entries truncated>
      ├─"test/test_expect_test.ml":668:40-674:69: loop_exceeded
      │ ├─<earlier entries truncated>
      │ ├─"test/test_expect_test.ml":668:40-674:69: loop_exceeded
      │ │ ├─<earlier entries truncated>
      │ │ ├─"test/test_expect_test.ml":668:40-674:69: loop_exceeded
      │ │ │ ├─<earlier entries truncated>
      │ │ │ ├─"test/test_expect_test.ml":673:15: z
      │ │ │ │ └─z = 17
      │ │ │ ├─"test/test_expect_test.ml":673:15: z
      │ │ │ │ └─z = 18
      │ │ │ ├─"test/test_expect_test.ml":673:15: z
      │ │ │ │ └─z = 19
      │ │ │ └─loop_exceeded = 190
      │ │ ├─"test/test_expect_test.ml":673:15: z
      │ │ │ └─z = 9
      │ │ ├─"test/test_expect_test.ml":668:40-674:69: loop_exceeded
      │ │ │ ├─<earlier entries truncated>
      │ │ │ ├─"test/test_expect_test.ml":673:15: z
      │ │ │ │ └─z = 17
      │ │ │ ├─"test/test_expect_test.ml":673:15: z
      │ │ │ │ └─z = 18
      │ │ │ ├─"test/test_expect_test.ml":673:15: z
      │ │ │ │ └─z = 19
      │ │ │ └─loop_exceeded = 190
      │ │ └─loop_exceeded = 1945
      │ ├─"test/test_expect_test.ml":673:15: z
      │ │ └─z = 5
      │ ├─"test/test_expect_test.ml":668:40-674:69: loop_exceeded
      │ │ ├─<earlier entries truncated>
      │ │ ├─"test/test_expect_test.ml":668:40-674:69: loop_exceeded
      │ │ │ ├─<earlier entries truncated>
      │ │ │ ├─"test/test_expect_test.ml":673:15: z
      │ │ │ │ └─z = 17
      │ │ │ ├─"test/test_expect_test.ml":673:15: z
      │ │ │ │ └─z = 18
      │ │ │ ├─"test/test_expect_test.ml":673:15: z
      │ │ │ │ └─z = 19
      │ │ │ └─loop_exceeded = 190
      │ │ ├─"test/test_expect_test.ml":673:15: z
      │ │ │ └─z = 9
      │ │ ├─"test/test_expect_test.ml":668:40-674:69: loop_exceeded
      │ │ │ ├─<earlier entries truncated>
      │ │ │ ├─"test/test_expect_test.ml":673:15: z
      │ │ │ │ └─z = 17
      │ │ │ ├─"test/test_expect_test.ml":673:15: z
      │ │ │ │ └─z = 18
      │ │ │ ├─"test/test_expect_test.ml":673:15: z
      │ │ │ │ └─z = 19
      │ │ │ └─loop_exceeded = 190
      │ │ └─loop_exceeded = 1945
      │ └─loop_exceeded = 11685
      ├─"test/test_expect_test.ml":673:15: z
      │ └─z = 5
      ├─"test/test_expect_test.ml":668:40-674:69: loop_exceeded
      │ ├─<earlier entries truncated>
      │ ├─"test/test_expect_test.ml":668:40-674:69: loop_exceeded
      │ │ ├─<earlier entries truncated>
      │ │ ├─"test/test_expect_test.ml":668:40-674:69: loop_exceeded
      │ │ │ ├─<earlier entries truncated>
      │ │ │ ├─"test/test_expect_test.ml":673:15: z
      │ │ │ │ └─z = 17
      │ │ │ ├─"test/test_expect_test.ml":673:15: z
      │ │ │ │ └─z = 18
      │ │ │ ├─"test/test_expect_test.ml":673:15: z
      │ │ │ │ └─z = 19
      │ │ │ └─loop_exceeded = 190
      │ │ ├─"test/test_expect_test.ml":673:15: z
      │ │ │ └─z = 9
      │ │ ├─"test/test_expect_test.ml":668:40-674:69: loop_exceeded
      │ │ │ ├─<earlier entries truncated>
      │ │ │ ├─"test/test_expect_test.ml":673:15: z
      │ │ │ │ └─z = 17
      │ │ │ ├─"test/test_expect_test.ml":673:15: z
      │ │ │ │ └─z = 18
      │ │ │ ├─"test/test_expect_test.ml":673:15: z
      │ │ │ │ └─z = 19
      │ │ │ └─loop_exceeded = 190
      │ │ └─loop_exceeded = 1945
      │ ├─"test/test_expect_test.ml":673:15: z
      │ │ └─z = 5
      │ ├─"test/test_expect_test.ml":668:40-674:69: loop_exceeded
      │ │ ├─<earlier entries truncated>
      │ │ ├─"test/test_expect_test.ml":668:40-674:69: loop_exceeded
      │ │ │ ├─<earlier entries truncated>
      │ │ │ ├─"test/test_expect_test.ml":673:15: z
      │ │ │ │ └─z = 17
      │ │ │ ├─"test/test_expect_test.ml":673:15: z
      │ │ │ │ └─z = 18
      │ │ │ ├─"test/test_expect_test.ml":673:15: z
      │ │ │ │ └─z = 19
      │ │ │ └─loop_exceeded = 190
      │ │ ├─"test/test_expect_test.ml":673:15: z
      │ │ │ └─z = 9
      │ │ ├─"test/test_expect_test.ml":668:40-674:69: loop_exceeded
      │ │ │ ├─<earlier entries truncated>
      │ │ │ ├─"test/test_expect_test.ml":673:15: z
      │ │ │ │ └─z = 17
      │ │ │ ├─"test/test_expect_test.ml":673:15: z
      │ │ │ │ └─z = 18
      │ │ │ ├─"test/test_expect_test.ml":673:15: z
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
      ┌────────────────────────────────────────────────────────┐
      │"test/test_expect_test.ml":796:41-800:61: loop_highlight│
      ├────────────────────────────────────────────────────────┘
      ├─x = 7
      ├─┬────────────────────────────────────┐
      │ │"test/test_expect_test.ml":799:10: z│
      │ ├────────────────────────────────────┘
      │ └─┬─────┐
      │   │z = 3│
      │   └─────┘
      ├─┬────────────────────────────────────────────────────────┐
      │ │"test/test_expect_test.ml":796:41-800:61: loop_highlight│
      │ ├────────────────────────────────────────────────────────┘
      │ ├─x = 6
      │ ├─"test/test_expect_test.ml":799:10: z
      │ │ └─z = 2
      │ ├─┬────────────────────────────────────────────────────────┐
      │ │ │"test/test_expect_test.ml":796:41-800:61: loop_highlight│
      │ │ ├────────────────────────────────────────────────────────┘
      │ │ ├─x = 5
      │ │ ├─"test/test_expect_test.ml":799:10: z
      │ │ │ └─z = 2
      │ │ ├─┬────────────────────────────────────────────────────────┐
      │ │ │ │"test/test_expect_test.ml":796:41-800:61: loop_highlight│
      │ │ │ ├────────────────────────────────────────────────────────┘
      │ │ │ ├─x = 4
      │ │ │ ├─"test/test_expect_test.ml":799:10: z
      │ │ │ │ └─z = 1
      │ │ │ ├─┬────────────────────────────────────────────────────────┐
      │ │ │ │ │"test/test_expect_test.ml":796:41-800:61: loop_highlight│
      │ │ │ │ ├────────────────────────────────────────────────────────┘
      │ │ │ │ ├─┬─────┐
      │ │ │ │ │ │x = 3│
      │ │ │ │ │ └─────┘
      │ │ │ │ ├─"test/test_expect_test.ml":799:10: z
      │ │ │ │ │ └─z = 1
      │ │ │ │ ├─"test/test_expect_test.ml":796:41-800:61: loop_highlight
      │ │ │ │ │ ├─x = 2
      │ │ │ │ │ ├─"test/test_expect_test.ml":799:10: z
      │ │ │ │ │ │ └─z = 0
      │ │ │ │ │ ├─"test/test_expect_test.ml":796:41-800:61: loop_highlight
      │ │ │ │ │ │ ├─x = 1
      │ │ │ │ │ │ ├─"test/test_expect_test.ml":799:10: z
      │ │ │ │ │ │ │ └─z = 0
      │ │ │ │ │ │ ├─"test/test_expect_test.ml":796:41-800:61: loop_highlight
      │ │ │ │ │ │ │ ├─x = 0
      │ │ │ │ │ │ │ ├─"test/test_expect_test.ml":799:10: z
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
      "test/test_expect_test.ml":866:37-868:46: track_branches
      ├─x = 7
      ├─"test/test_expect_test.ml":868:9: <if -- else branch>
      │ └─"test/test_expect_test.ml":868:36-868:37: <match -- branch 1>
      └─track_branches = 4
      4
      "test/test_expect_test.ml":866:37-868:46: track_branches
      ├─x = 3
      ├─"test/test_expect_test.ml":867:18: <if -- then branch>
      │ └─"test/test_expect_test.ml":867:54-867:57: <match -- branch 2>
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
      "test/test_expect_test.ml":899:11-899:12: <function -- branch 3>
      4
      "test/test_expect_test.ml":901:11-901:14: <function -- branch 5> x
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
      "test/test_expect_test.ml":920:37-934:16: track_branches
      ├─x = 8
      ├─"test/test_expect_test.ml":929:6: <if -- else branch>
      │ └─"test/test_expect_test.ml":933:10-934:16: <match -- branch 2>
      │   └─"test/test_expect_test.ml":933:14: result
      │     ├─"test/test_expect_test.ml":933:44: <if -- then branch>
      │     └─result = 8
      └─track_branches = 8
      8
      "test/test_expect_test.ml":920:37-934:16: track_branches
      ├─x = 3
      ├─"test/test_expect_test.ml":922:6: <if -- then branch>
      │ └─"test/test_expect_test.ml":926:14: result
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
    "test/test_expect_test.ml":966:27-970:5: track_foo
    ├─x = 8
    ├─"test/test_expect_test.ml":969:4-969:31: __fun
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
      "test/test_expect_test.ml":988:37-1002:16: track_branches
      ├─x = 8
      ├─"test/test_expect_test.ml":997:6: <if -- else branch>
      │ └─"test/test_expect_test.ml":1001:25: result
      │   ├─"test/test_expect_test.ml":1001:55: <if -- then branch>
      │   └─result = 8
      └─track_branches = 8
      8
      "test/test_expect_test.ml":988:37-1002:16: track_branches
      ├─x = 3
      ├─"test/test_expect_test.ml":990:6: <if -- then branch>
      │ └─"test/test_expect_test.ml":994:25: result
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
    "test/test_expect_test.ml":1032:27-1035:73: anonymous
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
    "test/test_expect_test.ml":1057:25-1067:25: wrapper
    "test/test_expect_test.ml":1058:29-1061:75: anonymous
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
    "test/test_expect_test.ml":1086:32-1087:70: anonymous
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
      "test/test_expect_test.ml":1100:32-1101:70: anonymous
      ├─x = 3
      ├─"test/test_expect_test.ml":1101:50-1101:70: __fun
      │ └─i = 0
      ├─"test/test_expect_test.ml":1101:50-1101:70: __fun
      │ └─i = 1
      ├─"test/test_expect_test.ml":1101:50-1101:70: __fun
      │ └─i = 2
      └─"test/test_expect_test.ml":1101:50-1101:70: __fun
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
      "test/test_expect_test.ml":1124:40-1132:72: loop_exceeded
      ├─x = 3
      └─"test/test_expect_test.ml":1130:11-1132:71: __fun
        ├─i = 0
        ├─"test/test_expect_test.ml":1131:17: z
        │ └─z = 1
        └─"test/test_expect_test.ml":1132:35: <if -- else branch>
          └─"test/test_expect_test.ml":1124:40-1132:72: loop_exceeded
            ├─x = 2
            └─"test/test_expect_test.ml":1130:11-1132:71: __fun
              ├─i = 0
              ├─"test/test_expect_test.ml":1131:17: z
              │ └─z = 0
              └─"test/test_expect_test.ml":1132:35: <if -- else branch>
                └─"test/test_expect_test.ml":1124:40-1132:72: loop_exceeded
                  ├─x = 1
                  └─"test/test_expect_test.ml":1130:11-1132:71: __fun
                    ├─i = 0
                    ├─"test/test_expect_test.ml":1131:17: z
                    │ └─z = 0
                    └─"test/test_expect_test.ml":1132:35: <if -- else branch>
                      └─"test/test_expect_test.ml":1124:40-1132:72: loop_exceeded
                        ├─x = 0
                        ├─"test/test_expect_test.ml":1130:11-1132:71: __fun
                        │ ├─i = 0
                        │ ├─"test/test_expect_test.ml":1131:17: z
                        │ │ └─z = 0
                        │ └─"test/test_expect_test.ml":1132:28: <if -- then branch>
                        ├─"test/test_expect_test.ml":1130:11-1132:71: __fun
                        │ ├─i = 1
                        │ ├─"test/test_expect_test.ml":1131:17: z
                        │ │ └─z = 1
                        │ └─"test/test_expect_test.ml":1132:28: <if -- then branch>
                        ├─"test/test_expect_test.ml":1130:11-1132:71: __fun
                        │ ├─i = 2
                        │ ├─"test/test_expect_test.ml":1131:17: z
                        │ │ └─z = 2
                        │ └─"test/test_expect_test.ml":1132:28: <if -- then branch>
                        ├─"test/test_expect_test.ml":1130:11-1132:71: __fun
                        │ ├─i = 3
                        │ ├─"test/test_expect_test.ml":1131:17: z
                        │ │ └─z = 3
                        │ └─"test/test_expect_test.ml":1132:28: <if -- then branch>
                        ├─"test/test_expect_test.ml":1130:11-1132:71: __fun
                        │ ├─i = 4
                        │ ├─"test/test_expect_test.ml":1131:17: z
                        │ │ └─z = 4
                        │ └─"test/test_expect_test.ml":1132:28: <if -- then branch>
                        ├─"test/test_expect_test.ml":1130:11-1132:71: __fun
                        │ ├─i = 5
                        │ ├─"test/test_expect_test.ml":1131:17: z
                        │ │ └─z = 5
                        │ └─"test/test_expect_test.ml":1132:28: <if -- then branch>
                        ├─"test/test_expect_test.ml":1130:11-1132:71: __fun
                        │ ├─i = 6
                        │ ├─"test/test_expect_test.ml":1131:17: z
                        │ │ └─z = 6
                        │ └─"test/test_expect_test.ml":1132:28: <if -- then branch>
                        ├─"test/test_expect_test.ml":1130:11-1132:71: __fun
                        │ ├─i = 7
                        │ ├─"test/test_expect_test.ml":1131:17: z
                        │ │ └─z = 7
                        │ └─"test/test_expect_test.ml":1132:28: <if -- then branch>
                        ├─"test/test_expect_test.ml":1130:11-1132:71: __fun
                        │ ├─i = 8
                        │ ├─"test/test_expect_test.ml":1131:17: z
                        │ │ └─z = 8
                        │ └─"test/test_expect_test.ml":1132:28: <if -- then branch>
                        ├─"test/test_expect_test.ml":1130:11-1132:71: __fun
                        │ ├─i = 9
                        │ ├─"test/test_expect_test.ml":1131:17: z
                        │ │ └─z = 9
                        │ └─"test/test_expect_test.ml":1132:28: <if -- then branch>
                        └─__fun = <max_num_children exceeded>
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
      "test/test_expect_test.ml":1220:40-1226:69: loop_exceeded
      ├─<earlier entries truncated>
      ├─"test/test_expect_test.ml":1224:9-1226:69: __fun
      │ ├─<earlier entries truncated>
      │ ├─"test/test_expect_test.ml":1225:15: z
      │ │ └─z = 7
      │ └─"test/test_expect_test.ml":1226:33: <if -- else branch>
      │   └─"test/test_expect_test.ml":1220:40-1226:69: loop_exceeded
      │     ├─<earlier entries truncated>
      │     ├─"test/test_expect_test.ml":1224:9-1226:69: __fun
      │     │ ├─<earlier entries truncated>
      │     │ ├─"test/test_expect_test.ml":1225:15: z
      │     │ │ └─z = 9
      │     │ └─"test/test_expect_test.ml":1226:33: <if -- else branch>
      │     │   └─"test/test_expect_test.ml":1220:40-1226:69: loop_exceeded
      │     │     ├─<earlier entries truncated>
      │     │     ├─"test/test_expect_test.ml":1224:9-1226:69: __fun
      │     │     │ ├─<earlier entries truncated>
      │     │     │ ├─"test/test_expect_test.ml":1225:15: z
      │     │     │ │ └─z = 14
      │     │     │ └─"test/test_expect_test.ml":1226:33: <if -- else branch>
      │     │     │   └─"test/test_expect_test.ml":1220:40-1226:69: loop_exceeded
      │     │     │     ├─<earlier entries truncated>
      │     │     │     ├─"test/test_expect_test.ml":1224:9-1226:69: __fun
      │     │     │     │ ├─<earlier entries truncated>
      │     │     │     │ ├─"test/test_expect_test.ml":1225:15: z
      │     │     │     │ │ └─z = 29
      │     │     │     │ └─"test/test_expect_test.ml":1226:26: <if -- then branch>
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
      "test/test_expect_test.ml":1278:26-1279:47: foo
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
  ├─"test/test_expect_test.ml":1304:41-1307:36
  ├─x = 7
  ├─z = 3
  │ └─"test/test_expect_test.ml":1305:8
  └─loop_truncated
    ├─"test/test_expect_test.ml":1304:41-1307:36
    ├─x = 6
    ├─z = 2
    │ └─"test/test_expect_test.ml":1305:8
    └─loop_truncated
      ├─"test/test_expect_test.ml":1304:41-1307:36
      ├─x = 5
      ├─z = 2
      │ └─"test/test_expect_test.ml":1305:8
      └─loop_truncated
        ├─"test/test_expect_test.ml":1304:41-1307:36
        ├─x = 4
        ├─z = 1
        │ └─"test/test_expect_test.ml":1305:8
        └─loop_truncated
          ├─"test/test_expect_test.ml":1304:41-1307:36
          ├─x = 3
          ├─z = 1
          │ └─"test/test_expect_test.ml":1305:8
          └─loop_truncated
            ├─"test/test_expect_test.ml":1304:41-1307:36
            ├─x = 2
            ├─z = 0
            │ └─"test/test_expect_test.ml":1305:8
            └─loop_truncated
              ├─"test/test_expect_test.ml":1304:41-1307:36
              ├─x = 1
              ├─z = 0
              │ └─"test/test_expect_test.ml":1305:8
              └─loop_truncated
                ├─"test/test_expect_test.ml":1304:41-1307:36
                ├─x = 0
                └─z = 0
                  └─"test/test_expect_test.ml":1305:8
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
    ├─"test/test_expect_test.ml":1363:26
    ├─_baz = 0
    │ └─"test/test_expect_test.ml":1367:16
    ├─_baz = 2
    │ └─"test/test_expect_test.ml":1367:16
    ├─_baz = 4
    │ └─"test/test_expect_test.ml":1367:16
    ├─_baz = 6
    │ └─"test/test_expect_test.ml":1367:16
    ├─_baz = 8
    │ └─"test/test_expect_test.ml":1367:16
    ├─_baz = 10
    │ └─"test/test_expect_test.ml":1367:16
    ├─_baz = 12
    │ └─"test/test_expect_test.ml":1367:16
    ├─_baz = 14
    │ └─"test/test_expect_test.ml":1367:16
    ├─_baz = 16
    │ └─"test/test_expect_test.ml":1367:16
    ├─_baz = 18
    │ └─"test/test_expect_test.ml":1367:16
    ├─_baz = 20
    │ └─"test/test_expect_test.ml":1367:16
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
      ├─"test/test_expect_test.ml":1408:26
      └─<for loop>
        ├─"test/test_expect_test.ml":1411:10
        ├─i = 0
        ├─<for i>
        │ ├─"test/test_expect_test.ml":1411:14
        │ └─_baz = 0
        │   └─"test/test_expect_test.ml":1412:16
        ├─i = 1
        ├─<for i>
        │ ├─"test/test_expect_test.ml":1411:14
        │ └─_baz = 2
        │   └─"test/test_expect_test.ml":1412:16
        ├─i = 2
        ├─<for i>
        │ ├─"test/test_expect_test.ml":1411:14
        │ └─_baz = 4
        │   └─"test/test_expect_test.ml":1412:16
        ├─i = 3
        ├─<for i>
        │ ├─"test/test_expect_test.ml":1411:14
        │ └─_baz = 6
        │   └─"test/test_expect_test.ml":1412:16
        ├─i = 4
        ├─<for i>
        │ ├─"test/test_expect_test.ml":1411:14
        │ └─_baz = 8
        │   └─"test/test_expect_test.ml":1412:16
        ├─i = 5
        ├─<for i>
        │ ├─"test/test_expect_test.ml":1411:14
        │ └─_baz = 10
        │   └─"test/test_expect_test.ml":1412:16
        ├─i = 6
        └─<for i>
          ├─"test/test_expect_test.ml":1411:14
          └─_baz = 12
            └─"test/test_expect_test.ml":1412:16 |}]

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
      ├─"test/test_expect_test.ml":1465:40-1473:72
      ├─x = 3
      ├─z = 1
      │ └─"test/test_expect_test.ml":1472:17
      └─loop_exceeded
        ├─"test/test_expect_test.ml":1465:40-1473:72
        ├─x = 2
        ├─z = 0
        │ └─"test/test_expect_test.ml":1472:17
        └─loop_exceeded
          ├─"test/test_expect_test.ml":1465:40-1473:72
          ├─x = 1
          ├─z = 0
          │ └─"test/test_expect_test.ml":1472:17
          └─loop_exceeded
            ├─"test/test_expect_test.ml":1465:40-1473:72
            ├─x = 0
            ├─z = 0
            │ └─"test/test_expect_test.ml":1472:17
            ├─z = 1
            │ └─"test/test_expect_test.ml":1472:17
            ├─z = 2
            │ └─"test/test_expect_test.ml":1472:17
            ├─z = 3
            │ └─"test/test_expect_test.ml":1472:17
            ├─z = 4
            │ └─"test/test_expect_test.ml":1472:17
            ├─z = 5
            │ └─"test/test_expect_test.ml":1472:17
            ├─z = 6
            │ └─"test/test_expect_test.ml":1472:17
            ├─z = 7
            │ └─"test/test_expect_test.ml":1472:17
            ├─z = 8
            │ └─"test/test_expect_test.ml":1472:17
            ├─z = 9
            │ └─"test/test_expect_test.ml":1472:17
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
      ├─"test/test_expect_test.ml":1529:40-1535:69
      ├─<earlier entries truncated>
      ├─z = 4 <N.NNμs>
      │ └─"test/test_expect_test.ml":1534:15
      ├─loop_exceeded = 11685 <N.NNμs>
      │ ├─"test/test_expect_test.ml":1529:40-1535:69
      │ ├─<earlier entries truncated>
      │ ├─z = 4 <N.NNμs>
      │ │ └─"test/test_expect_test.ml":1534:15
      │ ├─loop_exceeded = 1945 <N.NNμs>
      │ │ ├─"test/test_expect_test.ml":1529:40-1535:69
      │ │ ├─<earlier entries truncated>
      │ │ ├─z = 8 <N.NNμs>
      │ │ │ └─"test/test_expect_test.ml":1534:15
      │ │ ├─loop_exceeded = 190 <N.NNμs>
      │ │ │ ├─"test/test_expect_test.ml":1529:40-1535:69
      │ │ │ ├─<earlier entries truncated>
      │ │ │ ├─z = 16 <N.NNμs>
      │ │ │ │ └─"test/test_expect_test.ml":1534:15
      │ │ │ ├─z = 17 <N.NNμs>
      │ │ │ │ └─"test/test_expect_test.ml":1534:15
      │ │ │ ├─z = 18 <N.NNμs>
      │ │ │ │ └─"test/test_expect_test.ml":1534:15
      │ │ │ └─z = 19 <N.NNμs>
      │ │ │   └─"test/test_expect_test.ml":1534:15
      │ │ ├─z = 9 <N.NNμs>
      │ │ │ └─"test/test_expect_test.ml":1534:15
      │ │ └─loop_exceeded = 190 <N.NNμs>
      │ │   ├─"test/test_expect_test.ml":1529:40-1535:69
      │ │   ├─<earlier entries truncated>
      │ │   ├─z = 16 <N.NNμs>
      │ │   │ └─"test/test_expect_test.ml":1534:15
      │ │   ├─z = 17 <N.NNμs>
      │ │   │ └─"test/test_expect_test.ml":1534:15
      │ │   ├─z = 18 <N.NNμs>
      │ │   │ └─"test/test_expect_test.ml":1534:15
      │ │   └─z = 19 <N.NNμs>
      │ │     └─"test/test_expect_test.ml":1534:15
      │ ├─z = 5 <N.NNμs>
      │ │ └─"test/test_expect_test.ml":1534:15
      │ └─loop_exceeded = 1945 <N.NNμs>
      │   ├─"test/test_expect_test.ml":1529:40-1535:69
      │   ├─<earlier entries truncated>
      │   ├─z = 8 <N.NNμs>
      │   │ └─"test/test_expect_test.ml":1534:15
      │   ├─loop_exceeded = 190 <N.NNμs>
      │   │ ├─"test/test_expect_test.ml":1529:40-1535:69
      │   │ ├─<earlier entries truncated>
      │   │ ├─z = 16 <N.NNμs>
      │   │ │ └─"test/test_expect_test.ml":1534:15
      │   │ ├─z = 17 <N.NNμs>
      │   │ │ └─"test/test_expect_test.ml":1534:15
      │   │ ├─z = 18 <N.NNμs>
      │   │ │ └─"test/test_expect_test.ml":1534:15
      │   │ └─z = 19 <N.NNμs>
      │   │   └─"test/test_expect_test.ml":1534:15
      │   ├─z = 9 <N.NNμs>
      │   │ └─"test/test_expect_test.ml":1534:15
      │   └─loop_exceeded = 190 <N.NNμs>
      │     ├─"test/test_expect_test.ml":1529:40-1535:69
      │     ├─<earlier entries truncated>
      │     ├─z = 16 <N.NNμs>
      │     │ └─"test/test_expect_test.ml":1534:15
      │     ├─z = 17 <N.NNμs>
      │     │ └─"test/test_expect_test.ml":1534:15
      │     ├─z = 18 <N.NNμs>
      │     │ └─"test/test_expect_test.ml":1534:15
      │     └─z = 19 <N.NNμs>
      │       └─"test/test_expect_test.ml":1534:15
      ├─z = 5 <N.NNμs>
      │ └─"test/test_expect_test.ml":1534:15
      └─loop_exceeded = 11685 <N.NNμs>
        ├─"test/test_expect_test.ml":1529:40-1535:69
        ├─<earlier entries truncated>
        ├─z = 4 <N.NNμs>
        │ └─"test/test_expect_test.ml":1534:15
        ├─loop_exceeded = 1945 <N.NNμs>
        │ ├─"test/test_expect_test.ml":1529:40-1535:69
        │ ├─<earlier entries truncated>
        │ ├─z = 8 <N.NNμs>
        │ │ └─"test/test_expect_test.ml":1534:15
        │ ├─loop_exceeded = 190 <N.NNμs>
        │ │ ├─"test/test_expect_test.ml":1529:40-1535:69
        │ │ ├─<earlier entries truncated>
        │ │ ├─z = 16 <N.NNμs>
        │ │ │ └─"test/test_expect_test.ml":1534:15
        │ │ ├─z = 17 <N.NNμs>
        │ │ │ └─"test/test_expect_test.ml":1534:15
        │ │ ├─z = 18 <N.NNμs>
        │ │ │ └─"test/test_expect_test.ml":1534:15
        │ │ └─z = 19 <N.NNμs>
        │ │   └─"test/test_expect_test.ml":1534:15
        │ ├─z = 9 <N.NNμs>
        │ │ └─"test/test_expect_test.ml":1534:15
        │ └─loop_exceeded = 190 <N.NNμs>
        │   ├─"test/test_expect_test.ml":1529:40-1535:69
        │   ├─<earlier entries truncated>
        │   ├─z = 16 <N.NNμs>
        │   │ └─"test/test_expect_test.ml":1534:15
        │   ├─z = 17 <N.NNμs>
        │   │ └─"test/test_expect_test.ml":1534:15
        │   ├─z = 18 <N.NNμs>
        │   │ └─"test/test_expect_test.ml":1534:15
        │   └─z = 19 <N.NNμs>
        │     └─"test/test_expect_test.ml":1534:15
        ├─z = 5 <N.NNμs>
        │ └─"test/test_expect_test.ml":1534:15
        └─loop_exceeded = 1945 <N.NNμs>
          ├─"test/test_expect_test.ml":1529:40-1535:69
          ├─<earlier entries truncated>
          ├─z = 8 <N.NNμs>
          │ └─"test/test_expect_test.ml":1534:15
          ├─loop_exceeded = 190 <N.NNμs>
          │ ├─"test/test_expect_test.ml":1529:40-1535:69
          │ ├─<earlier entries truncated>
          │ ├─z = 16 <N.NNμs>
          │ │ └─"test/test_expect_test.ml":1534:15
          │ ├─z = 17 <N.NNμs>
          │ │ └─"test/test_expect_test.ml":1534:15
          │ ├─z = 18 <N.NNμs>
          │ │ └─"test/test_expect_test.ml":1534:15
          │ └─z = 19 <N.NNμs>
          │   └─"test/test_expect_test.ml":1534:15
          ├─z = 9 <N.NNμs>
          │ └─"test/test_expect_test.ml":1534:15
          └─loop_exceeded = 190 <N.NNμs>
            ├─"test/test_expect_test.ml":1529:40-1535:69
            ├─<earlier entries truncated>
            ├─z = 16 <N.NNμs>
            │ └─"test/test_expect_test.ml":1534:15
            ├─z = 17 <N.NNμs>
            │ └─"test/test_expect_test.ml":1534:15
            ├─z = 18 <N.NNμs>
            │ └─"test/test_expect_test.ml":1534:15
            └─z = 19 <N.NNμs>
              └─"test/test_expect_test.ml":1534:15
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
      ├─"test/test_expect_test.ml":1692:41-1694:58
      ├─x = 7
      ├─┬─────┐
      │ │z = 3│
      │ ├─────┘
      │ └─"test/test_expect_test.ml":1693:8
      └─┬──────────────────┐
        │loop_highlight = 6│
        ├──────────────────┘
        ├─"test/test_expect_test.ml":1692:41-1694:58
        ├─x = 6
        ├─z = 2
        │ └─"test/test_expect_test.ml":1693:8
        └─┬──────────────────┐
          │loop_highlight = 4│
          ├──────────────────┘
          ├─"test/test_expect_test.ml":1692:41-1694:58
          ├─x = 5
          ├─z = 2
          │ └─"test/test_expect_test.ml":1693:8
          └─┬──────────────────┐
            │loop_highlight = 2│
            ├──────────────────┘
            ├─"test/test_expect_test.ml":1692:41-1694:58
            ├─x = 4
            ├─z = 1
            │ └─"test/test_expect_test.ml":1693:8
            └─┬──────────────────┐
              │loop_highlight = 1│
              ├──────────────────┘
              ├─"test/test_expect_test.ml":1692:41-1694:58
              ├─┬─────┐
              │ │x = 3│
              │ └─────┘
              ├─z = 1
              │ └─"test/test_expect_test.ml":1693:8
              └─loop_highlight = 0
                ├─"test/test_expect_test.ml":1692:41-1694:58
                ├─x = 2
                ├─z = 0
                │ └─"test/test_expect_test.ml":1693:8
                └─loop_highlight = 0
                  ├─"test/test_expect_test.ml":1692:41-1694:58
                  ├─x = 1
                  ├─z = 0
                  │ └─"test/test_expect_test.ml":1693:8
                  └─loop_highlight = 0
                    ├─"test/test_expect_test.ml":1692:41-1694:58
                    ├─x = 0
                    └─z = 0
                      └─"test/test_expect_test.ml":1693:8
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
      ├─"test/test_expect_test.ml":1758:37-1760:46
      ├─x = 7
      └─<if -- else branch>
        ├─"test/test_expect_test.ml":1760:9
        └─<match -- branch 1>
          └─"test/test_expect_test.ml":1760:36-1760:37
      4
      track_branches = -3
      ├─"test/test_expect_test.ml":1758:37-1760:46
      ├─x = 3
      └─<if -- then branch>
        ├─"test/test_expect_test.ml":1759:18
        └─<match -- branch 2>
          └─"test/test_expect_test.ml":1759:54-1759:57
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
      ├─"test/test_expect_test.ml":1792:32-1793:70
      ├─x = 3
      ├─__fun
      │ ├─"test/test_expect_test.ml":1793:50-1793:70
      │ └─i = 0
      ├─__fun
      │ ├─"test/test_expect_test.ml":1793:50-1793:70
      │ └─i = 1
      ├─__fun
      │ ├─"test/test_expect_test.ml":1793:50-1793:70
      │ └─i = 2
      └─__fun
        ├─"test/test_expect_test.ml":1793:50-1793:70
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
    "test/test_expect_test.ml":1822:21-1825:15: bar
    ├─first = 7
    ├─second = 42
    ├─"test/test_expect_test.ml":1823:8: {first=a; second=b}
    │ ├─a = 7
    │ └─b = 45
    ├─"test/test_expect_test.ml":1824:8: y
    │ └─y = 8
    └─bar = 336
    336
    "test/test_expect_test.ml":1828:10-1830:28: baz
    ├─first = 7
    ├─second = 42
    ├─"test/test_expect_test.ml":1829:8: {first; second}
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
    "test/test_expect_test.ml":1857:21-1859:14: bar
    ├─first = 7
    ├─second = 42
    ├─"test/test_expect_test.ml":1858:8: y
    │ └─y = 8
    └─bar = 336
    336
    "test/test_expect_test.ml":1867:6: (r1, r2)
    ├─"test/test_expect_test.ml":1862:10-1865:35: baz
    │ ├─first = 7
    │ ├─second = 42
    │ ├─"test/test_expect_test.ml":1863:8: (y, z)
    │ │ ├─y = 8
    │ │ └─z = 3
    │ ├─"test/test_expect_test.ml":1864:8: (a, b)
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
    ├─"test/test_expect_test.ml":1937:21-1939:14
    ├─first = 7
    ├─second = 42
    └─y = 8
      └─"test/test_expect_test.ml":1938:8
    336
    (r1, r2)
    ├─"test/test_expect_test.ml":1947:6
    ├─<returns>
    │ ├─r1 = 339
    │ └─r2 = 109
    └─baz = (339, 109)
      ├─"test/test_expect_test.ml":1942:10-1945:35
      ├─first = 7
      ├─second = 42
      ├─(y, z)
      │ ├─"test/test_expect_test.ml":1943:8
      │ └─<values>
      │   ├─y = 8
      │   └─z = 3
      └─(a, b)
        ├─"test/test_expect_test.ml":1944:8
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
      ├─"test/test_expect_test.ml":1988:21-1990:9
      ├─x = 7
      └─y = 8
        └─"test/test_expect_test.ml":1989:8
      16
      baz = 5
      ├─"test/test_expect_test.ml":1994:24-1994:29
      ├─<function -- branch 0> Left x
      └─x = 4
      5
      baz = 6
      ├─"test/test_expect_test.ml":1995:31-1995:36
      ├─<function -- branch 1> Right Two y
      └─y = 3
      6
      foo = 3
      ├─"test/test_expect_test.ml":1998:10-1999:82
      └─<match -- branch 2>
        └─"test/test_expect_test.ml":1999:81-1999:82
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
    ├─"test/test_expect_test.ml":2036:6
    ├─<returns>
    │ ├─r1 = 339
    │ └─r2 = 109
    └─baz = (339, 109)
      ├─"test/test_expect_test.ml":2031:21-2034:35
      ├─first = 7
      ├─second = 42
      ├─(y, z)
      │ ├─"test/test_expect_test.ml":2032:8
      │ └─<values>
      │   ├─y = 8
      │   └─z = 3
      └─a = 8
        └─"test/test_expect_test.ml":2033:8
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
    ├─"test/test_expect_test.ml":2064:44-2064:61
    └─b = 6
    7
    g = 12
    ├─"test/test_expect_test.ml":2065:56-2065:79
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
      ├─"test/test_expect_test.ml":2084:37-2084:54
      ├─f : int
      └─b : int = 6
      7
      g : int = 12
      ├─"test/test_expect_test.ml":2085:49-2085:72
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
      ├─"test/test_expect_test.ml":2104:21-2105:59
      └─<match -- branch 1> Some y
        ├─"test/test_expect_test.ml":2105:54-2105:59
        └─y = 7
      14
      bar = 14
      ├─"test/test_expect_test.ml":2108:10-2108:75
      ├─l = (Some 7)
      └─<match -- branch 1> Some y
        └─"test/test_expect_test.ml":2108:70-2108:75
      14
      baz = 8
      ├─"test/test_expect_test.ml":2110:63-2110:68
      ├─<function -- branch 1> Some y
      └─y = 4
      8
      zoo = 9
      ├─"test/test_expect_test.ml":2112:76-2112:81
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
      ├─"test/test_expect_test.ml":2143:21-2143:82
      └─<match -- branch 1> :: (y, _)
        ├─"test/test_expect_test.ml":2143:77-2143:82
        └─y = 7
      14
      bar = 14
      ├─"test/test_expect_test.ml":2145:10-2145:71
      ├─l = [7]
      └─<match -- branch 1> :: (y, _)
        └─"test/test_expect_test.ml":2145:66-2145:71
      14
      baz = 8
      ├─"test/test_expect_test.ml":2149:15-2149:20
      ├─<function -- branch 1> :: (y, [])
      └─y = 4
      8
      baz = 9
      ├─"test/test_expect_test.ml":2150:18-2150:23
      ├─<function -- branch 2> :: (y, :: (z, []))
      ├─y = 4
      └─z = 5
      9
      baz = 10
      ├─"test/test_expect_test.ml":2151:21-2151:30
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
      ├─"test/test_expect_test.ml":2190:25-2191:55
      └─foo-1 <match -- branch 1> :: (y, _)
        ├─"test/test_expect_test.ml":2191:50-2191:55
        └─y = 7
      14

      BEGIN DEBUG SESSION baz-1
      baz = 8
      ├─"test/test_expect_test.ml":2201:15-2201:20
      ├─baz-1 <function -- branch 1> :: (y, [])
      └─y = 4
      8

      BEGIN DEBUG SESSION baz-2
      baz = 10
      ├─"test/test_expect_test.ml":2203:21-2203:30
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
      bar-1 bar begin "test/test_expect_test.ml":2243:24-2243:46
       bar-1 __fun begin "test/test_expect_test.ml":2243:29-2243:43
       bar-1 __fun end
      bar-1 bar end

      BEGIN DEBUG SESSION bar-2
      bar-2 bar begin "test/test_expect_test.ml":2243:24-2243:46
       bar-2 __fun begin "test/test_expect_test.ml":2243:29-2243:43
       bar-2 __fun end
      bar-2 bar end

      BEGIN DEBUG SESSION foo-1
      foo-1 foo begin "test/test_expect_test.ml":2246:24-2248:6
      foo-1 foo end

      BEGIN DEBUG SESSION foo-2
      foo-2 foo begin "test/test_expect_test.ml":2246:24-2248:6
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
      └─"test/test_expect_test.ml":2276:25-2282:14

      BEGIN DEBUG SESSION foo-1
      foo-1 foo begin "test/test_expect_test.ml":2278:26-2280:8
      foo-1 foo end

      BEGIN DEBUG SESSION foo-2
      foo-2 foo begin "test/test_expect_test.ml":2278:26-2280:8
      foo-2 foo end

      BEGIN DEBUG SESSION bar-1
      bar-1 bar begin "test/test_expect_test.ml":2277:26-2277:48
       bar-1 __fun begin "test/test_expect_test.ml":2277:31-2277:45
       bar-1 __fun end
      bar-1 bar end

      BEGIN DEBUG SESSION bar-2
      bar-2 bar begin "test/test_expect_test.ml":2277:26-2277:48
       bar-2 __fun begin "test/test_expect_test.ml":2277:31-2277:45
       bar-2 __fun end
      bar-2 bar end |}]

let%expect_test "%log constant entries" =
  let module Debug_runtime = (val Minidebug_runtime.debug ~values_first_mode:true ()) in
  let%debug_show foo () : unit =
    [%log "This is the first log line"];
    [%log [ "This is the"; "2"; "log line" ]];
    [%log "This is the", 3, "or", 3.14, "log line"]
  in
  let () = foo () in
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
      ├─"test/test_expect_test.ml":2317:21-2320:51
      ├─"This is the first log line"
      ├─["This is the"; "2"; "log line"]
      └─("This is the", 3, "or", 3.14, "log line")
      bar = ()
      ├─"test/test_expect_test.ml":2323:21-2326:51
      ├─"This is the first log line"
      ├─("This is the" 2 "log line")
      └─("This is the" 3 or 3.14 "log line") |}]

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
          ├─"test/test_expect_test.ml":2348:21-2353:25
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
          ├─"test/test_expect_test.ml":2373:21-2380:25
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
    "test/test_expect_test.ml":2398:4: <while loop>
    ├─"test/test_expect_test.ml":2399:6: <while loop>
    │ ├─(1 i= 0)
    │ ├─(2 i= 1)
    │ └─(3 j= 1)
    ├─"test/test_expect_test.ml":2399:6: <while loop>
    │ ├─(1 i= 1)
    │ ├─(2 i= 2)
    │ └─(3 j= 3)
    ├─"test/test_expect_test.ml":2399:6: <while loop>
    │ ├─(1 i= 2)
    │ ├─(2 i= 3)
    │ └─(3 j= 6)
    ├─"test/test_expect_test.ml":2399:6: <while loop>
    │ ├─(1 i= 3)
    │ ├─(2 i= 4)
    │ └─(3 j= 10)
    ├─"test/test_expect_test.ml":2399:6: <while loop>
    │ ├─(1 i= 4)
    │ ├─(2 i= 5)
    │ └─(3 j= 15)
    └─"test/test_expect_test.ml":2399:6: <while loop>
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
  "test/test_expect_test.ml":2440:28-2451:6: Everything result
  ├─"test/test_expect_test.ml":2443:4: Everything <while loop>
  │ ├─"test/test_expect_test.ml":2445:6: Everything <while loop>
  │ │ ├─"test/test_expect_test.ml":2445:21: Everything <if -- then branch>
  │ │ │ └─(ERROR: 1 i= 0)
  │ │ ├─(WARNING: 2 i= 1)
  │ │ ├─"test/test_expect_test.ml":2448:11-2448:46: Everything __fun
  │ │ └─(INFO: 3 j= 1)
  │ ├─"test/test_expect_test.ml":2445:6: Everything <while loop>
  │ │ ├─"test/test_expect_test.ml":2445:21: Everything <if -- then branch>
  │ │ │ └─(ERROR: 1 i= 1)
  │ │ ├─(WARNING: 2 i= 2)
  │ │ ├─"test/test_expect_test.ml":2448:11-2448:46: Everything __fun
  │ │ └─(INFO: 3 j= 3)
  │ ├─"test/test_expect_test.ml":2445:6: Everything <while loop>
  │ │ ├─"test/test_expect_test.ml":2445:63: Everything <if -- else branch>
  │ │ ├─(WARNING: 2 i= 3)
  │ │ ├─"test/test_expect_test.ml":2448:11-2448:46: Everything __fun
  │ │ └─(INFO: 3 j= 6)
  │ ├─"test/test_expect_test.ml":2445:6: Everything <while loop>
  │ │ ├─"test/test_expect_test.ml":2445:63: Everything <if -- else branch>
  │ │ ├─(WARNING: 2 i= 4)
  │ │ ├─"test/test_expect_test.ml":2448:11-2448:46: Everything __fun
  │ │ └─(INFO: 3 j= 10)
  │ ├─"test/test_expect_test.ml":2445:6: Everything <while loop>
  │ │ ├─"test/test_expect_test.ml":2445:63: Everything <if -- else branch>
  │ │ ├─(WARNING: 2 i= 5)
  │ │ ├─"test/test_expect_test.ml":2448:11-2448:46: Everything __fun
  │ │ └─(INFO: 3 j= 15)
  │ └─"test/test_expect_test.ml":2445:6: Everything <while loop>
  │   ├─"test/test_expect_test.ml":2445:63: Everything <if -- else branch>
  │   ├─(WARNING: 2 i= 6)
  │   ├─"test/test_expect_test.ml":2448:11-2448:46: Everything __fun
  │   └─(INFO: 3 j= 21)
  └─result = 21
  21

  BEGIN DEBUG SESSION Nothing
  21

  BEGIN DEBUG SESSION Nonempty
  result = 21
  ├─"test/test_expect_test.ml":2440:28-2451:6
  └─Nonempty <while loop>
    ├─"test/test_expect_test.ml":2443:4
    ├─Nonempty <while loop>
    │ ├─"test/test_expect_test.ml":2445:6
    │ ├─Nonempty <if -- then branch>
    │ │ ├─"test/test_expect_test.ml":2445:21
    │ │ └─(ERROR: 1 i= 0)
    │ ├─(WARNING: 2 i= 1)
    │ └─(INFO: 3 j= 1)
    ├─Nonempty <while loop>
    │ ├─"test/test_expect_test.ml":2445:6
    │ ├─Nonempty <if -- then branch>
    │ │ ├─"test/test_expect_test.ml":2445:21
    │ │ └─(ERROR: 1 i= 1)
    │ ├─(WARNING: 2 i= 2)
    │ └─(INFO: 3 j= 3)
    ├─Nonempty <while loop>
    │ ├─"test/test_expect_test.ml":2445:6
    │ ├─(WARNING: 2 i= 3)
    │ └─(INFO: 3 j= 6)
    ├─Nonempty <while loop>
    │ ├─"test/test_expect_test.ml":2445:6
    │ ├─(WARNING: 2 i= 4)
    │ └─(INFO: 3 j= 10)
    ├─Nonempty <while loop>
    │ ├─"test/test_expect_test.ml":2445:6
    │ ├─(WARNING: 2 i= 5)
    │ └─(INFO: 3 j= 15)
    └─Nonempty <while loop>
      ├─"test/test_expect_test.ml":2445:6
      ├─(WARNING: 2 i= 6)
      └─(INFO: 3 j= 21)
  21

  BEGIN DEBUG SESSION Prefixed
  Prefixed result
  ├─"test/test_expect_test.ml":2440:28-2451:6
  └─Prefixed <while loop>
    ├─"test/test_expect_test.ml":2443:4
    ├─Prefixed <while loop>
    │ ├─"test/test_expect_test.ml":2445:6
    │ ├─Prefixed <if -- then branch>
    │ │ ├─"test/test_expect_test.ml":2445:21
    │ │ └─(ERROR: 1 i= 0)
    │ └─(WARNING: 2 i= 1)
    ├─Prefixed <while loop>
    │ ├─"test/test_expect_test.ml":2445:6
    │ ├─Prefixed <if -- then branch>
    │ │ ├─"test/test_expect_test.ml":2445:21
    │ │ └─(ERROR: 1 i= 1)
    │ └─(WARNING: 2 i= 2)
    ├─Prefixed <while loop>
    │ ├─"test/test_expect_test.ml":2445:6
    │ └─(WARNING: 2 i= 3)
    ├─Prefixed <while loop>
    │ ├─"test/test_expect_test.ml":2445:6
    │ └─(WARNING: 2 i= 4)
    ├─Prefixed <while loop>
    │ ├─"test/test_expect_test.ml":2445:6
    │ └─(WARNING: 2 i= 5)
    └─Prefixed <while loop>
      ├─"test/test_expect_test.ml":2445:6
      └─(WARNING: 2 i= 6)
  21

  BEGIN DEBUG SESSION Prefixed_or_result
  result = 21
  ├─"test/test_expect_test.ml":2440:28-2451:6
  └─Prefixed_or_result <while loop>
    ├─"test/test_expect_test.ml":2443:4
    ├─Prefixed_or_result <while loop>
    │ ├─"test/test_expect_test.ml":2445:6
    │ ├─Prefixed_or_result <if -- then branch>
    │ │ ├─"test/test_expect_test.ml":2445:21
    │ │ └─(ERROR: 1 i= 0)
    │ └─(WARNING: 2 i= 1)
    ├─Prefixed_or_result <while loop>
    │ ├─"test/test_expect_test.ml":2445:6
    │ ├─Prefixed_or_result <if -- then branch>
    │ │ ├─"test/test_expect_test.ml":2445:21
    │ │ └─(ERROR: 1 i= 1)
    │ └─(WARNING: 2 i= 2)
    ├─Prefixed_or_result <while loop>
    │ ├─"test/test_expect_test.ml":2445:6
    │ └─(WARNING: 2 i= 3)
    ├─Prefixed_or_result <while loop>
    │ ├─"test/test_expect_test.ml":2445:6
    │ └─(WARNING: 2 i= 4)
    ├─Prefixed_or_result <while loop>
    │ ├─"test/test_expect_test.ml":2445:6
    │ └─(WARNING: 2 i= 5)
    └─Prefixed_or_result <while loop>
      ├─"test/test_expect_test.ml":2445:6
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
  ├─"test/test_expect_test.ml":2626:28-2639:9
  └─<while loop>
    ├─"test/test_expect_test.ml":2631:6
    ├─<while loop>
    │ ├─"test/test_expect_test.ml":2633:8
    │ ├─<if -- then branch>
    │ │ ├─"test/test_expect_test.ml":2633:23
    │ │ └─(ERROR: 1 i= 0)
    │ ├─(WARNING: 2 i= 1)
    │ ├─__fun
    │ │ └─"test/test_expect_test.ml":2636:13-2636:48
    │ └─(INFO: 3 j= 1)
    ├─<while loop>
    │ ├─"test/test_expect_test.ml":2633:8
    │ ├─<if -- then branch>
    │ │ ├─"test/test_expect_test.ml":2633:23
    │ │ └─(ERROR: 1 i= 1)
    │ ├─(WARNING: 2 i= 2)
    │ ├─__fun
    │ │ └─"test/test_expect_test.ml":2636:13-2636:48
    │ └─(INFO: 3 j= 3)
    ├─<while loop>
    │ ├─"test/test_expect_test.ml":2633:8
    │ ├─<if -- else branch>
    │ │ └─"test/test_expect_test.ml":2633:65
    │ ├─(WARNING: 2 i= 3)
    │ ├─__fun
    │ │ └─"test/test_expect_test.ml":2636:13-2636:48
    │ └─(INFO: 3 j= 6)
    ├─<while loop>
    │ ├─"test/test_expect_test.ml":2633:8
    │ ├─<if -- else branch>
    │ │ └─"test/test_expect_test.ml":2633:65
    │ ├─(WARNING: 2 i= 4)
    │ ├─__fun
    │ │ └─"test/test_expect_test.ml":2636:13-2636:48
    │ └─(INFO: 3 j= 10)
    ├─<while loop>
    │ ├─"test/test_expect_test.ml":2633:8
    │ ├─<if -- else branch>
    │ │ └─"test/test_expect_test.ml":2633:65
    │ ├─(WARNING: 2 i= 5)
    │ ├─__fun
    │ │ └─"test/test_expect_test.ml":2636:13-2636:48
    │ └─(INFO: 3 j= 15)
    └─<while loop>
      ├─"test/test_expect_test.ml":2633:8
      ├─<if -- else branch>
      │ └─"test/test_expect_test.ml":2633:65
      ├─(WARNING: 2 i= 6)
      ├─__fun
      │ └─"test/test_expect_test.ml":2636:13-2636:48
      └─(INFO: 3 j= 21)
  21
  nothing = 21
  └─"test/test_expect_test.ml":2641:25-2655:9
  21
  prefixed = 21
  ├─"test/test_expect_test.ml":2657:26-2670:9
  └─<while loop>
    ├─"test/test_expect_test.ml":2662:6
    ├─<while loop>
    │ ├─"test/test_expect_test.ml":2664:8
    │ ├─<if -- then branch>
    │ │ ├─"test/test_expect_test.ml":2664:23
    │ │ └─(ERROR: 1 i= 0)
    │ └─(WARNING: 2 i= 1)
    ├─<while loop>
    │ ├─"test/test_expect_test.ml":2664:8
    │ ├─<if -- then branch>
    │ │ ├─"test/test_expect_test.ml":2664:23
    │ │ └─(ERROR: 1 i= 1)
    │ └─(WARNING: 2 i= 2)
    ├─<while loop>
    │ ├─"test/test_expect_test.ml":2664:8
    │ └─(WARNING: 2 i= 3)
    ├─<while loop>
    │ ├─"test/test_expect_test.ml":2664:8
    │ └─(WARNING: 2 i= 4)
    ├─<while loop>
    │ ├─"test/test_expect_test.ml":2664:8
    │ └─(WARNING: 2 i= 5)
    └─<while loop>
      ├─"test/test_expect_test.ml":2664:8
      └─(WARNING: 2 i= 6)
  21
      |}]

let%expect_test "%log compile time log levels runtime-passing while-loop" =
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
  BEGIN DEBUG SESSION nothing
  21

  BEGIN DEBUG SESSION prefixed
  prefixed = 21
  ├─"test/test_expect_test.ml":2790:34-2801:10
  └─prefixed <while loop>
    ├─"test/test_expect_test.ml":2793:8
    ├─prefixed <while loop>
    │ ├─"test/test_expect_test.ml":2795:10
    │ ├─prefixed <if -- then branch>
    │ │ ├─"test/test_expect_test.ml":2795:25
    │ │ └─(ERROR: 1 i= 0)
    │ └─(WARNING: 2 i= 1)
    ├─prefixed <while loop>
    │ ├─"test/test_expect_test.ml":2795:10
    │ ├─prefixed <if -- then branch>
    │ │ ├─"test/test_expect_test.ml":2795:25
    │ │ └─(ERROR: 1 i= 1)
    │ └─(WARNING: 2 i= 2)
    ├─prefixed <while loop>
    │ ├─"test/test_expect_test.ml":2795:10
    │ └─(WARNING: 2 i= 3)
    ├─prefixed <while loop>
    │ ├─"test/test_expect_test.ml":2795:10
    │ └─(WARNING: 2 i= 4)
    ├─prefixed <while loop>
    │ ├─"test/test_expect_test.ml":2795:10
    │ └─(WARNING: 2 i= 5)
    └─prefixed <while loop>
      ├─"test/test_expect_test.ml":2795:10
      └─(WARNING: 2 i= 6)
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
          "test/test_expect_test.ml":2853:17: {#1} _bar
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
          └─"test/test_expect_test.ml":2887:17: {#1}
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
          └─"test/test_expect_test.ml":2923:21-2928:19: {#1}
          baz = ()
          └─"test/test_expect_test.ml":2930:21-2935:19: {#2}
          bar = ()
          └─"test/test_expect_test.ml":2923:21-2928:19: {#3}
          _foobar = ()
          ├─"test/test_expect_test.ml":2942:17: {#4}
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
  let%diagn_show bar { first : int; second : int } : int =
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
  let () = print_endline @@ Int.to_string @@ baz { first = 7; second = 42 } in
  [%expect
    {|
      BEGIN DEBUG SESSION
      bar
      ├─"test/test_expect_test.ml":2972:21-2976:15
      └─("for bar, b-3", 42)
      336
      baz
      ├─"test/test_expect_test.ml":2979:10-2982:28
      └─("for baz, f squared", 64)
      109 |}]

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
      bar = 336
      ├─"test/test_expect_test.ml":3002:14-3006:19
      ├─{first=a; second=b}
      │ ├─"test/test_expect_test.ml":3003:12
      │ └─<values>
      │   ├─a = 7
      │   └─b = 45
      ├─y = 8
      │ └─"test/test_expect_test.ml":3004:12
      └─("for bar, b-3", 42)
      336
      baz = 109
      ├─"test/test_expect_test.ml":3008:14-3011:32
      ├─{first; second}
      │ ├─"test/test_expect_test.ml":3009:12
      │ └─<values>
      │   ├─first = 8
      │   └─second = 45
      └─("for baz, f squared", 64)
      109 |}]
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
        bar = 336
        ├─"test/test_expect_test.ml":3073:14-3077:19
        └─("for bar, b-3", 42)
        336
        baz = 109
        ├─"test/test_expect_test.ml":3079:14-3082:32
        └─("for baz, f squared", 64)
        109 |}]


let%expect_test "%debug_this_show PrintBox snapshot" =
  let module Debug_runtime =
    (val Minidebug_runtime.debug ~values_first_mode:true ())
  in
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
      ├─"test/test_expect_test.ml":3104:41-3107:58
      ├─x = 7
      └─z = 3
        └─"test/test_expect_test.ml":3105:8
      [2J[1;1Hloop_highlight
      ├─"test/test_expect_test.ml":3104:41-3107:58
      ├─x = 7
      ├─z = 3
      │ └─"test/test_expect_test.ml":3105:8
      └─loop_highlight
        ├─"test/test_expect_test.ml":3104:41-3107:58
        ├─x = 6
        ├─z = 2
        │ └─"test/test_expect_test.ml":3105:8
        └─loop_highlight
          ├─"test/test_expect_test.ml":3104:41-3107:58
          ├─x = 5
          ├─z = 2
          │ └─"test/test_expect_test.ml":3105:8
          └─loop_highlight
            ├─"test/test_expect_test.ml":3104:41-3107:58
            ├─x = 4
            ├─z = 1
            │ └─"test/test_expect_test.ml":3105:8
            └─loop_highlight
              ├─"test/test_expect_test.ml":3104:41-3107:58
              ├─x = 3
              └─z = 1
                └─"test/test_expect_test.ml":3105:8
      [2J[1;1Hloop_highlight = 9
      ├─"test/test_expect_test.ml":3104:41-3107:58
      ├─x = 7
      ├─z = 3
      │ └─"test/test_expect_test.ml":3105:8
      └─loop_highlight = 6
        ├─"test/test_expect_test.ml":3104:41-3107:58
        ├─x = 6
        ├─z = 2
        │ └─"test/test_expect_test.ml":3105:8
        └─loop_highlight = 4
          ├─"test/test_expect_test.ml":3104:41-3107:58
          ├─x = 5
          ├─z = 2
          │ └─"test/test_expect_test.ml":3105:8
          └─loop_highlight = 2
            ├─"test/test_expect_test.ml":3104:41-3107:58
            ├─x = 4
            ├─z = 1
            │ └─"test/test_expect_test.ml":3105:8
            └─loop_highlight = 1
              ├─"test/test_expect_test.ml":3104:41-3107:58
              ├─x = 3
              ├─z = 1
              │ └─"test/test_expect_test.ml":3105:8
              └─loop_highlight = 0
                ├─"test/test_expect_test.ml":3104:41-3107:58
                ├─x = 2
                ├─z = 0
                │ └─"test/test_expect_test.ml":3105:8
                └─loop_highlight = 0
                  ├─"test/test_expect_test.ml":3104:41-3107:58
                  ├─x = 1
                  ├─z = 0
                  │ └─"test/test_expect_test.ml":3105:8
                  └─loop_highlight = 0
                    ├─"test/test_expect_test.ml":3104:41-3107:58
                    ├─x = 0
                    └─z = 0
                      └─"test/test_expect_test.ml":3105:8
      9 |}]
