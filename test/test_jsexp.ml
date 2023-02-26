open Base
let () = Caml.Format.printf "%a" Sexp.pp_hum ([%sexp_of: int list] [1; 2; 3])