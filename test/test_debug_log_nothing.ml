module Debug_runtime =
  (val Minidebug_runtime.debug_flushing ~filename:"debugger_show_log_nothing" ())

[%%global_debug_log_level 0]

let%debug_show rec loop_exceeded (x : int) : int =
  let z : int =
    [%log "ERROR: just kidding"];
    (x - 1) / 2
  in
  if x <= 0 then 0 else z + loop_exceeded (z + (x / 2))

let () =
  try print_endline @@ Int.to_string @@ loop_exceeded 17
  with _ -> print_endline "Raised exception."

let%track_show bar () : unit =
  for i = 0 to 100 do
    let _baz : int = i * 2 in
    [%log "loop step", (i : int), "value", (_baz : int)]
  done

let () = try bar () with _ -> print_endline "Raised exception."
