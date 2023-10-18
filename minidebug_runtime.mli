(** The functors creating a [Debug_runtime] module that
    {{:http://lukstafi.github.io/ppx_minidebug/ppx_minidebug/Minidebug_runtime/index.html}
    [ppx_minidebug]} requires. *)

module type Debug_ch = sig val debug_ch : out_channel val time_tagged : bool end

(** Opens a file with the given path for appending. Debugging is time tagged. *)
module Debug_ch : functor(_ : sig val filename : string end) -> Debug_ch

(** Opens a file with the given path for appending. Debugging is not time tagged. *)
module Debug_ch_no_time_tags : functor(_ : sig val filename : string end) -> Debug_ch

(** When using the
    {{:http://lukstafi.github.io/ppx_minidebug/ppx_minidebug/Minidebug_runtime/index.html}
    [ppx_minidebug]} syntax extension, provide a module called [Debug_runtime] with
    this signature in scope of the instrumented code. *)
module type Debug_runtime =
sig
  val close_log : unit -> unit
  val open_log_preamble_brief :
    fname:string ->
    pos_lnum:int -> pos_colnum:int -> message:string -> unit
  val open_log_preamble_full :
    fname:string ->
    start_lnum:int ->
    start_colnum:int ->
    end_lnum:int -> end_colnum:int -> message:string -> unit
  val log_value_sexp : descr:string -> sexp:Sexplib0.Sexp.t -> unit
  val log_value_pp :
    descr:string -> pp:(Format.formatter -> 'a -> unit) -> v:'a -> unit
  val log_value_show : descr:string -> v:string -> unit
end

(** The logged traces will be indented using OCaml's `Format` module. *)
module Pp_format : functor (_ : Debug_ch) -> Debug_runtime

(** The output is flushed line-at-a-time, so no output should be lost if the traced program crashes.
    The logged traces are still indented, but if the values to print are multi-line, their formatting
    might be messy. The indentation is also smaller (half of PrintBox). *)
module Flushing : functor (_ : Debug_ch) -> Debug_runtime

(** The logged traces will be pretty-printed as trees using the `printbox` package. This logger
    supports conditionally disabling a particular nesting of the logs, regardless of where
    in the nesting level [no_debug_if] is called. *)
module PrintBox : functor (_ : Debug_ch) -> sig
  include Debug_runtime

  (** When passed true within the scope of a log subtree, disables the logging of this subtree and its
      subtrees. Does not do anything when passed false ([no_debug_if false] does {e not} re-enable
      the log). *)
  val no_debug_if : bool -> unit
end
