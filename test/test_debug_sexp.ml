open Sexplib0.Sexp_conv

module Debug_runtime =
  Minidebug_runtime.PrintBox
    ((val Minidebug_runtime.shared_config "debugger_sexp_printbox.log"))

let%debug_sexp foo (x : int) : int list =
  let y : int = x + 1 in
  [ x; y; 2 * y ]

let () = ignore @@ List.hd @@ foo 7

type t = { first : int; second : int } [@@deriving sexp]

let%debug_sexp bar (x : t) : int =
  let y : int = x.first + 1 in
  x.second * y

let () = ignore @@ bar { first = 7; second = 42 }

let%debug_sexp baz (x : t) : int =
  let ((y, z) as _yz) : int * int = (x.first + 1, 3) in
  let ((u, w) as _uw) : int * int = (7, 13) in
  (x.second * y) + z + u + w

let () = ignore @@ baz { first = 7; second = 42 }

let%debug_sexp lab ~(x : int) : int list =
  let y : int = x + 1 in
  [ x; y; 2 * y ]

let () = ignore @@ List.hd @@ lab ~x:7

let%debug_sexp rec loop (depth : int) (x : t) : int =
  if depth > 4 then x.first + x.second
  else if depth > 1 then loop (depth + 1) { first = x.second + 1; second = x.first / 2 }
  else
    let y : int = loop (depth + 1) { first = x.second - 1; second = x.first + 2 } in
    let z : int = loop (depth + 1) { first = x.second + 1; second = y } in
    z + 7

let () = ignore @@ loop 0 { first = 7; second = 42 }
