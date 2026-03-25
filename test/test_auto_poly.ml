(* Test: auto-instrumentation preserves pvb_constraint for polymorphic types *)

let identity : 'a. 'a -> 'a = fun x -> x

let const : 'a 'b. 'a -> 'b -> 'a = fun x _y -> x
