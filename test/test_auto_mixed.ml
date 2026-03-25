(* Test: explicit annotations coexist with auto-instrumented functions *)

let _get_local_debug_runtime =
  let rt = Minidebug_db.debug_db_file "debugger_auto_mixed" in
  fun () -> rt

(* This is already annotated — should NOT be double-instrumented *)
let%debug_show annotated_fn (x : int) : int = x * 2

(* This is unannotated — should be auto-instrumented *)
let unannotated_fn (x : int) = x + 1
