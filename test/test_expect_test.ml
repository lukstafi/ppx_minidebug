type t = { first : int; second : int } [@@deriving show]

let%expect_test "%debug_show flushing to a file" =
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

let%expect_test "%debug_show PrintBox to stdout disabled subtree" =
  let module Debug_runtime = (val Minidebug_runtime.debug ()) in
  let%debug_this_show rec loop_complete (x : int) : int =
    let z : int = (x - 1) / 2 in
    if x <= 0 then 0 else z + loop_complete (z + (x / 2))
  in
  let () = print_endline @@ Int.to_string @@ loop_complete 7 in
  [%expect
    {|
    BEGIN DEBUG SESSION
    "test/test_expect_test.ml":60:40-62:57: loop_complete
    ├─x = 7
    ├─"test/test_expect_test.ml":61:8: z
    │ └─z = 3
    ├─"test/test_expect_test.ml":60:40-62:57: loop_complete
    │ ├─x = 6
    │ ├─"test/test_expect_test.ml":61:8: z
    │ │ └─z = 2
    │ ├─"test/test_expect_test.ml":60:40-62:57: loop_complete
    │ │ ├─x = 5
    │ │ ├─"test/test_expect_test.ml":61:8: z
    │ │ │ └─z = 2
    │ │ ├─"test/test_expect_test.ml":60:40-62:57: loop_complete
    │ │ │ ├─x = 4
    │ │ │ ├─"test/test_expect_test.ml":61:8: z
    │ │ │ │ └─z = 1
    │ │ │ ├─"test/test_expect_test.ml":60:40-62:57: loop_complete
    │ │ │ │ ├─x = 3
    │ │ │ │ ├─"test/test_expect_test.ml":61:8: z
    │ │ │ │ │ └─z = 1
    │ │ │ │ ├─"test/test_expect_test.ml":60:40-62:57: loop_complete
    │ │ │ │ │ ├─x = 2
    │ │ │ │ │ ├─"test/test_expect_test.ml":61:8: z
    │ │ │ │ │ │ └─z = 0
    │ │ │ │ │ ├─"test/test_expect_test.ml":60:40-62:57: loop_complete
    │ │ │ │ │ │ ├─x = 1
    │ │ │ │ │ │ ├─"test/test_expect_test.ml":61:8: z
    │ │ │ │ │ │ │ └─z = 0
    │ │ │ │ │ │ ├─"test/test_expect_test.ml":60:40-62:57: loop_complete
    │ │ │ │ │ │ │ ├─x = 0
    │ │ │ │ │ │ │ ├─"test/test_expect_test.ml":61:8: z
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
  "test/test_expect_test.ml":109:39-113:56: loop_changes
  ├─x = 7
  ├─"test/test_expect_test.ml":110:8: z
  │ └─z = 3
  ├─"test/test_expect_test.ml":109:39-113:56: loop_changes
  │ ├─x = 6
  │ ├─"test/test_expect_test.ml":110:8: z
  │ │ └─z = 2
  │ ├─"test/test_expect_test.ml":109:39-113:56: loop_changes
  │ │ ├─x = 5
  │ │ ├─"test/test_expect_test.ml":110:8: z
  │ │ │ └─z = 2
  │ │ └─loop_changes = 4
  │ └─loop_changes = 6
  └─loop_changes = 9
  9 |}]

let%expect_test "%debug_show PrintBox to stdout with exception" =
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
    "test/test_expect_test.ml":137:41-140:36: loop_truncated
    ├─x = 7
    ├─"test/test_expect_test.ml":138:8: z
    │ └─z = 3
    └─"test/test_expect_test.ml":137:41-140:36: loop_truncated
      ├─x = 6
      ├─"test/test_expect_test.ml":138:8: z
      │ └─z = 2
      └─"test/test_expect_test.ml":137:41-140:36: loop_truncated
        ├─x = 5
        ├─"test/test_expect_test.ml":138:8: z
        │ └─z = 2
        └─"test/test_expect_test.ml":137:41-140:36: loop_truncated
          ├─x = 4
          ├─"test/test_expect_test.ml":138:8: z
          │ └─z = 1
          └─"test/test_expect_test.ml":137:41-140:36: loop_truncated
            ├─x = 3
            ├─"test/test_expect_test.ml":138:8: z
            │ └─z = 1
            └─"test/test_expect_test.ml":137:41-140:36: loop_truncated
              ├─x = 2
              ├─"test/test_expect_test.ml":138:8: z
              │ └─z = 0
              └─"test/test_expect_test.ml":137:41-140:36: loop_truncated
                ├─x = 1
                ├─"test/test_expect_test.ml":138:8: z
                │ └─z = 0
                └─"test/test_expect_test.ml":137:41-140:36: loop_truncated
                  ├─x = 0
                  └─"test/test_expect_test.ml":138:8: z
                    └─z = 0
    Raised exception. |}]

let%expect_test "%debug_show PrintBox to stdout depth exceeded" =
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
      "test/test_expect_test.ml":185:40-189:60: loop_exceeded
      ├─x = 7
      ├─"test/test_expect_test.ml":188:10: z
      │ └─z = 3
      └─"test/test_expect_test.ml":185:40-189:60: loop_exceeded
        ├─x = 6
        ├─"test/test_expect_test.ml":188:10: z
        │ └─z = 2
        └─"test/test_expect_test.ml":185:40-189:60: loop_exceeded
          ├─x = 5
          ├─"test/test_expect_test.ml":188:10: z
          │ └─z = 2
          └─"test/test_expect_test.ml":185:40-189:60: loop_exceeded
            ├─x = 4
            ├─"test/test_expect_test.ml":188:10: z
            │ └─z = 1
            └─"test/test_expect_test.ml":185:40-189:60: loop_exceeded
              ├─x = 3
              └─"test/test_expect_test.ml":188:10: z
                └─z = <max_nesting_depth exceeded>
      Raised exception. |}]

let%expect_test "%debug_show PrintBox to stdout num children exceeded linear" =
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
    "test/test_expect_test.ml":224:26: _bar
    ├─"test/test_expect_test.ml":228:16: _baz
    │ └─_baz = 0
    ├─"test/test_expect_test.ml":228:16: _baz
    │ └─_baz = 2
    ├─"test/test_expect_test.ml":228:16: _baz
    │ └─_baz = 4
    ├─"test/test_expect_test.ml":228:16: _baz
    │ └─_baz = 6
    ├─"test/test_expect_test.ml":228:16: _baz
    │ └─_baz = 8
    ├─"test/test_expect_test.ml":228:16: _baz
    │ └─_baz = 10
    ├─"test/test_expect_test.ml":228:16: _baz
    │ └─_baz = 12
    ├─"test/test_expect_test.ml":228:16: _baz
    │ └─_baz = 14
    ├─"test/test_expect_test.ml":228:16: _baz
    │ └─_baz = 16
    ├─"test/test_expect_test.ml":228:16: _baz
    │ └─_baz = 18
    ├─"test/test_expect_test.ml":228:16: _baz
    │ └─_baz = 20
    └─_baz = <max_num_children exceeded>
    Raised exception: ppx_minidebug: max_num_children exceeded |}]

let%expect_test "%debug_show PrintBox to stdout track for-loop num children exceeded" =
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
    "test/test_expect_test.ml":268:26: _bar
    └─"test/test_expect_test.ml":271:10: <for loop>
      ├─i = 0
      ├─"test/test_expect_test.ml":271:14: <for i>
      │ └─"test/test_expect_test.ml":272:16: _baz
      │   └─_baz = 0
      ├─i = 1
      ├─"test/test_expect_test.ml":271:14: <for i>
      │ └─"test/test_expect_test.ml":272:16: _baz
      │   └─_baz = 2
      ├─i = 2
      ├─"test/test_expect_test.ml":271:14: <for i>
      │ └─"test/test_expect_test.ml":272:16: _baz
      │   └─_baz = 4
      ├─i = 3
      ├─"test/test_expect_test.ml":271:14: <for i>
      │ └─"test/test_expect_test.ml":272:16: _baz
      │   └─_baz = 6
      ├─i = 4
      ├─"test/test_expect_test.ml":271:14: <for i>
      │ └─"test/test_expect_test.ml":272:16: _baz
      │   └─_baz = 8
      ├─i = 5
      └─i = <max_num_children exceeded>
    Raised exception: ppx_minidebug: max_num_children exceeded |}]

let%expect_test "%debug_show PrintBox to stdout track for-loop" =
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
      "test/test_expect_test.ml":312:26: _bar
      ├─"test/test_expect_test.ml":315:10: <for loop>
      │ ├─i = 0
      │ ├─"test/test_expect_test.ml":315:14: <for i>
      │ │ └─"test/test_expect_test.ml":316:16: _baz
      │ │   └─_baz = 0
      │ ├─i = 1
      │ ├─"test/test_expect_test.ml":315:14: <for i>
      │ │ └─"test/test_expect_test.ml":316:16: _baz
      │ │   └─_baz = 2
      │ ├─i = 2
      │ ├─"test/test_expect_test.ml":315:14: <for i>
      │ │ └─"test/test_expect_test.ml":316:16: _baz
      │ │   └─_baz = 4
      │ ├─i = 3
      │ ├─"test/test_expect_test.ml":315:14: <for i>
      │ │ └─"test/test_expect_test.ml":316:16: _baz
      │ │   └─_baz = 6
      │ ├─i = 4
      │ ├─"test/test_expect_test.ml":315:14: <for i>
      │ │ └─"test/test_expect_test.ml":316:16: _baz
      │ │   └─_baz = 8
      │ ├─i = 5
      │ ├─"test/test_expect_test.ml":315:14: <for i>
      │ │ └─"test/test_expect_test.ml":316:16: _baz
      │ │   └─_baz = 10
      │ ├─i = 6
      │ └─"test/test_expect_test.ml":315:14: <for i>
      │   └─"test/test_expect_test.ml":316:16: _baz
      │     └─_baz = 12
      └─_bar = () |}]

let%expect_test "%debug_show PrintBox to stdout track while-loop" =
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
    "test/test_expect_test.ml":362:26: _bar
    ├─"test/test_expect_test.ml":364:8: <while loop>
    │ ├─"test/test_expect_test.ml":365:10: <while loop>
    │ │ └─"test/test_expect_test.ml":365:14: _baz
    │ │   └─_baz = 0
    │ ├─"test/test_expect_test.ml":365:10: <while loop>
    │ │ └─"test/test_expect_test.ml":365:14: _baz
    │ │   └─_baz = 2
    │ ├─"test/test_expect_test.ml":365:10: <while loop>
    │ │ └─"test/test_expect_test.ml":365:14: _baz
    │ │   └─_baz = 4
    │ ├─"test/test_expect_test.ml":365:10: <while loop>
    │ │ └─"test/test_expect_test.ml":365:14: _baz
    │ │   └─_baz = 6
    │ ├─"test/test_expect_test.ml":365:10: <while loop>
    │ │ └─"test/test_expect_test.ml":365:14: _baz
    │ │   └─_baz = 8
    │ └─"test/test_expect_test.ml":365:10: <while loop>
    │   └─"test/test_expect_test.ml":365:14: _baz
    │     └─_baz = 10
    └─_bar = ()
        |}]

let%expect_test "%debug_show PrintBox to stdout num children exceeded nested" =
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
      "test/test_expect_test.ml":400:40-408:72: loop_exceeded
      ├─x = 3
      ├─"test/test_expect_test.ml":407:17: z
      │ └─z = 1
      └─"test/test_expect_test.ml":400:40-408:72: loop_exceeded
        ├─x = 2
        ├─"test/test_expect_test.ml":407:17: z
        │ └─z = 0
        └─"test/test_expect_test.ml":400:40-408:72: loop_exceeded
          ├─x = 1
          ├─"test/test_expect_test.ml":407:17: z
          │ └─z = 0
          └─"test/test_expect_test.ml":400:40-408:72: loop_exceeded
            ├─x = 0
            ├─"test/test_expect_test.ml":407:17: z
            │ └─z = 0
            ├─"test/test_expect_test.ml":407:17: z
            │ └─z = 1
            ├─"test/test_expect_test.ml":407:17: z
            │ └─z = 2
            ├─"test/test_expect_test.ml":407:17: z
            │ └─z = 3
            ├─"test/test_expect_test.ml":407:17: z
            │ └─z = 4
            ├─"test/test_expect_test.ml":407:17: z
            │ └─z = 5
            ├─"test/test_expect_test.ml":407:17: z
            │ └─z = 6
            ├─"test/test_expect_test.ml":407:17: z
            │ └─z = 7
            ├─"test/test_expect_test.ml":407:17: z
            │ └─z = 8
            ├─"test/test_expect_test.ml":407:17: z
            │ └─z = 9
            └─z = <max_num_children exceeded>
      Raised exception: ppx_minidebug: max_num_children exceeded |}]

let%expect_test "%debug_show PrintBox to stdout highlight" =
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
      │"test/test_expect_test.ml":458:41-462:61: loop_highlight│
      ├────────────────────────────────────────────────────────┘
      ├─x = 7
      ├─┬────────────────────────────────────┐
      │ │"test/test_expect_test.ml":461:10: z│
      │ ├────────────────────────────────────┘
      │ └─┬─────┐
      │   │z = 3│
      │   └─────┘
      ├─┬────────────────────────────────────────────────────────┐
      │ │"test/test_expect_test.ml":458:41-462:61: loop_highlight│
      │ ├────────────────────────────────────────────────────────┘
      │ ├─x = 6
      │ ├─"test/test_expect_test.ml":461:10: z
      │ │ └─z = 2
      │ ├─┬────────────────────────────────────────────────────────┐
      │ │ │"test/test_expect_test.ml":458:41-462:61: loop_highlight│
      │ │ ├────────────────────────────────────────────────────────┘
      │ │ ├─x = 5
      │ │ ├─"test/test_expect_test.ml":461:10: z
      │ │ │ └─z = 2
      │ │ ├─┬────────────────────────────────────────────────────────┐
      │ │ │ │"test/test_expect_test.ml":458:41-462:61: loop_highlight│
      │ │ │ ├────────────────────────────────────────────────────────┘
      │ │ │ ├─x = 4
      │ │ │ ├─"test/test_expect_test.ml":461:10: z
      │ │ │ │ └─z = 1
      │ │ │ ├─┬────────────────────────────────────────────────────────┐
      │ │ │ │ │"test/test_expect_test.ml":458:41-462:61: loop_highlight│
      │ │ │ │ ├────────────────────────────────────────────────────────┘
      │ │ │ │ ├─┬─────┐
      │ │ │ │ │ │x = 3│
      │ │ │ │ │ └─────┘
      │ │ │ │ ├─"test/test_expect_test.ml":461:10: z
      │ │ │ │ │ └─z = 1
      │ │ │ │ ├─"test/test_expect_test.ml":458:41-462:61: loop_highlight
      │ │ │ │ │ ├─x = 2
      │ │ │ │ │ ├─"test/test_expect_test.ml":461:10: z
      │ │ │ │ │ │ └─z = 0
      │ │ │ │ │ ├─"test/test_expect_test.ml":458:41-462:61: loop_highlight
      │ │ │ │ │ │ ├─x = 1
      │ │ │ │ │ │ ├─"test/test_expect_test.ml":461:10: z
      │ │ │ │ │ │ │ └─z = 0
      │ │ │ │ │ │ ├─"test/test_expect_test.ml":458:41-462:61: loop_highlight
      │ │ │ │ │ │ │ ├─x = 0
      │ │ │ │ │ │ │ ├─"test/test_expect_test.ml":461:10: z
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

let%expect_test "%debug_show PrintBox tracking" =
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
      "test/test_expect_test.ml":528:37-530:46: track_branches
      ├─x = 7
      ├─"test/test_expect_test.ml":530:9: <if -- else branch>
      │ └─"test/test_expect_test.ml":530:36-530:37: <match -- branch 1>
      └─track_branches = 4
      4
      "test/test_expect_test.ml":528:37-530:46: track_branches
      ├─x = 3
      ├─"test/test_expect_test.ml":529:18: <if -- then branch>
      │ └─"test/test_expect_test.ml":529:54-529:57: <match -- branch 2>
      └─track_branches = -3
      -3
    |}]

let%expect_test "%debug_show PrintBox tracking <function>" =
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
      "test/test_expect_test.ml":561:11-561:12: <function -- branch 3>
      4
      "test/test_expect_test.ml":563:11-563:14: <function -- branch 5> x
      -3
    |}]

let%expect_test "%debug_show PrintBox tracking with debug_notrace" =
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
      "test/test_expect_test.ml":582:37-596:16: track_branches
      ├─x = 8
      ├─"test/test_expect_test.ml":591:6: <if -- else branch>
      │ └─"test/test_expect_test.ml":595:10-596:16: <match -- branch 2>
      │   └─"test/test_expect_test.ml":595:14: result
      │     ├─"test/test_expect_test.ml":595:44: <if -- then branch>
      │     └─result = 8
      └─track_branches = 8
      8
      "test/test_expect_test.ml":582:37-596:16: track_branches
      ├─x = 3
      ├─"test/test_expect_test.ml":584:6: <if -- then branch>
      │ └─"test/test_expect_test.ml":588:14: result
      │   └─result = 3
      └─track_branches = 3
      3
    |}]

let%expect_test "nested extension points are no-ops" =
  let module Debug_runtime = (val Minidebug_runtime.debug ()) in
  let%track_this_show track_branches (x : int) : int =
    if x < 6 then
      match%debug_notrace x with
      | 0 -> 1
      | 1 -> 0
      | _ ->
          let%debug_sexp result : int = if x > 2 then x else ~-x in
          result
    else
      match%debug_pp x with
      | 6 -> 5
      | 7 -> 4
      | _ ->
          let%track_pp result : int = if x < 10 then x else ~-x in
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
      "test/test_expect_test.ml":627:37-641:16: track_branches
      ├─x = 8
      ├─"test/test_expect_test.ml":636:6: <if -- else branch>
      │ └─"test/test_expect_test.ml":640:10-641:16: <match -- branch 2>
      │   └─"test/test_expect_test.ml":640:23: result
      │     ├─"test/test_expect_test.ml":640:53: <if -- then branch>
      │     └─result = 8
      └─track_branches = 8
      8
      "test/test_expect_test.ml":627:37-641:16: track_branches
      ├─x = 3
      ├─"test/test_expect_test.ml":629:6: <if -- then branch>
      │ └─"test/test_expect_test.ml":633:25: result
      │   └─result = 3
      └─track_branches = 3
      3
    |}]

let%expect_test "%track_show PrintBox to stdout no return type anonymous fun" =
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
      "test/test_expect_test.ml":683:32-684:70: anonymous
      ├─x = 3
      ├─"test/test_expect_test.ml":684:50-684:70: __fun
      │ └─i = 0
      ├─"test/test_expect_test.ml":684:50-684:70: __fun
      │ └─i = 1
      ├─"test/test_expect_test.ml":684:50-684:70: __fun
      │ └─i = 2
      └─"test/test_expect_test.ml":684:50-684:70: __fun
        └─i = 3
      6
    |}]

let%expect_test "%track_show PrintBox to stdout anonymous fun, num children exceeded" =
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
      "test/test_expect_test.ml":707:40-715:72: loop_exceeded
      ├─x = 3
      └─"test/test_expect_test.ml":713:11-715:71: __fun
        ├─i = 0
        ├─"test/test_expect_test.ml":714:17: z
        │ └─z = 1
        └─"test/test_expect_test.ml":715:35: <if -- else branch>
          └─"test/test_expect_test.ml":707:40-715:72: loop_exceeded
            ├─x = 2
            └─"test/test_expect_test.ml":713:11-715:71: __fun
              ├─i = 0
              ├─"test/test_expect_test.ml":714:17: z
              │ └─z = 0
              └─"test/test_expect_test.ml":715:35: <if -- else branch>
                └─"test/test_expect_test.ml":707:40-715:72: loop_exceeded
                  ├─x = 1
                  └─"test/test_expect_test.ml":713:11-715:71: __fun
                    ├─i = 0
                    ├─"test/test_expect_test.ml":714:17: z
                    │ └─z = 0
                    └─"test/test_expect_test.ml":715:35: <if -- else branch>
                      └─"test/test_expect_test.ml":707:40-715:72: loop_exceeded
                        ├─x = 0
                        ├─"test/test_expect_test.ml":713:11-715:71: __fun
                        │ ├─i = 0
                        │ ├─"test/test_expect_test.ml":714:17: z
                        │ │ └─z = 0
                        │ └─"test/test_expect_test.ml":715:28: <if -- then branch>
                        ├─"test/test_expect_test.ml":713:11-715:71: __fun
                        │ ├─i = 1
                        │ ├─"test/test_expect_test.ml":714:17: z
                        │ │ └─z = 1
                        │ └─"test/test_expect_test.ml":715:28: <if -- then branch>
                        ├─"test/test_expect_test.ml":713:11-715:71: __fun
                        │ ├─i = 2
                        │ ├─"test/test_expect_test.ml":714:17: z
                        │ │ └─z = 2
                        │ └─"test/test_expect_test.ml":715:28: <if -- then branch>
                        ├─"test/test_expect_test.ml":713:11-715:71: __fun
                        │ ├─i = 3
                        │ ├─"test/test_expect_test.ml":714:17: z
                        │ │ └─z = 3
                        │ └─"test/test_expect_test.ml":715:28: <if -- then branch>
                        ├─"test/test_expect_test.ml":713:11-715:71: __fun
                        │ ├─i = 4
                        │ ├─"test/test_expect_test.ml":714:17: z
                        │ │ └─z = 4
                        │ └─"test/test_expect_test.ml":715:28: <if -- then branch>
                        ├─"test/test_expect_test.ml":713:11-715:71: __fun
                        │ ├─i = 5
                        │ ├─"test/test_expect_test.ml":714:17: z
                        │ │ └─z = 5
                        │ └─"test/test_expect_test.ml":715:28: <if -- then branch>
                        ├─"test/test_expect_test.ml":713:11-715:71: __fun
                        │ ├─i = 6
                        │ ├─"test/test_expect_test.ml":714:17: z
                        │ │ └─z = 6
                        │ └─"test/test_expect_test.ml":715:28: <if -- then branch>
                        ├─"test/test_expect_test.ml":713:11-715:71: __fun
                        │ ├─i = 7
                        │ ├─"test/test_expect_test.ml":714:17: z
                        │ │ └─z = 7
                        │ └─"test/test_expect_test.ml":715:28: <if -- then branch>
                        ├─"test/test_expect_test.ml":713:11-715:71: __fun
                        │ ├─i = 8
                        │ ├─"test/test_expect_test.ml":714:17: z
                        │ │ └─z = 8
                        │ └─"test/test_expect_test.ml":715:28: <if -- then branch>
                        ├─"test/test_expect_test.ml":713:11-715:71: __fun
                        │ ├─i = 9
                        │ ├─"test/test_expect_test.ml":714:17: z
                        │ │ └─z = 9
                        │ └─"test/test_expect_test.ml":715:28: <if -- then branch>
                        └─__fun = <max_num_children exceeded>
      Raised exception: ppx_minidebug: max_num_children exceeded
    |}]

module type T = sig
  type c

  val c : c
end

let%expect_test "%track_show PrintBox to stdout function with abstract type" =
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
      "test/test_expect_test.ml":809:26-810:47: foo
      ├─c = 1
      └─foo = 2
      2
    |}]

let%expect_test "%debug_show PrintBox values_first_mode to stdout with exception" =
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
  ├─"test/test_expect_test.ml":835:41-838:36
  ├─x = 7
  ├─z = 3
  │ └─"test/test_expect_test.ml":836:8
  └─loop_truncated
    ├─"test/test_expect_test.ml":835:41-838:36
    ├─x = 6
    ├─z = 2
    │ └─"test/test_expect_test.ml":836:8
    └─loop_truncated
      ├─"test/test_expect_test.ml":835:41-838:36
      ├─x = 5
      ├─z = 2
      │ └─"test/test_expect_test.ml":836:8
      └─loop_truncated
        ├─"test/test_expect_test.ml":835:41-838:36
        ├─x = 4
        ├─z = 1
        │ └─"test/test_expect_test.ml":836:8
        └─loop_truncated
          ├─"test/test_expect_test.ml":835:41-838:36
          ├─x = 3
          ├─z = 1
          │ └─"test/test_expect_test.ml":836:8
          └─loop_truncated
            ├─"test/test_expect_test.ml":835:41-838:36
            ├─x = 2
            ├─z = 0
            │ └─"test/test_expect_test.ml":836:8
            └─loop_truncated
              ├─"test/test_expect_test.ml":835:41-838:36
              ├─x = 1
              ├─z = 0
              │ └─"test/test_expect_test.ml":836:8
              └─loop_truncated
                ├─"test/test_expect_test.ml":835:41-838:36
                ├─x = 0
                └─z = 0
                  └─"test/test_expect_test.ml":836:8
  Raised exception. |}]

let%expect_test "%debug_show PrintBox values_first_mode to stdout num children exceeded \
                 linear" =
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
    ├─"test/test_expect_test.ml":894:26
    ├─_baz = 0
    │ └─"test/test_expect_test.ml":898:16
    ├─_baz = 2
    │ └─"test/test_expect_test.ml":898:16
    ├─_baz = 4
    │ └─"test/test_expect_test.ml":898:16
    ├─_baz = 6
    │ └─"test/test_expect_test.ml":898:16
    ├─_baz = 8
    │ └─"test/test_expect_test.ml":898:16
    ├─_baz = 10
    │ └─"test/test_expect_test.ml":898:16
    ├─_baz = 12
    │ └─"test/test_expect_test.ml":898:16
    ├─_baz = 14
    │ └─"test/test_expect_test.ml":898:16
    ├─_baz = 16
    │ └─"test/test_expect_test.ml":898:16
    ├─_baz = 18
    │ └─"test/test_expect_test.ml":898:16
    ├─_baz = 20
    │ └─"test/test_expect_test.ml":898:16
    └─_baz = <max_num_children exceeded>
    Raised exception: ppx_minidebug: max_num_children exceeded |}]

let%expect_test "%debug_show PrintBox values_first_mode to stdout track for-loop" =
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
      ├─"test/test_expect_test.ml":939:26
      └─<for loop>
        ├─"test/test_expect_test.ml":942:10
        ├─i = 0
        ├─<for i>
        │ ├─"test/test_expect_test.ml":942:14
        │ └─_baz = 0
        │   └─"test/test_expect_test.ml":943:16
        ├─i = 1
        ├─<for i>
        │ ├─"test/test_expect_test.ml":942:14
        │ └─_baz = 2
        │   └─"test/test_expect_test.ml":943:16
        ├─i = 2
        ├─<for i>
        │ ├─"test/test_expect_test.ml":942:14
        │ └─_baz = 4
        │   └─"test/test_expect_test.ml":943:16
        ├─i = 3
        ├─<for i>
        │ ├─"test/test_expect_test.ml":942:14
        │ └─_baz = 6
        │   └─"test/test_expect_test.ml":943:16
        ├─i = 4
        ├─<for i>
        │ ├─"test/test_expect_test.ml":942:14
        │ └─_baz = 8
        │   └─"test/test_expect_test.ml":943:16
        ├─i = 5
        ├─<for i>
        │ ├─"test/test_expect_test.ml":942:14
        │ └─_baz = 10
        │   └─"test/test_expect_test.ml":943:16
        ├─i = 6
        └─<for i>
          ├─"test/test_expect_test.ml":942:14
          └─_baz = 12
            └─"test/test_expect_test.ml":943:16 |}]

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
      ├─"test/test_expect_test.ml":996:40-1004:72
      ├─x = 3
      ├─z = 1
      │ └─"test/test_expect_test.ml":1003:17
      └─loop_exceeded
        ├─"test/test_expect_test.ml":996:40-1004:72
        ├─x = 2
        ├─z = 0
        │ └─"test/test_expect_test.ml":1003:17
        └─loop_exceeded
          ├─"test/test_expect_test.ml":996:40-1004:72
          ├─x = 1
          ├─z = 0
          │ └─"test/test_expect_test.ml":1003:17
          └─loop_exceeded
            ├─"test/test_expect_test.ml":996:40-1004:72
            ├─x = 0
            ├─z = 0
            │ └─"test/test_expect_test.ml":1003:17
            ├─z = 1
            │ └─"test/test_expect_test.ml":1003:17
            ├─z = 2
            │ └─"test/test_expect_test.ml":1003:17
            ├─z = 3
            │ └─"test/test_expect_test.ml":1003:17
            ├─z = 4
            │ └─"test/test_expect_test.ml":1003:17
            ├─z = 5
            │ └─"test/test_expect_test.ml":1003:17
            ├─z = 6
            │ └─"test/test_expect_test.ml":1003:17
            ├─z = 7
            │ └─"test/test_expect_test.ml":1003:17
            ├─z = 8
            │ └─"test/test_expect_test.ml":1003:17
            ├─z = 9
            │ └─"test/test_expect_test.ml":1003:17
            └─z = <max_num_children exceeded>
      Raised exception: ppx_minidebug: max_num_children exceeded |}]

let%expect_test "%debug_show PrintBox values_first_mode to stdout highlight" =
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
      ├─"test/test_expect_test.ml":1058:41-1060:58
      ├─x = 7
      ├─┬─────┐
      │ │z = 3│
      │ ├─────┘
      │ └─"test/test_expect_test.ml":1059:8
      └─┬──────────────────┐
        │loop_highlight = 6│
        ├──────────────────┘
        ├─"test/test_expect_test.ml":1058:41-1060:58
        ├─x = 6
        ├─z = 2
        │ └─"test/test_expect_test.ml":1059:8
        └─┬──────────────────┐
          │loop_highlight = 4│
          ├──────────────────┘
          ├─"test/test_expect_test.ml":1058:41-1060:58
          ├─x = 5
          ├─z = 2
          │ └─"test/test_expect_test.ml":1059:8
          └─┬──────────────────┐
            │loop_highlight = 2│
            ├──────────────────┘
            ├─"test/test_expect_test.ml":1058:41-1060:58
            ├─x = 4
            ├─z = 1
            │ └─"test/test_expect_test.ml":1059:8
            └─┬──────────────────┐
              │loop_highlight = 1│
              ├──────────────────┘
              ├─"test/test_expect_test.ml":1058:41-1060:58
              ├─┬─────┐
              │ │x = 3│
              │ └─────┘
              ├─z = 1
              │ └─"test/test_expect_test.ml":1059:8
              └─loop_highlight = 0
                ├─"test/test_expect_test.ml":1058:41-1060:58
                ├─x = 2
                ├─z = 0
                │ └─"test/test_expect_test.ml":1059:8
                └─loop_highlight = 0
                  ├─"test/test_expect_test.ml":1058:41-1060:58
                  ├─x = 1
                  ├─z = 0
                  │ └─"test/test_expect_test.ml":1059:8
                  └─loop_highlight = 0
                    ├─"test/test_expect_test.ml":1058:41-1060:58
                    ├─x = 0
                    └─z = 0
                      └─"test/test_expect_test.ml":1059:8
      9 |}]

let%expect_test "%debug_show PrintBox values_first_mode tracking" =
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
      ├─"test/test_expect_test.ml":1124:37-1126:46
      ├─x = 7
      └─<if -- else branch>
        ├─"test/test_expect_test.ml":1126:9
        └─<match -- branch 1>
          └─"test/test_expect_test.ml":1126:36-1126:37
      4
      track_branches = -3
      ├─"test/test_expect_test.ml":1124:37-1126:46
      ├─x = 3
      └─<if -- then branch>
        ├─"test/test_expect_test.ml":1125:18
        └─<match -- branch 2>
          └─"test/test_expect_test.ml":1125:54-1125:57
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
      ├─"test/test_expect_test.ml":1158:32-1159:70
      ├─x = 3
      ├─i = 0
      │ └─"test/test_expect_test.ml":1159:50-1159:70
      ├─i = 1
      │ └─"test/test_expect_test.ml":1159:50-1159:70
      ├─i = 2
      │ └─"test/test_expect_test.ml":1159:50-1159:70
      └─i = 3
        └─"test/test_expect_test.ml":1159:50-1159:70
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
    "test/test_expect_test.ml":1184:21-1187:15: bar
    ├─first = 7
    ├─second = 42
    ├─"test/test_expect_test.ml":1185:8: {first=a; second=b}
    │ ├─a = 7
    │ └─b = 45
    ├─"test/test_expect_test.ml":1186:8: y
    │ └─y = 8
    └─bar = 336
    336
    "test/test_expect_test.ml":1190:10-1192:28: baz
    ├─first = 7
    ├─second = 42
    ├─"test/test_expect_test.ml":1191:8: {first; second}
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
    "test/test_expect_test.ml":1219:21-1221:14: bar
    ├─first = 7
    ├─second = 42
    ├─"test/test_expect_test.ml":1220:8: y
    │ └─y = 8
    └─bar = 336
    336
    "test/test_expect_test.ml":1229:6: (r1, r2)
    ├─"test/test_expect_test.ml":1224:10-1227:35: baz
    │ ├─first = 7
    │ ├─second = 42
    │ ├─"test/test_expect_test.ml":1225:8: (y, z)
    │ │ ├─y = 8
    │ │ └─z = 3
    │ ├─"test/test_expect_test.ml":1226:8: (a, b)
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
      ├─"test/test_expect_test.ml":1260:21-1263:15
      ├─first = 7
      ├─second = 42
      ├─{first=a; second=b}
      │ ├─"test/test_expect_test.ml":1261:8
      │ └─<values>
      │   ├─a = 7
      │   └─b = 45
      └─y = 8
        └─"test/test_expect_test.ml":1262:8
      336
      baz = 109
      ├─"test/test_expect_test.ml":1266:10-1268:28
      ├─first = 7
      ├─second = 42
      └─{first; second}
        ├─"test/test_expect_test.ml":1267:8
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
    ├─"test/test_expect_test.ml":1299:21-1301:14
    ├─first = 7
    ├─second = 42
    └─y = 8
      └─"test/test_expect_test.ml":1300:8
    336
    (r1, r2)
    ├─"test/test_expect_test.ml":1309:6
    ├─<values>
    │ ├─r1 = 339
    │ └─r2 = 109
    └─baz = (339, 109)
      ├─"test/test_expect_test.ml":1304:10-1307:35
      ├─first = 7
      ├─second = 42
      ├─(y, z)
      │ ├─"test/test_expect_test.ml":1305:8
      │ └─<values>
      │   ├─y = 8
      │   └─z = 3
      └─(a, b)
        ├─"test/test_expect_test.ml":1306:8
        └─<values>
          ├─a = 8
          └─b = 45
    339
    109 |}]

type 'a irrefutable = Zero of 'a
type ('a, 'b) left_right = Left of 'a | Right of 'b
type ('a, 'b, 'c) one_two_three = One of 'a | Two of 'b | Three of 'c

let%expect_test "%debug_show PrintBox to stdout variants values_first_mode" =
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
      ├─"test/test_expect_test.ml":1350:21-1352:9
      ├─x = 7
      └─y = 8
        └─"test/test_expect_test.ml":1351:8
      16
      baz = 5
      ├─"test/test_expect_test.ml":1356:24-1356:29
      └─x = 4
      5
      baz = 6
      ├─"test/test_expect_test.ml":1357:31-1357:36
      └─y = 3
      6
      foo = 3
      ├─"test/test_expect_test.ml":1360:10-1361:82
      └─<match -- branch 2>
        └─"test/test_expect_test.ml":1361:81-1361:82
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
    ├─"test/test_expect_test.ml":1396:6
    ├─<values>
    │ ├─r1 = 339
    │ └─r2 = 109
    └─baz = (339, 109)
      ├─"test/test_expect_test.ml":1391:21-1394:35
      ├─first = 7
      ├─second = 42
      ├─(y, z)
      │ ├─"test/test_expect_test.ml":1392:8
      │ └─<values>
      │   ├─y = 8
      │   └─z = 3
      └─(a, b)
        ├─"test/test_expect_test.ml":1393:8
        └─<values>
          └─a = 8
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
    ├─"test/test_expect_test.ml":1426:44-1426:61
    └─b = 6
    7
    g = 12
    ├─"test/test_expect_test.ml":1427:56-1427:79
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
      ├─"test/test_expect_test.ml":1446:37-1446:54
      └─b : int = 6
      7
      g : int = 12
      ├─"test/test_expect_test.ml":1447:49-1447:72
      └─b : int = 6
      12 |}]

let%expect_test "%debug_show PrintBox to stdout options values_first_mode" =
  let module Debug_runtime = (val Minidebug_runtime.debug ~values_first_mode:true ()) in
  let%track_show foo l : int =
    match (l : int option) with None -> 7 | Some y -> y * 2
  in
  let () = print_endline @@ Int.to_string @@ foo (Some 7) in
  let%track_show bar (l : int option) : int =
    match l with None -> 7 | Some y -> y * 2
  in
  let () = print_endline @@ Int.to_string @@ bar (Some 7) in
  let baz : int option -> int = function None -> 7 | Some y -> y * 2 in
  let () = print_endline @@ Int.to_string @@ baz (Some 4) in
  [%expect
    {|
      BEGIN DEBUG SESSION
      foo = 14
      ├─"test/test_expect_test.ml":1464:21-1465:59
      └─y = 7
        └─"test/test_expect_test.ml":1465:54-1465:59
      14
      bar = 14
      ├─"test/test_expect_test.ml":1468:21-1469:44
      ├─l = (Some 7)
      └─<match -- branch 1> Some y
        └─"test/test_expect_test.ml":1469:39-1469:44
      14
      baz = 8
      ├─"test/test_expect_test.ml":1472:63-1472:68
      └─y = 4
      8 |}]

let%expect_test "%debug_show PrintBox to stdout list values_first_mode" =
  let module Debug_runtime = (val Minidebug_runtime.debug ~values_first_mode:true ()) in
  let%track_show foo l : int = match (l : int list) with [] -> 7 | y :: _ -> y * 2 in
  let () = print_endline @@ Int.to_string @@ foo [ 7 ] in
  let%track_show bar (l : int list) : int = match l with [] -> 7 | y :: _ -> y * 2 in
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
      ├─"test/test_expect_test.ml":1490:21-1490:82
      └─<match -- branch 1> :: (y, _)
        ├─"test/test_expect_test.ml":1490:77-1490:82
        └─<values>
          └─y = 7
      14
      bar = 14
      ├─"test/test_expect_test.ml":1492:21-1492:82
      ├─l = [7]
      └─<match -- branch 1> :: (y, _)
        └─"test/test_expect_test.ml":1492:77-1492:82
      14
      <function -- branch 1> :: (y, [])
      ├─"test/test_expect_test.ml":1496:15-1496:20
      └─<values>
        ├─y = 4
        └─baz = 8
      8
      <function -- branch 2> :: (y, :: (z, []))
      ├─"test/test_expect_test.ml":1497:18-1497:23
      └─<values>
        ├─y = 4
        ├─z = 5
        └─baz = 9
      9
      <function -- branch 3> :: (y, :: (z, _))
      ├─"test/test_expect_test.ml":1498:21-1498:30
      └─<values>
        ├─y = 4
        ├─z = 5
        └─baz = 10
      10 |}]
