(** Tree renderer for terminal output *)

module Query = Minidebug_client.Query

type tree_node = { entry : Query.entry; children : tree_node list }

val build_node : (module Query.S) -> ?max_depth:int -> current_depth:int -> Query.entry -> tree_node
val build_tree : (module Query.S) -> ?max_depth:int -> Query.entry list -> tree_node list
(** Build tree structure from Query module and root entries (recommended for full traces)
*)

val build_tree_from_entries : Query.entry list -> tree_node list
(** Build tree structure from pre-loaded flat entry list (for search/filter use cases) *)

val render_tree :
  ?show_scope_ids:bool ->
  ?show_times:bool ->
  ?max_depth:int option ->
  ?values_first_mode:bool ->
  tree_node list ->
  string
(** Render tree to string with full details. When [values_first_mode] is true, result
    values become headers with location/message as children. *)

val render_compact : tree_node list -> string
(** Render compact summary (just function calls) *)

val render_roots : ?show_times:bool -> ?with_values:bool -> Query.entry list -> string
(** Render root entries as a flat list. When [with_values] is true, shows immediate
    children values. *)

val render_tree_json : ?max_depth:int option -> tree_node list -> string
(** Render tree as JSON array *)

val render_entries_json : Query.entry list -> string
(** Render entries as JSON array *)

val entry_to_json : Query.entry -> string
(** Render single entry as JSON object *)
