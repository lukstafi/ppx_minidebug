(* Test to verify boxify creates decomposed structures that can be queried *)

open Sexplib0.Sexp_conv

(* Create a database with boxified sexp structures *)
type tree = Leaf of int | Node of string * tree list [@@deriving sexp]

let _get_local_debug_runtime =
  let rt = Minidebug_db.debug_db_file "test_highlight_propagation" in
  fun () -> rt

let%debug_sexp create_nested_tree (name : string) : tree =
  Node (name, [ Leaf 1; Leaf 2; Node ("nested", [ Leaf 3; Leaf 4 ]) ])

let () =
  Printf.printf "Creating test database with nested structures...\n%!";
  let tree1 = create_nested_tree "root" in
  let tree2 = create_nested_tree "another" in
  Printf.printf "Tree 1: %s\n%!" (Sexplib0.Sexp.to_string_hum (sexp_of_tree tree1));
  Printf.printf "Tree 2: %s\n%!" (Sexplib0.Sexp.to_string_hum (sexp_of_tree tree2));
  Printf.printf "\nDatabase created: test_highlight_propagation_1.db\n\n%!";

  (* Verify we can query the database *)
  let module Q = Minidebug_client.Query.Make (struct
    let db_path = "test_highlight_propagation_1.db"
  end) in
  let stats = Q.get_stats () in

  Printf.printf "Database statistics:\n%!";
  Printf.printf "  Total entries: %d\n%!" stats.total_entries;
  Printf.printf "  Total value references: %d\n%!" stats.total_values;
  Printf.printf "  Unique values: %d\n%!" stats.unique_values;
  Printf.printf "  Deduplication: %.1f%%\n\n%!" stats.dedup_percentage;

  (* Get root entries and build tree from database *)
  let root_entries = Q.get_root_entries ~with_values:false in
  let trees = Minidebug_cli.Renderer.build_tree (module Q) root_entries in
  let output = Minidebug_cli.Renderer.render_tree ~values_first_mode:true trees in

  Printf.printf "Trace (values_first_mode):\n%!";
  print_string output;
  Printf.printf
    "\nSUCCESS: Database with nested structures created and queried successfully.\n%!"
