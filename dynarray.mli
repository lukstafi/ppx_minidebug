(** Minimal Dynarray implementation for compatibility with OCaml 4.13/4.14 *)

type 'a t
(** The type of dynamic arrays containing elements of type ['a]. *)

val create : unit -> 'a t
(** [create ()] is a new, empty array. *)

val length : 'a t -> int
(** [length a] is the number of elements in the array. *)

val get : 'a t -> int -> 'a
(** [get a i] is the [i]-th element of [a], starting with index [0].
    @raise Invalid_argument if the index is invalid *)

val set : 'a t -> int -> 'a -> unit
(** [set a i x] sets the [i]-th element of [a] to be [x].
    @raise Invalid_argument if the index is invalid. *)

val add_last : 'a t -> 'a -> unit
(** [add_last a x] adds the element [x] at the end of the array [a]. *)

val clear : 'a t -> unit
(** [clear a] removes all the elements of [a]. *)

val is_empty : 'a t -> bool
(** [is_empty a] is [true] if [a] is empty, that is, if [length a = 0]. *)

val to_seq : 'a t -> 'a Seq.t
(** [to_seq a] is the sequence of elements [get a 0], [get a 1]... [get a (length a - 1)].
*)

val to_array : 'a t -> 'a array
(** [to_array a] returns a fixed-sized array corresponding to the dynamic array [a]. This
    always allocate a new array and copies elements into it. *)

val of_seq : 'a Seq.t -> 'a t
(** [of_seq seq] is an array containing the same elements as [seq]. It traverses [seq]
    once and will terminate only if [seq] is finite. *)
