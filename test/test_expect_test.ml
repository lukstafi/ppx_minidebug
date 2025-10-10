open! Sexplib0.Sexp_conv

type t = { first : int; second : int } [@@deriving show]

(* Shared DB for all tests - each test creates a new run *)
let db_file = "test_expect_test.db"
let run_counter = ref 0

let next_run () =
  incr run_counter;
  !run_counter

let latest_run () =
  let run_id = next_run () in
  let result =
    Minidebug_client.Client.open_db db_file
    |> Minidebug_client.Client.get_latest_run |> Option.get
  in
  print_endline @@ "latest_run: " ^ Option.value ~default:"(no-name)" result.run_name;
  assert (result.run_id = run_id);
  result.run_id

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
    [debug] bar @ test/test_expect_test.ml:29:21-31:16 <TIME>
      x = { Test_expect_test.first = 7; second = 42 }
      [debug] y @ test/test_expect_test.ml:30:8-30:9 <TIME>
        y => 8
      bar => 336
    [debug] baz @ test/test_expect_test.ml:34:21-36:22 <TIME>
      x = { Test_expect_test.first = 7; second = 42 }
      [debug] _yz @ test/test_expect_test.ml:35:19-35:22 <TIME>
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
    [debug] bar @ test/test_expect_test.ml:68:21-70:16
      x = { Test_expect_test.first = 7; second = 42 }
      [debug] y @ test/test_expect_test.ml:69:8-69:9
        y => 8
      bar => 336
    [debug] baz @ test/test_expect_test.ml:73:21-75:22
      x = { Test_expect_test.first = 7; second = 42 }
      [debug] _yz @ test/test_expect_test.ml:74:19-74:22
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
    [debug] loop_complete @ test/test_expect_test.ml:106:35-108:57
      x = 7
      [debug] z @ test/test_expect_test.ml:107:8-107:9
        z => 3
      [debug] loop_complete @ test/test_expect_test.ml:106:35-108:57
        x = 6
        [debug] z @ test/test_expect_test.ml:107:8-107:9
          z => 2
        [debug] loop_complete @ test/test_expect_test.ml:106:35-108:57
          x = 5
          [debug] z @ test/test_expect_test.ml:107:8-107:9
            z => 2
          [debug] loop_complete @ test/test_expect_test.ml:106:35-108:57
            x = 4
            [debug] z @ test/test_expect_test.ml:107:8-107:9
              z => 1
            [debug] loop_complete @ test/test_expect_test.ml:106:35-108:57
              x = 3
              [debug] z @ test/test_expect_test.ml:107:8-107:9
                z => 1
              [debug] loop_complete @ test/test_expect_test.ml:106:35-108:57
                x = 2
                [debug] z @ test/test_expect_test.ml:107:8-107:9
                  z => 0
                [debug] loop_complete @ test/test_expect_test.ml:106:35-108:57
                  x = 1
                  [debug] z @ test/test_expect_test.ml:107:8-107:9
                    z => 0
                  [debug] loop_complete @ test/test_expect_test.ml:106:35-108:57
                    x = 0
                    [debug] z @ test/test_expect_test.ml:107:8-107:9
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
    [debug] loop_changes @ test/test_expect_test.ml:162:34-168:7
      x = 7
      [debug] z @ test/test_expect_test.ml:163:8-163:9
        z => 3
      [debug] loop_changes @ test/test_expect_test.ml:162:34-168:7
        x = 6
        [debug] z @ test/test_expect_test.ml:163:8-163:9
          z => 2
        [debug] loop_changes @ test/test_expect_test.ml:162:34-168:7
          x = 5
          [debug] z @ test/test_expect_test.ml:163:8-163:9
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
    [debug] loop_truncated @ test/test_expect_test.ml:200:36-203:36 <TIME>
      x = 7
      [debug] z @ test/test_expect_test.ml:201:8-201:9 <TIME>
        z => 3
      [debug] loop_truncated @ test/test_expect_test.ml:200:36-203:36 <TIME>
        x = 6
        [debug] z @ test/test_expect_test.ml:201:8-201:9 <TIME>
          z => 2
        [debug] loop_truncated @ test/test_expect_test.ml:200:36-203:36 <TIME>
          x = 5
          [debug] z @ test/test_expect_test.ml:201:8-201:9 <TIME>
            z => 2
          [debug] loop_truncated @ test/test_expect_test.ml:200:36-203:36 <TIME>
            x = 4
            [debug] z @ test/test_expect_test.ml:201:8-201:9 <TIME>
              z => 1
            [debug] loop_truncated @ test/test_expect_test.ml:200:36-203:36 <TIME>
              x = 3
              [debug] z @ test/test_expect_test.ml:201:8-201:9 <TIME>
                z => 1
              [debug] loop_truncated @ test/test_expect_test.ml:200:36-203:36 <TIME>
                x = 2
                [debug] z @ test/test_expect_test.ml:201:8-201:9 <TIME>
                  z => 0
                [debug] loop_truncated @ test/test_expect_test.ml:200:36-203:36 <TIME>
                  x = 1
                  [debug] z @ test/test_expect_test.ml:201:8-201:9 <TIME>
                    z => 0
                  [debug] loop_truncated @ test/test_expect_test.ml:200:36-203:36 <TIME>
                    x = 0
                    [debug] z @ test/test_expect_test.ml:201:8-201:9 <TIME>
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
    [debug] loop_exceeded @ test/test_expect_test.ml:260:35-264:60
      x = 7
      [debug] z @ test/test_expect_test.ml:263:10-263:11
        z => 3
      [debug] loop_exceeded @ test/test_expect_test.ml:260:35-264:60
        x = 6
        [debug] z @ test/test_expect_test.ml:263:10-263:11
          z => 2
        [debug] loop_exceeded @ test/test_expect_test.ml:260:35-264:60
          x = 5
          [debug] z @ test/test_expect_test.ml:263:10-263:11
            z => 2
          [debug] loop_exceeded @ test/test_expect_test.ml:260:35-264:60
            x = 4
            [debug] z @ test/test_expect_test.ml:263:10-263:11
              z => 1
            [debug] loop_exceeded @ test/test_expect_test.ml:260:35-264:60
              x = 3
              [debug] z @ test/test_expect_test.ml:263:10-263:11
                z => 1
              [debug] loop_exceeded @ test/test_expect_test.ml:260:35-264:60
                x = 2
                [debug] z @ test/test_expect_test.ml:263:10-263:11
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
    [debug] _bar @ test/test_expect_test.ml:311:21-311:25
      [debug] _baz @ test/test_expect_test.ml:315:16-315:20
        _baz => 0
      [debug] _baz @ test/test_expect_test.ml:315:16-315:20
        _baz => 2
      [debug] _baz @ test/test_expect_test.ml:315:16-315:20
        _baz => 4
      [debug] _baz @ test/test_expect_test.ml:315:16-315:20
        _baz => 6
      [debug] _baz @ test/test_expect_test.ml:315:16-315:20
        _baz => 8
      [debug] _baz @ test/test_expect_test.ml:315:16-315:20
        _baz => 10
      [debug] _baz @ test/test_expect_test.ml:315:16-315:20
        _baz => 12
      [debug] _baz @ test/test_expect_test.ml:315:16-315:20
        _baz => 14
      [debug] _baz @ test/test_expect_test.ml:315:16-315:20
        _baz => 16
      [debug] _baz @ test/test_expect_test.ml:315:16-315:20
        _baz => 18
      [debug] _baz @ test/test_expect_test.ml:315:16-315:20
        _baz => 20
      [debug] _baz @ test/test_expect_test.ml:315:16-315:20
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
    [track] _bar @ test/test_expect_test.ml:363:21-363:25
      [track] for:test_expect_test:366 @ test/test_expect_test.ml:366:10-369:14
        [track] <for i> @ test/test_expect_test.ml:366:14-366:15
          i = 0
          [track] _baz @ test/test_expect_test.ml:367:16-367:20
            _baz => 0
        [track] <for i> @ test/test_expect_test.ml:366:14-366:15
          i = 1
          [track] _baz @ test/test_expect_test.ml:367:16-367:20
            _baz => 2
        [track] <for i> @ test/test_expect_test.ml:366:14-366:15
          i = 2
          [track] _baz @ test/test_expect_test.ml:367:16-367:20
            _baz => 4
        [track] <for i> @ test/test_expect_test.ml:366:14-366:15
          i = 3
          [track] _baz @ test/test_expect_test.ml:367:16-367:20
            _baz => 6
        [track] <for i> @ test/test_expect_test.ml:366:14-366:15
          i = 4
          [track] _baz @ test/test_expect_test.ml:367:16-367:20
            _baz => 8
        [track] <for i> @ test/test_expect_test.ml:366:14-366:15
          i = 5
          [track] _baz @ test/test_expect_test.ml:367:16-367:20
            _baz => 10
        [track] <for i> @ test/test_expect_test.ml:366:14-366:15
          i = 6
          [track] _baz @ test/test_expect_test.ml:367:16-367:20
            _baz => 12
        [track] <for i> @ test/test_expect_test.ml:366:14-366:15
          i = 7
          [track] _baz @ test/test_expect_test.ml:367:16-367:20
            _baz => 14
        [track] <for i> @ test/test_expect_test.ml:366:14-366:15
          i = 8
          [track] _baz @ test/test_expect_test.ml:367:16-367:20
            _baz => 16
        [track] <for i> @ test/test_expect_test.ml:366:14-366:15
          i = 9
          [track] _baz @ test/test_expect_test.ml:367:16-367:20
            _baz => 18
        [track] <for i> @ test/test_expect_test.ml:366:14-366:15
          i = 10
          [track] _baz @ test/test_expect_test.ml:367:16-367:20
            _baz => 20
        [track] <for i> @ test/test_expect_test.ml:366:14-366:15
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
    [track] _bar @ test/test_expect_test.ml:438:21-438:25
      [track] for:test_expect_test:441 @ test/test_expect_test.ml:441:10-444:14
        [track] <for i> @ test/test_expect_test.ml:441:14-441:15
          i = 0
          [track] _baz @ test/test_expect_test.ml:442:16-442:20
            _baz => 0
        [track] <for i> @ test/test_expect_test.ml:441:14-441:15
          i = 1
          [track] _baz @ test/test_expect_test.ml:442:16-442:20
            _baz => 2
        [track] <for i> @ test/test_expect_test.ml:441:14-441:15
          i = 2
          [track] _baz @ test/test_expect_test.ml:442:16-442:20
            _baz => 4
        [track] <for i> @ test/test_expect_test.ml:441:14-441:15
          i = 3
          [track] _baz @ test/test_expect_test.ml:442:16-442:20
            _baz => 6
        [track] <for i> @ test/test_expect_test.ml:441:14-441:15
          i = 4
          [track] _baz @ test/test_expect_test.ml:442:16-442:20
            _baz => 8
        [track] <for i> @ test/test_expect_test.ml:441:14-441:15
          i = 5
          [track] _baz @ test/test_expect_test.ml:442:16-442:20
            _baz => 10
        [track] <for i> @ test/test_expect_test.ml:441:14-441:15
          i = 6
          [track] _baz @ test/test_expect_test.ml:442:16-442:20
            _baz => 12
      _bar => ()
    |}]

let%expect_test "%track_show track for-loop, time spans" =
  let run_id = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file ~elapsed_times:Microseconds db_file in
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
    Str.global_replace
      (Str.regexp {|[0-9]+?[0-9]+.[0-9]+[0-9]+\(μ\|m\|n\)s|})
      "N.NNμs" output
  in
  print_endline output;
  [%expect
    {|
    [track] _bar @ test/test_expect_test.ml:494:21-494:25 <N.NNμs>
      [track] for:test_expect_test:497 @ test/test_expect_test.ml:497:10-500:14 <N.NNμs>
        [track] <for i> @ test/test_expect_test.ml:497:14-497:15 <N.NNμs>
          i = 0
          [track] _baz @ test/test_expect_test.ml:498:16-498:20 <N.NNμs>
            _baz => 0
        [track] <for i> @ test/test_expect_test.ml:497:14-497:15 <N.NNμs>
          i = 1
          [track] _baz @ test/test_expect_test.ml:498:16-498:20 <N.NNμs>
            _baz => 2
        [track] <for i> @ test/test_expect_test.ml:497:14-497:15 <N.NNμs>
          i = 2
          [track] _baz @ test/test_expect_test.ml:498:16-498:20 <N.NNμs>
            _baz => 4
        [track] <for i> @ test/test_expect_test.ml:497:14-497:15 <N.NNμs>
          i = 3
          [track] _baz @ test/test_expect_test.ml:498:16-498:20 <N.NNμs>
            _baz => 6
        [track] <for i> @ test/test_expect_test.ml:497:14-497:15 <N.NNμs>
          i = 4
          [track] _baz @ test/test_expect_test.ml:498:16-498:20 <N.NNμs>
            _baz => 8
        [track] <for i> @ test/test_expect_test.ml:497:14-497:15 <N.NNμs>
          i = 5
          [track] _baz @ test/test_expect_test.ml:498:16-498:20 <N.NNμs>
            _baz => 10
        [track] <for i> @ test/test_expect_test.ml:497:14-497:15 <N.NNμs>
          i = 6
          [track] _baz @ test/test_expect_test.ml:498:16-498:20 <N.NNμs>
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
    [track] _bar @ test/test_expect_test.ml:557:21-557:25
      [track] while:test_expect_test:559 @ test/test_expect_test.ml:559:8-562:12
        [track] <while loop> @ test/test_expect_test.ml:560:10-561:16
          [track] _baz @ test/test_expect_test.ml:560:14-560:18
            _baz => 0
        [track] <while loop> @ test/test_expect_test.ml:560:10-561:16
          [track] _baz @ test/test_expect_test.ml:560:14-560:18
            _baz => 2
        [track] <while loop> @ test/test_expect_test.ml:560:10-561:16
          [track] _baz @ test/test_expect_test.ml:560:14-560:18
            _baz => 4
        [track] <while loop> @ test/test_expect_test.ml:560:10-561:16
          [track] _baz @ test/test_expect_test.ml:560:14-560:18
            _baz => 6
        [track] <while loop> @ test/test_expect_test.ml:560:10-561:16
          [track] _baz @ test/test_expect_test.ml:560:14-560:18
            _baz => 8
        [track] <while loop> @ test/test_expect_test.ml:560:10-561:16
          [track] _baz @ test/test_expect_test.ml:560:14-560:18
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
    [debug] loop_exceeded @ test/test_expect_test.ml:600:35-608:72
      x = 3
      [debug] z @ test/test_expect_test.ml:607:17-607:18
        z => 1
      [debug] loop_exceeded @ test/test_expect_test.ml:600:35-608:72
        x = 2
        [debug] z @ test/test_expect_test.ml:607:17-607:18
          z => 0
        [debug] loop_exceeded @ test/test_expect_test.ml:600:35-608:72
          x = 1
          [debug] z @ test/test_expect_test.ml:607:17-607:18
            z => 0
          [debug] loop_exceeded @ test/test_expect_test.ml:600:35-608:72
            x = 0
            [debug] z @ test/test_expect_test.ml:607:17-607:18
              z => 0
            [debug] z @ test/test_expect_test.ml:607:17-607:18
              z => 1
            [debug] z @ test/test_expect_test.ml:607:17-607:18
              z => 2
            [debug] z @ test/test_expect_test.ml:607:17-607:18
              z => 3
            [debug] z @ test/test_expect_test.ml:607:17-607:18
              z => 4
            [debug] z @ test/test_expect_test.ml:607:17-607:18
              z => 5
            [debug] z @ test/test_expect_test.ml:607:17-607:18
              z => 6
            [debug] z @ test/test_expect_test.ml:607:17-607:18
              z => 7
            [debug] z @ test/test_expect_test.ml:607:17-607:18
              z => 8
            [debug] z @ test/test_expect_test.ml:607:17-607:18
              z => 9
            [debug] z @ test/test_expect_test.ml:607:17-607:18
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
    [track] track_branches @ test/test_expect_test.ml:663:32-665:46
      x = 7
      [track] else:test_expect_test:665 @ test/test_expect_test.ml:665:9-665:46
        [track] <match -- branch 1> @ test/test_expect_test.ml:665:36-665:37
      track_branches => 4
    [track] track_branches @ test/test_expect_test.ml:663:32-665:46
      x = 3
      [track] then:test_expect_test:664 @ test/test_expect_test.ml:664:18-664:57
        [track] <match -- branch 2> @ test/test_expect_test.ml:664:54-664:57
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
    [track] <function -- branch 3> @ test/test_expect_test.ml:701:11-701:12
    [track] <function -- branch 5> x @ test/test_expect_test.ml:703:11-703:14
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
    [track] track_branches @ test/test_expect_test.ml:728:32-742:16
      x = 8
      [track] else:test_expect_test:737 @ test/test_expect_test.ml:737:6-742:16
        [track] <match -- branch 2> @ test/test_expect_test.ml:741:10-742:16
          [track] result @ test/test_expect_test.ml:741:14-741:20
            [track] then:test_expect_test:741 @ test/test_expect_test.ml:741:44-741:45
            result => 8
      track_branches => 8
    [track] track_branches @ test/test_expect_test.ml:728:32-742:16
      x = 3
      [track] then:test_expect_test:730 @ test/test_expect_test.ml:730:6-735:16
        [debug] result @ test/test_expect_test.ml:734:14-734:20
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
  let () =
    try print_endline @@ Int.to_string @@ track_foo 8
    with _ -> print_endline "Raised exception."
  in
  let db = Minidebug_client.Client.open_db db_file in
  Minidebug_client.Client.show_trace db ~values_first_mode:false run_id;
  [%expect
    {|
    8
    [track] track_foo @ test/test_expect_test.ml:780:27-784:5
      x = 8
      [track] fun:test_expect_test:783 @ test/test_expect_test.ml:783:4-783:31
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
    [track] track_branches @ test/test_expect_test.ml:808:32-822:16
      x = 8
      [track] else:test_expect_test:817 @ test/test_expect_test.ml:817:6-822:16
        [track] result @ test/test_expect_test.ml:821:25-821:31
          [track] then:test_expect_test:821 @ test/test_expect_test.ml:821:55-821:56
          result => 8
      track_branches => 8
    [track] track_branches @ test/test_expect_test.ml:808:32-822:16
      x = 3
      [track] then:test_expect_test:810 @ test/test_expect_test.ml:810:6-815:16
        [debug] result @ test/test_expect_test.ml:814:25-814:31
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
    [debug] anonymous @ test/test_expect_test.ml:857:27-860:73
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
    [debug] wrapper @ test/test_expect_test.ml:887:25-897:25
    [debug] anonymous @ test/test_expect_test.ml:888:29-891:75
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
    [debug] anonymous @ test/test_expect_test.ml:921:27-922:70
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
    [track] anonymous @ test/test_expect_test.ml:944:27-945:70
      x = 3
      [track] fun:test_expect_test:945 @ test/test_expect_test.ml:945:50-945:70
        i = 0
      [track] fun:test_expect_test:945 @ test/test_expect_test.ml:945:50-945:70
        i = 1
      [track] fun:test_expect_test:945 @ test/test_expect_test.ml:945:50-945:70
        i = 2
      [track] fun:test_expect_test:945 @ test/test_expect_test.ml:945:50-945:70
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
    [track] loop_exceeded @ test/test_expect_test.ml:975:35-983:72
      x = 3
      [track] fun:test_expect_test:981 @ test/test_expect_test.ml:981:11-983:71
        i = 0
        [track] z @ test/test_expect_test.ml:982:17-982:18
          z => 1
        [track] else:test_expect_test:983 @ test/test_expect_test.ml:983:35-983:70
          [track] loop_exceeded @ test/test_expect_test.ml:975:35-983:72
            x = 2
            [track] fun:test_expect_test:981 @ test/test_expect_test.ml:981:11-983:71
              i = 0
              [track] z @ test/test_expect_test.ml:982:17-982:18
                z => 0
              [track] else:test_expect_test:983 @ test/test_expect_test.ml:983:35-983:70
                [track] loop_exceeded @ test/test_expect_test.ml:975:35-983:72
                  x = 1
                  [track] fun:test_expect_test:981 @ test/test_expect_test.ml:981:11-983:71
                    i = 0
                    [track] z @ test/test_expect_test.ml:982:17-982:18
                      z => 0
                    [track] else:test_expect_test:983 @ test/test_expect_test.ml:983:35-983:70
                      [track] loop_exceeded @ test/test_expect_test.ml:975:35-983:72
                        x = 0
                        [track] fun:test_expect_test:981 @ test/test_expect_test.ml:981:11-983:71
                          i = 0
                          [track] z @ test/test_expect_test.ml:982:17-982:18
                            z => 0
                          [track] then:test_expect_test:983 @ test/test_expect_test.ml:983:28-983:29
                        [track] fun:test_expect_test:981 @ test/test_expect_test.ml:981:11-983:71
                          i = 1
                          [track] z @ test/test_expect_test.ml:982:17-982:18
                            z => 1
                          [track] then:test_expect_test:983 @ test/test_expect_test.ml:983:28-983:29
                        [track] fun:test_expect_test:981 @ test/test_expect_test.ml:981:11-983:71
                          i = 2
                          [track] z @ test/test_expect_test.ml:982:17-982:18
                            z => 2
                          [track] then:test_expect_test:983 @ test/test_expect_test.ml:983:28-983:29
                        [track] fun:test_expect_test:981 @ test/test_expect_test.ml:981:11-983:71
                          i = 3
                          [track] z @ test/test_expect_test.ml:982:17-982:18
                            z => 3
                          [track] then:test_expect_test:983 @ test/test_expect_test.ml:983:28-983:29
                        [track] fun:test_expect_test:981 @ test/test_expect_test.ml:981:11-983:71
                          i = 4
                          [track] z @ test/test_expect_test.ml:982:17-982:18
                            z => 4
                          [track] then:test_expect_test:983 @ test/test_expect_test.ml:983:28-983:29
                        [track] fun:test_expect_test:981 @ test/test_expect_test.ml:981:11-983:71
                          i = 5
                          [track] z @ test/test_expect_test.ml:982:17-982:18
                            z => 5
                          [track] then:test_expect_test:983 @ test/test_expect_test.ml:983:28-983:29
                        [track] fun:test_expect_test:981 @ test/test_expect_test.ml:981:11-983:71
                          i = 6
                          [track] z @ test/test_expect_test.ml:982:17-982:18
                            z => 6
                          [track] then:test_expect_test:983 @ test/test_expect_test.ml:983:28-983:29
                        [track] fun:test_expect_test:981 @ test/test_expect_test.ml:981:11-983:71
                          i = 7
                          [track] z @ test/test_expect_test.ml:982:17-982:18
                            z => 7
                          [track] then:test_expect_test:983 @ test/test_expect_test.ml:983:28-983:29
                        [track] fun:test_expect_test:981 @ test/test_expect_test.ml:981:11-983:71
                          i = 8
                          [track] z @ test/test_expect_test.ml:982:17-982:18
                            z => 8
                          [track] then:test_expect_test:983 @ test/test_expect_test.ml:983:28-983:29
                        [track] fun:test_expect_test:981 @ test/test_expect_test.ml:981:11-983:71
                          i = 9
                          [track] z @ test/test_expect_test.ml:982:17-982:18
                            z => 9
                          [track] then:test_expect_test:983 @ test/test_expect_test.ml:983:28-983:29
                        [track] fun:test_expect_test:981 @ test/test_expect_test.ml:981:11-983:71
                          i = 10
                          fun:test_expect_test:981 = <max_num_children exceeded>
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
    [debug] foo @ test/test_expect_test.ml:1084:21-1085:47
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
    [debug] loop_truncated @ test/test_expect_test.ml:1115:36-1118:36
      x = 7
      [debug] z => 3 @ test/test_expect_test.ml:1116:8-1116:9
      [debug] loop_truncated @ test/test_expect_test.ml:1115:36-1118:36
        x = 6
        [debug] z => 2 @ test/test_expect_test.ml:1116:8-1116:9
        [debug] loop_truncated @ test/test_expect_test.ml:1115:36-1118:36
          x = 5
          [debug] z => 2 @ test/test_expect_test.ml:1116:8-1116:9
          [debug] loop_truncated @ test/test_expect_test.ml:1115:36-1118:36
            x = 4
            [debug] z => 1 @ test/test_expect_test.ml:1116:8-1116:9
            [debug] loop_truncated @ test/test_expect_test.ml:1115:36-1118:36
              x = 3
              [debug] z => 1 @ test/test_expect_test.ml:1116:8-1116:9
              [debug] loop_truncated @ test/test_expect_test.ml:1115:36-1118:36
                x = 2
                [debug] z => 0 @ test/test_expect_test.ml:1116:8-1116:9
                [debug] loop_truncated @ test/test_expect_test.ml:1115:36-1118:36
                  x = 1
                  [debug] z => 0 @ test/test_expect_test.ml:1116:8-1116:9
                  [debug] loop_truncated @ test/test_expect_test.ml:1115:36-1118:36
                    x = 0
                    [debug] z => 0 @ test/test_expect_test.ml:1116:8-1116:9
    |}]

let%expect_test "%debug_show values_first_mode to stdout num children exceeded linear" =
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
    [debug] _bar @ test/test_expect_test.ml:1163:21-1163:25
      [debug] _baz => 0 @ test/test_expect_test.ml:1167:16-1167:20
      [debug] _baz => 2 @ test/test_expect_test.ml:1167:16-1167:20
      [debug] _baz => 4 @ test/test_expect_test.ml:1167:16-1167:20
      [debug] _baz => 6 @ test/test_expect_test.ml:1167:16-1167:20
      [debug] _baz => 8 @ test/test_expect_test.ml:1167:16-1167:20
      [debug] _baz => 10 @ test/test_expect_test.ml:1167:16-1167:20
      [debug] _baz => 12 @ test/test_expect_test.ml:1167:16-1167:20
      [debug] _baz => 14 @ test/test_expect_test.ml:1167:16-1167:20
      [debug] _baz => 16 @ test/test_expect_test.ml:1167:16-1167:20
      [debug] _baz => 18 @ test/test_expect_test.ml:1167:16-1167:20
      [debug] _baz => 20 @ test/test_expect_test.ml:1167:16-1167:20
      [debug] _baz @ test/test_expect_test.ml:1167:16-1167:20
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
    [track] _bar => () @ test/test_expect_test.ml:1203:21-1203:25
      [track] for:test_expect_test:1206 @ test/test_expect_test.ml:1206:10-1209:14
        [track] <for i> @ test/test_expect_test.ml:1206:14-1206:15
          i = 0
          [track] _baz => 0 @ test/test_expect_test.ml:1207:16-1207:20
        [track] <for i> @ test/test_expect_test.ml:1206:14-1206:15
          i = 1
          [track] _baz => 2 @ test/test_expect_test.ml:1207:16-1207:20
        [track] <for i> @ test/test_expect_test.ml:1206:14-1206:15
          i = 2
          [track] _baz => 4 @ test/test_expect_test.ml:1207:16-1207:20
        [track] <for i> @ test/test_expect_test.ml:1206:14-1206:15
          i = 3
          [track] _baz => 6 @ test/test_expect_test.ml:1207:16-1207:20
        [track] <for i> @ test/test_expect_test.ml:1206:14-1206:15
          i = 4
          [track] _baz => 8 @ test/test_expect_test.ml:1207:16-1207:20
        [track] <for i> @ test/test_expect_test.ml:1206:14-1206:15
          i = 5
          [track] _baz => 10 @ test/test_expect_test.ml:1207:16-1207:20
        [track] <for i> @ test/test_expect_test.ml:1206:14-1206:15
          i = 6
          [track] _baz => 12 @ test/test_expect_test.ml:1207:16-1207:20
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
    [debug] loop_exceeded @ test/test_expect_test.ml:1249:35-1257:72
      x = 3
      [debug] z => 1 @ test/test_expect_test.ml:1256:17-1256:18
      [debug] loop_exceeded @ test/test_expect_test.ml:1249:35-1257:72
        x = 2
        [debug] z => 0 @ test/test_expect_test.ml:1256:17-1256:18
        [debug] loop_exceeded @ test/test_expect_test.ml:1249:35-1257:72
          x = 1
          [debug] z => 0 @ test/test_expect_test.ml:1256:17-1256:18
          [debug] loop_exceeded @ test/test_expect_test.ml:1249:35-1257:72
            x = 0
            [debug] z => 0 @ test/test_expect_test.ml:1256:17-1256:18
            [debug] z => 1 @ test/test_expect_test.ml:1256:17-1256:18
            [debug] z => 2 @ test/test_expect_test.ml:1256:17-1256:18
            [debug] z => 3 @ test/test_expect_test.ml:1256:17-1256:18
            [debug] z => 4 @ test/test_expect_test.ml:1256:17-1256:18
            [debug] z => 5 @ test/test_expect_test.ml:1256:17-1256:18
            [debug] z => 6 @ test/test_expect_test.ml:1256:17-1256:18
            [debug] z => 7 @ test/test_expect_test.ml:1256:17-1256:18
            [debug] z => 8 @ test/test_expect_test.ml:1256:17-1256:18
            [debug] z => 9 @ test/test_expect_test.ml:1256:17-1256:18
            [debug] z @ test/test_expect_test.ml:1256:17-1256:18
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
    [track] track_branches => 4 @ test/test_expect_test.ml:1299:32-1301:46
      x = 7
      [track] else:test_expect_test:1301 @ test/test_expect_test.ml:1301:9-1301:46
        [track] <match -- branch 1> @ test/test_expect_test.ml:1301:36-1301:37
    [track] track_branches => -3 @ test/test_expect_test.ml:1299:32-1301:46
      x = 3
      [track] then:test_expect_test:1300 @ test/test_expect_test.ml:1300:18-1300:57
        [track] <match -- branch 2> @ test/test_expect_test.ml:1300:54-1300:57
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
    [track] anonymous @ test/test_expect_test.ml:1331:27-1332:70
      x = 3
      [track] fun:test_expect_test:1332 @ test/test_expect_test.ml:1332:50-1332:70
        i = 0
      [track] fun:test_expect_test:1332 @ test/test_expect_test.ml:1332:50-1332:70
        i = 1
      [track] fun:test_expect_test:1332 @ test/test_expect_test.ml:1332:50-1332:70
        i = 2
      [track] fun:test_expect_test:1332 @ test/test_expect_test.ml:1332:50-1332:70
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
    [debug] bar @ test/test_expect_test.ml:1361:21-1364:15
      first = 7
      second = 42
      [debug] {first=a; second=b} @ test/test_expect_test.ml:1362:8-1362:45
        a => 7
        b => 45
      [debug] y @ test/test_expect_test.ml:1363:8-1363:9
        y => 8
      bar => 336
    [debug] baz @ test/test_expect_test.ml:1367:21-1369:28
      first = 7
      second = 42
      [debug] {first; second} @ test/test_expect_test.ml:1368:8-1368:37
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
    [debug] bar @ test/test_expect_test.ml:1402:21-1404:14
      first = 7
      second = 42
      [debug] y @ test/test_expect_test.ml:1403:8-1403:9
        y => 8
      bar => 336
    [debug] (r1, r2) @ test/test_expect_test.ml:1412:17-1412:23
      [debug] baz @ test/test_expect_test.ml:1407:21-1410:35
        first = 7
        second = 42
        [debug] (y, z) @ test/test_expect_test.ml:1408:8-1408:14
          y => 8
          z => 3
        [debug] (a, b) @ test/test_expect_test.ml:1409:8-1409:28
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
    [debug] bar => 336 @ test/test_expect_test.ml:1449:21-1452:15
      first = 7
      second = 42
      [debug] {first=a; second=b} @ test/test_expect_test.ml:1450:8-1450:45
        a => 7
        b => 45
      [debug] y => 8 @ test/test_expect_test.ml:1451:8-1451:9
    [debug] baz => 109 @ test/test_expect_test.ml:1455:21-1457:28
      first = 7
      second = 42
      [debug] {first; second} @ test/test_expect_test.ml:1456:8-1456:37
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
    [debug] bar => 336 @ test/test_expect_test.ml:1487:21-1489:14
      first = 7
      second = 42
      [debug] y => 8 @ test/test_expect_test.ml:1488:8-1488:9
    [debug] (r1, r2) @ test/test_expect_test.ml:1497:17-1497:23
      r1 => 339
      r2 => 109
      [debug] baz => (339, 109) @ test/test_expect_test.ml:1492:21-1495:35
        first = 7
        second = 42
        [debug] (y, z) @ test/test_expect_test.ml:1493:8-1493:14
          y => 8
          z => 3
        [debug] (a, b) @ test/test_expect_test.ml:1494:8-1494:28
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
    [track] bar => 16 @ test/test_expect_test.ml:1535:21-1537:9
      x = 7
      [track] y => 8 @ test/test_expect_test.ml:1536:8-1536:9
    [track] <function -- branch 0> Left x => baz = 5 @ test/test_expect_test.ml:1541:24-1541:29
      x = 4
    [track] <function -- branch 1> Right Two y => baz = 6 @ test/test_expect_test.ml:1542:31-1542:36
      y = 3
    [track] foo => 3 @ test/test_expect_test.ml:1545:21-1546:82
      [track] <match -- branch 2> @ test/test_expect_test.ml:1546:81-1546:82
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
    [debug] (r1, r2) @ test/test_expect_test.ml:1581:17-1581:38
      r1 => 339
      r2 => 109
      [debug] baz => (339, 109) @ test/test_expect_test.ml:1576:21-1579:35
        first = 7
        second = 42
        [debug] (y, z) @ test/test_expect_test.ml:1577:8-1577:29
          y => 8
          z => 3
        [debug] (a, b) => a = 8 @ test/test_expect_test.ml:1578:8-1578:20
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
    [debug] f => 7 @ test/test_expect_test.ml:1609:44-1609:61
      b = 6
    [debug] g => 12 @ test/test_expect_test.ml:1610:56-1610:79
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
    [debug] f : int => 7 @ test/test_expect_test.ml:1634:37-1634:54
      b : int = 6
    [debug] g : int => 12 @ test/test_expect_test.ml:1635:49-1635:72
      b : int = 6
    |}]
(* $MDX part-end *)

let%expect_test "%track_show options values_first_mode" =
  let run_id = next_run () in
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
  let db = Minidebug_client.Client.open_db db_file in
  Minidebug_client.Client.show_trace db ~values_first_mode:true run_id;
  [%expect
    {|
    14
    14
    8
    9
    [track] foo => 14 @ test/test_expect_test.ml:1657:21-1658:59
      [track] <match -- branch 1> Some y @ test/test_expect_test.ml:1658:54-1658:59
        y = 7
    [track] bar => 14 @ test/test_expect_test.ml:1661:21-1662:44
      l = (Some 7)
      [track] <match -- branch 1> Some y @ test/test_expect_test.ml:1662:39-1662:44
    [track] <function -- branch 1> Some y => baz = 8 @ test/test_expect_test.ml:1665:74-1665:79
      y = 4
    [track] <function -- branch 1> Some (y, z) => zoo = 9 @ test/test_expect_test.ml:1669:21-1669:26
      y = 4
      z = 5
    |}]

let%expect_test "%track_show list values_first_mode" =
  let run_id = next_run () in
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
  let db = Minidebug_client.Client.open_db db_file in
  Minidebug_client.Client.show_trace db ~values_first_mode:true run_id;
  [%expect
    {|
    14
    14
    8
    9
    10
    [track] foo => 14 @ test/test_expect_test.ml:1699:21-1699:82
      [track] <match -- branch 1> :: (y, _) @ test/test_expect_test.ml:1699:77-1699:82
        y = 7
    [track] bar => 14 @ test/test_expect_test.ml:1701:21-1701:82
      l = [7]
      [track] <match -- branch 1> :: (y, _) @ test/test_expect_test.ml:1701:77-1701:82
    [track] <function -- branch 1> :: (y, []) => baz = 8 @ test/test_expect_test.ml:1705:15-1705:20
      y = 4
    [track] <function -- branch 2> :: (y, :: (z, [])) => baz = 9 @ test/test_expect_test.ml:1706:18-1706:23
      y = 4
      z = 5
    [track] <function -- branch 3> :: (y, :: (z, _)) => baz = 10 @ test/test_expect_test.ml:1707:21-1707:30
      y = 4
      z = 5
    |}]

let%expect_test "%track_rt_show list runtime passing" =
  (* $MDX part-begin=track_rt_show_list_runtime_passing *)
  let rt run_name = Minidebug_db.debug_db_file ~run_name db_file in
  let%track_rt_show foo l : int = match (l : int list) with [] -> 7 | y :: _ -> y * 2 in
  let () = print_endline @@ Int.to_string @@ foo (rt "foo-1") [ 7 ] in
  let db = Minidebug_client.Client.open_db db_file in
  Minidebug_client.Client.show_trace db ~values_first_mode:true (latest_run ());
  let%track_rt_show baz : int list -> int = function
    | [] -> 7
    | [ y ] -> y * 2
    | [ y; z ] -> y + z
    | y :: z :: _ -> y + z + 1
  in
  let () = print_endline @@ Int.to_string @@ baz (rt "baz-1") [ 4 ] in
  Minidebug_client.Client.show_trace db ~values_first_mode:true (latest_run ());
  let () = print_endline @@ Int.to_string @@ baz (rt "baz-2") [ 4; 5; 6 ] in
  Minidebug_client.Client.show_trace db ~values_first_mode:true (latest_run ());
  [%expect
    {|
    14
    latest_run: foo-1
    [track] foo => 14 @ test/test_expect_test.ml:1740:24-1740:85
      [track] <match -- branch 1> :: (y, _) @ test/test_expect_test.ml:1740:80-1740:85
        y = 7
    8
    latest_run: baz-1
    [track] <function -- branch 1> :: (y, []) => baz = 8 @ test/test_expect_test.ml:1746:15-1746:20
      y = 4
    10
    latest_run: baz-2
    [track] <function -- branch 3> :: (y, :: (z, _)) => baz = 10 @ test/test_expect_test.ml:1748:21-1748:30
      y = 4
      z = 5
    |}]
(* $MDX part-end *)

let%expect_test "%track_rt_show procedure runtime passing" =
  let rt run_name = Minidebug_db.debug_db_file ~run_name db_file in
  let%track_rt_show bar () = (fun () -> ()) () in
  let () = bar (rt "bar-1") () in
  let db = Minidebug_client.Client.open_db db_file in
  Minidebug_client.Client.show_trace db (latest_run ());
  let () = bar (rt "bar-2") () in
  Minidebug_client.Client.show_trace db (latest_run ());
  let%track_rt_show foo () =
    let () = () in
    ()
  in
  let () = foo (rt "foo-1") () in
  Minidebug_client.Client.show_trace db (latest_run ());
  let () = foo (rt "foo-2") () in
  Minidebug_client.Client.show_trace db (latest_run ());
  [%expect
    {|
    latest_run: bar-1
    [track] bar @ test/test_expect_test.ml:1775:24-1775:46
      [track] fun:test_expect_test:1775 @ test/test_expect_test.ml:1775:29-1775:43
    latest_run: bar-2
    [track] bar @ test/test_expect_test.ml:1775:24-1775:46
      [track] fun:test_expect_test:1775 @ test/test_expect_test.ml:1775:29-1775:43
    latest_run: foo-1
    [track] foo @ test/test_expect_test.ml:1781:24-1783:6
    latest_run: foo-2
    [track] foo @ test/test_expect_test.ml:1781:24-1783:6
    |}]

let%expect_test "%track_rt_show nested procedure runtime passing" =
  let rt run_name = Minidebug_db.debug_db_file ~run_name db_file in
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
  let db = Minidebug_client.Client.open_db db_file in
  let () = foo (rt "foo-1") () in
  Minidebug_client.Client.show_trace db (latest_run ());
  let () = foo (rt "foo-2") () in
  Minidebug_client.Client.show_trace db (latest_run ());
  let () = bar (rt "bar-1") () in
  Minidebug_client.Client.show_trace db (latest_run ());
  let () = bar (rt "bar-2") () in
  Minidebug_client.Client.show_trace db (latest_run ());
  [%expect
    {|
    latest_run: foo-1
    [track] foo @ test/test_expect_test.ml:1811:26-1813:8
    latest_run: foo-2
    [track] foo @ test/test_expect_test.ml:1811:26-1813:8
    latest_run: bar-1
    [track] bar @ test/test_expect_test.ml:1810:26-1810:48
      [track] fun:test_expect_test:1810 @ test/test_expect_test.ml:1810:31-1810:45
    latest_run: bar-2
    [track] bar @ test/test_expect_test.ml:1810:26-1810:48
      [track] fun:test_expect_test:1810 @ test/test_expect_test.ml:1810:31-1810:45
    |}]

let%expect_test "%log constant entries" =
  let run_id1 = next_run () in
  let rt1 = Minidebug_db.debug_db_file ~boxify_sexp_from_size:20 db_file in
  let _get_local_debug_runtime = fun () -> rt1 in
  let%debug_show foo () : unit =
    [%log "This is the first log line"];
    [%log [ "This is the"; "2"; "log line" ]];
    [%log "This is the", 3, "or", 3.14, "log line"]
  in
  let () = foo () in
  let db = Minidebug_client.Client.open_db db_file in
  Minidebug_client.Client.show_trace db run_id1;
  let run_id2 = next_run () in
  let rt2 = Minidebug_db.debug_db_file ~boxify_sexp_from_size:2 db_file in
  let _get_local_debug_runtime = fun () -> rt2 in
  let%debug_sexp bar () : unit =
    [%log "This is the first log line"];
    [%log [ "This is the"; "2"; "log line" ]];
    [%log "This is the", 3, "or", 3.14, "log line"]
  in
  let () = bar () in
  Minidebug_client.Client.show_trace db run_id2;
  [%expect
    {|
    [debug] foo => () @ test/test_expect_test.ml:1845:21-1848:51
      "This is the first log line"
      ["This is the"; "2"; "log line"]
      ("This is the", 3, "or", 3.14, "log line")
    [debug] bar @ test/test_expect_test.ml:1856:21-1859:51
      "This is the first log line"
      2
      "log line"
      3
      or
      3.14
      "log line"
    |}]

let%expect_test "%log with type annotations" =
  let run_id = next_run () in
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
  let db = Minidebug_client.Client.open_db db_file in
  Minidebug_client.Client.show_trace db run_id;
  [%expect
    {|
    [debug] foo => () @ test/test_expect_test.ml:1888:21-1893:25
      ("This is like", 3, "or", 3.14, "above")
      ("tau =", 6.28)
      [4; 1; 2; 3]
      [3; 1; 2; 3]
      [3; 1; 2; 3]
    |}]

let%expect_test "%log with default type assumption" =
  let run_id = next_run () in
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
  let db = Minidebug_client.Client.open_db db_file in
  Minidebug_client.Client.show_trace db run_id;
  [%expect
    {|
    [debug] foo => () @ test/test_expect_test.ml:1918:21-1925:25
      "2*3"
      ("This is like", "3", "or", "3.14", "above")
      ("tau =", "2*3.14")
      [("2*3", 0); ("1", 1); ("2", 2); ("3", 3)]
    |}]

let%expect_test "%log track while-loop" =
  let run_id = next_run () in
  (* $MDX part-begin=track_while_loop_example *)
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
      [%log 3, "j=", (!j : int)]
    done;
    !j
  in
  let () = print_endline @@ Int.to_string result in
  let db = Minidebug_client.Client.open_db db_file in
  Minidebug_client.Client.show_trace db run_id;
  [%expect
    {|
    21
    [track] result @ test/test_expect_test.ml:1946:17-1946:23
      [track] while:test_expect_test:1949 @ test/test_expect_test.ml:1949:4-1955:8
        [track] <while loop> @ test/test_expect_test.ml:1950:6-1954:32
          (1 i= 0)
          (2 i= 1)
          (3 j= 1)
        [track] <while loop> @ test/test_expect_test.ml:1950:6-1954:32
          (1 i= 1)
          (2 i= 2)
          (3 j= 3)
        [track] <while loop> @ test/test_expect_test.ml:1950:6-1954:32
          (1 i= 2)
          (2 i= 3)
          (3 j= 6)
        [track] <while loop> @ test/test_expect_test.ml:1950:6-1954:32
          (1 i= 3)
          (2 i= 4)
          (3 j= 10)
        [track] <while loop> @ test/test_expect_test.ml:1950:6-1954:32
          (1 i= 4)
          (2 i= 5)
          (3 j= 15)
        [track] <while loop> @ test/test_expect_test.ml:1950:6-1954:32
          (1 i= 5)
          (2 i= 6)
          (3 j= 21)
    |}]
(* $MDX part-end *)

let%expect_test "%log runtime log levels while-loop" =
  (* $MDX part-begin=log_runtime_log_levels_while_loop_example *)
  let rt log_level run_name = Minidebug_db.debug_db_file ~log_level ~run_name db_file in
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
  let db = Minidebug_client.Client.open_db db_file in
  Minidebug_client.Client.show_trace db (latest_run ());
  print_endline @@ Int.to_string (result (rt 0 "Nothing") ());
  let latest_run_after_nothing =
    Minidebug_client.Client.open_db db_file
    |> Minidebug_client.Client.get_latest_run |> Option.get
  in
  print_endline @@ "latest_run_after_nothing: "
  ^ Option.get latest_run_after_nothing.run_name;
  print_endline @@ Int.to_string (result (rt 1 "Error") ());
  (* $MDX part-end *)
  Minidebug_client.Client.show_trace db (latest_run ());
  print_endline @@ Int.to_string (result (rt 2 "Warning") ());
  Minidebug_client.Client.show_trace db (latest_run ());
  [%expect
    {|
    21
    latest_run: Everything
    [track] result => 21 @ test/test_expect_test.ml:1996:27-2007:6
      [track] while:test_expect_test:1999 @ test/test_expect_test.ml:1999:4-2006:8
        [track] <while loop> @ test/test_expect_test.ml:2001:6-2005:42
          [track] then:test_expect_test:2001 @ test/test_expect_test.ml:2001:21-2001:58
            (ERROR: 1 i= 0)
          (WARNING: 2 i= 1)
          [track] fun:test_expect_test:2004 @ test/test_expect_test.ml:2004:11-2004:46
          (INFO: 3 j= 1)
        [track] <while loop> @ test/test_expect_test.ml:2001:6-2005:42
          [track] then:test_expect_test:2001 @ test/test_expect_test.ml:2001:21-2001:58
            (ERROR: 1 i= 1)
          (WARNING: 2 i= 2)
          [track] fun:test_expect_test:2004 @ test/test_expect_test.ml:2004:11-2004:46
          (INFO: 3 j= 3)
        [track] <while loop> @ test/test_expect_test.ml:2001:6-2005:42
          [track] else:test_expect_test:2001 @ test/test_expect_test.ml:2001:64-2001:66
          (WARNING: 2 i= 3)
          [track] fun:test_expect_test:2004 @ test/test_expect_test.ml:2004:11-2004:46
          (INFO: 3 j= 6)
        [track] <while loop> @ test/test_expect_test.ml:2001:6-2005:42
          [track] else:test_expect_test:2001 @ test/test_expect_test.ml:2001:64-2001:66
          (WARNING: 2 i= 4)
          [track] fun:test_expect_test:2004 @ test/test_expect_test.ml:2004:11-2004:46
          (INFO: 3 j= 10)
        [track] <while loop> @ test/test_expect_test.ml:2001:6-2005:42
          [track] else:test_expect_test:2001 @ test/test_expect_test.ml:2001:64-2001:66
          (WARNING: 2 i= 5)
          [track] fun:test_expect_test:2004 @ test/test_expect_test.ml:2004:11-2004:46
          (INFO: 3 j= 15)
        [track] <while loop> @ test/test_expect_test.ml:2001:6-2005:42
          [track] else:test_expect_test:2001 @ test/test_expect_test.ml:2001:64-2001:66
          (WARNING: 2 i= 6)
          [track] fun:test_expect_test:2004 @ test/test_expect_test.ml:2004:11-2004:46
          (INFO: 3 j= 21)
    21
    latest_run_after_nothing: Everything
    21
    latest_run: Error
    [track] result => 21 @ test/test_expect_test.ml:1996:27-2007:6
      [track] while:test_expect_test:1999 @ test/test_expect_test.ml:1999:4-2006:8
        [track] <while loop> @ test/test_expect_test.ml:2001:6-2005:42
          [track] then:test_expect_test:2001 @ test/test_expect_test.ml:2001:21-2001:58
            (ERROR: 1 i= 0)
          [track] fun:test_expect_test:2004 @ test/test_expect_test.ml:2004:11-2004:46
        [track] <while loop> @ test/test_expect_test.ml:2001:6-2005:42
          [track] then:test_expect_test:2001 @ test/test_expect_test.ml:2001:21-2001:58
            (ERROR: 1 i= 1)
          [track] fun:test_expect_test:2004 @ test/test_expect_test.ml:2004:11-2004:46
        [track] <while loop> @ test/test_expect_test.ml:2001:6-2005:42
          [track] else:test_expect_test:2001 @ test/test_expect_test.ml:2001:64-2001:66
          [track] fun:test_expect_test:2004 @ test/test_expect_test.ml:2004:11-2004:46
        [track] <while loop> @ test/test_expect_test.ml:2001:6-2005:42
          [track] else:test_expect_test:2001 @ test/test_expect_test.ml:2001:64-2001:66
          [track] fun:test_expect_test:2004 @ test/test_expect_test.ml:2004:11-2004:46
        [track] <while loop> @ test/test_expect_test.ml:2001:6-2005:42
          [track] else:test_expect_test:2001 @ test/test_expect_test.ml:2001:64-2001:66
          [track] fun:test_expect_test:2004 @ test/test_expect_test.ml:2004:11-2004:46
        [track] <while loop> @ test/test_expect_test.ml:2001:6-2005:42
          [track] else:test_expect_test:2001 @ test/test_expect_test.ml:2001:64-2001:66
          [track] fun:test_expect_test:2004 @ test/test_expect_test.ml:2004:11-2004:46
    21
    latest_run: Warning
    [track] result => 21 @ test/test_expect_test.ml:1996:27-2007:6
      [track] while:test_expect_test:1999 @ test/test_expect_test.ml:1999:4-2006:8
        [track] <while loop> @ test/test_expect_test.ml:2001:6-2005:42
          [track] then:test_expect_test:2001 @ test/test_expect_test.ml:2001:21-2001:58
            (ERROR: 1 i= 0)
          (WARNING: 2 i= 1)
          [track] fun:test_expect_test:2004 @ test/test_expect_test.ml:2004:11-2004:46
        [track] <while loop> @ test/test_expect_test.ml:2001:6-2005:42
          [track] then:test_expect_test:2001 @ test/test_expect_test.ml:2001:21-2001:58
            (ERROR: 1 i= 1)
          (WARNING: 2 i= 2)
          [track] fun:test_expect_test:2004 @ test/test_expect_test.ml:2004:11-2004:46
        [track] <while loop> @ test/test_expect_test.ml:2001:6-2005:42
          [track] else:test_expect_test:2001 @ test/test_expect_test.ml:2001:64-2001:66
          (WARNING: 2 i= 3)
          [track] fun:test_expect_test:2004 @ test/test_expect_test.ml:2004:11-2004:46
        [track] <while loop> @ test/test_expect_test.ml:2001:6-2005:42
          [track] else:test_expect_test:2001 @ test/test_expect_test.ml:2001:64-2001:66
          (WARNING: 2 i= 4)
          [track] fun:test_expect_test:2004 @ test/test_expect_test.ml:2004:11-2004:46
        [track] <while loop> @ test/test_expect_test.ml:2001:6-2005:42
          [track] else:test_expect_test:2001 @ test/test_expect_test.ml:2001:64-2001:66
          (WARNING: 2 i= 5)
          [track] fun:test_expect_test:2004 @ test/test_expect_test.ml:2004:11-2004:46
        [track] <while loop> @ test/test_expect_test.ml:2001:6-2005:42
          [track] else:test_expect_test:2001 @ test/test_expect_test.ml:2001:64-2001:66
          (WARNING: 2 i= 6)
          [track] fun:test_expect_test:2004 @ test/test_expect_test.ml:2004:11-2004:46
    |}]

let%expect_test "%log compile time log levels while-loop" =
  let run_id = next_run () in
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
  let db = Minidebug_client.Client.open_db db_file in
  Minidebug_client.Client.show_trace db run_id;
  [%expect
    {|
    21
    21
    21
    [track] everything => 21 @ test/test_expect_test.ml:2126:28-2139:9
      [track] while:test_expect_test:2131 @ test/test_expect_test.ml:2131:6-2138:10
        [track] <while loop> @ test/test_expect_test.ml:2133:8-2137:44
          [track] then:test_expect_test:2133 @ test/test_expect_test.ml:2133:23-2133:60
            (ERROR: 1 i= 0)
          (WARNING: 2 i= 1)
          [track] fun:test_expect_test:2136 @ test/test_expect_test.ml:2136:13-2136:48
          (INFO: 3 j= 1)
        [track] <while loop> @ test/test_expect_test.ml:2133:8-2137:44
          [track] then:test_expect_test:2133 @ test/test_expect_test.ml:2133:23-2133:60
            (ERROR: 1 i= 1)
          (WARNING: 2 i= 2)
          [track] fun:test_expect_test:2136 @ test/test_expect_test.ml:2136:13-2136:48
          (INFO: 3 j= 3)
        [track] <while loop> @ test/test_expect_test.ml:2133:8-2137:44
          [track] else:test_expect_test:2133 @ test/test_expect_test.ml:2133:66-2133:68
          (WARNING: 2 i= 3)
          [track] fun:test_expect_test:2136 @ test/test_expect_test.ml:2136:13-2136:48
          (INFO: 3 j= 6)
        [track] <while loop> @ test/test_expect_test.ml:2133:8-2137:44
          [track] else:test_expect_test:2133 @ test/test_expect_test.ml:2133:66-2133:68
          (WARNING: 2 i= 4)
          [track] fun:test_expect_test:2136 @ test/test_expect_test.ml:2136:13-2136:48
          (INFO: 3 j= 10)
        [track] <while loop> @ test/test_expect_test.ml:2133:8-2137:44
          [track] else:test_expect_test:2133 @ test/test_expect_test.ml:2133:66-2133:68
          (WARNING: 2 i= 5)
          [track] fun:test_expect_test:2136 @ test/test_expect_test.ml:2136:13-2136:48
          (INFO: 3 j= 15)
        [track] <while loop> @ test/test_expect_test.ml:2133:8-2137:44
          [track] else:test_expect_test:2133 @ test/test_expect_test.ml:2133:66-2133:68
          (WARNING: 2 i= 6)
          [track] fun:test_expect_test:2136 @ test/test_expect_test.ml:2136:13-2136:48
          (INFO: 3 j= 21)
    [track] nothing => 21 @ test/test_expect_test.ml:2141:25-2155:9
    [track] warning => 21 @ test/test_expect_test.ml:2157:25-2172:9
      [track] while:test_expect_test:2162 @ test/test_expect_test.ml:2162:6-2171:10
        [track] <while loop> @ test/test_expect_test.ml:2164:8-2170:47
          (ERROR: 1 i= 0)
          (WARNING: 2 i= 1)
        [track] <while loop> @ test/test_expect_test.ml:2164:8-2170:47
          (ERROR: 1 i= 1)
          (WARNING: 2 i= 2)
        [track] <while loop> @ test/test_expect_test.ml:2164:8-2170:47
          (WARNING: 2 i= 3)
        [track] <while loop> @ test/test_expect_test.ml:2164:8-2170:47
          (WARNING: 2 i= 4)
        [track] <while loop> @ test/test_expect_test.ml:2164:8-2170:47
          (WARNING: 2 i= 5)
        [track] <while loop> @ test/test_expect_test.ml:2164:8-2170:47
          (WARNING: 2 i= 6)
    |}]

let%expect_test "%log track while-loop result" =
  let run_id = next_run () in
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
  let db = Minidebug_client.Client.open_db db_file in
  Minidebug_client.Client.show_trace db ~values_first_mode:false run_id;
  [%expect
    {|
    21
    [track] result @ test/test_expect_test.ml:2243:17-2243:23
      [track] while:test_expect_test:2246 @ test/test_expect_test.ml:2246:4-2252:8
        [track] <while loop> @ test/test_expect_test.ml:2247:6-2251:39
          (1 i= 0)
          (2 i= 1)
          => => (3 j= 1)
        [track] <while loop> @ test/test_expect_test.ml:2247:6-2251:39
          (1 i= 1)
          (2 i= 2)
          => => (3 j= 3)
        [track] <while loop> @ test/test_expect_test.ml:2247:6-2251:39
          (1 i= 2)
          (2 i= 3)
          => => (3 j= 6)
        [track] <while loop> @ test/test_expect_test.ml:2247:6-2251:39
          (1 i= 3)
          (2 i= 4)
          => => (3 j= 10)
        [track] <while loop> @ test/test_expect_test.ml:2247:6-2251:39
          (1 i= 4)
          (2 i= 5)
          => => (3 j= 15)
        [track] <while loop> @ test/test_expect_test.ml:2247:6-2251:39
          (1 i= 5)
          (2 i= 6)
          => => (3 j= 21)
      => => 21
    |}]

let%expect_test "%log without scope" =
  let run_id = next_run () in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file ~print_entry_ids:true db_file in
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
  let db = Minidebug_client.Client.open_db db_file in
  Minidebug_client.Client.show_trace db ~values_first_mode:false run_id;
  [%expect
    {|
    [debug] _bar @ test/test_expect_test.ml:2304:17-2304:21
      _bar => ()
      ("This is like", 3, "or", 3.14, "above")
      ("tau =", 6.28)
      [4; 1; 2; 3]
      [3; 1; 2; 3]
      [3; 1; 2; 3]
    |}]

let%expect_test "%log without scope values_first_mode" =
  let run_id = next_run () in
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
  let () = !foo () in
  let db = Minidebug_client.Client.open_db db_file in
  Minidebug_client.Client.show_trace db ~values_first_mode:true run_id;
  [%expect
    {|
    [debug] _bar => () @ test/test_expect_test.ml:2337:17-2337:21
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
  let run_id = next_run () in
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
  let db = Minidebug_client.Client.open_db db_file in
  Minidebug_client.Client.show_trace db run_id;
  [%expect
    {|
    [debug] bar => () @ test/test_expect_test.ml:2378:21-2383:19
      ("This is like", 3, "or", 3.14, "above")
      ("tau =", 6.28)
      ("This is like", 3, "or", 3.14, "above")
      ("tau =", 6.28)
    [debug] baz => () @ test/test_expect_test.ml:2385:21-2390:19
      [3; 1; 2; 3]
      [3; 1; 2; 3]
      [3; 1; 2; 3]
      [3; 1; 2; 3]
    [debug] bar => () @ test/test_expect_test.ml:2378:21-2383:19
      ("This is like", 3, "or", 3.14, "above")
      ("tau =", 6.28)
    [debug] _foobar => () @ test/test_expect_test.ml:2397:17-2397:24
    |}]
(* $MDX part-end *)

let%expect_test "%diagn_show ignores type annots" =
  let run_id = next_run () in
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
  let db = Minidebug_client.Client.open_db db_file in
  Minidebug_client.Client.show_trace db run_id;
  [%expect
    {|
    336
    109
    [diagn] toplevel @ test/test_expect_test.ml:2426:17-2426:25
      ("for bar, b-3", 42)
      ("for baz, f squared", 64)
    |}]

let%expect_test "%diagn_show ignores non-empty bindings" =
  (* $MDX part-begin=diagn_show_ignores_bindings *)
  let run_id = next_run () in
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
  let db = Minidebug_client.Client.open_db db_file in
  Minidebug_client.Client.show_trace db run_id;
  [%expect
    {|
    336
    91
    [diagn] bar @ test/test_expect_test.ml:2460:21-2464:15
      ("for bar, b-3", 42)
    [diagn] baz @ test/test_expect_test.ml:2467:21-2472:25
      ("foo baz, f squared", 49)
    |}]
(* $MDX part-end *)

let%expect_test "%diagn_show no logs" =
  let db = Minidebug_client.Client.open_db db_file in
  let latest_run_before = db |> Minidebug_client.Client.get_latest_run |> Option.get in
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
  let latest_run_after = db |> Minidebug_client.Client.get_latest_run |> Option.get in
  print_endline @@ "latest_run_before: " ^ Int.to_string latest_run_before.run_id;
  print_endline @@ "latest_run_after: " ^ Int.to_string latest_run_after.run_id;
  print_endline @@ "run_counter: " ^ Int.to_string !run_counter;
  [%expect
    {|
    336
    91
    latest_run_before: 65
    latest_run_after: 65
    run_counter: 65
    |}]

let%expect_test "%debug_show log level compile time" =
  let run_id = next_run () in
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
  let db = Minidebug_client.Client.open_db db_file in
  Minidebug_client.Client.show_trace db run_id;
  [%expect
    {|
    336
    336
    109
    [debug] () @ test/test_expect_test.ml:2525:18-2525:20
      [debug] baz => 109 @ test/test_expect_test.ml:2540:26-2543:32
        first = 7
        second = 42
        [debug] {first; second} @ test/test_expect_test.ml:2541:12-2541:41
          first => 8
          second => 45
        ("for baz, f squared", 64)
    |}]

let%expect_test "%debug_show log level runtime" =
  (* $MDX part-begin=debug_show_log_level_runtime *)
  let run_id = next_run () in
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
  let db = Minidebug_client.Client.open_db db_file in
  Minidebug_client.Client.show_trace db run_id;
  [%expect
    {|
    336
    336
    109
    [debug] baz => 109 @ test/test_expect_test.ml:2586:24-2589:30
      first = 7
      second = 42
      [debug] {first; second} @ test/test_expect_test.ml:2587:10-2587:39
        first => 8
        second => 45
      ("for baz, f squared", 64)
    |}]
(* $MDX part-end *)

let%expect_test "%track_show don't show unannotated non-function bindings" =
  let db = Minidebug_client.Client.open_db db_file in
  let latest_run_before = db |> Minidebug_client.Client.get_latest_run |> Option.get in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file ~log_level:3 db_file in
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
    latest_run_before: 67
    latest_run_after: 67
    run_counter: 67
    |}]

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
  let run_id = latest_run () in
  let db = Minidebug_client.Client.open_db db_file in
  Minidebug_client.Client.show_trace db run_id;
  [%expect
    {|
    latest_run: (no-name)
    [debug] foo => () @ test/test_expect_test.ml:2644:21-2657:91
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
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file in
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
  let db = Minidebug_client.Client.open_db db_file in
  Minidebug_client.Client.show_trace db (latest_run ());
  [%expect
    {|
    latest_run: (no-name)
    [diagn] _logging_logic @ test/test_expect_test.ml:2712:17-2712:31
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
  let run_id = next_run () in
  let module Debug_runtime = (val Minidebug_db.debug_db_file db_file) in
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
  let db = Minidebug_client.Client.open_db db_file in
  Minidebug_client.Client.show_trace db run_id;
  [%expect
    {|
    15
    [track] bar => 15 @ test/test_expect_test.ml:2770:23-2778:9
      x = 7
      [track] y => 8 @ test/test_expect_test.ml:2772:8-2772:9
    |}]

let%expect_test "%track_show procedure runtime prefixes" =
  (* $MDX part-begin=track_show_procedure_runtime_prefixes *)
  let i = ref 0 in
  let run_ids = ref [] in
  let _get_local_debug_runtime () =
    let rt = Minidebug_db.debug_db_file ~run_name:("foo-" ^ string_of_int !i) db_file in
    let run_id = next_run () in
    run_ids := run_id :: !run_ids;
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
  let db = Minidebug_client.Client.open_db db_file in
  List.iter
    (fun run_id -> Minidebug_client.Client.show_trace db run_id)
    (List.rev !run_ids);
  [%expect
    {|
    [track] foo @ test/test_expect_test.ml:2801:21-2803:23
      "inside foo"
    [track] <function -- branch 0> () @ test/test_expect_test.ml:2807:8-2808:27
      "inside bar"
    [track] foo @ test/test_expect_test.ml:2801:21-2803:23
      "inside foo"
    [track] <function -- branch 0> () @ test/test_expect_test.ml:2807:8-2808:27
      "inside bar"
    [track] foo @ test/test_expect_test.ml:2801:21-2803:23
      "inside foo"
    [track] <function -- branch 0> () @ test/test_expect_test.ml:2807:8-2808:27
      "inside bar"
    |}]
(* $MDX part-end *)

let%expect_test "%track_rt_show expression runtime passing" =
  let run_id1 = next_run () in
  [%track_rt_show
    [%log_block
      "test A";
      [%log "line A"]]]
    (Minidebug_db.debug_db_file ~run_name:"t1" db_file);
  let run_id2 = next_run () in
  [%track_rt_show
    [%log_block
      "test B";
      [%log "line B"]]]
    (Minidebug_db.debug_db_file ~run_name:"t2" db_file);
  [%track_rt_show
    [%log_block
      "test C";
      [%log "line C"]]]
    Minidebug_db.(debug_db_file ~run_name:"t3" ~log_level:0 db_file);
  let db = Minidebug_client.Client.open_db db_file in
  Minidebug_client.Client.show_trace db ~values_first_mode:false run_id1;
  Minidebug_client.Client.show_trace db ~values_first_mode:false run_id2;
  print_endline @@ "run_id2: " ^ Int.to_string run_id2;
  print_endline @@ "latest_run: "
  ^ Int.to_string (Minidebug_client.Client.get_latest_run db |> Option.get).run_id;
  [%expect
    {|
    [track] test A @ :0:0-0:0
      "line A"
    [track] test B @ :0:0-0:0
      "line B"
    run_id2: 78
    latest_run: 78
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
          Minidebug_db.(debug_db_file ~run_name:"for=2,with=default" db_file)
          ~for_log_level:2);
  let db = Minidebug_client.Client.open_db db_file in
  Minidebug_client.Client.show_trace db (latest_run ());
  print_endline
  @@ Int.to_string
       (result
          Minidebug_db.(debug_db_file ~log_level:0 ~run_name:"for=1,with=0" db_file)
          ~for_log_level:1);
  print_endline @@ "latest_run name: "
  ^ Option.get (Minidebug_client.Client.get_latest_run db |> Option.get).run_name;
  print_endline
  @@ Int.to_string
       (result
          Minidebug_db.(debug_db_file ~log_level:1 ~run_name:"for=2,with=1" db_file)
          ~for_log_level:2);
  Minidebug_client.Client.show_trace db (latest_run ());
  print_endline
  @@ Int.to_string
       (result
          Minidebug_db.(debug_db_file ~log_level:2 ~run_name:"for=1,with=2" db_file)
          ~for_log_level:1);
  Minidebug_client.Client.show_trace db (latest_run ());
  print_endline
  @@ Int.to_string
       (result
          Minidebug_db.(debug_db_file ~log_level:3 ~run_name:"for=3,with=3" db_file)
          ~for_log_level:3);
  Minidebug_client.Client.show_trace db (latest_run ());
  (* Unlike with other constructs, INFO should not be printed in "for=4,with=3", because
     log_block filters out the whole body by the log level. *)
  print_endline
  @@ Int.to_string
       (result
          Minidebug_db.(debug_db_file ~log_level:3 ~run_name:"for=4,with=3" db_file)
          ~for_log_level:4);
  Minidebug_client.Client.show_trace db (latest_run ());
  [%expect
    {|
    21
    latest_run: for=2,with=default
    [track] result => 21 @ test/test_expect_test.ml:2872:27-2884:6
      [track] while:test_expect_test:2875 @ test/test_expect_test.ml:2875:4-2883:8
        [track] <while loop> @ test/test_expect_test.ml:2876:6-2882:45
          [track] i=1 @ :0:0-0:0
            [track] then:test_expect_test:2879 @ test/test_expect_test.ml:2879:23-2879:59
              (ERROR: 1 i= 1)
            (WARNING: 2 i= 1)
            [track] fun:test_expect_test:2881 @ test/test_expect_test.ml:2881:13-2881:48
            (INFO: 3 j= 1)
        [track] <while loop> @ test/test_expect_test.ml:2876:6-2882:45
          [track] i=2 @ :0:0-0:0
            [track] then:test_expect_test:2879 @ test/test_expect_test.ml:2879:23-2879:59
              (ERROR: 1 i= 2)
            (WARNING: 2 i= 2)
            [track] fun:test_expect_test:2881 @ test/test_expect_test.ml:2881:13-2881:48
            (INFO: 3 j= 3)
        [track] <while loop> @ test/test_expect_test.ml:2876:6-2882:45
          [track] i=3 @ :0:0-0:0
            [track] else:test_expect_test:2879 @ test/test_expect_test.ml:2879:65-2879:67
            (WARNING: 2 i= 3)
            [track] fun:test_expect_test:2881 @ test/test_expect_test.ml:2881:13-2881:48
            (INFO: 3 j= 6)
        [track] <while loop> @ test/test_expect_test.ml:2876:6-2882:45
          [track] i=4 @ :0:0-0:0
            [track] else:test_expect_test:2879 @ test/test_expect_test.ml:2879:65-2879:67
            (WARNING: 2 i= 4)
            [track] fun:test_expect_test:2881 @ test/test_expect_test.ml:2881:13-2881:48
            (INFO: 3 j= 10)
        [track] <while loop> @ test/test_expect_test.ml:2876:6-2882:45
          [track] i=5 @ :0:0-0:0
            [track] else:test_expect_test:2879 @ test/test_expect_test.ml:2879:65-2879:67
            (WARNING: 2 i= 5)
            [track] fun:test_expect_test:2881 @ test/test_expect_test.ml:2881:13-2881:48
            (INFO: 3 j= 15)
        [track] <while loop> @ test/test_expect_test.ml:2876:6-2882:45
          [track] i=6 @ :0:0-0:0
            [track] else:test_expect_test:2879 @ test/test_expect_test.ml:2879:65-2879:67
            (WARNING: 2 i= 6)
            [track] fun:test_expect_test:2881 @ test/test_expect_test.ml:2881:13-2881:48
            (INFO: 3 j= 21)
    0
    latest_run name: for=2,with=default
    0
    latest_run: for=2,with=1
    [track] result => 0 @ test/test_expect_test.ml:2872:27-2884:6
      [track] while:test_expect_test:2875 @ test/test_expect_test.ml:2875:4-2883:8
        [track] <while loop> @ test/test_expect_test.ml:2876:6-2882:45
        [track] <while loop> @ test/test_expect_test.ml:2876:6-2882:45
        [track] <while loop> @ test/test_expect_test.ml:2876:6-2882:45
        [track] <while loop> @ test/test_expect_test.ml:2876:6-2882:45
        [track] <while loop> @ test/test_expect_test.ml:2876:6-2882:45
        [track] <while loop> @ test/test_expect_test.ml:2876:6-2882:45
    21
    latest_run: for=1,with=2
    [track] result => 21 @ test/test_expect_test.ml:2872:27-2884:6
      [track] while:test_expect_test:2875 @ test/test_expect_test.ml:2875:4-2883:8
        [track] <while loop> @ test/test_expect_test.ml:2876:6-2882:45
          [track] i=1 @ :0:0-0:0
            [track] then:test_expect_test:2879 @ test/test_expect_test.ml:2879:23-2879:59
              (ERROR: 1 i= 1)
            (WARNING: 2 i= 1)
            [track] fun:test_expect_test:2881 @ test/test_expect_test.ml:2881:13-2881:48
        [track] <while loop> @ test/test_expect_test.ml:2876:6-2882:45
          [track] i=2 @ :0:0-0:0
            [track] then:test_expect_test:2879 @ test/test_expect_test.ml:2879:23-2879:59
              (ERROR: 1 i= 2)
            (WARNING: 2 i= 2)
            [track] fun:test_expect_test:2881 @ test/test_expect_test.ml:2881:13-2881:48
        [track] <while loop> @ test/test_expect_test.ml:2876:6-2882:45
          [track] i=3 @ :0:0-0:0
            [track] else:test_expect_test:2879 @ test/test_expect_test.ml:2879:65-2879:67
            (WARNING: 2 i= 3)
            [track] fun:test_expect_test:2881 @ test/test_expect_test.ml:2881:13-2881:48
        [track] <while loop> @ test/test_expect_test.ml:2876:6-2882:45
          [track] i=4 @ :0:0-0:0
            [track] else:test_expect_test:2879 @ test/test_expect_test.ml:2879:65-2879:67
            (WARNING: 2 i= 4)
            [track] fun:test_expect_test:2881 @ test/test_expect_test.ml:2881:13-2881:48
        [track] <while loop> @ test/test_expect_test.ml:2876:6-2882:45
          [track] i=5 @ :0:0-0:0
            [track] else:test_expect_test:2879 @ test/test_expect_test.ml:2879:65-2879:67
            (WARNING: 2 i= 5)
            [track] fun:test_expect_test:2881 @ test/test_expect_test.ml:2881:13-2881:48
        [track] <while loop> @ test/test_expect_test.ml:2876:6-2882:45
          [track] i=6 @ :0:0-0:0
            [track] else:test_expect_test:2879 @ test/test_expect_test.ml:2879:65-2879:67
            (WARNING: 2 i= 6)
            [track] fun:test_expect_test:2881 @ test/test_expect_test.ml:2881:13-2881:48
    21
    latest_run: for=3,with=3
    [track] result => 21 @ test/test_expect_test.ml:2872:27-2884:6
      [track] while:test_expect_test:2875 @ test/test_expect_test.ml:2875:4-2883:8
        [track] <while loop> @ test/test_expect_test.ml:2876:6-2882:45
          [track] i=1 @ :0:0-0:0
            [track] then:test_expect_test:2879 @ test/test_expect_test.ml:2879:23-2879:59
              (ERROR: 1 i= 1)
            (WARNING: 2 i= 1)
            [track] fun:test_expect_test:2881 @ test/test_expect_test.ml:2881:13-2881:48
            (INFO: 3 j= 1)
        [track] <while loop> @ test/test_expect_test.ml:2876:6-2882:45
          [track] i=2 @ :0:0-0:0
            [track] then:test_expect_test:2879 @ test/test_expect_test.ml:2879:23-2879:59
              (ERROR: 1 i= 2)
            (WARNING: 2 i= 2)
            [track] fun:test_expect_test:2881 @ test/test_expect_test.ml:2881:13-2881:48
            (INFO: 3 j= 3)
        [track] <while loop> @ test/test_expect_test.ml:2876:6-2882:45
          [track] i=3 @ :0:0-0:0
            [track] else:test_expect_test:2879 @ test/test_expect_test.ml:2879:65-2879:67
            (WARNING: 2 i= 3)
            [track] fun:test_expect_test:2881 @ test/test_expect_test.ml:2881:13-2881:48
            (INFO: 3 j= 6)
        [track] <while loop> @ test/test_expect_test.ml:2876:6-2882:45
          [track] i=4 @ :0:0-0:0
            [track] else:test_expect_test:2879 @ test/test_expect_test.ml:2879:65-2879:67
            (WARNING: 2 i= 4)
            [track] fun:test_expect_test:2881 @ test/test_expect_test.ml:2881:13-2881:48
            (INFO: 3 j= 10)
        [track] <while loop> @ test/test_expect_test.ml:2876:6-2882:45
          [track] i=5 @ :0:0-0:0
            [track] else:test_expect_test:2879 @ test/test_expect_test.ml:2879:65-2879:67
            (WARNING: 2 i= 5)
            [track] fun:test_expect_test:2881 @ test/test_expect_test.ml:2881:13-2881:48
            (INFO: 3 j= 15)
        [track] <while loop> @ test/test_expect_test.ml:2876:6-2882:45
          [track] i=6 @ :0:0-0:0
            [track] else:test_expect_test:2879 @ test/test_expect_test.ml:2879:65-2879:67
            (WARNING: 2 i= 6)
            [track] fun:test_expect_test:2881 @ test/test_expect_test.ml:2881:13-2881:48
            (INFO: 3 j= 21)
    0
    latest_run: for=4,with=3
    [track] result => 0 @ test/test_expect_test.ml:2872:27-2884:6
      [track] while:test_expect_test:2875 @ test/test_expect_test.ml:2875:4-2883:8
        [track] <while loop> @ test/test_expect_test.ml:2876:6-2882:45
        [track] <while loop> @ test/test_expect_test.ml:2876:6-2882:45
        [track] <while loop> @ test/test_expect_test.ml:2876:6-2882:45
        [track] <while loop> @ test/test_expect_test.ml:2876:6-2882:45
        [track] <while loop> @ test/test_expect_test.ml:2876:6-2882:45
        [track] <while loop> @ test/test_expect_test.ml:2876:6-2882:45
    |}]

let%expect_test "%log_block compile-time nothing" =
  let db = Minidebug_client.Client.open_db db_file in
  let latest_run_before = db |> Minidebug_client.Client.get_latest_run |> Option.get in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file in
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
    latest run before: 83
    latest run after: 83
    |}]

let%expect_test "%log_block compile-time nothing dynamic scope" =
  let db = Minidebug_client.Client.open_db db_file in
  let latest_run_before = db |> Minidebug_client.Client.get_latest_run |> Option.get in
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file in
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
    latest run before: 83
    latest run after: 83
    |}]

let%expect_test "%log compile time log levels while-loop dynamic scope" =
  let run_id = next_run () in
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
  let db = Minidebug_client.Client.open_db db_file in
  Minidebug_client.Client.show_trace db ~values_first_mode:false run_id;
  [%expect
    {|
    21
    21
    21
    [track] everything @ test/test_expect_test.ml:3206:28-3209:14
      [track] loop @ test/test_expect_test.ml:3193:22-3204:6
        [track] while:test_expect_test:3196 @ test/test_expect_test.ml:3196:4-3203:8
          [track] <while loop> @ test/test_expect_test.ml:3198:6-3202:42
            [track] then:test_expect_test:3198 @ test/test_expect_test.ml:3198:21-3198:58
              (ERROR: 1 i= 0)
            (WARNING: 2 i= 1)
            [track] fun:test_expect_test:3201 @ test/test_expect_test.ml:3201:11-3201:46
            (INFO: 3 j= 1)
          [track] <while loop> @ test/test_expect_test.ml:3198:6-3202:42
            [track] then:test_expect_test:3198 @ test/test_expect_test.ml:3198:21-3198:58
              (ERROR: 1 i= 1)
            (WARNING: 2 i= 2)
            [track] fun:test_expect_test:3201 @ test/test_expect_test.ml:3201:11-3201:46
            (INFO: 3 j= 3)
          [track] <while loop> @ test/test_expect_test.ml:3198:6-3202:42
            [track] else:test_expect_test:3198 @ test/test_expect_test.ml:3198:64-3198:66
            (WARNING: 2 i= 3)
            [track] fun:test_expect_test:3201 @ test/test_expect_test.ml:3201:11-3201:46
            (INFO: 3 j= 6)
          [track] <while loop> @ test/test_expect_test.ml:3198:6-3202:42
            [track] else:test_expect_test:3198 @ test/test_expect_test.ml:3198:64-3198:66
            (WARNING: 2 i= 4)
            [track] fun:test_expect_test:3201 @ test/test_expect_test.ml:3201:11-3201:46
            (INFO: 3 j= 10)
          [track] <while loop> @ test/test_expect_test.ml:3198:6-3202:42
            [track] else:test_expect_test:3198 @ test/test_expect_test.ml:3198:64-3198:66
            (WARNING: 2 i= 5)
            [track] fun:test_expect_test:3201 @ test/test_expect_test.ml:3201:11-3201:46
            (INFO: 3 j= 15)
          [track] <while loop> @ test/test_expect_test.ml:3198:6-3202:42
            [track] else:test_expect_test:3198 @ test/test_expect_test.ml:3198:64-3198:66
            (WARNING: 2 i= 6)
            [track] fun:test_expect_test:3201 @ test/test_expect_test.ml:3201:11-3201:46
            (INFO: 3 j= 21)
      everything => 21
    [track] nothing @ test/test_expect_test.ml:3211:25-3215:14
      nothing => 21
    [track] warning @ test/test_expect_test.ml:3217:25-3220:14
      [track] loop @ test/test_expect_test.ml:3193:22-3204:6
        [track] while:test_expect_test:3196 @ test/test_expect_test.ml:3196:4-3203:8
          [track] <while loop> @ test/test_expect_test.ml:3198:6-3202:42
            [track] then:test_expect_test:3198 @ test/test_expect_test.ml:3198:21-3198:58
              (ERROR: 1 i= 0)
            (WARNING: 2 i= 1)
            [track] fun:test_expect_test:3201 @ test/test_expect_test.ml:3201:11-3201:46
          [track] <while loop> @ test/test_expect_test.ml:3198:6-3202:42
            [track] then:test_expect_test:3198 @ test/test_expect_test.ml:3198:21-3198:58
              (ERROR: 1 i= 1)
            (WARNING: 2 i= 2)
            [track] fun:test_expect_test:3201 @ test/test_expect_test.ml:3201:11-3201:46
          [track] <while loop> @ test/test_expect_test.ml:3198:6-3202:42
            [track] else:test_expect_test:3198 @ test/test_expect_test.ml:3198:64-3198:66
            (WARNING: 2 i= 3)
            [track] fun:test_expect_test:3201 @ test/test_expect_test.ml:3201:11-3201:46
          [track] <while loop> @ test/test_expect_test.ml:3198:6-3202:42
            [track] else:test_expect_test:3198 @ test/test_expect_test.ml:3198:64-3198:66
            (WARNING: 2 i= 4)
            [track] fun:test_expect_test:3201 @ test/test_expect_test.ml:3201:11-3201:46
          [track] <while loop> @ test/test_expect_test.ml:3198:6-3202:42
            [track] else:test_expect_test:3198 @ test/test_expect_test.ml:3198:64-3198:66
            (WARNING: 2 i= 5)
            [track] fun:test_expect_test:3201 @ test/test_expect_test.ml:3201:11-3201:46
          [track] <while loop> @ test/test_expect_test.ml:3198:6-3202:42
            [track] else:test_expect_test:3198 @ test/test_expect_test.ml:3198:64-3198:66
            (WARNING: 2 i= 6)
            [track] fun:test_expect_test:3201 @ test/test_expect_test.ml:3201:11-3201:46
      warning => 21
    |}]
