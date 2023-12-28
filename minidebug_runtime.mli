(** The functors creating a [Debug_runtime] module that
    {{:http://lukstafi.github.io/ppx_minidebug/ppx_minidebug/Minidebug_runtime/index.html}
    [ppx_minidebug]} requires. *)

module type Debug_ch = sig
  val debug_ch : out_channel
  val time_tagged : bool
  val max_nesting_depth : int option
  val max_num_children : int option
end

val debug_ch :
  ?time_tagged:bool ->
  ?max_nesting_depth:int ->
  ?max_num_children:int ->
  ?for_append:bool ->
  string ->
  (module Debug_ch)
(** Opens a file with the given path. By default the logging will not be time tagged and
    will be appending to the file. *)

(** When using the
    {{:http://lukstafi.github.io/ppx_minidebug/ppx_minidebug/Minidebug_runtime/index.html}
    [ppx_minidebug]} syntax extension, provide a module called [Debug_runtime] with
    this signature in scope of the instrumented code. *)
module type Debug_runtime = sig
  val close_log : unit -> unit

  val open_log_preamble_brief :
    fname:string -> pos_lnum:int -> pos_colnum:int -> message:string -> unit

  val open_log_preamble_full :
    fname:string ->
    start_lnum:int ->
    start_colnum:int ->
    end_lnum:int ->
    end_colnum:int ->
    message:string ->
    unit

  val log_value_sexp : descr:string -> sexp:Sexplib0.Sexp.t -> unit
  val log_value_pp : descr:string -> pp:(Format.formatter -> 'a -> unit) -> v:'a -> unit
  val log_value_show : descr:string -> v:string -> unit
  val exceeds_max_nesting : unit -> bool
  val exceeds_max_children : unit -> bool
end

(** The logged traces will be indented using OCaml's `Format` module. *)
module Pp_format : functor (_ : Debug_ch) -> Debug_runtime

(** The output is flushed line-at-a-time, so no output should be lost if the traced program crashes.
    The logged traces are still indented, but if the values to print are multi-line, their formatting
    might be messy. The indentation is also smaller (half of PrintBox). *)
module Flushing : functor (_ : Debug_ch) -> Debug_runtime

module type Debug_runtime_cond = sig
  include Debug_runtime

  val no_debug_if : bool -> unit
  (** When passed true within the scope of a log subtree, disables the logging of this subtree and its
      subtrees. Does not do anything when passed false ([no_debug_if false] does {e not} re-enable
      the log). *)
end

(** The logged traces will be pretty-printed as trees using the `printbox` package. This logger
    supports conditionally disabling a particular nesting of the logs, regardless of where
    in the nesting level [no_debug_if] is called. *)
module PrintBox : functor (_ : Debug_ch) -> sig
  include Debug_runtime_cond

  val to_html : bool ref
  (** While [true], logs are generated as html; if [false], as monospaced text. *)

  val boxify_sexp_from_size : int ref
  (** If positive, [Sexp.t]-based logs with this many or more atoms are converted to print-boxes
      before logging. *)

  val highlight_terms : Re.re option ref
  (** Uses a highlight style for logs on paths ending with a log matching the regular expression. *)

  val exclude_on_path : Re.re option ref
  (** Does not propagate the highlight status from child logs through log headers matching
      the given regular expression. *)

  val highlighted_roots : bool ref
  (** If set to true, only ouptputs highlighted toplevel boxes. This makes it simpler to trim
      excessive logging while still providing all the context. Defaults to [false]. *)
end

val debug_html :
  ?time_tagged:bool ->
  ?max_nesting_depth:int ->
  ?max_num_children:int ->
  ?highlight_terms:Re.t ->
  ?exclude_on_path:Re.t ->
  ?highlighted_roots:bool ->
  ?for_append:bool ->
  ?boxify_sexp_from_size:int ->
  string ->
  (module Debug_runtime_cond)
(** Creates a PrintBox-based debug runtime configured to output html to a file with the given name.
    By default the logging will not be time tagged and the file will be created or erased
    by this function. The default [boxify_sexp_from_size] value is 50. *)

val debug :
  ?debug_ch:out_channel ->
  ?time_tagged:bool ->
  ?max_nesting_depth:int ->
  ?max_num_children:int ->
  ?highlight_terms:Re.t ->
  ?exclude_on_path:Re.t ->
  ?highlighted_roots:bool ->
  unit ->
  (module Debug_runtime_cond)
(** Creates a PrintBox-based debug runtime. By default it will log to [stdout] and will not be
    time tagged. *)

val debug_flushing :
  ?debug_ch:out_channel ->
  ?time_tagged:bool ->
  ?max_nesting_depth:int ->
  ?max_num_children:int ->
  unit ->
  (module Debug_runtime)
(** Creates a PrintBox-based debug runtime. By default it will log to [stdout] and will not be
    time tagged. *)
