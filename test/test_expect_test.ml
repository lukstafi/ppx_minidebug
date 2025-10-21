open! Sexplib0.Sexp_conv

type t = { first : int; second : int } [@@deriving show]

(* File versioning: each runtime gets its own versioned database file *)
let db_file_base = "test_expect_test"
let run_counter = ref 0

(* Get the next runtime counter and corresponding versioned filename *)
let next_run () =
  incr run_counter;
  !run_counter

(* Get versioned filename for a given run number *)
let db_file_for_run run_num = Printf.sprintf "%s_%d.db" db_file_base run_num

(* Open the latest versioned database file and verify it's the right one *)
let latest_run () =
  let run_num = next_run () in
  let db_file = db_file_for_run run_num in
  (* Verify next file doesn't exist - confirms we're at the right versioned file *)
  let next_file = db_file_for_run (run_num + 1) in
  assert (not (Sys.file_exists next_file));
  (* Open the database and get run info *)
  let db = Minidebug_client.Client.open_db db_file in
  let result = Minidebug_client.Client.get_latest_run db |> Option.get in
  print_endline @@ "latest_run: " ^ Option.value ~default:"(no-name)" result.run_name;
  (* Each versioned file has only one run with run_id=1 *)
  assert (result.run_id = 1);
  db

let%expect_test "%debug_show, `as` alias and show_times" =
  let run_num = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file_base in
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
  let db = Minidebug_client.Client.open_db (db_file_for_run run_num) in
  Minidebug_client.Client.show_trace db ~show_times:true ~values_first_mode:false 1;
  let output = [%expect.output] in
  let output =
    Str.global_replace (Str.regexp {|<[0-9.]+\(μs\|ms\|s\)>|}) "<TIME>" output
  in
  print_endline output;
  [%expect
    {|
    336
    339
    [debug] bar @ test/test_expect_test.ml:38:21-40:16 <TIME>
      x = { Test_expect_test.first = 7; second = 42 }
      [debug] y @ test/test_expect_test.ml:39:8-39:9 <TIME>
        y => 8
      bar => 336
    [debug] baz @ test/test_expect_test.ml:43:21-45:22 <TIME>
      x = { Test_expect_test.first = 7; second = 42 }
      [debug] _yz @ test/test_expect_test.ml:44:19-44:22 <TIME>
        _yz => (8, 3)
      baz => 339
    |}]

let%expect_test "%debug_show with run name" =
  let run_num = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file ~run_name:"test-51" db_file_base in
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
  let db = Minidebug_client.Client.open_db (db_file_for_run run_num) in
  Minidebug_client.Client.show_trace db ~values_first_mode:false 1;
  let runs = Minidebug_client.Client.list_runs db in
  let run = List.find (fun r -> r.Minidebug_client.Query.run_id = 1) runs in
  Printf.printf "\nRun #%d has name: %s\n" run.run_id
    (match run.run_name with Some n -> n | None -> "(none)");
  [%expect
    {|
    336
    339
    [debug] bar @ test/test_expect_test.ml:77:21-79:16
      x = { Test_expect_test.first = 7; second = 42 }
      [debug] y @ test/test_expect_test.ml:78:8-78:9
        y => 8
      bar => 336
    [debug] baz @ test/test_expect_test.ml:82:21-84:22
      x = { Test_expect_test.first = 7; second = 42 }
      [debug] _yz @ test/test_expect_test.ml:83:19-83:22
        _yz => (8, 3)
      baz => 339

    Run #1 has name: (none)
    |}]

let%expect_test "%debug_show disabled subtree" =
  let run_num1 = next_run () in
  let rt1 = Minidebug_db.debug_db_file db_file_base in
  let _get_local_debug_runtime = fun () -> rt1 in
  let%debug_show rec loop_complete (x : int) : int =
    let z : int = (x - 1) / 2 in
    if x <= 0 then 0 else z + loop_complete (z + (x / 2))
  in
  let () = print_endline @@ Int.to_string @@ loop_complete 7 in
  let db = Minidebug_client.Client.open_db (db_file_for_run run_num1) in
  Minidebug_client.Client.show_trace db ~values_first_mode:false 1;
  [%expect
    {|
    9
    [debug] loop_complete @ test/test_expect_test.ml:115:35-117:57
      x = 7
      [debug] z @ test/test_expect_test.ml:116:8-116:9
        z => 3
      [debug] loop_complete @ test/test_expect_test.ml:115:35-117:57
        x = 6
        [debug] z @ test/test_expect_test.ml:116:8-116:9
          z => 2
        [debug] loop_complete @ test/test_expect_test.ml:115:35-117:57
          x = 5
          [debug] z @ test/test_expect_test.ml:116:8-116:9
            z => 2
          [debug] loop_complete @ test/test_expect_test.ml:115:35-117:57
            x = 4
            [debug] z @ test/test_expect_test.ml:116:8-116:9
              z => 1
            [debug] loop_complete @ test/test_expect_test.ml:115:35-117:57
              x = 3
              [debug] z @ test/test_expect_test.ml:116:8-116:9
                z => 1
              [debug] loop_complete @ test/test_expect_test.ml:115:35-117:57
                x = 2
                [debug] z @ test/test_expect_test.ml:116:8-116:9
                  z => 0
                [debug] loop_complete @ test/test_expect_test.ml:115:35-117:57
                  x = 1
                  [debug] z @ test/test_expect_test.ml:116:8-116:9
                    z => 0
                  [debug] loop_complete @ test/test_expect_test.ml:115:35-117:57
                    x = 0
                    [debug] z @ test/test_expect_test.ml:116:8-116:9
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

  let run_num2 = next_run () in
  let rt2 = Minidebug_db.debug_db_file db_file_base in
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
  let db = Minidebug_client.Client.open_db (db_file_for_run run_num2) in
  Minidebug_client.Client.show_trace db ~values_first_mode:false 1;
  [%expect
    {|
    9
    [debug] loop_changes @ test/test_expect_test.ml:171:34-177:7
      x = 7
      [debug] z @ test/test_expect_test.ml:172:8-172:9
        z => 3
      [debug] loop_changes @ test/test_expect_test.ml:171:34-177:7
        x = 6
        [debug] z @ test/test_expect_test.ml:172:8-172:9
          z => 2
        [debug] loop_changes @ test/test_expect_test.ml:171:34-177:7
          x = 5
          [debug] z @ test/test_expect_test.ml:172:8-172:9
            z => 2
          loop_changes => 4
        loop_changes => 6
      loop_changes => 9
    |}]
(* $MDX part-end *)

let%expect_test "%debug_show with exception" =
  let run_num = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file_base in
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
  let db = Minidebug_client.Client.open_db (db_file_for_run run_num) in
  Minidebug_client.Client.show_trace db ~values_first_mode:false ~show_times:true 1;
  let output = [%expect.output] in
  let output =
    Str.global_replace (Str.regexp {|<[0-9.]+\(μs\|ms\|s\)>|}) "<TIME>" output
  in
  print_endline output;
  [%expect
    {|
    Raised exception.
    [debug] loop_truncated @ test/test_expect_test.ml:209:36-212:36 <TIME>
      x = 7
      [debug] z @ test/test_expect_test.ml:210:8-210:9 <TIME>
        z => 3
      [debug] loop_truncated @ test/test_expect_test.ml:209:36-212:36 <TIME>
        x = 6
        [debug] z @ test/test_expect_test.ml:210:8-210:9 <TIME>
          z => 2
        [debug] loop_truncated @ test/test_expect_test.ml:209:36-212:36 <TIME>
          x = 5
          [debug] z @ test/test_expect_test.ml:210:8-210:9 <TIME>
            z => 2
          [debug] loop_truncated @ test/test_expect_test.ml:209:36-212:36 <TIME>
            x = 4
            [debug] z @ test/test_expect_test.ml:210:8-210:9 <TIME>
              z => 1
            [debug] loop_truncated @ test/test_expect_test.ml:209:36-212:36 <TIME>
              x = 3
              [debug] z @ test/test_expect_test.ml:210:8-210:9 <TIME>
                z => 1
              [debug] loop_truncated @ test/test_expect_test.ml:209:36-212:36 <TIME>
                x = 2
                [debug] z @ test/test_expect_test.ml:210:8-210:9 <TIME>
                  z => 0
                [debug] loop_truncated @ test/test_expect_test.ml:209:36-212:36 <TIME>
                  x = 1
                  [debug] z @ test/test_expect_test.ml:210:8-210:9 <TIME>
                    z => 0
                  [debug] loop_truncated @ test/test_expect_test.ml:209:36-212:36 <TIME>
                    x = 0
                    [debug] z @ test/test_expect_test.ml:210:8-210:9 <TIME>
                      z => 0
    |}]

let%expect_test "%debug_show depth exceeded" =
  let run_num = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file_base in
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
  let db = Minidebug_client.Client.open_db (db_file_for_run run_num) in
  Minidebug_client.Client.show_trace db ~values_first_mode:false 1;
  [%expect
    {|
    Raised exception.
    [debug] loop_exceeded @ test/test_expect_test.ml:269:35-273:60
      x = 7
      [debug] z @ test/test_expect_test.ml:272:10-272:11
        z => 3
      [debug] loop_exceeded @ test/test_expect_test.ml:269:35-273:60
        x = 6
        [debug] z @ test/test_expect_test.ml:272:10-272:11
          z => 2
        [debug] loop_exceeded @ test/test_expect_test.ml:269:35-273:60
          x = 5
          [debug] z @ test/test_expect_test.ml:272:10-272:11
            z => 2
          [debug] loop_exceeded @ test/test_expect_test.ml:269:35-273:60
            x = 4
            [debug] z @ test/test_expect_test.ml:272:10-272:11
              z => 1
            [debug] loop_exceeded @ test/test_expect_test.ml:269:35-273:60
              x = 3
              [debug] z @ test/test_expect_test.ml:272:10-272:11
                z => 1
              [debug] loop_exceeded @ test/test_expect_test.ml:269:35-273:60
                x = 2
                [debug] z @ test/test_expect_test.ml:272:10-272:11
                  z = <max_nesting_depth exceeded>
    |}]
(* $MDX part-end *)

let%expect_test "%debug_show num children exceeded linear" =
  let run_num = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file_base in
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
  let db = Minidebug_client.Client.open_db (db_file_for_run run_num) in
  Minidebug_client.Client.show_trace db ~values_first_mode:false 1;
  [%expect
    {|
    Raised exception: ppx_minidebug: max_num_children exceeded
    [debug] _bar @ test/test_expect_test.ml:320:21-320:25
      [debug] _baz @ test/test_expect_test.ml:324:16-324:20
        _baz => 0
      [debug] _baz @ test/test_expect_test.ml:324:16-324:20
        _baz => 2
      [debug] _baz @ test/test_expect_test.ml:324:16-324:20
        _baz => 4
      [debug] _baz @ test/test_expect_test.ml:324:16-324:20
        _baz => 6
      [debug] _baz @ test/test_expect_test.ml:324:16-324:20
        _baz => 8
      [debug] _baz @ test/test_expect_test.ml:324:16-324:20
        _baz => 10
      [debug] _baz @ test/test_expect_test.ml:324:16-324:20
        _baz => 12
      [debug] _baz @ test/test_expect_test.ml:324:16-324:20
        _baz => 14
      [debug] _baz @ test/test_expect_test.ml:324:16-324:20
        _baz => 16
      [debug] _baz @ test/test_expect_test.ml:324:16-324:20
        _baz => 18
      [debug] _baz @ test/test_expect_test.ml:324:16-324:20
        _baz => 20
      [debug] _baz @ test/test_expect_test.ml:324:16-324:20
        _baz = <max_num_children exceeded>
    |}]
(* $MDX part-end *)

let%expect_test "%track_show track for-loop num children exceeded" =
  let run_num = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file_base in
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
  let db = Minidebug_client.Client.open_db (db_file_for_run run_num) in
  Minidebug_client.Client.show_trace db ~values_first_mode:false 1;
  [%expect
    {|
    Raised exception: ppx_minidebug: max_num_children exceeded
    [track] _bar @ test/test_expect_test.ml:372:21-372:25
      [track] for:test_expect_test:375 @ test/test_expect_test.ml:375:10-378:14
        [track] <for i> @ test/test_expect_test.ml:375:14-375:15
          i = 0
          [track] _baz @ test/test_expect_test.ml:376:16-376:20
            _baz => 0
        [track] <for i> @ test/test_expect_test.ml:375:14-375:15
          i = 1
          [track] _baz @ test/test_expect_test.ml:376:16-376:20
            _baz => 2
        [track] <for i> @ test/test_expect_test.ml:375:14-375:15
          i = 2
          [track] _baz @ test/test_expect_test.ml:376:16-376:20
            _baz => 4
        [track] <for i> @ test/test_expect_test.ml:375:14-375:15
          i = 3
          [track] _baz @ test/test_expect_test.ml:376:16-376:20
            _baz => 6
        [track] <for i> @ test/test_expect_test.ml:375:14-375:15
          i = 4
          [track] _baz @ test/test_expect_test.ml:376:16-376:20
            _baz => 8
        [track] <for i> @ test/test_expect_test.ml:375:14-375:15
          i = 5
          [track] _baz @ test/test_expect_test.ml:376:16-376:20
            _baz => 10
        [track] <for i> @ test/test_expect_test.ml:375:14-375:15
          i = 6
          [track] _baz @ test/test_expect_test.ml:376:16-376:20
            _baz => 12
        [track] <for i> @ test/test_expect_test.ml:375:14-375:15
          i = 7
          [track] _baz @ test/test_expect_test.ml:376:16-376:20
            _baz => 14
        [track] <for i> @ test/test_expect_test.ml:375:14-375:15
          i = 8
          [track] _baz @ test/test_expect_test.ml:376:16-376:20
            _baz => 16
        [track] <for i> @ test/test_expect_test.ml:375:14-375:15
          i = 9
          [track] _baz @ test/test_expect_test.ml:376:16-376:20
            _baz => 18
        [track] <for i> @ test/test_expect_test.ml:375:14-375:15
          i = 10
          [track] _baz @ test/test_expect_test.ml:376:16-376:20
            _baz => 20
        [track] <for i> @ test/test_expect_test.ml:375:14-375:15
          i = 11
          i = <max_num_children exceeded>
    |}]

let%expect_test "%track_show track for-loop" =
  let run_num = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file_base in
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
  let db = Minidebug_client.Client.open_db (db_file_for_run run_num) in
  Minidebug_client.Client.show_trace db ~values_first_mode:false 1;
  [%expect
    {|
    [track] _bar @ test/test_expect_test.ml:447:21-447:25
      [track] for:test_expect_test:450 @ test/test_expect_test.ml:450:10-453:14
        [track] <for i> @ test/test_expect_test.ml:450:14-450:15
          i = 0
          [track] _baz @ test/test_expect_test.ml:451:16-451:20
            _baz => 0
        [track] <for i> @ test/test_expect_test.ml:450:14-450:15
          i = 1
          [track] _baz @ test/test_expect_test.ml:451:16-451:20
            _baz => 2
        [track] <for i> @ test/test_expect_test.ml:450:14-450:15
          i = 2
          [track] _baz @ test/test_expect_test.ml:451:16-451:20
            _baz => 4
        [track] <for i> @ test/test_expect_test.ml:450:14-450:15
          i = 3
          [track] _baz @ test/test_expect_test.ml:451:16-451:20
            _baz => 6
        [track] <for i> @ test/test_expect_test.ml:450:14-450:15
          i = 4
          [track] _baz @ test/test_expect_test.ml:451:16-451:20
            _baz => 8
        [track] <for i> @ test/test_expect_test.ml:450:14-450:15
          i = 5
          [track] _baz @ test/test_expect_test.ml:451:16-451:20
            _baz => 10
        [track] <for i> @ test/test_expect_test.ml:450:14-450:15
          i = 6
          [track] _baz @ test/test_expect_test.ml:451:16-451:20
            _baz => 12
      _bar => ()
    |}]

let%expect_test "%track_show track for-loop, time spans" =
  let run_num = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file ~elapsed_times:Microseconds db_file_base in
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
  let db = Minidebug_client.Client.open_db (db_file_for_run run_num) in
  Minidebug_client.Client.show_trace db ~values_first_mode:false ~show_times:true 1;
  let output = [%expect.output] in
  let output =
    Str.global_replace
      (Str.regexp {|[0-9]+?[0-9]+.[0-9]+[0-9]+\(μ\|m\|n\)s|})
      "N.NNμs" output
  in
  print_endline output;
  [%expect
    {|
    [track] _bar @ test/test_expect_test.ml:503:21-503:25 <N.NNμs>
      [track] for:test_expect_test:506 @ test/test_expect_test.ml:506:10-509:14 <N.NNμs>
        [track] <for i> @ test/test_expect_test.ml:506:14-506:15 <N.NNμs>
          i = 0
          [track] _baz @ test/test_expect_test.ml:507:16-507:20 <N.NNμs>
            _baz => 0
        [track] <for i> @ test/test_expect_test.ml:506:14-506:15 <N.NNμs>
          i = 1
          [track] _baz @ test/test_expect_test.ml:507:16-507:20 <N.NNμs>
            _baz => 2
        [track] <for i> @ test/test_expect_test.ml:506:14-506:15 <N.NNμs>
          i = 2
          [track] _baz @ test/test_expect_test.ml:507:16-507:20 <N.NNμs>
            _baz => 4
        [track] <for i> @ test/test_expect_test.ml:506:14-506:15 <N.NNμs>
          i = 3
          [track] _baz @ test/test_expect_test.ml:507:16-507:20 <N.NNμs>
            _baz => 6
        [track] <for i> @ test/test_expect_test.ml:506:14-506:15 <N.NNμs>
          i = 4
          [track] _baz @ test/test_expect_test.ml:507:16-507:20 <N.NNμs>
            _baz => 8
        [track] <for i> @ test/test_expect_test.ml:506:14-506:15 <N.NNμs>
          i = 5
          [track] _baz @ test/test_expect_test.ml:507:16-507:20 <N.NNμs>
            _baz => 10
        [track] <for i> @ test/test_expect_test.ml:506:14-506:15 <N.NNμs>
          i = 6
          [track] _baz @ test/test_expect_test.ml:507:16-507:20 <N.NNμs>
            _baz => 12
      _bar => ()
    |}]

let%expect_test "%track_show track while-loop" =
  let run_num = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file_base in
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
  let db = Minidebug_client.Client.open_db (db_file_for_run run_num) in
  Minidebug_client.Client.show_trace db ~values_first_mode:false 1;
  [%expect
    {|
    [track] _bar @ test/test_expect_test.ml:566:21-566:25
      [track] while:test_expect_test:568 @ test/test_expect_test.ml:568:8-571:12
        [track] <while loop> @ test/test_expect_test.ml:569:10-570:16
          [track] _baz @ test/test_expect_test.ml:569:14-569:18
            _baz => 0
        [track] <while loop> @ test/test_expect_test.ml:569:10-570:16
          [track] _baz @ test/test_expect_test.ml:569:14-569:18
            _baz => 2
        [track] <while loop> @ test/test_expect_test.ml:569:10-570:16
          [track] _baz @ test/test_expect_test.ml:569:14-569:18
            _baz => 4
        [track] <while loop> @ test/test_expect_test.ml:569:10-570:16
          [track] _baz @ test/test_expect_test.ml:569:14-569:18
            _baz => 6
        [track] <while loop> @ test/test_expect_test.ml:569:10-570:16
          [track] _baz @ test/test_expect_test.ml:569:14-569:18
            _baz => 8
        [track] <while loop> @ test/test_expect_test.ml:569:10-570:16
          [track] _baz @ test/test_expect_test.ml:569:14-569:18
            _baz => 10
      _bar => ()
    |}]

let%expect_test "%debug_show num children exceeded nested" =
  let run_num = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file_base in
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
  let db = Minidebug_client.Client.open_db (db_file_for_run run_num) in
  Minidebug_client.Client.show_trace db ~values_first_mode:false 1;
  [%expect
    {|
    Raised exception: ppx_minidebug: max_num_children exceeded
    [debug] loop_exceeded @ test/test_expect_test.ml:609:35-617:72
      x = 3
      [debug] z @ test/test_expect_test.ml:616:17-616:18
        z => 1
      [debug] loop_exceeded @ test/test_expect_test.ml:609:35-617:72
        x = 2
        [debug] z @ test/test_expect_test.ml:616:17-616:18
          z => 0
        [debug] loop_exceeded @ test/test_expect_test.ml:609:35-617:72
          x = 1
          [debug] z @ test/test_expect_test.ml:616:17-616:18
            z => 0
          [debug] loop_exceeded @ test/test_expect_test.ml:609:35-617:72
            x = 0
            [debug] z @ test/test_expect_test.ml:616:17-616:18
              z => 0
            [debug] z @ test/test_expect_test.ml:616:17-616:18
              z => 1
            [debug] z @ test/test_expect_test.ml:616:17-616:18
              z => 2
            [debug] z @ test/test_expect_test.ml:616:17-616:18
              z => 3
            [debug] z @ test/test_expect_test.ml:616:17-616:18
              z => 4
            [debug] z @ test/test_expect_test.ml:616:17-616:18
              z => 5
            [debug] z @ test/test_expect_test.ml:616:17-616:18
              z => 6
            [debug] z @ test/test_expect_test.ml:616:17-616:18
              z => 7
            [debug] z @ test/test_expect_test.ml:616:17-616:18
              z => 8
            [debug] z @ test/test_expect_test.ml:616:17-616:18
              z => 9
            [debug] z @ test/test_expect_test.ml:616:17-616:18
              z = <max_num_children exceeded>
    |}]

let%expect_test "%track_show PrintBox tracking" =
  let run_num = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file_base in
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
  let db = Minidebug_client.Client.open_db (db_file_for_run run_num) in
  Minidebug_client.Client.show_trace db ~values_first_mode:false 1;
  [%expect
    {|
    4
    -3
    [track] track_branches @ test/test_expect_test.ml:672:32-674:46
      x = 7
      [track] else:test_expect_test:674 @ test/test_expect_test.ml:674:9-674:46
        <match -- branch 1> =
      track_branches => 4
    [track] track_branches @ test/test_expect_test.ml:672:32-674:46
      x = 3
      [track] then:test_expect_test:673 @ test/test_expect_test.ml:673:18-673:57
        <match -- branch 2> =
      track_branches => -3
    |}]

let%expect_test "%track_show PrintBox tracking <function>" =
  let run_num = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file_base in
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
  let db = Minidebug_client.Client.open_db (db_file_for_run run_num) in
  Minidebug_client.Client.show_trace db ~values_first_mode:false 1;
  [%expect
    {|
    4
    -3
    <function -- branch 3> =
    <function -- branch 5> x =
    |}]

let%expect_test "%track_show PrintBox tracking with debug_notrace" =
  let run_num = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file_base in
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
  let db = Minidebug_client.Client.open_db (db_file_for_run run_num) in
  Minidebug_client.Client.show_trace db ~values_first_mode:false 1;
  [%expect
    {|
    8
    3
    [track] track_branches @ test/test_expect_test.ml:737:32-751:16
      x = 8
      [track] else:test_expect_test:746 @ test/test_expect_test.ml:746:6-751:16
        [track] <match -- branch 2> @ test/test_expect_test.ml:750:10-751:16
          [track] result @ test/test_expect_test.ml:750:14-750:20
            then:test_expect_test:750 =
            result => 8
      track_branches => 8
    [track] track_branches @ test/test_expect_test.ml:737:32-751:16
      x = 3
      [track] then:test_expect_test:739 @ test/test_expect_test.ml:739:6-744:16
        [debug] result @ test/test_expect_test.ml:743:14-743:20
          result => 3
      track_branches => 3
    |}]
(* $MDX part-end *)

let%expect_test "%track_show PrintBox not tracking anonymous functions with debug_notrace"
    =
  let run_num = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file_base in
    fun () -> rt
  in
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
  let db = Minidebug_client.Client.open_db (db_file_for_run run_num) in
  Minidebug_client.Client.show_trace db ~values_first_mode:false 1;
  [%expect
    {|
    8
    [track] track_foo @ test/test_expect_test.ml:789:27-793:5
      x = 8
      [track] fun:test_expect_test:792 @ test/test_expect_test.ml:792:4-792:31
        z = 8
      track_foo => 8
    |}]

let%expect_test "respect scope of nested extension points" =
  let run_num = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file_base in
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
  let db = Minidebug_client.Client.open_db (db_file_for_run run_num) in
  Minidebug_client.Client.show_trace db ~values_first_mode:false 1;
  [%expect
    {|
    8
    3
    [track] track_branches @ test/test_expect_test.ml:817:32-831:16
      x = 8
      [track] else:test_expect_test:826 @ test/test_expect_test.ml:826:6-831:16
        [track] result @ test/test_expect_test.ml:830:25-830:31
          then:test_expect_test:830 =
          result => 8
      track_branches => 8
    [track] track_branches @ test/test_expect_test.ml:817:32-831:16
      x = 3
      [track] then:test_expect_test:819 @ test/test_expect_test.ml:819:6-824:16
        [debug] result @ test/test_expect_test.ml:823:25-823:31
          result => 3
      track_branches => 3
    |}]

let%expect_test "%debug_show un-annotated toplevel fun" =
  let run_num = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file_base in
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
  let db = Minidebug_client.Client.open_db (db_file_for_run run_num) in
  Minidebug_client.Client.show_trace db ~values_first_mode:false 1;
  [%expect
    {|
    6
    6
    [debug] anonymous @ test/test_expect_test.ml:866:27-869:73
      "We do log this function"
    |}]

let%expect_test "%debug_show nested un-annotated toplevel fun" =
  let run_num = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file_base in
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
  let db = Minidebug_client.Client.open_db (db_file_for_run run_num) in
  Minidebug_client.Client.show_trace db ~values_first_mode:false 1;
  [%expect
    {|
    6
    6
    wrapper =
    [debug] anonymous @ test/test_expect_test.ml:897:29-900:75
      "We do log this function"
    |}]

let%expect_test "%track_show no return type anonymous fun 1" =
  let run_num = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file_base in
    fun () -> rt
  in
  let%debug_show anonymous (x : int) =
    Array.fold_left ( + ) 0 @@ Array.init (x + 1) (fun (i : int) -> i)
  in
  let () =
    try print_endline @@ Int.to_string @@ anonymous 3
    with Failure s -> print_endline @@ "Raised exception: " ^ s
  in
  let db = Minidebug_client.Client.open_db (db_file_for_run run_num) in
  Minidebug_client.Client.show_trace db ~values_first_mode:false 1;
  [%expect
    {|
    6
    [debug] anonymous @ test/test_expect_test.ml:930:27-931:70
      x = 3
    |}]

let%expect_test "%track_show no return type anonymous fun 2" =
  let run_num = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file_base in
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
  let db = Minidebug_client.Client.open_db (db_file_for_run run_num) in
  Minidebug_client.Client.show_trace db ~values_first_mode:false 1;
  [%expect
    {|
    6
    [track] anonymous @ test/test_expect_test.ml:953:27-954:70
      x = 3
      [track] fun:test_expect_test:954 @ test/test_expect_test.ml:954:50-954:70
        i = 0
      [track] fun:test_expect_test:954 @ test/test_expect_test.ml:954:50-954:70
        i = 1
      [track] fun:test_expect_test:954 @ test/test_expect_test.ml:954:50-954:70
        i = 2
      [track] fun:test_expect_test:954 @ test/test_expect_test.ml:954:50-954:70
        i = 3
    |}]
(* $MDX part-end *)

let%expect_test "%track_show anonymous fun, num children exceeded" =
  let run_num = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file_base in
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
  let db = Minidebug_client.Client.open_db (db_file_for_run run_num) in
  Minidebug_client.Client.show_trace db ~values_first_mode:false 1;
  [%expect
    {|
    Raised exception: ppx_minidebug: max_num_children exceeded
    [track] loop_exceeded @ test/test_expect_test.ml:984:35-992:72
      x = 3
      [track] fun:test_expect_test:990 @ test/test_expect_test.ml:990:11-992:71
        i = 0
        [track] z @ test/test_expect_test.ml:991:17-991:18
          z => 1
        [track] else:test_expect_test:992 @ test/test_expect_test.ml:992:35-992:70
          [track] loop_exceeded @ test/test_expect_test.ml:984:35-992:72
            x = 2
            [track] fun:test_expect_test:990 @ test/test_expect_test.ml:990:11-992:71
              i = 0
              [track] z @ test/test_expect_test.ml:991:17-991:18
                z => 0
              [track] else:test_expect_test:992 @ test/test_expect_test.ml:992:35-992:70
                [track] loop_exceeded @ test/test_expect_test.ml:984:35-992:72
                  x = 1
                  [track] fun:test_expect_test:990 @ test/test_expect_test.ml:990:11-992:71
                    i = 0
                    [track] z @ test/test_expect_test.ml:991:17-991:18
                      z => 0
                    [track] else:test_expect_test:992 @ test/test_expect_test.ml:992:35-992:70
                      [track] loop_exceeded @ test/test_expect_test.ml:984:35-992:72
                        x = 0
                        [track] fun:test_expect_test:990 @ test/test_expect_test.ml:990:11-992:71
                          i = 0
                          [track] z @ test/test_expect_test.ml:991:17-991:18
                            z => 0
                          then:test_expect_test:992 =
                        [track] fun:test_expect_test:990 @ test/test_expect_test.ml:990:11-992:71
                          i = 1
                          [track] z @ test/test_expect_test.ml:991:17-991:18
                            z => 1
                          then:test_expect_test:992 =
                        [track] fun:test_expect_test:990 @ test/test_expect_test.ml:990:11-992:71
                          i = 2
                          [track] z @ test/test_expect_test.ml:991:17-991:18
                            z => 2
                          then:test_expect_test:992 =
                        [track] fun:test_expect_test:990 @ test/test_expect_test.ml:990:11-992:71
                          i = 3
                          [track] z @ test/test_expect_test.ml:991:17-991:18
                            z => 3
                          then:test_expect_test:992 =
                        [track] fun:test_expect_test:990 @ test/test_expect_test.ml:990:11-992:71
                          i = 4
                          [track] z @ test/test_expect_test.ml:991:17-991:18
                            z => 4
                          then:test_expect_test:992 =
                        [track] fun:test_expect_test:990 @ test/test_expect_test.ml:990:11-992:71
                          i = 5
                          [track] z @ test/test_expect_test.ml:991:17-991:18
                            z => 5
                          then:test_expect_test:992 =
                        [track] fun:test_expect_test:990 @ test/test_expect_test.ml:990:11-992:71
                          i = 6
                          [track] z @ test/test_expect_test.ml:991:17-991:18
                            z => 6
                          then:test_expect_test:992 =
                        [track] fun:test_expect_test:990 @ test/test_expect_test.ml:990:11-992:71
                          i = 7
                          [track] z @ test/test_expect_test.ml:991:17-991:18
                            z => 7
                          then:test_expect_test:992 =
                        [track] fun:test_expect_test:990 @ test/test_expect_test.ml:990:11-992:71
                          i = 8
                          [track] z @ test/test_expect_test.ml:991:17-991:18
                            z => 8
                          then:test_expect_test:992 =
                        [track] fun:test_expect_test:990 @ test/test_expect_test.ml:990:11-992:71
                          i = 9
                          [track] z @ test/test_expect_test.ml:991:17-991:18
                            z => 9
                          then:test_expect_test:992 =
                        [track] fun:test_expect_test:990 @ test/test_expect_test.ml:990:11-992:71
                          i = 10
                          fun:test_expect_test:990 = <max_num_children exceeded>
    |}]

module type T = sig
  type c

  val c : c
end

let%expect_test "%debug_show function with abstract type" =
  let run_num = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file_base in
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
  let db = Minidebug_client.Client.open_db (db_file_for_run run_num) in
  Minidebug_client.Client.show_trace db ~values_first_mode:false 1;
  [%expect
    {|
    2
    [debug] foo @ test/test_expect_test.ml:1093:21-1094:47
      c = 1
      foo => 2
    |}]

let%expect_test "%debug_show PrintBox values_first_mode to stdout with exception" =
  let run_num = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file_base in
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
  let db = Minidebug_client.Client.open_db (db_file_for_run run_num) in
  Minidebug_client.Client.show_trace db ~values_first_mode:true 1;
  [%expect
    {|
    Raised exception.
    [debug] loop_truncated @ test/test_expect_test.ml:1124:36-1127:36
      x = 7
      [debug] z => 3 @ test/test_expect_test.ml:1125:8-1125:9
      [debug] loop_truncated @ test/test_expect_test.ml:1124:36-1127:36
        x = 6
        [debug] z => 2 @ test/test_expect_test.ml:1125:8-1125:9
        [debug] loop_truncated @ test/test_expect_test.ml:1124:36-1127:36
          x = 5
          [debug] z => 2 @ test/test_expect_test.ml:1125:8-1125:9
          [debug] loop_truncated @ test/test_expect_test.ml:1124:36-1127:36
            x = 4
            [debug] z => 1 @ test/test_expect_test.ml:1125:8-1125:9
            [debug] loop_truncated @ test/test_expect_test.ml:1124:36-1127:36
              x = 3
              [debug] z => 1 @ test/test_expect_test.ml:1125:8-1125:9
              [debug] loop_truncated @ test/test_expect_test.ml:1124:36-1127:36
                x = 2
                [debug] z => 0 @ test/test_expect_test.ml:1125:8-1125:9
                [debug] loop_truncated @ test/test_expect_test.ml:1124:36-1127:36
                  x = 1
                  [debug] z => 0 @ test/test_expect_test.ml:1125:8-1125:9
                  [debug] loop_truncated @ test/test_expect_test.ml:1124:36-1127:36
                    x = 0
                    [debug] z => 0 @ test/test_expect_test.ml:1125:8-1125:9
    |}]

let%expect_test "%debug_show values_first_mode to stdout num children exceeded linear" =
  let run_num = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file_base in
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
  let db = Minidebug_client.Client.open_db (db_file_for_run run_num) in
  Minidebug_client.Client.show_trace db ~values_first_mode:true 1;
  [%expect
    {|
    Raised exception: ppx_minidebug: max_num_children exceeded
    [debug] _bar @ test/test_expect_test.ml:1172:21-1172:25
      [debug] _baz => 0 @ test/test_expect_test.ml:1176:16-1176:20
      [debug] _baz => 2 @ test/test_expect_test.ml:1176:16-1176:20
      [debug] _baz => 4 @ test/test_expect_test.ml:1176:16-1176:20
      [debug] _baz => 6 @ test/test_expect_test.ml:1176:16-1176:20
      [debug] _baz => 8 @ test/test_expect_test.ml:1176:16-1176:20
      [debug] _baz => 10 @ test/test_expect_test.ml:1176:16-1176:20
      [debug] _baz => 12 @ test/test_expect_test.ml:1176:16-1176:20
      [debug] _baz => 14 @ test/test_expect_test.ml:1176:16-1176:20
      [debug] _baz => 16 @ test/test_expect_test.ml:1176:16-1176:20
      [debug] _baz => 18 @ test/test_expect_test.ml:1176:16-1176:20
      [debug] _baz => 20 @ test/test_expect_test.ml:1176:16-1176:20
      [debug] _baz @ test/test_expect_test.ml:1176:16-1176:20
        _baz = <max_num_children exceeded>
    |}]

let%expect_test "%track_show values_first_mode to stdout track for-loop" =
  let run_num = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file_base in
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
  let db = Minidebug_client.Client.open_db (db_file_for_run run_num) in
  Minidebug_client.Client.show_trace db ~values_first_mode:true 1;
  [%expect
    {|
    [track] _bar => () @ test/test_expect_test.ml:1212:21-1212:25
      [track] for:test_expect_test:1215 @ test/test_expect_test.ml:1215:10-1218:14
        [track] <for i> @ test/test_expect_test.ml:1215:14-1215:15
          i = 0
          [track] _baz => 0 @ test/test_expect_test.ml:1216:16-1216:20
        [track] <for i> @ test/test_expect_test.ml:1215:14-1215:15
          i = 1
          [track] _baz => 2 @ test/test_expect_test.ml:1216:16-1216:20
        [track] <for i> @ test/test_expect_test.ml:1215:14-1215:15
          i = 2
          [track] _baz => 4 @ test/test_expect_test.ml:1216:16-1216:20
        [track] <for i> @ test/test_expect_test.ml:1215:14-1215:15
          i = 3
          [track] _baz => 6 @ test/test_expect_test.ml:1216:16-1216:20
        [track] <for i> @ test/test_expect_test.ml:1215:14-1215:15
          i = 4
          [track] _baz => 8 @ test/test_expect_test.ml:1216:16-1216:20
        [track] <for i> @ test/test_expect_test.ml:1215:14-1215:15
          i = 5
          [track] _baz => 10 @ test/test_expect_test.ml:1216:16-1216:20
        [track] <for i> @ test/test_expect_test.ml:1215:14-1215:15
          i = 6
          [track] _baz => 12 @ test/test_expect_test.ml:1216:16-1216:20
    |}]

let%expect_test "%debug_show values_first_mode to stdout num children exceeded nested" =
  let run_num = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file_base in
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
  let db = Minidebug_client.Client.open_db (db_file_for_run run_num) in
  Minidebug_client.Client.show_trace db ~values_first_mode:true 1;
  [%expect
    {|
    Raised exception: ppx_minidebug: max_num_children exceeded
    [debug] loop_exceeded @ test/test_expect_test.ml:1258:35-1266:72
      x = 3
      [debug] z => 1 @ test/test_expect_test.ml:1265:17-1265:18
      [debug] loop_exceeded @ test/test_expect_test.ml:1258:35-1266:72
        x = 2
        [debug] z => 0 @ test/test_expect_test.ml:1265:17-1265:18
        [debug] loop_exceeded @ test/test_expect_test.ml:1258:35-1266:72
          x = 1
          [debug] z => 0 @ test/test_expect_test.ml:1265:17-1265:18
          [debug] loop_exceeded @ test/test_expect_test.ml:1258:35-1266:72
            x = 0
            [debug] z => 0 @ test/test_expect_test.ml:1265:17-1265:18
            [debug] z => 1 @ test/test_expect_test.ml:1265:17-1265:18
            [debug] z => 2 @ test/test_expect_test.ml:1265:17-1265:18
            [debug] z => 3 @ test/test_expect_test.ml:1265:17-1265:18
            [debug] z => 4 @ test/test_expect_test.ml:1265:17-1265:18
            [debug] z => 5 @ test/test_expect_test.ml:1265:17-1265:18
            [debug] z => 6 @ test/test_expect_test.ml:1265:17-1265:18
            [debug] z => 7 @ test/test_expect_test.ml:1265:17-1265:18
            [debug] z => 8 @ test/test_expect_test.ml:1265:17-1265:18
            [debug] z => 9 @ test/test_expect_test.ml:1265:17-1265:18
            [debug] z @ test/test_expect_test.ml:1265:17-1265:18
              z = <max_num_children exceeded>
    |}]

let%expect_test "%track_show values_first_mode tracking" =
  let run_num = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file_base in
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
  let db = Minidebug_client.Client.open_db (db_file_for_run run_num) in
  Minidebug_client.Client.show_trace db ~values_first_mode:true 1;
  [%expect
    {|
    4
    -3
    [track] track_branches => 4 @ test/test_expect_test.ml:1308:32-1310:46
      x = 7
      [track] else:test_expect_test:1310 @ test/test_expect_test.ml:1310:9-1310:46
        <match -- branch 1> =
    [track] track_branches => -3 @ test/test_expect_test.ml:1308:32-1310:46
      x = 3
      [track] then:test_expect_test:1309 @ test/test_expect_test.ml:1309:18-1309:57
        <match -- branch 2> =
    |}]

let%expect_test "%track_show values_first_mode to stdout no return type anonymous fun" =
  let run_num = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file_base in
    fun () -> rt
  in
  let%track_show anonymous (x : int) =
    Array.fold_left ( + ) 0 @@ Array.init (x + 1) (fun (i : int) -> i)
  in
  let () =
    try print_endline @@ Int.to_string @@ anonymous 3
    with Failure s -> print_endline @@ "Raised exception: " ^ s
  in
  let db = Minidebug_client.Client.open_db (db_file_for_run run_num) in
  Minidebug_client.Client.show_trace db ~values_first_mode:true 1;
  [%expect
    {|
    6
    [track] anonymous @ test/test_expect_test.ml:1340:27-1341:70
      x = 3
      [track] fun:test_expect_test:1341 @ test/test_expect_test.ml:1341:50-1341:70
        i = 0
      [track] fun:test_expect_test:1341 @ test/test_expect_test.ml:1341:50-1341:70
        i = 1
      [track] fun:test_expect_test:1341 @ test/test_expect_test.ml:1341:50-1341:70
        i = 2
      [track] fun:test_expect_test:1341 @ test/test_expect_test.ml:1341:50-1341:70
        i = 3
    |}]

let%expect_test "%debug_show records" =
  let run_num = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file_base in
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
  let db = Minidebug_client.Client.open_db (db_file_for_run run_num) in
  Minidebug_client.Client.show_trace db ~values_first_mode:false 1;
  [%expect
    {|
    336
    109
    [debug] bar @ test/test_expect_test.ml:1370:21-1373:15
      first = 7
      second = 42
      [debug] {first=a; second=b} @ test/test_expect_test.ml:1371:8-1371:45
        a => 7
        b => 45
      [debug] y @ test/test_expect_test.ml:1372:8-1372:9
        y => 8
      bar => 336
    [debug] baz @ test/test_expect_test.ml:1376:21-1378:28
      first = 7
      second = 42
      [debug] {first; second} @ test/test_expect_test.ml:1377:8-1377:37
        first => 8
        second => 45
      baz => 109
    |}]

let%expect_test "%debug_show tuples" =
  let run_num = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file_base in
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
  let db = Minidebug_client.Client.open_db (db_file_for_run run_num) in
  Minidebug_client.Client.show_trace db ~values_first_mode:false 1;
  [%expect
    {|
    336
    339
    109
    [debug] bar @ test/test_expect_test.ml:1411:21-1413:14
      first = 7
      second = 42
      [debug] y @ test/test_expect_test.ml:1412:8-1412:9
        y => 8
      bar => 336
    [debug] (r1, r2) @ test/test_expect_test.ml:1421:17-1421:23
      [debug] baz @ test/test_expect_test.ml:1416:21-1419:35
        first = 7
        second = 42
        [debug] (y, z) @ test/test_expect_test.ml:1417:8-1417:14
          y => 8
          z => 3
        [debug] (a, b) @ test/test_expect_test.ml:1418:8-1418:28
          a => 8
          b => 45
        baz => (339, 109)
      r1 => 339
      r2 => 109
    |}]

let%expect_test "%debug_show records values_first_mode" =
  let run_num = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file_base in
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
  let db = Minidebug_client.Client.open_db (db_file_for_run run_num) in
  Minidebug_client.Client.show_trace db ~values_first_mode:true 1;
  [%expect
    {|
    336
    109
    [debug] bar => 336 @ test/test_expect_test.ml:1458:21-1461:15
      first = 7
      second = 42
      [debug] {first=a; second=b} @ test/test_expect_test.ml:1459:8-1459:45
        a => 7
        b => 45
      [debug] y => 8 @ test/test_expect_test.ml:1460:8-1460:9
    [debug] baz => 109 @ test/test_expect_test.ml:1464:21-1466:28
      first = 7
      second = 42
      [debug] {first; second} @ test/test_expect_test.ml:1465:8-1465:37
        first => 8
        second => 45
    |}]

let%expect_test "%debug_show tuples values_first_mode" =
  let run_num = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file_base in
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
  let db = Minidebug_client.Client.open_db (db_file_for_run run_num) in
  Minidebug_client.Client.show_trace db ~values_first_mode:true 1;
  [%expect
    {|
    336
    339
    109
    [debug] bar => 336 @ test/test_expect_test.ml:1496:21-1498:14
      first = 7
      second = 42
      [debug] y => 8 @ test/test_expect_test.ml:1497:8-1497:9
    [debug] (r1, r2) @ test/test_expect_test.ml:1506:17-1506:23
      r1 => 339
      r2 => 109
      [debug] baz => (339, 109) @ test/test_expect_test.ml:1501:21-1504:35
        first = 7
        second = 42
        [debug] (y, z) @ test/test_expect_test.ml:1502:8-1502:14
          y => 8
          z => 3
        [debug] (a, b) @ test/test_expect_test.ml:1503:8-1503:28
          a => 8
          b => 45
    |}]

type 'a irrefutable = Zero of 'a
type ('a, 'b) left_right = Left of 'a | Right of 'b
type ('a, 'b, 'c) one_two_three = One of 'a | Two of 'b | Three of 'c

let%expect_test "%track_show variants values_first_mode" =
  let run_num = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file_base in
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
  let db = Minidebug_client.Client.open_db (db_file_for_run run_num) in
  Minidebug_client.Client.show_trace db ~values_first_mode:true 1;
  [%expect
    {|
    16
    5
    6
    3
    [track] bar => 16 @ test/test_expect_test.ml:1544:21-1546:9
      x = 7
      [track] y => 8 @ test/test_expect_test.ml:1545:8-1545:9
    [track] <function -- branch 0> Left x => baz = 5 @ test/test_expect_test.ml:1550:24-1550:29
      x = 4
    [track] <function -- branch 1> Right Two y => baz = 6 @ test/test_expect_test.ml:1551:31-1551:36
      y = 3
    [track] foo => 3 @ test/test_expect_test.ml:1554:21-1555:82
      <match -- branch 2> =
    |}]

let%expect_test "%debug_show tuples merge type info" =
  let run_num = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file_base in
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
  let db = Minidebug_client.Client.open_db (db_file_for_run run_num) in
  Minidebug_client.Client.show_trace db 1;
  (* Note the missing value of [b]: the nested-in-expression type is not propagated. *)
  [%expect
    {|
    339
    109
    [debug] (r1, r2) @ test/test_expect_test.ml:1590:17-1590:38
      r1 => 339
      r2 => 109
      [debug] baz => (339, 109) @ test/test_expect_test.ml:1585:21-1588:35
        first = 7
        second = 42
        [debug] (y, z) @ test/test_expect_test.ml:1586:8-1586:29
          y => 8
          z => 3
        [debug] (a, b) => a = 8 @ test/test_expect_test.ml:1587:8-1587:20
    |}]

let%expect_test "%debug_show decompose multi-argument function type" =
  let run_num = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file_base in
    fun () -> rt
  in
  let%debug_show f : 'a. 'a -> int -> int = fun _a b -> b + 1 in
  let%debug_show g : 'a. 'a -> int -> 'a -> 'a -> int = fun _a b _c _d -> b * 2 in
  let () = print_endline @@ Int.to_string @@ f 'a' 6 in
  let () = print_endline @@ Int.to_string @@ g 'a' 6 'b' 'c' in
  let db = Minidebug_client.Client.open_db (db_file_for_run run_num) in
  Minidebug_client.Client.show_trace db 1;
  [%expect
    {|
    7
    12
    [debug] f => 7 @ test/test_expect_test.ml:1618:44-1618:61
      b = 6
    [debug] g => 12 @ test/test_expect_test.ml:1619:56-1619:79
      b = 6
    |}]

let%expect_test "%debug_show debug type info" =
  let run_num = next_run () in
  (* $MDX part-begin=debug_type_info *)
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file_base in
    fun () -> rt
  in
  [%debug_show
    [%debug_type_info
      let f : 'a. 'a -> int -> int = fun _a b -> b + 1 in
      let g : 'a. 'a -> int -> 'a -> 'a -> int = fun _a b _c _d -> b * 2 in
      let () = print_endline @@ Int.to_string @@ f 'a' 6 in
      print_endline @@ Int.to_string @@ g 'a' 6 'b' 'c']];
  let db = Minidebug_client.Client.open_db (db_file_for_run run_num) in
  Minidebug_client.Client.show_trace db 1;
  [%expect
    {|
    7
    12
    [debug] f : int => 7 @ test/test_expect_test.ml:1643:37-1643:54
      b : int = 6
    [debug] g : int => 12 @ test/test_expect_test.ml:1644:49-1644:72
      b : int = 6
    |}]
(* $MDX part-end *)

let%expect_test "%track_show options values_first_mode" =
  let run_num = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file_base in
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
  let db = Minidebug_client.Client.open_db (db_file_for_run run_num) in
  Minidebug_client.Client.show_trace db ~values_first_mode:true 1;
  [%expect
    {|
    14
    14
    8
    9
    [track] foo => 14 @ test/test_expect_test.ml:1666:21-1667:59
      [track] <match -- branch 1> Some y @ test/test_expect_test.ml:1667:54-1667:59
        y = 7
    [track] bar => 14 @ test/test_expect_test.ml:1670:21-1671:44
      l = (Some 7)
      <match -- branch 1> Some y =
    [track] <function -- branch 1> Some y => baz = 8 @ test/test_expect_test.ml:1674:74-1674:79
      y = 4
    [track] <function -- branch 1> Some (y, z) => zoo = 9 @ test/test_expect_test.ml:1678:21-1678:26
      y = 4
      z = 5
    |}]

let%expect_test "%track_show list values_first_mode" =
  let run_num = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file_base in
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
  let db = Minidebug_client.Client.open_db (db_file_for_run run_num) in
  Minidebug_client.Client.show_trace db ~values_first_mode:true 1;
  [%expect
    {|
    14
    14
    8
    9
    10
    [track] foo => 14 @ test/test_expect_test.ml:1708:21-1708:82
      [track] <match -- branch 1> :: (y, _) @ test/test_expect_test.ml:1708:77-1708:82
        y = 7
    [track] bar => 14 @ test/test_expect_test.ml:1710:21-1710:82
      l = [7]
      <match -- branch 1> :: (y, _) =
    [track] <function -- branch 1> :: (y, []) => baz = 8 @ test/test_expect_test.ml:1714:15-1714:20
      y = 4
    [track] <function -- branch 2> :: (y, :: (z, [])) => baz = 9 @ test/test_expect_test.ml:1715:18-1715:23
      y = 4
      z = 5
    [track] <function -- branch 3> :: (y, :: (z, _)) => baz = 10 @ test/test_expect_test.ml:1716:21-1716:30
      y = 4
      z = 5
    |}]

let%expect_test "%track_rt_show list runtime passing" =
  (* $MDX part-begin=track_rt_show_list_runtime_passing *)
  let rt run_name = Minidebug_db.debug_db_file ~run_name db_file_base in
  let%track_rt_show foo l : int = match (l : int list) with [] -> 7 | y :: _ -> y * 2 in
  let () = print_endline @@ Int.to_string @@ foo (rt "foo-1") [ 7 ] in
  Minidebug_client.Client.show_trace (latest_run ()) ~values_first_mode:true 1;
  let%track_rt_show baz : int list -> int = function
    | [] -> 7
    | [ y ] -> y * 2
    | [ y; z ] -> y + z
    | y :: z :: _ -> y + z + 1
  in
  let () = print_endline @@ Int.to_string @@ baz (rt "baz-1") [ 4 ] in
  Minidebug_client.Client.show_trace (latest_run ()) ~values_first_mode:true 1;
  let () = print_endline @@ Int.to_string @@ baz (rt "baz-2") [ 4; 5; 6 ] in
  Minidebug_client.Client.show_trace (latest_run ()) ~values_first_mode:true 1;
  [%expect
    {|
    14
    latest_run: (no-name)
    [track] foo => 14 @ test/test_expect_test.ml:1749:24-1749:85
      [track] <match -- branch 1> :: (y, _) @ test/test_expect_test.ml:1749:80-1749:85
        y = 7
    8
    latest_run: (no-name)
    [track] <function -- branch 1> :: (y, []) => baz = 8 @ test/test_expect_test.ml:1754:15-1754:20
      y = 4
    10
    latest_run: (no-name)
    [track] <function -- branch 3> :: (y, :: (z, _)) => baz = 10 @ test/test_expect_test.ml:1756:21-1756:30
      y = 4
      z = 5
    |}]
(* $MDX part-end *)

let%expect_test "%track_rt_show procedure runtime passing" =
  let rt run_name = Minidebug_db.debug_db_file ~run_name db_file_base in
  let%track_rt_show bar () = (fun () -> ()) () in
  let () = bar (rt "bar-1") () in
  Minidebug_client.Client.show_trace (latest_run ()) 1;
  let () = bar (rt "bar-2") () in
  Minidebug_client.Client.show_trace (latest_run ()) 1;
  let%track_rt_show foo () =
    let () = () in
    ()
  in
  let () = foo (rt "foo-1") () in
  Minidebug_client.Client.show_trace (latest_run ()) 1;
  let () = foo (rt "foo-2") () in
  Minidebug_client.Client.show_trace (latest_run ()) 1;
  [%expect
    {|
    latest_run: (no-name)
    [track] bar @ test/test_expect_test.ml:1783:24-1783:46
      fun:test_expect_test:1783 =
    latest_run: (no-name)
    [track] bar @ test/test_expect_test.ml:1783:24-1783:46
      fun:test_expect_test:1783 =
    latest_run: (no-name)
    foo =
    latest_run: (no-name)
    foo =
    |}]

let%expect_test "%track_rt_show nested procedure runtime passing" =
  let rt run_name = Minidebug_db.debug_db_file ~run_name db_file_base in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file_base in
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
  let () = foo (rt "foo-1") () in
  Minidebug_client.Client.show_trace (latest_run ()) 1;
  let () = foo (rt "foo-2") () in
  Minidebug_client.Client.show_trace (latest_run ()) 1;
  let () = bar (rt "bar-1") () in
  Minidebug_client.Client.show_trace (latest_run ()) 1;
  let () = bar (rt "bar-2") () in
  Minidebug_client.Client.show_trace (latest_run ()) 1;
  [%expect
    {|
    latest_run: (no-name)
    foo =
    latest_run: (no-name)
    foo =
    latest_run: (no-name)
    [track] bar @ test/test_expect_test.ml:1817:26-1817:48
      fun:test_expect_test:1817 =
    latest_run: (no-name)
    [track] bar @ test/test_expect_test.ml:1817:26-1817:48
      fun:test_expect_test:1817 =
    |}]

let%expect_test "%log constant entries" =
  let run_num1 = next_run () in
  let rt1 = Minidebug_db.debug_db_file db_file_base in
  let _get_local_debug_runtime = fun () -> rt1 in
  let%debug_show foo () : unit =
    [%log "This is the first log line"];
    [%log [ "This is the"; "2"; "log line" ]];
    [%log "This is the", 3, "or", 3.14, "log line"]
  in
  let () = foo () in
  let db = Minidebug_client.Client.open_db (db_file_for_run run_num1) in
  Minidebug_client.Client.show_trace db 1;
  let run_num2 = next_run () in
  let rt2 = Minidebug_db.debug_db_file db_file_base in
  let _get_local_debug_runtime = fun () -> rt2 in
  let%debug_sexp bar () : unit =
    [%log "This is the first log line"];
    [%log [ "This is the"; "2"; "log line" ]];
    [%log "This is the", 3, "or", 3.14, "log line"]
  in
  let () = bar () in
  let db = Minidebug_client.Client.open_db (db_file_for_run run_num2) in
  Minidebug_client.Client.show_trace db 1;
  [%expect
    {|
    [debug] foo => () @ test/test_expect_test.ml:1851:21-1854:51
      "This is the first log line"
      ["This is the"; "2"; "log line"]
      ("This is the", 3, "or", 3.14, "log line")
    [debug] bar @ test/test_expect_test.ml:1862:21-1865:51
      "This is the first log line"
      ("This is the" 2 "log line")
      ("This is the" 3 or 3.14 "log line")
    |}]

let%expect_test "%log with type annotations" =
  let run_num = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file_base in
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
  let db = Minidebug_client.Client.open_db (db_file_for_run run_num) in
  Minidebug_client.Client.show_trace db 1;
  [%expect
    {|
    [debug] foo => () @ test/test_expect_test.ml:1891:21-1896:25
      ("This is like", 3, "or", 3.14, "above")
      ("tau =", 6.28)
      [4; 1; 2; 3]
      [3; 1; 2; 3]
      [3; 1; 2; 3]
    |}]

let%expect_test "%log with default type assumption" =
  let run_num = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file_base in
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
  let db = Minidebug_client.Client.open_db (db_file_for_run run_num) in
  Minidebug_client.Client.show_trace db 1;
  [%expect
    {|
    [debug] foo => () @ test/test_expect_test.ml:1921:21-1928:25
      "2*3"
      ("This is like", "3", "or", "3.14", "above")
      ("tau =", "2*3.14")
      [("2*3", 0); ("1", 1); ("2", 2); ("3", 3)]
    |}]

let%expect_test "%log track while-loop" =
  let run_num = next_run () in
  (* $MDX part-begin=track_while_loop_example *)
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file_base in
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
  let () = print_endline @@ Int.to_string result in
  let db = Minidebug_client.Client.open_db (db_file_for_run run_num) in
  Minidebug_client.Client.show_trace db 1;
  [%expect
    {|
    21
    [track] result @ test/test_expect_test.ml:1949:17-1949:23
      [track] while:test_expect_test:1952 @ test/test_expect_test.ml:1952:4-1958:8
        [track] <while loop> @ test/test_expect_test.ml:1953:6-1957:32
          (1 i= 0)
          (2 i= 1)
          (3 j= 1)
        [track] <while loop> @ test/test_expect_test.ml:1953:6-1957:32
          (1 i= 1)
          (2 i= 2)
          (3 j= 3)
        [track] <while loop> @ test/test_expect_test.ml:1953:6-1957:32
          (1 i= 2)
          (2 i= 3)
          (3 j= 6)
        [track] <while loop> @ test/test_expect_test.ml:1953:6-1957:32
          (1 i= 3)
          (2 i= 4)
          (3 j= 10)
        [track] <while loop> @ test/test_expect_test.ml:1953:6-1957:32
          (1 i= 4)
          (2 i= 5)
          (3 j= 15)
        [track] <while loop> @ test/test_expect_test.ml:1953:6-1957:32
          (1 i= 5)
          (2 i= 6)
          (3 j= 21)
    |}]
(* $MDX part-end *)

let%expect_test "%log runtime log levels while-loop" =
  (* $MDX part-begin=log_runtime_log_levels_while_loop_example *)
  let run_num = next_run () in
  let rt log_level run_name = Minidebug_db.debug_db_file ~log_level ~run_name db_file_base in
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
  print_endline @@ Int.to_string (result (rt 9 "Everything") ());
  Minidebug_client.Client.show_trace (latest_run ()) 1;
  print_endline @@ Int.to_string (result (rt 0 "Nothing") ());
  let latest_run_after_nothing =
    Minidebug_client.Client.open_db (db_file_for_run run_num)
    |> Minidebug_client.Client.get_latest_run |> Option.get
  in
  print_endline @@ "latest_run_after_nothing: "
  ^ Option.get latest_run_after_nothing.run_name;
  print_endline @@ Int.to_string (result (rt 1 "Error") ());
  (* $MDX part-end *)
  Minidebug_client.Client.show_trace (latest_run ()) 1;
  print_endline @@ Int.to_string (result (rt 2 "Warning") ());
  Minidebug_client.Client.show_trace (latest_run ()) 1;
  (* FIXME: THIS TEST IS NOT WORKING AND EXPECTATION IS WRONG *)
  [%expect.unreachable]
[@@expect.uncaught_exn {|
  (* CR expect_test_collector: This test expectation appears to contain a backtrace.
     This is strongly discouraged as backtraces are fragile.
     Please change this test to not include a backtrace. *)
  ("Sqlite3.Error(\"error opening database: unable to open database file\")")
  Raised by primitive operation at Sqlite3.db_open in file "lib/sqlite3.ml", line 281, characters 2-52
  Called from Minidebug_client.Client.open_db in file "minidebug_client.ml", line 1730, characters 13-52
  Called from Test_inline_tests__Test_expect_test.latest_run in file "test/test_expect_test.ml", line 25, characters 11-50
  Called from Test_inline_tests__Test_expect_test.(fun) in file "test/test_expect_test.ml", line 2014, characters 37-52
  Called from Ppx_expect_runtime__Test_block.Configured.dump_backtrace in file "runtime/test_block.ml", line 142, characters 10-28

  Trailing output
  ---------------
  21
  latest_run: (no-name)
  [track] result => 21 @ test/test_expect_test.ml:1992:27-2003:6
    [track] while:test_expect_test:1995 @ test/test_expect_test.ml:1995:4-2002:8
      [track] <while loop> @ test/test_expect_test.ml:1997:6-2001:42
        [track] then:test_expect_test:1997 @ test/test_expect_test.ml:1997:21-1997:58
          (ERROR: 1 i= 0)
        (WARNING: 2 i= 1)
        fun:test_expect_test:2000 =
        (INFO: 3 j= 1)
      [track] <while loop> @ test/test_expect_test.ml:1997:6-2001:42
        [track] then:test_expect_test:1997 @ test/test_expect_test.ml:1997:21-1997:58
          (ERROR: 1 i= 1)
        (WARNING: 2 i= 2)
        fun:test_expect_test:2000 =
        (INFO: 3 j= 3)
      [track] <while loop> @ test/test_expect_test.ml:1997:6-2001:42
        else:test_expect_test:1997 =
        (WARNING: 2 i= 3)
        fun:test_expect_test:2000 =
        (INFO: 3 j= 6)
      [track] <while loop> @ test/test_expect_test.ml:1997:6-2001:42
        else:test_expect_test:1997 =
        (WARNING: 2 i= 4)
        fun:test_expect_test:2000 =
        (INFO: 3 j= 10)
      [track] <while loop> @ test/test_expect_test.ml:1997:6-2001:42
        else:test_expect_test:1997 =
        (WARNING: 2 i= 5)
        fun:test_expect_test:2000 =
        (INFO: 3 j= 15)
      [track] <while loop> @ test/test_expect_test.ml:1997:6-2001:42
        else:test_expect_test:1997 =
        (WARNING: 2 i= 6)
        fun:test_expect_test:2000 =
        (INFO: 3 j= 21)
  21
  |}]

let%expect_test "%log compile time log levels while-loop" =
  let run_num = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file_base in
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
  let db = Minidebug_client.Client.open_db (db_file_for_run run_num) in
  Minidebug_client.Client.show_trace db 1;
  [%expect
    {|
    21
    21
    21
    [track] everything => 21 @ test/test_expect_test.ml:2078:28-2091:9
      [track] while:test_expect_test:2083 @ test/test_expect_test.ml:2083:6-2090:10
        [track] <while loop> @ test/test_expect_test.ml:2085:8-2089:44
          [track] then:test_expect_test:2085 @ test/test_expect_test.ml:2085:23-2085:60
            (ERROR: 1 i= 0)
          (WARNING: 2 i= 1)
          fun:test_expect_test:2088 =
          (INFO: 3 j= 1)
        [track] <while loop> @ test/test_expect_test.ml:2085:8-2089:44
          [track] then:test_expect_test:2085 @ test/test_expect_test.ml:2085:23-2085:60
            (ERROR: 1 i= 1)
          (WARNING: 2 i= 2)
          fun:test_expect_test:2088 =
          (INFO: 3 j= 3)
        [track] <while loop> @ test/test_expect_test.ml:2085:8-2089:44
          else:test_expect_test:2085 =
          (WARNING: 2 i= 3)
          fun:test_expect_test:2088 =
          (INFO: 3 j= 6)
        [track] <while loop> @ test/test_expect_test.ml:2085:8-2089:44
          else:test_expect_test:2085 =
          (WARNING: 2 i= 4)
          fun:test_expect_test:2088 =
          (INFO: 3 j= 10)
        [track] <while loop> @ test/test_expect_test.ml:2085:8-2089:44
          else:test_expect_test:2085 =
          (WARNING: 2 i= 5)
          fun:test_expect_test:2088 =
          (INFO: 3 j= 15)
        [track] <while loop> @ test/test_expect_test.ml:2085:8-2089:44
          else:test_expect_test:2085 =
          (WARNING: 2 i= 6)
          fun:test_expect_test:2088 =
          (INFO: 3 j= 21)
    [track] nothing => 21 @ test/test_expect_test.ml:2093:25-2107:9
    [track] warning => 21 @ test/test_expect_test.ml:2109:25-2124:9
      [track] while:test_expect_test:2114 @ test/test_expect_test.ml:2114:6-2123:10
        [track] <while loop> @ test/test_expect_test.ml:2116:8-2122:47
          (ERROR: 1 i= 0)
          (WARNING: 2 i= 1)
        [track] <while loop> @ test/test_expect_test.ml:2116:8-2122:47
          (ERROR: 1 i= 1)
          (WARNING: 2 i= 2)
        [track] <while loop> @ test/test_expect_test.ml:2116:8-2122:47
          (WARNING: 2 i= 3)
        [track] <while loop> @ test/test_expect_test.ml:2116:8-2122:47
          (WARNING: 2 i= 4)
        [track] <while loop> @ test/test_expect_test.ml:2116:8-2122:47
          (WARNING: 2 i= 5)
        [track] <while loop> @ test/test_expect_test.ml:2116:8-2122:47
          (WARNING: 2 i= 6)
    |}]

let%expect_test "%log track while-loop result" =
  let run_num = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file_base in
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
  let db = Minidebug_client.Client.open_db (db_file_for_run run_num) in
  Minidebug_client.Client.show_trace db ~values_first_mode:false 1;
  [%expect
    {|
    21
    [track] result @ test/test_expect_test.ml:2195:17-2195:23
      [track] while:test_expect_test:2198 @ test/test_expect_test.ml:2198:4-2204:8
        [track] <while loop> @ test/test_expect_test.ml:2199:6-2203:39
          (1 i= 0)
          (2 i= 1)
          => => (3 j= 1)
        [track] <while loop> @ test/test_expect_test.ml:2199:6-2203:39
          (1 i= 1)
          (2 i= 2)
          => => (3 j= 3)
        [track] <while loop> @ test/test_expect_test.ml:2199:6-2203:39
          (1 i= 2)
          (2 i= 3)
          => => (3 j= 6)
        [track] <while loop> @ test/test_expect_test.ml:2199:6-2203:39
          (1 i= 3)
          (2 i= 4)
          => => (3 j= 10)
        [track] <while loop> @ test/test_expect_test.ml:2199:6-2203:39
          (1 i= 4)
          (2 i= 5)
          => => (3 j= 15)
        [track] <while loop> @ test/test_expect_test.ml:2199:6-2203:39
          (1 i= 5)
          (2 i= 6)
          => => (3 j= 21)
      => => 21
    |}]

let%expect_test "%log without scope" =
  let run_num = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file ~print_entry_ids:true db_file_base in
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
  let db = Minidebug_client.Client.open_db (db_file_for_run run_num) in
  Minidebug_client.Client.show_trace db ~values_first_mode:false 1;
  [%expect
    {|
    [debug] _bar @ test/test_expect_test.ml:2256:17-2256:21
      _bar => ()
      ("This is like", 3, "or", 3.14, "above")
      ("tau =", 6.28)
      [4; 1; 2; 3]
      [3; 1; 2; 3]
      [3; 1; 2; 3]
    |}]

let%expect_test "%log without scope values_first_mode" =
  let run_num = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file ~print_entry_ids:true db_file_base in
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
  let () = !foo () in
  let db = Minidebug_client.Client.open_db (db_file_for_run run_num) in
  Minidebug_client.Client.show_trace db ~values_first_mode:true 1;
  [%expect
    {|
    [debug] _bar => () @ test/test_expect_test.ml:2289:17-2289:21
      ("This is like", 3, "or", 3.14, "above")
      ("tau =", 6.28)
      [4; 1; 2; 3]
      [3; 1; 2; 3]
      [3; 1; 2; 3]
      ("This is like", 3, "or", 3.14, "above")
      ("tau =", 6.28)
      [4; 1; 2; 3]
      [3; 1; 2; 3]
      [3; 1; 2; 3]
    |}]

let%expect_test "%log with print_entry_ids, mixed up scopes" =
  (* $MDX part-begin=log_with_print_entry_ids_mixed_up_scopes *)
  let run_num = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file ~print_entry_ids:true db_file_base in
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
  let db = Minidebug_client.Client.open_db (db_file_for_run run_num) in
  Minidebug_client.Client.show_trace db 1;
  [%expect
    {|
    [debug] bar => () @ test/test_expect_test.ml:2330:21-2335:19
      ("This is like", 3, "or", 3.14, "above")
      ("tau =", 6.28)
      ("This is like", 3, "or", 3.14, "above")
      ("tau =", 6.28)
    [debug] baz => () @ test/test_expect_test.ml:2337:21-2342:19
      [3; 1; 2; 3]
      [3; 1; 2; 3]
      [3; 1; 2; 3]
      [3; 1; 2; 3]
    [debug] bar => () @ test/test_expect_test.ml:2330:21-2335:19
      ("This is like", 3, "or", 3.14, "above")
      ("tau =", 6.28)
    [debug] _foobar => () @ test/test_expect_test.ml:2349:17-2349:24
    |}]
(* $MDX part-end *)

let%expect_test "%diagn_show ignores type annots" =
  let run_num = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file_base in
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
  let db = Minidebug_client.Client.open_db (db_file_for_run run_num) in
  Minidebug_client.Client.show_trace db 1;
  [%expect
    {|
    336
    109
    [diagn] toplevel @ test/test_expect_test.ml:2378:17-2378:25
      ("for bar, b-3", 42)
      ("for baz, f squared", 64)
    |}]

let%expect_test "%diagn_show ignores non-empty bindings" =
  (* $MDX part-begin=diagn_show_ignores_bindings *)
  let run_num = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file_base in
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
  let db = Minidebug_client.Client.open_db (db_file_for_run run_num) in
  Minidebug_client.Client.show_trace db 1;
  [%expect
    {|
    336
    91
    [diagn] bar @ test/test_expect_test.ml:2412:21-2416:15
      ("for bar, b-3", 42)
    [diagn] baz @ test/test_expect_test.ml:2419:21-2424:25
      ("foo baz, f squared", 49)
    |}]
(* $MDX part-end *)

let%expect_test "%diagn_show no logs" =
  let run_num = next_run () in
  let db = Minidebug_client.Client.open_db (db_file_for_run run_num) in
  let latest_run_before = db |> Minidebug_client.Client.get_latest_run |> Option.get in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file_base in
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
  let latest_run_after = db |> Minidebug_client.Client.get_latest_run |> Option.get in
  print_endline @@ "latest_run_before: " ^ Int.to_string latest_run_before.run_id;
  print_endline @@ "latest_run_after: " ^ Int.to_string latest_run_after.run_id;
  print_endline @@ "run_counter: " ^ Int.to_string !run_counter;
  [%expect
    {|
    336
    91
    latest_run_before: 63
    latest_run_after: 63
    run_counter: 63
  |}]

let%expect_test "%debug_show log level compile time" =
  let run_num = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file_base in
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
  let db = Minidebug_client.Client.open_db (db_file_for_run run_num) in
  Minidebug_client.Client.show_trace db 1;
  [%expect
    {|
    336
    336
    109
    [debug] () @ test/test_expect_test.ml:2477:18-2477:20
      [debug] baz => 109 @ test/test_expect_test.ml:2492:26-2495:32
        first = 7
        second = 42
        [debug] {first; second} @ test/test_expect_test.ml:2493:12-2493:41
          first => 8
          second => 45
        ("for baz, f squared", 64)
    |}]

let%expect_test "%debug_show log level runtime" =
  (* $MDX part-begin=debug_show_log_level_runtime *)
  let run_num = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file ~log_level:2 db_file_base in
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
  let db = Minidebug_client.Client.open_db (db_file_for_run run_num) in
  Minidebug_client.Client.show_trace db 1;
  [%expect
    {|
    336
    336
    109
    [debug] baz => 109 @ test/test_expect_test.ml:2538:24-2541:30
      first = 7
      second = 42
      [debug] {first; second} @ test/test_expect_test.ml:2539:10-2539:39
        first => 8
        second => 45
      ("for baz, f squared", 64)
    |}]
(* $MDX part-end *)

let%expect_test "%track_show don't show unannotated non-function bindings" =
  let run_num = next_run () in
  let db = Minidebug_client.Client.open_db (db_file_for_run run_num) in
  let latest_run_before = db |> Minidebug_client.Client.get_latest_run |> Option.get in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file ~log_level:3 db_file_base in
    fun () -> rt
  in
  let () =
    [%track_show
      let%ppx_minidebug_noop_for_testing point =
        let open! Minidebug_runtime in
        (1, 2)
      in
      ignore point]
  in
  let latest_run_after = db |> Minidebug_client.Client.get_latest_run |> Option.get in
  print_endline @@ "latest_run_before: " ^ Int.to_string latest_run_before.run_id;
  print_endline @@ "latest_run_after: " ^ Int.to_string latest_run_after.run_id;
  print_endline @@ "run_counter: " ^ Int.to_string !run_counter;
  [%expect
    {|
    latest_run_before: 65
    latest_run_after: 65
    run_counter: 65
    |}]

let%expect_test "%log_printbox" =
  (* $MDX part-begin=log_printbox *)
  let run_num = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file_base in
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
  let _ = latest_run () in
  let db = Minidebug_client.Client.open_db (db_file_for_run run_num) in
  Minidebug_client.Client.show_trace db 1;
  [%expect
    {|
    latest_run: (no-name)
    [debug] foo => () @ test/test_expect_test.ml:2596:21-2609:91
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
    |}]
(* $MDX part-end *)

let%expect_test "%log_entry" =
  (* $MDX part-begin=log_entry *)
  let _ = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file_base in
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
  Minidebug_client.Client.show_trace (latest_run ()) 1;
  [%expect
    {|
    latest_run: (no-name)
    [diagn] _logging_logic @ test/test_expect_test.ml:2664:17-2664:31
      "preamble"
      [diagn] header 1 @ :0:0-0:0
        "log 1"
        [diagn] nested header @ :0:0-0:0
          "log 2"
        "log 3"
      [diagn] header 2 @ :0:0-0:0
        "log 4"
      "postscript"
    |}]
(* $MDX part-end *)

let%expect_test "%debug_show skip module bindings" =
  let optional v thunk = match v with Some v -> v | None -> thunk () in
  let run_num = next_run () in
  let module Debug_runtime = (val Minidebug_db.debug_db_file db_file_base) in
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
  let db = Minidebug_client.Client.open_db (db_file_for_run run_num) in
  Minidebug_client.Client.show_trace db 1;
  [%expect
    {|
    15
    [track] bar => 15 @ test/test_expect_test.ml:2722:23-2730:9
      x = 7
      [track] y => 8 @ test/test_expect_test.ml:2724:8-2724:9
    |}]

let%expect_test "%track_show procedure runtime prefixes" =
  (* $MDX part-begin=track_show_procedure_runtime_prefixes *)
  let run_num = next_run () in
  let i = ref 0 in
  let run_ids = ref [] in
  let _get_local_debug_runtime () =
    let rt = Minidebug_db.debug_db_file ~run_name:("foo-" ^ string_of_int !i) db_file_base in
    run_ids := 1 :: !run_ids;
    rt
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
  let db = Minidebug_client.Client.open_db (db_file_for_run run_num) in
  List.iter
    (fun run_id -> Minidebug_client.Client.show_trace db run_id)
    (List.rev !run_ids);
  [%expect
    {|
    [track] <function -- branch 0> () @ test/test_expect_test.ml:2770:8-2771:27
      "inside bar"
    [track] <function -- branch 0> () @ test/test_expect_test.ml:2770:8-2771:27
      "inside bar"
    [track] <function -- branch 0> () @ test/test_expect_test.ml:2770:8-2771:27
      "inside bar"
    [track] <function -- branch 0> () @ test/test_expect_test.ml:2770:8-2771:27
      "inside bar"
    [track] <function -- branch 0> () @ test/test_expect_test.ml:2770:8-2771:27
      "inside bar"
    [track] <function -- branch 0> () @ test/test_expect_test.ml:2770:8-2771:27
      "inside bar"
    |}]
(* $MDX part-end *)

let%expect_test "%track_rt_show expression runtime passing" =
  let run_num1 = next_run () in
  [%track_rt_show
    [%log_block
      "test A";
      [%log "line A"]]]
    (Minidebug_db.debug_db_file ~run_name:"t1" db_file_base);
  let run_num2 = next_run () in
  [%track_rt_show
    [%log_block
      "test B";
      [%log "line B"]]]
    (Minidebug_db.debug_db_file ~run_name:"t2" db_file_base);
  [%track_rt_show
    [%log_block
      "test C";
      [%log "line C"]]]
    Minidebug_db.(debug_db_file ~run_name:"t3" ~log_level:0 db_file_base);
  let db = Minidebug_client.Client.open_db (db_file_for_run run_num1) in
  Minidebug_client.Client.show_trace db ~values_first_mode:false 1;
  let db = Minidebug_client.Client.open_db (db_file_for_run run_num2) in
  Minidebug_client.Client.show_trace db ~values_first_mode:false 1;
  print_endline @@ "run_id2: " ^ Int.to_string 1;
  print_endline @@ "latest_run: "
  ^ Int.to_string (Minidebug_client.Client.get_latest_run db |> Option.get).run_id;
  [%expect
    {|
    [track] test A @ :0:0-0:0
      "line A"
    [track] test B @ :0:0-0:0
      "line B"
    run_id2: 1
    latest_run: 1
    |}]

let%expect_test "%logN_block runtime log levels" =
  (* $MDX part-begin=logN_block *)
  let _ = next_run () in
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
          Minidebug_db.(debug_db_file ~run_name:"for=2,with=default" db_file_base)
          ~for_log_level:2);
  Minidebug_client.Client.show_trace (latest_run ()) 1;
  print_endline
  @@ Int.to_string
       (result
          Minidebug_db.(debug_db_file ~log_level:0 ~run_name:"for=1,with=0" db_file_base)
          ~for_log_level:1);
  let db_check = latest_run () in
  print_endline @@ "latest_run name: "
  ^ Option.get (Minidebug_client.Client.get_latest_run db_check |> Option.get).run_name;
  print_endline
  @@ Int.to_string
       (result
          Minidebug_db.(debug_db_file ~log_level:1 ~run_name:"for=2,with=1" db_file_base)
          ~for_log_level:2);
  Minidebug_client.Client.show_trace (latest_run ()) 1;
  print_endline
  @@ Int.to_string
       (result
          Minidebug_db.(debug_db_file ~log_level:2 ~run_name:"for=1,with=2" db_file_base)
          ~for_log_level:1);
  Minidebug_client.Client.show_trace (latest_run ()) 1;
  print_endline
  @@ Int.to_string
       (result
          Minidebug_db.(debug_db_file ~log_level:3 ~run_name:"for=3,with=3" db_file_base)
          ~for_log_level:3);
  Minidebug_client.Client.show_trace (latest_run ()) 1;
  (* Unlike with other constructs, INFO should not be printed in "for=4,with=3", because
     log_block filters out the whole body by the log level. *)
  print_endline
  @@ Int.to_string
       (result
          Minidebug_db.(debug_db_file ~log_level:3 ~run_name:"for=4,with=3" db_file_base)
          ~for_log_level:4);
  Minidebug_client.Client.show_trace (latest_run ()) 1;
  (* FIXME: THIS TEST IS NOT WORKING *)
  [%expect.unreachable]
[@@expect.uncaught_exn {|
  (* CR expect_test_collector: This test expectation appears to contain a backtrace.
     This is strongly discouraged as backtraces are fragile.
     Please change this test to not include a backtrace. *)
  ("Sqlite3.Error(\"error opening database: unable to open database file\")")
  Raised by primitive operation at Sqlite3.db_open in file "lib/sqlite3.ml", line 281, characters 2-52
  Called from Minidebug_client.Client.open_db in file "minidebug_client.ml", line 1730, characters 13-52
  Called from Test_inline_tests__Test_expect_test.latest_run in file "test/test_expect_test.ml", line 25, characters 11-50
  Called from Test_inline_tests__Test_expect_test.(fun) in file "test/test_expect_test.ml", line 2857, characters 37-52
  Called from Ppx_expect_runtime__Test_block.Configured.dump_backtrace in file "runtime/test_block.ml", line 142, characters 10-28

  Trailing output
  ---------------
  21
  latest_run: (no-name)
  [track] result => 21 @ test/test_expect_test.ml:2824:27-2836:6
    [track] while:test_expect_test:2827 @ test/test_expect_test.ml:2827:4-2835:8
      [track] <while loop> @ test/test_expect_test.ml:2828:6-2834:45
        [track] i=1 @ :0:0-0:0
          [track] then:test_expect_test:2831 @ test/test_expect_test.ml:2831:23-2831:59
            (ERROR: 1 i= 1)
          (WARNING: 2 i= 1)
          fun:test_expect_test:2833 =
          (INFO: 3 j= 1)
      [track] <while loop> @ test/test_expect_test.ml:2828:6-2834:45
        [track] i=2 @ :0:0-0:0
          [track] then:test_expect_test:2831 @ test/test_expect_test.ml:2831:23-2831:59
            (ERROR: 1 i= 2)
          (WARNING: 2 i= 2)
          fun:test_expect_test:2833 =
          (INFO: 3 j= 3)
      [track] <while loop> @ test/test_expect_test.ml:2828:6-2834:45
        [track] i=3 @ :0:0-0:0
          else:test_expect_test:2831 =
          (WARNING: 2 i= 3)
          fun:test_expect_test:2833 =
          (INFO: 3 j= 6)
      [track] <while loop> @ test/test_expect_test.ml:2828:6-2834:45
        [track] i=4 @ :0:0-0:0
          else:test_expect_test:2831 =
          (WARNING: 2 i= 4)
          fun:test_expect_test:2833 =
          (INFO: 3 j= 10)
      [track] <while loop> @ test/test_expect_test.ml:2828:6-2834:45
        [track] i=5 @ :0:0-0:0
          else:test_expect_test:2831 =
          (WARNING: 2 i= 5)
          fun:test_expect_test:2833 =
          (INFO: 3 j= 15)
      [track] <while loop> @ test/test_expect_test.ml:2828:6-2834:45
        [track] i=6 @ :0:0-0:0
          else:test_expect_test:2831 =
          (WARNING: 2 i= 6)
          fun:test_expect_test:2833 =
          (INFO: 3 j= 21)
  0
  |}]

let%expect_test "%log_block compile-time nothing" =
  let run_num = next_run () in
  let db = Minidebug_client.Client.open_db (db_file_for_run run_num) in
  let latest_run_before = db |> Minidebug_client.Client.get_latest_run |> Option.get in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file_base in
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
  let latest_run_after = db |> Minidebug_client.Client.get_latest_run |> Option.get in
  print_endline @@ "latest run before: " ^ Int.to_string latest_run_before.run_id;
  print_endline @@ "latest run after: " ^ Int.to_string latest_run_after.run_id;
  [%expect {|
    latest run before: 77
    latest run after: 77
    |}]

let%expect_test "%log_block compile-time nothing dynamic scope" =
  let run_num = next_run () in
  let db = Minidebug_client.Client.open_db (db_file_for_run run_num) in
  let latest_run_before = db |> Minidebug_client.Client.get_latest_run |> Option.get in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file_base in
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
  let latest_run_after = db |> Minidebug_client.Client.get_latest_run |> Option.get in
  print_endline @@ "latest run before: " ^ Int.to_string latest_run_before.run_id;
  print_endline @@ "latest run after: " ^ Int.to_string latest_run_after.run_id;
  [%expect {|
    latest run before: 77
    latest run after: 77
    |}]

let%expect_test "%log compile time log levels while-loop dynamic scope" =
  let run_num = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file_base in
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
  let db = Minidebug_client.Client.open_db (db_file_for_run run_num) in
  Minidebug_client.Client.show_trace db ~values_first_mode:false 1;
  [%expect
    {|
    21
    21
    21
    [track] everything @ test/test_expect_test.ml:3070:28-3073:14
      [track] loop @ test/test_expect_test.ml:3057:22-3068:6
        [track] while:test_expect_test:3060 @ test/test_expect_test.ml:3060:4-3067:8
          [track] <while loop> @ test/test_expect_test.ml:3062:6-3066:42
            [track] then:test_expect_test:3062 @ test/test_expect_test.ml:3062:21-3062:58
              (ERROR: 1 i= 0)
            (WARNING: 2 i= 1)
            fun:test_expect_test:3065 =
            (INFO: 3 j= 1)
          [track] <while loop> @ test/test_expect_test.ml:3062:6-3066:42
            [track] then:test_expect_test:3062 @ test/test_expect_test.ml:3062:21-3062:58
              (ERROR: 1 i= 1)
            (WARNING: 2 i= 2)
            fun:test_expect_test:3065 =
            (INFO: 3 j= 3)
          [track] <while loop> @ test/test_expect_test.ml:3062:6-3066:42
            else:test_expect_test:3062 =
            (WARNING: 2 i= 3)
            fun:test_expect_test:3065 =
            (INFO: 3 j= 6)
          [track] <while loop> @ test/test_expect_test.ml:3062:6-3066:42
            else:test_expect_test:3062 =
            (WARNING: 2 i= 4)
            fun:test_expect_test:3065 =
            (INFO: 3 j= 10)
          [track] <while loop> @ test/test_expect_test.ml:3062:6-3066:42
            else:test_expect_test:3062 =
            (WARNING: 2 i= 5)
            fun:test_expect_test:3065 =
            (INFO: 3 j= 15)
          [track] <while loop> @ test/test_expect_test.ml:3062:6-3066:42
            else:test_expect_test:3062 =
            (WARNING: 2 i= 6)
            fun:test_expect_test:3065 =
            (INFO: 3 j= 21)
      everything => 21
    [track] nothing @ test/test_expect_test.ml:3075:25-3079:14
      nothing => 21
    [track] warning @ test/test_expect_test.ml:3081:25-3084:14
      [track] loop @ test/test_expect_test.ml:3057:22-3068:6
        [track] while:test_expect_test:3060 @ test/test_expect_test.ml:3060:4-3067:8
          [track] <while loop> @ test/test_expect_test.ml:3062:6-3066:42
            [track] then:test_expect_test:3062 @ test/test_expect_test.ml:3062:21-3062:58
              (ERROR: 1 i= 0)
            (WARNING: 2 i= 1)
            fun:test_expect_test:3065 =
          [track] <while loop> @ test/test_expect_test.ml:3062:6-3066:42
            [track] then:test_expect_test:3062 @ test/test_expect_test.ml:3062:21-3062:58
              (ERROR: 1 i= 1)
            (WARNING: 2 i= 2)
            fun:test_expect_test:3065 =
          [track] <while loop> @ test/test_expect_test.ml:3062:6-3066:42
            else:test_expect_test:3062 =
            (WARNING: 2 i= 3)
            fun:test_expect_test:3065 =
          [track] <while loop> @ test/test_expect_test.ml:3062:6-3066:42
            else:test_expect_test:3062 =
            (WARNING: 2 i= 4)
            fun:test_expect_test:3065 =
          [track] <while loop> @ test/test_expect_test.ml:3062:6-3066:42
            else:test_expect_test:3062 =
            (WARNING: 2 i= 5)
            fun:test_expect_test:3065 =
          [track] <while loop> @ test/test_expect_test.ml:3062:6-3066:42
            else:test_expect_test:3062 =
            (WARNING: 2 i= 6)
            fun:test_expect_test:3065 =
      warning => 21
    |}]
