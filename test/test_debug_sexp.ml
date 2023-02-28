open Base
module Debug_runtime = Debug_runtime_jane.Printf(struct let v = "../../../debugger.log" end)

let%debug_sexp foo (x: int): int list =
  let y: int = x + 1 in
  [x; y; 2 * y]

let () = Stdio.Out_channel.print_endline @@ Int.to_string @@ List.hd_exn @@ foo 7

type t = {first: int; second: int} [@@deriving sexp]
let%debug_sexp bar (x: t): int = let y: int = x.first + 1 in x.second * y
let () = Stdio.Out_channel.print_endline @@ Int.to_string @@ bar {first=7; second=42}
