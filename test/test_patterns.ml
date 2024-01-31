module Debug_runtime =
  (val Minidebug_runtime.debug_file ~hyperlink:"../" ~values_first_mode:true
         "debugger_patterns")

let%debug_show f : 'a. 'a -> int -> 'a -> int = fun _a b _c -> b + 1
let () = print_endline @@ Int.to_string @@ f 'a' 6 'b'
