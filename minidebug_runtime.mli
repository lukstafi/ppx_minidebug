(** The functors creating a [Debug_runtime] module that
    {{:http://lukstafi.github.io/ppx_minidebug/ppx_minidebug/Minidebug_runtime/index.html}
    [ppx_minidebug]} requires. *)

type elapsed_times = Not_reported | Seconds | Milliseconds | Microseconds | Nanoseconds

(** The log levels, for both (in scope) compile time, and for the PrintBox runtime. When considered at
    compile time, inspecting strings requires string literals, at runtime it applies to all string values.
    Not logging at compile time means the corresponding loggingcode is not generated; not logging at
    runtime means the logging state is not updated. *)
type log_level =
  | Nothing  (** Does not log anything. *)
  | Prefixed of string array
      (** Behaves as [Nonempty_entries] and additionally: only logs "leaf" values when the inspected string
          starts with one of the prefixes. *)
  | Prefixed_or_result of string array
      (** Behaves as [Nonempty_entries] and additionally: only logs "leaf" values when the inspected string
          starts with one of the prefixes, or the value is marked as a result. Doesn't output results
          of an entry if there are no non-result logs. *)
  | Nonempty_entries
      (** Does not log entries without children (treating results as children). *)
  | Everything  (** Does not restrict logging. *)

module type Debug_ch = sig
  val refresh_ch : unit -> bool
  val debug_ch : unit -> out_channel
  val snapshot_ch : unit -> unit
  val reset_to_snapshot : unit -> unit
  val time_tagged : bool
  val elapsed_times : elapsed_times
  val print_entry_ids : bool
  val global_prefix : string
  val split_files_after : int option
end

val debug_ch :
  ?time_tagged:bool ->
  ?elapsed_times:elapsed_times ->
  ?print_entry_ids:bool ->
  ?global_prefix:string ->
  ?split_files_after:int ->
  ?for_append:bool ->
  string ->
  (module Debug_ch)
(** Sets up a file with the given path, or if [split_files_after] is given, creates a directory
    to store the files. By default the logging will not be time tagged and will be appending
    to the file / creating more files. If [split_files_after] is given and [for_append] is false,
    clears the directory. If the opened file exceeds [split_files_after] characters, [Debug_ch.refresh_ch ()]
    returns true; if in that case [Debug_ch.debug_ch ()] is called, it will create and return a new file.

    If [elapsed_times] is different from [Not_reported], the elapsed time spans are printed for log
    subtrees, in the corresponding units with precision up to 1%. The times include printing out logs,
    therefore might not be reliable for profiling. In the runtime creation functions, [elapsed_times]
    defaults to [Not_reported].

    If [print_entry_ids] is true, the [entry_id] identifiers are printed on log headers with the syntax
    [{#ID}]; by default they are omitted.

    If [global_prefix] is given, the log header messages (and the log closing messages for the flushing
    backend) are prefixed with it. *)

(** When using the
    {{:http://lukstafi.github.io/ppx_minidebug/ppx_minidebug/Minidebug_runtime/index.html}
    [ppx_minidebug]} syntax extension, provide a module called [Debug_runtime] with
    this signature in scope of the instrumented code. *)
module type Debug_runtime = sig
  val close_log : unit -> unit

  val open_log_preamble_brief :
    fname:string ->
    pos_lnum:int ->
    pos_colnum:int ->
    message:string ->
    entry_id:int ->
    unit

  val open_log_preamble_full :
    fname:string ->
    start_lnum:int ->
    start_colnum:int ->
    end_lnum:int ->
    end_colnum:int ->
    message:string ->
    entry_id:int ->
    unit

  val log_value_sexp :
    ?descr:string -> entry_id:int -> is_result:bool -> Sexplib0.Sexp.t -> unit

  val log_value_pp :
    ?descr:string ->
    entry_id:int ->
    pp:(Format.formatter -> 'a -> unit) ->
    is_result:bool ->
    'a ->
    unit

  val log_value_show : ?descr:string -> entry_id:int -> is_result:bool -> string -> unit
  val exceeds_max_nesting : unit -> bool
  val exceeds_max_children : unit -> bool
  val get_entry_id : unit -> int
  val max_nesting_depth : int option ref
  val max_num_children : int option ref
end

(** The output is flushed line-at-a-time, so no output should be lost if the traced program crashes.
    The logged traces are still indented, but if the values to print are multi-line, their formatting
    might be messy. The indentation is also smaller (half of PrintBox). *)
module Flushing : functor (_ : Debug_ch) -> Debug_runtime

val default_html_config : PrintBox_html.Config.t
val default_md_config : PrintBox_md.Config.t

module type PrintBox_runtime = sig
  include Debug_runtime

  val no_debug_if : bool -> unit
  (** When passed true within the scope of a log subtree, disables the logging of this subtree and its
      subtrees. Does not do anything when passed false ([no_debug_if false] does {e not} re-enable
      the log). *)

  type config = {
    mutable hyperlink : [ `Prefix of string | `No_hyperlinks ];
        (** If [hyperlink] is [`Prefix prefix], code pointers are rendered as hyperlinks.
            When [prefix] is either empty, starts with a dot, or starts with ["http:"] or ["https:"],
            the link address has the form [sprintf "%s#L%d" fname start_lnum], allowing browsing in HTML directly.
            Otherwise, it has the form [sprintf "%s:%d:%d" fname start_lnum (start_colnum + 1)],
            intended for editor-specific prefixes such as ["vscode://file/"].

            Note that rendering a link on a node will make the node non-foldable, therefore it is best
            to combine [`prefix prefix] with [values_first_mode]. *)
    mutable backend :
      [ `Text | `Html of PrintBox_html.Config.t | `Markdown of PrintBox_md.Config.t ];
        (** If the content is [`Text], logs are generated as monospaced text; for other settings as html
            or markdown. *)
    mutable boxify_sexp_from_size : int;
        (** If positive, [Sexp.t]-based logs with this many or more atoms are converted to print-boxes
            before logging. *)
    mutable highlight_terms : Re.re option;
        (** Uses a highlight style for logs on paths ending with a log matching the regular expression. *)
    mutable exclude_on_path : Re.re option;
        (** Does not propagate the highlight status from child logs through log headers matching
            the given regular expression. *)
    mutable prune_upto : int;
        (** At depths lower than [prune_upto] (or equal if counting from 1) only ouptputs highlighted boxes.
            This makes it simpler to trim excessive logging while still providing some context.
            Defaults to [0] -- no pruning. *)
    mutable truncate_children : int;
        (** If > 0, only the given number of the most recent children is kept at each node.
            Defaults to [0] -- keep all (no pruning). *)
    mutable values_first_mode : bool;
        (** If set to true, does not put the source code location of a computation as a header of its subtree.
            Rather, puts the result of the computation as the header of a computation subtree,
            if rendered as a single line -- or just the name, and puts the result near the top.
            If false, puts the result at the end of the computation subtree, i.e. preserves the order
            of the computation. *)
    mutable max_inline_sexp_size : int;
        (** Maximal size (in atoms) up to which a sexp value can be inlined during "boxification". *)
    mutable max_inline_sexp_length : int;
        (** Maximal length (in characters/bytes) up to which a sexp value can be inlined during "boxification". *)
    mutable log_level : log_level;  (** How much to log, see {!type:log_level}. *)
    mutable snapshot_every_sec : float option;
        (** If given, output a snapshot of the pending logs when at least the given time (in seconds) has
            passed since the previous output. This is only checked at calls to log values. *)
  }

  val config : config

  val snapshot : unit -> unit
  (** Outputs the current logging stack to the logging channel. If the logging channel supports that,
      an output following a snapshot will rewind the channel to the state prior to the snapshot. *)
end

(** The logged traces will be pretty-printed as trees using the `printbox` package. This logger
    supports conditionally disabling a particular nesting of the logs, regardless of where
    in the nesting level [no_debug_if] is called. *)
module PrintBox : functor (_ : Debug_ch) -> PrintBox_runtime

val debug_file :
  ?time_tagged:bool ->
  ?elapsed_times:elapsed_times ->
  ?print_entry_ids:bool ->
  ?global_prefix:string ->
  ?split_files_after:int ->
  ?highlight_terms:Re.t ->
  ?exclude_on_path:Re.t ->
  ?prune_upto:int ->
  ?truncate_children:int ->
  ?for_append:bool ->
  ?boxify_sexp_from_size:int ->
  ?backend:[ `Text | `Html of PrintBox_html.Config.t | `Markdown of PrintBox_md.Config.t ] ->
  ?hyperlink:string ->
  ?values_first_mode:bool ->
  ?log_level:log_level ->
  ?snapshot_every_sec:float ->
  string ->
  (module PrintBox_runtime)
(** Creates a PrintBox-based debug runtime configured to output html or markdown to a file with
    the given name suffixed with [".log"], [".html"] or [".md"] depending on the backend.
    By default the logging will not be time tagged and the file will be created or erased by
    this function. The default [boxify_sexp_from_size] value is 50.
    
    By default [backend] is [`Markdown PrintBox.default_md_config].
    See {!type:PrintBox.config} for details about PrintBox-specific parameters.
    See {!debug_ch} for the details about shared parameters. *)

val debug :
  ?debug_ch:out_channel ->
  ?time_tagged:bool ->
  ?elapsed_times:elapsed_times ->
  ?print_entry_ids:bool ->
  ?global_prefix:string ->
  ?highlight_terms:Re.t ->
  ?exclude_on_path:Re.t ->
  ?prune_upto:int ->
  ?truncate_children:int ->
  ?values_first_mode:bool ->
  ?log_level:log_level ->
  ?snapshot_every_sec:float ->
  unit ->
  (module PrintBox_runtime)
(** Creates a PrintBox-based debug runtime for the [`Text] backend. By default it will log to [stdout]
    and will not be time tagged.

    See {!type:PrintBox.config} for details about PrintBox-specific parameters.
    See {!debug_ch} for the details about shared parameters. *)

val debug_flushing :
  ?debug_ch:out_channel ->
  ?time_tagged:bool ->
  ?elapsed_times:elapsed_times ->
  ?print_entry_ids:bool ->
  ?global_prefix:string ->
  unit ->
  (module Debug_runtime)
(** Creates a flushing-based debug runtime. By default it will log to [stdout] and will not be
    time tagged. See {!debug_ch} for the details about shared parameters. *)

val forget_printbox : (module PrintBox_runtime) -> (module Debug_runtime)
(** Upcasts the runtime. *)
