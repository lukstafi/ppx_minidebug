(** Query layer for database access, helper functions for the client *)

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

val format_elapsed_ns : int -> string
(** Format elapsed time in human-readable units *)

val elapsed_time : entry -> int option
(** Calculate elapsed time for an entry in nanoseconds *)

(** Module signature for Query operations - all functions access module-level DB
    connections *)
module type S = sig
  val db_path : string
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
  val extract_along_path : start_scope_id:int -> extraction_path:string list -> int option

  val populate_search_results :
    search_term:string ->
    quiet_path:string option ->
    search_order:search_order ->
    completed_ref:bool ref ->
    results_table:(int * int, bool) Hashtbl.t ->
    unit

  val populate_extract_search_results :
    search_path:string list ->
    extraction_path:string list ->
    quiet_path:string option ->
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
