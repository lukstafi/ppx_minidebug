type 'a t = {
  mutable array : 'a array;
  mutable length : int;
}

let create () = {
  array = [||];
  length = 0;
}

let length t = t.length

let get t i =
  if i < 0 || i >= t.length then
    invalid_arg "Dynarray.get: index out of bounds"
  else
    t.array.(i)

let set t i v =
  if i < 0 || i >= t.length then
    invalid_arg "Dynarray.set: index out of bounds"
  else
    t.array.(i) <- v

let ensure_capacity t n =
  if n > Array.length t.array then
    let new_capacity = max n (max 1 (2 * Array.length t.array)) in
    let new_array = Array.make new_capacity (Obj.magic 0) in
    Array.blit t.array 0 new_array 0 t.length;
    t.array <- new_array

let add_last t v =
  ensure_capacity t (t.length + 1);
  t.array.(t.length) <- v;
  t.length <- t.length + 1

let clear t =
  t.length <- 0

let is_empty t = t.length = 0

let to_seq t =
  let rec aux i () =
    if i >= t.length then Seq.Nil
    else Seq.Cons (t.array.(i), aux (i + 1))
  in
  aux 0

let to_array t =
  if t.length = 0 then [||]
  else
    let result = Array.make t.length t.array.(0) in
    Array.blit t.array 0 result 0 t.length;
    result

let of_seq seq =
  let t = create () in
  Seq.iter (fun x -> add_last t x) seq;
  t 