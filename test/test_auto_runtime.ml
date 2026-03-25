(* Test: auto-instrumented code produces correct runtime output.
   This file is preprocessed with --auto flag, which injects Debug_runtime
   automatically and instruments unannotated top-level functions. *)

let foo (x : int) = x + 1

let bar (x : int) (y : int) : int =
  let z = x + y in
  z * 2

let () =
  let _ = foo 5 in
  let _ = bar 3 7 in
  ()
