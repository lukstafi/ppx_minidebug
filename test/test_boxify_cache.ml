(** Test sexp caching in boxify - verify deduplication of repeated structures *)

open Sexplib0.Sexp_conv

let _get_local_debug_runtime =
  let rt = Minidebug_db.debug_db_file "debugger_boxify_cache" in
  fun () -> rt

module Debug_runtime = (val _get_local_debug_runtime ())

type tree = Leaf of int | Node of string * tree list [@@deriving sexp]

let%debug_sexp rec process_tree (tree : tree) : int =
  match tree with
  | Leaf n -> n
  | Node (name, children) ->
      Printf.printf "Processing %s\n%!" name;
      let mapped : int list = List.map process_tree children in
      List.fold_left ( + ) 0 mapped

let () =
  Printf.printf "Testing boxify cache with repeated structures\n%!";

  (* Create a shared subtree that will appear multiple times *)
  let shared_subtree =
    Node
      ( "shared",
        [ Leaf 1; Leaf 2; Node ("nested", [ Leaf 3; Leaf 4; Leaf 5 ]); Leaf 6; Leaf 7 ] )
  in

  (* Create a tree with repeated references to the same structure *)
  let tree =
    Node
      ( "root",
        [ shared_subtree; Node ("middle", [ shared_subtree; Leaf 10 ]); shared_subtree ]
      )
  in

  let result = process_tree tree in
  Printf.printf "Result: %d\n%!" result;

  (* Expected: The cache should deduplicate the repeated shared_subtree sexps,
     significantly reducing database size compared to without caching. *)
  ()
