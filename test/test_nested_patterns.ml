type 'a irrefutable = Zero of 'a
type ('a, 'b) left_right = Left of 'a | Right of 'b
type ('a, 'b, 'c) one_two_three = One of 'a | Two of 'b | Three of 'c

module Debug_runtime =
  (val Minidebug_runtime.debug_file ~hyperlink:"../" ~values_first_mode:true
         "debugger_nested_patterns")

let%track_show bar (Zero (x : int)) : int =
  let y = (x + 1 : int) in
  2 * y

let () = print_endline @@ Int.to_string @@ bar (Zero 7)

let%track_show baz : 'a -> int = function
  | Left (x : int) -> x + 1
  | Right (Two (y : int)) -> y * 2
  | _ -> 3

let%track_show foo x : int =
  match x with Left (x : int) -> x + 1 | Right (Two (y : int)) -> y * 2 | _ -> 3

let () = print_endline @@ Int.to_string @@ baz (Left 4)
let () = print_endline @@ Int.to_string @@ baz (Right (One 7))
let () = print_endline @@ Int.to_string @@ baz (Right (Two 3))
let () = print_endline @@ Int.to_string @@ foo (Right (Three 0))
