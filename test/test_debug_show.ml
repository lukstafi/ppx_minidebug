module Debug_runtime = Debug_runtime_unix.Printf(struct let v = "../../../debugger_show.log" end)

let%debug_show foo (x: int): int list =
  let y: int = x + 1 in
  [x; y; 2 * y]

let () = print_endline @@ Int.to_string @@ List.hd @@ foo 7

type t = {first: int; second: int} [@@deriving show]
let%debug_show bar (x: t): int = let y: int = x.first + 1 in x.second * y
let () = print_endline @@ Int.to_string @@ bar {first=7; second=42}
