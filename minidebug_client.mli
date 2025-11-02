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
    db_file : string;
  }

  type stats = {
    total_entries : int;
    total_values : int;
    unique_values : int;
    dedup_percentage : float;
    database_size_kb : int;
  }

  type search_order = AscendingIds | DescendingIds

  (** Module signature for Query operations - all functions access module-level DB connections *)
  module type S = sig
    val get_runs : unit -> run_info list
    val get_latest_run_id : unit -> int option
    val get_run_by_name : run_name:string -> run_info option
    val get_stats : unit -> stats
    val search_entries : pattern:string -> entry list
    val find_entry : scope_id:int -> seq_id:int -> entry option
    val find_scope_header : scope_id:int -> entry option
    val get_entries_for_scopes : scope_ids:int list -> entry list
    val get_entries_from_results : results_table:(int * int, bool) Hashtbl.t -> entry list
    val get_root_entries : with_values:bool -> entry list
    val get_scope_children : parent_scope_id:int -> entry list
    val has_children : parent_scope_id:int -> bool
    val get_parent_ids : scope_id:int -> int list
    val get_parent_id : scope_id:int -> int option
    val get_all_ancestor_paths : scope_id:int -> int list list
    val get_ancestors : scope_id:int -> int list
    val get_max_scope_id : unit -> int
    val lowest_common_ancestor : int list -> int option
    val get_root_scope : int -> int
    val find_matching_paths : patterns:string list -> (int * int list) list
    val extract_along_path :
      start_scope_id:int -> extraction_path:string list -> int option
    val populate_search_results :
      search_term:string ->
      quiet_path:string option ->
      search_order:search_order ->
      completed_ref:bool ref ->
      results_table:(int * int, bool) Hashtbl.t ->
      unit
  end

  (** Functor creating Query module with connections to main DB and metadata DB *)
  module Make : functor
    (_ : sig
       val db_path : string
     end)
    -> S
end

(** Tree renderer for terminal output *)
module Renderer : sig
  type tree_node = { entry : Query.entry; children : tree_node list }

  val build_tree : (module Query.S) -> ?max_depth:int -> Query.entry list -> tree_node list
  (** Build tree structure from Query module and root entries (recommended for full traces) *)

  val build_tree_from_entries : Query.entry list -> tree_node list
  (** Build tree structure from pre-loaded flat entry list (for search/filter use cases) *)

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
  val run : (module Query.S) -> string -> unit
  (** Launch interactive terminal UI for exploring a trace run. Arguments: Query module,
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

  val get_run_by_name : t -> run_name:string -> Query.run_info option
  (** Get a run by its name *)

  val show_run_summary : ?output:Format.formatter -> t -> int -> unit
  (** Print summary of the run with the given ID *)

  val show_stats : ?output:Format.formatter -> t -> unit
  (** Print database statistics *)

  val show_trace :
    ?output:Format.formatter ->
    ?show_scope_ids:bool ->
    ?show_times:bool ->
    ?max_depth:int option ->
    ?values_first_mode:bool ->
    t ->
    unit
  (** Print full trace tree for a run. When [values_first_mode] is true (default), result
      values become headers with location/message as children. *)

  val show_compact_trace : ?output:Format.formatter -> t -> unit
  (** Print compact trace (function names only) *)

  val show_roots :
    ?output:Format.formatter -> ?show_times:bool -> ?with_values:bool -> t -> unit
  (** Print root entries efficiently. Fast for large databases. When [with_values] is
      true, includes immediate children values. *)

  val search : ?output:Format.formatter -> t -> pattern:string -> unit
  (** Search and print matching entries *)

  val export_markdown : t -> output_file:string -> unit
  (** Export trace to markdown file *)

  val search_tree :
    ?output:Format.formatter ->
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
    ?output:Format.formatter ->
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

  val search_intersection :
    ?output:Format.formatter ->
    ?quiet_path:string option ->
    ?format:[ `Text | `Json ] ->
    ?show_times:bool ->
    ?max_depth:int option ->
    ?limit:int option ->
    ?offset:int option ->
    t ->
    patterns:string list ->
    int
  (** Search for scopes matching ALL patterns (intersection/AND logic).
      Returns number of scopes in the intersection.

      For each pattern, runs a separate search with ancestor propagation.
      Then computes the intersection of matching scope IDs across all searches.
      Shows full tree context (ancestors) for scopes in the intersection.

      Arguments:
      - [patterns]: List of 2-4 search patterns (all must match)
      - [quiet_path]: Stop ancestor propagation at pattern (applies to all searches)
      - [limit]: Limit number of results
      - [offset]: Skip first n results

      Example: [search_intersection ~patterns:["(id 79)"; "(id 1802)"] client]
      finds scopes where both patterns appear in their subtree. *)

  val show_scope :
    ?output:Format.formatter ->
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

  val show_subtree :
    ?output:Format.formatter ->
    ?format:[ `Text | `Json ] ->
    ?show_times:bool ->
    ?max_depth:int option ->
    ?show_ancestors:bool ->
    t ->
    scope_id:int ->
    unit
  (** Show a specific scope subtree with full tree rendering.

      Displays: ancestor path (if [show_ancestors]=true) → target scope → all descendants.

      Arguments:
      - [max_depth]: INCREMENTAL depth from target scope (not absolute depth from root).
        For example, if target is at depth 5 and max_depth=3, shows up to depth 8.
      - [show_ancestors]: If true (default), includes ancestor path from root to scope.
      - [show_times]: Include elapsed times in output
      - [format]: Output format (Text or JSON)

      This command is useful after [search_intersection] to explore the full context
      of an LCA scope. *)

  val show_entry :
    ?output:Format.formatter -> ?format:[ `Text | `Json ] -> t -> scope_id:int -> seq_id:int -> unit
  (** Show detailed information for a specific entry *)

  val get_ancestors :
    ?output:Format.formatter -> ?format:[ `Text | `Json ] -> t -> scope_id:int -> unit
  (** Get and print ancestors of a scope (list of scope IDs from root to target) *)

  val get_parent :
    ?output:Format.formatter -> ?format:[ `Text | `Json ] -> t -> scope_id:int -> unit
  (** Get and print parent of a scope *)

  val get_children :
    ?output:Format.formatter -> ?format:[ `Text | `Json ] -> t -> scope_id:int -> unit
  (** Get and print immediate children scope IDs of a scope *)

  val search_at_depth :
    ?output:Format.formatter ->
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

  val search_extract :
    ?output:Format.formatter ->
    ?format:[ `Text | `Json ] ->
    ?show_times:bool ->
    ?max_depth:int option ->
    t ->
    search_path:string list ->
    extraction_path:string list ->
    unit
  (** Search DAG with a path pattern, then extract along a different path with
      deduplication.

      For each match of search_path, extracts along extraction_path (which must share
      the first element with search_path). Prints each extracted subtree, skipping
      consecutive duplicates (same scope_id).

      Arguments:
      - [search_path]: Sequence of patterns to match in the DAG
      - [extraction_path]: Path to extract from each match (first element must match
        search_path's first element)
      - [show_times]: Include elapsed times in output
      - [max_depth]: Limit tree depth in extracted subtrees
      - [format]: Output format (Text or JSON)

      Example: [search_extract ~search_path:["fn_a"; "param_x"]
      ~extraction_path:["fn_a"; "result"] client] finds all paths matching "fn_a" →
      "param_x", then from each match extracts "fn_a" → "result" and prints unique
      results. *)
end
