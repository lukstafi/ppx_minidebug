type t = {first: int; second: int} [@@deriving show]

let%expect_test "%debug_show flushing to a file" =
  let module Debug_runtime =
    Minidebug_runtime.Flushing(
      (val Minidebug_runtime.debug_ch ~time_tagged:true "../../../debugger_expect_show_flushing.log")) in
  let%debug_this_show rec loop (depth: int) (x: t): int =
    if depth > 6 then x.first + x.second
    else if depth > 3 then loop (depth + 1) {first=x.second + 1; second=x.first / 2}
    else
      let y: int = loop (depth + 1) {first=x.second - 1; second=x.first + 2} in
      let z: int = loop (depth + 1) {first=x.second + 1; second=y} in
      z + 7 in
  print_endline @@ Int.to_string @@ loop 0 {first=7; second=42};
  [%expect {| 56 |}]

let%expect_test "%debug_show flushing to stdout" =
  let module Debug_runtime = Minidebug_runtime.Flushing(struct let debug_ch = stdout let time_tagged = true end) in
  let%debug_show bar (x: t): int = let y: int = x.first + 1 in x.second * y in
  let () = print_endline @@ Int.to_string @@ bar {first=7; second=42} in
  let baz (x: t): int =
    let (y, z as _yz): int * int = x.first + 1, 3 in x.second * y + z in
  let () = print_endline @@ Int.to_string @@ baz {first=7; second=42} in
  let output = [%expect.output] in
  let output = Str.global_replace
      (Str.regexp {|[0-9]+-[0-9]+-[0-9]+ [0-9]+:[0-9]+:[0-9]+\.[0-9]+\( \+[0-9]+:[0-9]+\)?|})
      "YYYY-MM-DD HH:MM:SS.NNNNNN" output in
  print_endline output;
  [%expect {|
    BEGIN DEBUG SESSION at time YYYY-MM-DD HH:MM:SS.NNNNNN
    YYYY-MM-DD HH:MM:SS.NNNNNN - bar begin "test/test_expect_test.ml":19:21-19:75
     x = { Test_expect_test.first = 7; second = 42 }
      "test/test_expect_test.ml":19:39:
      y = 8
     bar = 336
    YYYY-MM-DD HH:MM:SS.NNNNNN - bar end
    336
    YYYY-MM-DD HH:MM:SS.NNNNNN - baz begin "test/test_expect_test.ml":21:10-22:69
     x = { Test_expect_test.first = 7; second = 42 }
      "test/test_expect_test.ml":22:17:
      _yz = (8, 3)
     baz = 339
    YYYY-MM-DD HH:MM:SS.NNNNNN - baz end
    339 |}]

let%expect_test "%debug_show PrintBox to stdout disabled subtree" =
  let module Debug_runtime = (val Minidebug_runtime.debug ()) in
  let%debug_this_show rec loop_complete (x: int): int =
    let z: int = (x - 1) / 2 in
    if x <= 0 then 0 else z + loop_complete (z + x / 2) in
  let () = print_endline @@ Int.to_string @@ loop_complete 7 in
  [%expect {|
    BEGIN DEBUG SESSION
    "test/test_expect_test.ml":48:40-50:55: loop_complete
    ├─x = 7
    ├─"test/test_expect_test.ml":49:8:
    │ └─z = 3
    ├─"test/test_expect_test.ml":48:40-50:55: loop_complete
    │ ├─x = 6
    │ ├─"test/test_expect_test.ml":49:8:
    │ │ └─z = 2
    │ ├─"test/test_expect_test.ml":48:40-50:55: loop_complete
    │ │ ├─x = 5
    │ │ ├─"test/test_expect_test.ml":49:8:
    │ │ │ └─z = 2
    │ │ ├─"test/test_expect_test.ml":48:40-50:55: loop_complete
    │ │ │ ├─x = 4
    │ │ │ ├─"test/test_expect_test.ml":49:8:
    │ │ │ │ └─z = 1
    │ │ │ ├─"test/test_expect_test.ml":48:40-50:55: loop_complete
    │ │ │ │ ├─x = 3
    │ │ │ │ ├─"test/test_expect_test.ml":49:8:
    │ │ │ │ │ └─z = 1
    │ │ │ │ ├─"test/test_expect_test.ml":48:40-50:55: loop_complete
    │ │ │ │ │ ├─x = 2
    │ │ │ │ │ ├─"test/test_expect_test.ml":49:8:
    │ │ │ │ │ │ └─z = 0
    │ │ │ │ │ ├─"test/test_expect_test.ml":48:40-50:55: loop_complete
    │ │ │ │ │ │ ├─x = 1
    │ │ │ │ │ │ ├─"test/test_expect_test.ml":49:8:
    │ │ │ │ │ │ │ └─z = 0
    │ │ │ │ │ │ ├─"test/test_expect_test.ml":48:40-50:55: loop_complete
    │ │ │ │ │ │ │ ├─x = 0
    │ │ │ │ │ │ │ ├─"test/test_expect_test.ml":49:8:
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
  let%debug_this_show rec loop_changes (x: int): int =
    let z: int = (x - 1) / 2 in
    (* The call [x = 2] is not printed because it is a descendant of the no-debug call [x = 4]. *)
    Debug_runtime.no_debug_if (x <> 6 && x <> 2 && (z + 1) * 2 = x);
    if x <= 0 then 0 else z + loop_changes (z + x / 2) in
let () = print_endline @@ Int.to_string @@ loop_changes 7 in
[%expect {|
  "test/test_expect_test.ml":95:39-99:54: loop_changes
  ├─x = 7
  ├─"test/test_expect_test.ml":96:8:
  │ └─z = 3
  ├─"test/test_expect_test.ml":95:39-99:54: loop_changes
  │ ├─x = 6
  │ ├─"test/test_expect_test.ml":96:8:
  │ │ └─z = 2
  │ ├─"test/test_expect_test.ml":95:39-99:54: loop_changes
  │ │ ├─x = 5
  │ │ ├─"test/test_expect_test.ml":96:8:
  │ │ │ └─z = 2
  │ │ └─loop_changes = 4
  │ └─loop_changes = 6
  └─loop_changes = 9
  9 |}] 


let%expect_test "%debug_show PrintBox to stdout with exception" =
  let module Debug_runtime = (val Minidebug_runtime.debug ()) in
  let%debug_this_show rec loop_truncated (x: int): int =
    let z: int = (x - 1) / 2 in
    if x <= 0 then failwith "the log as for loop_complete but without return values";
    z + loop_truncated (z + x / 2) in
  let () =
    try print_endline @@ Int.to_string @@ loop_truncated 7
    with _ -> print_endline "Raised exception." in
  [%expect {|
    BEGIN DEBUG SESSION
    "test/test_expect_test.ml":122:41-125:34: loop_truncated
    ├─x = 7
    ├─"test/test_expect_test.ml":123:8:
    │ └─z = 3
    └─"test/test_expect_test.ml":122:41-125:34: loop_truncated
      ├─x = 6
      ├─"test/test_expect_test.ml":123:8:
      │ └─z = 2
      └─"test/test_expect_test.ml":122:41-125:34: loop_truncated
        ├─x = 5
        ├─"test/test_expect_test.ml":123:8:
        │ └─z = 2
        └─"test/test_expect_test.ml":122:41-125:34: loop_truncated
          ├─x = 4
          ├─"test/test_expect_test.ml":123:8:
          │ └─z = 1
          └─"test/test_expect_test.ml":122:41-125:34: loop_truncated
            ├─x = 3
            ├─"test/test_expect_test.ml":123:8:
            │ └─z = 1
            └─"test/test_expect_test.ml":122:41-125:34: loop_truncated
              ├─x = 2
              ├─"test/test_expect_test.ml":123:8:
              │ └─z = 0
              └─"test/test_expect_test.ml":122:41-125:34: loop_truncated
                ├─x = 1
                ├─"test/test_expect_test.ml":123:8:
                │ └─z = 0
                └─"test/test_expect_test.ml":122:41-125:34: loop_truncated
                  ├─x = 0
                  └─"test/test_expect_test.ml":123:8:
                    └─z = 0
    Raised exception. |}]
