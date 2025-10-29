(** In-process client for querying and displaying ppx_minidebug database traces *)

(** Query layer for database access *)
module Query : sig
  type entry = {
    scope_id : int; (* Scope ID - groups all rows for a scope *)
    seq_id : int; (* Position within parent's children *)
    child_scope_id : int option; (* NULL for values, points to new scope for headers *)
    depth : int;
    message : string;
    location : string option;
    data : string option;
    elapsed_start_ns : int;
    elapsed_end_ns : int option;
    is_result : bool;
    log_level : int;
    entry_type : string;
  }

  type run_info = {
    run_id : int;
    timestamp : string;
    elapsed_ns : int;
    command_line : string;
    run_name : string option;
  }

  type stats = {
    total_entries : int;
    total_values : int;
    unique_values : int;
    dedup_percentage : float;
    database_size_kb : int;
  }

  val get_runs : string -> run_info list
  (** Get all runs from metadata database (schema v3+), given the versioned DB path.
      Automatically finds the corresponding <name>_meta.db file. *)

  val get_latest_run_id : string -> int option
  (** Get the ID of the most recent run from metadata DB, given the versioned DB path *)

  val get_entries : Sqlite3.db -> ?parent_id:int -> ?max_depth:int -> unit -> entry list
  (** Get entries for a specific run, optionally filtered by parent_id and max_depth *)

  val get_stats : Sqlite3.db -> string -> stats
  (** Get database statistics including deduplication metrics *)

  val search_entries : Sqlite3.db -> pattern:string -> entry list
  (** Search entries by regex pattern matching message, location, or data *)

  val get_root_entries : Sqlite3.db -> with_values:bool -> entry list
  (** Get only root-level entries efficiently. When [with_values] is true, includes
      immediate children values. Fast for large databases. *)
end

(** Tree renderer for terminal output *)
module Renderer : sig
  type tree_node = { entry : Query.entry; children : tree_node list }

  val build_tree : Query.entry list -> tree_node list
  (** Build tree structure from flat entry list *)

  val format_elapsed_ns : int -> string
  (** Format elapsed time in human-readable units *)

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

  val elapsed_time : Query.entry -> int option
  (** Calculate elapsed time for an entry in nanoseconds *)

  val render_tree_json : ?max_depth:int option -> tree_node list -> string
  (** Render tree as JSON array *)

  val render_entries_json : Query.entry list -> string
  (** Render entries as JSON array *)

  val entry_to_json : Query.entry -> string
  (** Render single entry as JSON object *)
end

(** Interactive TUI using Notty *)
module Interactive : sig
  val run : Sqlite3.db -> string -> unit
  (** Launch interactive terminal UI for exploring a trace run. Arguments: db handle,
      db_path

      Controls:
      - [↑/↓] or [k/j]: Navigate up/down
      - [Enter]: Expand/collapse current node
      - [t]: Toggle time display
      - [v]: Toggle values-first mode
      - [q] or [Esc]: Quit *)
end

(** Main client interface *)
module Client : sig
  type t

  val open_db : string -> t
  (** Open database for reading *)

  val close : t -> unit
  (** Close database connection *)

  val list_runs : t -> Query.run_info list
  (** List all runs *)

  val get_latest_run : t -> Query.run_info option
  (** Get the run in the database *)

  val show_run_summary : t -> int -> unit
  (** Print summary of the run with the given ID *)

  val show_stats : t -> unit
  (** Print database statistics *)

  val show_trace :
    ?show_scope_ids:bool ->
    ?show_times:bool ->
    ?max_depth:int option ->
    ?values_first_mode:bool ->
    t ->
    unit
  (** Print full trace tree for a run. When [values_first_mode] is true (default), result
      values become headers with location/message as children. *)

  val show_compact_trace : t -> unit
  (** Print compact trace (function names only) *)

  val show_roots : ?show_times:bool -> ?with_values:bool -> t -> unit
  (** Print root entries efficiently. Fast for large databases. When [with_values] is
      true, includes immediate children values. *)

  val search : t -> pattern:string -> unit
  (** Search and print matching entries *)

  val export_markdown : t -> output_file:string -> unit
  (** Export trace to markdown file *)

  val search_tree :
    ?quiet_path:string option ->
    ?format:[ `Text | `Json ] ->
    ?show_times:bool ->
    ?max_depth:int option ->
    ?limit:int option ->
    ?offset:int option ->
    t ->
    pattern:string ->
    int
  (** Search with tree context - shows matching entries with their ancestor paths.
      Uses efficient ancestor propagation like the TUI.
      Returns number of matching scopes found.

      Arguments:
      - [quiet_path]: Stop ancestor propagation when this pattern is matched
      - [format]: Output format (Text or Json)
      - [show_times]: Include elapsed times in output
      - [max_depth]: Limit tree depth
      - [limit]: Limit number of results
      - [offset]: Skip first n results
      - [pattern]: Search pattern (substring match) *)

  val search_subtree :
    ?quiet_path:string option ->
    ?format:[ `Text | `Json ] ->
    ?show_times:bool ->
    ?max_depth:int option ->
    ?limit:int option ->
    ?offset:int option ->
    t ->
    pattern:string ->
    int
  (** Search and show only matching subtrees, pruning non-matching branches.
      Returns number of actual matches (not including propagated ancestors).

      This builds a minimal tree containing only paths to matches, unlike
      [search_tree] which shows full context paths.

      Arguments:
      - [limit]: Limit number of results
      - [offset]: Skip first n results *)

  val show_scope :
    ?format:[ `Text | `Json ] ->
    ?show_times:bool ->
    ?max_depth:int option ->
    ?show_ancestors:bool ->
    t ->
    scope_id:int ->
    unit
  (** Show a specific scope and its descendants.

      Arguments:
      - [show_ancestors]: If true, shows path from root to this scope instead of descendants *)

  val show_entry : ?format:[ `Text | `Json ] -> t -> scope_id:int -> seq_id:int -> unit
  (** Show detailed information for a specific entry *)

  val get_ancestors : ?format:[ `Text | `Json ] -> t -> scope_id:int -> unit
  (** Get and print ancestors of a scope (list of scope IDs from root to target) *)

  val get_parent : ?format:[ `Text | `Json ] -> t -> scope_id:int -> unit
  (** Get and print parent of a scope *)

  val get_children : ?format:[ `Text | `Json ] -> t -> scope_id:int -> unit
  (** Get and print immediate children scope IDs of a scope *)

  val search_at_depth :
    ?quiet_path:string option ->
    ?format:[ `Text | `Json ] ->
    ?show_times:bool ->
    depth:int ->
    t ->
    pattern:string ->
    unit
  (** Search and show only unique entries at a specific depth on paths to matches.

      This provides a TUI-like summary view - shows only the depth-N ancestors
      of matching entries, giving a high-level overview without overwhelming detail.

      Example: [search_at_depth ~depth:4 ~pattern:"(id 79)" ~quiet_path:"env"]
      shows only the depth-4 scopes that are ancestors of matches, deduplicated.

      Use case: When [search_tree] returns too many results, use this to see
      a summary at a shallower depth, then drill down with [show_scope]. *)
end
