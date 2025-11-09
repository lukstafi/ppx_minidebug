open! Sexplib0.Sexp_conv

let db_file = "test_comptime_log_level_rt_passing.db"

let () =
  let rt log_level run_name = Minidebug_db.debug_db_file ~log_level ~run_name db_file in
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
       print_endline @@ Int.to_string @@ nothing (rt 9 "nothing") ()]);
    [%log_level
      2;
      let%track_rt_sexp warning () : int =
        let i = ref 0 in
        let j = ref 0 in
        while !i < 6 do
          (* Reduce the debugging noise. *)
          [%diagn_o_sexp
            (* Intentional empty but not omitted else-branch. *)
            if !i < 2 then [%log1 "ERROR:", 1, "i=", (!i : int)] else ();
            incr i;
            [%log2 "WARNING:", 2, "i=", (!i : int)];
            j := (fun { contents } -> !j + contents) i;
            [%log3 "INFO:", 3, "j=", (!j : int)]]
        done;
        !j
      in
      print_endline @@ Int.to_string @@ warning (rt 9 "warning") ()]
  in
  (* Query each versioned database file separately *)
  (* File 1: TOPLEVEL runtime - has the outer debug_sexp scope *)
  let db1 = Minidebug_cli.Cli.open_db "test_comptime_log_level_rt_passing_1.db" in
  List.iter
    (fun run ->
      print_endline @@ "run: "
      ^ Option.value ~default:"<none>" run.Minidebug_client.Query.run_name;
      Minidebug_cli.Cli.show_trace db1)
    (Minidebug_cli.Cli.list_runs db1);
  (* "nothing" runtime - compile-time log_level=0, no logs generated, no file created *)
  (* File 2: "warning" runtime - compile-time log_level=2, shows ERROR and WARNING *)
  let db2 = Minidebug_cli.Cli.open_db "test_comptime_log_level_rt_passing_2.db" in
  List.iter
    (fun run ->
      print_endline @@ "run: "
      ^ Option.value ~default:"<none>" run.Minidebug_client.Query.run_name;
      Minidebug_cli.Cli.show_trace db2)
    (Minidebug_cli.Cli.list_runs db2)
