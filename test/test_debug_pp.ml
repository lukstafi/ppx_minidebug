module Debug_runtime = Debug_runtime_unix.Printf(struct let v = "../../../debugger_pp.log" end)
type t = {first: int; second: int} [@@deriving show]
type num = int [@@deriving show]
let%debug_pp bar (x: t): num = let y: num = x.first + 1 in x.second * y

let () = print_endline @@ Int.to_string @@ bar {first=7; second=42}

let%debug_pp baz (x: t): num =
  let ({first=y; second=z} as _yz): t = {first=x.first + 1; second=3} in x.second * y + z
let () = print_endline @@ Int.to_string @@ baz {first=7; second=42}
