(** Database-backed tracing runtime for ppx_minidebug.

    This module provides a database backend for storing debug traces with
    content-addressed deduplication. *)

(** Schema management and database initialization *)
module Schema : sig
  val schema_version : int
  (** Current database schema version *)

  val initialize_db : Sqlite3.db -> unit
  (** Initialize database tables and indexes *)
end

(** Content-addressed value storage with O(1) deduplication *)
module ValueIntern : sig
  type t
  (** Value interning context *)

  val create : Sqlite3.db -> t
  (** Create a new value interning context *)

  val hash_value : string -> string
  (** Hash a string value for content addressing *)

  val intern : t -> value_type:string -> string -> int
  (** Intern a value and return its value_id *)

  val finalize : t -> unit
  (** Finalize prepared statements *)
end

(** Extended config module type *)
module type Db_config = sig
  include Minidebug_runtime.Shared_config
end

(** Database backend implementing Debug_runtime interface *)
module DatabaseBackend : functor (_ : Db_config) -> Minidebug_runtime.Debug_runtime

val debug_db_file :
  ?time_tagged:Minidebug_runtime.time_tagged ->
  ?elapsed_times:Minidebug_runtime.elapsed_times ->
  ?location_format:Minidebug_runtime.location_format ->
  ?print_entry_ids:bool ->
  ?verbose_entry_ids:bool ->
  ?run_name:string ->
  ?for_append:bool ->
  ?log_level:int ->
  ?path_filter:[ `Whitelist of Re.re | `Blacklist of Re.re ] ->
  string ->
  (module Minidebug_runtime.Debug_runtime)
(** Factory function to create a database runtime that writes to a file *)

val debug_db :
  ?debug_ch:out_channel ->
  ?time_tagged:Minidebug_runtime.time_tagged ->
  ?elapsed_times:Minidebug_runtime.elapsed_times ->
  ?location_format:Minidebug_runtime.location_format ->
  ?print_entry_ids:bool ->
  ?verbose_entry_ids:bool ->
  ?run_name:string ->
  ?log_level:int ->
  ?path_filter:[ `Whitelist of Re.re | `Blacklist of Re.re ] ->
  unit ->
  (module Minidebug_runtime.Debug_runtime)
(** Factory function to create a database runtime (defaults to "debug.db" filename) *)
