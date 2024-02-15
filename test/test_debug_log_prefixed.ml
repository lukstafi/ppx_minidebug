module Debug_runtime =
  Minidebug_runtime.Flushing
    ((val Minidebug_runtime.debug_ch "debugger_show_log_prefixed.log"))

[%%global_debug_log_level Prefixed [|"INFO"|]]

let%debug_show rec loop_exceeded (x : int) : int =
  let z : int =
    [%log "INFO: inside loop", (x : int)];
    (x - 1) / 2
  in
  if x <= 0 then 0 else z + loop_exceeded (z + (x / 2))

let () =
  try print_endline @@ Int.to_string @@ loop_exceeded 7
  with _ -> print_endline "Raised exception."

let%track_show bar () : unit =
  for i = 0 to 10 do
    let _baz : int = i * 2 in
    [%log "INFO: loop step", (i : int), "value", (_baz : int)]
  done

let () = try bar () with _ -> print_endline "Raised exception."
