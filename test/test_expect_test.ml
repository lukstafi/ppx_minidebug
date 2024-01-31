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
  let module Debug_runtime = (val Minidebug_runtime.debug ~max_nesting_depth:5 ()) in
  let%debug_this_show rec loop_exceeded (x : int) : int =
    let z : int = (x - 1) / 2 in
    if x <= 0 then 0 else z + loop_exceeded (z + (x / 2))
  in
  let () =
    try print_endline @@ Int.to_string @@ loop_exceeded 7
    with _ -> print_endline "Raised exception."
  in
  [%expect
    {|
      BEGIN DEBUG SESSION
      "test/test_expect_test.ml":185:40-187:57: loop_exceeded
      ├─x = 7
      ├─"test/test_expect_test.ml":186:8: z
      │ └─z = 3
      └─"test/test_expect_test.ml":185:40-187:57: loop_exceeded
        ├─x = 6
        ├─"test/test_expect_test.ml":186:8: z
        │ └─z = 2
        └─"test/test_expect_test.ml":185:40-187:57: loop_exceeded
          ├─x = 5
          ├─"test/test_expect_test.ml":186:8: z
          │ └─z = 2
          └─"test/test_expect_test.ml":185:40-187:57: loop_exceeded
            ├─x = 4
            ├─"test/test_expect_test.ml":186:8: z
            │ └─z = 1
            └─"test/test_expect_test.ml":185:40-187:57: loop_exceeded
              ├─x = 3
              └─"test/test_expect_test.ml":186:8: z
                └─z = <max_nesting_depth exceeded>
      Raised exception. |}]

let%expect_test "%debug_show PrintBox to stdout num children exceeded linear" =
  let module Debug_runtime = (val Minidebug_runtime.debug ~max_num_children:10 ()) in
  let () =
    try
      let%debug_this_show _bar : unit =
        for i = 0 to 100 do
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
    "test/test_expect_test.ml":222:26: _bar
    ├─"test/test_expect_test.ml":224:14: _baz
    │ └─_baz = 0
    ├─"test/test_expect_test.ml":224:14: _baz
    │ └─_baz = 2
    ├─"test/test_expect_test.ml":224:14: _baz
    │ └─_baz = 4
    ├─"test/test_expect_test.ml":224:14: _baz
    │ └─_baz = 6
    ├─"test/test_expect_test.ml":224:14: _baz
    │ └─_baz = 8
    ├─"test/test_expect_test.ml":224:14: _baz
    │ └─_baz = 10
    ├─"test/test_expect_test.ml":224:14: _baz
    │ └─_baz = 12
    ├─"test/test_expect_test.ml":224:14: _baz
    │ └─_baz = 14
    ├─"test/test_expect_test.ml":224:14: _baz
    │ └─_baz = 16
    ├─"test/test_expect_test.ml":224:14: _baz
    │ └─_baz = 18
    ├─"test/test_expect_test.ml":224:14: _baz
    │ └─_baz = 20
    └─_baz = <max_num_children exceeded>
    Raised exception: ppx_minidebug: max_num_children exceeded |}]

let%expect_test "%debug_show PrintBox to stdout track for-loop num children exceeded" =
  let module Debug_runtime = (val Minidebug_runtime.debug ~max_num_children:10 ()) in
  let () =
    try
      let%track_this_show _bar : unit =
        for i = 0 to 100 do
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
    "test/test_expect_test.ml":264:26: _bar
    └─"test/test_expect_test.ml":265:8: <for loop>
      ├─i = 0
      ├─"test/test_expect_test.ml":265:12: <for i>
      │ └─"test/test_expect_test.ml":266:14: _baz
      │   └─_baz = 0
      ├─i = 1
      ├─"test/test_expect_test.ml":265:12: <for i>
      │ └─"test/test_expect_test.ml":266:14: _baz
      │   └─_baz = 2
      ├─i = 2
      ├─"test/test_expect_test.ml":265:12: <for i>
      │ └─"test/test_expect_test.ml":266:14: _baz
      │   └─_baz = 4
      ├─i = 3
      ├─"test/test_expect_test.ml":265:12: <for i>
      │ └─"test/test_expect_test.ml":266:14: _baz
      │   └─_baz = 6
      ├─i = 4
      ├─"test/test_expect_test.ml":265:12: <for i>
      │ └─"test/test_expect_test.ml":266:14: _baz
      │   └─_baz = 8
      ├─i = 5
      └─i = <max_num_children exceeded>
    Raised exception: ppx_minidebug: max_num_children exceeded |}]

let%expect_test "%debug_show PrintBox to stdout track for-loop" =
  let module Debug_runtime = (val Minidebug_runtime.debug ()) in
  let () =
    try
      let%track_this_show _bar : unit =
        for i = 0 to 6 do
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
      "test/test_expect_test.ml":306:26: _bar
      ├─"test/test_expect_test.ml":307:8: <for loop>
      │ ├─i = 0
      │ ├─"test/test_expect_test.ml":307:12: <for i>
      │ │ └─"test/test_expect_test.ml":308:14: _baz
      │ │   └─_baz = 0
      │ ├─i = 1
      │ ├─"test/test_expect_test.ml":307:12: <for i>
      │ │ └─"test/test_expect_test.ml":308:14: _baz
      │ │   └─_baz = 2
      │ ├─i = 2
      │ ├─"test/test_expect_test.ml":307:12: <for i>
      │ │ └─"test/test_expect_test.ml":308:14: _baz
      │ │   └─_baz = 4
      │ ├─i = 3
      │ ├─"test/test_expect_test.ml":307:12: <for i>
      │ │ └─"test/test_expect_test.ml":308:14: _baz
      │ │   └─_baz = 6
      │ ├─i = 4
      │ ├─"test/test_expect_test.ml":307:12: <for i>
      │ │ └─"test/test_expect_test.ml":308:14: _baz
      │ │   └─_baz = 8
      │ ├─i = 5
      │ ├─"test/test_expect_test.ml":307:12: <for i>
      │ │ └─"test/test_expect_test.ml":308:14: _baz
      │ │   └─_baz = 10
      │ ├─i = 6
      │ └─"test/test_expect_test.ml":307:12: <for i>
      │   └─"test/test_expect_test.ml":308:14: _baz
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
    "test/test_expect_test.ml":354:26: _bar
    ├─"test/test_expect_test.ml":356:8: <while loop>
    │ ├─"test/test_expect_test.ml":357:10: <while loop>
    │ │ └─"test/test_expect_test.ml":357:14: _baz
    │ │   └─_baz = 0
    │ ├─"test/test_expect_test.ml":357:10: <while loop>
    │ │ └─"test/test_expect_test.ml":357:14: _baz
    │ │   └─_baz = 2
    │ ├─"test/test_expect_test.ml":357:10: <while loop>
    │ │ └─"test/test_expect_test.ml":357:14: _baz
    │ │   └─_baz = 4
    │ ├─"test/test_expect_test.ml":357:10: <while loop>
    │ │ └─"test/test_expect_test.ml":357:14: _baz
    │ │   └─_baz = 6
    │ ├─"test/test_expect_test.ml":357:10: <while loop>
    │ │ └─"test/test_expect_test.ml":357:14: _baz
    │ │   └─_baz = 8
    │ └─"test/test_expect_test.ml":357:10: <while loop>
    │   └─"test/test_expect_test.ml":357:14: _baz
    │     └─_baz = 10
    └─_bar = ()
        |}]

let%expect_test "%debug_show PrintBox to stdout num children exceeded nested" =
  let module Debug_runtime = (val Minidebug_runtime.debug ~max_num_children:10 ()) in
  let%debug_this_show rec loop_exceeded (x : int) : int =
    Array.fold_left ( + ) 0
    @@ Array.init
         (100 / (x + 1))
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
      "test/test_expect_test.ml":392:40-398:69: loop_exceeded
      ├─x = 3
      ├─"test/test_expect_test.ml":397:15: z
      │ └─z = 1
      └─"test/test_expect_test.ml":392:40-398:69: loop_exceeded
        ├─x = 2
        ├─"test/test_expect_test.ml":397:15: z
        │ └─z = 0
        └─"test/test_expect_test.ml":392:40-398:69: loop_exceeded
          ├─x = 1
          ├─"test/test_expect_test.ml":397:15: z
          │ └─z = 0
          └─"test/test_expect_test.ml":392:40-398:69: loop_exceeded
            ├─x = 0
            ├─"test/test_expect_test.ml":397:15: z
            │ └─z = 0
            ├─"test/test_expect_test.ml":397:15: z
            │ └─z = 1
            ├─"test/test_expect_test.ml":397:15: z
            │ └─z = 2
            ├─"test/test_expect_test.ml":397:15: z
            │ └─z = 3
            ├─"test/test_expect_test.ml":397:15: z
            │ └─z = 4
            ├─"test/test_expect_test.ml":397:15: z
            │ └─z = 5
            ├─"test/test_expect_test.ml":397:15: z
            │ └─z = 6
            ├─"test/test_expect_test.ml":397:15: z
            │ └─z = 7
            ├─"test/test_expect_test.ml":397:15: z
            │ └─z = 8
            ├─"test/test_expect_test.ml":397:15: z
            │ └─z = 9
            └─z = <max_num_children exceeded>
      Raised exception: ppx_minidebug: max_num_children exceeded |}]

let%expect_test "%debug_show PrintBox to stdout highlight" =
  let module Debug_runtime =
    (val Minidebug_runtime.debug ~highlight_terms:(Re.str "3") ())
  in
  let%debug_this_show rec loop_highlight (x : int) : int =
    let z : int = (x - 1) / 2 in
    if x <= 0 then 0 else z + loop_highlight (z + (x / 2))
  in
  print_endline @@ Int.to_string @@ loop_highlight 7;
  [%expect
    {|
      BEGIN DEBUG SESSION
      ┌────────────────────────────────────────────────────────┐
      │"test/test_expect_test.ml":448:41-450:58: loop_highlight│
      ├────────────────────────────────────────────────────────┘
      ├─x = 7
      ├─┬───────────────────────────────────┐
      │ │"test/test_expect_test.ml":449:8: z│
      │ ├───────────────────────────────────┘
      │ └─┬─────┐
      │   │z = 3│
      │   └─────┘
      ├─┬────────────────────────────────────────────────────────┐
      │ │"test/test_expect_test.ml":448:41-450:58: loop_highlight│
      │ ├────────────────────────────────────────────────────────┘
      │ ├─x = 6
      │ ├─"test/test_expect_test.ml":449:8: z
      │ │ └─z = 2
      │ ├─┬────────────────────────────────────────────────────────┐
      │ │ │"test/test_expect_test.ml":448:41-450:58: loop_highlight│
      │ │ ├────────────────────────────────────────────────────────┘
      │ │ ├─x = 5
      │ │ ├─"test/test_expect_test.ml":449:8: z
      │ │ │ └─z = 2
      │ │ ├─┬────────────────────────────────────────────────────────┐
      │ │ │ │"test/test_expect_test.ml":448:41-450:58: loop_highlight│
      │ │ │ ├────────────────────────────────────────────────────────┘
      │ │ │ ├─x = 4
      │ │ │ ├─"test/test_expect_test.ml":449:8: z
      │ │ │ │ └─z = 1
      │ │ │ ├─┬────────────────────────────────────────────────────────┐
      │ │ │ │ │"test/test_expect_test.ml":448:41-450:58: loop_highlight│
      │ │ │ │ ├────────────────────────────────────────────────────────┘
      │ │ │ │ ├─┬─────┐
      │ │ │ │ │ │x = 3│
      │ │ │ │ │ └─────┘
      │ │ │ │ ├─"test/test_expect_test.ml":449:8: z
      │ │ │ │ │ └─z = 1
      │ │ │ │ ├─"test/test_expect_test.ml":448:41-450:58: loop_highlight
      │ │ │ │ │ ├─x = 2
      │ │ │ │ │ ├─"test/test_expect_test.ml":449:8: z
      │ │ │ │ │ │ └─z = 0
      │ │ │ │ │ ├─"test/test_expect_test.ml":448:41-450:58: loop_highlight
      │ │ │ │ │ │ ├─x = 1
      │ │ │ │ │ │ ├─"test/test_expect_test.ml":449:8: z
      │ │ │ │ │ │ │ └─z = 0
      │ │ │ │ │ │ ├─"test/test_expect_test.ml":448:41-450:58: loop_highlight
      │ │ │ │ │ │ │ ├─x = 0
      │ │ │ │ │ │ │ ├─"test/test_expect_test.ml":449:8: z
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
      "test/test_expect_test.ml":516:37-518:46: track_branches
      ├─x = 7
      ├─"test/test_expect_test.ml":518:9: <if -- else branch>
      │ └─"test/test_expect_test.ml":518:36-518:37: <match -- branch 1>
      └─track_branches = 4
      4
      "test/test_expect_test.ml":516:37-518:46: track_branches
      ├─x = 3
      ├─"test/test_expect_test.ml":517:18: <if -- then branch>
      │ └─"test/test_expect_test.ml":517:54-517:57: <match -- branch 2>
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
      "test/test_expect_test.ml":549:11-549:12: <function -- branch 3>
      4
      "test/test_expect_test.ml":551:11-551:14: <function -- branch 5> x
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
      "test/test_expect_test.ml":570:37-584:16: track_branches
      ├─x = 8
      ├─"test/test_expect_test.ml":579:6: <if -- else branch>
      │ └─"test/test_expect_test.ml":583:10-584:16: <match -- branch 2>
      │   └─"test/test_expect_test.ml":583:14: result
      │     ├─"test/test_expect_test.ml":583:44: <if -- then branch>
      │     └─result = 8
      └─track_branches = 8
      8
      "test/test_expect_test.ml":570:37-584:16: track_branches
      ├─x = 3
      ├─"test/test_expect_test.ml":572:6: <if -- then branch>
      │ └─"test/test_expect_test.ml":576:14: result
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
      "test/test_expect_test.ml":615:37-629:16: track_branches
      ├─x = 8
      ├─"test/test_expect_test.ml":624:6: <if -- else branch>
      │ └─"test/test_expect_test.ml":628:10-629:16: <match -- branch 2>
      │   └─"test/test_expect_test.ml":628:23: result
      │     ├─"test/test_expect_test.ml":628:53: <if -- then branch>
      │     └─result = 8
      └─track_branches = 8
      8
      "test/test_expect_test.ml":615:37-629:16: track_branches
      ├─x = 3
      ├─"test/test_expect_test.ml":617:6: <if -- then branch>
      │ └─"test/test_expect_test.ml":621:25: result
      │   └─result = 3
      └─track_branches = 3
      3
    |}]

let%expect_test "%track_show PrintBox to stdout no return type anonymous fun" =
  let module Debug_runtime = (val Minidebug_runtime.debug ~max_num_children:10 ()) in
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
      "test/test_expect_test.ml":671:32-672:70: anonymous
      ├─x = 3
      ├─"test/test_expect_test.ml":672:50-672:70: __fun
      │ └─i = 0
      ├─"test/test_expect_test.ml":672:50-672:70: __fun
      │ └─i = 1
      ├─"test/test_expect_test.ml":672:50-672:70: __fun
      │ └─i = 2
      └─"test/test_expect_test.ml":672:50-672:70: __fun
        └─i = 3
      6
    |}]

let%expect_test "%track_show PrintBox to stdout anonymous fun, num children exceeded" =
  let module Debug_runtime = (val Minidebug_runtime.debug ~max_num_children:10 ()) in
  let%track_this_show rec loop_exceeded (x : int) : int =
    Array.fold_left ( + ) 0
    @@ Array.init
         (100 / (x + 1))
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
      "test/test_expect_test.ml":695:40-701:69: loop_exceeded
      ├─x = 3
      └─"test/test_expect_test.ml":699:9-701:69: __fun
        ├─i = 0
        ├─"test/test_expect_test.ml":700:15: z
        │ └─z = 1
        └─"test/test_expect_test.ml":701:33: <if -- else branch>
          └─"test/test_expect_test.ml":695:40-701:69: loop_exceeded
            ├─x = 2
            └─"test/test_expect_test.ml":699:9-701:69: __fun
              ├─i = 0
              ├─"test/test_expect_test.ml":700:15: z
              │ └─z = 0
              └─"test/test_expect_test.ml":701:33: <if -- else branch>
                └─"test/test_expect_test.ml":695:40-701:69: loop_exceeded
                  ├─x = 1
                  └─"test/test_expect_test.ml":699:9-701:69: __fun
                    ├─i = 0
                    ├─"test/test_expect_test.ml":700:15: z
                    │ └─z = 0
                    └─"test/test_expect_test.ml":701:33: <if -- else branch>
                      └─"test/test_expect_test.ml":695:40-701:69: loop_exceeded
                        ├─x = 0
                        ├─"test/test_expect_test.ml":699:9-701:69: __fun
                        │ ├─i = 0
                        │ ├─"test/test_expect_test.ml":700:15: z
                        │ │ └─z = 0
                        │ └─"test/test_expect_test.ml":701:26: <if -- then branch>
                        ├─"test/test_expect_test.ml":699:9-701:69: __fun
                        │ ├─i = 1
                        │ ├─"test/test_expect_test.ml":700:15: z
                        │ │ └─z = 1
                        │ └─"test/test_expect_test.ml":701:26: <if -- then branch>
                        ├─"test/test_expect_test.ml":699:9-701:69: __fun
                        │ ├─i = 2
                        │ ├─"test/test_expect_test.ml":700:15: z
                        │ │ └─z = 2
                        │ └─"test/test_expect_test.ml":701:26: <if -- then branch>
                        ├─"test/test_expect_test.ml":699:9-701:69: __fun
                        │ ├─i = 3
                        │ ├─"test/test_expect_test.ml":700:15: z
                        │ │ └─z = 3
                        │ └─"test/test_expect_test.ml":701:26: <if -- then branch>
                        ├─"test/test_expect_test.ml":699:9-701:69: __fun
                        │ ├─i = 4
                        │ ├─"test/test_expect_test.ml":700:15: z
                        │ │ └─z = 4
                        │ └─"test/test_expect_test.ml":701:26: <if -- then branch>
                        ├─"test/test_expect_test.ml":699:9-701:69: __fun
                        │ ├─i = 5
                        │ ├─"test/test_expect_test.ml":700:15: z
                        │ │ └─z = 5
                        │ └─"test/test_expect_test.ml":701:26: <if -- then branch>
                        ├─"test/test_expect_test.ml":699:9-701:69: __fun
                        │ ├─i = 6
                        │ ├─"test/test_expect_test.ml":700:15: z
                        │ │ └─z = 6
                        │ └─"test/test_expect_test.ml":701:26: <if -- then branch>
                        ├─"test/test_expect_test.ml":699:9-701:69: __fun
                        │ ├─i = 7
                        │ ├─"test/test_expect_test.ml":700:15: z
                        │ │ └─z = 7
                        │ └─"test/test_expect_test.ml":701:26: <if -- then branch>
                        ├─"test/test_expect_test.ml":699:9-701:69: __fun
                        │ ├─i = 8
                        │ ├─"test/test_expect_test.ml":700:15: z
                        │ │ └─z = 8
                        │ └─"test/test_expect_test.ml":701:26: <if -- then branch>
                        ├─"test/test_expect_test.ml":699:9-701:69: __fun
                        │ ├─i = 9
                        │ ├─"test/test_expect_test.ml":700:15: z
                        │ │ └─z = 9
                        │ └─"test/test_expect_test.ml":701:26: <if -- then branch>
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
      "test/test_expect_test.ml":795:26-796:47: foo
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
  ├─"test/test_expect_test.ml":821:41-824:36
  ├─x = 7
  ├─z = 3
  │ └─"test/test_expect_test.ml":822:8
  └─loop_truncated
    ├─"test/test_expect_test.ml":821:41-824:36
    ├─x = 6
    ├─z = 2
    │ └─"test/test_expect_test.ml":822:8
    └─loop_truncated
      ├─"test/test_expect_test.ml":821:41-824:36
      ├─x = 5
      ├─z = 2
      │ └─"test/test_expect_test.ml":822:8
      └─loop_truncated
        ├─"test/test_expect_test.ml":821:41-824:36
        ├─x = 4
        ├─z = 1
        │ └─"test/test_expect_test.ml":822:8
        └─loop_truncated
          ├─"test/test_expect_test.ml":821:41-824:36
          ├─x = 3
          ├─z = 1
          │ └─"test/test_expect_test.ml":822:8
          └─loop_truncated
            ├─"test/test_expect_test.ml":821:41-824:36
            ├─x = 2
            ├─z = 0
            │ └─"test/test_expect_test.ml":822:8
            └─loop_truncated
              ├─"test/test_expect_test.ml":821:41-824:36
              ├─x = 1
              ├─z = 0
              │ └─"test/test_expect_test.ml":822:8
              └─loop_truncated
                ├─"test/test_expect_test.ml":821:41-824:36
                ├─x = 0
                └─z = 0
                  └─"test/test_expect_test.ml":822:8
  Raised exception. |}]

let%expect_test "%debug_show PrintBox values_first_mode to stdout num children exceeded \
                 linear" =
  let module Debug_runtime =
    (val Minidebug_runtime.debug ~max_num_children:10 ~values_first_mode:true ())
  in
  let () =
    try
      let%debug_this_show _bar : unit =
        for i = 0 to 100 do
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
    _bar
    ├─"test/test_expect_test.ml":882:26
    ├─_baz = 0
    │ └─"test/test_expect_test.ml":884:14
    ├─_baz = 2
    │ └─"test/test_expect_test.ml":884:14
    ├─_baz = 4
    │ └─"test/test_expect_test.ml":884:14
    ├─_baz = 6
    │ └─"test/test_expect_test.ml":884:14
    ├─_baz = 8
    │ └─"test/test_expect_test.ml":884:14
    ├─_baz = 10
    │ └─"test/test_expect_test.ml":884:14
    ├─_baz = 12
    │ └─"test/test_expect_test.ml":884:14
    ├─_baz = 14
    │ └─"test/test_expect_test.ml":884:14
    ├─_baz = 16
    │ └─"test/test_expect_test.ml":884:14
    ├─_baz = 18
    │ └─"test/test_expect_test.ml":884:14
    ├─_baz = 20
    │ └─"test/test_expect_test.ml":884:14
    └─_baz = <max_num_children exceeded>
    Raised exception: ppx_minidebug: max_num_children exceeded |}]

let%expect_test "%debug_show PrintBox values_first_mode to stdout track for-loop" =
  let module Debug_runtime = (val Minidebug_runtime.debug ~values_first_mode:true ()) in
  let () =
    try
      let%track_this_show _bar : unit =
        for i = 0 to 6 do
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
      _bar = ()
      ├─"test/test_expect_test.ml":925:26
      └─<for loop>
        ├─"test/test_expect_test.ml":926:8
        ├─i = 0
        ├─<for i>
        │ ├─"test/test_expect_test.ml":926:12
        │ └─_baz = 0
        │   └─"test/test_expect_test.ml":927:14
        ├─i = 1
        ├─<for i>
        │ ├─"test/test_expect_test.ml":926:12
        │ └─_baz = 2
        │   └─"test/test_expect_test.ml":927:14
        ├─i = 2
        ├─<for i>
        │ ├─"test/test_expect_test.ml":926:12
        │ └─_baz = 4
        │   └─"test/test_expect_test.ml":927:14
        ├─i = 3
        ├─<for i>
        │ ├─"test/test_expect_test.ml":926:12
        │ └─_baz = 6
        │   └─"test/test_expect_test.ml":927:14
        ├─i = 4
        ├─<for i>
        │ ├─"test/test_expect_test.ml":926:12
        │ └─_baz = 8
        │   └─"test/test_expect_test.ml":927:14
        ├─i = 5
        ├─<for i>
        │ ├─"test/test_expect_test.ml":926:12
        │ └─_baz = 10
        │   └─"test/test_expect_test.ml":927:14
        ├─i = 6
        └─<for i>
          ├─"test/test_expect_test.ml":926:12
          └─_baz = 12
            └─"test/test_expect_test.ml":927:14 |}]

let%expect_test "%debug_show PrintBox values_first_mode to stdout num children exceeded \
                 nested" =
  let module Debug_runtime =
    (val Minidebug_runtime.debug ~max_num_children:10 ~values_first_mode:true ())
  in
  let%debug_this_show rec loop_exceeded (x : int) : int =
    Array.fold_left ( + ) 0
    @@ Array.init
         (100 / (x + 1))
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
      loop_exceeded
      ├─"test/test_expect_test.ml":982:40-988:69
      ├─x = 3
      ├─z = 1
      │ └─"test/test_expect_test.ml":987:15
      └─loop_exceeded
        ├─"test/test_expect_test.ml":982:40-988:69
        ├─x = 2
        ├─z = 0
        │ └─"test/test_expect_test.ml":987:15
        └─loop_exceeded
          ├─"test/test_expect_test.ml":982:40-988:69
          ├─x = 1
          ├─z = 0
          │ └─"test/test_expect_test.ml":987:15
          └─loop_exceeded
            ├─"test/test_expect_test.ml":982:40-988:69
            ├─x = 0
            ├─z = 0
            │ └─"test/test_expect_test.ml":987:15
            ├─z = 1
            │ └─"test/test_expect_test.ml":987:15
            ├─z = 2
            │ └─"test/test_expect_test.ml":987:15
            ├─z = 3
            │ └─"test/test_expect_test.ml":987:15
            ├─z = 4
            │ └─"test/test_expect_test.ml":987:15
            ├─z = 5
            │ └─"test/test_expect_test.ml":987:15
            ├─z = 6
            │ └─"test/test_expect_test.ml":987:15
            ├─z = 7
            │ └─"test/test_expect_test.ml":987:15
            ├─z = 8
            │ └─"test/test_expect_test.ml":987:15
            ├─z = 9
            │ └─"test/test_expect_test.ml":987:15
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
      ├─"test/test_expect_test.ml":1042:41-1044:58
      ├─x = 7
      ├─┬─────┐
      │ │z = 3│
      │ ├─────┘
      │ └─"test/test_expect_test.ml":1043:8
      └─┬──────────────────┐
        │loop_highlight = 6│
        ├──────────────────┘
        ├─"test/test_expect_test.ml":1042:41-1044:58
        ├─x = 6
        ├─z = 2
        │ └─"test/test_expect_test.ml":1043:8
        └─┬──────────────────┐
          │loop_highlight = 4│
          ├──────────────────┘
          ├─"test/test_expect_test.ml":1042:41-1044:58
          ├─x = 5
          ├─z = 2
          │ └─"test/test_expect_test.ml":1043:8
          └─┬──────────────────┐
            │loop_highlight = 2│
            ├──────────────────┘
            ├─"test/test_expect_test.ml":1042:41-1044:58
            ├─x = 4
            ├─z = 1
            │ └─"test/test_expect_test.ml":1043:8
            └─┬──────────────────┐
              │loop_highlight = 1│
              ├──────────────────┘
              ├─"test/test_expect_test.ml":1042:41-1044:58
              ├─┬─────┐
              │ │x = 3│
              │ └─────┘
              ├─z = 1
              │ └─"test/test_expect_test.ml":1043:8
              └─loop_highlight = 0
                ├─"test/test_expect_test.ml":1042:41-1044:58
                ├─x = 2
                ├─z = 0
                │ └─"test/test_expect_test.ml":1043:8
                └─loop_highlight = 0
                  ├─"test/test_expect_test.ml":1042:41-1044:58
                  ├─x = 1
                  ├─z = 0
                  │ └─"test/test_expect_test.ml":1043:8
                  └─loop_highlight = 0
                    ├─"test/test_expect_test.ml":1042:41-1044:58
                    ├─x = 0
                    └─z = 0
                      └─"test/test_expect_test.ml":1043:8
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
      ├─"test/test_expect_test.ml":1108:37-1110:46
      ├─x = 7
      └─<if -- else branch>
        ├─"test/test_expect_test.ml":1110:9
        └─<match -- branch 1>
          └─"test/test_expect_test.ml":1110:36-1110:37
      4
      track_branches = -3
      ├─"test/test_expect_test.ml":1108:37-1110:46
      ├─x = 3
      └─<if -- then branch>
        ├─"test/test_expect_test.ml":1109:18
        └─<match -- branch 2>
          └─"test/test_expect_test.ml":1109:54-1109:57
      -3
    |}]

let%expect_test "%track_show PrintBox values_first_mode to stdout no return type \
                 anonymous fun" =
  let module Debug_runtime =
    (val Minidebug_runtime.debug ~max_num_children:10 ~values_first_mode:true ())
  in
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
      ├─"test/test_expect_test.ml":1144:32-1145:70
      ├─x = 3
      ├─i = 0
      │ └─"test/test_expect_test.ml":1145:50-1145:70
      ├─i = 1
      │ └─"test/test_expect_test.ml":1145:50-1145:70
      ├─i = 2
      │ └─"test/test_expect_test.ml":1145:50-1145:70
      └─i = 3
        └─"test/test_expect_test.ml":1145:50-1145:70
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
    "test/test_expect_test.ml":1170:21-1173:15: bar
    ├─first = 7
    ├─second = 42
    ├─"test/test_expect_test.ml":1171:8: {first=a; second=b}
    │ ├─a = 7
    │ └─b = 45
    ├─"test/test_expect_test.ml":1172:8: y
    │ └─y = 8
    └─bar = 336
    336
    "test/test_expect_test.ml":1176:10-1178:28: baz
    ├─first = 7
    ├─second = 42
    ├─"test/test_expect_test.ml":1177:8: {first; second}
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
    "test/test_expect_test.ml":1205:21-1207:14: bar
    ├─first = 7
    ├─second = 42
    ├─"test/test_expect_test.ml":1206:8: y
    │ └─y = 8
    └─bar = 336
    336
    "test/test_expect_test.ml":1215:6: (r1, r2)
    ├─"test/test_expect_test.ml":1210:10-1213:35: baz
    │ ├─first = 7
    │ ├─second = 42
    │ ├─"test/test_expect_test.ml":1211:8: (y, z)
    │ │ ├─y = 8
    │ │ └─z = 3
    │ ├─"test/test_expect_test.ml":1212:8: (a, b)
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
      ├─"test/test_expect_test.ml":1246:21-1249:15
      ├─first = 7
      ├─second = 42
      ├─{first=a; second=b}
      │ ├─"test/test_expect_test.ml":1247:8
      │ └─<values>
      │   ├─a = 7
      │   └─b = 45
      └─y = 8
        └─"test/test_expect_test.ml":1248:8
      336
      baz = 109
      ├─"test/test_expect_test.ml":1252:10-1254:28
      ├─first = 7
      ├─second = 42
      └─{first; second}
        ├─"test/test_expect_test.ml":1253:8
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
    ├─"test/test_expect_test.ml":1285:21-1287:14
    ├─first = 7
    ├─second = 42
    └─y = 8
      └─"test/test_expect_test.ml":1286:8
    336
    (r1, r2)
    ├─"test/test_expect_test.ml":1295:6
    ├─<values>
    │ ├─r1 = 339
    │ └─r2 = 109
    └─baz = (339, 109)
      ├─"test/test_expect_test.ml":1290:10-1293:35
      ├─first = 7
      ├─second = 42
      ├─(y, z)
      │ ├─"test/test_expect_test.ml":1291:8
      │ └─<values>
      │   ├─y = 8
      │   └─z = 3
      └─(a, b)
        ├─"test/test_expect_test.ml":1292:8
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
      ├─"test/test_expect_test.ml":1336:21-1338:9
      ├─x = 7
      └─y = 8
        └─"test/test_expect_test.ml":1337:8
      16
      baz = 5
      ├─"test/test_expect_test.ml":1342:24-1342:29
      └─x = 4
      5
      baz = 6
      ├─"test/test_expect_test.ml":1343:31-1343:36
      └─y = 3
      6
      foo = 3
      ├─"test/test_expect_test.ml":1346:10-1347:82
      └─<match -- branch 2>
        └─"test/test_expect_test.ml":1347:81-1347:82
      3 |}]
