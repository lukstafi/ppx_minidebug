(* Integration test: this file is compiled via dune instrumentation.
   ppx_minidebug --auto should inject Debug_runtime and instrument greet. *)

let greet (name : string) = "Hello, " ^ name ^ "!"

let () =
  let msg = greet "world" in
  print_endline msg
