(* open Sexplib0.Sexp_conv *)

(* $MDX part-begin=introduction *)
let _get_local_debug_runtime = Minidebug_runtime.local_runtime "sync_to_md-introduction"
let%debug_sexp rec foo : int list -> int = function [] -> 0 | x :: xs -> x + foo xs
let (_ : int) = foo [ 1; 2; 3 ]
(* $MDX part-end *)

(* $MDX part-begin=simple_html *)
let _get_local_debug_runtime =
  Minidebug_runtime.local_runtime ~backend:(`Html Minidebug_runtime.default_html_config)
    "sync_to_md-simple_html"

let%debug_sexp rec foo : int list -> int = function [] -> 0 | x :: xs -> x + foo xs
let (_ : int) = foo [ 1; 2; 3 ]
(* $MDX part-end *)

(* $MDX part-begin=highlight_diffs *)
let _get_local_debug_runtime =
  Minidebug_runtime.local_runtime ~prev_run_file:"sync_to_md-introduction.raw"
    "sync_to_md-highlight_diffs"

let%debug_sexp rec foo : int list -> int = function [] -> 0 | x :: xs -> x + foo xs
let (_ : int) = foo [ 1; 5; 3; 4 ]
(* $MDX part-end *)

(* $MDX part-begin=at_log_level *)
let _get_local_debug_runtime = Minidebug_runtime.local_runtime "sync_to_md-at_log_level"

let%debug_sexp test_at_log_level for_log_level : unit =
  if !Debug_runtime.log_level >= for_log_level then
    [%at_log_level
      for_log_level;
      [%log_entry
        "header";
        Printf.printf "level %d" for_log_level]]

let%debug_sexp _test_at_log_level_2 : unit = test_at_log_level 2
let%debug_sexp _test_at_log_level_3 : unit = test_at_log_level 3
(* $MDX part-end *)
