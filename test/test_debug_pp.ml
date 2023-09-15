module Debug_runtime =
  Minidebug_runtime.Pp_format(
    Minidebug_runtime.Debug_ch_no_time_tags(struct let filename = "debugger_pp_format.log" end))
type t = {first: int; second: int} [@@deriving show]
type num = int [@@deriving show]
let%debug_pp bar (x: t): num = let y: num = x.first + 1 in x.second * y

let () = ignore @@ bar {first=7; second=42}

let%debug_pp baz (x: t): num =
  let ({first=y; second=z} as _yz): t = {first=x.first + 1; second=3} in x.second * y + z
let () = ignore @@ baz {first=7; second=42}

let%debug_pp rec loop (depth: num) (x: t): num =
  if depth > 6 then x.first + x.second
  else if depth > 3 then loop (depth + 1) {first=x.second + 1; second=x.first / 2}
  else
    let y: num = loop (depth + 1) {first=x.second - 1; second=x.first + 2} in
    let z: num = loop (depth + 1) {first=x.second + 1; second=y} in
    z + 7
let () = ignore @@ loop 0 {first=7; second=42}
