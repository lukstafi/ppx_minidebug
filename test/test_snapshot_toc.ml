let _get_local_debug_runtime =
  Minidebug_runtime.local_runtime ~values_first_mode:false ~with_toc_listing:true
    ~snapshot_every_sec:0.1 "debugger_snapshot_toc_debug"

let%debug_show slow_computation (x : int) : int =
  let y : int = x * 2 in
  Unix.sleepf 0.15;
  let z : int = y + 1 in
  Unix.sleepf 0.15;
  let w : int = z * 3 in
  w

let () =
  let result = slow_computation 5 in
  Printf.printf "Result: %d\n" result;
  let module D = (val _get_local_debug_runtime ()) in
  D.finish_and_cleanup ()

let () =
  (* Verify the toc file doesn't have duplicate entries from snapshots *)
  let toc_file = "debugger_snapshot_toc_debug-toc.log" in
  let ic = open_in toc_file in
  let content = In_channel.input_all ic in
  close_in ic;
  (* Count occurrences of the function name in the toc *)
  let count = ref 0 in
  let len = String.length content in
  let needle = "slow_computation" in
  let nlen = String.length needle in
  for i = 0 to len - nlen do
    if String.sub content i nlen = needle then incr count
  done;
  if !count > 1 then
    Printf.printf "FAIL: toc has %d entries for slow_computation (expected 1)\n" !count
  else Printf.printf "PASS: toc has exactly %d entry for slow_computation\n" !count
