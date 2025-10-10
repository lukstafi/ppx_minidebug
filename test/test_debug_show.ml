let _get_local_debug_runtime =
  let rt = Minidebug_db.debug_db_file "debugger_show" in
  fun () -> rt

let%debug_show foo (x : int) : int list =
  let y : int = x + 1 in
  [ x; y; 2 * y ]

let () = ignore @@ List.hd @@ foo 7

type t = { first : int; second : int } [@@deriving show]

let%debug_show bar (x : t) : int =
  let y : int = x.first + 1 in
  x.second * y

let () = ignore @@ bar { first = 7; second = 42 }

let%debug_show baz (x : t) : int =
  let ((y, z) as _yz) : int * int = (x.first + 1, 3) in
  (x.second * y) + z

let () = ignore @@ baz { first = 7; second = 42 }

let%debug_show rec loop (depth : int) (x : t) : int =
  if depth > 6 then x.first + x.second
  else if depth > 3 then loop (depth + 1) { first = x.second + 1; second = x.first / 2 }
  else
    let y : int = loop (depth + 1) { first = x.second - 1; second = x.first + 2 } in
    let z : int = loop (depth + 1) { first = x.second + 1; second = y } in
    z + 7

let () = ignore @@ loop 0 { first = 7; second = 42 }

(* Test cases for issue #62: cascading function abstractions with type constraints *)

(* Simple case: function returning unit -> unit *)
let%debug_show simple_thunk (x : string) : unit -> unit = fun () -> print_endline x
let () = simple_thunk "hello" ()

(* More complex case: nested function abstraction *)
let%debug_show nested_fun (x : int) : int -> unit = fun y -> ignore (x + y)
let () = nested_fun 5 10

(* Case with multiple cascading abstractions *)
let%debug_show cascade (x : int) : int -> int -> int = fun y -> fun z -> x + y + z
let () = ignore @@ cascade 1 2 3

(* Real-world-like case similar to the bug report *)
let%debug_show parallel_update (x : int) (y : int) : unit -> unit =
  let result = x + y in
  fun () -> print_int result

let () = parallel_update 10 20 ()

(* More complex case closer to the real bug report *)
let%debug_show complex_case (type buffer_ptr) (x : int) (y : buffer_ptr -> int) :
    unit -> unit =
  let compute = x + y (Obj.magic 0) in
  fun () -> print_int compute

let () = complex_case 5 (fun _ -> 10) ()
