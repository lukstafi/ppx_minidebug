(* Test: file with no eligible functions is unchanged by auto-instrumentation *)

let value = 42

let () = print_endline "hello"

type t = { x : int; y : int }

let pair = (1, 2)
