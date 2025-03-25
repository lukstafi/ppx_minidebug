open Sexplib0.Sexp_conv

let debug_run1 () =
  let _get_local_debug_runtime =
    Minidebug_runtime.local_runtime ~values_first_mode:true ~boxify_sexp_from_size:0
           ~backend:`Text "debugger_diffs_run1"
  in
  let%debug_sexp foo (x : int) : int list =
    let y : int = x + 1 in
    let z : int = y + 1 in
    [ x; y; z; 2 * z ]
  in
  ignore @@ foo 7

let debug_run2 () =
  let _get_local_debug_runtime =
    Minidebug_runtime.local_runtime ~values_first_mode:true ~boxify_sexp_from_size:0
           ~backend:`Text ~prev_run_file:"debugger_diffs_run1.raw" "debugger_diffs_run2"
  in
  let%debug_sexp foo (x : int) : int list =
    let y : int = x + 1 in
    let z : int = y + 2 in
    [ x; y; z; 2 * z ]
  in
  ignore @@ foo 7

let () =
  if Array.length Sys.argv > 1 && Sys.argv.(1) = "run2" then debug_run2 ()
  else if Array.length Sys.argv > 1 && Sys.argv.(1) = "run1" then debug_run1 ()
  else failwith "Usage: test_debug_diffs run1|run2"
