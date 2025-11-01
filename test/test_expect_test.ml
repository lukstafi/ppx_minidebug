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
  Minidebug_client.Client.show_trace db ~show_times:true ~values_first_mode:false;
  let output = [%expect.output] in
  let output =
    Str.global_replace (Str.regexp {|<[0-9.]+\(μs\|ms\|s\)>|}) "<TIME>" output
  in
  print_endline output;
  [%expect
    {|
    336
    339
    [debug] bar @ test/test_expect_test.ml:36:21-38:16 <TIME>
      x = { Test_expect_test.first = 7; second = 42 }
      [debug] y @ test/test_expect_test.ml:37:8-37:9 <TIME>
        y => 8
      bar => 336
    [debug] baz @ test/test_expect_test.ml:41:21-43:22 <TIME>
      x = { Test_expect_test.first = 7; second = 42 }
      [debug] _yz @ test/test_expect_test.ml:42:19-42:22 <TIME>
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
  Minidebug_client.Client.show_trace db ~values_first_mode:false;
  let runs = Minidebug_client.Client.list_runs db in
  let run = List.find (fun r -> r.Minidebug_client.Query.run_id = 1) runs in
  Printf.printf "\nRun #%d has name: %s\n" run.run_id
    (match run.run_name with Some n -> n | None -> "(none)");
  [%expect
    {|
    336
    339
    [debug] bar @ test/test_expect_test.ml:75:21-77:16
      x = { Test_expect_test.first = 7; second = 42 }
      [debug] y @ test/test_expect_test.ml:76:8-76:9
        y => 8
      bar => 336
    [debug] baz @ test/test_expect_test.ml:80:21-82:22
      x = { Test_expect_test.first = 7; second = 42 }
      [debug] _yz @ test/test_expect_test.ml:81:19-81:22
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
  Minidebug_client.Client.show_trace db ~values_first_mode:false;
  [%expect
    {|
    9
    [debug] loop_complete @ test/test_expect_test.ml:113:35-115:57
      x = 7
      [debug] z @ test/test_expect_test.ml:114:8-114:9
        z => 3
      [debug] loop_complete @ test/test_expect_test.ml:113:35-115:57
        x = 6
        [debug] z @ test/test_expect_test.ml:114:8-114:9
          z => 2
        [debug] loop_complete @ test/test_expect_test.ml:113:35-115:57
          x = 5
          [debug] z @ test/test_expect_test.ml:114:8-114:9
            z => 2
          [debug] loop_complete @ test/test_expect_test.ml:113:35-115:57
            x = 4
            [debug] z @ test/test_expect_test.ml:114:8-114:9
              z => 1
            [debug] loop_complete @ test/test_expect_test.ml:113:35-115:57
              x = 3
              [debug] z @ test/test_expect_test.ml:114:8-114:9
                z => 1
              [debug] loop_complete @ test/test_expect_test.ml:113:35-115:57
                x = 2
                [debug] z @ test/test_expect_test.ml:114:8-114:9
                  z => 0
                [debug] loop_complete @ test/test_expect_test.ml:113:35-115:57
                  x = 1
                  [debug] z @ test/test_expect_test.ml:114:8-114:9
                    z => 0
                  [debug] loop_complete @ test/test_expect_test.ml:113:35-115:57
                    x = 0
                    [debug] z @ test/test_expect_test.ml:114:8-114:9
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
  Minidebug_client.Client.show_trace db ~values_first_mode:false;
  [%expect
    {|
    9
    [debug] loop_changes @ test/test_expect_test.ml:169:34-175:7
      x = 7
      [debug] z @ test/test_expect_test.ml:170:8-170:9
        z => 3
      [debug] loop_changes @ test/test_expect_test.ml:169:34-175:7
        x = 6
        [debug] z @ test/test_expect_test.ml:170:8-170:9
          z => 2
        [debug] loop_changes @ test/test_expect_test.ml:169:34-175:7
          x = 5
          [debug] z @ test/test_expect_test.ml:170:8-170:9
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
  Minidebug_client.Client.show_trace db ~values_first_mode:false ~show_times:true;
  let output = [%expect.output] in
  let output =
    Str.global_replace (Str.regexp {|<[0-9.]+\(μs\|ms\|s\)>|}) "<TIME>" output
  in
  print_endline output;
  [%expect
    {|
    Raised exception.
    [debug] loop_truncated @ test/test_expect_test.ml:207:36-210:36 <TIME>
      x = 7
      [debug] z @ test/test_expect_test.ml:208:8-208:9 <TIME>
        z => 3
      [debug] loop_truncated @ test/test_expect_test.ml:207:36-210:36 <TIME>
        x = 6
        [debug] z @ test/test_expect_test.ml:208:8-208:9 <TIME>
          z => 2
        [debug] loop_truncated @ test/test_expect_test.ml:207:36-210:36 <TIME>
          x = 5
          [debug] z @ test/test_expect_test.ml:208:8-208:9 <TIME>
            z => 2
          [debug] loop_truncated @ test/test_expect_test.ml:207:36-210:36 <TIME>
            x = 4
            [debug] z @ test/test_expect_test.ml:208:8-208:9 <TIME>
              z => 1
            [debug] loop_truncated @ test/test_expect_test.ml:207:36-210:36 <TIME>
              x = 3
              [debug] z @ test/test_expect_test.ml:208:8-208:9 <TIME>
                z => 1
              [debug] loop_truncated @ test/test_expect_test.ml:207:36-210:36 <TIME>
                x = 2
                [debug] z @ test/test_expect_test.ml:208:8-208:9 <TIME>
                  z => 0
                [debug] loop_truncated @ test/test_expect_test.ml:207:36-210:36 <TIME>
                  x = 1
                  [debug] z @ test/test_expect_test.ml:208:8-208:9 <TIME>
                    z => 0
                  [debug] loop_truncated @ test/test_expect_test.ml:207:36-210:36 <TIME>
                    x = 0
                    [debug] z @ test/test_expect_test.ml:208:8-208:9 <TIME>
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
  Minidebug_client.Client.show_trace db ~values_first_mode:false;
  [%expect
    {|
    Raised exception.
    [debug] loop_exceeded @ test/test_expect_test.ml:267:35-271:60
      x = 7
      [debug] z @ test/test_expect_test.ml:270:10-270:11
        z => 3
      [debug] loop_exceeded @ test/test_expect_test.ml:267:35-271:60
        x = 6
        [debug] z @ test/test_expect_test.ml:270:10-270:11
          z => 2
        [debug] loop_exceeded @ test/test_expect_test.ml:267:35-271:60
          x = 5
          [debug] z @ test/test_expect_test.ml:270:10-270:11
            z => 2
          [debug] loop_exceeded @ test/test_expect_test.ml:267:35-271:60
            x = 4
            [debug] z @ test/test_expect_test.ml:270:10-270:11
              z => 1
            [debug] loop_exceeded @ test/test_expect_test.ml:267:35-271:60
              x = 3
              [debug] z @ test/test_expect_test.ml:270:10-270:11
                z => 1
              [debug] loop_exceeded @ test/test_expect_test.ml:267:35-271:60
                x = 2
                [debug] z @ test/test_expect_test.ml:270:10-270:11
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
  Minidebug_client.Client.show_trace db ~values_first_mode:false;
  [%expect
    {|
    Raised exception: ppx_minidebug: max_num_children exceeded
    [debug] _bar @ test/test_expect_test.ml:318:21-318:25
      [debug] _baz @ test/test_expect_test.ml:322:16-322:20
        _baz => 0
      [debug] _baz @ test/test_expect_test.ml:322:16-322:20
        _baz => 2
      [debug] _baz @ test/test_expect_test.ml:322:16-322:20
        _baz => 4
      [debug] _baz @ test/test_expect_test.ml:322:16-322:20
        _baz => 6
      [debug] _baz @ test/test_expect_test.ml:322:16-322:20
        _baz => 8
      [debug] _baz @ test/test_expect_test.ml:322:16-322:20
        _baz => 10
      [debug] _baz @ test/test_expect_test.ml:322:16-322:20
        _baz => 12
      [debug] _baz @ test/test_expect_test.ml:322:16-322:20
        _baz => 14
      [debug] _baz @ test/test_expect_test.ml:322:16-322:20
        _baz => 16
      [debug] _baz @ test/test_expect_test.ml:322:16-322:20
        _baz => 18
      [debug] _baz @ test/test_expect_test.ml:322:16-322:20
        _baz => 20
      [debug] _baz @ test/test_expect_test.ml:322:16-322:20
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
  Minidebug_client.Client.show_trace db ~values_first_mode:false;
  [%expect
    {|
    Raised exception: ppx_minidebug: max_num_children exceeded
    [track] _bar @ test/test_expect_test.ml:370:21-370:25
      [track] for:test_expect_test:373 @ test/test_expect_test.ml:373:10-376:14
        [track] <for i> @ test/test_expect_test.ml:373:14-373:15
          i = 0
          [track] _baz @ test/test_expect_test.ml:374:16-374:20
            _baz => 0
        [track] <for i> @ test/test_expect_test.ml:373:14-373:15
          i = 1
          [track] _baz @ test/test_expect_test.ml:374:16-374:20
            _baz => 2
        [track] <for i> @ test/test_expect_test.ml:373:14-373:15
          i = 2
          [track] _baz @ test/test_expect_test.ml:374:16-374:20
            _baz => 4
        [track] <for i> @ test/test_expect_test.ml:373:14-373:15
          i = 3
          [track] _baz @ test/test_expect_test.ml:374:16-374:20
            _baz => 6
        [track] <for i> @ test/test_expect_test.ml:373:14-373:15
          i = 4
          [track] _baz @ test/test_expect_test.ml:374:16-374:20
            _baz => 8
        [track] <for i> @ test/test_expect_test.ml:373:14-373:15
          i = 5
          [track] _baz @ test/test_expect_test.ml:374:16-374:20
            _baz => 10
        [track] <for i> @ test/test_expect_test.ml:373:14-373:15
          i = 6
          [track] _baz @ test/test_expect_test.ml:374:16-374:20
            _baz => 12
        [track] <for i> @ test/test_expect_test.ml:373:14-373:15
          i = 7
          [track] _baz @ test/test_expect_test.ml:374:16-374:20
            _baz => 14
        [track] <for i> @ test/test_expect_test.ml:373:14-373:15
          i = 8
          [track] _baz @ test/test_expect_test.ml:374:16-374:20
            _baz => 16
        [track] <for i> @ test/test_expect_test.ml:373:14-373:15
          i = 9
          [track] _baz @ test/test_expect_test.ml:374:16-374:20
            _baz => 18
        [track] <for i> @ test/test_expect_test.ml:373:14-373:15
          i = 10
          [track] _baz @ test/test_expect_test.ml:374:16-374:20
            _baz => 20
        [track] <for i> @ test/test_expect_test.ml:373:14-373:15
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
  Minidebug_client.Client.show_trace db ~values_first_mode:false;
  [%expect
    {|
    [track] _bar @ test/test_expect_test.ml:445:21-445:25
      [track] for:test_expect_test:448 @ test/test_expect_test.ml:448:10-451:14
        [track] <for i> @ test/test_expect_test.ml:448:14-448:15
          i = 0
          [track] _baz @ test/test_expect_test.ml:449:16-449:20
            _baz => 0
        [track] <for i> @ test/test_expect_test.ml:448:14-448:15
          i = 1
          [track] _baz @ test/test_expect_test.ml:449:16-449:20
            _baz => 2
        [track] <for i> @ test/test_expect_test.ml:448:14-448:15
          i = 2
          [track] _baz @ test/test_expect_test.ml:449:16-449:20
            _baz => 4
        [track] <for i> @ test/test_expect_test.ml:448:14-448:15
          i = 3
          [track] _baz @ test/test_expect_test.ml:449:16-449:20
            _baz => 6
        [track] <for i> @ test/test_expect_test.ml:448:14-448:15
          i = 4
          [track] _baz @ test/test_expect_test.ml:449:16-449:20
            _baz => 8
        [track] <for i> @ test/test_expect_test.ml:448:14-448:15
          i = 5
          [track] _baz @ test/test_expect_test.ml:449:16-449:20
            _baz => 10
        [track] <for i> @ test/test_expect_test.ml:448:14-448:15
          i = 6
          [track] _baz @ test/test_expect_test.ml:449:16-449:20
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
  Minidebug_client.Client.show_trace db ~values_first_mode:false ~show_times:true;
  let output = [%expect.output] in
  let output =
    Str.global_replace
      (Str.regexp {|[0-9]+?[0-9]+.[0-9]+[0-9]+\(μ\|m\|n\)s|})
      "N.NNμs" output
  in
  print_endline output;
  [%expect
    {|
    [track] _bar @ test/test_expect_test.ml:501:21-501:25 <N.NNμs>
      [track] for:test_expect_test:504 @ test/test_expect_test.ml:504:10-507:14 <N.NNμs>
        [track] <for i> @ test/test_expect_test.ml:504:14-504:15 <N.NNμs>
          i = 0
          [track] _baz @ test/test_expect_test.ml:505:16-505:20 <N.NNμs>
            _baz => 0
        [track] <for i> @ test/test_expect_test.ml:504:14-504:15 <N.NNμs>
          i = 1
          [track] _baz @ test/test_expect_test.ml:505:16-505:20 <N.NNμs>
            _baz => 2
        [track] <for i> @ test/test_expect_test.ml:504:14-504:15 <N.NNμs>
          i = 2
          [track] _baz @ test/test_expect_test.ml:505:16-505:20 <N.NNμs>
            _baz => 4
        [track] <for i> @ test/test_expect_test.ml:504:14-504:15 <N.NNμs>
          i = 3
          [track] _baz @ test/test_expect_test.ml:505:16-505:20 <N.NNμs>
            _baz => 6
        [track] <for i> @ test/test_expect_test.ml:504:14-504:15 <N.NNμs>
          i = 4
          [track] _baz @ test/test_expect_test.ml:505:16-505:20 <N.NNμs>
            _baz => 8
        [track] <for i> @ test/test_expect_test.ml:504:14-504:15 <N.NNμs>
          i = 5
          [track] _baz @ test/test_expect_test.ml:505:16-505:20 <N.NNμs>
            _baz => 10
        [track] <for i> @ test/test_expect_test.ml:504:14-504:15 <N.NNμs>
          i = 6
          [track] _baz @ test/test_expect_test.ml:505:16-505:20 <N.NNμs>
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
  Minidebug_client.Client.show_trace db ~values_first_mode:false;
  [%expect
    {|
    [track] _bar @ test/test_expect_test.ml:564:21-564:25
      [track] while:test_expect_test:566 @ test/test_expect_test.ml:566:8-569:12
        [track] <while loop> @ test/test_expect_test.ml:567:10-568:16
          [track] _baz @ test/test_expect_test.ml:567:14-567:18
            _baz => 0
        [track] <while loop> @ test/test_expect_test.ml:567:10-568:16
          [track] _baz @ test/test_expect_test.ml:567:14-567:18
            _baz => 2
        [track] <while loop> @ test/test_expect_test.ml:567:10-568:16
          [track] _baz @ test/test_expect_test.ml:567:14-567:18
            _baz => 4
        [track] <while loop> @ test/test_expect_test.ml:567:10-568:16
          [track] _baz @ test/test_expect_test.ml:567:14-567:18
            _baz => 6
        [track] <while loop> @ test/test_expect_test.ml:567:10-568:16
          [track] _baz @ test/test_expect_test.ml:567:14-567:18
            _baz => 8
        [track] <while loop> @ test/test_expect_test.ml:567:10-568:16
          [track] _baz @ test/test_expect_test.ml:567:14-567:18
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
  Minidebug_client.Client.show_trace db ~values_first_mode:false;
  [%expect
    {|
    Raised exception: ppx_minidebug: max_num_children exceeded
    [debug] loop_exceeded @ test/test_expect_test.ml:607:35-615:72
      x = 3
      [debug] z @ test/test_expect_test.ml:614:17-614:18
        z => 1
      [debug] loop_exceeded @ test/test_expect_test.ml:607:35-615:72
        x = 2
        [debug] z @ test/test_expect_test.ml:614:17-614:18
          z => 0
        [debug] loop_exceeded @ test/test_expect_test.ml:607:35-615:72
          x = 1
          [debug] z @ test/test_expect_test.ml:614:17-614:18
            z => 0
          [debug] loop_exceeded @ test/test_expect_test.ml:607:35-615:72
            x = 0
            [debug] z @ test/test_expect_test.ml:614:17-614:18
              z => 0
            [debug] z @ test/test_expect_test.ml:614:17-614:18
              z => 1
            [debug] z @ test/test_expect_test.ml:614:17-614:18
              z => 2
            [debug] z @ test/test_expect_test.ml:614:17-614:18
              z => 3
            [debug] z @ test/test_expect_test.ml:614:17-614:18
              z => 4
            [debug] z @ test/test_expect_test.ml:614:17-614:18
              z => 5
            [debug] z @ test/test_expect_test.ml:614:17-614:18
              z => 6
            [debug] z @ test/test_expect_test.ml:614:17-614:18
              z => 7
            [debug] z @ test/test_expect_test.ml:614:17-614:18
              z => 8
            [debug] z @ test/test_expect_test.ml:614:17-614:18
              z => 9
            [debug] z @ test/test_expect_test.ml:614:17-614:18
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
  Minidebug_client.Client.show_trace db ~values_first_mode:false;
  [%expect
    {|
    4
    -3
    [track] track_branches @ test/test_expect_test.ml:670:32-672:46
      x = 7
      [track] else:test_expect_test:672 @ test/test_expect_test.ml:672:9-672:46
        <match -- branch 1> =
      track_branches => 4
    [track] track_branches @ test/test_expect_test.ml:670:32-672:46
      x = 3
      [track] then:test_expect_test:671 @ test/test_expect_test.ml:671:18-671:57
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
  Minidebug_client.Client.show_trace db ~values_first_mode:false;
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
  Minidebug_client.Client.show_trace db ~values_first_mode:false;
  [%expect
    {|
    8
    3
    [track] track_branches @ test/test_expect_test.ml:735:32-749:16
      x = 8
      [track] else:test_expect_test:744 @ test/test_expect_test.ml:744:6-749:16
        [track] <match -- branch 2> @ test/test_expect_test.ml:748:10-749:16
          [track] result @ test/test_expect_test.ml:748:14-748:20
            then:test_expect_test:748 =
            result => 8
      track_branches => 8
    [track] track_branches @ test/test_expect_test.ml:735:32-749:16
      x = 3
      [track] then:test_expect_test:737 @ test/test_expect_test.ml:737:6-742:16
        [debug] result @ test/test_expect_test.ml:741:14-741:20
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
  Minidebug_client.Client.show_trace db ~values_first_mode:false;
  [%expect
    {|
    8
    [track] track_foo @ test/test_expect_test.ml:787:27-791:5
      x = 8
      [track] fun:test_expect_test:790 @ test/test_expect_test.ml:790:4-790:31
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
  Minidebug_client.Client.show_trace db ~values_first_mode:false;
  [%expect
    {|
    8
    3
    [track] track_branches @ test/test_expect_test.ml:815:32-829:16
      x = 8
      [track] else:test_expect_test:824 @ test/test_expect_test.ml:824:6-829:16
        [track] result @ test/test_expect_test.ml:828:25-828:31
          then:test_expect_test:828 =
          result => 8
      track_branches => 8
    [track] track_branches @ test/test_expect_test.ml:815:32-829:16
      x = 3
      [track] then:test_expect_test:817 @ test/test_expect_test.ml:817:6-822:16
        [debug] result @ test/test_expect_test.ml:821:25-821:31
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
  Minidebug_client.Client.show_trace db ~values_first_mode:false;
  [%expect
    {|
    6
    6
    [debug] anonymous @ test/test_expect_test.ml:864:27-867:73
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
  Minidebug_client.Client.show_trace db ~values_first_mode:false;
  [%expect
    {|
    6
    6
    wrapper =
    [debug] anonymous @ test/test_expect_test.ml:895:29-898:75
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
  Minidebug_client.Client.show_trace db ~values_first_mode:false;
  [%expect
    {|
    6
    [debug] anonymous @ test/test_expect_test.ml:928:27-929:70
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
  Minidebug_client.Client.show_trace db ~values_first_mode:false;
  [%expect
    {|
    6
    [track] anonymous @ test/test_expect_test.ml:951:27-952:70
      x = 3
      [track] fun:test_expect_test:952 @ test/test_expect_test.ml:952:50-952:70
        i = 0
      [track] fun:test_expect_test:952 @ test/test_expect_test.ml:952:50-952:70
        i = 1
      [track] fun:test_expect_test:952 @ test/test_expect_test.ml:952:50-952:70
        i = 2
      [track] fun:test_expect_test:952 @ test/test_expect_test.ml:952:50-952:70
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
  Minidebug_client.Client.show_trace db ~values_first_mode:false;
  [%expect
    {|
    Raised exception: ppx_minidebug: max_num_children exceeded
    [track] loop_exceeded @ test/test_expect_test.ml:982:35-990:72
      x = 3
      [track] fun:test_expect_test:988 @ test/test_expect_test.ml:988:11-990:71
        i = 0
        [track] z @ test/test_expect_test.ml:989:17-989:18
          z => 1
        [track] else:test_expect_test:990 @ test/test_expect_test.ml:990:35-990:70
          [track] loop_exceeded @ test/test_expect_test.ml:982:35-990:72
            x = 2
            [track] fun:test_expect_test:988 @ test/test_expect_test.ml:988:11-990:71
              i = 0
              [track] z @ test/test_expect_test.ml:989:17-989:18
                z => 0
              [track] else:test_expect_test:990 @ test/test_expect_test.ml:990:35-990:70
                [track] loop_exceeded @ test/test_expect_test.ml:982:35-990:72
                  x = 1
                  [track] fun:test_expect_test:988 @ test/test_expect_test.ml:988:11-990:71
                    i = 0
                    [track] z @ test/test_expect_test.ml:989:17-989:18
                      z => 0
                    [track] else:test_expect_test:990 @ test/test_expect_test.ml:990:35-990:70
                      [track] loop_exceeded @ test/test_expect_test.ml:982:35-990:72
                        x = 0
                        [track] fun:test_expect_test:988 @ test/test_expect_test.ml:988:11-990:71
                          i = 0
                          [track] z @ test/test_expect_test.ml:989:17-989:18
                            z => 0
                          then:test_expect_test:990 =
                        [track] fun:test_expect_test:988 @ test/test_expect_test.ml:988:11-990:71
                          i = 1
                          [track] z @ test/test_expect_test.ml:989:17-989:18
                            z => 1
                          then:test_expect_test:990 =
                        [track] fun:test_expect_test:988 @ test/test_expect_test.ml:988:11-990:71
                          i = 2
                          [track] z @ test/test_expect_test.ml:989:17-989:18
                            z => 2
                          then:test_expect_test:990 =
                        [track] fun:test_expect_test:988 @ test/test_expect_test.ml:988:11-990:71
                          i = 3
                          [track] z @ test/test_expect_test.ml:989:17-989:18
                            z => 3
                          then:test_expect_test:990 =
                        [track] fun:test_expect_test:988 @ test/test_expect_test.ml:988:11-990:71
                          i = 4
                          [track] z @ test/test_expect_test.ml:989:17-989:18
                            z => 4
                          then:test_expect_test:990 =
                        [track] fun:test_expect_test:988 @ test/test_expect_test.ml:988:11-990:71
                          i = 5
                          [track] z @ test/test_expect_test.ml:989:17-989:18
                            z => 5
                          then:test_expect_test:990 =
                        [track] fun:test_expect_test:988 @ test/test_expect_test.ml:988:11-990:71
                          i = 6
                          [track] z @ test/test_expect_test.ml:989:17-989:18
                            z => 6
                          then:test_expect_test:990 =
                        [track] fun:test_expect_test:988 @ test/test_expect_test.ml:988:11-990:71
                          i = 7
                          [track] z @ test/test_expect_test.ml:989:17-989:18
                            z => 7
                          then:test_expect_test:990 =
                        [track] fun:test_expect_test:988 @ test/test_expect_test.ml:988:11-990:71
                          i = 8
                          [track] z @ test/test_expect_test.ml:989:17-989:18
                            z => 8
                          then:test_expect_test:990 =
                        [track] fun:test_expect_test:988 @ test/test_expect_test.ml:988:11-990:71
                          i = 9
                          [track] z @ test/test_expect_test.ml:989:17-989:18
                            z => 9
                          then:test_expect_test:990 =
                        [track] fun:test_expect_test:988 @ test/test_expect_test.ml:988:11-990:71
                          i = 10
                          fun:test_expect_test:988 = <max_num_children exceeded>
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
  Minidebug_client.Client.show_trace db ~values_first_mode:false;
  [%expect
    {|
    2
    [debug] foo @ test/test_expect_test.ml:1091:21-1092:47
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
  Minidebug_client.Client.show_trace db ~values_first_mode:true;
  [%expect
    {|
    Raised exception.
    [debug] loop_truncated @ test/test_expect_test.ml:1122:36-1125:36
      x = 7
      [debug] z => 3 @ test/test_expect_test.ml:1123:8-1123:9
      [debug] loop_truncated @ test/test_expect_test.ml:1122:36-1125:36
        x = 6
        [debug] z => 2 @ test/test_expect_test.ml:1123:8-1123:9
        [debug] loop_truncated @ test/test_expect_test.ml:1122:36-1125:36
          x = 5
          [debug] z => 2 @ test/test_expect_test.ml:1123:8-1123:9
          [debug] loop_truncated @ test/test_expect_test.ml:1122:36-1125:36
            x = 4
            [debug] z => 1 @ test/test_expect_test.ml:1123:8-1123:9
            [debug] loop_truncated @ test/test_expect_test.ml:1122:36-1125:36
              x = 3
              [debug] z => 1 @ test/test_expect_test.ml:1123:8-1123:9
              [debug] loop_truncated @ test/test_expect_test.ml:1122:36-1125:36
                x = 2
                [debug] z => 0 @ test/test_expect_test.ml:1123:8-1123:9
                [debug] loop_truncated @ test/test_expect_test.ml:1122:36-1125:36
                  x = 1
                  [debug] z => 0 @ test/test_expect_test.ml:1123:8-1123:9
                  [debug] loop_truncated @ test/test_expect_test.ml:1122:36-1125:36
                    x = 0
                    [debug] z => 0 @ test/test_expect_test.ml:1123:8-1123:9
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
  Minidebug_client.Client.show_trace db ~values_first_mode:true;
  [%expect
    {|
    Raised exception: ppx_minidebug: max_num_children exceeded
    [debug] _bar @ test/test_expect_test.ml:1170:21-1170:25
      [debug] _baz => 0 @ test/test_expect_test.ml:1174:16-1174:20
      [debug] _baz => 2 @ test/test_expect_test.ml:1174:16-1174:20
      [debug] _baz => 4 @ test/test_expect_test.ml:1174:16-1174:20
      [debug] _baz => 6 @ test/test_expect_test.ml:1174:16-1174:20
      [debug] _baz => 8 @ test/test_expect_test.ml:1174:16-1174:20
      [debug] _baz => 10 @ test/test_expect_test.ml:1174:16-1174:20
      [debug] _baz => 12 @ test/test_expect_test.ml:1174:16-1174:20
      [debug] _baz => 14 @ test/test_expect_test.ml:1174:16-1174:20
      [debug] _baz => 16 @ test/test_expect_test.ml:1174:16-1174:20
      [debug] _baz => 18 @ test/test_expect_test.ml:1174:16-1174:20
      [debug] _baz => 20 @ test/test_expect_test.ml:1174:16-1174:20
      [debug] _baz @ test/test_expect_test.ml:1174:16-1174:20
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
  Minidebug_client.Client.show_trace db ~values_first_mode:true;
  [%expect
    {|
    [track] _bar => () @ test/test_expect_test.ml:1210:21-1210:25
      [track] for:test_expect_test:1213 @ test/test_expect_test.ml:1213:10-1216:14
        [track] <for i> @ test/test_expect_test.ml:1213:14-1213:15
          i = 0
          [track] _baz => 0 @ test/test_expect_test.ml:1214:16-1214:20
        [track] <for i> @ test/test_expect_test.ml:1213:14-1213:15
          i = 1
          [track] _baz => 2 @ test/test_expect_test.ml:1214:16-1214:20
        [track] <for i> @ test/test_expect_test.ml:1213:14-1213:15
          i = 2
          [track] _baz => 4 @ test/test_expect_test.ml:1214:16-1214:20
        [track] <for i> @ test/test_expect_test.ml:1213:14-1213:15
          i = 3
          [track] _baz => 6 @ test/test_expect_test.ml:1214:16-1214:20
        [track] <for i> @ test/test_expect_test.ml:1213:14-1213:15
          i = 4
          [track] _baz => 8 @ test/test_expect_test.ml:1214:16-1214:20
        [track] <for i> @ test/test_expect_test.ml:1213:14-1213:15
          i = 5
          [track] _baz => 10 @ test/test_expect_test.ml:1214:16-1214:20
        [track] <for i> @ test/test_expect_test.ml:1213:14-1213:15
          i = 6
          [track] _baz => 12 @ test/test_expect_test.ml:1214:16-1214:20
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
  Minidebug_client.Client.show_trace db ~values_first_mode:true;
  [%expect
    {|
    Raised exception: ppx_minidebug: max_num_children exceeded
    [debug] loop_exceeded @ test/test_expect_test.ml:1256:35-1264:72
      x = 3
      [debug] z => 1 @ test/test_expect_test.ml:1263:17-1263:18
      [debug] loop_exceeded @ test/test_expect_test.ml:1256:35-1264:72
        x = 2
        [debug] z => 0 @ test/test_expect_test.ml:1263:17-1263:18
        [debug] loop_exceeded @ test/test_expect_test.ml:1256:35-1264:72
          x = 1
          [debug] z => 0 @ test/test_expect_test.ml:1263:17-1263:18
          [debug] loop_exceeded @ test/test_expect_test.ml:1256:35-1264:72
            x = 0
            [debug] z => 0 @ test/test_expect_test.ml:1263:17-1263:18
            [debug] z => 1 @ test/test_expect_test.ml:1263:17-1263:18
            [debug] z => 2 @ test/test_expect_test.ml:1263:17-1263:18
            [debug] z => 3 @ test/test_expect_test.ml:1263:17-1263:18
            [debug] z => 4 @ test/test_expect_test.ml:1263:17-1263:18
            [debug] z => 5 @ test/test_expect_test.ml:1263:17-1263:18
            [debug] z => 6 @ test/test_expect_test.ml:1263:17-1263:18
            [debug] z => 7 @ test/test_expect_test.ml:1263:17-1263:18
            [debug] z => 8 @ test/test_expect_test.ml:1263:17-1263:18
            [debug] z => 9 @ test/test_expect_test.ml:1263:17-1263:18
            [debug] z @ test/test_expect_test.ml:1263:17-1263:18
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
  Minidebug_client.Client.show_trace db ~values_first_mode:true;
  [%expect
    {|
    4
    -3
    [track] track_branches => 4 @ test/test_expect_test.ml:1306:32-1308:46
      x = 7
      [track] else:test_expect_test:1308 @ test/test_expect_test.ml:1308:9-1308:46
        <match -- branch 1> =
    [track] track_branches => -3 @ test/test_expect_test.ml:1306:32-1308:46
      x = 3
      [track] then:test_expect_test:1307 @ test/test_expect_test.ml:1307:18-1307:57
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
  Minidebug_client.Client.show_trace db ~values_first_mode:true;
  [%expect
    {|
    6
    [track] anonymous @ test/test_expect_test.ml:1338:27-1339:70
      x = 3
      [track] fun:test_expect_test:1339 @ test/test_expect_test.ml:1339:50-1339:70
        i = 0
      [track] fun:test_expect_test:1339 @ test/test_expect_test.ml:1339:50-1339:70
        i = 1
      [track] fun:test_expect_test:1339 @ test/test_expect_test.ml:1339:50-1339:70
        i = 2
      [track] fun:test_expect_test:1339 @ test/test_expect_test.ml:1339:50-1339:70
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
  Minidebug_client.Client.show_trace db ~values_first_mode:false;
  [%expect
    {|
    336
    109
    [debug] bar @ test/test_expect_test.ml:1368:21-1371:15
      first = 7
      second = 42
      [debug] {first=a; second=b} @ test/test_expect_test.ml:1369:8-1369:45
        a => 7
        b => 45
      [debug] y @ test/test_expect_test.ml:1370:8-1370:9
        y => 8
      bar => 336
    [debug] baz @ test/test_expect_test.ml:1374:21-1376:28
      first = 7
      second = 42
      [debug] {first; second} @ test/test_expect_test.ml:1375:8-1375:37
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
  Minidebug_client.Client.show_trace db ~values_first_mode:false;
  [%expect
    {|
    336
    339
    109
    [debug] bar @ test/test_expect_test.ml:1409:21-1411:14
      first = 7
      second = 42
      [debug] y @ test/test_expect_test.ml:1410:8-1410:9
        y => 8
      bar => 336
    [debug] (r1, r2) @ test/test_expect_test.ml:1419:17-1419:23
      [debug] baz @ test/test_expect_test.ml:1414:21-1417:35
        first = 7
        second = 42
        [debug] (y, z) @ test/test_expect_test.ml:1415:8-1415:14
          y => 8
          z => 3
        [debug] (a, b) @ test/test_expect_test.ml:1416:8-1416:28
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
  Minidebug_client.Client.show_trace db ~values_first_mode:true;
  [%expect
    {|
    336
    109
    [debug] bar => 336 @ test/test_expect_test.ml:1456:21-1459:15
      first = 7
      second = 42
      [debug] {first=a; second=b} @ test/test_expect_test.ml:1457:8-1457:45
        a => 7
        b => 45
      [debug] y => 8 @ test/test_expect_test.ml:1458:8-1458:9
    [debug] baz => 109 @ test/test_expect_test.ml:1462:21-1464:28
      first = 7
      second = 42
      [debug] {first; second} @ test/test_expect_test.ml:1463:8-1463:37
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
  Minidebug_client.Client.show_trace db ~values_first_mode:true;
  [%expect
    {|
    336
    339
    109
    [debug] bar => 336 @ test/test_expect_test.ml:1494:21-1496:14
      first = 7
      second = 42
      [debug] y => 8 @ test/test_expect_test.ml:1495:8-1495:9
    [debug] (r1, r2) @ test/test_expect_test.ml:1504:17-1504:23
      r1 => 339
      r2 => 109
      [debug] baz => (339, 109) @ test/test_expect_test.ml:1499:21-1502:35
        first = 7
        second = 42
        [debug] (y, z) @ test/test_expect_test.ml:1500:8-1500:14
          y => 8
          z => 3
        [debug] (a, b) @ test/test_expect_test.ml:1501:8-1501:28
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
  Minidebug_client.Client.show_trace db ~values_first_mode:true;
  [%expect
    {|
    16
    5
    6
    3
    [track] bar => 16 @ test/test_expect_test.ml:1542:21-1544:9
      x = 7
      [track] y => 8 @ test/test_expect_test.ml:1543:8-1543:9
    [track] <function -- branch 0> Left x => baz = 5 @ test/test_expect_test.ml:1548:24-1548:29
      x = 4
    [track] <function -- branch 1> Right Two y => baz = 6 @ test/test_expect_test.ml:1549:31-1549:36
      y = 3
    [track] foo => 3 @ test/test_expect_test.ml:1552:21-1553:82
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
  Minidebug_client.Client.show_trace db;
  (* Note the missing value of [b]: the nested-in-expression type is not propagated. *)
  [%expect
    {|
    339
    109
    [debug] (r1, r2) @ test/test_expect_test.ml:1588:17-1588:38
      r1 => 339
      r2 => 109
      [debug] baz => (339, 109) @ test/test_expect_test.ml:1583:21-1586:35
        first = 7
        second = 42
        [debug] (y, z) @ test/test_expect_test.ml:1584:8-1584:29
          y => 8
          z => 3
        [debug] (a, b) => a = 8 @ test/test_expect_test.ml:1585:8-1585:20
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
  Minidebug_client.Client.show_trace db;
  [%expect
    {|
    7
    12
    [debug] f => 7 @ test/test_expect_test.ml:1616:44-1616:61
      b = 6
    [debug] g => 12 @ test/test_expect_test.ml:1617:56-1617:79
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
  Minidebug_client.Client.show_trace db;
  [%expect
    {|
    7
    12
    [debug] f : int => 7 @ test/test_expect_test.ml:1641:37-1641:54
      b : int = 6
    [debug] g : int => 12 @ test/test_expect_test.ml:1642:49-1642:72
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
  Minidebug_client.Client.show_trace db ~values_first_mode:true;
  [%expect
    {|
    14
    14
    8
    9
    [track] foo => 14 @ test/test_expect_test.ml:1664:21-1665:59
      [track] <match -- branch 1> Some y @ test/test_expect_test.ml:1665:54-1665:59
        y = 7
    [track] bar => 14 @ test/test_expect_test.ml:1668:21-1669:44
      l = (Some 7)
      <match -- branch 1> Some y =
    [track] <function -- branch 1> Some y => baz = 8 @ test/test_expect_test.ml:1672:74-1672:79
      y = 4
    [track] <function -- branch 1> Some (y, z) => zoo = 9 @ test/test_expect_test.ml:1676:21-1676:26
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
  Minidebug_client.Client.show_trace db ~values_first_mode:true;
  [%expect
    {|
    14
    14
    8
    9
    10
    [track] foo => 14 @ test/test_expect_test.ml:1706:21-1706:82
      [track] <match -- branch 1> :: (y, _) @ test/test_expect_test.ml:1706:77-1706:82
        y = 7
    [track] bar => 14 @ test/test_expect_test.ml:1708:21-1708:82
      l = [7]
      <match -- branch 1> :: (y, _) =
    [track] <function -- branch 1> :: (y, []) => baz = 8 @ test/test_expect_test.ml:1712:15-1712:20
      y = 4
    [track] <function -- branch 2> :: (y, :: (z, [])) => baz = 9 @ test/test_expect_test.ml:1713:18-1713:23
      y = 4
      z = 5
    [track] <function -- branch 3> :: (y, :: (z, _)) => baz = 10 @ test/test_expect_test.ml:1714:21-1714:30
      y = 4
      z = 5
    |}]

let%expect_test "%track_rt_show list runtime passing" =
  (* $MDX part-begin=track_rt_show_list_runtime_passing *)
  let rt run_name = Minidebug_db.debug_db_file ~run_name db_file_base in
  let%track_rt_show foo l : int = match (l : int list) with [] -> 7 | y :: _ -> y * 2 in
  let () = print_endline @@ Int.to_string @@ foo (rt "foo-1") [ 7 ] in
  Minidebug_client.Client.show_trace (latest_run ()) ~values_first_mode:true;
  let%track_rt_show baz : int list -> int = function
    | [] -> 7
    | [ y ] -> y * 2
    | [ y; z ] -> y + z
    | y :: z :: _ -> y + z + 1
  in
  let () = print_endline @@ Int.to_string @@ baz (rt "baz-1") [ 4 ] in
  Minidebug_client.Client.show_trace (latest_run ()) ~values_first_mode:true;
  let () = print_endline @@ Int.to_string @@ baz (rt "baz-2") [ 4; 5; 6 ] in
  Minidebug_client.Client.show_trace (latest_run ()) ~values_first_mode:true;
  [%expect.unreachable]
[@@expect.uncaught_exn {|
  (* CR expect_test_collector: This test expectation appears to contain a backtrace.
     This is strongly discouraged as backtraces are fragile.
     Please change this test to not include a backtrace. *)
  (Failure "Failed to create run in metadata DB")
  Raised at Stdlib.failwith in file "stdlib.ml", line 29, characters 17-33
  Called from Minidebug_db.DatabaseBackend.initialize_database in file "minidebug_db.ml", line 344, characters 11-57
  Called from Minidebug_db.DatabaseBackend.get_db in file "minidebug_db.ml", line 382, characters 8-36
  Called from Minidebug_db.DatabaseBackend.open_log in file "minidebug_db.ml", line 419, characters 15-24
  Called from Test_inline_tests__Test_expect_test.(fun).baz.(fun) in file "test/test_expect_test.ml", line 1752, characters 15-20
  Called from Test_inline_tests__Test_expect_test.(fun) in file "test/test_expect_test.ml", line 1756, characters 45-67
  Called from Ppx_expect_runtime__Test_block.Configured.dump_backtrace in file "runtime/test_block.ml", line 142, characters 10-28

  Trailing output
  ---------------
  14
  latest_run: foo-1
  [track] foo => 14 @ test/test_expect_test.ml:1747:24-1747:85
    [track] <match -- branch 1> :: (y, _) @ test/test_expect_test.ml:1747:80-1747:85
      y = 7
  |}]
(* $MDX part-end *)

let%expect_test "%track_rt_show procedure runtime passing" =
  let rt run_name = Minidebug_db.debug_db_file ~run_name db_file_base in
  let%track_rt_show bar () = (fun () -> ()) () in
  let () = bar (rt "bar-1") () in
  Minidebug_client.Client.show_trace (latest_run ());
  let () = bar (rt "bar-2") () in
  Minidebug_client.Client.show_trace (latest_run ());
  let%track_rt_show foo () =
    let () = () in
    ()
  in
  let () = foo (rt "foo-1") () in
  Minidebug_client.Client.show_trace (latest_run ());
  let () = foo (rt "foo-2") () in
  Minidebug_client.Client.show_trace (latest_run ());
  [%expect.unreachable]
[@@expect.uncaught_exn {|
  (* CR expect_test_collector: This test expectation appears to contain a backtrace.
     This is strongly discouraged as backtraces are fragile.
     Please change this test to not include a backtrace. *)
  (Failure "Failed to create run in metadata DB")
  Raised at Stdlib.failwith in file "stdlib.ml", line 29, characters 17-33
  Called from Minidebug_db.DatabaseBackend.initialize_database in file "minidebug_db.ml", line 344, characters 11-57
  Called from Minidebug_db.DatabaseBackend.get_db in file "minidebug_db.ml", line 382, characters 8-36
  Called from Minidebug_db.DatabaseBackend.open_log in file "minidebug_db.ml", line 419, characters 15-24
  Called from Test_inline_tests__Test_expect_test.(fun).bar in file "test/test_expect_test.ml", line 1781, characters 24-46
  Called from Test_inline_tests__Test_expect_test.(fun) in file "test/test_expect_test.ml", line 1782, characters 11-30
  Called from Ppx_expect_runtime__Test_block.Configured.dump_backtrace in file "runtime/test_block.ml", line 142, characters 10-28
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
  Minidebug_client.Client.show_trace (latest_run ());
  let () = foo (rt "foo-2") () in
  Minidebug_client.Client.show_trace (latest_run ());
  let () = bar (rt "bar-1") () in
  Minidebug_client.Client.show_trace (latest_run ());
  let () = bar (rt "bar-2") () in
  Minidebug_client.Client.show_trace (latest_run ());
  [%expect.unreachable]
[@@expect.uncaught_exn {|
  (* CR expect_test_collector: This test expectation appears to contain a backtrace.
     This is strongly discouraged as backtraces are fragile.
     Please change this test to not include a backtrace. *)
  (Failure "Failed to create run in metadata DB")
  Raised at Stdlib.failwith in file "stdlib.ml", line 29, characters 17-33
  Called from Minidebug_db.DatabaseBackend.initialize_database in file "minidebug_db.ml", line 344, characters 11-57
  Called from Minidebug_db.DatabaseBackend.get_db in file "minidebug_db.ml", line 382, characters 8-36
  Called from Minidebug_db.DatabaseBackend.open_log in file "minidebug_db.ml", line 419, characters 15-24
  Called from Test_inline_tests__Test_expect_test.(fun).rt_test.foo in file "test/test_expect_test.ml", lines 1816-1818, characters 26-8
  Called from Test_inline_tests__Test_expect_test.(fun) in file "test/test_expect_test.ml", line 1823, characters 11-30
  Called from Ppx_expect_runtime__Test_block.Configured.dump_backtrace in file "runtime/test_block.ml", line 142, characters 10-28
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
  Minidebug_client.Client.show_trace db;
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
  Minidebug_client.Client.show_trace db;
  [%expect.unreachable]
[@@expect.uncaught_exn {|
  (* CR expect_test_collector: This test expectation appears to contain a backtrace.
     This is strongly discouraged as backtraces are fragile.
     Please change this test to not include a backtrace. *)
  (Failure "Failed to create run in metadata DB")
  Raised at Stdlib.failwith in file "stdlib.ml", line 29, characters 17-33
  Called from Minidebug_db.DatabaseBackend.initialize_database in file "minidebug_db.ml", line 344, characters 11-57
  Called from Minidebug_db.DatabaseBackend.get_db in file "minidebug_db.ml", line 382, characters 8-36
  Called from Minidebug_db.DatabaseBackend.open_log in file "minidebug_db.ml", line 419, characters 15-24
  Called from Test_inline_tests__Test_expect_test.(fun).foo in file "test/test_expect_test.ml", lines 1849-1852, characters 21-51
  Called from Ppx_expect_runtime__Test_block.Configured.dump_backtrace in file "runtime/test_block.ml", line 142, characters 10-28
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
  Minidebug_client.Client.show_trace db;
  [%expect.unreachable]
[@@expect.uncaught_exn {|
  (* CR expect_test_collector: This test expectation appears to contain a backtrace.
     This is strongly discouraged as backtraces are fragile.
     Please change this test to not include a backtrace. *)
  (Failure "Failed to create run in metadata DB")
  Raised at Stdlib.failwith in file "stdlib.ml", line 29, characters 17-33
  Called from Minidebug_db.DatabaseBackend.initialize_database in file "minidebug_db.ml", line 344, characters 11-57
  Called from Minidebug_db.DatabaseBackend.get_db in file "minidebug_db.ml", line 382, characters 8-36
  Called from Minidebug_db.DatabaseBackend.open_log in file "minidebug_db.ml", line 419, characters 15-24
  Called from Test_inline_tests__Test_expect_test.(fun).foo in file "test/test_expect_test.ml", lines 1889-1894, characters 21-25
  Called from Ppx_expect_runtime__Test_block.Configured.dump_backtrace in file "runtime/test_block.ml", line 142, characters 10-28
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
  Minidebug_client.Client.show_trace db;
  [%expect.unreachable]
[@@expect.uncaught_exn {|
  (* CR expect_test_collector: This test expectation appears to contain a backtrace.
     This is strongly discouraged as backtraces are fragile.
     Please change this test to not include a backtrace. *)
  (Failure "Failed to create run in metadata DB")
  Raised at Stdlib.failwith in file "stdlib.ml", line 29, characters 17-33
  Called from Minidebug_db.DatabaseBackend.initialize_database in file "minidebug_db.ml", line 344, characters 11-57
  Called from Minidebug_db.DatabaseBackend.get_db in file "minidebug_db.ml", line 382, characters 8-36
  Called from Minidebug_db.DatabaseBackend.open_log in file "minidebug_db.ml", line 419, characters 15-24
  Called from Test_inline_tests__Test_expect_test.(fun).foo in file "test/test_expect_test.ml", lines 1919-1926, characters 21-25
  Called from Ppx_expect_runtime__Test_block.Configured.dump_backtrace in file "runtime/test_block.ml", line 142, characters 10-28
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
  Minidebug_client.Client.show_trace db;
  [%expect.unreachable]
[@@expect.uncaught_exn {|
  (* CR expect_test_collector: This test expectation appears to contain a backtrace.
     This is strongly discouraged as backtraces are fragile.
     Please change this test to not include a backtrace. *)
  (Failure "Failed to create run in metadata DB")
  Raised at Stdlib.failwith in file "stdlib.ml", line 29, characters 17-33
  Called from Minidebug_db.DatabaseBackend.initialize_database in file "minidebug_db.ml", line 344, characters 11-57
  Called from Minidebug_db.DatabaseBackend.get_db in file "minidebug_db.ml", line 382, characters 8-36
  Called from Minidebug_db.DatabaseBackend.open_log in file "minidebug_db.ml", line 419, characters 15-24
  Called from Test_inline_tests__Test_expect_test.(fun) in file "test/test_expect_test.ml", line 1947, characters 17-23
  Called from Ppx_expect_runtime__Test_block.Configured.dump_backtrace in file "runtime/test_block.ml", line 142, characters 10-28
  |}]
(* $MDX part-end *)

let%expect_test "%log runtime log levels while-loop" =
  (* $MDX part-begin=log_runtime_log_levels_while_loop_example *)
  let rt log_level run_name =
    Minidebug_db.debug_db_file ~log_level ~run_name db_file_base
  in
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
  Minidebug_client.Client.show_trace (latest_run ());
  print_endline @@ Int.to_string (result (rt 0 "Nothing") ());
  (* There is no new run after Nothing, so we just skip invoking the client. *)
  print_endline @@ Int.to_string (result (rt 1 "Error") ());
  (* $MDX part-end *)
  Minidebug_client.Client.show_trace (latest_run ());
  print_endline @@ Int.to_string (result (rt 2 "Warning") ());
  Minidebug_client.Client.show_trace (latest_run ());
  [%expect.unreachable]
[@@expect.uncaught_exn {|
  (* CR expect_test_collector: This test expectation appears to contain a backtrace.
     This is strongly discouraged as backtraces are fragile.
     Please change this test to not include a backtrace. *)
  (Failure "Failed to create run in metadata DB")
  Raised at Stdlib.failwith in file "stdlib.ml", line 29, characters 17-33
  Called from Minidebug_db.DatabaseBackend.initialize_database in file "minidebug_db.ml", line 344, characters 11-57
  Called from Minidebug_db.DatabaseBackend.get_db in file "minidebug_db.ml", line 382, characters 8-36
  Called from Minidebug_db.DatabaseBackend.open_log in file "minidebug_db.ml", line 419, characters 15-24
  Called from Test_inline_tests__Test_expect_test.(fun).result in file "test/test_expect_test.ml", lines 1999-2010, characters 27-6
  Called from Test_inline_tests__Test_expect_test.(fun) in file "test/test_expect_test.ml", line 2012, characters 33-64
  Called from Ppx_expect_runtime__Test_block.Configured.dump_backtrace in file "runtime/test_block.ml", line 142, characters 10-28
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
  Minidebug_client.Client.show_trace db;
  [%expect.unreachable]
[@@expect.uncaught_exn {|
  (* CR expect_test_collector: This test expectation appears to contain a backtrace.
     This is strongly discouraged as backtraces are fragile.
     Please change this test to not include a backtrace. *)
  (Failure "Failed to create run in metadata DB")
  Raised at Stdlib.failwith in file "stdlib.ml", line 29, characters 17-33
  Called from Minidebug_db.DatabaseBackend.initialize_database in file "minidebug_db.ml", line 344, characters 11-57
  Called from Minidebug_db.DatabaseBackend.get_db in file "minidebug_db.ml", line 382, characters 8-36
  Called from Minidebug_db.DatabaseBackend.open_log in file "minidebug_db.ml", line 419, characters 15-24
  Called from Test_inline_tests__Test_expect_test.(fun).everything in file "test/test_expect_test.ml", lines 2122-2135, characters 28-9
  Called from Ppx_expect_runtime__Test_block.Configured.dump_backtrace in file "runtime/test_block.ml", line 142, characters 10-28
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
  Minidebug_client.Client.show_trace db ~values_first_mode:false;
  [%expect.unreachable]
[@@expect.uncaught_exn {|
  (* CR expect_test_collector: This test expectation appears to contain a backtrace.
     This is strongly discouraged as backtraces are fragile.
     Please change this test to not include a backtrace. *)
  (Failure "Failed to create run in metadata DB")
  Raised at Stdlib.failwith in file "stdlib.ml", line 29, characters 17-33
  Called from Minidebug_db.DatabaseBackend.initialize_database in file "minidebug_db.ml", line 344, characters 11-57
  Called from Minidebug_db.DatabaseBackend.get_db in file "minidebug_db.ml", line 382, characters 8-36
  Called from Minidebug_db.DatabaseBackend.open_log in file "minidebug_db.ml", line 419, characters 15-24
  Called from Test_inline_tests__Test_expect_test.(fun) in file "test/test_expect_test.ml", line 2239, characters 17-23
  Called from Ppx_expect_runtime__Test_block.Configured.dump_backtrace in file "runtime/test_block.ml", line 142, characters 10-28
  |}]

let%expect_test "%log without scope" =
  let run_num = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file ~print_scope_ids:true db_file_base in
    fun () -> rt
  in
  let i = 3 in
  let pi = 3.14 in
  let l = [ 1; 2; 3 ] in
  (* Orphaned logs are often prevented by the typechecker complaining about missing
     __scope_id. But they can happen with closures and other complex ways to interleave
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
  Minidebug_client.Client.show_trace db ~values_first_mode:false;
  [%expect.unreachable]
[@@expect.uncaught_exn {|
  (* CR expect_test_collector: This test expectation appears to contain a backtrace.
     This is strongly discouraged as backtraces are fragile.
     Please change this test to not include a backtrace. *)
  (Failure "Failed to create run in metadata DB")
  Raised at Stdlib.failwith in file "stdlib.ml", line 29, characters 17-33
  Called from Minidebug_db.DatabaseBackend.initialize_database in file "minidebug_db.ml", line 344, characters 11-57
  Called from Minidebug_db.DatabaseBackend.get_db in file "minidebug_db.ml", line 382, characters 8-36
  Called from Minidebug_db.DatabaseBackend.open_log in file "minidebug_db.ml", line 419, characters 15-24
  Called from Test_inline_tests__Test_expect_test.(fun) in file "test/test_expect_test.ml", line 2300, characters 17-21
  Called from Ppx_expect_runtime__Test_block.Configured.dump_backtrace in file "runtime/test_block.ml", line 142, characters 10-28
  |}]

let%expect_test "%log without scope values_first_mode" =
  let run_num = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file ~print_scope_ids:true db_file_base in
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
  Minidebug_client.Client.show_trace db ~values_first_mode:true;
  [%expect.unreachable]
[@@expect.uncaught_exn {|
  (* CR expect_test_collector: This test expectation appears to contain a backtrace.
     This is strongly discouraged as backtraces are fragile.
     Please change this test to not include a backtrace. *)
  (Failure "Failed to create run in metadata DB")
  Raised at Stdlib.failwith in file "stdlib.ml", line 29, characters 17-33
  Called from Minidebug_db.DatabaseBackend.initialize_database in file "minidebug_db.ml", line 344, characters 11-57
  Called from Minidebug_db.DatabaseBackend.get_db in file "minidebug_db.ml", line 382, characters 8-36
  Called from Minidebug_db.DatabaseBackend.open_log in file "minidebug_db.ml", line 419, characters 15-24
  Called from Test_inline_tests__Test_expect_test.(fun) in file "test/test_expect_test.ml", line 2333, characters 17-21
  Called from Ppx_expect_runtime__Test_block.Configured.dump_backtrace in file "runtime/test_block.ml", line 142, characters 10-28
  |}]

let%expect_test "%log with print_scope_ids, mixed up scopes" =
  (* $MDX part-begin=log_with_print_scope_ids_mixed_up_scopes *)
  let run_num = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file ~print_scope_ids:true db_file_base in
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
  Minidebug_client.Client.show_trace db;
  [%expect.unreachable]
[@@expect.uncaught_exn {|
  (* CR expect_test_collector: This test expectation appears to contain a backtrace.
     This is strongly discouraged as backtraces are fragile.
     Please change this test to not include a backtrace. *)
  (Failure "Failed to create run in metadata DB")
  Raised at Stdlib.failwith in file "stdlib.ml", line 29, characters 17-33
  Called from Minidebug_db.DatabaseBackend.initialize_database in file "minidebug_db.ml", line 344, characters 11-57
  Called from Minidebug_db.DatabaseBackend.get_db in file "minidebug_db.ml", line 382, characters 8-36
  Called from Minidebug_db.DatabaseBackend.open_log in file "minidebug_db.ml", line 419, characters 15-24
  Called from Test_inline_tests__Test_expect_test.(fun).bar in file "test/test_expect_test.ml", lines 2374-2379, characters 21-19
  Called from Test_inline_tests__Test_expect_test.(fun) in file "test/test_expect_test.ml", line 2389, characters 4-13
  Called from Ppx_expect_runtime__Test_block.Configured.dump_backtrace in file "runtime/test_block.ml", line 142, characters 10-28
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
  Minidebug_client.Client.show_trace db;
  [%expect.unreachable]
[@@expect.uncaught_exn {|
  (* CR expect_test_collector: This test expectation appears to contain a backtrace.
     This is strongly discouraged as backtraces are fragile.
     Please change this test to not include a backtrace. *)
  (Failure "Failed to create run in metadata DB")
  Raised at Stdlib.failwith in file "stdlib.ml", line 29, characters 17-33
  Called from Minidebug_db.DatabaseBackend.initialize_database in file "minidebug_db.ml", line 344, characters 11-57
  Called from Minidebug_db.DatabaseBackend.get_db in file "minidebug_db.ml", line 382, characters 8-36
  Called from Minidebug_db.DatabaseBackend.open_log in file "minidebug_db.ml", line 419, characters 15-24
  Called from Test_inline_tests__Test_expect_test.(fun) in file "test/test_expect_test.ml", line 2422, characters 17-25
  Called from Ppx_expect_runtime__Test_block.Configured.dump_backtrace in file "runtime/test_block.ml", line 142, characters 10-28
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
  Minidebug_client.Client.show_trace db;
  [%expect
    {|
    336
    91
    |}]
(* $MDX part-end *)

let%expect_test "%diagn_show no logs" =
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
  (* Nothing to check here, if the run created a DB file it would cascade into the next
     test. *)
  print_endline @@ "run_counter: " ^ Int.to_string !run_counter;
  [%expect {|
    336
    91
    run_counter: 51
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
  Minidebug_client.Client.show_trace db;
  [%expect
    {|
    336
    336
    109
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
  Minidebug_client.Client.show_trace db;
  [%expect
    {|
    336
    336
    109
    |}]
(* $MDX part-end *)

let%expect_test "%track_show don't show unannotated non-function bindings" =
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
  (* Nothing to check here, if the run created a DB file it would cascade into the next
     test. *)
  print_endline @@ "run_counter: " ^ Int.to_string !run_counter;
  [%expect {| run_counter: 53 |}]

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
  let db = Minidebug_client.Client.open_db (db_file_for_run run_num) in
  Minidebug_client.Client.show_trace db;
  [%expect
    {| |}]
(* $MDX part-end *)

let%expect_test "%log_entry" =
  (* $MDX part-begin=log_entry *)
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
  Minidebug_client.Client.show_trace (latest_run ());
  [%expect.unreachable]
[@@expect.uncaught_exn {|
  (* CR expect_test_collector: This test expectation appears to contain a backtrace.
     This is strongly discouraged as backtraces are fragile.
     Please change this test to not include a backtrace. *)
  "Assert_failure test/test_expect_test.ml:23:2"
  Raised at Test_inline_tests__Test_expect_test.latest_run in file "test/test_expect_test.ml", line 23, characters 2-42
  Called from Test_inline_tests__Test_expect_test.(fun) in file "test/test_expect_test.ml", line 2729, characters 37-52
  Called from Ppx_expect_runtime__Test_block.Configured.dump_backtrace in file "runtime/test_block.ml", line 142, characters 10-28
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
    let z : int = y * 2 in
    z - 1
  in
  let () = print_endline @@ Int.to_string @@ bar ~rt:(module Debug_runtime) 7 in
  let db = Minidebug_client.Client.open_db (db_file_for_run run_num) in
  Minidebug_client.Client.show_trace db;
  [%expect
    {|
    15
    [debug] () @ test/test_expect_test.ml:2515:18-2515:20
      [debug] baz => 109 @ test/test_expect_test.ml:2530:26-2533:32
        first = 7
        second = 42
        [debug] {first; second} @ test/test_expect_test.ml:2531:12-2531:41
          first => 8
          second => 45
        ("for baz, f squared", 64)
    |}]

(* TODO: restore "%track_show procedure runtime prefixes" = *)

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
  Minidebug_client.Client.show_trace db ~values_first_mode:false;
  let db = Minidebug_client.Client.open_db (db_file_for_run run_num2) in
  Minidebug_client.Client.show_trace db ~values_first_mode:false;
  [%expect
    {|
    [debug] baz @ test/test_expect_test.ml:2576:24-2579:30
      first = 7
      second = 42
      [debug] {first; second} @ test/test_expect_test.ml:2577:10-2577:39
        first => 8
        second => 45
      ("for baz, f squared", 64)
      baz => 109
    [debug] foo @ test/test_expect_test.ml:2627:21-2640:91
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
      foo => ()
    |}]

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
          Minidebug_db.(debug_db_file ~run_name:"for=2,with=default" db_file_base)
          ~for_log_level:2);
  Minidebug_client.Client.show_trace (latest_run ());
  print_endline
  @@ Int.to_string
       (result
          Minidebug_db.(debug_db_file ~log_level:0 ~run_name:"for=1,with=0" db_file_base)
          ~for_log_level:1);
  (* Nothing to check here, if the run created a DB file it would cascade into the next
     test. *)
  print_endline
  @@ Int.to_string
       (result
          Minidebug_db.(debug_db_file ~log_level:1 ~run_name:"for=2,with=1" db_file_base)
          ~for_log_level:2);
  Minidebug_client.Client.show_trace (latest_run ());
  print_endline
  @@ Int.to_string
       (result
          Minidebug_db.(debug_db_file ~log_level:2 ~run_name:"for=1,with=2" db_file_base)
          ~for_log_level:1);
  Minidebug_client.Client.show_trace (latest_run ());
  print_endline
  @@ Int.to_string
       (result
          Minidebug_db.(debug_db_file ~log_level:3 ~run_name:"for=3,with=3" db_file_base)
          ~for_log_level:3);
  Minidebug_client.Client.show_trace (latest_run ());
  (* Unlike with other constructs, INFO should not be printed in "for=4,with=3", because
     log_block filters out the whole body by the log level. *)
  print_endline
  @@ Int.to_string
       (result
          Minidebug_db.(debug_db_file ~log_level:3 ~run_name:"for=4,with=3" db_file_base)
          ~for_log_level:4);
  Minidebug_client.Client.show_trace (latest_run ());
  [%expect.unreachable]
[@@expect.uncaught_exn {|
  (* CR expect_test_collector: This test expectation appears to contain a backtrace.
     This is strongly discouraged as backtraces are fragile.
     Please change this test to not include a backtrace. *)
  "Assert_failure test/test_expect_test.ml:23:2"
  Raised at Test_inline_tests__Test_expect_test.latest_run in file "test/test_expect_test.ml", line 23, characters 2-42
  Called from Test_inline_tests__Test_expect_test.(fun) in file "test/test_expect_test.ml", line 2826, characters 37-52
  Called from Ppx_expect_runtime__Test_block.Configured.dump_backtrace in file "runtime/test_block.ml", line 142, characters 10-28

  Trailing output
  ---------------
  21
  |}]

let%expect_test "%log_block compile-time nothing" =
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
  (* Nothing to check here, if the run created a DB file it would cascade into the next
     test. *)
  print_endline @@ "run_counter: " ^ Int.to_string !run_counter;
  [%expect {| run_counter: 59 |}]

let%expect_test "%log_block compile-time nothing dynamic scope" =
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
  (* Nothing to check here, if the run created a DB file it would cascade into the next
     test. *)
  print_endline @@ "run_counter: " ^ Int.to_string !run_counter;
  [%expect {| run_counter: 59 |}]

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
  Minidebug_client.Client.show_trace db ~values_first_mode:false;
  [%expect
    {|
    21
    21
    21
    [track] bar @ test/test_expect_test.ml:2750:23-2758:9
      x = 7
      [track] y @ test/test_expect_test.ml:2752:8-2752:9
        y => 8
      [track] z @ test/test_expect_test.ml:2757:8-2757:9
        z => 16
      bar => 15
    |}]
