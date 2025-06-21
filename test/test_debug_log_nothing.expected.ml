module Debug_runtime = (val
  Minidebug_runtime.debug_flushing ~filename:"debugger_show_log_nothing" ())
;;()
let rec loop_exceeded (x : int) =
  (let z = (); (x - 1) / 2 in
   if x <= 0 then 0 else z + (loop_exceeded (z + (x / 2))) : int)
let () =
  try print_endline @@ (Int.to_string @@ (loop_exceeded 17))
  with | _ -> print_endline "Raised exception."
let bar () = (for i = 0 to 100 do let _baz = i * 2 in () done : unit)
let () = try bar () with | _ -> print_endline "Raised exception."
