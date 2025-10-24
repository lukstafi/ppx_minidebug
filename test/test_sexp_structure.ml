(** Test to understand sexp structure for debugging boxify rendering issues *)

open Sexplib0.Sexp_conv

type tree = Leaf of int | Node of string * tree list [@@deriving sexp]

let () =
  Printf.printf "Testing sexp structure for tree type:\n\n";

  (* Simple leaf *)
  let leaf = Leaf 5 in
  Printf.printf "Leaf 5:\n%s\n\n" (Sexplib0.Sexp.to_string_hum (sexp_of_tree leaf));

  (* Simple node *)
  let simple_node = Node ("root", [ Leaf 1; Leaf 2 ]) in
  Printf.printf "Node (\"root\", [Leaf 1; Leaf 2]):\n%s\n\n"
    (Sexplib0.Sexp.to_string_hum (sexp_of_tree simple_node));

  (* Nested node *)
  let nested = Node ("parent", [ Node ("child", [ Leaf 1; Leaf 2 ]); Leaf 3 ]) in
  Printf.printf "Node (\"parent\", [Node (\"child\", [Leaf 1; Leaf 2]); Leaf 3]):\n%s\n\n"
    (Sexplib0.Sexp.to_string_hum (sexp_of_tree nested));

  (* The actual structure from the test *)
  let shared_subtree =
    Node
      ( "shared",
        [ Leaf 1; Leaf 2; Node ("nested", [ Leaf 3; Leaf 4; Leaf 5 ]); Leaf 6; Leaf 7 ] )
  in
  Printf.printf "shared_subtree:\n%s\n\n"
    (Sexplib0.Sexp.to_string_hum (sexp_of_tree shared_subtree))
