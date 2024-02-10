type t = { first : int; second : int } [@@deriving show]

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
    YYYY-MM-DD HH:MM:SS.NNNNNN - bar begin "test/test_expect_test.ml":22:21-24:16
     x = { Test_expect_test.first = 7; second = 42 }
      "test/test_expect_test.ml":23:8: y
      y = 8
     bar = 336
    YYYY-MM-DD HH:MM:SS.NNNNNN - bar end
    336
    YYYY-MM-DD HH:MM:SS.NNNNNN - baz begin "test/test_expect_test.ml":27:10-29:22
     x = { Test_expect_test.first = 7; second = 42 }
      "test/test_expect_test.ml":28:19: _yz
      _yz = (8, 3)
     baz = 339
    YYYY-MM-DD HH:MM:SS.NNNNNN - baz end
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
    test-51 bar begin "test/test_expect_test.ml":62:21-64:16
     x = { Test_expect_test.first = 7; second = 42 }
      "test/test_expect_test.ml":63:8: test-51 y
      y = 8
     bar = 336
    test-51 bar end
    336
    test-51 baz begin "test/test_expect_test.ml":67:10-69:22
     x = { Test_expect_test.first = 7; second = 42 }
      "test/test_expect_test.ml":68:19: test-51 _yz
      _yz = (8, 3)
     baz = 339
    test-51 baz end
    339 |}]

let%expect_test "%debug_this_show PrintBox to stdout disabled subtree" =
  let module Debug_runtime = (val Minidebug_runtime.debug ()) in
  let%debug_this_show rec loop_complete (x : int) : int =
    let z : int = (x - 1) / 2 in
    if x <= 0 then 0 else z + loop_complete (z + (x / 2))
  in
  let () = print_endline @@ Int.to_string @@ loop_complete 7 in
  [%expect
    {|
    BEGIN DEBUG SESSION
    "test/test_expect_test.ml":94:40-96:57: loop_complete
    ├─x = 7
    ├─"test/test_expect_test.ml":95:8: z
    │ └─z = 3
    ├─"test/test_expect_test.ml":94:40-96:57: loop_complete
    │ ├─x = 6
    │ ├─"test/test_expect_test.ml":95:8: z
    │ │ └─z = 2
    │ ├─"test/test_expect_test.ml":94:40-96:57: loop_complete
    │ │ ├─x = 5
    │ │ ├─"test/test_expect_test.ml":95:8: z
    │ │ │ └─z = 2
    │ │ ├─"test/test_expect_test.ml":94:40-96:57: loop_complete
    │ │ │ ├─x = 4
    │ │ │ ├─"test/test_expect_test.ml":95:8: z
    │ │ │ │ └─z = 1
    │ │ │ ├─"test/test_expect_test.ml":94:40-96:57: loop_complete
    │ │ │ │ ├─x = 3
    │ │ │ │ ├─"test/test_expect_test.ml":95:8: z
    │ │ │ │ │ └─z = 1
    │ │ │ │ ├─"test/test_expect_test.ml":94:40-96:57: loop_complete
    │ │ │ │ │ ├─x = 2
    │ │ │ │ │ ├─"test/test_expect_test.ml":95:8: z
    │ │ │ │ │ │ └─z = 0
    │ │ │ │ │ ├─"test/test_expect_test.ml":94:40-96:57: loop_complete
    │ │ │ │ │ │ ├─x = 1
    │ │ │ │ │ │ ├─"test/test_expect_test.ml":95:8: z
    │ │ │ │ │ │ │ └─z = 0
    │ │ │ │ │ │ ├─"test/test_expect_test.ml":94:40-96:57: loop_complete
    │ │ │ │ │ │ │ ├─x = 0
    │ │ │ │ │ │ │ ├─"test/test_expect_test.ml":95:8: z
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
  "test/test_expect_test.ml":143:39-147:56: loop_changes
  ├─x = 7
  ├─"test/test_expect_test.ml":144:8: z
  │ └─z = 3
  ├─"test/test_expect_test.ml":143:39-147:56: loop_changes
  │ ├─x = 6
  │ ├─"test/test_expect_test.ml":144:8: z
  │ │ └─z = 2
  │ ├─"test/test_expect_test.ml":143:39-147:56: loop_changes
  │ │ ├─x = 5
  │ │ ├─"test/test_expect_test.ml":144:8: z
  │ │ │ └─z = 2
  │ │ └─loop_changes = 4
  │ └─loop_changes = 6
  └─loop_changes = 9
  9 |}]

let%expect_test "%debug_this_show PrintBox to stdout with exception" =
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
    "test/test_expect_test.ml":171:41-174:36: loop_truncated
    ├─x = 7
    ├─"test/test_expect_test.ml":172:8: z
    │ └─z = 3
    └─"test/test_expect_test.ml":171:41-174:36: loop_truncated
      ├─x = 6
      ├─"test/test_expect_test.ml":172:8: z
      │ └─z = 2
      └─"test/test_expect_test.ml":171:41-174:36: loop_truncated
        ├─x = 5
        ├─"test/test_expect_test.ml":172:8: z
        │ └─z = 2
        └─"test/test_expect_test.ml":171:41-174:36: loop_truncated
          ├─x = 4
          ├─"test/test_expect_test.ml":172:8: z
          │ └─z = 1
          └─"test/test_expect_test.ml":171:41-174:36: loop_truncated
            ├─x = 3
            ├─"test/test_expect_test.ml":172:8: z
            │ └─z = 1
            └─"test/test_expect_test.ml":171:41-174:36: loop_truncated
              ├─x = 2
              ├─"test/test_expect_test.ml":172:8: z
              │ └─z = 0
              └─"test/test_expect_test.ml":171:41-174:36: loop_truncated
                ├─x = 1
                ├─"test/test_expect_test.ml":172:8: z
                │ └─z = 0
                └─"test/test_expect_test.ml":171:41-174:36: loop_truncated
                  ├─x = 0
                  └─"test/test_expect_test.ml":172:8: z
                    └─z = 0
    Raised exception. |}]

let%expect_test "%debug_this_show PrintBox to stdout depth exceeded" =
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
      "test/test_expect_test.ml":219:40-223:60: loop_exceeded
      ├─x = 7
      ├─"test/test_expect_test.ml":222:10: z
      │ └─z = 3
      └─"test/test_expect_test.ml":219:40-223:60: loop_exceeded
        ├─x = 6
        ├─"test/test_expect_test.ml":222:10: z
        │ └─z = 2
        └─"test/test_expect_test.ml":219:40-223:60: loop_exceeded
          ├─x = 5
          ├─"test/test_expect_test.ml":222:10: z
          │ └─z = 2
          └─"test/test_expect_test.ml":219:40-223:60: loop_exceeded
            ├─x = 4
            ├─"test/test_expect_test.ml":222:10: z
            │ └─z = 1
            └─"test/test_expect_test.ml":219:40-223:60: loop_exceeded
              ├─x = 3
              └─"test/test_expect_test.ml":222:10: z
                └─z = <max_nesting_depth exceeded>
      Raised exception. |}]

let%expect_test "%debug_this_show PrintBox to stdout num children exceeded linear" =
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
    "test/test_expect_test.ml":258:26: _bar
    ├─"test/test_expect_test.ml":262:16: _baz
    │ └─_baz = 0
    ├─"test/test_expect_test.ml":262:16: _baz
    │ └─_baz = 2
    ├─"test/test_expect_test.ml":262:16: _baz
    │ └─_baz = 4
    ├─"test/test_expect_test.ml":262:16: _baz
    │ └─_baz = 6
    ├─"test/test_expect_test.ml":262:16: _baz
    │ └─_baz = 8
    ├─"test/test_expect_test.ml":262:16: _baz
    │ └─_baz = 10
    ├─"test/test_expect_test.ml":262:16: _baz
    │ └─_baz = 12
    ├─"test/test_expect_test.ml":262:16: _baz
    │ └─_baz = 14
    ├─"test/test_expect_test.ml":262:16: _baz
    │ └─_baz = 16
    ├─"test/test_expect_test.ml":262:16: _baz
    │ └─_baz = 18
    ├─"test/test_expect_test.ml":262:16: _baz
    │ └─_baz = 20
    └─_baz = <max_num_children exceeded>
    Raised exception: ppx_minidebug: max_num_children exceeded |}]

let%expect_test "%debug_this_show PrintBox to stdout truncated children linear" =
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
    "test/test_expect_test.ml":302:26: _bar
    ├─<earlier entries truncated>
    ├─"test/test_expect_test.ml":304:14: _baz
    │ └─_baz = 44
    ├─"test/test_expect_test.ml":304:14: _baz
    │ └─_baz = 46
    ├─"test/test_expect_test.ml":304:14: _baz
    │ └─_baz = 48
    ├─"test/test_expect_test.ml":304:14: _baz
    │ └─_baz = 50
    ├─"test/test_expect_test.ml":304:14: _baz
    │ └─_baz = 52
    ├─"test/test_expect_test.ml":304:14: _baz
    │ └─_baz = 54
    ├─"test/test_expect_test.ml":304:14: _baz
    │ └─_baz = 56
    ├─"test/test_expect_test.ml":304:14: _baz
    │ └─_baz = 58
    ├─"test/test_expect_test.ml":304:14: _baz
    │ └─_baz = 60
    └─_bar = () |}]

let%expect_test "%track_this_show PrintBox to stdout track for-loop num children exceeded"
    =
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
    "test/test_expect_test.ml":341:26: _bar
    └─"test/test_expect_test.ml":344:10: <for loop>
      ├─i = 0
      ├─"test/test_expect_test.ml":344:14: <for i>
      │ └─"test/test_expect_test.ml":345:16: _baz
      │   └─_baz = 0
      ├─i = 1
      ├─"test/test_expect_test.ml":344:14: <for i>
      │ └─"test/test_expect_test.ml":345:16: _baz
      │   └─_baz = 2
      ├─i = 2
      ├─"test/test_expect_test.ml":344:14: <for i>
      │ └─"test/test_expect_test.ml":345:16: _baz
      │   └─_baz = 4
      ├─i = 3
      ├─"test/test_expect_test.ml":344:14: <for i>
      │ └─"test/test_expect_test.ml":345:16: _baz
      │   └─_baz = 6
      ├─i = 4
      ├─"test/test_expect_test.ml":344:14: <for i>
      │ └─"test/test_expect_test.ml":345:16: _baz
      │   └─_baz = 8
      ├─i = 5
      └─i = <max_num_children exceeded>
    Raised exception: ppx_minidebug: max_num_children exceeded |}]

let%expect_test "%track_this_show PrintBox to stdout track for-loop truncated children" =
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
    "test/test_expect_test.ml":385:26: _bar
    ├─"test/test_expect_test.ml":386:8: <for loop>
    │ ├─<earlier entries truncated>
    │ ├─i = 26
    │ ├─"test/test_expect_test.ml":386:12: <for i>
    │ │ └─"test/test_expect_test.ml":387:14: _baz
    │ │   └─_baz = 52
    │ ├─i = 27
    │ ├─"test/test_expect_test.ml":386:12: <for i>
    │ │ └─"test/test_expect_test.ml":387:14: _baz
    │ │   └─_baz = 54
    │ ├─i = 28
    │ ├─"test/test_expect_test.ml":386:12: <for i>
    │ │ └─"test/test_expect_test.ml":387:14: _baz
    │ │   └─_baz = 56
    │ ├─i = 29
    │ ├─"test/test_expect_test.ml":386:12: <for i>
    │ │ └─"test/test_expect_test.ml":387:14: _baz
    │ │   └─_baz = 58
    │ ├─i = 30
    │ └─"test/test_expect_test.ml":386:12: <for i>
    │   └─"test/test_expect_test.ml":387:14: _baz
    │     └─_baz = 60
    └─_bar = () |}]

let%expect_test "%track_this_show PrintBox to stdout track for-loop" =
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
      "test/test_expect_test.ml":426:26: _bar
      ├─"test/test_expect_test.ml":429:10: <for loop>
      │ ├─i = 0
      │ ├─"test/test_expect_test.ml":429:14: <for i>
      │ │ └─"test/test_expect_test.ml":430:16: _baz
      │ │   └─_baz = 0
      │ ├─i = 1
      │ ├─"test/test_expect_test.ml":429:14: <for i>
      │ │ └─"test/test_expect_test.ml":430:16: _baz
      │ │   └─_baz = 2
      │ ├─i = 2
      │ ├─"test/test_expect_test.ml":429:14: <for i>
      │ │ └─"test/test_expect_test.ml":430:16: _baz
      │ │   └─_baz = 4
      │ ├─i = 3
      │ ├─"test/test_expect_test.ml":429:14: <for i>
      │ │ └─"test/test_expect_test.ml":430:16: _baz
      │ │   └─_baz = 6
      │ ├─i = 4
      │ ├─"test/test_expect_test.ml":429:14: <for i>
      │ │ └─"test/test_expect_test.ml":430:16: _baz
      │ │   └─_baz = 8
      │ ├─i = 5
      │ ├─"test/test_expect_test.ml":429:14: <for i>
      │ │ └─"test/test_expect_test.ml":430:16: _baz
      │ │   └─_baz = 10
      │ ├─i = 6
      │ └─"test/test_expect_test.ml":429:14: <for i>
      │   └─"test/test_expect_test.ml":430:16: _baz
      │     └─_baz = 12
      └─_bar = () |}]

let%expect_test "%track_this_show PrintBox to stdout track while-loop" =
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
    "test/test_expect_test.ml":476:26: _bar
    ├─"test/test_expect_test.ml":478:8: <while loop>
    │ ├─"test/test_expect_test.ml":479:10: <while loop>
    │ │ └─"test/test_expect_test.ml":479:14: _baz
    │ │   └─_baz = 0
    │ ├─"test/test_expect_test.ml":479:10: <while loop>
    │ │ └─"test/test_expect_test.ml":479:14: _baz
    │ │   └─_baz = 2
    │ ├─"test/test_expect_test.ml":479:10: <while loop>
    │ │ └─"test/test_expect_test.ml":479:14: _baz
    │ │   └─_baz = 4
    │ ├─"test/test_expect_test.ml":479:10: <while loop>
    │ │ └─"test/test_expect_test.ml":479:14: _baz
    │ │   └─_baz = 6
    │ ├─"test/test_expect_test.ml":479:10: <while loop>
    │ │ └─"test/test_expect_test.ml":479:14: _baz
    │ │   └─_baz = 8
    │ └─"test/test_expect_test.ml":479:10: <while loop>
    │   └─"test/test_expect_test.ml":479:14: _baz
    │     └─_baz = 10
    └─_bar = ()
        |}]

let%expect_test "%debug_this_show PrintBox to stdout num children exceeded nested" =
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
      "test/test_expect_test.ml":514:40-522:72: loop_exceeded
      ├─x = 3
      ├─"test/test_expect_test.ml":521:17: z
      │ └─z = 1
      └─"test/test_expect_test.ml":514:40-522:72: loop_exceeded
        ├─x = 2
        ├─"test/test_expect_test.ml":521:17: z
        │ └─z = 0
        └─"test/test_expect_test.ml":514:40-522:72: loop_exceeded
          ├─x = 1
          ├─"test/test_expect_test.ml":521:17: z
          │ └─z = 0
          └─"test/test_expect_test.ml":514:40-522:72: loop_exceeded
            ├─x = 0
            ├─"test/test_expect_test.ml":521:17: z
            │ └─z = 0
            ├─"test/test_expect_test.ml":521:17: z
            │ └─z = 1
            ├─"test/test_expect_test.ml":521:17: z
            │ └─z = 2
            ├─"test/test_expect_test.ml":521:17: z
            │ └─z = 3
            ├─"test/test_expect_test.ml":521:17: z
            │ └─z = 4
            ├─"test/test_expect_test.ml":521:17: z
            │ └─z = 5
            ├─"test/test_expect_test.ml":521:17: z
            │ └─z = 6
            ├─"test/test_expect_test.ml":521:17: z
            │ └─z = 7
            ├─"test/test_expect_test.ml":521:17: z
            │ └─z = 8
            ├─"test/test_expect_test.ml":521:17: z
            │ └─z = 9
            └─z = <max_num_children exceeded>
      Raised exception: ppx_minidebug: max_num_children exceeded |}]

let%expect_test "%debug_this_show PrintBox to stdout truncated children nested" =
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
      "test/test_expect_test.ml":570:40-576:69: loop_exceeded
      ├─<earlier entries truncated>
      ├─"test/test_expect_test.ml":570:40-576:69: loop_exceeded
      │ ├─<earlier entries truncated>
      │ ├─"test/test_expect_test.ml":570:40-576:69: loop_exceeded
      │ │ ├─<earlier entries truncated>
      │ │ ├─"test/test_expect_test.ml":570:40-576:69: loop_exceeded
      │ │ │ ├─<earlier entries truncated>
      │ │ │ ├─"test/test_expect_test.ml":575:15: z
      │ │ │ │ └─z = 17
      │ │ │ ├─"test/test_expect_test.ml":575:15: z
      │ │ │ │ └─z = 18
      │ │ │ ├─"test/test_expect_test.ml":575:15: z
      │ │ │ │ └─z = 19
      │ │ │ └─loop_exceeded = 190
      │ │ ├─"test/test_expect_test.ml":575:15: z
      │ │ │ └─z = 9
      │ │ ├─"test/test_expect_test.ml":570:40-576:69: loop_exceeded
      │ │ │ ├─<earlier entries truncated>
      │ │ │ ├─"test/test_expect_test.ml":575:15: z
      │ │ │ │ └─z = 17
      │ │ │ ├─"test/test_expect_test.ml":575:15: z
      │ │ │ │ └─z = 18
      │ │ │ ├─"test/test_expect_test.ml":575:15: z
      │ │ │ │ └─z = 19
      │ │ │ └─loop_exceeded = 190
      │ │ └─loop_exceeded = 1945
      │ ├─"test/test_expect_test.ml":575:15: z
      │ │ └─z = 5
      │ ├─"test/test_expect_test.ml":570:40-576:69: loop_exceeded
      │ │ ├─<earlier entries truncated>
      │ │ ├─"test/test_expect_test.ml":570:40-576:69: loop_exceeded
      │ │ │ ├─<earlier entries truncated>
      │ │ │ ├─"test/test_expect_test.ml":575:15: z
      │ │ │ │ └─z = 17
      │ │ │ ├─"test/test_expect_test.ml":575:15: z
      │ │ │ │ └─z = 18
      │ │ │ ├─"test/test_expect_test.ml":575:15: z
      │ │ │ │ └─z = 19
      │ │ │ └─loop_exceeded = 190
      │ │ ├─"test/test_expect_test.ml":575:15: z
      │ │ │ └─z = 9
      │ │ ├─"test/test_expect_test.ml":570:40-576:69: loop_exceeded
      │ │ │ ├─<earlier entries truncated>
      │ │ │ ├─"test/test_expect_test.ml":575:15: z
      │ │ │ │ └─z = 17
      │ │ │ ├─"test/test_expect_test.ml":575:15: z
      │ │ │ │ └─z = 18
      │ │ │ ├─"test/test_expect_test.ml":575:15: z
      │ │ │ │ └─z = 19
      │ │ │ └─loop_exceeded = 190
      │ │ └─loop_exceeded = 1945
      │ └─loop_exceeded = 11685
      ├─"test/test_expect_test.ml":575:15: z
      │ └─z = 5
      ├─"test/test_expect_test.ml":570:40-576:69: loop_exceeded
      │ ├─<earlier entries truncated>
      │ ├─"test/test_expect_test.ml":570:40-576:69: loop_exceeded
      │ │ ├─<earlier entries truncated>
      │ │ ├─"test/test_expect_test.ml":570:40-576:69: loop_exceeded
      │ │ │ ├─<earlier entries truncated>
      │ │ │ ├─"test/test_expect_test.ml":575:15: z
      │ │ │ │ └─z = 17
      │ │ │ ├─"test/test_expect_test.ml":575:15: z
      │ │ │ │ └─z = 18
      │ │ │ ├─"test/test_expect_test.ml":575:15: z
      │ │ │ │ └─z = 19
      │ │ │ └─loop_exceeded = 190
      │ │ ├─"test/test_expect_test.ml":575:15: z
      │ │ │ └─z = 9
      │ │ ├─"test/test_expect_test.ml":570:40-576:69: loop_exceeded
      │ │ │ ├─<earlier entries truncated>
      │ │ │ ├─"test/test_expect_test.ml":575:15: z
      │ │ │ │ └─z = 17
      │ │ │ ├─"test/test_expect_test.ml":575:15: z
      │ │ │ │ └─z = 18
      │ │ │ ├─"test/test_expect_test.ml":575:15: z
      │ │ │ │ └─z = 19
      │ │ │ └─loop_exceeded = 190
      │ │ └─loop_exceeded = 1945
      │ ├─"test/test_expect_test.ml":575:15: z
      │ │ └─z = 5
      │ ├─"test/test_expect_test.ml":570:40-576:69: loop_exceeded
      │ │ ├─<earlier entries truncated>
      │ │ ├─"test/test_expect_test.ml":570:40-576:69: loop_exceeded
      │ │ │ ├─<earlier entries truncated>
      │ │ │ ├─"test/test_expect_test.ml":575:15: z
      │ │ │ │ └─z = 17
      │ │ │ ├─"test/test_expect_test.ml":575:15: z
      │ │ │ │ └─z = 18
      │ │ │ ├─"test/test_expect_test.ml":575:15: z
      │ │ │ │ └─z = 19
      │ │ │ └─loop_exceeded = 190
      │ │ ├─"test/test_expect_test.ml":575:15: z
      │ │ │ └─z = 9
      │ │ ├─"test/test_expect_test.ml":570:40-576:69: loop_exceeded
      │ │ │ ├─<earlier entries truncated>
      │ │ │ ├─"test/test_expect_test.ml":575:15: z
      │ │ │ │ └─z = 17
      │ │ │ ├─"test/test_expect_test.ml":575:15: z
      │ │ │ │ └─z = 18
      │ │ │ ├─"test/test_expect_test.ml":575:15: z
      │ │ │ │ └─z = 19
      │ │ │ └─loop_exceeded = 190
      │ │ └─loop_exceeded = 1945
      │ └─loop_exceeded = 11685
      └─loop_exceeded = 58435
      58435 |}]

let%expect_test "%track_this_show PrintBox to stdout highlight" =
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
      │"test/test_expect_test.ml":698:41-702:61: loop_highlight│
      ├────────────────────────────────────────────────────────┘
      ├─x = 7
      ├─┬────────────────────────────────────┐
      │ │"test/test_expect_test.ml":701:10: z│
      │ ├────────────────────────────────────┘
      │ └─┬─────┐
      │   │z = 3│
      │   └─────┘
      ├─┬────────────────────────────────────────────────────────┐
      │ │"test/test_expect_test.ml":698:41-702:61: loop_highlight│
      │ ├────────────────────────────────────────────────────────┘
      │ ├─x = 6
      │ ├─"test/test_expect_test.ml":701:10: z
      │ │ └─z = 2
      │ ├─┬────────────────────────────────────────────────────────┐
      │ │ │"test/test_expect_test.ml":698:41-702:61: loop_highlight│
      │ │ ├────────────────────────────────────────────────────────┘
      │ │ ├─x = 5
      │ │ ├─"test/test_expect_test.ml":701:10: z
      │ │ │ └─z = 2
      │ │ ├─┬────────────────────────────────────────────────────────┐
      │ │ │ │"test/test_expect_test.ml":698:41-702:61: loop_highlight│
      │ │ │ ├────────────────────────────────────────────────────────┘
      │ │ │ ├─x = 4
      │ │ │ ├─"test/test_expect_test.ml":701:10: z
      │ │ │ │ └─z = 1
      │ │ │ ├─┬────────────────────────────────────────────────────────┐
      │ │ │ │ │"test/test_expect_test.ml":698:41-702:61: loop_highlight│
      │ │ │ │ ├────────────────────────────────────────────────────────┘
      │ │ │ │ ├─┬─────┐
      │ │ │ │ │ │x = 3│
      │ │ │ │ │ └─────┘
      │ │ │ │ ├─"test/test_expect_test.ml":701:10: z
      │ │ │ │ │ └─z = 1
      │ │ │ │ ├─"test/test_expect_test.ml":698:41-702:61: loop_highlight
      │ │ │ │ │ ├─x = 2
      │ │ │ │ │ ├─"test/test_expect_test.ml":701:10: z
      │ │ │ │ │ │ └─z = 0
      │ │ │ │ │ ├─"test/test_expect_test.ml":698:41-702:61: loop_highlight
      │ │ │ │ │ │ ├─x = 1
      │ │ │ │ │ │ ├─"test/test_expect_test.ml":701:10: z
      │ │ │ │ │ │ │ └─z = 0
      │ │ │ │ │ │ ├─"test/test_expect_test.ml":698:41-702:61: loop_highlight
      │ │ │ │ │ │ │ ├─x = 0
      │ │ │ │ │ │ │ ├─"test/test_expect_test.ml":701:10: z
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
      "test/test_expect_test.ml":768:37-770:46: track_branches
      ├─x = 7
      ├─"test/test_expect_test.ml":770:9: <if -- else branch>
      │ └─"test/test_expect_test.ml":770:36-770:37: <match -- branch 1>
      └─track_branches = 4
      4
      "test/test_expect_test.ml":768:37-770:46: track_branches
      ├─x = 3
      ├─"test/test_expect_test.ml":769:18: <if -- then branch>
      │ └─"test/test_expect_test.ml":769:54-769:57: <match -- branch 2>
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
      "test/test_expect_test.ml":801:11-801:12: <function -- branch 3>
      4
      "test/test_expect_test.ml":803:11-803:14: <function -- branch 5> x
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
      "test/test_expect_test.ml":822:37-836:16: track_branches
      ├─x = 8
      ├─"test/test_expect_test.ml":831:6: <if -- else branch>
      │ └─"test/test_expect_test.ml":835:10-836:16: <match -- branch 2>
      │   └─"test/test_expect_test.ml":835:14: result
      │     ├─"test/test_expect_test.ml":835:44: <if -- then branch>
      │     └─result = 8
      └─track_branches = 8
      8
      "test/test_expect_test.ml":822:37-836:16: track_branches
      ├─x = 3
      ├─"test/test_expect_test.ml":824:6: <if -- then branch>
      │ └─"test/test_expect_test.ml":828:14: result
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
    "test/test_expect_test.ml":868:27-872:5: track_foo
    ├─x = 8
    ├─"test/test_expect_test.ml":871:4-871:31: __fun
    │ └─z = 8
    └─track_foo = 8
    8 |}]

let%expect_test "nested extension points are no-ops" =
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
      "test/test_expect_test.ml":890:37-904:16: track_branches
      ├─x = 8
      ├─"test/test_expect_test.ml":899:6: <if -- else branch>
      │ └─"test/test_expect_test.ml":903:10-904:16: <match -- branch 2>
      │   └─"test/test_expect_test.ml":903:25: result
      │     ├─"test/test_expect_test.ml":903:55: <if -- then branch>
      │     └─result = 8
      └─track_branches = 8
      8
      "test/test_expect_test.ml":890:37-904:16: track_branches
      ├─x = 3
      ├─"test/test_expect_test.ml":892:6: <if -- then branch>
      │ └─"test/test_expect_test.ml":896:25: result
      │   └─result = 3
      └─track_branches = 3
      3
    |}]

let%expect_test "%track_this_show PrintBox to stdout no return type anonymous fun" =
  let module Debug_runtime = (val Minidebug_runtime.debug ()) in
  let%debug_this_show anonymous (x : int) =
    Array.fold_left ( + ) 0 @@ Array.init (x + 1) (fun (i : int) -> i)
  in
  let () =
    try print_endline @@ Int.to_string @@ anonymous 3
    with Failure s -> print_endline @@ "Raised exception: " ^ s
  in
  [%expect {|
    BEGIN DEBUG SESSION
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
      "test/test_expect_test.ml":946:32-947:70: anonymous
      ├─x = 3
      ├─"test/test_expect_test.ml":947:50-947:70: __fun
      │ └─i = 0
      ├─"test/test_expect_test.ml":947:50-947:70: __fun
      │ └─i = 1
      ├─"test/test_expect_test.ml":947:50-947:70: __fun
      │ └─i = 2
      └─"test/test_expect_test.ml":947:50-947:70: __fun
        └─i = 3
      6
    |}]

let%expect_test "%track_this_show PrintBox to stdout anonymous fun, num children exceeded"
    =
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
      "test/test_expect_test.ml":971:40-979:72: loop_exceeded
      ├─x = 3
      └─"test/test_expect_test.ml":977:11-979:71: __fun
        ├─i = 0
        ├─"test/test_expect_test.ml":978:17: z
        │ └─z = 1
        └─"test/test_expect_test.ml":979:35: <if -- else branch>
          └─"test/test_expect_test.ml":971:40-979:72: loop_exceeded
            ├─x = 2
            └─"test/test_expect_test.ml":977:11-979:71: __fun
              ├─i = 0
              ├─"test/test_expect_test.ml":978:17: z
              │ └─z = 0
              └─"test/test_expect_test.ml":979:35: <if -- else branch>
                └─"test/test_expect_test.ml":971:40-979:72: loop_exceeded
                  ├─x = 1
                  └─"test/test_expect_test.ml":977:11-979:71: __fun
                    ├─i = 0
                    ├─"test/test_expect_test.ml":978:17: z
                    │ └─z = 0
                    └─"test/test_expect_test.ml":979:35: <if -- else branch>
                      └─"test/test_expect_test.ml":971:40-979:72: loop_exceeded
                        ├─x = 0
                        ├─"test/test_expect_test.ml":977:11-979:71: __fun
                        │ ├─i = 0
                        │ ├─"test/test_expect_test.ml":978:17: z
                        │ │ └─z = 0
                        │ └─"test/test_expect_test.ml":979:28: <if -- then branch>
                        ├─"test/test_expect_test.ml":977:11-979:71: __fun
                        │ ├─i = 1
                        │ ├─"test/test_expect_test.ml":978:17: z
                        │ │ └─z = 1
                        │ └─"test/test_expect_test.ml":979:28: <if -- then branch>
                        ├─"test/test_expect_test.ml":977:11-979:71: __fun
                        │ ├─i = 2
                        │ ├─"test/test_expect_test.ml":978:17: z
                        │ │ └─z = 2
                        │ └─"test/test_expect_test.ml":979:28: <if -- then branch>
                        ├─"test/test_expect_test.ml":977:11-979:71: __fun
                        │ ├─i = 3
                        │ ├─"test/test_expect_test.ml":978:17: z
                        │ │ └─z = 3
                        │ └─"test/test_expect_test.ml":979:28: <if -- then branch>
                        ├─"test/test_expect_test.ml":977:11-979:71: __fun
                        │ ├─i = 4
                        │ ├─"test/test_expect_test.ml":978:17: z
                        │ │ └─z = 4
                        │ └─"test/test_expect_test.ml":979:28: <if -- then branch>
                        ├─"test/test_expect_test.ml":977:11-979:71: __fun
                        │ ├─i = 5
                        │ ├─"test/test_expect_test.ml":978:17: z
                        │ │ └─z = 5
                        │ └─"test/test_expect_test.ml":979:28: <if -- then branch>
                        ├─"test/test_expect_test.ml":977:11-979:71: __fun
                        │ ├─i = 6
                        │ ├─"test/test_expect_test.ml":978:17: z
                        │ │ └─z = 6
                        │ └─"test/test_expect_test.ml":979:28: <if -- then branch>
                        ├─"test/test_expect_test.ml":977:11-979:71: __fun
                        │ ├─i = 7
                        │ ├─"test/test_expect_test.ml":978:17: z
                        │ │ └─z = 7
                        │ └─"test/test_expect_test.ml":979:28: <if -- then branch>
                        ├─"test/test_expect_test.ml":977:11-979:71: __fun
                        │ ├─i = 8
                        │ ├─"test/test_expect_test.ml":978:17: z
                        │ │ └─z = 8
                        │ └─"test/test_expect_test.ml":979:28: <if -- then branch>
                        ├─"test/test_expect_test.ml":977:11-979:71: __fun
                        │ ├─i = 9
                        │ ├─"test/test_expect_test.ml":978:17: z
                        │ │ └─z = 9
                        │ └─"test/test_expect_test.ml":979:28: <if -- then branch>
                        └─__fun = <max_num_children exceeded>
      Raised exception: ppx_minidebug: max_num_children exceeded
    |}]

let%expect_test "%track_this_show PrintBox to stdout anonymous fun, truncated children" =
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
      "test/test_expect_test.ml":1067:40-1073:69: loop_exceeded
      ├─<earlier entries truncated>
      ├─"test/test_expect_test.ml":1071:9-1073:69: __fun
      │ ├─<earlier entries truncated>
      │ ├─"test/test_expect_test.ml":1072:15: z
      │ │ └─z = 7
      │ └─"test/test_expect_test.ml":1073:33: <if -- else branch>
      │   └─"test/test_expect_test.ml":1067:40-1073:69: loop_exceeded
      │     ├─<earlier entries truncated>
      │     ├─"test/test_expect_test.ml":1071:9-1073:69: __fun
      │     │ ├─<earlier entries truncated>
      │     │ ├─"test/test_expect_test.ml":1072:15: z
      │     │ │ └─z = 9
      │     │ └─"test/test_expect_test.ml":1073:33: <if -- else branch>
      │     │   └─"test/test_expect_test.ml":1067:40-1073:69: loop_exceeded
      │     │     ├─<earlier entries truncated>
      │     │     ├─"test/test_expect_test.ml":1071:9-1073:69: __fun
      │     │     │ ├─<earlier entries truncated>
      │     │     │ ├─"test/test_expect_test.ml":1072:15: z
      │     │     │ │ └─z = 14
      │     │     │ └─"test/test_expect_test.ml":1073:33: <if -- else branch>
      │     │     │   └─"test/test_expect_test.ml":1067:40-1073:69: loop_exceeded
      │     │     │     ├─<earlier entries truncated>
      │     │     │     ├─"test/test_expect_test.ml":1071:9-1073:69: __fun
      │     │     │     │ ├─<earlier entries truncated>
      │     │     │     │ ├─"test/test_expect_test.ml":1072:15: z
      │     │     │     │ │ └─z = 29
      │     │     │     │ └─"test/test_expect_test.ml":1073:26: <if -- then branch>
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

let%expect_test "%debug_this_show PrintBox to stdout function with abstract type" =
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
      "test/test_expect_test.ml":1125:26-1126:47: foo
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
  ├─"test/test_expect_test.ml":1151:41-1154:36
  ├─x = 7
  ├─z = 3
  │ └─"test/test_expect_test.ml":1152:8
  └─loop_truncated
    ├─"test/test_expect_test.ml":1151:41-1154:36
    ├─x = 6
    ├─z = 2
    │ └─"test/test_expect_test.ml":1152:8
    └─loop_truncated
      ├─"test/test_expect_test.ml":1151:41-1154:36
      ├─x = 5
      ├─z = 2
      │ └─"test/test_expect_test.ml":1152:8
      └─loop_truncated
        ├─"test/test_expect_test.ml":1151:41-1154:36
        ├─x = 4
        ├─z = 1
        │ └─"test/test_expect_test.ml":1152:8
        └─loop_truncated
          ├─"test/test_expect_test.ml":1151:41-1154:36
          ├─x = 3
          ├─z = 1
          │ └─"test/test_expect_test.ml":1152:8
          └─loop_truncated
            ├─"test/test_expect_test.ml":1151:41-1154:36
            ├─x = 2
            ├─z = 0
            │ └─"test/test_expect_test.ml":1152:8
            └─loop_truncated
              ├─"test/test_expect_test.ml":1151:41-1154:36
              ├─x = 1
              ├─z = 0
              │ └─"test/test_expect_test.ml":1152:8
              └─loop_truncated
                ├─"test/test_expect_test.ml":1151:41-1154:36
                ├─x = 0
                └─z = 0
                  └─"test/test_expect_test.ml":1152:8
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
    ├─"test/test_expect_test.ml":1210:26
    ├─_baz = 0
    │ └─"test/test_expect_test.ml":1214:16
    ├─_baz = 2
    │ └─"test/test_expect_test.ml":1214:16
    ├─_baz = 4
    │ └─"test/test_expect_test.ml":1214:16
    ├─_baz = 6
    │ └─"test/test_expect_test.ml":1214:16
    ├─_baz = 8
    │ └─"test/test_expect_test.ml":1214:16
    ├─_baz = 10
    │ └─"test/test_expect_test.ml":1214:16
    ├─_baz = 12
    │ └─"test/test_expect_test.ml":1214:16
    ├─_baz = 14
    │ └─"test/test_expect_test.ml":1214:16
    ├─_baz = 16
    │ └─"test/test_expect_test.ml":1214:16
    ├─_baz = 18
    │ └─"test/test_expect_test.ml":1214:16
    ├─_baz = 20
    │ └─"test/test_expect_test.ml":1214:16
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
      ├─"test/test_expect_test.ml":1255:26
      └─<for loop>
        ├─"test/test_expect_test.ml":1258:10
        ├─i = 0
        ├─<for i>
        │ ├─"test/test_expect_test.ml":1258:14
        │ └─_baz = 0
        │   └─"test/test_expect_test.ml":1259:16
        ├─i = 1
        ├─<for i>
        │ ├─"test/test_expect_test.ml":1258:14
        │ └─_baz = 2
        │   └─"test/test_expect_test.ml":1259:16
        ├─i = 2
        ├─<for i>
        │ ├─"test/test_expect_test.ml":1258:14
        │ └─_baz = 4
        │   └─"test/test_expect_test.ml":1259:16
        ├─i = 3
        ├─<for i>
        │ ├─"test/test_expect_test.ml":1258:14
        │ └─_baz = 6
        │   └─"test/test_expect_test.ml":1259:16
        ├─i = 4
        ├─<for i>
        │ ├─"test/test_expect_test.ml":1258:14
        │ └─_baz = 8
        │   └─"test/test_expect_test.ml":1259:16
        ├─i = 5
        ├─<for i>
        │ ├─"test/test_expect_test.ml":1258:14
        │ └─_baz = 10
        │   └─"test/test_expect_test.ml":1259:16
        ├─i = 6
        └─<for i>
          ├─"test/test_expect_test.ml":1258:14
          └─_baz = 12
            └─"test/test_expect_test.ml":1259:16 |}]

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
      ├─"test/test_expect_test.ml":1312:40-1320:72
      ├─x = 3
      ├─z = 1
      │ └─"test/test_expect_test.ml":1319:17
      └─loop_exceeded
        ├─"test/test_expect_test.ml":1312:40-1320:72
        ├─x = 2
        ├─z = 0
        │ └─"test/test_expect_test.ml":1319:17
        └─loop_exceeded
          ├─"test/test_expect_test.ml":1312:40-1320:72
          ├─x = 1
          ├─z = 0
          │ └─"test/test_expect_test.ml":1319:17
          └─loop_exceeded
            ├─"test/test_expect_test.ml":1312:40-1320:72
            ├─x = 0
            ├─z = 0
            │ └─"test/test_expect_test.ml":1319:17
            ├─z = 1
            │ └─"test/test_expect_test.ml":1319:17
            ├─z = 2
            │ └─"test/test_expect_test.ml":1319:17
            ├─z = 3
            │ └─"test/test_expect_test.ml":1319:17
            ├─z = 4
            │ └─"test/test_expect_test.ml":1319:17
            ├─z = 5
            │ └─"test/test_expect_test.ml":1319:17
            ├─z = 6
            │ └─"test/test_expect_test.ml":1319:17
            ├─z = 7
            │ └─"test/test_expect_test.ml":1319:17
            ├─z = 8
            │ └─"test/test_expect_test.ml":1319:17
            ├─z = 9
            │ └─"test/test_expect_test.ml":1319:17
            └─z = <max_num_children exceeded>
      Raised exception: ppx_minidebug: max_num_children exceeded |}]

let%expect_test "%debug_this_show PrintBox values_first_mode to stdout truncated \
                 children nested" =
  let module Debug_runtime =
    (val Minidebug_runtime.debug ~values_first_mode:true ~truncate_children:4 ())
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
  [%expect
    {|
      BEGIN DEBUG SESSION
      loop_exceeded = 58435
      ├─"test/test_expect_test.ml":1375:40-1381:69
      ├─<earlier entries truncated>
      ├─z = 4
      │ └─"test/test_expect_test.ml":1380:15
      ├─loop_exceeded = 11685
      │ ├─"test/test_expect_test.ml":1375:40-1381:69
      │ ├─<earlier entries truncated>
      │ ├─z = 4
      │ │ └─"test/test_expect_test.ml":1380:15
      │ ├─loop_exceeded = 1945
      │ │ ├─"test/test_expect_test.ml":1375:40-1381:69
      │ │ ├─<earlier entries truncated>
      │ │ ├─z = 8
      │ │ │ └─"test/test_expect_test.ml":1380:15
      │ │ ├─loop_exceeded = 190
      │ │ │ ├─"test/test_expect_test.ml":1375:40-1381:69
      │ │ │ ├─<earlier entries truncated>
      │ │ │ ├─z = 16
      │ │ │ │ └─"test/test_expect_test.ml":1380:15
      │ │ │ ├─z = 17
      │ │ │ │ └─"test/test_expect_test.ml":1380:15
      │ │ │ ├─z = 18
      │ │ │ │ └─"test/test_expect_test.ml":1380:15
      │ │ │ └─z = 19
      │ │ │   └─"test/test_expect_test.ml":1380:15
      │ │ ├─z = 9
      │ │ │ └─"test/test_expect_test.ml":1380:15
      │ │ └─loop_exceeded = 190
      │ │   ├─"test/test_expect_test.ml":1375:40-1381:69
      │ │   ├─<earlier entries truncated>
      │ │   ├─z = 16
      │ │   │ └─"test/test_expect_test.ml":1380:15
      │ │   ├─z = 17
      │ │   │ └─"test/test_expect_test.ml":1380:15
      │ │   ├─z = 18
      │ │   │ └─"test/test_expect_test.ml":1380:15
      │ │   └─z = 19
      │ │     └─"test/test_expect_test.ml":1380:15
      │ ├─z = 5
      │ │ └─"test/test_expect_test.ml":1380:15
      │ └─loop_exceeded = 1945
      │   ├─"test/test_expect_test.ml":1375:40-1381:69
      │   ├─<earlier entries truncated>
      │   ├─z = 8
      │   │ └─"test/test_expect_test.ml":1380:15
      │   ├─loop_exceeded = 190
      │   │ ├─"test/test_expect_test.ml":1375:40-1381:69
      │   │ ├─<earlier entries truncated>
      │   │ ├─z = 16
      │   │ │ └─"test/test_expect_test.ml":1380:15
      │   │ ├─z = 17
      │   │ │ └─"test/test_expect_test.ml":1380:15
      │   │ ├─z = 18
      │   │ │ └─"test/test_expect_test.ml":1380:15
      │   │ └─z = 19
      │   │   └─"test/test_expect_test.ml":1380:15
      │   ├─z = 9
      │   │ └─"test/test_expect_test.ml":1380:15
      │   └─loop_exceeded = 190
      │     ├─"test/test_expect_test.ml":1375:40-1381:69
      │     ├─<earlier entries truncated>
      │     ├─z = 16
      │     │ └─"test/test_expect_test.ml":1380:15
      │     ├─z = 17
      │     │ └─"test/test_expect_test.ml":1380:15
      │     ├─z = 18
      │     │ └─"test/test_expect_test.ml":1380:15
      │     └─z = 19
      │       └─"test/test_expect_test.ml":1380:15
      ├─z = 5
      │ └─"test/test_expect_test.ml":1380:15
      └─loop_exceeded = 11685
        ├─"test/test_expect_test.ml":1375:40-1381:69
        ├─<earlier entries truncated>
        ├─z = 4
        │ └─"test/test_expect_test.ml":1380:15
        ├─loop_exceeded = 1945
        │ ├─"test/test_expect_test.ml":1375:40-1381:69
        │ ├─<earlier entries truncated>
        │ ├─z = 8
        │ │ └─"test/test_expect_test.ml":1380:15
        │ ├─loop_exceeded = 190
        │ │ ├─"test/test_expect_test.ml":1375:40-1381:69
        │ │ ├─<earlier entries truncated>
        │ │ ├─z = 16
        │ │ │ └─"test/test_expect_test.ml":1380:15
        │ │ ├─z = 17
        │ │ │ └─"test/test_expect_test.ml":1380:15
        │ │ ├─z = 18
        │ │ │ └─"test/test_expect_test.ml":1380:15
        │ │ └─z = 19
        │ │   └─"test/test_expect_test.ml":1380:15
        │ ├─z = 9
        │ │ └─"test/test_expect_test.ml":1380:15
        │ └─loop_exceeded = 190
        │   ├─"test/test_expect_test.ml":1375:40-1381:69
        │   ├─<earlier entries truncated>
        │   ├─z = 16
        │   │ └─"test/test_expect_test.ml":1380:15
        │   ├─z = 17
        │   │ └─"test/test_expect_test.ml":1380:15
        │   ├─z = 18
        │   │ └─"test/test_expect_test.ml":1380:15
        │   └─z = 19
        │     └─"test/test_expect_test.ml":1380:15
        ├─z = 5
        │ └─"test/test_expect_test.ml":1380:15
        └─loop_exceeded = 1945
          ├─"test/test_expect_test.ml":1375:40-1381:69
          ├─<earlier entries truncated>
          ├─z = 8
          │ └─"test/test_expect_test.ml":1380:15
          ├─loop_exceeded = 190
          │ ├─"test/test_expect_test.ml":1375:40-1381:69
          │ ├─<earlier entries truncated>
          │ ├─z = 16
          │ │ └─"test/test_expect_test.ml":1380:15
          │ ├─z = 17
          │ │ └─"test/test_expect_test.ml":1380:15
          │ ├─z = 18
          │ │ └─"test/test_expect_test.ml":1380:15
          │ └─z = 19
          │   └─"test/test_expect_test.ml":1380:15
          ├─z = 9
          │ └─"test/test_expect_test.ml":1380:15
          └─loop_exceeded = 190
            ├─"test/test_expect_test.ml":1375:40-1381:69
            ├─<earlier entries truncated>
            ├─z = 16
            │ └─"test/test_expect_test.ml":1380:15
            ├─z = 17
            │ └─"test/test_expect_test.ml":1380:15
            ├─z = 18
            │ └─"test/test_expect_test.ml":1380:15
            └─z = 19
              └─"test/test_expect_test.ml":1380:15
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
      ├─"test/test_expect_test.ml":1533:41-1535:58
      ├─x = 7
      ├─┬─────┐
      │ │z = 3│
      │ ├─────┘
      │ └─"test/test_expect_test.ml":1534:8
      └─┬──────────────────┐
        │loop_highlight = 6│
        ├──────────────────┘
        ├─"test/test_expect_test.ml":1533:41-1535:58
        ├─x = 6
        ├─z = 2
        │ └─"test/test_expect_test.ml":1534:8
        └─┬──────────────────┐
          │loop_highlight = 4│
          ├──────────────────┘
          ├─"test/test_expect_test.ml":1533:41-1535:58
          ├─x = 5
          ├─z = 2
          │ └─"test/test_expect_test.ml":1534:8
          └─┬──────────────────┐
            │loop_highlight = 2│
            ├──────────────────┘
            ├─"test/test_expect_test.ml":1533:41-1535:58
            ├─x = 4
            ├─z = 1
            │ └─"test/test_expect_test.ml":1534:8
            └─┬──────────────────┐
              │loop_highlight = 1│
              ├──────────────────┘
              ├─"test/test_expect_test.ml":1533:41-1535:58
              ├─┬─────┐
              │ │x = 3│
              │ └─────┘
              ├─z = 1
              │ └─"test/test_expect_test.ml":1534:8
              └─loop_highlight = 0
                ├─"test/test_expect_test.ml":1533:41-1535:58
                ├─x = 2
                ├─z = 0
                │ └─"test/test_expect_test.ml":1534:8
                └─loop_highlight = 0
                  ├─"test/test_expect_test.ml":1533:41-1535:58
                  ├─x = 1
                  ├─z = 0
                  │ └─"test/test_expect_test.ml":1534:8
                  └─loop_highlight = 0
                    ├─"test/test_expect_test.ml":1533:41-1535:58
                    ├─x = 0
                    └─z = 0
                      └─"test/test_expect_test.ml":1534:8
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
      ├─"test/test_expect_test.ml":1599:37-1601:46
      ├─x = 7
      └─<if -- else branch>
        ├─"test/test_expect_test.ml":1601:9
        └─<match -- branch 1>
          └─"test/test_expect_test.ml":1601:36-1601:37
      4
      track_branches = -3
      ├─"test/test_expect_test.ml":1599:37-1601:46
      ├─x = 3
      └─<if -- then branch>
        ├─"test/test_expect_test.ml":1600:18
        └─<match -- branch 2>
          └─"test/test_expect_test.ml":1600:54-1600:57
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
      ├─"test/test_expect_test.ml":1633:32-1634:70
      ├─x = 3
      ├─__fun
      │ ├─"test/test_expect_test.ml":1634:50-1634:70
      │ └─i = 0
      ├─__fun
      │ ├─"test/test_expect_test.ml":1634:50-1634:70
      │ └─i = 1
      ├─__fun
      │ ├─"test/test_expect_test.ml":1634:50-1634:70
      │ └─i = 2
      └─__fun
        ├─"test/test_expect_test.ml":1634:50-1634:70
        └─i = 3
      6
    |}]

let%expect_test "%debug_show PrintBox to stdout records" =
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
    "test/test_expect_test.ml":1663:21-1666:15: bar
    ├─first = 7
    ├─second = 42
    ├─"test/test_expect_test.ml":1664:8: {first=a; second=b}
    │ ├─a = 7
    │ └─b = 45
    ├─"test/test_expect_test.ml":1665:8: y
    │ └─y = 8
    └─bar = 336
    336
    "test/test_expect_test.ml":1669:10-1671:28: baz
    ├─first = 7
    ├─second = 42
    ├─"test/test_expect_test.ml":1670:8: {first; second}
    │ ├─first = 8
    │ └─second = 45
    └─baz = 109
    109 |}]

let%expect_test "%debug_show PrintBox to stdout tuples" =
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
    "test/test_expect_test.ml":1698:21-1700:14: bar
    ├─first = 7
    ├─second = 42
    ├─"test/test_expect_test.ml":1699:8: y
    │ └─y = 8
    └─bar = 336
    336
    "test/test_expect_test.ml":1708:6: (r1, r2)
    ├─"test/test_expect_test.ml":1703:10-1706:35: baz
    │ ├─first = 7
    │ ├─second = 42
    │ ├─"test/test_expect_test.ml":1704:8: (y, z)
    │ │ ├─y = 8
    │ │ └─z = 3
    │ ├─"test/test_expect_test.ml":1705:8: (a, b)
    │ │ ├─a = 8
    │ │ └─b = 45
    │ └─baz = (339, 109)
    ├─r1 = 339
    └─r2 = 109
    339
    109 |}]

let%expect_test "%debug_show PrintBox to stdout records values_first_mode" =
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
      ├─"test/test_expect_test.ml":1739:21-1742:15
      ├─first = 7
      ├─second = 42
      ├─{first=a; second=b}
      │ ├─"test/test_expect_test.ml":1740:8
      │ └─<values>
      │   ├─a = 7
      │   └─b = 45
      └─y = 8
        └─"test/test_expect_test.ml":1741:8
      336
      baz = 109
      ├─"test/test_expect_test.ml":1745:10-1747:28
      ├─first = 7
      ├─second = 42
      └─{first; second}
        ├─"test/test_expect_test.ml":1746:8
        └─<values>
          ├─first = 8
          └─second = 45
      109 |}]

let%expect_test "%debug_show PrintBox to stdout tuples values_first_mode" =
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
    ├─"test/test_expect_test.ml":1778:21-1780:14
    ├─first = 7
    ├─second = 42
    └─y = 8
      └─"test/test_expect_test.ml":1779:8
    336
    (r1, r2)
    ├─"test/test_expect_test.ml":1788:6
    ├─<returns>
    │ ├─r1 = 339
    │ └─r2 = 109
    └─baz = (339, 109)
      ├─"test/test_expect_test.ml":1783:10-1786:35
      ├─first = 7
      ├─second = 42
      ├─(y, z)
      │ ├─"test/test_expect_test.ml":1784:8
      │ └─<values>
      │   ├─y = 8
      │   └─z = 3
      └─(a, b)
        ├─"test/test_expect_test.ml":1785:8
        └─<values>
          ├─a = 8
          └─b = 45
    339
    109 |}]

type 'a irrefutable = Zero of 'a
type ('a, 'b) left_right = Left of 'a | Right of 'b
type ('a, 'b, 'c) one_two_three = One of 'a | Two of 'b | Three of 'c

let%expect_test "%track_show PrintBox to stdout variants values_first_mode" =
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
      ├─"test/test_expect_test.ml":1829:21-1831:9
      ├─x = 7
      └─y = 8
        └─"test/test_expect_test.ml":1830:8
      16
      baz = 5
      ├─"test/test_expect_test.ml":1835:24-1835:29
      ├─<function -- branch 0> Left x
      └─x = 4
      5
      baz = 6
      ├─"test/test_expect_test.ml":1836:31-1836:36
      ├─<function -- branch 1> Right Two y
      └─y = 3
      6
      foo = 3
      ├─"test/test_expect_test.ml":1839:10-1840:82
      └─<match -- branch 2>
        └─"test/test_expect_test.ml":1840:81-1840:82
      3 |}]

let%expect_test "%debug_show PrintBox to stdout tuples merge type info" =
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
    ├─"test/test_expect_test.ml":1877:6
    ├─<returns>
    │ ├─r1 = 339
    │ └─r2 = 109
    └─baz = (339, 109)
      ├─"test/test_expect_test.ml":1872:21-1875:35
      ├─first = 7
      ├─second = 42
      ├─(y, z)
      │ ├─"test/test_expect_test.ml":1873:8
      │ └─<values>
      │   ├─y = 8
      │   └─z = 3
      └─a = 8
        └─"test/test_expect_test.ml":1874:8
    339
    109 |}]

let%expect_test "%debug_show PrintBox to stdout decompose multi-argument function type" =
  let module Debug_runtime = (val Minidebug_runtime.debug ~values_first_mode:true ()) in
  let%debug_show f : 'a. 'a -> int -> int = fun _a b -> b + 1 in
  let%debug_show g : 'a. 'a -> int -> 'a -> 'a -> int = fun _a b _c _d -> b * 2 in
  let () = print_endline @@ Int.to_string @@ f 'a' 6 in
  let () = print_endline @@ Int.to_string @@ g 'a' 6 'b' 'c' in
  [%expect
    {|
    BEGIN DEBUG SESSION
    f = 7
    ├─"test/test_expect_test.ml":1905:44-1905:61
    └─b = 6
    7
    g = 12
    ├─"test/test_expect_test.ml":1906:56-1906:79
    └─b = 6
    12 |}]

let%expect_test "%debug_show PrintBox to stdout debug type info" =
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
      ├─"test/test_expect_test.ml":1925:37-1925:54
      ├─f : int
      └─b : int = 6
      7
      g : int = 12
      ├─"test/test_expect_test.ml":1926:49-1926:72
      ├─g : int
      └─b : int = 6
      12 |}]

let%expect_test "%track_show PrintBox to stdout options values_first_mode" =
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
      ├─"test/test_expect_test.ml":1945:21-1946:59
      └─<match -- branch 1> Some y
        ├─"test/test_expect_test.ml":1946:54-1946:59
        └─y = 7
      14
      bar = 14
      ├─"test/test_expect_test.ml":1949:10-1949:75
      ├─l = (Some 7)
      └─<match -- branch 1> Some y
        └─"test/test_expect_test.ml":1949:70-1949:75
      14
      baz = 8
      ├─"test/test_expect_test.ml":1951:63-1951:68
      ├─<function -- branch 1> Some y
      └─y = 4
      8
      zoo = 9
      ├─"test/test_expect_test.ml":1953:76-1953:81
      ├─<function -- branch 1> Some (y, z)
      ├─y = 4
      └─z = 5
      9 |}]

let%expect_test "%track_show PrintBox to stdout list values_first_mode" =
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
      ├─"test/test_expect_test.ml":1984:21-1984:82
      └─<match -- branch 1> :: (y, _)
        ├─"test/test_expect_test.ml":1984:77-1984:82
        └─y = 7
      14
      bar = 14
      ├─"test/test_expect_test.ml":1986:10-1986:71
      ├─l = [7]
      └─<match -- branch 1> :: (y, _)
        └─"test/test_expect_test.ml":1986:66-1986:71
      14
      baz = 8
      ├─"test/test_expect_test.ml":1990:15-1990:20
      ├─<function -- branch 1> :: (y, [])
      └─y = 4
      8
      baz = 9
      ├─"test/test_expect_test.ml":1991:18-1991:23
      ├─<function -- branch 2> :: (y, :: (z, []))
      ├─y = 4
      └─z = 5
      9
      baz = 10
      ├─"test/test_expect_test.ml":1992:21-1992:30
      ├─<function -- branch 3> :: (y, :: (z, _))
      ├─y = 4
      └─z = 5
      10 |}]

let%expect_test "%track_rtb_show PrintBox to stdout list runtime passing" =
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
      ├─"test/test_expect_test.ml":2031:25-2032:55
      └─foo-1 <match -- branch 1> :: (y, _)
        ├─"test/test_expect_test.ml":2032:50-2032:55
        └─y = 7
      14

      BEGIN DEBUG SESSION baz-1
      baz = 8
      ├─"test/test_expect_test.ml":2042:15-2042:20
      ├─baz-1 <function -- branch 1> :: (y, [])
      └─y = 4
      8

      BEGIN DEBUG SESSION baz-2
      baz = 10
      ├─"test/test_expect_test.ml":2044:21-2044:30
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
      bar-1 bar begin "test/test_expect_test.ml":2084:24-2084:46
       bar-1 __fun begin "test/test_expect_test.ml":2084:29-2084:43
       bar-1 __fun end
      bar-1 bar end

      BEGIN DEBUG SESSION bar-2
      bar-2 bar begin "test/test_expect_test.ml":2084:24-2084:46
       bar-2 __fun begin "test/test_expect_test.ml":2084:29-2084:43
       bar-2 __fun end
      bar-2 bar end

      BEGIN DEBUG SESSION foo-1
      foo-1 foo begin "test/test_expect_test.ml":2087:24-2089:6
      foo-1 foo end

      BEGIN DEBUG SESSION foo-2
      foo-2 foo begin "test/test_expect_test.ml":2087:24-2089:6
      foo-2 foo end |}]

let%expect_test "%log constant entries" =
  let module Debug_runtime = (val Minidebug_runtime.debug ~values_first_mode:true ()) in
  let%debug_show foo () : unit =
    [%log "This is the first log line"];
    [%log [ "This is the"; "2"; "log line" ]];
    [%log "This is the", 3, "or", 3.14, "log line"]
  in
  let () = foo () in
  let sexp_of_string s = Sexplib0.Sexp.Atom s in
  let sexp_of_list f l = Sexplib0.Sexp.List (List.map f l) in
  let sexp_of_unit () = Sexplib0.Sexp.List [] in
  let sexp_of_int i = Sexplib0.Sexp.Atom (string_of_int i) in
  let sexp_of_float n = Sexplib0.Sexp.Atom (string_of_float n) in
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
      ├─"test/test_expect_test.ml":2117:21-2120:51
      ├─"This is the first log line"
      ├─["This is the"; "2"; "log line"]
      └─("This is the", 3, "or", 3.14, "log line")
      bar = ()
      ├─"test/test_expect_test.ml":2128:21-2131:51
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
          ├─"test/test_expect_test.ml":2153:21-2158:25
          ├─("This is like", 3, "or", 3.14, "above")
          ├─("tau =", 6.28)
          ├─[4; 1; 2; 3]
          ├─[3; 1; 2; 3]
          └─[3; 1; 2; 3] |}]
