(* Test: auto-instrumentation transforms unannotated top-level functions *)

let foo (x : int) = x + 1

let bar (x : int) (y : int) : int =
  let z = x + y in
  z * 2

(* Non-function bindings should NOT be instrumented *)
let value = 42

(* Unit-pattern bindings should NOT be instrumented *)
let () = print_endline "hello"
