
module Debug_ch : functor(_ : sig val v : string end) -> sig val debug_ch : out_channel end
    
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

module Format : functor (_ : sig val debug_ch : out_channel end) -> Debug_runtime
    
module Flushing : functor (_ : sig val debug_ch : out_channel end) -> Debug_runtime

module PrintBox : functor (_ : sig val debug_ch : out_channel end) -> Debug_runtime
