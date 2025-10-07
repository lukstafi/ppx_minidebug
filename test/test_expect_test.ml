open! Sexplib0.Sexp_conv

type t = { first : int; second : int } [@@deriving show]

(* Shared DB for all tests - each test creates a new run *)
let db_file = "test_expect_test.db"
let run_counter = ref 0

let next_run () =
  incr run_counter;
  !run_counter

let%expect_test "%debug_show, `as` alias and show_times" =
  let run_id = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file in
    fun () -> rt
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
  let db = Minidebug_client.Client.open_db db_file in
  Minidebug_client.Client.show_trace db ~show_times:true ~values_first_mode:false run_id;
  let output = [%expect.output] in
  let output =
    Str.global_replace (Str.regexp {|<[0-9.]+\(μs\|ms\|s\)>|}) "<TIME>" output
  in
  print_endline output;
  [%expect
    {|
    336
    339
    [debug] bar @ test/test_expect_test.ml:19:21-21:16 <TIME>
      x = { Test_expect_test.first = 7; second = 42 }
      [debug] y @ test/test_expect_test.ml:20:8-20:9 <TIME>
        y => 8
      bar => 336
    [debug] baz @ test/test_expect_test.ml:24:21-26:22 <TIME>
      x = { Test_expect_test.first = 7; second = 42 }
      [debug] _yz @ test/test_expect_test.ml:25:19-25:22 <TIME>
        _yz => (8, 3)
      baz => 339
    |}]

let%expect_test "%debug_show with run name" =
  let run_id = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file ~run_name:"test-51" db_file in
    fun () -> rt
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
  let db = Minidebug_client.Client.open_db db_file in
  Minidebug_client.Client.show_trace db ~values_first_mode:false run_id;
  let runs = Minidebug_client.Client.list_runs db in
  let run = List.find (fun r -> r.Minidebug_client.Query.run_id = run_id) runs in
  Printf.printf "\nRun #%d has name: %s\n" run.run_id
    (match run.run_name with Some n -> n | None -> "(none)");
  [%expect
    {|
    336
    339
    [debug] bar @ test/test_expect_test.ml:58:21-60:16
      x = { Test_expect_test.first = 7; second = 42 }
      [debug] y @ test/test_expect_test.ml:59:8-59:9
        y => 8
      bar => 336
    [debug] baz @ test/test_expect_test.ml:63:21-65:22
      x = { Test_expect_test.first = 7; second = 42 }
      [debug] _yz @ test/test_expect_test.ml:64:19-64:22
        _yz => (8, 3)
      baz => 339

    Run #2 has name: test-51
    |}]

let%expect_test "%debug_show disabled subtree" =
  let run_id1 = next_run () in
  let rt1 = Minidebug_db.debug_db_file db_file in
  let _get_local_debug_runtime = fun () -> rt1 in
  let%debug_show rec loop_complete (x : int) : int =
    let z : int = (x - 1) / 2 in
    if x <= 0 then 0 else z + loop_complete (z + (x / 2))
  in
  let () = print_endline @@ Int.to_string @@ loop_complete 7 in
  let db = Minidebug_client.Client.open_db db_file in
  Minidebug_client.Client.show_trace db ~values_first_mode:false run_id1;
  [%expect
    {|
    9
    [debug] loop_complete @ test/test_expect_test.ml:96:35-98:57
      x = 7
      [debug] z @ test/test_expect_test.ml:97:8-97:9
        z => 3
      [debug] loop_complete @ test/test_expect_test.ml:96:35-98:57
        x = 6
        [debug] z @ test/test_expect_test.ml:97:8-97:9
          z => 2
        [debug] loop_complete @ test/test_expect_test.ml:96:35-98:57
          x = 5
          [debug] z @ test/test_expect_test.ml:97:8-97:9
            z => 2
          [debug] loop_complete @ test/test_expect_test.ml:96:35-98:57
            x = 4
            [debug] z @ test/test_expect_test.ml:97:8-97:9
              z => 1
            [debug] loop_complete @ test/test_expect_test.ml:96:35-98:57
              x = 3
              [debug] z @ test/test_expect_test.ml:97:8-97:9
                z => 1
              [debug] loop_complete @ test/test_expect_test.ml:96:35-98:57
                x = 2
                [debug] z @ test/test_expect_test.ml:97:8-97:9
                  z => 0
                [debug] loop_complete @ test/test_expect_test.ml:96:35-98:57
                  x = 1
                  [debug] z @ test/test_expect_test.ml:97:8-97:9
                    z => 0
                  [debug] loop_complete @ test/test_expect_test.ml:96:35-98:57
                    x = 0
                    [debug] z @ test/test_expect_test.ml:97:8-97:9
                      z => 0
                    loop_complete => 0
                  loop_complete => 0
                loop_complete => 0
              loop_complete => 1
            loop_complete => 2
          loop_complete => 4
        loop_complete => 6
      loop_complete => 9
    |}];

  let run_id2 = next_run () in
  let rt2 = Minidebug_db.debug_db_file db_file in
  let _get_local_debug_runtime = fun () -> rt2 in
  (* $MDX part-begin=loop_changes *)
  let%debug_show rec loop_changes (x : int) : int =
    let z : int = (x - 1) / 2 in
    (* The call [x = 2] is not printed because it is a descendant of the no-debug call [x
       = 4]. The whole subtree is not printed. *)
    let res = if x <= 0 then 0 else z + loop_changes (z + (x / 2)) in
    Debug_runtime.no_debug_if (x <> 6 && x <> 2 && (z + 1) * 2 = x);
    res
  in
  let () = print_endline @@ Int.to_string @@ loop_changes 7 in
  let db = Minidebug_client.Client.open_db db_file in
  Minidebug_client.Client.show_trace db ~values_first_mode:false run_id2;
  [%expect
    {|
    9
    [debug] loop_changes @ test/test_expect_test.ml:152:34-158:7
      x = 7
      [debug] z @ test/test_expect_test.ml:153:8-153:9
        z => 3
      [debug] loop_changes @ test/test_expect_test.ml:152:34-158:7
        x = 6
        [debug] z @ test/test_expect_test.ml:153:8-153:9
          z => 2
        [debug] loop_changes @ test/test_expect_test.ml:152:34-158:7
          x = 5
          [debug] z @ test/test_expect_test.ml:153:8-153:9
            z => 2
          loop_changes => 4
        loop_changes => 6
      loop_changes => 9
    |}]
(* $MDX part-end *)

let%expect_test "%debug_show with exception" =
  let run_id = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file in
    fun () -> rt
  in
  let%debug_show rec loop_truncated (x : int) : int =
    let z : int = (x - 1) / 2 in
    if x <= 0 then failwith "the log as for loop_complete but without return values";
    z + loop_truncated (z + (x / 2))
  in
  let () =
    try print_endline @@ Int.to_string @@ loop_truncated 7
    with _ -> print_endline "Raised exception."
  in
  let db = Minidebug_client.Client.open_db db_file in
  Minidebug_client.Client.show_trace db ~values_first_mode:false ~show_times:true run_id;
  let output = [%expect.output] in
  let output =
    Str.global_replace (Str.regexp {|<[0-9.]+\(μs\|ms\|s\)>|}) "<TIME>" output
  in
  print_endline output;
  [%expect
    {|
    Raised exception.
    [debug] loop_truncated @ test/test_expect_test.ml:190:36-193:36 <TIME>
      x = 7
      [debug] z @ test/test_expect_test.ml:191:8-191:9 <TIME>
        z => 3
      [debug] loop_truncated @ test/test_expect_test.ml:190:36-193:36 <TIME>
        x = 6
        [debug] z @ test/test_expect_test.ml:191:8-191:9 <TIME>
          z => 2
        [debug] loop_truncated @ test/test_expect_test.ml:190:36-193:36 <TIME>
          x = 5
          [debug] z @ test/test_expect_test.ml:191:8-191:9 <TIME>
            z => 2
          [debug] loop_truncated @ test/test_expect_test.ml:190:36-193:36 <TIME>
            x = 4
            [debug] z @ test/test_expect_test.ml:191:8-191:9 <TIME>
              z => 1
            [debug] loop_truncated @ test/test_expect_test.ml:190:36-193:36 <TIME>
              x = 3
              [debug] z @ test/test_expect_test.ml:191:8-191:9 <TIME>
                z => 1
              [debug] loop_truncated @ test/test_expect_test.ml:190:36-193:36 <TIME>
                x = 2
                [debug] z @ test/test_expect_test.ml:191:8-191:9 <TIME>
                  z => 0
                [debug] loop_truncated @ test/test_expect_test.ml:190:36-193:36 <TIME>
                  x = 1
                  [debug] z @ test/test_expect_test.ml:191:8-191:9 <TIME>
                    z => 0
                  [debug] loop_truncated @ test/test_expect_test.ml:190:36-193:36 <TIME>
                    x = 0
                    [debug] z @ test/test_expect_test.ml:191:8-191:9 <TIME>
                      z => 0
    |}]

let%expect_test "%debug_show depth exceeded" =
  let run_id = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file in
    fun () -> rt
  in
  (* $MDX part-begin=debug_interrupts *)
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
  let db = Minidebug_client.Client.open_db db_file in
  Minidebug_client.Client.show_trace db ~values_first_mode:false run_id;
  [%expect
    {|
    Raised exception.
    [debug] loop_exceeded @ test/test_expect_test.ml:250:35-254:60
      x = 7
      [debug] z @ test/test_expect_test.ml:253:10-253:11
        z => 3
      [debug] loop_exceeded @ test/test_expect_test.ml:250:35-254:60
        x = 6
        [debug] z @ test/test_expect_test.ml:253:10-253:11
          z => 2
        [debug] loop_exceeded @ test/test_expect_test.ml:250:35-254:60
          x = 5
          [debug] z @ test/test_expect_test.ml:253:10-253:11
            z => 2
          [debug] loop_exceeded @ test/test_expect_test.ml:250:35-254:60
            x = 4
            [debug] z @ test/test_expect_test.ml:253:10-253:11
              z => 1
            [debug] loop_exceeded @ test/test_expect_test.ml:250:35-254:60
              x = 3
              [debug] z @ test/test_expect_test.ml:253:10-253:11
                z => 1
              [debug] loop_exceeded @ test/test_expect_test.ml:250:35-254:60
                x = 2
                [debug] z @ test/test_expect_test.ml:253:10-253:11
                  z = <max_nesting_depth exceeded>
    |}]
(* $MDX part-end *)

let%expect_test "%debug_show num children exceeded linear" =
  let run_id = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file in
    fun () -> rt
  in
  (* $MDX part-begin=debug_limit_children *)
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
  let db = Minidebug_client.Client.open_db db_file in
  Minidebug_client.Client.show_trace db ~values_first_mode:false run_id;
  [%expect
    {|
    Raised exception: ppx_minidebug: max_num_children exceeded
    [debug] _bar @ test/test_expect_test.ml:301:21-301:25
      [debug] _baz @ test/test_expect_test.ml:305:16-305:20
        _baz => 0
      [debug] _baz @ test/test_expect_test.ml:305:16-305:20
        _baz => 2
      [debug] _baz @ test/test_expect_test.ml:305:16-305:20
        _baz => 4
      [debug] _baz @ test/test_expect_test.ml:305:16-305:20
        _baz => 6
      [debug] _baz @ test/test_expect_test.ml:305:16-305:20
        _baz => 8
      [debug] _baz @ test/test_expect_test.ml:305:16-305:20
        _baz => 10
      [debug] _baz @ test/test_expect_test.ml:305:16-305:20
        _baz => 12
      [debug] _baz @ test/test_expect_test.ml:305:16-305:20
        _baz => 14
      [debug] _baz @ test/test_expect_test.ml:305:16-305:20
        _baz => 16
      [debug] _baz @ test/test_expect_test.ml:305:16-305:20
        _baz => 18
      [debug] _baz @ test/test_expect_test.ml:305:16-305:20
        _baz => 20
      [debug] _baz @ test/test_expect_test.ml:305:16-305:20
        _baz = <max_num_children exceeded>
    |}]
(* $MDX part-end *)

let%expect_test "%track_show track for-loop num children exceeded" =
  let run_id = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file in
    fun () -> rt
  in
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
  let db = Minidebug_client.Client.open_db db_file in
  Minidebug_client.Client.show_trace db ~values_first_mode:false run_id;
  [%expect
    {|
    Raised exception: ppx_minidebug: max_num_children exceeded
    [track] _bar @ test/test_expect_test.ml:353:21-353:25
      [track] for:test_expect_test:356 @ test/test_expect_test.ml:356:10-359:14
        [track] <for i> @ test/test_expect_test.ml:356:14-356:15
          i = 0
          [track] _baz @ test/test_expect_test.ml:357:16-357:20
            _baz => 0
        [track] <for i> @ test/test_expect_test.ml:356:14-356:15
          i = 1
          [track] _baz @ test/test_expect_test.ml:357:16-357:20
            _baz => 2
        [track] <for i> @ test/test_expect_test.ml:356:14-356:15
          i = 2
          [track] _baz @ test/test_expect_test.ml:357:16-357:20
            _baz => 4
        [track] <for i> @ test/test_expect_test.ml:356:14-356:15
          i = 3
          [track] _baz @ test/test_expect_test.ml:357:16-357:20
            _baz => 6
        [track] <for i> @ test/test_expect_test.ml:356:14-356:15
          i = 4
          [track] _baz @ test/test_expect_test.ml:357:16-357:20
            _baz => 8
        [track] <for i> @ test/test_expect_test.ml:356:14-356:15
          i = 5
          [track] _baz @ test/test_expect_test.ml:357:16-357:20
            _baz => 10
        [track] <for i> @ test/test_expect_test.ml:356:14-356:15
          i = 6
          [track] _baz @ test/test_expect_test.ml:357:16-357:20
            _baz => 12
        [track] <for i> @ test/test_expect_test.ml:356:14-356:15
          i = 7
          [track] _baz @ test/test_expect_test.ml:357:16-357:20
            _baz => 14
        [track] <for i> @ test/test_expect_test.ml:356:14-356:15
          i = 8
          [track] _baz @ test/test_expect_test.ml:357:16-357:20
            _baz => 16
        [track] <for i> @ test/test_expect_test.ml:356:14-356:15
          i = 9
          [track] _baz @ test/test_expect_test.ml:357:16-357:20
            _baz => 18
        [track] <for i> @ test/test_expect_test.ml:356:14-356:15
          i = 10
          [track] _baz @ test/test_expect_test.ml:357:16-357:20
            _baz => 20
        [track] <for i> @ test/test_expect_test.ml:356:14-356:15
          i = 11
          i = <max_num_children exceeded>
    |}]

let%expect_test "%track_show track for-loop" =
  let run_id = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file in
    fun () -> rt
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
  let db = Minidebug_client.Client.open_db db_file in
  Minidebug_client.Client.show_trace db ~values_first_mode:false run_id;
  [%expect
    {|
    [track] _bar @ test/test_expect_test.ml:428:21-428:25
      [track] for:test_expect_test:431 @ test/test_expect_test.ml:431:10-434:14
        [track] <for i> @ test/test_expect_test.ml:431:14-431:15
          i = 0
          [track] _baz @ test/test_expect_test.ml:432:16-432:20
            _baz => 0
        [track] <for i> @ test/test_expect_test.ml:431:14-431:15
          i = 1
          [track] _baz @ test/test_expect_test.ml:432:16-432:20
            _baz => 2
        [track] <for i> @ test/test_expect_test.ml:431:14-431:15
          i = 2
          [track] _baz @ test/test_expect_test.ml:432:16-432:20
            _baz => 4
        [track] <for i> @ test/test_expect_test.ml:431:14-431:15
          i = 3
          [track] _baz @ test/test_expect_test.ml:432:16-432:20
            _baz => 6
        [track] <for i> @ test/test_expect_test.ml:431:14-431:15
          i = 4
          [track] _baz @ test/test_expect_test.ml:432:16-432:20
            _baz => 8
        [track] <for i> @ test/test_expect_test.ml:431:14-431:15
          i = 5
          [track] _baz @ test/test_expect_test.ml:432:16-432:20
            _baz => 10
        [track] <for i> @ test/test_expect_test.ml:431:14-431:15
          i = 6
          [track] _baz @ test/test_expect_test.ml:432:16-432:20
            _baz => 12
      _bar => ()
    |}]

let%expect_test "%track_show track for-loop, time spans" =
  let run_id = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file
      ~elapsed_times:Microseconds db_file in
    fun () -> rt
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
  let db = Minidebug_client.Client.open_db db_file in
  Minidebug_client.Client.show_trace db ~values_first_mode:false ~show_times:true run_id;
  let output = [%expect.output] in
  let output =
    Str.global_replace (Str.regexp {|[0-9]+?[0-9]+.[0-9]+[0-9]+\(μ\|m\|n\)s|}) "N.NNμs" output
  in
  print_endline output;
  [%expect
    {|
    [track] _bar @ test/test_expect_test.ml:485:21-485:25 <N.NNμs>
      [track] for:test_expect_test:488 @ test/test_expect_test.ml:488:10-491:14 <N.NNμs>
        [track] <for i> @ test/test_expect_test.ml:488:14-488:15 <N.NNμs>
          i = 0
          [track] _baz @ test/test_expect_test.ml:489:16-489:20 <N.NNμs>
            _baz => 0
        [track] <for i> @ test/test_expect_test.ml:488:14-488:15 <N.NNμs>
          i = 1
          [track] _baz @ test/test_expect_test.ml:489:16-489:20 <N.NNμs>
            _baz => 2
        [track] <for i> @ test/test_expect_test.ml:488:14-488:15 <N.NNμs>
          i = 2
          [track] _baz @ test/test_expect_test.ml:489:16-489:20 <N.NNμs>
            _baz => 4
        [track] <for i> @ test/test_expect_test.ml:488:14-488:15 <N.NNμs>
          i = 3
          [track] _baz @ test/test_expect_test.ml:489:16-489:20 <N.NNμs>
            _baz => 6
        [track] <for i> @ test/test_expect_test.ml:488:14-488:15 <N.NNμs>
          i = 4
          [track] _baz @ test/test_expect_test.ml:489:16-489:20 <N.NNμs>
            _baz => 8
        [track] <for i> @ test/test_expect_test.ml:488:14-488:15 <N.NNμs>
          i = 5
          [track] _baz @ test/test_expect_test.ml:489:16-489:20 <N.NNμs>
            _baz => 10
        [track] <for i> @ test/test_expect_test.ml:488:14-488:15 <N.NNμs>
          i = 6
          [track] _baz @ test/test_expect_test.ml:489:16-489:20 <N.NNμs>
            _baz => 12
      _bar => ()
    |}]

let%expect_test "%track_show track while-loop" =
  let run_id = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file in
    fun () -> rt
  in
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
  let db = Minidebug_client.Client.open_db db_file in
  Minidebug_client.Client.show_trace db ~values_first_mode:false run_id;
  [%expect
    {|
    [track] _bar @ test/test_expect_test.ml:546:21-546:25
      [track] while:test_expect_test:548 @ test/test_expect_test.ml:548:8-551:12
        [track] <while loop> @ test/test_expect_test.ml:549:10-550:16
          [track] _baz @ test/test_expect_test.ml:549:14-549:18
            _baz => 0
        [track] <while loop> @ test/test_expect_test.ml:549:10-550:16
          [track] _baz @ test/test_expect_test.ml:549:14-549:18
            _baz => 2
        [track] <while loop> @ test/test_expect_test.ml:549:10-550:16
          [track] _baz @ test/test_expect_test.ml:549:14-549:18
            _baz => 4
        [track] <while loop> @ test/test_expect_test.ml:549:10-550:16
          [track] _baz @ test/test_expect_test.ml:549:14-549:18
            _baz => 6
        [track] <while loop> @ test/test_expect_test.ml:549:10-550:16
          [track] _baz @ test/test_expect_test.ml:549:14-549:18
            _baz => 8
        [track] <while loop> @ test/test_expect_test.ml:549:10-550:16
          [track] _baz @ test/test_expect_test.ml:549:14-549:18
            _baz => 10
      _bar => ()
    |}]

let%expect_test "%debug_show num children exceeded nested" =
  let run_id = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file in
    fun () -> rt
  in
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
  let db = Minidebug_client.Client.open_db db_file in
  Minidebug_client.Client.show_trace db ~values_first_mode:false run_id;
  [%expect
    {|
    Raised exception: ppx_minidebug: max_num_children exceeded
    [debug] loop_exceeded @ test/test_expect_test.ml:589:35-597:72
      x = 3
      [debug] z @ test/test_expect_test.ml:596:17-596:18
        z => 1
      [debug] loop_exceeded @ test/test_expect_test.ml:589:35-597:72
        x = 2
        [debug] z @ test/test_expect_test.ml:596:17-596:18
          z => 0
        [debug] loop_exceeded @ test/test_expect_test.ml:589:35-597:72
          x = 1
          [debug] z @ test/test_expect_test.ml:596:17-596:18
            z => 0
          [debug] loop_exceeded @ test/test_expect_test.ml:589:35-597:72
            x = 0
            [debug] z @ test/test_expect_test.ml:596:17-596:18
              z => 0
            [debug] z @ test/test_expect_test.ml:596:17-596:18
              z => 1
            [debug] z @ test/test_expect_test.ml:596:17-596:18
              z => 2
            [debug] z @ test/test_expect_test.ml:596:17-596:18
              z => 3
            [debug] z @ test/test_expect_test.ml:596:17-596:18
              z => 4
            [debug] z @ test/test_expect_test.ml:596:17-596:18
              z => 5
            [debug] z @ test/test_expect_test.ml:596:17-596:18
              z => 6
            [debug] z @ test/test_expect_test.ml:596:17-596:18
              z => 7
            [debug] z @ test/test_expect_test.ml:596:17-596:18
              z => 8
            [debug] z @ test/test_expect_test.ml:596:17-596:18
              z => 9
            [debug] z @ test/test_expect_test.ml:596:17-596:18
              z = <max_num_children exceeded>
    |}]

let%expect_test "%track_show PrintBox tracking" =
  let run_id = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file in
    fun () -> rt
  in
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
  let db = Minidebug_client.Client.open_db db_file in
  Minidebug_client.Client.show_trace db ~values_first_mode:false run_id;
  [%expect
    {|
    4
    -3
    [track] track_branches @ test/test_expect_test.ml:652:32-654:46
      x = 7
      [track] else:test_expect_test:654 @ test/test_expect_test.ml:654:9-654:46
        [track] <match -- branch 1> @ test/test_expect_test.ml:654:36-654:37
      track_branches => 4
    [track] track_branches @ test/test_expect_test.ml:652:32-654:46
      x = 3
      [track] then:test_expect_test:653 @ test/test_expect_test.ml:653:18-653:57
        [track] <match -- branch 2> @ test/test_expect_test.ml:653:54-653:57
      track_branches => -3
    |}]

let%expect_test "%track_show PrintBox tracking <function>" =
  let run_id = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file in
    fun () -> rt
  in
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
  let db = Minidebug_client.Client.open_db db_file in
  Minidebug_client.Client.show_trace db ~values_first_mode:false run_id;
  [%expect
    {|
    4
    -3
    [track] <function -- branch 3> @ test/test_expect_test.ml:690:11-690:12
    [track] <function -- branch 5> x @ test/test_expect_test.ml:692:11-692:14
    |}]

let%expect_test "%track_show PrintBox tracking with debug_notrace" =
  let run_id = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file in
    fun () -> rt
  in
  (* $MDX part-begin=track_notrace_example *)
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
  let db = Minidebug_client.Client.open_db db_file in
  Minidebug_client.Client.show_trace db ~values_first_mode:false run_id;
  [%expect
    {|
    8
    3
    [track] track_branches @ test/test_expect_test.ml:717:32-731:16
      x = 8
      [track] else:test_expect_test:726 @ test/test_expect_test.ml:726:6-731:16
        [track] <match -- branch 2> @ test/test_expect_test.ml:730:10-731:16
          [track] result @ test/test_expect_test.ml:730:14-730:20
            [track] then:test_expect_test:730 @ test/test_expect_test.ml:730:44-730:45
            result => 8
      track_branches => 8
    [track] track_branches @ test/test_expect_test.ml:717:32-731:16
      x = 3
      [track] then:test_expect_test:719 @ test/test_expect_test.ml:719:6-724:16
        [debug] result @ test/test_expect_test.ml:723:14-723:20
          result => 3
      track_branches => 3
    |}]
(* $MDX part-end *)

let%expect_test "%track_show PrintBox not tracking anonymous functions with debug_notrace"
    =
  let run_id = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file in
    fun () -> rt
  in
  let%track_show track_foo (x : int) : int =
    [%debug_notrace (fun (y : int) -> ignore y) x];
    let w = [%debug_notrace (fun (v : int) -> v) x] in
    (fun (z : int) -> ignore z) x;
    w
  in
  let () = try print_endline @@ Int.to_string @@ track_foo 8 with _ -> print_endline "Raised exception." in
  let db = Minidebug_client.Client.open_db db_file in
  Minidebug_client.Client.show_trace db ~values_first_mode:false run_id;
  [%expect
    {|
    8
    [track] track_foo @ test/test_expect_test.ml:769:27-773:5
      x = 8
      [track] fun:test_expect_test:772 @ test/test_expect_test.ml:772:4-772:31
        z = 8
      track_foo => 8
    |}]

let%expect_test "respect scope of nested extension points" =
  let run_id = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file in
    fun () -> rt
  in
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
  let db = Minidebug_client.Client.open_db db_file in
  Minidebug_client.Client.show_trace db ~values_first_mode:false run_id;
  [%expect
    {|
    8
    3
    [track] track_branches @ test/test_expect_test.ml:794:32-808:16
      x = 8
      [track] else:test_expect_test:803 @ test/test_expect_test.ml:803:6-808:16
        [track] result @ test/test_expect_test.ml:807:25-807:31
          [track] then:test_expect_test:807 @ test/test_expect_test.ml:807:55-807:56
          result => 8
      track_branches => 8
    [track] track_branches @ test/test_expect_test.ml:794:32-808:16
      x = 3
      [track] then:test_expect_test:796 @ test/test_expect_test.ml:796:6-801:16
        [debug] result @ test/test_expect_test.ml:800:25-800:31
          result => 3
      track_branches => 3
    |}]

let%expect_test "%debug_show un-annotated toplevel fun" =
  let run_id = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file in
    fun () -> rt
  in
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
  let db = Minidebug_client.Client.open_db db_file in
  Minidebug_client.Client.show_trace db ~values_first_mode:false run_id;
  [%expect
    {|
    6
    6
    [debug] anonymous @ test/test_expect_test.ml:843:27-846:73
      "We do log this function"
    |}]

let%expect_test "%debug_show nested un-annotated toplevel fun" =
  let run_id = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file in
    fun () -> rt
  in
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
  let db = Minidebug_client.Client.open_db db_file in
  Minidebug_client.Client.show_trace db ~values_first_mode:false run_id;
  [%expect
    {|
    6
    6
    [debug] wrapper @ test/test_expect_test.ml:873:25-883:25
    [debug] anonymous @ test/test_expect_test.ml:874:29-877:75
      "We do log this function"
    |}]

let%expect_test "%track_show no return type anonymous fun 1" =
  let run_id = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file in
    fun () -> rt
  in
  let%debug_show anonymous (x : int) =
    Array.fold_left ( + ) 0 @@ Array.init (x + 1) (fun (i : int) -> i)
  in
  let () =
    try print_endline @@ Int.to_string @@ anonymous 3
    with Failure s -> print_endline @@ "Raised exception: " ^ s
  in
  let db = Minidebug_client.Client.open_db db_file in
  Minidebug_client.Client.show_trace db ~values_first_mode:false run_id;
  [%expect
    {|
    6
    [debug] anonymous @ test/test_expect_test.ml:907:27-908:70
      x = 3
    |}]

let%expect_test "%track_show no return type anonymous fun 2" =
  let run_id = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file in
    fun () -> rt
  in
  (* $MDX part-begin=track_anonymous_example *)
  let%track_show anonymous (x : int) =
    Array.fold_left ( + ) 0 @@ Array.init (x + 1) (fun (i : int) -> i)
  in
  let () =
    try print_endline @@ Int.to_string @@ anonymous 3
    with Failure s -> print_endline @@ "Raised exception: " ^ s
  in
  let db = Minidebug_client.Client.open_db db_file in
  Minidebug_client.Client.show_trace db ~values_first_mode:false run_id;
  [%expect
    {|
    6
    [track] anonymous @ test/test_expect_test.ml:930:27-931:70
      x = 3
      [track] fun:test_expect_test:931 @ test/test_expect_test.ml:931:50-931:70
        i = 0
      [track] fun:test_expect_test:931 @ test/test_expect_test.ml:931:50-931:70
        i = 1
      [track] fun:test_expect_test:931 @ test/test_expect_test.ml:931:50-931:70
        i = 2
      [track] fun:test_expect_test:931 @ test/test_expect_test.ml:931:50-931:70
        i = 3
    |}]
(* $MDX part-end *)

let%expect_test "%track_show anonymous fun, num children exceeded" =
  let run_id = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file in
    fun () -> rt
  in
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
  let db = Minidebug_client.Client.open_db db_file in
  Minidebug_client.Client.show_trace db ~values_first_mode:false run_id;
  [%expect
    {|
    Raised exception: ppx_minidebug: max_num_children exceeded
    [track] loop_exceeded @ test/test_expect_test.ml:961:35-969:72
      x = 3
      [track] fun:test_expect_test:967 @ test/test_expect_test.ml:967:11-969:71
        i = 0
        [track] z @ test/test_expect_test.ml:968:17-968:18
          z => 1
        [track] else:test_expect_test:969 @ test/test_expect_test.ml:969:35-969:70
          [track] loop_exceeded @ test/test_expect_test.ml:961:35-969:72
            x = 2
            [track] fun:test_expect_test:967 @ test/test_expect_test.ml:967:11-969:71
              i = 0
              [track] z @ test/test_expect_test.ml:968:17-968:18
                z => 0
              [track] else:test_expect_test:969 @ test/test_expect_test.ml:969:35-969:70
                [track] loop_exceeded @ test/test_expect_test.ml:961:35-969:72
                  x = 1
                  [track] fun:test_expect_test:967 @ test/test_expect_test.ml:967:11-969:71
                    i = 0
                    [track] z @ test/test_expect_test.ml:968:17-968:18
                      z => 0
                    [track] else:test_expect_test:969 @ test/test_expect_test.ml:969:35-969:70
                      [track] loop_exceeded @ test/test_expect_test.ml:961:35-969:72
                        x = 0
                        [track] fun:test_expect_test:967 @ test/test_expect_test.ml:967:11-969:71
                          i = 0
                          [track] z @ test/test_expect_test.ml:968:17-968:18
                            z => 0
                          [track] then:test_expect_test:969 @ test/test_expect_test.ml:969:28-969:29
                        [track] fun:test_expect_test:967 @ test/test_expect_test.ml:967:11-969:71
                          i = 1
                          [track] z @ test/test_expect_test.ml:968:17-968:18
                            z => 1
                          [track] then:test_expect_test:969 @ test/test_expect_test.ml:969:28-969:29
                        [track] fun:test_expect_test:967 @ test/test_expect_test.ml:967:11-969:71
                          i = 2
                          [track] z @ test/test_expect_test.ml:968:17-968:18
                            z => 2
                          [track] then:test_expect_test:969 @ test/test_expect_test.ml:969:28-969:29
                        [track] fun:test_expect_test:967 @ test/test_expect_test.ml:967:11-969:71
                          i = 3
                          [track] z @ test/test_expect_test.ml:968:17-968:18
                            z => 3
                          [track] then:test_expect_test:969 @ test/test_expect_test.ml:969:28-969:29
                        [track] fun:test_expect_test:967 @ test/test_expect_test.ml:967:11-969:71
                          i = 4
                          [track] z @ test/test_expect_test.ml:968:17-968:18
                            z => 4
                          [track] then:test_expect_test:969 @ test/test_expect_test.ml:969:28-969:29
                        [track] fun:test_expect_test:967 @ test/test_expect_test.ml:967:11-969:71
                          i = 5
                          [track] z @ test/test_expect_test.ml:968:17-968:18
                            z => 5
                          [track] then:test_expect_test:969 @ test/test_expect_test.ml:969:28-969:29
                        [track] fun:test_expect_test:967 @ test/test_expect_test.ml:967:11-969:71
                          i = 6
                          [track] z @ test/test_expect_test.ml:968:17-968:18
                            z => 6
                          [track] then:test_expect_test:969 @ test/test_expect_test.ml:969:28-969:29
                        [track] fun:test_expect_test:967 @ test/test_expect_test.ml:967:11-969:71
                          i = 7
                          [track] z @ test/test_expect_test.ml:968:17-968:18
                            z => 7
                          [track] then:test_expect_test:969 @ test/test_expect_test.ml:969:28-969:29
                        [track] fun:test_expect_test:967 @ test/test_expect_test.ml:967:11-969:71
                          i = 8
                          [track] z @ test/test_expect_test.ml:968:17-968:18
                            z => 8
                          [track] then:test_expect_test:969 @ test/test_expect_test.ml:969:28-969:29
                        [track] fun:test_expect_test:967 @ test/test_expect_test.ml:967:11-969:71
                          i = 9
                          [track] z @ test/test_expect_test.ml:968:17-968:18
                            z => 9
                          [track] then:test_expect_test:969 @ test/test_expect_test.ml:969:28-969:29
                        [track] fun:test_expect_test:967 @ test/test_expect_test.ml:967:11-969:71
                          i = 10
                          fun:test_expect_test:967 = <max_num_children exceeded>
    |}]

module type T = sig
  type c

  val c : c
end

let%expect_test "%debug_show function with abstract type" =
  let run_id = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file in
    fun () -> rt
  in
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
  let db = Minidebug_client.Client.open_db db_file in
  Minidebug_client.Client.show_trace db ~values_first_mode:false run_id;
  [%expect
    {|
    2
    [debug] foo @ test/test_expect_test.ml:1070:21-1071:47
      c = 1
      foo => 2
    |}]

let%expect_test "%debug_show PrintBox values_first_mode to stdout with exception" =
  let run_id = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file in
    fun () -> rt
  in
  let%debug_show rec loop_truncated (x : int) : int =
    let z : int = (x - 1) / 2 in
    if x <= 0 then failwith "the log as for loop_complete but without return values";
    z + loop_truncated (z + (x / 2))
  in
  let () =
    try print_endline @@ Int.to_string @@ loop_truncated 7
    with _ -> print_endline "Raised exception."
  in
  let db = Minidebug_client.Client.open_db db_file in
  Minidebug_client.Client.show_trace db ~values_first_mode:true run_id;
  [%expect
    {|
    Raised exception.
    [debug] loop_truncated @ test/test_expect_test.ml:1101:36-1104:36
      x = 7
      [debug] z => 3 @ test/test_expect_test.ml:1102:8-1102:9
      [debug] loop_truncated @ test/test_expect_test.ml:1101:36-1104:36
        x = 6
        [debug] z => 2 @ test/test_expect_test.ml:1102:8-1102:9
        [debug] loop_truncated @ test/test_expect_test.ml:1101:36-1104:36
          x = 5
          [debug] z => 2 @ test/test_expect_test.ml:1102:8-1102:9
          [debug] loop_truncated @ test/test_expect_test.ml:1101:36-1104:36
            x = 4
            [debug] z => 1 @ test/test_expect_test.ml:1102:8-1102:9
            [debug] loop_truncated @ test/test_expect_test.ml:1101:36-1104:36
              x = 3
              [debug] z => 1 @ test/test_expect_test.ml:1102:8-1102:9
              [debug] loop_truncated @ test/test_expect_test.ml:1101:36-1104:36
                x = 2
                [debug] z => 0 @ test/test_expect_test.ml:1102:8-1102:9
                [debug] loop_truncated @ test/test_expect_test.ml:1101:36-1104:36
                  x = 1
                  [debug] z => 0 @ test/test_expect_test.ml:1102:8-1102:9
                  [debug] loop_truncated @ test/test_expect_test.ml:1101:36-1104:36
                    x = 0
                    [debug] z => 0 @ test/test_expect_test.ml:1102:8-1102:9
    |}]

let%expect_test
    "%debug_show values_first_mode to stdout num children exceeded linear" =
  let run_id = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file in
    fun () -> rt
  in
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
  let db = Minidebug_client.Client.open_db db_file in
  Minidebug_client.Client.show_trace db ~values_first_mode:true run_id;
  [%expect
    {|
    Raised exception: ppx_minidebug: max_num_children exceeded
    [debug] _bar @ test/test_expect_test.ml:1150:21-1150:25
      [debug] _baz => 0 @ test/test_expect_test.ml:1154:16-1154:20
      [debug] _baz => 2 @ test/test_expect_test.ml:1154:16-1154:20
      [debug] _baz => 4 @ test/test_expect_test.ml:1154:16-1154:20
      [debug] _baz => 6 @ test/test_expect_test.ml:1154:16-1154:20
      [debug] _baz => 8 @ test/test_expect_test.ml:1154:16-1154:20
      [debug] _baz => 10 @ test/test_expect_test.ml:1154:16-1154:20
      [debug] _baz => 12 @ test/test_expect_test.ml:1154:16-1154:20
      [debug] _baz => 14 @ test/test_expect_test.ml:1154:16-1154:20
      [debug] _baz => 16 @ test/test_expect_test.ml:1154:16-1154:20
      [debug] _baz => 18 @ test/test_expect_test.ml:1154:16-1154:20
      [debug] _baz => 20 @ test/test_expect_test.ml:1154:16-1154:20
      [debug] _baz @ test/test_expect_test.ml:1154:16-1154:20
        _baz = <max_num_children exceeded>
    |}]

let%expect_test "%track_show values_first_mode to stdout track for-loop" =
  let run_id = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file in
    fun () -> rt
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
  let db = Minidebug_client.Client.open_db db_file in
  Minidebug_client.Client.show_trace db ~values_first_mode:true run_id;
  [%expect
    {|
    [track] _bar => () @ test/test_expect_test.ml:1190:21-1190:25
      [track] for:test_expect_test:1193 @ test/test_expect_test.ml:1193:10-1196:14
        [track] <for i> @ test/test_expect_test.ml:1193:14-1193:15
          i = 0
          [track] _baz => 0 @ test/test_expect_test.ml:1194:16-1194:20
        [track] <for i> @ test/test_expect_test.ml:1193:14-1193:15
          i = 1
          [track] _baz => 2 @ test/test_expect_test.ml:1194:16-1194:20
        [track] <for i> @ test/test_expect_test.ml:1193:14-1193:15
          i = 2
          [track] _baz => 4 @ test/test_expect_test.ml:1194:16-1194:20
        [track] <for i> @ test/test_expect_test.ml:1193:14-1193:15
          i = 3
          [track] _baz => 6 @ test/test_expect_test.ml:1194:16-1194:20
        [track] <for i> @ test/test_expect_test.ml:1193:14-1193:15
          i = 4
          [track] _baz => 8 @ test/test_expect_test.ml:1194:16-1194:20
        [track] <for i> @ test/test_expect_test.ml:1193:14-1193:15
          i = 5
          [track] _baz => 10 @ test/test_expect_test.ml:1194:16-1194:20
        [track] <for i> @ test/test_expect_test.ml:1193:14-1193:15
          i = 6
          [track] _baz => 12 @ test/test_expect_test.ml:1194:16-1194:20
    |}]

let%expect_test "%debug_show values_first_mode to stdout num children exceeded nested" =
  let run_id = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file in
    fun () -> rt
  in
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
  let db = Minidebug_client.Client.open_db db_file in
  Minidebug_client.Client.show_trace db ~values_first_mode:true run_id;
  [%expect
    {|
    Raised exception: ppx_minidebug: max_num_children exceeded
    [debug] loop_exceeded @ test/test_expect_test.ml:1236:35-1244:72
      x = 3
      [debug] z => 1 @ test/test_expect_test.ml:1243:17-1243:18
      [debug] loop_exceeded @ test/test_expect_test.ml:1236:35-1244:72
        x = 2
        [debug] z => 0 @ test/test_expect_test.ml:1243:17-1243:18
        [debug] loop_exceeded @ test/test_expect_test.ml:1236:35-1244:72
          x = 1
          [debug] z => 0 @ test/test_expect_test.ml:1243:17-1243:18
          [debug] loop_exceeded @ test/test_expect_test.ml:1236:35-1244:72
            x = 0
            [debug] z => 0 @ test/test_expect_test.ml:1243:17-1243:18
            [debug] z => 1 @ test/test_expect_test.ml:1243:17-1243:18
            [debug] z => 2 @ test/test_expect_test.ml:1243:17-1243:18
            [debug] z => 3 @ test/test_expect_test.ml:1243:17-1243:18
            [debug] z => 4 @ test/test_expect_test.ml:1243:17-1243:18
            [debug] z => 5 @ test/test_expect_test.ml:1243:17-1243:18
            [debug] z => 6 @ test/test_expect_test.ml:1243:17-1243:18
            [debug] z => 7 @ test/test_expect_test.ml:1243:17-1243:18
            [debug] z => 8 @ test/test_expect_test.ml:1243:17-1243:18
            [debug] z => 9 @ test/test_expect_test.ml:1243:17-1243:18
            [debug] z @ test/test_expect_test.ml:1243:17-1243:18
              z = <max_num_children exceeded>
    |}]


let%expect_test "%track_show values_first_mode tracking" =
  let run_id = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file in
    fun () -> rt
  in
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
  let db = Minidebug_client.Client.open_db db_file in
  Minidebug_client.Client.show_trace db ~values_first_mode:true run_id;
  [%expect
    {|
    4
    -3
    [track] track_branches => 4 @ test/test_expect_test.ml:1287:32-1289:46
      x = 7
      [track] else:test_expect_test:1289 @ test/test_expect_test.ml:1289:9-1289:46
        [track] <match -- branch 1> @ test/test_expect_test.ml:1289:36-1289:37
    [track] track_branches => -3 @ test/test_expect_test.ml:1287:32-1289:46
      x = 3
      [track] then:test_expect_test:1288 @ test/test_expect_test.ml:1288:18-1288:57
        [track] <match -- branch 2> @ test/test_expect_test.ml:1288:54-1288:57
    |}]

let%expect_test "%track_show values_first_mode to stdout no return type anonymous fun" =
  let run_id = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file in
    fun () -> rt
  in
  let%track_show anonymous (x : int) =
    Array.fold_left ( + ) 0 @@ Array.init (x + 1) (fun (i : int) -> i)
  in
  let () =
    try print_endline @@ Int.to_string @@ anonymous 3
    with Failure s -> print_endline @@ "Raised exception: " ^ s
  in
  let db = Minidebug_client.Client.open_db db_file in
  Minidebug_client.Client.show_trace db ~values_first_mode:true run_id;
  [%expect
    {|
    6
    [track] anonymous @ test/test_expect_test.ml:1319:27-1320:70
      x = 3
      [track] fun:test_expect_test:1320 @ test/test_expect_test.ml:1320:50-1320:70
        i = 0
      [track] fun:test_expect_test:1320 @ test/test_expect_test.ml:1320:50-1320:70
        i = 1
      [track] fun:test_expect_test:1320 @ test/test_expect_test.ml:1320:50-1320:70
        i = 2
      [track] fun:test_expect_test:1320 @ test/test_expect_test.ml:1320:50-1320:70
        i = 3
    |}]

let%expect_test "%debug_show records" =
  let run_id = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file in
    fun () -> rt
  in
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
  let db = Minidebug_client.Client.open_db db_file in
  Minidebug_client.Client.show_trace db ~values_first_mode:false run_id;
  [%expect
    {|
    336
    109
    [debug] bar @ test/test_expect_test.ml:1349:21-1352:15
      first = 7
      second = 42
      [debug] {first=a; second=b} @ test/test_expect_test.ml:1350:8-1350:45
        a => 7
        b => 45
      [debug] y @ test/test_expect_test.ml:1351:8-1351:9
        y => 8
      bar => 336
    [debug] baz @ test/test_expect_test.ml:1355:21-1357:28
      first = 7
      second = 42
      [debug] {first; second} @ test/test_expect_test.ml:1356:8-1356:37
        first => 8
        second => 45
      baz => 109
    |}]

let%expect_test "%debug_show tuples" =
  let run_id = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file in
    fun () -> rt
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
  let db = Minidebug_client.Client.open_db db_file in
  Minidebug_client.Client.show_trace db ~values_first_mode:false run_id;
  [%expect
    {|
    336
    339
    109
    [debug] bar @ test/test_expect_test.ml:1390:21-1392:14
      first = 7
      second = 42
      [debug] y @ test/test_expect_test.ml:1391:8-1391:9
        y => 8
      bar => 336
    [debug] (r1, r2) @ test/test_expect_test.ml:1400:17-1400:23
      [debug] baz @ test/test_expect_test.ml:1395:21-1398:35
        first = 7
        second = 42
        [debug] (y, z) @ test/test_expect_test.ml:1396:8-1396:14
          y => 8
          z => 3
        [debug] (a, b) @ test/test_expect_test.ml:1397:8-1397:28
          a => 8
          b => 45
        baz => (339, 109)
      r1 => 339
      r2 => 109
    |}]

let%expect_test "%debug_show records values_first_mode" =
  let run_id = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file in
    fun () -> rt
  in
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
  let db = Minidebug_client.Client.open_db db_file in
  Minidebug_client.Client.show_trace db ~values_first_mode:true run_id;
  [%expect
    {|
    336
    109
    [debug] bar => 336 @ test/test_expect_test.ml:1437:21-1440:15
      first = 7
      second = 42
      [debug] {first=a; second=b} @ test/test_expect_test.ml:1438:8-1438:45
        a => 7
        b => 45
      [debug] y => 8 @ test/test_expect_test.ml:1439:8-1439:9
    [debug] baz => 109 @ test/test_expect_test.ml:1443:21-1445:28
      first = 7
      second = 42
      [debug] {first; second} @ test/test_expect_test.ml:1444:8-1444:37
        first => 8
        second => 45
    |}]

let%expect_test "%debug_show tuples values_first_mode" =
  let run_id = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file in
    fun () -> rt
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
  let db = Minidebug_client.Client.open_db db_file in
  Minidebug_client.Client.show_trace db ~values_first_mode:true run_id;
  [%expect
    {|
    336
    339
    109
    [debug] bar => 336 @ test/test_expect_test.ml:1475:21-1477:14
      first = 7
      second = 42
      [debug] y => 8 @ test/test_expect_test.ml:1476:8-1476:9
    [debug] (r1, r2) @ test/test_expect_test.ml:1485:17-1485:23
      r1 => 339
      r2 => 109
      [debug] baz => (339, 109) @ test/test_expect_test.ml:1480:21-1483:35
        first = 7
        second = 42
        [debug] (y, z) @ test/test_expect_test.ml:1481:8-1481:14
          y => 8
          z => 3
        [debug] (a, b) @ test/test_expect_test.ml:1482:8-1482:28
          a => 8
          b => 45
    |}]

type 'a irrefutable = Zero of 'a
type ('a, 'b) left_right = Left of 'a | Right of 'b
type ('a, 'b, 'c) one_two_three = One of 'a | Two of 'b | Three of 'c

let%expect_test "%track_show variants values_first_mode" =
  let run_id = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file in
    fun () -> rt
  in
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
  let db = Minidebug_client.Client.open_db db_file in
  Minidebug_client.Client.show_trace db ~values_first_mode:true run_id;
  [%expect
    {|
    16
    5
    6
    3
    [track] bar => 16 @ test/test_expect_test.ml:1523:21-1525:9
      x = 7
      [track] y => 8 @ test/test_expect_test.ml:1524:8-1524:9
    [track] <function -- branch 0> Left x => baz = 5 @ test/test_expect_test.ml:1529:24-1529:29
      x = 4
    [track] <function -- branch 1> Right Two y => baz = 6 @ test/test_expect_test.ml:1530:31-1530:36
      y = 3
    [track] foo => 3 @ test/test_expect_test.ml:1533:21-1534:82
      [track] <match -- branch 2> @ test/test_expect_test.ml:1534:81-1534:82
    |}]

let%expect_test "%debug_show tuples merge type info" =
  let run_id = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file in
    fun () -> rt
  in
  let%debug_show baz (((first : int), (second : 'a)) : 'b * int) : int * int =
    let ((y : 'c), (z : int)) : int * 'd = (first + 1, 3) in
    let (a : int), b = (first + 1, (second + 3 : int)) in
    ((second * y) + z, (a * a) + b)
  in
  let%debug_show (r1 : 'e), (r2 : int) = (baz (7, 42) : int * 'f) in
  let () = print_endline @@ Int.to_string r1 in
  let () = print_endline @@ Int.to_string r2 in
  let db = Minidebug_client.Client.open_db db_file in
  Minidebug_client.Client.show_trace db run_id;
  (* Note the missing value of [b]: the nested-in-expression type is not propagated. *)
  [%expect
    {|
    339
    109
    [debug] (r1, r2) @ test/test_expect_test.ml:1569:17-1569:38
      r1 => 339
      r2 => 109
      [debug] baz => (339, 109) @ test/test_expect_test.ml:1564:21-1567:35
        first = 7
        second = 42
        [debug] (y, z) @ test/test_expect_test.ml:1565:8-1565:29
          y => 8
          z => 3
        [debug] (a, b) => a = 8 @ test/test_expect_test.ml:1566:8-1566:20
    |}]

let%expect_test "%debug_show decompose multi-argument function type" =
  let run_id = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file in
    fun () -> rt
  in
  let%debug_show f : 'a. 'a -> int -> int = fun _a b -> b + 1 in
  let%debug_show g : 'a. 'a -> int -> 'a -> 'a -> int = fun _a b _c _d -> b * 2 in
  let () = print_endline @@ Int.to_string @@ f 'a' 6 in
  let () = print_endline @@ Int.to_string @@ g 'a' 6 'b' 'c' in
  let db = Minidebug_client.Client.open_db db_file in
  Minidebug_client.Client.show_trace db run_id;
  [%expect
    {|
    7
    12
    [debug] f => 7 @ test/test_expect_test.ml:1597:44-1597:61
      b = 6
    [debug] g => 12 @ test/test_expect_test.ml:1598:56-1598:79
      b = 6
    |}]

let%expect_test "%debug_show debug type info" =
  let run_id = next_run () in
  (* $MDX part-begin=debug_type_info *)
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file in
    fun () -> rt
  in
  [%debug_show
    [%debug_type_info
      let f : 'a. 'a -> int -> int = fun _a b -> b + 1 in
      let g : 'a. 'a -> int -> 'a -> 'a -> int = fun _a b _c _d -> b * 2 in
      let () = print_endline @@ Int.to_string @@ f 'a' 6 in
      print_endline @@ Int.to_string @@ g 'a' 6 'b' 'c']];
  let db = Minidebug_client.Client.open_db db_file in
  Minidebug_client.Client.show_trace db run_id;
  [%expect
    {|
    7
    12
    [debug] f : int => 7 @ test/test_expect_test.ml:1622:37-1622:54
      b : int = 6
    [debug] g : int => 12 @ test/test_expect_test.ml:1623:49-1623:72
      b : int = 6
    |}]
(* $MDX part-end *)

(*
let%expect_test "%track_show options values_first_mode" =
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file in
    fun () -> rt
  in
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
    ├─"test/test_expect_test.ml":2241:21
    └─<match -- branch 1> Some y
      ├─"test/test_expect_test.ml":2242:54
      └─y = 7
    14
    bar = 14
    ├─"test/test_expect_test.ml":2245:21
    ├─l = (Some 7)
    └─<match -- branch 1> Some y
      └─"test/test_expect_test.ml":2246:39
    14
    baz = 8
    ├─"test/test_expect_test.ml":2249:74
    ├─<function -- branch 1> Some y
    └─y = 4
    8
    zoo = 9
    ├─"test/test_expect_test.ml":2253:21
    ├─<function -- branch 1> Some (y, z)
    ├─y = 4
    └─z = 5
    9
    |}]

*)

(*
let%expect_test "%track_show list values_first_mode" =
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file in
    fun () -> rt
  in
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
    ├─"test/test_expect_test.ml":2286:21
    └─<match -- branch 1> :: (y, _)
      ├─"test/test_expect_test.ml":2286:77
      └─y = 7
    14
    bar = 14
    ├─"test/test_expect_test.ml":2288:21
    ├─l = [7]
    └─<match -- branch 1> :: (y, _)
      └─"test/test_expect_test.ml":2288:77
    14
    baz = 8
    ├─"test/test_expect_test.ml":2292:15
    ├─<function -- branch 1> :: (y, [])
    └─y = 4
    8
    baz = 9
    ├─"test/test_expect_test.ml":2293:18
    ├─<function -- branch 2> :: (y, :: (z, []))
    ├─y = 4
    └─z = 5
    9
    baz = 10
    ├─"test/test_expect_test.ml":2294:21
    ├─<function -- branch 3> :: (y, :: (z, _))
    ├─y = 4
    └─z = 5
    10
    |}]

*)

(*
let%expect_test "%track_rt_show list runtime passing" =
  (* $MDX part-begin=track_rt_show_list_runtime_passing *)
  let%track_rt_show foo l : int = match (l : int list) with [] -> 7 | y :: _ -> y * 2 in
  let () =
    print_endline @@ Int.to_string
    @@ foo Minidebug_runtime.(forget_printbox @@ debug ~run_name:"foo-1" ()) [ 7 ]
  in
  let%track_rt_show baz : int list -> int = function
    | [] -> 7
    | [ y ] -> y * 2
    | [ y; z ] -> y + z
    | y :: z :: _ -> y + z + 1
  in
  let () =
    print_endline @@ Int.to_string
    @@ baz Minidebug_runtime.(forget_printbox @@ debug ~run_name:"baz-1" ()) [ 4 ]
  in
  let () =
    print_endline @@ Int.to_string
    @@ baz
         Minidebug_runtime.(forget_printbox @@ debug ~run_name:"baz-2" ())
         [ 4; 5; 6 ]
  in
  [%expect
    {|
    BEGIN DEBUG SESSION foo-1
    foo = 14
    ├─"test/test_expect_test.ml":2335:24
    └─foo-1 <match -- branch 1> :: (y, _)
      ├─"test/test_expect_test.ml":2335:80
      └─y = 7
    14

    BEGIN DEBUG SESSION baz-1
    baz = 8
    ├─"test/test_expect_test.ml":2342:15
    ├─baz-1 <function -- branch 1> :: (y, [])
    └─y = 4
    8

    BEGIN DEBUG SESSION baz-2
    baz = 10
    ├─"test/test_expect_test.ml":2344:21
    ├─baz-2 <function -- branch 3> :: (y, :: (z, _))
    ├─y = 4
    └─z = 5
    10
    |}]
(* $MDX part-end *)

*)

(*
let%expect_test "%track_rt_show procedure runtime passing" =
  let%track_rt_show bar () = (fun () -> ()) () in
  let () = bar (Minidebug_runtime.debug_flushing ~run_name:"bar-1" ()) () in
  let () = bar (Minidebug_runtime.debug_flushing ~run_name:"bar-2" ()) () in
  let%track_rt_show foo () =
    let () = () in
    ()
  in
  let () = foo (Minidebug_runtime.debug_flushing ~run_name:"foo-1" ()) () in
  let () = foo (Minidebug_runtime.debug_flushing ~run_name:"foo-2" ()) () in
  [%expect
    {|
    BEGIN DEBUG SESSION bar-1
    bar-1 bar begin "test/test_expect_test.ml":2384:24:
     bar-1 fun:test_expect_test:2384 begin "test/test_expect_test.ml":2384:29:
     bar-1 fun:test_expect_test:2384 end
    bar-1 bar end

    BEGIN DEBUG SESSION bar-2
    bar-2 bar begin "test/test_expect_test.ml":2384:24:
     bar-2 fun:test_expect_test:2384 begin "test/test_expect_test.ml":2384:29:
     bar-2 fun:test_expect_test:2384 end
    bar-2 bar end

    BEGIN DEBUG SESSION foo-1
    foo-1 foo begin "test/test_expect_test.ml":2387:24:
    foo-1 foo end

    BEGIN DEBUG SESSION foo-2
    foo-2 foo begin "test/test_expect_test.ml":2387:24:
    foo-2 foo end
    |}]

*)

(*
let%expect_test "%track_rt_show nested procedure runtime passing" =
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file in
    fun () -> rt
  in
  let%debug_show rt_test () =
    let%track_rt_show bar () = (fun () -> ()) () in
    let%track_rt_show foo () =
      let () = () in
      ()
    in
    (foo, bar)
  in
  let foo, bar = rt_test () in
  let () = foo (Minidebug_runtime.debug_flushing ~run_name:"foo-1" ()) () in
  let () = foo (Minidebug_runtime.debug_flushing ~run_name:"foo-2" ()) () in
  let () = bar (Minidebug_runtime.debug_flushing ~run_name:"bar-1" ()) () in
  let () = bar (Minidebug_runtime.debug_flushing ~run_name:"bar-2" ()) () in
  [%expect
    {|
    BEGIN DEBUG SESSION

    BEGIN DEBUG SESSION foo-1
    foo-1 foo begin "test/test_expect_test.ml":2420:26:
    foo-1 foo end

    BEGIN DEBUG SESSION foo-2
    foo-2 foo begin "test/test_expect_test.ml":2420:26:
    foo-2 foo end

    BEGIN DEBUG SESSION bar-1
    bar-1 bar begin "test/test_expect_test.ml":2419:26:
     bar-1 fun:test_expect_test:2419 begin "test/test_expect_test.ml":2419:31:
     bar-1 fun:test_expect_test:2419 end
    bar-1 bar end

    BEGIN DEBUG SESSION bar-2
    bar-2 bar begin "test/test_expect_test.ml":2419:26:
     bar-2 fun:test_expect_test:2419 begin "test/test_expect_test.ml":2419:31:
     bar-2 fun:test_expect_test:2419 end
    bar-2 bar end
    |}]

*)

(*
let%expect_test "%log constant entries" =
  let boxify_sexp_from = ref 20 in
  let update_config config =
    config.Minidebug_runtime.boxify_sexp_from_size <- !boxify_sexp_from
  in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file in
    fun () -> rt
  in
  let%debug_show foo () : unit =
    [%log "This is the first log line"];
    [%log [ "This is the"; "2"; "log line" ]];
    [%log "This is the", 3, "or", 3.14, "log line"]
  in
  let () = foo () in
  boxify_sexp_from := 2;
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
    ├─"test/test_expect_test.ml":2462:21
    ├─"This is the first log line"
    ├─["This is the"; "2"; "log line"]
    └─("This is the", 3, "or", 3.14, "log line")
    bar
    ├─"test/test_expect_test.ml":2469:21
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

*)

(*
let%expect_test "%log with type annotations" =
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file in
    fun () -> rt
  in
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
    ├─"test/test_expect_test.ml":2501:21
    ├─("This is like", 3, "or", 3.14, "above")
    ├─("tau =", 6.28)
    ├─[4; 1; 2; 3]
    ├─[3; 1; 2; 3]
    └─[3; 1; 2; 3]
    |}]

*)

(*
let%expect_test "%log with default type assumption" =
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file in
    fun () -> rt
  in
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
    ├─"test/test_expect_test.ml":2527:21
    ├─"2*3"
    ├─("This is like", "3", "or", "3.14", "above")
    ├─("tau =", "2*3.14")
    └─[("2*3", 0); ("1", 1); ("2", 2); ("3", 3)]
    |}]

*)

(*
let%expect_test "%log track while-loop" =
  (* $MDX part-begin=track_while_loop_example *)
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file ~values_first_mode:false db_file in
    fun () -> rt
  in
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
    "test/test_expect_test.ml":2553:17: result
    └─"test/test_expect_test.ml":2556:4: while:test_expect_test:2556
      ├─"test/test_expect_test.ml":2557:6: <while loop>
      │ ├─(1 i= 0)
      │ ├─(2 i= 1)
      │ └─(3 j= 1)
      ├─"test/test_expect_test.ml":2557:6: <while loop>
      │ ├─(1 i= 1)
      │ ├─(2 i= 2)
      │ └─(3 j= 3)
      ├─"test/test_expect_test.ml":2557:6: <while loop>
      │ ├─(1 i= 2)
      │ ├─(2 i= 3)
      │ └─(3 j= 6)
      ├─"test/test_expect_test.ml":2557:6: <while loop>
      │ ├─(1 i= 3)
      │ ├─(2 i= 4)
      │ └─(3 j= 10)
      ├─"test/test_expect_test.ml":2557:6: <while loop>
      │ ├─(1 i= 4)
      │ ├─(2 i= 5)
      │ └─(3 j= 15)
      └─"test/test_expect_test.ml":2557:6: <while loop>
        ├─(1 i= 5)
        ├─(2 i= 6)
        └─(3 j= 21)
    21
    |}]
(* $MDX part-end *)

*)

(*
let%expect_test "%log runtime log levels while-loop" =
  (* $MDX part-begin=log_runtime_log_levels_while_loop_example *)
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
          Minidebug_runtime.(
            forget_printbox
            @@ debug ~values_first_mode:false ~run_name:"Everything" ())
          ());
  print_endline
  @@ Int.to_string
       (result
          Minidebug_runtime.(
            forget_printbox
            @@ debug ~values_first_mode:false ~log_level:0 ~run_name:"Nothing" ())
          ());
  print_endline
  @@ Int.to_string
       (result
          Minidebug_runtime.(
            forget_printbox @@ debug ~log_level:1 ~run_name:"Error" ())
          ());
  (* $MDX part-end *)
  print_endline
  @@ Int.to_string
       (result
          Minidebug_runtime.(
            forget_printbox @@ debug ~log_level:2 ~run_name:"Warning" ())
          ());
  [%expect
    {|
    BEGIN DEBUG SESSION Everything
    "test/test_expect_test.ml":2601:27: Everything result
    ├─"test/test_expect_test.ml":2604:4: Everything while:test_expect_test:2604
    │ ├─"test/test_expect_test.ml":2606:6: Everything <while loop>
    │ │ ├─"test/test_expect_test.ml":2606:21: Everything then:test_expect_test:2606
    │ │ │ └─(ERROR: 1 i= 0)
    │ │ ├─(WARNING: 2 i= 1)
    │ │ ├─"test/test_expect_test.ml":2609:11: Everything fun:test_expect_test:2609
    │ │ └─(INFO: 3 j= 1)
    │ ├─"test/test_expect_test.ml":2606:6: Everything <while loop>
    │ │ ├─"test/test_expect_test.ml":2606:21: Everything then:test_expect_test:2606
    │ │ │ └─(ERROR: 1 i= 1)
    │ │ ├─(WARNING: 2 i= 2)
    │ │ ├─"test/test_expect_test.ml":2609:11: Everything fun:test_expect_test:2609
    │ │ └─(INFO: 3 j= 3)
    │ ├─"test/test_expect_test.ml":2606:6: Everything <while loop>
    │ │ ├─"test/test_expect_test.ml":2606:64: Everything else:test_expect_test:2606
    │ │ ├─(WARNING: 2 i= 3)
    │ │ ├─"test/test_expect_test.ml":2609:11: Everything fun:test_expect_test:2609
    │ │ └─(INFO: 3 j= 6)
    │ ├─"test/test_expect_test.ml":2606:6: Everything <while loop>
    │ │ ├─"test/test_expect_test.ml":2606:64: Everything else:test_expect_test:2606
    │ │ ├─(WARNING: 2 i= 4)
    │ │ ├─"test/test_expect_test.ml":2609:11: Everything fun:test_expect_test:2609
    │ │ └─(INFO: 3 j= 10)
    │ ├─"test/test_expect_test.ml":2606:6: Everything <while loop>
    │ │ ├─"test/test_expect_test.ml":2606:64: Everything else:test_expect_test:2606
    │ │ ├─(WARNING: 2 i= 5)
    │ │ ├─"test/test_expect_test.ml":2609:11: Everything fun:test_expect_test:2609
    │ │ └─(INFO: 3 j= 15)
    │ └─"test/test_expect_test.ml":2606:6: Everything <while loop>
    │   ├─"test/test_expect_test.ml":2606:64: Everything else:test_expect_test:2606
    │   ├─(WARNING: 2 i= 6)
    │   ├─"test/test_expect_test.ml":2609:11: Everything fun:test_expect_test:2609
    │   └─(INFO: 3 j= 21)
    └─result = 21
    21
    21

    BEGIN DEBUG SESSION Error
    result = 21
    ├─"test/test_expect_test.ml":2601:27
    └─Error while:test_expect_test:2604
      ├─"test/test_expect_test.ml":2604:4
      ├─Error <while loop>
      │ ├─"test/test_expect_test.ml":2606:6
      │ ├─Error then:test_expect_test:2606
      │ │ ├─"test/test_expect_test.ml":2606:21
      │ │ └─(ERROR: 1 i= 0)
      │ ├─(WARNING: 2 i= 1)
      │ ├─Error fun:test_expect_test:2609
      │ │ └─"test/test_expect_test.ml":2609:11
      │ └─(INFO: 3 j= 1)
      ├─Error <while loop>
      │ ├─"test/test_expect_test.ml":2606:6
      │ ├─Error then:test_expect_test:2606
      │ │ ├─"test/test_expect_test.ml":2606:21
      │ │ └─(ERROR: 1 i= 1)
      │ ├─(WARNING: 2 i= 2)
      │ ├─Error fun:test_expect_test:2609
      │ │ └─"test/test_expect_test.ml":2609:11
      │ └─(INFO: 3 j= 3)
      ├─Error <while loop>
      │ ├─"test/test_expect_test.ml":2606:6
      │ ├─Error else:test_expect_test:2606
      │ │ └─"test/test_expect_test.ml":2606:64
      │ ├─(WARNING: 2 i= 3)
      │ ├─Error fun:test_expect_test:2609
      │ │ └─"test/test_expect_test.ml":2609:11
      │ └─(INFO: 3 j= 6)
      ├─Error <while loop>
      │ ├─"test/test_expect_test.ml":2606:6
      │ ├─Error else:test_expect_test:2606
      │ │ └─"test/test_expect_test.ml":2606:64
      │ ├─(WARNING: 2 i= 4)
      │ ├─Error fun:test_expect_test:2609
      │ │ └─"test/test_expect_test.ml":2609:11
      │ └─(INFO: 3 j= 10)
      ├─Error <while loop>
      │ ├─"test/test_expect_test.ml":2606:6
      │ ├─Error else:test_expect_test:2606
      │ │ └─"test/test_expect_test.ml":2606:64
      │ ├─(WARNING: 2 i= 5)
      │ ├─Error fun:test_expect_test:2609
      │ │ └─"test/test_expect_test.ml":2609:11
      │ └─(INFO: 3 j= 15)
      └─Error <while loop>
        ├─"test/test_expect_test.ml":2606:6
        ├─Error else:test_expect_test:2606
        │ └─"test/test_expect_test.ml":2606:64
        ├─(WARNING: 2 i= 6)
        ├─Error fun:test_expect_test:2609
        │ └─"test/test_expect_test.ml":2609:11
        └─(INFO: 3 j= 21)
    21

    BEGIN DEBUG SESSION Warning
    result = 21
    ├─"test/test_expect_test.ml":2601:27
    └─Warning while:test_expect_test:2604
      ├─"test/test_expect_test.ml":2604:4
      ├─Warning <while loop>
      │ ├─"test/test_expect_test.ml":2606:6
      │ ├─Warning then:test_expect_test:2606
      │ │ ├─"test/test_expect_test.ml":2606:21
      │ │ └─(ERROR: 1 i= 0)
      │ ├─(WARNING: 2 i= 1)
      │ ├─Warning fun:test_expect_test:2609
      │ │ └─"test/test_expect_test.ml":2609:11
      │ └─(INFO: 3 j= 1)
      ├─Warning <while loop>
      │ ├─"test/test_expect_test.ml":2606:6
      │ ├─Warning then:test_expect_test:2606
      │ │ ├─"test/test_expect_test.ml":2606:21
      │ │ └─(ERROR: 1 i= 1)
      │ ├─(WARNING: 2 i= 2)
      │ ├─Warning fun:test_expect_test:2609
      │ │ └─"test/test_expect_test.ml":2609:11
      │ └─(INFO: 3 j= 3)
      ├─Warning <while loop>
      │ ├─"test/test_expect_test.ml":2606:6
      │ ├─Warning else:test_expect_test:2606
      │ │ └─"test/test_expect_test.ml":2606:64
      │ ├─(WARNING: 2 i= 3)
      │ ├─Warning fun:test_expect_test:2609
      │ │ └─"test/test_expect_test.ml":2609:11
      │ └─(INFO: 3 j= 6)
      ├─Warning <while loop>
      │ ├─"test/test_expect_test.ml":2606:6
      │ ├─Warning else:test_expect_test:2606
      │ │ └─"test/test_expect_test.ml":2606:64
      │ ├─(WARNING: 2 i= 4)
      │ ├─Warning fun:test_expect_test:2609
      │ │ └─"test/test_expect_test.ml":2609:11
      │ └─(INFO: 3 j= 10)
      ├─Warning <while loop>
      │ ├─"test/test_expect_test.ml":2606:6
      │ ├─Warning else:test_expect_test:2606
      │ │ └─"test/test_expect_test.ml":2606:64
      │ ├─(WARNING: 2 i= 5)
      │ ├─Warning fun:test_expect_test:2609
      │ │ └─"test/test_expect_test.ml":2609:11
      │ └─(INFO: 3 j= 15)
      └─Warning <while loop>
        ├─"test/test_expect_test.ml":2606:6
        ├─Warning else:test_expect_test:2606
        │ └─"test/test_expect_test.ml":2606:64
        ├─(WARNING: 2 i= 6)
        ├─Warning fun:test_expect_test:2609
        │ └─"test/test_expect_test.ml":2609:11
        └─(INFO: 3 j= 21)
    21
    |}]

*)

(*
let%expect_test "%log compile time log levels while-loop" =
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file in
    fun () -> rt
  in
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
    ├─"test/test_expect_test.ml":2799:28
    └─while:test_expect_test:2804
      ├─"test/test_expect_test.ml":2804:6
      ├─<while loop>
      │ ├─"test/test_expect_test.ml":2806:8
      │ ├─then:test_expect_test:2806
      │ │ ├─"test/test_expect_test.ml":2806:23
      │ │ └─(ERROR: 1 i= 0)
      │ ├─(WARNING: 2 i= 1)
      │ ├─fun:test_expect_test:2809
      │ │ └─"test/test_expect_test.ml":2809:13
      │ └─(INFO: 3 j= 1)
      ├─<while loop>
      │ ├─"test/test_expect_test.ml":2806:8
      │ ├─then:test_expect_test:2806
      │ │ ├─"test/test_expect_test.ml":2806:23
      │ │ └─(ERROR: 1 i= 1)
      │ ├─(WARNING: 2 i= 2)
      │ ├─fun:test_expect_test:2809
      │ │ └─"test/test_expect_test.ml":2809:13
      │ └─(INFO: 3 j= 3)
      ├─<while loop>
      │ ├─"test/test_expect_test.ml":2806:8
      │ ├─else:test_expect_test:2806
      │ │ └─"test/test_expect_test.ml":2806:66
      │ ├─(WARNING: 2 i= 3)
      │ ├─fun:test_expect_test:2809
      │ │ └─"test/test_expect_test.ml":2809:13
      │ └─(INFO: 3 j= 6)
      ├─<while loop>
      │ ├─"test/test_expect_test.ml":2806:8
      │ ├─else:test_expect_test:2806
      │ │ └─"test/test_expect_test.ml":2806:66
      │ ├─(WARNING: 2 i= 4)
      │ ├─fun:test_expect_test:2809
      │ │ └─"test/test_expect_test.ml":2809:13
      │ └─(INFO: 3 j= 10)
      ├─<while loop>
      │ ├─"test/test_expect_test.ml":2806:8
      │ ├─else:test_expect_test:2806
      │ │ └─"test/test_expect_test.ml":2806:66
      │ ├─(WARNING: 2 i= 5)
      │ ├─fun:test_expect_test:2809
      │ │ └─"test/test_expect_test.ml":2809:13
      │ └─(INFO: 3 j= 15)
      └─<while loop>
        ├─"test/test_expect_test.ml":2806:8
        ├─else:test_expect_test:2806
        │ └─"test/test_expect_test.ml":2806:66
        ├─(WARNING: 2 i= 6)
        ├─fun:test_expect_test:2809
        │ └─"test/test_expect_test.ml":2809:13
        └─(INFO: 3 j= 21)
    21
    nothing = 21
    └─"test/test_expect_test.ml":2814:25
    21
    warning = 21
    ├─"test/test_expect_test.ml":2830:25
    └─while:test_expect_test:2835
      ├─"test/test_expect_test.ml":2835:6
      ├─<while loop>
      │ ├─"test/test_expect_test.ml":2837:8
      │ ├─(ERROR: 1 i= 0)
      │ └─(WARNING: 2 i= 1)
      ├─<while loop>
      │ ├─"test/test_expect_test.ml":2837:8
      │ ├─(ERROR: 1 i= 1)
      │ └─(WARNING: 2 i= 2)
      ├─<while loop>
      │ ├─"test/test_expect_test.ml":2837:8
      │ └─(WARNING: 2 i= 3)
      ├─<while loop>
      │ ├─"test/test_expect_test.ml":2837:8
      │ └─(WARNING: 2 i= 4)
      ├─<while loop>
      │ ├─"test/test_expect_test.ml":2837:8
      │ └─(WARNING: 2 i= 5)
      └─<while loop>
        ├─"test/test_expect_test.ml":2837:8
        └─(WARNING: 2 i= 6)
    21
    |}]

*)

(*
let%expect_test "%log compile time log levels runtime-passing while-loop" =
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file ~run_name:"TOPLEVEL" db_file in
    fun () -> rt
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
            Minidebug_runtime.(forget_printbox @@ debug ~run_name:"nothing" ())
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
           Minidebug_runtime.(forget_printbox @@ debug ~run_name:"warning" ())
           ()]
  in
  [%expect
    {|
    BEGIN DEBUG SESSION TOPLEVEL

    BEGIN DEBUG SESSION nothing
    21

    BEGIN DEBUG SESSION warning
    warning = 21
    ├─"test/test_expect_test.ml":2966:32
    └─warning while:test_expect_test:2969
      ├─"test/test_expect_test.ml":2969:8
      ├─warning <while loop>
      │ └─"test/test_expect_test.ml":2971:10
      ├─warning <while loop>
      │ └─"test/test_expect_test.ml":2971:10
      ├─warning <while loop>
      │ └─"test/test_expect_test.ml":2971:10
      ├─warning <while loop>
      │ └─"test/test_expect_test.ml":2971:10
      ├─warning <while loop>
      │ └─"test/test_expect_test.ml":2971:10
      └─warning <while loop>
        └─"test/test_expect_test.ml":2971:10
    21
    TOPLEVEL ()
    ├─"test/test_expect_test.ml":2944:17
    ├─(ERROR: 1 i= 0)
    ├─(WARNING: 2 i= 1)
    ├─(ERROR: 1 i= 1)
    ├─(WARNING: 2 i= 2)
    ├─(WARNING: 2 i= 3)
    ├─(WARNING: 2 i= 4)
    ├─(WARNING: 2 i= 5)
    └─(WARNING: 2 i= 6)
    |}]

*)

(*
let%expect_test "%log track while-loop result" =
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file in
    fun () -> rt
  in
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
    ├─"test/test_expect_test.ml":3025:17
    └─while:test_expect_test:3028
      ├─"test/test_expect_test.ml":3028:4
      ├─(3 j= 1)
      │ ├─"test/test_expect_test.ml":3029:6
      │ ├─<while loop>
      │ ├─(1 i= 0)
      │ └─(2 i= 1)
      ├─(3 j= 3)
      │ ├─"test/test_expect_test.ml":3029:6
      │ ├─<while loop>
      │ ├─(1 i= 1)
      │ └─(2 i= 2)
      ├─(3 j= 6)
      │ ├─"test/test_expect_test.ml":3029:6
      │ ├─<while loop>
      │ ├─(1 i= 2)
      │ └─(2 i= 3)
      ├─(3 j= 10)
      │ ├─"test/test_expect_test.ml":3029:6
      │ ├─<while loop>
      │ ├─(1 i= 3)
      │ └─(2 i= 4)
      ├─(3 j= 15)
      │ ├─"test/test_expect_test.ml":3029:6
      │ ├─<while loop>
      │ ├─(1 i= 4)
      │ └─(2 i= 5)
      └─(3 j= 21)
        ├─"test/test_expect_test.ml":3029:6
        ├─<while loop>
        ├─(1 i= 5)
        └─(2 i= 6)
    21
    |}]

*)

(*
let%expect_test "%log without scope" =
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file ~values_first_mode:false ~print_entry_ids:true db_file in
    fun () -> rt
  in
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
    "test/test_expect_test.ml":3090:17: _bar {#1}
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

*)

(*
let%expect_test "%log without scope values_first_mode" =
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file ~print_entry_ids:true db_file in
    fun () -> rt
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
    └─"test/test_expect_test.ml":3125:17 {#1}
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

*)

(*
let%expect_test "%log with print_entry_ids, mixed up scopes" =
  (* $MDX part-begin=log_with_print_entry_ids_mixed_up_scopes *)
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file ~print_entry_ids:true db_file in
    fun () -> rt
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
    └─"test/test_expect_test.ml":3163:21 {#1}
    baz = ()
    └─"test/test_expect_test.ml":3170:21 {#2}
    bar = ()
    └─"test/test_expect_test.ml":3163:21 {#3}
    _foobar = ()
    ├─"test/test_expect_test.ml":3182:17 {#4}
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
(* $MDX part-end *)

*)

(*
let%expect_test "%log with print_entry_ids, verbose_entry_ids in HTML, values_first_mode"
    =
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file ~print_entry_ids:true ~verbose_entry_ids:true
      ~backend:(`Html PrintBox_html.Config.default) db_file in
    fun () -> rt
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
    <div><div><table class="non-framed"><tr><td><a id="1"></a></td><td><pre style="font-family: monospace">{#1} bar = ()</pre></td></tr></table><ul><li><table class="non-framed"><tr><td><div>&quot;test/test_expect_test.ml&quot;:3224:21</div></td><td><div><a href="#1"><div>{#1}</div></a></div></td></tr></table></li></ul></div></div>

    <div><div><table class="non-framed"><tr><td><a id="2"></a></td><td><pre style="font-family: monospace">{#2} baz = ()</pre></td></tr></table><ul><li><table class="non-framed"><tr><td><div>&quot;test/test_expect_test.ml&quot;:3231:21</div></td><td><div><a href="#2"><div>{#2}</div></a></div></td></tr></table></li></ul></div></div>

    <div><div><table class="non-framed"><tr><td><a id="3"></a></td><td><pre style="font-family: monospace">{#3} bar = ()</pre></td></tr></table><ul><li><table class="non-framed"><tr><td><div>&quot;test/test_expect_test.ml&quot;:3224:21</div></td><td><div><a href="#3"><div>{#3}</div></a></div></td></tr></table></li></ul></div></div>

    <div><div><table class="non-framed"><tr><td><a id="4"></a></td><td><pre style="font-family: monospace">{#4} _foobar = ()</pre></td></tr></table><ul><li><table class="non-framed"><tr><td><div>&quot;test/test_expect_test.ml&quot;:3243:17</div></td><td><div><a href="#4"><div>{#4}</div></a></div></td></tr></table></li><li><pre style="font-family: monospace">{#3} (&quot;This is like&quot;, 3, &quot;or&quot;, 3.14, &quot;above&quot;)</pre></li><li><pre style="font-family: monospace">{#3} (&quot;tau =&quot;, 6.28)</pre></li><li><pre style="font-family: monospace">{#2} [3; 1; 2; 3]</pre></li><li><pre style="font-family: monospace">{#2} [3; 1; 2; 3]</pre></li><li><pre style="font-family: monospace">{#1} (&quot;This is like&quot;, 3, &quot;or&quot;, 3.14, &quot;above&quot;)</pre></li><li><pre style="font-family: monospace">{#1} (&quot;tau =&quot;, 6.28)</pre></li></ul></div></div>

    <div><div><table class="non-framed"><tr><td><div></div></td><td><pre style="font-family: monospace">{#2} [3; 1; 2; 3]</pre></td></tr></table><ul><li><div>{orphaned from #2}</div></li></ul></div></div>

    <div><div><table class="non-framed"><tr><td><div></div></td><td><pre style="font-family: monospace">{#2} [3; 1; 2; 3]</pre></td></tr></table><ul><li><div>{orphaned from #2}</div></li></ul></div></div>

    <div><div><table class="non-framed"><tr><td><div></div></td><td><pre style="font-family: monospace">{#1} (&quot;This is like&quot;, 3, &quot;or&quot;, 3.14, &quot;above&quot;)</pre></td></tr></table><ul><li><div>{orphaned from #1}</div></li></ul></div></div>

    <div><div><table class="non-framed"><tr><td><div></div></td><td><pre style="font-family: monospace">{#1} (&quot;tau =&quot;, 6.28)</pre></td></tr></table><ul><li><div>{orphaned from #1}</div></li></ul></div></div>
    |}]

*)

(*
let%expect_test "%diagn_show ignores type annots" =
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file in
    fun () -> rt
  in
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
    ├─"test/test_expect_test.ml":3267:17
    ├─("for bar, b-3", 42)
    └─("for baz, f squared", 64)
    |}]

*)

(*
let%expect_test "%diagn_show ignores non-empty bindings" =
  (* $MDX part-begin=diagn_show_ignores_bindings *)
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file in
    fun () -> rt
  in
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
    ├─"test/test_expect_test.ml":3297:21
    └─("for bar, b-3", 42)
    336
    baz
    ├─"test/test_expect_test.ml":3304:21
    └─("foo baz, f squared", 49)
    91
    |}]
(* $MDX part-end *)

*)

(*
let%expect_test "%diagn_show no logs" =
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file in
    fun () -> rt
  in
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

*)

(*
let%expect_test "%debug_show log level compile time" =
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file in
    fun () -> rt
  in
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
    ├─"test/test_expect_test.ml":3347:18
    └─baz = 109
      ├─"test/test_expect_test.ml":3362:26
      ├─first = 7
      ├─second = 42
      ├─{first; second}
      │ ├─"test/test_expect_test.ml":3363:12
      │ └─<values>
      │   ├─first = 8
      │   └─second = 45
      └─("for baz, f squared", 64)
    |}]

*)

(*
let%expect_test "%debug_show log level runtime" =
  (* $MDX part-begin=debug_show_log_level_runtime *)
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file ~log_level:2 db_file in
    fun () -> rt
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
    336
    baz = 109
    ├─"test/test_expect_test.ml":3407:24
    ├─first = 7
    ├─second = 42
    ├─{first; second}
    │ ├─"test/test_expect_test.ml":3408:10
    │ └─<values>
    │   ├─first = 8
    │   └─second = 45
    └─("for baz, f squared", 64)
    109
    |}]
(* $MDX part-end *)

*)

(*
let%expect_test "%debug_show PrintBox snapshot" =
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file in
    fun () -> rt
  in
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
    ├─"test/test_expect_test.ml":3437:36
    ├─x = 7
    └─z = 3
      └─"test/test_expect_test.ml":3438:8
    [2J[1;1Hloop_highlight
    ├─"test/test_expect_test.ml":3437:36
    ├─x = 7
    ├─z = 3
    │ └─"test/test_expect_test.ml":3438:8
    └─loop_highlight
      ├─"test/test_expect_test.ml":3437:36
      ├─x = 6
      ├─z = 2
      │ └─"test/test_expect_test.ml":3438:8
      └─loop_highlight
        ├─"test/test_expect_test.ml":3437:36
        ├─x = 5
        ├─z = 2
        │ └─"test/test_expect_test.ml":3438:8
        └─loop_highlight
          ├─"test/test_expect_test.ml":3437:36
          ├─x = 4
          ├─z = 1
          │ └─"test/test_expect_test.ml":3438:8
          └─loop_highlight
            ├─"test/test_expect_test.ml":3437:36
            ├─x = 3
            └─z = 1
              └─"test/test_expect_test.ml":3438:8
    [2J[1;1Hloop_highlight = 9
    ├─"test/test_expect_test.ml":3437:36
    ├─x = 7
    ├─z = 3
    │ └─"test/test_expect_test.ml":3438:8
    └─loop_highlight = 6
      ├─"test/test_expect_test.ml":3437:36
      ├─x = 6
      ├─z = 2
      │ └─"test/test_expect_test.ml":3438:8
      └─loop_highlight = 4
        ├─"test/test_expect_test.ml":3437:36
        ├─x = 5
        ├─z = 2
        │ └─"test/test_expect_test.ml":3438:8
        └─loop_highlight = 2
          ├─"test/test_expect_test.ml":3437:36
          ├─x = 4
          ├─z = 1
          │ └─"test/test_expect_test.ml":3438:8
          └─loop_highlight = 1
            ├─"test/test_expect_test.ml":3437:36
            ├─x = 3
            ├─z = 1
            │ └─"test/test_expect_test.ml":3438:8
            └─loop_highlight = 0
              ├─"test/test_expect_test.ml":3437:36
              ├─x = 2
              ├─z = 0
              │ └─"test/test_expect_test.ml":3438:8
              └─loop_highlight = 0
                ├─"test/test_expect_test.ml":3437:36
                ├─x = 1
                ├─z = 0
                │ └─"test/test_expect_test.ml":3438:8
                └─loop_highlight = 0
                  ├─"test/test_expect_test.ml":3437:36
                  ├─x = 0
                  └─z = 0
                    └─"test/test_expect_test.ml":3438:8
    9
    |}]

*)

(*
let%expect_test "%track_show don't show unannotated non-function bindings" =
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file ~log_level:3 db_file in
    fun () -> rt
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

*)

(*
let%expect_test "%log_printbox" =
  (* $MDX part-begin=log_printbox *)
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file in
    fun () -> rt
  in
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
    ├─"test/test_expect_test.ml":3536:21
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
(* $MDX part-end *)

*)

(*
let%expect_test "%log_printbox flushing" =
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file in
    fun () -> rt
  in
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
    foo begin "test/test_expect_test.ml":3599:21:
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
     bar begin "test/test_expect_test.ml":3608:12:
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

*)

(*
let%expect_test "%log_entry" =
  (* $MDX part-begin=log_entry *)
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file ~values_first_mode:false db_file in
    fun () -> rt
  in
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
    "test/test_expect_test.ml":3671:17: _logging_logic
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
(* $MDX part-end *)

*)

(*
let%expect_test "flame graph" =
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file ~values_first_mode:false ~hyperlink:"../"
      ~toc_specific_hyperlink:"./" ~toc_flame_graph:true
      ~backend:(`Html PrintBox_html.Config.(tree_summary true default))
      "test_expect_test_flame_graph" in
    fun () -> rt
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
                    <div style="position: relative; height: 0px;"><div style="position: relative; top: 0%; width: 100%; height: 100%;"><div style="position: relative; top: 0px; left: 0px; width: 100%; background: #a3b8d2;"><div><div><a href="./test_expect_test_flame_graph.html#1"><div>&quot;test/test_expect_test.ml&quot;:3730:26: loop</div></a></div></div>
    </div><div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0%; width: 100%; height: 100%;"><div style="position: relative; top: 0px; left: 0px; width: 100%; background: #a7a1eb;"><div><div><a href="./test_expect_test_flame_graph.html#2"><div>&quot;test/test_expect_test.ml&quot;:3734:10: y</div></a></div></div>
    </div><div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0%; width: 100%; height: 100%;"><div style="position: relative; top: 0px; left: 0px; width: 100%; background: #b88f91;"><div><div><a href="./test_expect_test_flame_graph.html#3"><div>&quot;test/test_expect_test.ml&quot;:3730:26: loop</div></a></div></div>
    </div><div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0%; width: 100%; height: 100%;"><div style="position: relative; top: 0px; left: 0px; width: 100%; background: #bfadb3;"><div><div><a href="./test_expect_test_flame_graph.html#4"><div>&quot;test/test_expect_test.ml&quot;:3734:10: y</div></a></div></div>
    </div><div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0%; width: 100%; height: 100%;"><div style="position: relative; top: 0px; left: 0px; width: 100%; background: #c5c7ed;"><div><div><a href="./test_expect_test_flame_graph.html#5"><div>&quot;test/test_expect_test.ml&quot;:3730:26: loop</div></a></div></div>
    </div><div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0%; width: 100%; height: 100%;"><div style="position: relative; top: 0px; left: 0px; width: 100%; background: #ebdf9d;"><div><div><a href="./test_expect_test_flame_graph.html#6"><div>&quot;test/test_expect_test.ml&quot;:3730:26: loop</div></a></div></div>
    </div><div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0%; width: 100%; height: 100%;"><div style="position: relative; top: 0px; left: 0px; width: 100%; background: #bfbbe7;"><div><div><a href="./test_expect_test_flame_graph.html#7"><div>&quot;test/test_expect_test.ml&quot;:3730:26: loop</div></a></div></div>
    </div><div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0px; left: 0px; width: 100%; background: #ebebd3;"><div><div><a href="./test_expect_test_flame_graph.html#8"><div>&quot;test/test_expect_test.ml&quot;:3730:26: loop</div></a></div></div>
    </div></div>
           </div></div>
           </div></div>
           </div></div>
           </div></div>
           <div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0%; width: 100%; height: 100%;"><div style="position: relative; top: 0px; left: 0px; width: 100%; background: #9994b2;"><div><div><a href="./test_expect_test_flame_graph.html#9"><div>&quot;test/test_expect_test.ml&quot;:3735:10: z</div></a></div></div>
    </div><div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0%; width: 100%; height: 100%;"><div style="position: relative; top: 0px; left: 0px; width: 100%; background: #c4efdd;"><div><div><a href="./test_expect_test_flame_graph.html#10"><div>&quot;test/test_expect_test.ml&quot;:3730:26: loop</div></a></div></div>
    </div><div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0%; width: 100%; height: 100%;"><div style="position: relative; top: 0px; left: 0px; width: 100%; background: #d8eeca;"><div><div><a href="./test_expect_test_flame_graph.html#11"><div>&quot;test/test_expect_test.ml&quot;:3730:26: loop</div></a></div></div>
    </div><div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0%; width: 100%; height: 100%;"><div style="position: relative; top: 0px; left: 0px; width: 100%; background: #bea2e0;"><div><div><a href="./test_expect_test_flame_graph.html#12"><div>&quot;test/test_expect_test.ml&quot;:3730:26: loop</div></a></div></div>
    </div><div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0px; left: 0px; width: 100%; background: #9192c4;"><div><div><a href="./test_expect_test_flame_graph.html#13"><div>&quot;test/test_expect_test.ml&quot;:3730:26: loop</div></a></div></div>
    </div></div>
           </div></div>
           </div></div>
           </div></div>
           </div></div>
           </div></div>
           </div></div>
           <div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0%; width: 100%; height: 100%;"><div style="position: relative; top: 0px; left: 0px; width: 100%; background: #bb8f91;"><div><div><a href="./test_expect_test_flame_graph.html#14"><div>&quot;test/test_expect_test.ml&quot;:3735:10: z</div></a></div></div>
    </div><div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0%; width: 100%; height: 100%;"><div style="position: relative; top: 0px; left: 0px; width: 100%; background: #bd8fef;"><div><div><a href="./test_expect_test_flame_graph.html#15"><div>&quot;test/test_expect_test.ml&quot;:3730:26: loop</div></a></div></div>
    </div><div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0%; width: 100%; height: 100%;"><div style="position: relative; top: 0px; left: 0px; width: 100%; background: #d7decc;"><div><div><a href="./test_expect_test_flame_graph.html#16"><div>&quot;test/test_expect_test.ml&quot;:3734:10: y</div></a></div></div>
    </div><div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0%; width: 100%; height: 100%;"><div style="position: relative; top: 0px; left: 0px; width: 100%; background: #9fbbbd;"><div><div><a href="./test_expect_test_flame_graph.html#17"><div>&quot;test/test_expect_test.ml&quot;:3730:26: loop</div></a></div></div>
    </div><div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0%; width: 100%; height: 100%;"><div style="position: relative; top: 0px; left: 0px; width: 100%; background: #e2e7d3;"><div><div><a href="./test_expect_test_flame_graph.html#18"><div>&quot;test/test_expect_test.ml&quot;:3730:26: loop</div></a></div></div>
    </div><div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0%; width: 100%; height: 100%;"><div style="position: relative; top: 0px; left: 0px; width: 100%; background: #a0b0f0;"><div><div><a href="./test_expect_test_flame_graph.html#19"><div>&quot;test/test_expect_test.ml&quot;:3730:26: loop</div></a></div></div>
    </div><div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0px; left: 0px; width: 100%; background: #a39abc;"><div><div><a href="./test_expect_test_flame_graph.html#20"><div>&quot;test/test_expect_test.ml&quot;:3730:26: loop</div></a></div></div>
    </div></div>
           </div></div>
           </div></div>
           </div></div>
           </div></div>
           <div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0%; width: 100%; height: 100%;"><div style="position: relative; top: 0px; left: 0px; width: 100%; background: #b1a1b5;"><div><div><a href="./test_expect_test_flame_graph.html#21"><div>&quot;test/test_expect_test.ml&quot;:3735:10: z</div></a></div></div>
    </div><div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0%; width: 100%; height: 100%;"><div style="position: relative; top: 0px; left: 0px; width: 100%; background: #d7efa5;"><div><div><a href="./test_expect_test_flame_graph.html#22"><div>&quot;test/test_expect_test.ml&quot;:3730:26: loop</div></a></div></div>
    </div><div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0%; width: 100%; height: 100%;"><div style="position: relative; top: 0px; left: 0px; width: 100%; background: #f1e7a3;"><div><div><a href="./test_expect_test_flame_graph.html#23"><div>&quot;test/test_expect_test.ml&quot;:3730:26: loop</div></a></div></div>
    </div><div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0%; width: 100%; height: 100%;"><div style="position: relative; top: 0px; left: 0px; width: 100%; background: #9295dd;"><div><div><a href="./test_expect_test_flame_graph.html#24"><div>&quot;test/test_expect_test.ml&quot;:3730:26: loop</div></a></div></div>
    </div><div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0px; left: 0px; width: 100%; background: #d6dcaa;"><div><div><a href="./test_expect_test_flame_graph.html#25"><div>&quot;test/test_expect_test.ml&quot;:3730:26: loop</div></a></div></div>
    </div></div>
           </div></div>
           </div></div>
           </div></div>
           </div></div>
           </div></div>
           </div></div>
           </div></div><div style="height: 320px;"></div>
    |}]

*)

(*
let%expect_test "flame graph reduced ToC" =
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file ~values_first_mode:false ~hyperlink:"../"
      ~toc_specific_hyperlink:"./" ~toc_flame_graph:true
      ~toc_entry:(Minidebug_runtime.Minimal_depth 1)
      ~backend:(`Html PrintBox_html.Config.(tree_summary true default))
      "test_expect_test_flame_graph" in
    fun () -> rt
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
                    <div style="position: relative; height: 0px;"><div style="position: relative; top: 0%; width: 100%; height: 100%;"><div style="position: relative; top: 0px; left: 0px; width: 100%; background: #d7efa5;"><div><div><a href="./test_expect_test_flame_graph.html#1"><div>&quot;test/test_expect_test.ml&quot;:3835:26: loop</div></a></div></div>
    </div><div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0%; width: 100%; height: 100%;"><div style="position: relative; top: 0px; left: 0px; width: 100%; background: #9994b2;"><div><div><a href="./test_expect_test_flame_graph.html#2"><div>&quot;test/test_expect_test.ml&quot;:3839:10: y</div></a></div></div>
    </div><div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0%; width: 100%; height: 100%;"><div style="position: relative; top: 0px; left: 0px; width: 100%; background: #c4efdd;"><div><div><a href="./test_expect_test_flame_graph.html#3"><div>&quot;test/test_expect_test.ml&quot;:3835:26: loop</div></a></div></div>
    </div><div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0%; width: 100%; height: 100%;"><div style="position: relative; top: 0px; left: 0px; width: 100%; background: #c5c7ed;"><div><div><a href="./test_expect_test_flame_graph.html#4"><div>&quot;test/test_expect_test.ml&quot;:3839:10: y</div></a></div></div>
    </div><div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0%; width: 100%; height: 100%;"><div style="position: relative; top: 0px; left: 0px; width: 100%; background: #ebdf9d;"><div><div><a href="./test_expect_test_flame_graph.html#5"><div>&quot;test/test_expect_test.ml&quot;:3835:26: loop</div></a></div></div>
    </div><div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0%; width: 100%; height: 100%;"><div style="position: relative; top: 0px; left: 0px; width: 100%; background: #bfbbe7;"><div><div><a href="./test_expect_test_flame_graph.html#6"><div>&quot;test/test_expect_test.ml&quot;:3835:26: loop</div></a></div></div>
    </div><div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0px; left: 0px; width: 100%; background: #ebebd3;"><div><div><a href="./test_expect_test_flame_graph.html#7"><div>&quot;test/test_expect_test.ml&quot;:3835:26: loop</div></a></div></div>
    </div></div>
           </div></div>
           </div></div>
           </div></div>
           <div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0%; width: 100%; height: 100%;"><div style="position: relative; top: 0px; left: 0px; width: 100%; background: #d8eeca;"><div><div><a href="./test_expect_test_flame_graph.html#9"><div>&quot;test/test_expect_test.ml&quot;:3840:10: z</div></a></div></div>
    </div><div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0%; width: 100%; height: 100%;"><div style="position: relative; top: 0px; left: 0px; width: 100%; background: #bea2e0;"><div><div><a href="./test_expect_test_flame_graph.html#10"><div>&quot;test/test_expect_test.ml&quot;:3835:26: loop</div></a></div></div>
    </div><div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0%; width: 100%; height: 100%;"><div style="position: relative; top: 0px; left: 0px; width: 100%; background: #9192c4;"><div><div><a href="./test_expect_test_flame_graph.html#11"><div>&quot;test/test_expect_test.ml&quot;:3835:26: loop</div></a></div></div>
    </div><div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0px; left: 0px; width: 100%; background: #bfadb3;"><div><div><a href="./test_expect_test_flame_graph.html#12"><div>&quot;test/test_expect_test.ml&quot;:3835:26: loop</div></a></div></div>
    </div></div>
           </div></div>
           </div></div>
           </div></div>
           </div></div>
           </div></div>
           <div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0%; width: 100%; height: 100%;"><div style="position: relative; top: 0px; left: 0px; width: 100%; background: #f1e7a3;"><div><div><a href="./test_expect_test_flame_graph.html#14"><div>&quot;test/test_expect_test.ml&quot;:3840:10: z</div></a></div></div>
    </div><div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0%; width: 100%; height: 100%;"><div style="position: relative; top: 0px; left: 0px; width: 100%; background: #9295dd;"><div><div><a href="./test_expect_test_flame_graph.html#15"><div>&quot;test/test_expect_test.ml&quot;:3835:26: loop</div></a></div></div>
    </div><div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0%; width: 100%; height: 100%;"><div style="position: relative; top: 0px; left: 0px; width: 100%; background: #a0b0f0;"><div><div><a href="./test_expect_test_flame_graph.html#16"><div>&quot;test/test_expect_test.ml&quot;:3839:10: y</div></a></div></div>
    </div><div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0%; width: 100%; height: 100%;"><div style="position: relative; top: 0px; left: 0px; width: 100%; background: #a39abc;"><div><div><a href="./test_expect_test_flame_graph.html#17"><div>&quot;test/test_expect_test.ml&quot;:3835:26: loop</div></a></div></div>
    </div><div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0%; width: 100%; height: 100%;"><div style="position: relative; top: 0px; left: 0px; width: 100%; background: #a7a1eb;"><div><div><a href="./test_expect_test_flame_graph.html#18"><div>&quot;test/test_expect_test.ml&quot;:3835:26: loop</div></a></div></div>
    </div><div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0px; left: 0px; width: 100%; background: #b88f91;"><div><div><a href="./test_expect_test_flame_graph.html#19"><div>&quot;test/test_expect_test.ml&quot;:3835:26: loop</div></a></div></div>
    </div></div>
           </div></div>
           </div></div>
           </div></div>
           <div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0%; width: 100%; height: 100%;"><div style="position: relative; top: 0px; left: 0px; width: 100%; background: #d6dcaa;"><div><div><a href="./test_expect_test_flame_graph.html#21"><div>&quot;test/test_expect_test.ml&quot;:3840:10: z</div></a></div></div>
    </div><div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0%; width: 100%; height: 100%;"><div style="position: relative; top: 0px; left: 0px; width: 100%; background: #d7decc;"><div><div><a href="./test_expect_test_flame_graph.html#22"><div>&quot;test/test_expect_test.ml&quot;:3835:26: loop</div></a></div></div>
    </div><div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0%; width: 100%; height: 100%;"><div style="position: relative; top: 0px; left: 0px; width: 100%; background: #9fbbbd;"><div><div><a href="./test_expect_test_flame_graph.html#23"><div>&quot;test/test_expect_test.ml&quot;:3835:26: loop</div></a></div></div>
    </div><div style="position: relative; top:10%; height: 90%; left:N.NNNN%; width:N.NNNN%;">
           <div style="position: relative; top: 0px; left: 0px; width: 100%; background: #e2e7d3;"><div><div><a href="./test_expect_test_flame_graph.html#24"><div>&quot;test/test_expect_test.ml&quot;:3835:26: loop</div></a></div></div>
    </div></div>
           </div></div>
           </div></div>
           </div></div>
           </div></div>
           </div></div>
           </div></div><div style="height: 280px;"></div>
    |}]

*)

(*
let%expect_test "%debug_show skip module bindings" =
  let optional v thunk = match v with Some v -> v | None -> thunk () in
  let module Debug_runtime = (val Minidebug_runtime.debug db_file) in
  let%track_o_sexp bar ?(rt : (module Minidebug_runtime.Debug_runtime) option) (x : int) :
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
    ├─"test/test_expect_test.ml":3923:23
    ├─x = 7
    └─y = 8
      └─"test/test_expect_test.ml":3925:8
    15
    |}]

*)

(*
let%expect_test "%track_show procedure runtime prefixes" =
  (* $MDX part-begin=track_show_procedure_runtime_prefixes *)
  let i = ref 0 in
  let _get_local_debug_runtime () =
    let rt = Minidebug_db.debug_db_file ~run_name:("foo-" ^ string_of_int !i) db_file in
    fun () -> rt
  in
  let%track_show foo () =
    let () = () in
    [%log "inside foo"]
  in
  let%track_show bar = function
    | () ->
        let () = () in
        [%log "inside bar"]
  in
  while !i < 3 do
    incr i;
    foo ();
    bar ()
  done;
  [%expect
    {|
    BEGIN DEBUG SESSION foo-1
    foo-1 foo begin "test/test_expect_test.ml":3951:21:
     "inside foo"
    foo-1 foo end

    BEGIN DEBUG SESSION foo-1
    foo-1 <function -- branch 0> () begin "test/test_expect_test.ml":3957:8:
     "inside bar"
    foo-1 <function -- branch 0> () end

    BEGIN DEBUG SESSION foo-2
    foo-2 foo begin "test/test_expect_test.ml":3951:21:
     "inside foo"
    foo-2 foo end

    BEGIN DEBUG SESSION foo-2
    foo-2 <function -- branch 0> () begin "test/test_expect_test.ml":3957:8:
     "inside bar"
    foo-2 <function -- branch 0> () end

    BEGIN DEBUG SESSION foo-3
    foo-3 foo begin "test/test_expect_test.ml":3951:21:
     "inside foo"
    foo-3 foo end

    BEGIN DEBUG SESSION foo-3
    foo-3 <function -- branch 0> () begin "test/test_expect_test.ml":3957:8:
     "inside bar"
    foo-3 <function -- branch 0> () end
    |}]
(* $MDX part-end *)

*)

(*
let%expect_test "%track_rt_show expression runtime passing" =
  [%track_rt_show
    [%log_block
      "test A";
      [%log "line A"]]]
    (Minidebug_db.debug_db_file ~run_name:"t1" db_file);
  [%track_rt_show
    [%log_block
      "test B";
      [%log "line B"]]]
    (Minidebug_db.debug_db_file ~run_name:"t2" db_file);
  [%track_rt_show
    [%log_block
      "test C";
      [%log "line C"]]]
    Minidebug_db.(
      debug_db_file ~values_first_mode:false ~run_name:"t3" ~log_level:0 db_file);
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
    |}]

*)

(*
let%expect_test "%debug_show tuples values_first_mode highlighted" =
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file ~highlight_terms:Re.(alt [ str "339"; str "8" ]) db_file in
    fun () -> rt
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
    ├─"test/test_expect_test.ml":4034:21
    ├─first = 7
    ├─second = 42
    └─┬─────┐
      │y = 8│
      ├─────┘
      └─"test/test_expect_test.ml":4035:8
    336
    ┌────────┐
    │(r1, r2)│
    ├────────┘
    ├─"test/test_expect_test.ml":4044:17
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
      ├─"test/test_expect_test.ml":4039:21
      ├─first = 7
      ├─second = 42
      ├─┬──────┐
      │ │(y, z)│
      │ ├──────┘
      │ ├─"test/test_expect_test.ml":4040:8
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
        ├─"test/test_expect_test.ml":4041:8
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

*)

(*
let%expect_test "%logN_block runtime log levels" =
  (* $MDX part-begin=logN_block *)
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
  (* $MDX part-end *)
  print_endline
  @@ Int.to_string
       (result
          Minidebug_db.(
            debug_db_file ~values_first_mode:false ~run_name:"for=2,with=default" db_file)
          ~for_log_level:2);
  print_endline
  @@ Int.to_string
       (result
          Minidebug_db.(
            debug_db_file ~log_level:0 ~run_name:"for=1,with=0" db_file)
          ~for_log_level:1);
  print_endline
  @@ Int.to_string
       (result
          Minidebug_db.(
            debug_db_file ~log_level:1 ~run_name:"for=2,with=1" db_file)
          ~for_log_level:2);
  print_endline
  @@ Int.to_string
       (result
          Minidebug_db.(
            debug_db_file ~log_level:2 ~run_name:"for=1,with=2" db_file)
          ~for_log_level:1);
  print_endline
  @@ Int.to_string
       (result
          Minidebug_db.(
            debug_db_file ~log_level:3 ~run_name:"for=3,with=3" db_file)
          ~for_log_level:3);
  (* Unlike with other constructs, INFO should not be printed in "for=4,with=3", because
     log_block filters out the whole body by the log level. *)
  print_endline
  @@ Int.to_string
       (result
          Minidebug_db.(
            debug_db_file ~log_level:3 ~run_name:"for=4,with=3" db_file)
          ~for_log_level:4);
  [%expect
    {|
    BEGIN DEBUG SESSION for=2,with=default
    "test/test_expect_test.ml":4106:27: for=2,with=default result
    ├─"test/test_expect_test.ml":4109:4: for=2,with=default while:test_expect_test:4109
    │ ├─"test/test_expect_test.ml":4110:6: for=2,with=default <while loop>
    │ │ └─for=2,with=default i=1
    │ │   ├─"test/test_expect_test.ml":4113:23: for=2,with=default then:test_expect_test:4113
    │ │   │ └─(ERROR: 1 i= 1)
    │ │   ├─(WARNING: 2 i= 1)
    │ │   ├─"test/test_expect_test.ml":4115:13: for=2,with=default fun:test_expect_test:4115
    │ │   └─(INFO: 3 j= 1)
    │ ├─"test/test_expect_test.ml":4110:6: for=2,with=default <while loop>
    │ │ └─for=2,with=default i=2
    │ │   ├─"test/test_expect_test.ml":4113:23: for=2,with=default then:test_expect_test:4113
    │ │   │ └─(ERROR: 1 i= 2)
    │ │   ├─(WARNING: 2 i= 2)
    │ │   ├─"test/test_expect_test.ml":4115:13: for=2,with=default fun:test_expect_test:4115
    │ │   └─(INFO: 3 j= 3)
    │ ├─"test/test_expect_test.ml":4110:6: for=2,with=default <while loop>
    │ │ └─for=2,with=default i=3
    │ │   ├─"test/test_expect_test.ml":4113:65: for=2,with=default else:test_expect_test:4113
    │ │   ├─(WARNING: 2 i= 3)
    │ │   ├─"test/test_expect_test.ml":4115:13: for=2,with=default fun:test_expect_test:4115
    │ │   └─(INFO: 3 j= 6)
    │ ├─"test/test_expect_test.ml":4110:6: for=2,with=default <while loop>
    │ │ └─for=2,with=default i=4
    │ │   ├─"test/test_expect_test.ml":4113:65: for=2,with=default else:test_expect_test:4113
    │ │   ├─(WARNING: 2 i= 4)
    │ │   ├─"test/test_expect_test.ml":4115:13: for=2,with=default fun:test_expect_test:4115
    │ │   └─(INFO: 3 j= 10)
    │ ├─"test/test_expect_test.ml":4110:6: for=2,with=default <while loop>
    │ │ └─for=2,with=default i=5
    │ │   ├─"test/test_expect_test.ml":4113:65: for=2,with=default else:test_expect_test:4113
    │ │   ├─(WARNING: 2 i= 5)
    │ │   ├─"test/test_expect_test.ml":4115:13: for=2,with=default fun:test_expect_test:4115
    │ │   └─(INFO: 3 j= 15)
    │ └─"test/test_expect_test.ml":4110:6: for=2,with=default <while loop>
    │   └─for=2,with=default i=6
    │     ├─"test/test_expect_test.ml":4113:65: for=2,with=default else:test_expect_test:4113
    │     ├─(WARNING: 2 i= 6)
    │     ├─"test/test_expect_test.ml":4115:13: for=2,with=default fun:test_expect_test:4115
    │     └─(INFO: 3 j= 21)
    └─result = 21
    21
    0

    BEGIN DEBUG SESSION for=2,with=1
    result = 0
    ├─"test/test_expect_test.ml":4106:27
    ├─for=2,with=1 result
    └─for=2,with=1 while:test_expect_test:4109
      ├─"test/test_expect_test.ml":4109:4
      ├─for=2,with=1 <while loop>
      │ └─"test/test_expect_test.ml":4110:6
      ├─for=2,with=1 <while loop>
      │ └─"test/test_expect_test.ml":4110:6
      ├─for=2,with=1 <while loop>
      │ └─"test/test_expect_test.ml":4110:6
      ├─for=2,with=1 <while loop>
      │ └─"test/test_expect_test.ml":4110:6
      ├─for=2,with=1 <while loop>
      │ └─"test/test_expect_test.ml":4110:6
      └─for=2,with=1 <while loop>
        └─"test/test_expect_test.ml":4110:6
    0

    BEGIN DEBUG SESSION for=1,with=2
    result = 21
    ├─"test/test_expect_test.ml":4106:27
    ├─for=1,with=2 result
    └─for=1,with=2 while:test_expect_test:4109
      ├─"test/test_expect_test.ml":4109:4
      ├─for=1,with=2 <while loop>
      │ ├─"test/test_expect_test.ml":4110:6
      │ └─for=1,with=2 i=1
      │   ├─for=1,with=2 then:test_expect_test:4113
      │   │ ├─"test/test_expect_test.ml":4113:23
      │   │ └─(ERROR: 1 i= 1)
      │   ├─(WARNING: 2 i= 1)
      │   ├─for=1,with=2 fun:test_expect_test:4115
      │   │ └─"test/test_expect_test.ml":4115:13
      │   └─(INFO: 3 j= 1)
      ├─for=1,with=2 <while loop>
      │ ├─"test/test_expect_test.ml":4110:6
      │ └─for=1,with=2 i=2
      │   ├─for=1,with=2 then:test_expect_test:4113
      │   │ ├─"test/test_expect_test.ml":4113:23
      │   │ └─(ERROR: 1 i= 2)
      │   ├─(WARNING: 2 i= 2)
      │   ├─for=1,with=2 fun:test_expect_test:4115
      │   │ └─"test/test_expect_test.ml":4115:13
      │   └─(INFO: 3 j= 3)
      ├─for=1,with=2 <while loop>
      │ ├─"test/test_expect_test.ml":4110:6
      │ └─for=1,with=2 i=3
      │   ├─for=1,with=2 else:test_expect_test:4113
      │   │ └─"test/test_expect_test.ml":4113:65
      │   ├─(WARNING: 2 i= 3)
      │   ├─for=1,with=2 fun:test_expect_test:4115
      │   │ └─"test/test_expect_test.ml":4115:13
      │   └─(INFO: 3 j= 6)
      ├─for=1,with=2 <while loop>
      │ ├─"test/test_expect_test.ml":4110:6
      │ └─for=1,with=2 i=4
      │   ├─for=1,with=2 else:test_expect_test:4113
      │   │ └─"test/test_expect_test.ml":4113:65
      │   ├─(WARNING: 2 i= 4)
      │   ├─for=1,with=2 fun:test_expect_test:4115
      │   │ └─"test/test_expect_test.ml":4115:13
      │   └─(INFO: 3 j= 10)
      ├─for=1,with=2 <while loop>
      │ ├─"test/test_expect_test.ml":4110:6
      │ └─for=1,with=2 i=5
      │   ├─for=1,with=2 else:test_expect_test:4113
      │   │ └─"test/test_expect_test.ml":4113:65
      │   ├─(WARNING: 2 i= 5)
      │   ├─for=1,with=2 fun:test_expect_test:4115
      │   │ └─"test/test_expect_test.ml":4115:13
      │   └─(INFO: 3 j= 15)
      └─for=1,with=2 <while loop>
        ├─"test/test_expect_test.ml":4110:6
        └─for=1,with=2 i=6
          ├─for=1,with=2 else:test_expect_test:4113
          │ └─"test/test_expect_test.ml":4113:65
          ├─(WARNING: 2 i= 6)
          ├─for=1,with=2 fun:test_expect_test:4115
          │ └─"test/test_expect_test.ml":4115:13
          └─(INFO: 3 j= 21)
    21

    BEGIN DEBUG SESSION for=3,with=3
    result = 21
    ├─"test/test_expect_test.ml":4106:27
    ├─for=3,with=3 result
    └─for=3,with=3 while:test_expect_test:4109
      ├─"test/test_expect_test.ml":4109:4
      ├─for=3,with=3 <while loop>
      │ ├─"test/test_expect_test.ml":4110:6
      │ └─for=3,with=3 i=1
      │   ├─for=3,with=3 then:test_expect_test:4113
      │   │ ├─"test/test_expect_test.ml":4113:23
      │   │ └─(ERROR: 1 i= 1)
      │   ├─(WARNING: 2 i= 1)
      │   ├─for=3,with=3 fun:test_expect_test:4115
      │   │ └─"test/test_expect_test.ml":4115:13
      │   └─(INFO: 3 j= 1)
      ├─for=3,with=3 <while loop>
      │ ├─"test/test_expect_test.ml":4110:6
      │ └─for=3,with=3 i=2
      │   ├─for=3,with=3 then:test_expect_test:4113
      │   │ ├─"test/test_expect_test.ml":4113:23
      │   │ └─(ERROR: 1 i= 2)
      │   ├─(WARNING: 2 i= 2)
      │   ├─for=3,with=3 fun:test_expect_test:4115
      │   │ └─"test/test_expect_test.ml":4115:13
      │   └─(INFO: 3 j= 3)
      ├─for=3,with=3 <while loop>
      │ ├─"test/test_expect_test.ml":4110:6
      │ └─for=3,with=3 i=3
      │   ├─for=3,with=3 else:test_expect_test:4113
      │   │ └─"test/test_expect_test.ml":4113:65
      │   ├─(WARNING: 2 i= 3)
      │   ├─for=3,with=3 fun:test_expect_test:4115
      │   │ └─"test/test_expect_test.ml":4115:13
      │   └─(INFO: 3 j= 6)
      ├─for=3,with=3 <while loop>
      │ ├─"test/test_expect_test.ml":4110:6
      │ └─for=3,with=3 i=4
      │   ├─for=3,with=3 else:test_expect_test:4113
      │   │ └─"test/test_expect_test.ml":4113:65
      │   ├─(WARNING: 2 i= 4)
      │   ├─for=3,with=3 fun:test_expect_test:4115
      │   │ └─"test/test_expect_test.ml":4115:13
      │   └─(INFO: 3 j= 10)
      ├─for=3,with=3 <while loop>
      │ ├─"test/test_expect_test.ml":4110:6
      │ └─for=3,with=3 i=5
      │   ├─for=3,with=3 else:test_expect_test:4113
      │   │ └─"test/test_expect_test.ml":4113:65
      │   ├─(WARNING: 2 i= 5)
      │   ├─for=3,with=3 fun:test_expect_test:4115
      │   │ └─"test/test_expect_test.ml":4115:13
      │   └─(INFO: 3 j= 15)
      └─for=3,with=3 <while loop>
        ├─"test/test_expect_test.ml":4110:6
        └─for=3,with=3 i=6
          ├─for=3,with=3 else:test_expect_test:4113
          │ └─"test/test_expect_test.ml":4113:65
          ├─(WARNING: 2 i= 6)
          ├─for=3,with=3 fun:test_expect_test:4115
          │ └─"test/test_expect_test.ml":4115:13
          └─(INFO: 3 j= 21)
    21

    BEGIN DEBUG SESSION for=4,with=3
    result = 0
    ├─"test/test_expect_test.ml":4106:27
    ├─for=4,with=3 result
    └─for=4,with=3 while:test_expect_test:4109
      ├─"test/test_expect_test.ml":4109:4
      ├─for=4,with=3 <while loop>
      │ └─"test/test_expect_test.ml":4110:6
      ├─for=4,with=3 <while loop>
      │ └─"test/test_expect_test.ml":4110:6
      ├─for=4,with=3 <while loop>
      │ └─"test/test_expect_test.ml":4110:6
      ├─for=4,with=3 <while loop>
      │ └─"test/test_expect_test.ml":4110:6
      ├─for=4,with=3 <while loop>
      │ └─"test/test_expect_test.ml":4110:6
      └─for=4,with=3 <while loop>
        └─"test/test_expect_test.ml":4110:6
    0
    |}]

*)

(*
let%expect_test "%log_block compile-time nothing" =
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file ~values_first_mode:false db_file in
    fun () -> rt
  in
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

*)

(*
let%expect_test "%log_block compile-time nothing dynamic scope" =
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file ~values_first_mode:false db_file in
    fun () -> rt
  in
  let%diagn_show logify _logs =
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
  let%diagn_show _logging_logic : unit =
    [%log_level
      0;
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

*)

(*
let%expect_test "%log compile time log levels while-loop dynamic scope" =
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file in
    fun () -> rt
  in
  let%track_sexp loop () =
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
  let%track_sexp everything () : int =
    [%log_level
      9;
      loop ()]
  in
  let%track_sexp nothing () : int =
    (* The result is still logged, because the binding is outside of %log_level. *)
    [%log_level
      0;
      loop ()]
  in
  let%track_sexp warning () : int =
    [%log_level
      2;
      loop ()]
  in
  print_endline @@ Int.to_string @@ everything ();
  print_endline @@ Int.to_string @@ nothing ();
  print_endline @@ Int.to_string @@ warning ();
  [%expect
    {|
    BEGIN DEBUG SESSION
    everything = 21
    ├─"test/test_expect_test.ml":4487:28
    └─loop
      ├─"test/test_expect_test.ml":4474:22
      └─while:test_expect_test:4477
        ├─"test/test_expect_test.ml":4477:4
        ├─<while loop>
        │ ├─"test/test_expect_test.ml":4479:6
        │ ├─then:test_expect_test:4479
        │ │ ├─"test/test_expect_test.ml":4479:21
        │ │ └─(ERROR: 1 i= 0)
        │ ├─(WARNING: 2 i= 1)
        │ ├─fun:test_expect_test:4482
        │ │ └─"test/test_expect_test.ml":4482:11
        │ └─(INFO: 3 j= 1)
        ├─<while loop>
        │ ├─"test/test_expect_test.ml":4479:6
        │ ├─then:test_expect_test:4479
        │ │ ├─"test/test_expect_test.ml":4479:21
        │ │ └─(ERROR: 1 i= 1)
        │ ├─(WARNING: 2 i= 2)
        │ ├─fun:test_expect_test:4482
        │ │ └─"test/test_expect_test.ml":4482:11
        │ └─(INFO: 3 j= 3)
        ├─<while loop>
        │ ├─"test/test_expect_test.ml":4479:6
        │ ├─else:test_expect_test:4479
        │ │ └─"test/test_expect_test.ml":4479:64
        │ ├─(WARNING: 2 i= 3)
        │ ├─fun:test_expect_test:4482
        │ │ └─"test/test_expect_test.ml":4482:11
        │ └─(INFO: 3 j= 6)
        ├─<while loop>
        │ ├─"test/test_expect_test.ml":4479:6
        │ ├─else:test_expect_test:4479
        │ │ └─"test/test_expect_test.ml":4479:64
        │ ├─(WARNING: 2 i= 4)
        │ ├─fun:test_expect_test:4482
        │ │ └─"test/test_expect_test.ml":4482:11
        │ └─(INFO: 3 j= 10)
        ├─<while loop>
        │ ├─"test/test_expect_test.ml":4479:6
        │ ├─else:test_expect_test:4479
        │ │ └─"test/test_expect_test.ml":4479:64
        │ ├─(WARNING: 2 i= 5)
        │ ├─fun:test_expect_test:4482
        │ │ └─"test/test_expect_test.ml":4482:11
        │ └─(INFO: 3 j= 15)
        └─<while loop>
          ├─"test/test_expect_test.ml":4479:6
          ├─else:test_expect_test:4479
          │ └─"test/test_expect_test.ml":4479:64
          ├─(WARNING: 2 i= 6)
          ├─fun:test_expect_test:4482
          │ └─"test/test_expect_test.ml":4482:11
          └─(INFO: 3 j= 21)
    21
    nothing = 21
    └─"test/test_expect_test.ml":4492:25
    21
    warning = 21
    ├─"test/test_expect_test.ml":4498:25
    └─loop
      ├─"test/test_expect_test.ml":4474:22
      └─while:test_expect_test:4477
        ├─"test/test_expect_test.ml":4477:4
        ├─<while loop>
        │ ├─"test/test_expect_test.ml":4479:6
        │ ├─then:test_expect_test:4479
        │ │ ├─"test/test_expect_test.ml":4479:21
        │ │ └─(ERROR: 1 i= 0)
        │ ├─(WARNING: 2 i= 1)
        │ ├─fun:test_expect_test:4482
        │ │ └─"test/test_expect_test.ml":4482:11
        │ └─(INFO: 3 j= 1)
        ├─<while loop>
        │ ├─"test/test_expect_test.ml":4479:6
        │ ├─then:test_expect_test:4479
        │ │ ├─"test/test_expect_test.ml":4479:21
        │ │ └─(ERROR: 1 i= 1)
        │ ├─(WARNING: 2 i= 2)
        │ ├─fun:test_expect_test:4482
        │ │ └─"test/test_expect_test.ml":4482:11
        │ └─(INFO: 3 j= 3)
        ├─<while loop>
        │ ├─"test/test_expect_test.ml":4479:6
        │ ├─else:test_expect_test:4479
        │ │ └─"test/test_expect_test.ml":4479:64
        │ ├─(WARNING: 2 i= 3)
        │ ├─fun:test_expect_test:4482
        │ │ └─"test/test_expect_test.ml":4482:11
        │ └─(INFO: 3 j= 6)
        ├─<while loop>
        │ ├─"test/test_expect_test.ml":4479:6
        │ ├─else:test_expect_test:4479
        │ │ └─"test/test_expect_test.ml":4479:64
        │ ├─(WARNING: 2 i= 4)
        │ ├─fun:test_expect_test:4482
        │ │ └─"test/test_expect_test.ml":4482:11
        │ └─(INFO: 3 j= 10)
        ├─<while loop>
        │ ├─"test/test_expect_test.ml":4479:6
        │ ├─else:test_expect_test:4479
        │ │ └─"test/test_expect_test.ml":4479:64
        │ ├─(WARNING: 2 i= 5)
        │ ├─fun:test_expect_test:4482
        │ │ └─"test/test_expect_test.ml":4482:11
        │ └─(INFO: 3 j= 15)
        └─<while loop>
          ├─"test/test_expect_test.ml":4479:6
          ├─else:test_expect_test:4479
          │ └─"test/test_expect_test.ml":4479:64
          ├─(WARNING: 2 i= 6)
          ├─fun:test_expect_test:4482
          │ └─"test/test_expect_test.ml":4482:11
          └─(INFO: 3 j= 21)
    21
    |}]

*)

(*
let%expect_test "%debug_show comparing differences across runs" =
  let prev_run = "test_expect_test_prev_run" in
  let curr_run = "test_expect_test_curr_run" in

  (* First run - create baseline *)
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file ~values_first_mode:false ~backend:`Text prev_run in
    fun () -> rt
  in
  let%debug_show foo (x : t) : int =
    let y : int = x.first + 1 in
    let z : int = x.second * 2 in
    y + z
  in
  let () = print_endline @@ Int.to_string @@ foo { first = 7; second = 42 } in
  let rec print_log log_file =
    try
      print_endline (input_line log_file);
      print_log log_file
    with End_of_file -> ()
  in
  let log_file = open_in (prev_run ^ ".log") in
  print_log log_file;
  close_in log_file;

  (* Move current run to prev run *)

  (* Second run with some changes *)
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file ~values_first_mode:false ~backend:`Text
      ~prev_run_file:(prev_run ^ ".raw") curr_run in
    fun () -> rt
  in
  let%debug_show foo (x : t) : int =
    let y : int = x.first + 2 in
    (* Changed from +1 to +2 *)
    let z : int = x.second * 2 in
    y + z
  in
  let () = print_endline @@ Int.to_string @@ foo { first = 7; second = 42 } in

  (* Read and print the log file *)
  let log_file = open_in (curr_run ^ ".log") in
  print_log log_file;
  close_in log_file;
  [%expect
    {|
    92

    BEGIN DEBUG SESSION
    "test/test_expect_test.ml":4636:21: foo
    ├─x = { Test_expect_test.first = 7; second = 42 }
    ├─"test/test_expect_test.ml":4637:8: y
    │ └─y = 8
    ├─"test/test_expect_test.ml":4638:8: z
    │ └─z = 84
    └─foo = 92
    93

    BEGIN DEBUG SESSION
    ┌───────────────────────────────────────┐Changed from: y = 8
    │"test/test_expect_test.ml":4659:21: foo│
    ├───────────────────────────────────────┘
    ├─x = { Test_expect_test.first = 7; second = 42 }
    ├─┬────────────────────────────────────┐Changed from: y = 8
    │ │"test/test_expect_test.ml":4660:8: y│
    │ ├────────────────────────────────────┘
    │ └─┬─────┐Changed from: y = 8
    │   │y = 9│
    │   └─────┘
    ├─"test/test_expect_test.ml":4662:8: z
    │ └─z = 84
    └─┬────────┐Changed from: foo = 92
      │foo = 93│
      └────────┘
    |}]

*)

(*
let%expect_test "%debug_show comparing differences with normalized patterns" =
  let prev_run = "test_expect_test_prev_run_norm" in
  let curr_run = "test_expect_test_curr_run_norm" in

  (* First run - create baseline *)
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file ~values_first_mode:false ~backend:`Text prev_run in
    fun () -> rt
  in
  let%debug_show process_message (msg : string) : int =
    let timestamp : string = "[2024-03-21 10:00:00] " in
    let processed : string = timestamp ^ "Processing: " ^ msg in
    String.length processed
  in
  let () = print_endline @@ Int.to_string @@ process_message "hello" in
  let rec print_log log_file =
    try
      print_endline (input_line log_file);
      print_log log_file
    with End_of_file -> ()
  in
  let log_file = open_in (prev_run ^ ".log") in
  print_log log_file;
  close_in log_file;
  [%expect
    {|
    39

    BEGIN DEBUG SESSION
    "test/test_expect_test.ml":4711:33: process_message
    ├─msg = "hello"
    ├─"test/test_expect_test.ml":4712:8: timestamp
    │ └─timestamp = "[2024-03-21 10:00:00] "
    ├─"test/test_expect_test.ml":4713:8: processed
    │ └─processed = "[2024-03-21 10:00:00] Processing: hello"
    └─process_message = 39
    |}];

  (* Second run - with different timestamp but same message *)
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file ~values_first_mode:false ~backend:`Text
      ~prev_run_file:(prev_run ^ ".raw")
      ~diff_ignore_pattern:(Re.Pcre.re {|\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\]|})
      curr_run in
    fun () -> rt
  in
  let%debug_show process_message (msg : string) : int =
    let timestamp : string = "[2024-03-22 15:30:45] " in
    (* Different timestamp *)
    let processed : string = timestamp ^ "Processing: " ^ msg in
    String.length processed
  in
  let () = print_endline @@ Int.to_string @@ process_message "hello" in
  let log_file = open_in (curr_run ^ ".log") in
  print_log log_file;
  close_in log_file;
  [%expect
    {|
    39

    BEGIN DEBUG SESSION
    "test/test_expect_test.ml":4747:33: process_message
    ├─msg = "hello"
    ├─"test/test_expect_test.ml":4748:8: timestamp
    │ └─timestamp = "[2024-03-22 15:30:45] "
    ├─"test/test_expect_test.ml":4750:8: processed
    │ └─processed = "[2024-03-22 15:30:45] Processing: hello"
    └─process_message = 39
    |}];
  let curr_run2 = "test_expect_test_curr_run_norm2" in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file ~values_first_mode:false ~backend:`Text
      ~prev_run_file:(prev_run ^ ".raw")
      ~diff_ignore_pattern:(Re.Pcre.re {|\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\]|})
      curr_run2 in
    fun () -> rt
  in
  let%debug_show process_message (msg : string) : int =
    let timestamp : string = "[2024-03-22 15:30:45] " in
    let processing : string = "Processing: " ^ msg in
    let processed : string = timestamp ^ processing in
    String.length processed
  in
  let () = print_endline @@ Int.to_string @@ process_message "hello" in
  let log_file = open_in (curr_run2 ^ ".log") in
  print_log log_file;
  close_in log_file;
  [%expect
    {|
    39

    BEGIN DEBUG SESSION
    ┌───────────────────────────────────────────────────┐Inserted in current run
    │"test/test_expect_test.ml":4777:33: process_message│
    ├───────────────────────────────────────────────────┘
    ├─msg = "hello"
    ├─"test/test_expect_test.ml":4778:8: timestamp
    │ └─timestamp = "[2024-03-22 15:30:45] "
    ├─┬─────────────────────────────────────────────┐Inserted in current run
    │ │"test/test_expect_test.ml":4779:8: processing│
    │ ├─────────────────────────────────────────────┘
    │ └─┬────────────────────────────────┐Inserted in current run
    │   │processing = "Processing: hello"│
    │   └────────────────────────────────┘
    ├─"test/test_expect_test.ml":4780:8: processed
    │ └─processed = "[2024-03-22 15:30:45] Processing: hello"
    └─process_message = 39
    |}]

*)

(*
let%expect_test "comparing differences with entry_id_pairs" =
  let prev_run = "test_expect_test_entry_id_pairs_prev" in
  let curr_run = "test_expect_test_entry_id_pairs_curr" in

  (* First run - create baseline with several entries *)
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file ~values_first_mode:false ~print_entry_ids:true
      ~backend:`Text prev_run in
    fun () -> rt
  in
  let%debug_show _run1 : unit =
    let logify logs =
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
        ignore (loop logs)]
    in

    (* First run with specific entries *)
    logify
      [
        "start";
        "Entry one";
        "This is the first entry";
        "end";
        "start";
        "Entry two";
        "This is the second entry";
        "end";
        "start";
        "Entry three";
        "This is the third entry";
        "Some more content";
        "end";
        "start";
        "Entry four";
        "This is the fourth entry";
        "end";
        "start";
        "Entry five";
        "This is the fifth entry";
        "end";
        "start";
        "Entry six";
        "This is the sixth entry";
        "end";
        "start";
        "Final content";
        "end";
      ]
  in
  (let module D = (val _get_local_debug_runtime ()) in
  D.finish_and_cleanup ());

  (* Second run with different structure *)
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file ~values_first_mode:false ~print_entry_ids:true
      ~backend:`Text ~prev_run_file:(prev_run ^ ".raw")
      ~entry_id_pairs:[ (2, 4); (8, 6) ]
        (* Force mappings: - Entry 1 (early prev) to Entry 4 (middle curr) - Entry 6 (late
           prev) to Entry 13 (shorter curr) *)
      curr_run in
    fun () -> rt
  in
  (* Second run with different structure to test diffing *)
  let%debug_show _run2 : unit =
    let logify logs =
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
        ignore (loop logs)]
    in
    logify
      [
        "start";
        "New first";
        "This is a new first entry";
        "end";
        "start";
        "New second";
        "This is a new second entry";
        "end";
        "start";
        "Entry one";
        "This is the first entry";
        "With some modifications";
        "end";
        "start";
        "New third";
        "Another new entry";
        "end";
        "start";
        "Entry four";
        "This is the fourth entry";
        "end";
        "start";
        "Final content";
        "end";
      ]
  in
  (let module D = (val _get_local_debug_runtime ()) in
  D.finish_and_cleanup ());

  (* Print the outputs to show the diff results *)
  let print_log filename =
    let log_file = open_in (filename ^ ".log") in
    try
      while true do
        print_endline (input_line log_file)
      done
    with End_of_file -> close_in log_file
  in

  print_endline "=== Previous Run ===";
  print_log prev_run;
  print_endline "\n=== Current Run with Diff ===";
  print_log curr_run;

  [%expect
    {|
    === Previous Run ===

    BEGIN DEBUG SESSION
    "test/test_expect_test.ml":4818:17: _run1 {#1}
    ├─logs {#2}
    │ ├─Entry one {#3}
    │ │ └─"This is the first entry"
    │ ├─Entry two {#4}
    │ │ └─"This is the second entry"
    │ ├─Entry three {#5}
    │ │ ├─"This is the third entry"
    │ │ └─"Some more content"
    │ ├─Entry four {#6}
    │ │ └─"This is the fourth entry"
    │ ├─Entry five {#7}
    │ │ └─"This is the fifth entry"
    │ ├─Entry six {#8}
    │ │ └─"This is the sixth entry"
    │ └─Final content {#9}
    └─_run1 = ()

    END DEBUG SESSION

    === Current Run with Diff ===

    BEGIN DEBUG SESSION
    ┌─────────────────────────────────────────┐┌─┐┌────┐Inserted in current run
    │"test/test_expect_test.ml":4886:17: _run2││ ││{#1}│
    ├─────────────────────────────────────────┘└─┘└────┘
    ├─┬────┐┌─┐┌────┐Inserted in current run
    │ │logs││ ││{#2}│
    │ ├────┘└─┘└────┘
    │ ├─┬─────────┐┌─┐┌────┐Inserted in current run
    │ │ │New first││ ││{#3}│
    │ │ ├─────────┘└─┘└────┘
    │ │ └─┬───────────────────────────┐Changed from: _run1
    │ │   │"This is a new first entry"│
    │ │   └───────────────────────────┘
    │ ├─┬──────────┐┌─┐┌────┐Changed from: logs
    │ │ │New second││ ││{#4}│
    │ │ ├──────────┘└─┘└────┘
    │ │ └─┬────────────────────────────┐Changed from: Entry one
    │ │   │"This is a new second entry"│
    │ │   └────────────────────────────┘
    │ ├─┬─────────┐┌─┐┌────┐Changed from: Entry two
    │ │ │Entry one││ ││{#5}│
    │ │ ├─────────┘└─┘└────┘
    │ │ ├─┬─────────────────────────┐Changed from: "This is the fourth entry"
    │ │ │ │"This is the first entry"│
    │ │ │ └─────────────────────────┘
    │ │ └─┬─────────────────────────┐Changed from: "This is the fifth entry"
    │ │   │"With some modifications"│
    │ │   └─────────────────────────┘
    │ ├─┬─────────┐┌─┐┌────┐Changed from: Entry six
    │ │ │New third││ ││{#6}│
    │ │ ├─────────┘└─┘└────┘
    │ │ └─┬───────────────────┐Changed from: "This is the sixth entry"
    │ │   │"Another new entry"│
    │ │   └───────────────────┘
    │ ├─┬──────────┐┌─┐┌────┐Inserted in current run
    │ │ │Entry four││ ││{#7}│
    │ │ ├──────────┘└─┘└────┘
    │ │ └─┬──────────────────────────┐Inserted in current run
    │ │   │"This is the fourth entry"│
    │ │   └──────────────────────────┘
    │ └─Final content {#8}
    └─┬──────────┐Changed from: _run1 = ()
      │_run2 = ()│
      └──────────┘

    END DEBUG SESSION
    |}]
*)