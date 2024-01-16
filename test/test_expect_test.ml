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
      "test/test_expect_test.ml":23:8:
      y = 8
     bar = 336
    YYYY-MM-DD HH:MM:SS.NNNNNN - bar end
    336
    YYYY-MM-DD HH:MM:SS.NNNNNN - baz begin "test/test_expect_test.ml":27:10-29:22
     x = { Test_expect_test.first = 7; second = 42 }
      "test/test_expect_test.ml":28:19:
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
    ├─"test/test_expect_test.ml":61:8:
    │ └─z = 3
    ├─"test/test_expect_test.ml":60:40-62:57: loop_complete
    │ ├─x = 6
    │ ├─"test/test_expect_test.ml":61:8:
    │ │ └─z = 2
    │ ├─"test/test_expect_test.ml":60:40-62:57: loop_complete
    │ │ ├─x = 5
    │ │ ├─"test/test_expect_test.ml":61:8:
    │ │ │ └─z = 2
    │ │ ├─"test/test_expect_test.ml":60:40-62:57: loop_complete
    │ │ │ ├─x = 4
    │ │ │ ├─"test/test_expect_test.ml":61:8:
    │ │ │ │ └─z = 1
    │ │ │ ├─"test/test_expect_test.ml":60:40-62:57: loop_complete
    │ │ │ │ ├─x = 3
    │ │ │ │ ├─"test/test_expect_test.ml":61:8:
    │ │ │ │ │ └─z = 1
    │ │ │ │ ├─"test/test_expect_test.ml":60:40-62:57: loop_complete
    │ │ │ │ │ ├─x = 2
    │ │ │ │ │ ├─"test/test_expect_test.ml":61:8:
    │ │ │ │ │ │ └─z = 0
    │ │ │ │ │ ├─"test/test_expect_test.ml":60:40-62:57: loop_complete
    │ │ │ │ │ │ ├─x = 1
    │ │ │ │ │ │ ├─"test/test_expect_test.ml":61:8:
    │ │ │ │ │ │ │ └─z = 0
    │ │ │ │ │ │ ├─"test/test_expect_test.ml":60:40-62:57: loop_complete
    │ │ │ │ │ │ │ ├─x = 0
    │ │ │ │ │ │ │ ├─"test/test_expect_test.ml":61:8:
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
  ├─"test/test_expect_test.ml":110:8:
  │ └─z = 3
  ├─"test/test_expect_test.ml":109:39-113:56: loop_changes
  │ ├─x = 6
  │ ├─"test/test_expect_test.ml":110:8:
  │ │ └─z = 2
  │ ├─"test/test_expect_test.ml":109:39-113:56: loop_changes
  │ │ ├─x = 5
  │ │ ├─"test/test_expect_test.ml":110:8:
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
    ├─"test/test_expect_test.ml":138:8:
    │ └─z = 3
    └─"test/test_expect_test.ml":137:41-140:36: loop_truncated
      ├─x = 6
      ├─"test/test_expect_test.ml":138:8:
      │ └─z = 2
      └─"test/test_expect_test.ml":137:41-140:36: loop_truncated
        ├─x = 5
        ├─"test/test_expect_test.ml":138:8:
        │ └─z = 2
        └─"test/test_expect_test.ml":137:41-140:36: loop_truncated
          ├─x = 4
          ├─"test/test_expect_test.ml":138:8:
          │ └─z = 1
          └─"test/test_expect_test.ml":137:41-140:36: loop_truncated
            ├─x = 3
            ├─"test/test_expect_test.ml":138:8:
            │ └─z = 1
            └─"test/test_expect_test.ml":137:41-140:36: loop_truncated
              ├─x = 2
              ├─"test/test_expect_test.ml":138:8:
              │ └─z = 0
              └─"test/test_expect_test.ml":137:41-140:36: loop_truncated
                ├─x = 1
                ├─"test/test_expect_test.ml":138:8:
                │ └─z = 0
                └─"test/test_expect_test.ml":137:41-140:36: loop_truncated
                  ├─x = 0
                  └─"test/test_expect_test.ml":138:8:
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
      ├─"test/test_expect_test.ml":186:8:
      │ └─z = 3
      └─"test/test_expect_test.ml":185:40-187:57: loop_exceeded
        ├─x = 6
        ├─"test/test_expect_test.ml":186:8:
        │ └─z = 2
        └─"test/test_expect_test.ml":185:40-187:57: loop_exceeded
          ├─x = 5
          ├─"test/test_expect_test.ml":186:8:
          │ └─z = 2
          └─"test/test_expect_test.ml":185:40-187:57: loop_exceeded
            ├─x = 4
            ├─"test/test_expect_test.ml":186:8:
            │ └─z = 1
            └─"test/test_expect_test.ml":185:40-187:57: loop_exceeded
              ├─x = 3
              └─"test/test_expect_test.ml":186:8:
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
    "test/test_expect_test.ml":222:26:
    ├─"test/test_expect_test.ml":224:14:
    │ └─_baz = 0
    ├─"test/test_expect_test.ml":224:14:
    │ └─_baz = 2
    ├─"test/test_expect_test.ml":224:14:
    │ └─_baz = 4
    ├─"test/test_expect_test.ml":224:14:
    │ └─_baz = 6
    ├─"test/test_expect_test.ml":224:14:
    │ └─_baz = 8
    ├─"test/test_expect_test.ml":224:14:
    │ └─_baz = 10
    ├─"test/test_expect_test.ml":224:14:
    │ └─_baz = 12
    ├─"test/test_expect_test.ml":224:14:
    │ └─_baz = 14
    ├─"test/test_expect_test.ml":224:14:
    │ └─_baz = 16
    ├─"test/test_expect_test.ml":224:14:
    │ └─_baz = 18
    ├─"test/test_expect_test.ml":224:14:
    │ └─_baz = 20
    └─_baz = <max_num_children exceeded>
    Raised exception: ppx_minidebug: max_num_children exceeded |}]

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
      "test/test_expect_test.ml":262:40-268:69: loop_exceeded
      ├─x = 3
      ├─"test/test_expect_test.ml":267:15:
      │ └─z = 1
      └─"test/test_expect_test.ml":262:40-268:69: loop_exceeded
        ├─x = 2
        ├─"test/test_expect_test.ml":267:15:
        │ └─z = 0
        └─"test/test_expect_test.ml":262:40-268:69: loop_exceeded
          ├─x = 1
          ├─"test/test_expect_test.ml":267:15:
          │ └─z = 0
          └─"test/test_expect_test.ml":262:40-268:69: loop_exceeded
            ├─x = 0
            ├─"test/test_expect_test.ml":267:15:
            │ └─z = 0
            ├─"test/test_expect_test.ml":267:15:
            │ └─z = 1
            ├─"test/test_expect_test.ml":267:15:
            │ └─z = 2
            ├─"test/test_expect_test.ml":267:15:
            │ └─z = 3
            ├─"test/test_expect_test.ml":267:15:
            │ └─z = 4
            ├─"test/test_expect_test.ml":267:15:
            │ └─z = 5
            ├─"test/test_expect_test.ml":267:15:
            │ └─z = 6
            ├─"test/test_expect_test.ml":267:15:
            │ └─z = 7
            ├─"test/test_expect_test.ml":267:15:
            │ └─z = 8
            ├─"test/test_expect_test.ml":267:15:
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
      │"test/test_expect_test.ml":318:41-320:58: loop_highlight│
      ├────────────────────────────────────────────────────────┘
      ├─x = 7
      ├─┬──────────────────────────────────┐
      │ │"test/test_expect_test.ml":319:8: │
      │ ├──────────────────────────────────┘
      │ └─┬─────┐
      │   │z = 3│
      │   └─────┘
      ├─┬────────────────────────────────────────────────────────┐
      │ │"test/test_expect_test.ml":318:41-320:58: loop_highlight│
      │ ├────────────────────────────────────────────────────────┘
      │ ├─x = 6
      │ ├─"test/test_expect_test.ml":319:8:
      │ │ └─z = 2
      │ ├─┬────────────────────────────────────────────────────────┐
      │ │ │"test/test_expect_test.ml":318:41-320:58: loop_highlight│
      │ │ ├────────────────────────────────────────────────────────┘
      │ │ ├─x = 5
      │ │ ├─"test/test_expect_test.ml":319:8:
      │ │ │ └─z = 2
      │ │ ├─┬────────────────────────────────────────────────────────┐
      │ │ │ │"test/test_expect_test.ml":318:41-320:58: loop_highlight│
      │ │ │ ├────────────────────────────────────────────────────────┘
      │ │ │ ├─x = 4
      │ │ │ ├─"test/test_expect_test.ml":319:8:
      │ │ │ │ └─z = 1
      │ │ │ ├─┬────────────────────────────────────────────────────────┐
      │ │ │ │ │"test/test_expect_test.ml":318:41-320:58: loop_highlight│
      │ │ │ │ ├────────────────────────────────────────────────────────┘
      │ │ │ │ ├─┬─────┐
      │ │ │ │ │ │x = 3│
      │ │ │ │ │ └─────┘
      │ │ │ │ ├─"test/test_expect_test.ml":319:8:
      │ │ │ │ │ └─z = 1
      │ │ │ │ ├─"test/test_expect_test.ml":318:41-320:58: loop_highlight
      │ │ │ │ │ ├─x = 2
      │ │ │ │ │ ├─"test/test_expect_test.ml":319:8:
      │ │ │ │ │ │ └─z = 0
      │ │ │ │ │ ├─"test/test_expect_test.ml":318:41-320:58: loop_highlight
      │ │ │ │ │ │ ├─x = 1
      │ │ │ │ │ │ ├─"test/test_expect_test.ml":319:8:
      │ │ │ │ │ │ │ └─z = 0
      │ │ │ │ │ │ ├─"test/test_expect_test.ml":318:41-320:58: loop_highlight
      │ │ │ │ │ │ │ ├─x = 0
      │ │ │ │ │ │ │ ├─"test/test_expect_test.ml":319:8:
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
      "test/test_expect_test.ml":386:37-388:46: track_branches
      ├─x = 7
      ├─"test/test_expect_test.ml":388:9: <if -- else branch>
      │ └─"test/test_expect_test.ml":388:31: <match -- branch 1>
      └─track_branches = 4
      4
      "test/test_expect_test.ml":386:37-388:46: track_branches
      ├─x = 3
      ├─"test/test_expect_test.ml":387:18: <if -- then branch>
      │ └─"test/test_expect_test.ml":387:49: <match -- branch 2>
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
      "test/test_expect_test.ml":419:6: <function -- branch 3>
      4
      "test/test_expect_test.ml":421:6: <function -- branch 5>
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
      "test/test_expect_test.ml":448:37-462:16: track_branches
      ├─x = 8
      ├─"test/test_expect_test.ml":457:6: <if -- else branch>
      │ └─"test/test_expect_test.ml":460:8: <match -- branch 2>
      │   └─"test/test_expect_test.ml":461:14:
      │     ├─"test/test_expect_test.ml":461:44: <if -- then branch>
      │     └─result = 8
      └─track_branches = 8
      8
      "test/test_expect_test.ml":448:37-462:16: track_branches
      ├─x = 3
      ├─"test/test_expect_test.ml":450:6: <if -- then branch>
      │ └─"test/test_expect_test.ml":454:14:
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
      "test/test_expect_test.ml":493:37-507:16: track_branches
      ├─x = 8
      ├─"test/test_expect_test.ml":502:6: <if -- else branch>
      │ └─"test/test_expect_test.ml":505:8: <match -- branch 2>
      │   └─"test/test_expect_test.ml":506:23:
      │     ├─"test/test_expect_test.ml":506:53: <if -- then branch>
      │     └─result = 8
      └─track_branches = 8
      8
      "test/test_expect_test.ml":493:37-507:16: track_branches
      ├─x = 3
      ├─"test/test_expect_test.ml":495:6: <if -- then branch>
      │ └─"test/test_expect_test.ml":499:25:
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
      "test/test_expect_test.ml":549:32-550:70: anonymous
      ├─x = 3
      ├─"test/test_expect_test.ml":550:50-550:70: __fun
      │ └─i = 0
      ├─"test/test_expect_test.ml":550:50-550:70: __fun
      │ └─i = 1
      ├─"test/test_expect_test.ml":550:50-550:70: __fun
      │ └─i = 2
      └─"test/test_expect_test.ml":550:50-550:70: __fun
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
      "test/test_expect_test.ml":573:40-579:69: loop_exceeded
      ├─x = 3
      └─"test/test_expect_test.ml":577:9-579:69: __fun
        ├─i = 0
        ├─"test/test_expect_test.ml":578:15:
        │ └─z = 1
        └─"test/test_expect_test.ml":579:33: <if -- else branch>
          └─"test/test_expect_test.ml":573:40-579:69: loop_exceeded
            ├─x = 2
            └─"test/test_expect_test.ml":577:9-579:69: __fun
              ├─i = 0
              ├─"test/test_expect_test.ml":578:15:
              │ └─z = 0
              └─"test/test_expect_test.ml":579:33: <if -- else branch>
                └─"test/test_expect_test.ml":573:40-579:69: loop_exceeded
                  ├─x = 1
                  └─"test/test_expect_test.ml":577:9-579:69: __fun
                    ├─i = 0
                    ├─"test/test_expect_test.ml":578:15:
                    │ └─z = 0
                    └─"test/test_expect_test.ml":579:33: <if -- else branch>
                      └─"test/test_expect_test.ml":573:40-579:69: loop_exceeded
                        ├─x = 0
                        ├─"test/test_expect_test.ml":577:9-579:69: __fun
                        │ ├─i = 0
                        │ ├─"test/test_expect_test.ml":578:15:
                        │ │ └─z = 0
                        │ └─"test/test_expect_test.ml":579:26: <if -- then branch>
                        ├─"test/test_expect_test.ml":577:9-579:69: __fun
                        │ ├─i = 1
                        │ ├─"test/test_expect_test.ml":578:15:
                        │ │ └─z = 1
                        │ └─"test/test_expect_test.ml":579:26: <if -- then branch>
                        ├─"test/test_expect_test.ml":577:9-579:69: __fun
                        │ ├─i = 2
                        │ ├─"test/test_expect_test.ml":578:15:
                        │ │ └─z = 2
                        │ └─"test/test_expect_test.ml":579:26: <if -- then branch>
                        ├─"test/test_expect_test.ml":577:9-579:69: __fun
                        │ ├─i = 3
                        │ ├─"test/test_expect_test.ml":578:15:
                        │ │ └─z = 3
                        │ └─"test/test_expect_test.ml":579:26: <if -- then branch>
                        ├─"test/test_expect_test.ml":577:9-579:69: __fun
                        │ ├─i = 4
                        │ ├─"test/test_expect_test.ml":578:15:
                        │ │ └─z = 4
                        │ └─"test/test_expect_test.ml":579:26: <if -- then branch>
                        ├─"test/test_expect_test.ml":577:9-579:69: __fun
                        │ ├─i = 5
                        │ ├─"test/test_expect_test.ml":578:15:
                        │ │ └─z = 5
                        │ └─"test/test_expect_test.ml":579:26: <if -- then branch>
                        ├─"test/test_expect_test.ml":577:9-579:69: __fun
                        │ ├─i = 6
                        │ ├─"test/test_expect_test.ml":578:15:
                        │ │ └─z = 6
                        │ └─"test/test_expect_test.ml":579:26: <if -- then branch>
                        ├─"test/test_expect_test.ml":577:9-579:69: __fun
                        │ ├─i = 7
                        │ ├─"test/test_expect_test.ml":578:15:
                        │ │ └─z = 7
                        │ └─"test/test_expect_test.ml":579:26: <if -- then branch>
                        ├─"test/test_expect_test.ml":577:9-579:69: __fun
                        │ ├─i = 8
                        │ ├─"test/test_expect_test.ml":578:15:
                        │ │ └─z = 8
                        │ └─"test/test_expect_test.ml":579:26: <if -- then branch>
                        ├─"test/test_expect_test.ml":577:9-579:69: __fun
                        │ ├─i = 9
                        │ ├─"test/test_expect_test.ml":578:15:
                        │ │ └─z = 9
                        │ └─"test/test_expect_test.ml":579:26: <if -- then branch>
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
      "test/test_expect_test.ml":673:26-674:47: foo
      ├─c = 1
      └─foo = 2
      2
    |}]
