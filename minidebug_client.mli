(** In-process client for querying and displaying ppx_minidebug database traces *)

(** Query layer for database access *)
module Query : sig
  type entry = {
    entry_id : int;
    parent_id : int option;
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
  }

  type stats = {
    total_entries : int;
    total_values : int;
    unique_values : int;
    dedup_percentage : float;
    database_size_kb : int;
  }

  val get_runs : Sqlite3.db -> run_info list
  (** Get all runs from database, ordered by run_id descending *)

  val get_latest_run_id : Sqlite3.db -> int option
  (** Get the ID of the most recent run *)

  val get_entries :
    Sqlite3.db ->
    run_id:int ->
    ?parent_id:int ->
    ?max_depth:int ->
    unit ->
    entry list
  (** Get entries for a specific run, optionally filtered by parent_id and max_depth *)

  val get_stats : Sqlite3.db -> string -> stats
  (** Get database statistics including deduplication metrics *)

  val search_entries : Sqlite3.db -> run_id:int -> pattern:string -> entry list
  (** Search entries by regex pattern matching message, location, or data *)
end

(** Tree renderer for terminal output *)
module Renderer : sig
  type tree_node = {
    entry : Query.entry;
    children : tree_node list;
  }

  val build_tree : Query.entry list -> tree_node list
  (** Build tree structure from flat entry list *)

  val format_elapsed_ns : int -> string
  (** Format elapsed time in human-readable units *)

  val render_tree :
    ?show_entry_ids:bool ->
    ?show_times:bool ->
    ?max_depth:int option ->
    tree_node list ->
    string
  (** Render tree to string with full details *)

  val render_compact : tree_node list -> string
  (** Render compact summary (just function calls) *)
end

(** Main client interface *)
module Client : sig
  type t

  val open_db : string -> t
  (** Open database for reading *)

  val close : t -> unit
  (** Close database connection *)

  val list_runs : t -> Query.run_info list
  (** List all runs in the database *)

  val get_latest_run : t -> Query.run_info option
  (** Get the most recent run *)

  val show_run_summary : t -> int -> unit
  (** Print summary of a specific run *)

  val show_stats : t -> unit
  (** Print database statistics *)

  val show_trace :
    t ->
    ?show_entry_ids:bool ->
    ?show_times:bool ->
    ?max_depth:int option ->
    int ->
    unit
  (** Print full trace tree for a run *)

  val show_compact_trace : t -> int -> unit
  (** Print compact trace (function names only) *)

  val search : t -> run_id:int -> pattern:string -> unit
  (** Search and print matching entries *)

  val export_markdown : t -> run_id:int -> output_file:string -> unit
  (** Export trace to markdown file *)
end
