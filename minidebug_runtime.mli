(** The functors creating a [Debug_runtime] module that
    {{:http://lukstafi.github.io/ppx_minidebug/ppx_minidebug/Minidebug_runtime/index.html}
      [ppx_minidebug]} requires. *)

type time_tagged = Not_tagged | Clock | Elapsed
type elapsed_times = Not_reported | Seconds | Milliseconds | Microseconds | Nanoseconds

type location_format =
  | No_location
  | File_only
  | Beg_line
  | Beg_pos
  | Range_line
  | Range_pos

type toc_entry_criteria =
  | Minimal_depth of int
  | Minimal_size of int
  | Minimal_span of Mtime.span
  | And of toc_entry_criteria list
  | Or of toc_entry_criteria list

module PrevRun : sig
  type edit_type = Match | Insert | Delete | Change

  type edit_info = {
    edit_type : edit_type;
    curr_index : int; (* Index in current run where edit occurred *)
  }

  type chunk = {
    messages : string array;
  }

  type dp_state = {
    mutable prev_chunk : chunk option;  (* Previous run's current chunk *)
    curr_chunk : string Dynarray.t;  (* Current chunk being built *)
    mutable dp_table : (int * int * int) array array;  (* (edit_dist, prev_i, new_i) *)
    mutable last_computed_row : int;  (* Last computed row in dp table *)
    mutable last_computed_col : int;  (* Last computed column in dp table *)
    mutable optimal_edits : edit_info list;  (* Optimal edit sequence so far *)
    prev_ic : in_channel option;  (* Channel for reading previous chunks *)
    curr_oc : out_channel;  (* Channel for writing current chunks *)
  }

  val init_run : ?prev_file:string -> string -> dp_state option
  val check_diff : dp_state -> string -> unit -> bool
  val signal_chunk_end : dp_state -> unit
end

module type Shared_config = sig
  val refresh_ch : unit -> bool
  val debug_ch : unit -> out_channel
  val debug_ch_name : unit -> string
  val snapshot_ch : unit -> unit
  val reset_to_snapshot : unit -> unit
  val table_of_contents_ch : out_channel option
  val time_tagged : time_tagged
  val elapsed_times : elapsed_times
  val location_format : location_format
  val print_entry_ids : bool
  val verbose_entry_ids : bool
  val global_prefix : string
  val split_files_after : int option
  val toc_entry : toc_entry_criteria
  val description : string
  val init_log_level : int
end

val shared_config :
  ?time_tagged:time_tagged ->
  ?elapsed_times:elapsed_times ->
  ?location_format:location_format ->
  ?print_entry_ids:bool ->
  ?verbose_entry_ids:bool ->
  ?global_prefix:string ->
  ?split_files_after:int ->
  ?with_table_of_contents:bool ->
  ?toc_entry:toc_entry_criteria ->
  ?for_append:bool ->
  ?log_level:int ->
  string ->
  (module Shared_config)
(** Sets up a file with the given path, or if [split_files_after] is given, creates a
    directory to store the files. By default the logging will not be time tagged and will
    be appending to the file / creating more files. If [time_tagged] is [Clock], entries
    will be tagged with a date and clock time; if it is [Elapsed], they will be tagged
    with the time span elapsed since the start of the process (using
    [Mtime_clock.elapsed]). If [split_files_after] is given and [for_append] is false,
    clears the directory. If the opened file exceeds [split_files_after] characters,
    [Shared_config.refresh_ch ()] returns true; if in that case
    [Shared_config.debug_ch ()] is called, it will create and return a new file.

    If [elapsed_times] is different from [Not_reported], the elapsed time spans are
    printed for log subtrees, in the corresponding units with precision up to 1%. The
    times include printing out logs, therefore might not be reliable for profiling. In the
    runtime creation functions, [elapsed_times] defaults to [Not_reported].

    If [print_entry_ids] is true, the [entry_id] identifiers are printed on log headers
    with the syntax [{#ID}]; by default they are omitted. If [verbose_entry_ids] is true,
    the [entry_id] identifiers are also printed on logged values.

    If [global_prefix] is given, the log header messages (and the log closing messages for
    the flushing backend) are prefixed with it.

    If [table_of_contents_ch] is given or [with_table_of_contents=true], outputs selected
    log headers to this channel. The provided file name is used as a prefix for links to
    anchors of the log headers. Note that debug runtime builders that take a channel
    instead of a file name, will use [global_prefix] instead for the anchor links. The
    setting [toc_entry] controls the selection of headers to include in a ToC (it defaults
    to [And []], which means including all entries).

    [log_level], by default 9, specifies {!Shared_config.init_log_level}. This is the
    initial log level. In particular, the header "BEGIN DEBUG SESSION" is only printed if
    (initial) [log_level > 0]. *)

(** When using the
    {{:http://lukstafi.github.io/ppx_minidebug/ppx_minidebug/Minidebug_runtime/index.html}
      [ppx_minidebug]} syntax extension, provide a module called [Debug_runtime] with this
    signature in scope of the instrumented code. *)
module type Debug_runtime = sig
  val close_log : fname:string -> start_lnum:int -> entry_id:int -> unit

  val open_log :
    fname:string ->
    start_lnum:int ->
    start_colnum:int ->
    end_lnum:int ->
    end_colnum:int ->
    message:string ->
    entry_id:int ->
    log_level:int ->
    [ `Diagn | `Debug | `Track ] ->
    unit

  val open_log_no_source :
    message:string ->
    entry_id:int ->
    log_level:int ->
    [ `Diagn | `Debug | `Track ] ->
    unit

  val log_value_sexp :
    ?descr:string ->
    entry_id:int ->
    log_level:int ->
    is_result:bool ->
    Sexplib0.Sexp.t ->
    unit

  val log_value_pp :
    ?descr:string ->
    entry_id:int ->
    log_level:int ->
    pp:(Format.formatter -> 'a -> unit) ->
    is_result:bool ->
    'a ->
    unit

  val log_value_show :
    ?descr:string -> entry_id:int -> log_level:int -> is_result:bool -> string -> unit

  val log_value_printbox : entry_id:int -> log_level:int -> PrintBox.t -> unit
  val exceeds_max_nesting : unit -> bool
  val exceeds_max_children : unit -> bool
  val get_entry_id : unit -> int
  val max_nesting_depth : int option ref
  val max_num_children : int option ref
  val global_prefix : string

  val snapshot : unit -> unit
  (** For [PrintBox] runtimes, outputs the current logging stack to the logging channel.
      If the logging channel supports that, an output following a snapshot will rewind the
      channel to the state prior to the snapshot. Does nothing for the [Flushing]
      runtimes. *)

  val description : string
  (** A description that should be sufficient to locate where the logs end up. If not
      configured explicitly, it will be some combination of: the global prefix, the file
      name or "stdout". *)

  val no_debug_if : bool -> unit
  (** For [PrintBox] runtimes, when passed true within the scope of a log subtree,
      disables the logging of this subtree and its subtrees. Does not do anything when
      passed false ([no_debug_if false] does {e not} re-enable the log). Does nothing for
      the [Flushing] runtimes. *)

  val log_level : int ref
  (** The runtime log level.

      The log levels are used both at compile time, and for the PrintBox runtime. Not
      logging at compile time means the corresponding logging code is not generated; not
      logging at runtime means the logging state is not updated. *)
end

(** The output is flushed line-at-a-time, so no output should be lost if the traced
    program crashes. The logged traces are still indented, but if the values to print are
    multi-line, their formatting might be messy. The indentation is also smaller (half of
    PrintBox). *)
module Flushing : functor (_ : Shared_config) -> Debug_runtime

val default_html_config : PrintBox_html.Config.t
val default_md_config : PrintBox_md.Config.t

module type PrintBox_runtime = sig
  include Debug_runtime

  type config = {
    mutable hyperlink : [ `Prefix of string | `No_hyperlinks ];
    mutable toc_specific_hyperlink : string option;
    mutable backend :
      [ `Text | `Html of PrintBox_html.Config.t | `Markdown of PrintBox_md.Config.t ];
    mutable boxify_sexp_from_size : int;
    mutable highlight_terms : Re.re option;
    mutable highlight_diffs : bool;
    mutable exclude_on_path : Re.re option;
    mutable prune_upto : int;
    mutable truncate_children : int;
    mutable values_first_mode : bool;
    mutable max_inline_sexp_size : int;
    mutable max_inline_sexp_length : int;
    mutable snapshot_every_sec : float option;
    mutable sexp_unescape_strings : bool;
    mutable with_toc_listing : bool;
    mutable toc_flame_graph : bool;
    mutable flame_graph_separation : int;
    mutable prev_run_state : PrevRun.dp_state option;
  }

  val config : config
end

(** The logged traces will be pretty-printed as trees using the `printbox` package. This
    logger supports conditionally disabling a particular nesting of the logs, regardless
    of where in the nesting level [no_debug_if] is called. *)
module PrintBox : functor (_ : Shared_config) -> PrintBox_runtime

val debug_file :
  ?time_tagged:time_tagged ->
  ?elapsed_times:elapsed_times ->
  ?location_format:location_format ->
  ?print_entry_ids:bool ->
  ?verbose_entry_ids:bool ->
  ?global_prefix:string ->
  ?split_files_after:int ->
  ?with_toc_listing:bool ->
  ?toc_entry:toc_entry_criteria ->
  ?toc_flame_graph:bool ->
  ?flame_graph_separation:int ->
  ?highlight_terms:Re.t ->
  ?exclude_on_path:Re.t ->
  ?prune_upto:int ->
  ?truncate_children:int ->
  ?for_append:bool ->
  ?boxify_sexp_from_size:int ->
  ?max_inline_sexp_length:int ->
  ?backend:[ `Text | `Html of PrintBox_html.Config.t | `Markdown of PrintBox_md.Config.t ] ->
  ?hyperlink:string ->
  ?toc_specific_hyperlink:string ->
  ?values_first_mode:bool ->
  ?log_level:int ->
  ?snapshot_every_sec:float ->
  ?prev_run_file:string ->
  string ->
  (module PrintBox_runtime)
(** Creates a PrintBox-based debug runtime configured to output html or markdown to a file
    with the given name suffixed with [".log"], [".html"] or [".md"] depending on the
    backend. By default the logging will not be time tagged and the file will be created
    or erased by this function. The default [boxify_sexp_from_size] value is 50.

    Setting [~with_toc_listing:true] or [~toc_flame_graph:true] or both will create an
    additional log file, the given name suffixed with ["-toc"] and the corresponding file
    name extension. This file will collect selected entries, hyperlinking to anchors in
    the main logging file(s).

    If [prev_run_file] is provided, differences between the current run and the previous run
    will be highlighted in the output.

    By default [backend] is [`Markdown PrintBox.default_md_config]. See
    {!type:PrintBox.config} for details about PrintBox-specific parameters. See
    {!shared_config} for the details about shared parameters. *)

val debug :
  ?debug_ch:out_channel ->
  ?time_tagged:time_tagged ->
  ?elapsed_times:elapsed_times ->
  ?location_format:location_format ->
  ?print_entry_ids:bool ->
  ?verbose_entry_ids:bool ->
  ?description:string ->
  ?global_prefix:string ->
  ?table_of_contents_ch:out_channel ->
  ?toc_entry:toc_entry_criteria ->
  ?highlight_terms:Re.t ->
  ?exclude_on_path:Re.t ->
  ?prune_upto:int ->
  ?truncate_children:int ->
  ?toc_specific_hyperlink:string ->
  ?values_first_mode:bool ->
  ?log_level:int ->
  ?snapshot_every_sec:float ->
  unit ->
  (module PrintBox_runtime)
(** Creates a PrintBox-based debug runtime for the [`Text] backend. By default it will log
    to [stdout] and will not be time tagged.

    See {!type:PrintBox.config} for details about PrintBox-specific parameters. See
    {!shared_config} for the details about shared parameters. *)

val debug_flushing :
  ?debug_ch:out_channel ->
  ?table_of_contents_ch:out_channel ->
  ?filename:string ->
  ?time_tagged:time_tagged ->
  ?elapsed_times:elapsed_times ->
  ?location_format:location_format ->
  ?print_entry_ids:bool ->
  ?verbose_entry_ids:bool ->
  ?description:string ->
  ?global_prefix:string ->
  ?split_files_after:int ->
  ?with_table_of_contents:bool ->
  ?toc_entry:toc_entry_criteria ->
  ?for_append:bool ->
  ?log_level:int ->
  unit ->
  (module Debug_runtime)
(** Creates a flushing-based debug runtime. By default it will log to [stdout] and will
    not be time tagged. At most one of [debug_ch], [filename] can be provided. Adds the
    suffix [".log"] to the file name if [filename] is given.

    See {!shared_config} for the details about shared parameters. *)

val forget_printbox : (module PrintBox_runtime) -> (module Debug_runtime)
(** Upcasts the runtime. *)

val sexp_of_lazy_t : ('a -> Sexplib0.Sexp.t) -> 'a lazy_t -> Sexplib0.Sexp.t
(** Unlike [Lazy.sexp_of_t] available in the [Base] library, does not force the lazy
    value, only converts it if it's already computed and non-exception. *)
