(* Test: [%%ppx_minidebug_disable] prevents auto-instrumentation *)
[%%ppx_minidebug_disable]

let foo (x : int) = x + 1

let bar (x : int) (y : int) : int =
  let z = x + y in
  z * 2
