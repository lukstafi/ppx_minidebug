module Debug_runtime = Minidebug_runtime.PrintBox(struct let v = "../../../debugger_show_printbox.log" end)

let%debug_show foo (x: int): int list =
  let y: int = x + 1 in
  [x; y; 2 * y]

let () = print_endline @@ Int.to_string @@ List.hd @@ foo 7

type t = {first: int; second: int} [@@deriving show]
let%debug_show bar (x: t): int = let y: int = x.first + 1 in x.second * y
let () = print_endline @@ Int.to_string @@ bar {first=7; second=42}

let%debug_show baz (x: t): int =
  let (y, z as _yz): int * int = x.first + 1, 3 in x.second * y + z
let () = print_endline @@ Int.to_string @@ baz {first=7; second=42}

let%debug_show rec loop (depth: int) (x: t): int =
  if depth > 6 then x.first + x.second
  else if depth > 3 then loop (depth + 1) {first=x.second + 1; second=x.first / 2}
  else
    let y: int = loop (depth + 1) {first=x.second - 1; second=x.first + 2} in
    let z: int = loop (depth + 1) {first=x.second + 1; second=y} in
    z + 7
let () = print_endline @@ Int.to_string @@ loop 0 {first=7; second=42}
