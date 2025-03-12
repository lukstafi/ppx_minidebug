## SpecStory

## Debugging Insights for PrevRun Module (3/8/2025, 11:24:15 PM)

_**User**_

I see bad behavior when I apply use this project to debug a complex situation in another project. We need an insight why there's a failure to align when there are large gaps in current run vs. previous run, even though I configured the exploration band max_distance_factor very large. We could be outputting a meta-debug-log to get that information. Let's restrict the meta-debugging to the PrevRun module. We need to see what the optimal edits are at various points, without too much redundant information.

---

_**Assistant**_

I'll help you add meta-debugging to the `PrevRun` module to understand the alignment issues. We'll want to see:

1. The exploration band boundaries being used
2. The optimal edit sequences being computed
3. The costs at key points in the dynamic programming table

Let me add this meta-debugging capability:

---

_****_

```diff
      max_distance_factor : int;
          (* Maximum distance to consider as a factor of current position *)
-   }
+     meta_debug_oc : out_channel option;
+         (* Optional channel for meta-debugging information *)
+   }
+ 
+   let meta_debug state fmt =
+     match state.meta_debug_oc with
+     | None -> Printf.ifprintf stdout fmt
+     | Some oc -> Printf.fprintf oc fmt
+ 
+   let string_of_edit_type = function
+     | Match -> "Match"
+     | Insert -> "Insert"
+     | Delete -> "Delete"
+     | Change s -> Printf.sprintf "Change(%s)" s
+ 
+   let dump_edits state edits =
+     meta_debug state "Optimal edit sequence (%d edits):\n" (List.length edits);
+     List.iteri
+       (fun i edit ->
+         meta_debug state "  %d: %s at pos %d\n" i (string_of_edit_type edit.edit_type)
+           edit.curr_index)
+       edits
+ 
+   let dump_exploration_band state j center_row min_i max_i =
+     meta_debug state
+       "Column %d: Exploring rows %d to %d (center: %d, band_size: %d)\n" j min_i max_i
+       center_row (max_i - min_i + 1)
  
    let save_chunk oc messages =
      let prev_normalized_chunk = normalize_chunk diff_ignore_pattern prev_chunk in
      let curr_oc = open_out_bin (curr_file ^ ".raw") in
+     let meta_debug_oc =
+       if Option.is_some prev_file then
+         let oc = open_out (curr_file ^ ".meta-debug.log") in
+         Gc.finalise (fun _ -> close_out oc) oc;
+         Some oc
+       else None
+     in
      Gc.finalise (fun _ -> close_out curr_oc) curr_oc;
      Some
          diff_ignore_pattern;
          normalized_msgs = Hashtbl.create 1000;
-         (* Still keep this for messages not in chunks *)
          min_cost_rows = Hashtbl.create 1000;
-         (* Track min cost row for each column *)
          max_distance_factor;
+         meta_debug_oc;
        }
  
          (max_int, -1, -1) costs
      in
+     meta_debug state "DP(%d,%d) = %d from (%d,%d)\n" i j min_cost prev_i prev_j;
      Hashtbl.replace state.dp_table (i, j) (min_cost, prev_i, prev_j);
      min_cost
        let min_i = max 0 (center_row - state.max_distance_factor) in
        let max_i = min state.num_rows (center_row + state.max_distance_factor) in
+ 
+       dump_exploration_band state j center_row min_i max_i;
  
        let min_cost_for_col = ref max_int in
        done;
  
+       meta_debug state "Column %d: Minimum cost %d at row %d\n" j !min_cost_for_col
+         !min_cost_row;
+ 
        (* Store the row with minimum cost for this column *)
        Hashtbl.replace state.min_cost_rows j !min_cost_row
      done;
  
-     if state.last_computed_col < col then update_optimal_edits state col;
+     if state.last_computed_col < col then (
+       update_optimal_edits state col;
+       dump_edits state state.optimal_edits);
      state.last_computed_col <- max state.last_computed_col col
  
```

---

_****_

I've added meta-debugging capabilities to the `PrevRun` module. Here's what the changes do:

1. Added a `meta_debug_oc` field to the `dp_state` type to store an optional debug output channel.

2. Added helper functions:
   - `meta_debug`: A printf-style function that writes to the meta debug channel if enabled
   - `string_of_edit_type`: Converts edit types to strings for debugging
   - `dump_edits`: Prints the current optimal edit sequence
   - `dump_exploration_band`: Shows the exploration band boundaries for each column

3. Added debug output at key points:
   - When computing each DP cell, showing the cost and backpointer
   - When exploring each column, showing the exploration band boundaries
   - When finding minimum costs in each column
   - When updating optimal edits

4. The meta-debug log is only created when there's a previous run file to compare against (since that's when we need the debugging info).

The meta-debug log will be written to `<filename>.meta-debug.log` and will contain entries like:

```
Column 5: Exploring rows 0 to 200 (center: 5, band_size: 201)
DP(0,5) = 10 from (-1,-1)
DP(1,5) = 8 from (0,4)
...
Column 5: Minimum cost 6 at row 5
Optimal edit sequence (6 edits):
  0: Match at pos 0
  1: Insert at pos 1
  ...
```

This will help diagnose issues by showing:
1. Whether the exploration band is centered correctly
2. If the band width is sufficient
3. Where the minimum costs are occurring
4. What edit sequences are being chosen and why

To use this, you would:
1. Run your debug session with a previous run file specified
2. Look at the `.meta-debug.log` file to see the alignment process
3. Pay attention to:
   - If the exploration bands are missing important regions
   - If the minimum costs are occurring at band boundaries (suggesting the band might be too narrow)
   - If the optimal edit sequences make sense given the input

Would you like me to add any additional debugging information or modify the format of the output?

---



---

