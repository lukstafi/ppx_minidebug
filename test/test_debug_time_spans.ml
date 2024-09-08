module Debug_runtime =
  (val Minidebug_runtime.debug_file ~elapsed_times:Microseconds ~hyperlink:"./"
         ~backend:(`Markdown Minidebug_runtime.default_md_config) ~truncate_children:4
         "debugger_sexp_time_spans")

let sexp_of_int i = Sexplib0.Sexp.Atom (string_of_int i)

let () =
  let%debug_sexp rec loop (x : int) : int =
    Array.fold_left ( + ) 0
    @@ Array.init
         (20 / (x + 1))
         (fun i ->
           let z : int = i + ((x - 1) / 2) in
           if x <= 0 then i else i + loop (z + (x / 2) - i))
  in
  print_endline @@ Int.to_string @@ loop 3
