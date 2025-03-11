## SpecStory

## Optimizing PrevRun for Large Chunks (2/27/2025, 11:48:04 AM)

_**User**_

Any ideas on how to optimize PrevRun ? Doesn't need to be the precise edit distance if the chunks are large.

---

_**Assistant**_

I can suggest several optimizations for the `PrevRun` module, which currently implements a dynamic programming approach for computing edit distances between chunks of debug messages. Here are some improvements that could make it more efficient, especially for large chunks:

```ocaml:minidebug_runtime.ml
// ... existing code ...
  let load_next_chunk ic =
    try
      let chunk = (Marshal.from_channel ic : chunk) in
      Some chunk
    with End_of_file -> None

  (* Optimization: Use a faster heuristic for large chunks *)
  let fast_diff_heuristic prev_msgs curr_msgs =
    (* For large chunks, use a sampling approach instead of full edit distance *)
    let prev_len = Array.length prev_msgs in
    let curr_len = Dynarray.length curr_msgs in
    
    (* If chunks are small enough, don't use the heuristic *)
    if prev_len < 100 || curr_len < 100 then
      None
    else
      (* Sample a subset of messages to compare *)
      let sample_size = min 50 (min prev_len curr_len) in
      let sample_interval prev_len n = 
        if n <= 1 then 0 else max 1 (prev_len / (n + 1))
      in
      let prev_interval = sample_interval prev_len sample_size in
      let curr_interval = sample_interval curr_len sample_size in
      
      (* Count matches in the samples *)
      let matches = ref 0 in
      for i = 0 to sample_size - 1 do
        let prev_idx = min (prev_len - 1) (i * prev_interval) in
        let curr_idx = min (curr_len - 1) (i * curr_interval) in
        if prev_msgs.(prev_idx) = Dynarray.get curr_msgs curr_idx then
          incr matches
      done;
      
      (* If more than 70% match, consider chunks similar *)
      let match_ratio = float_of_int !matches /. float_of_int sample_size in
      Some (match_ratio < 0.7)
  
  let del_cost = 2
  let ins_cost = 2
  let change_cost = 3
// ... existing code ...

  let compute_dp_upto state row col =
    (* Optimization: Try fast heuristic first for large chunks *)
    match state.prev_chunk with
    | Some chunk when row > 100 && col > 100 ->
        (match fast_diff_heuristic chunk.messages state.curr_chunk with
        | Some different ->
            (* If heuristic says chunks are different, mark all as different *)
            if different then
              state.optimal_edits <- 
                List.init (col + 1) (fun j -> { edit_type = Insert; curr_index = j })
            else
              (* If similar, mark all as matching (approximate) *)
              state.optimal_edits <-
                List.init (col + 1) (fun j -> { edit_type = Match; curr_index = j })
        | None ->
            (* Fall back to full DP if heuristic doesn't apply *)
            for i = state.last_computed_row + 1 to row do
              for j = 0 to col do
                compute_dp_cell state i j (Dynarray.get state.curr_chunk j)
              done
            done;
            for i = 0 to state.last_computed_row do
              for j = state.last_computed_col + 1 to col do
                compute_dp_cell state i j (Dynarray.get state.curr_chunk j)
              done
            done;
            state.last_computed_row <- max state.last_computed_row row;
            state.last_computed_col <- max state.last_computed_col col;
            update_optimal_edits state row col)
    | _ ->
        (* Original DP computation for smaller chunks *)
        for i = state.last_computed_row + 1 to row do
          for j = 0 to col do
            compute_dp_cell state i j (Dynarray.get state.curr_chunk j)
          done
        done;
        for i = 0 to state.last_computed_row do
          for j = state.last_computed_col + 1 to col do
            compute_dp_cell state i j (Dynarray.get state.curr_chunk j)
          done
        done;
        state.last_computed_row <- max state.last_computed_row row;
        state.last_computed_col <- max state.last_computed_col col;
        update_optimal_edits state row col
// ... existing code ...
```

Here are the key optimizations I've suggested:

1. **Fast Heuristic for Large Chunks**: Added a `fast_diff_heuristic` function that uses sampling to quickly determine if two chunks are significantly different without computing the full edit distance.

2. **Sampling Approach**: Instead of comparing every message, it samples a subset of messages at regular intervals and checks if they match.

3. **Threshold-Based Decision**: If more than 70% of sampled messages match, it considers the chunks similar enough to skip the expensive DP computation.

4. **Modified `compute_dp_upto`**: Now tries the fast heuristic first for large chunks (over 100 messages) before falling back to the full DP algorithm.

Additional optimizations you could consider:

1. **Memoization**: Cache results for frequently compared message pairs.

2. **Early Termination**: Stop the DP computation early if the edit distance exceeds a threshold.

3. **Locality-Sensitive Hashing**: For very large chunks, you could implement a locality-sensitive hashing approach to find similar messages.

4. **Parallel Processing**: For very large chunks, you could split the DP table computation across multiple threads.

5. **Incremental Updates**: Only recompute parts of the DP table that are affected by new messages.

These optimizations should significantly improve performance for large chunks while maintaining reasonable accuracy for diff detection.

---

_**User**_

Sampling defeats the edit distance concept since a single insertion / deletion can lead to a false claim of complete mismatch. I like Memoization and Early Termination -- let's expand on the latter since the former is starightforward.

---

_**Assistant**_

You're absolutely right about the sampling approach - it could lead to false claims of complete mismatch with just a single insertion or deletion shifting all subsequent messages. Let's focus on early termination strategies for the edit distance computation, which can provide significant performance benefits while maintaining accuracy.

Here's how we could implement early termination in the `PrevRun` module:

```ocaml:minidebug_runtime.ml
// ... existing code ...
  let del_cost = 2
  let ins_cost = 2
  let change_cost = 3
  
  (* Maximum edit distance we care about - beyond this, we consider chunks different *)
  let max_edit_distance_threshold = 100
  
  let init_run ?prev_file ?diff_ignore_pattern curr_file =
    let prev_ic = Option.map open_in_bin prev_file in
    let prev_chunk = Option.bind prev_ic load_next_chunk in
    let dp_rows = match prev_chunk with None -> 0 | Some c -> Array.length c.messages in
    let dp_cols =
      1000
      (* Initial size, will grow as needed *)
    in
    let dp_table = Array.make_matrix dp_rows dp_cols (max_int, -1, -1) in
    let curr_oc = open_out_bin (curr_file ^ ".raw") in
    Some
      {
        prev_chunk;
        curr_chunk = Dynarray.create ();
        dp_table;
        last_computed_row = -1;
        last_computed_col = -1;
        optimal_edits = [];
        prev_ic;
        curr_oc;
        diff_ignore_pattern;
      }
// ... existing code ...

  let compute_dp_cell state i j msg =
    if j >= Array.length state.dp_table.(0) then extend_dp_table state;
    let prev_msg = (Option.get state.prev_chunk).messages.(i) in
    let normalized_prev = normalize_message state.diff_ignore_pattern prev_msg in
    let normalized_curr = normalize_message state.diff_ignore_pattern msg in
    let match_cost = if normalized_prev = normalized_curr then 0 else change_cost in
    (* Get costs from previous cells, being careful about overflow *)
    let safe_add a b =
      if a = max_int || b = max_int then max_int
      else if a > max_int - b then max_int
      else a + b
    in

    let above =
      if i > 0 then
        let c, _, _ = state.dp_table.(i - 1).(j) in
        safe_add c del_cost
      else (j * ins_cost) + del_cost
    in
    let left =
      if j > 0 then
        let c, _, _ = state.dp_table.(i).(j - 1) in
        safe_add c ins_cost
      else (i * del_cost) + ins_cost
    in
    let diag =
      if i > 0 && j > 0 then
        let c, _, _ = state.dp_table.(i - 1).(j - 1) in
        safe_add c match_cost
      else match_cost + (i * del_cost) + (j * ins_cost)
    in

    (* Compute minimum cost operation *)
    let min_cost, prev_i, prev_j =
      let costs = [ (above, i - 1, j); (left, i, j - 1); (diag, i - 1, j - 1) ] in
      List.fold_left
        (fun (mc, pi, pj) (c, i', j') -> if c <= mc then (c, i', j') else (mc, pi, pj))
        (max_int, -1, -1) costs
    in
    state.dp_table.(i).(j) <- (min_cost, prev_i, prev_j)

  (* Check if we can terminate early based on minimum possible edit distance *)
  let can_terminate_early state row col =
    (* Check if all rows have at least one cell exceeding threshold *)
    let all_rows_exceed_threshold = ref true in
    
    (* For each row, check if there's any cell with cost below threshold *)
    for i = 0 to row do
      let row_exceeds = ref true in
      for j = 0 to min col (Array.length state.dp_table.(0) - 1) do
        let cost, _, _ = state.dp_table.(i).(j) in
        if cost < max_edit_distance_threshold then begin
          row_exceeds := false;
          break;
        end
      done;
      if not !row_exceeds then begin
        all_rows_exceed_threshold := false;
        break;
      end
    done;
    
    (* If all rows have costs exceeding threshold, we can terminate early *)
    !all_rows_exceed_threshold
  
  let compute_dp_upto state row col =
    (* Early termination flag *)
    let terminated_early = ref false in
    
    (* Compute DP table with potential early termination *)
    for i = state.last_computed_row + 1 to row do
      (* Check for early termination periodically *)
      if i mod 10 = 0 && i > 0 && can_terminate_early state (i-1) col then begin
        terminated_early := true;
        break;
      end;
      
      for j = 0 to col do
        compute_dp_cell state i j (Dynarray.get state.curr_chunk j)
      done
    done;
    
    (* If we didn't terminate early, complete the computation *)
    if not !terminated_early then begin
      for i = 0 to state.last_computed_row do
        for j = state.last_computed_col + 1 to col do
          compute_dp_cell state i j (Dynarray.get state.curr_chunk j)
        done
      done;
      
      state.last_computed_row <- max state.last_computed_row row;
      state.last_computed_col <- max state.last_computed_col col;
      update_optimal_edits state row col
    else begin
      (* If terminated early, mark all as different *)
      state.last_computed_row <- row;
      state.last_computed_col <- col;
      state.optimal_edits <- 
        List.init (col + 1) (fun j -> { edit_type = Insert; curr_index = j })
    end

  (* Optimization: Diagonal band approach for edit distance *)
  let compute_dp_band state row col =
    (* Only compute cells within a band around the diagonal *)
    let band_width = 30 in  (* Adjust based on expected similarity *)
    
    for i = state.last_computed_row + 1 to row do
      (* Determine band boundaries for this row *)
      let j_start = max 0 (i - band_width) in
      let j_end = min col (i + band_width) in
      
      for j = j_start to j_end do
        compute_dp_cell state i j (Dynarray.get state.curr_chunk j)
      done;
      
      (* Check if minimum cost in this row exceeds threshold *)
      let min_cost = ref max_int in
      for j = j_start to j_end do
        let cost, _, _ = state.dp_table.(i).(j) in
        min_cost := min !min_cost cost;
      done;
      
      (* Early termination if minimum cost exceeds threshold *)
      if !min_cost > max_edit_distance_threshold then begin
        state.last_computed_row <- i;
        state.last_computed_col <- col;
        state.optimal_edits <- 
          List.init (col + 1) (fun j -> { edit_type = Insert; curr_index = j });
        (* Early return *)
        return;
      end
    done;
    
    state.last_computed_row <- row;
    state.last_computed_col <- col;
    update_optimal_edits state row col
// ... existing code ...
```

Here are the key optimizations I've added:

1. **Early Termination Threshold**: Added a `max_edit_distance_threshold` constant that defines when we consider chunks too different to continue computing.

2. **Early Termination Check**: Added a `can_terminate_early` function that checks if all rows have edit distances exceeding our threshold, indicating the chunks are too different to be worth comparing in detail.

3. **Modified `compute_dp_upto`**: Now checks for early termination periodically (every 10 rows) to avoid unnecessary computation.

4. **Diagonal Band Approach**: Added a `compute_dp_band` function that only computes cells within a band around the diagonal, which is where the optimal alignment typically lies. This significantly reduces computation for large chunks.

5. **Row-based Early Termination**: In the band approach, we check if the minimum cost in a row exceeds our threshold, allowing for early termination.

These optimizations should provide significant performance improvements for large chunks while maintaining the accuracy of the edit distance calculation. The diagonal band approach is particularly effective for comparing sequences that are expected to have a relatively small number of edits.

Additional considerations:

1. **Adaptive Band Width**: You could make the band width adaptive based on the observed edit distance so far.

2. **Progressive Refinement**: Start with a narrow band and expand it if the edit distance is high.

3. **Checkpointing**: For very large chunks, periodically save the state of the computation to allow resuming if needed.

4. **Sparse DP Table**: For very large chunks with few edits, you could use a sparse representation of the DP table to save memory.

---



---

