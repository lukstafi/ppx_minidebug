module Debug_runtime =
  (val Minidebug_runtime.debug_flushing ~filename:"debugger_show_interrupts" ())

[%%global_debug_interrupts { max_nesting_depth = 5; max_num_children = 10 }]
[%%global_debug_type_info true]

let%debug_o_show rec loop_exceeded (x : int) : int =
  let z : int = (x - 1) / 2 in
  if x <= 0 then 0 else z + loop_exceeded (z + (x / 2))

let () =
  try print_endline @@ Int.to_string @@ loop_exceeded 17
  with _ -> print_endline "Raised exception."

let%track_o_show bar () : unit =
  for i = 0 to 100 do
    let _baz : int = i * 2 in
    ()
  done

let () = try bar () with _ -> print_endline "Raised exception."
