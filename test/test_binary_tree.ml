(** Test that binary trees are properly decomposed by boxify *)

open Sexplib0.Sexp_conv

let _get_local_debug_runtime =
  let rt = Minidebug_db.debug_db_file "debugger_binary_tree" in
  fun () -> rt

module Debug_runtime = (val _get_local_debug_runtime ())

(* Simple binary tree with Empty leaves *)
type 'a tree = Empty | Node of 'a * 'a tree * 'a tree [@@deriving sexp]

let%debug_sexp rec test_tree (t : int tree) : int =
  match t with
  | Empty -> 0
  | Node (v, left, right) ->
      let l = test_tree left in
      let r = test_tree right in
      v + l + r

let () =
  (* Small tree with Empty leaves *)
  let tree = Node (5, Node (3, Empty, Empty), Node (7, Empty, Empty)) in
  let result = test_tree tree in
  Printf.printf "Result: %d\n" result
