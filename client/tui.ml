(** Original Notty render functions - for terminal TUI *)

module Query = Minidebug_client.Query
open Notty
open Notty_unix
module I = Minidebug_client.Interactive
module NI = Notty.I

let sanitize_for_notty = I.sanitize_text

(** Poll for terminal event with timeout. Returns None on timeout. *)
let event_with_timeout term timeout_sec =
  (* Get the input file descriptor from stdin *)
  let stdin_fd = Unix.stdin in
  (* Retry select on EINTR (interrupted system call) *)
  let rec select_with_retry () =
    try
      let ready, _, _ = Unix.select [ stdin_fd ] [] [] timeout_sec in
      if ready = [] then None (* Timeout *) else Some (Term.event term)
      (* Event available *)
    with Unix.Unix_error (Unix.EINTR, _, _) ->
      (* Interrupted by signal (e.g., SIGWINCH on terminal resize) - retry *)
      select_with_retry ()
  in
  select_with_retry ()

(** Render a single line *)
let render_line ~width ~is_selected ~show_times ~margin_width ~search_slots
    ~current_slot:_ ~query:(module Q : Query.S) ~values_first item =
  match item.I.content with
  | Ellipsis { parent_scope_id; start_seq_id; end_seq_id; hidden_count } ->
      (* Render ellipsis placeholder *)
      let scope_id_str = Printf.sprintf "%*d │ " margin_width parent_scope_id in
      let indent = String.make (item.indent_level * 2) ' ' in
      let expansion_mark = "⋯ " in
      let text =
        Printf.sprintf "%s%s(%d hidden entries: seq %d-%d)%s" indent expansion_mark
          hidden_count start_seq_id end_seq_id
          (String.make (item.indent_level * 2) ' ')
      in
      let attr = if is_selected then A.(bg lightblue ++ fg black) else A.(fg (gray 12)) in
      NI.hcat
        [
          NI.string (if is_selected then attr else A.(fg yellow)) scope_id_str;
          NI.string attr text;
        ]
  | RealEntry entry ->
      (* Entry ID margin - use child_scope_id for scopes, scope_id for values *)
      (* Don't display negative IDs (used for boxified/decomposed values) *)
      let display_id =
        match entry.child_scope_id with
        | Some hid when hid >= 0 ->
            Some hid (* This is a scope/header - show its actual scope ID *)
        | Some _ -> None (* Negative child_scope_id - hide it *)
        | None when entry.scope_id >= 0 ->
            Some entry.scope_id (* This is a value - show its parent scope ID *)
        | None -> None (* Negative scope_id - hide it *)
      in
      let scope_id_str =
        match display_id with
        | Some id -> Printf.sprintf "%*d │ " margin_width id
        | None -> String.make (margin_width + 3) ' ' (* Blank margin: spaces + " │ " *)
      in
      let content_width = width - String.length scope_id_str in

      let indent = String.make (item.indent_level * 2) ' ' in

      (* Expansion indicator *)
      let expansion_mark =
        if item.is_expandable then if item.is_expanded then "▼ " else "▶ " else "  "
      in

      (* Entry content *)
      let content =
        match entry.child_scope_id with
        | Some hid when values_first && item.is_expanded -> (
            (* Header/scope in values_first mode: check for single result child to
               combine *)
            let children = Q.get_scope_children ~parent_scope_id:hid in
            let results, _non_results =
              List.partition (fun e -> e.Query.is_result) children
            in
            match results with
            | [ single_result ] ->
                (* Don't combine if result is itself a scope/header (e.g., synthetic
                   scopes from boxify). Only combine simple value results with their
                   parent headers. *)
                if single_result.child_scope_id = None then
                  (* Combine result with header: [type] message => result_data *)
                  let result_data = Option.value ~default:"" single_result.data in
                  let result_msg = single_result.message in
                  let combined_result =
                    if result_msg <> "" && result_msg <> entry.message then
                      Printf.sprintf " => %s = %s" result_msg result_data
                    else Printf.sprintf " => %s" result_data
                  in
                  Printf.sprintf "%s%s[%s] %s%s" indent expansion_mark entry.entry_type
                    entry.message combined_result
                else
                  (* Result has children: normal rendering *)
                  Printf.sprintf "%s%s[%s] %s" indent expansion_mark entry.entry_type
                    entry.message
            | _ ->
                (* Multiple results or no results: normal rendering *)
                (* For synthetic scopes (no location), show data inline with message *)
                let is_synthetic = entry.location = None in
                let display_text =
                  match (entry.message, entry.data, is_synthetic) with
                  | msg, Some data, true when msg <> "" ->
                      Printf.sprintf "%s: %s" msg data
                  | "", Some data, true -> data
                  | msg, _, _ when msg <> "" -> msg
                  | _ -> ""
                in
                Printf.sprintf "%s%s[%s] %s" indent expansion_mark entry.entry_type
                  display_text)
        | Some _ ->
            (* Header/scope - normal rendering *)
            let display_text =
              let message = entry.message in
              let data = Option.value ~default:"" entry.data in
              if message <> "" then message else data
            in
            Printf.sprintf "%s%s[%s] %s" indent expansion_mark entry.entry_type
              display_text
        | None ->
            (* Value *)
            let display_text =
              let message = entry.message in
              let data = Option.value ~default:"" entry.data in
              let is_result = entry.is_result in
              (if message <> "" then message ^ " " else "")
              ^ (if is_result then "=> "
                 else if message <> "" && data <> "" then "= "
                 else "")
              ^ data
            in
            Printf.sprintf "%s  %s" indent display_text
      in

      (* Time *)
      let time_str =
        if show_times then
          match Query.elapsed_time entry with
          | Some elapsed -> Printf.sprintf " <%s>" (Query.format_elapsed_ns elapsed)
          | None -> ""
        else ""
      in

      let full_text = content ^ time_str in
      let truncated =
        let t =
          if I.Utf8.char_count full_text > content_width then
            I.Utf8.truncate full_text (content_width - 3) ^ "..."
          else full_text
        in
        I.sanitize_text t
      in

      (* Get all matching search slots for checkered pattern *)
      let all_matches =
        I.get_all_search_matches ~search_slots ~scope_id:entry.scope_id
          ~seq_id:entry.seq_id
      in

      (* Helper: get color attribute for a slot number *)
      let slot_color = function
        | I.SlotNumber.S1 -> A.(fg green) (* Search slot 1: green *)
        | S2 -> A.(fg cyan) (* Search slot 2: cyan *)
        | S3 -> A.(fg magenta) (* Search slot 3: magenta *)
        | S4 -> A.(fg yellow)
        (* Search slot 4: yellow *)
        (* Search slot 4: yellow *)
      in

      (* Render line with appropriate highlighting *)
      let content_image, margin_image =
        if is_selected then
          (* Selection takes priority - blue background *)
          let attr = A.(bg lightblue ++ fg black) in
          (NI.string attr truncated, NI.string attr scope_id_str)
        else
          match all_matches with
          | [] ->
              (* No match: default (margin still yellow) *)
              (NI.string A.empty truncated, NI.string A.(fg yellow) scope_id_str)
          | [ single_match ] ->
              (* Single match: simple uniform coloring *)
              let attr = slot_color single_match in
              (NI.string attr truncated, NI.string attr scope_id_str)
          | multiple_matches when List.length multiple_matches >= 2 ->
              (* Multiple matches: checkered pattern - split text into segments *)
              let num_matches = List.length multiple_matches in
              let text_len = I.Utf8.char_count truncated in
              (* Create min(num_matches * 2, text_len) segments *)
              let num_segments = min (num_matches * 2) text_len in
              let segment_size = max 1 (text_len / num_segments) in

              (* Build checkered content by alternating colors *)
              let content_segments = ref [] in
              let pos = ref 0 in
              let color_idx = ref 0 in
              while !pos < text_len do
                let remaining = text_len - !pos in
                let seg_len = min segment_size remaining in
                let segment = I.Utf8.sub truncated !pos seg_len in
                let color =
                  slot_color (List.nth multiple_matches (!color_idx mod num_matches))
                in
                content_segments := NI.string color segment :: !content_segments;
                pos := !pos + seg_len;
                color_idx := !color_idx + 1
              done;
              let content_img = NI.hcat (List.rev !content_segments) in

              (* Margin uses first matching color *)
              let margin_color = slot_color (List.hd multiple_matches) in
              let margin_img = NI.string margin_color scope_id_str in

              (content_img, margin_img)
          | _ ->
              (* Fallback (shouldn't happen) *)
              (NI.string A.empty truncated, NI.string A.(fg yellow) scope_id_str)
      in

      NI.hcat [ margin_image; content_image ]

(** Render the full screen *)
let render_screen state ~width ~height =
  let header_height = 2 in
  let footer_height = 2 in
  let content_height = height - header_height - footer_height in

  (* Calculate margin width based on max_scope_id *)
  let margin_width = String.length (string_of_int state.I.max_scope_id) in

  (* Calculate progress indicator - find closest ancestor with positive ID *)
  let current_scope_id =
    if state.cursor >= 0 && state.cursor < Array.length state.visible_items then
      match state.visible_items.(state.cursor).content with
      | Ellipsis { parent_scope_id; _ } -> parent_scope_id
      | RealEntry entry -> (
          (* For scopes, use child_scope_id; for values, use scope_id *)
          let id_to_check =
            match entry.child_scope_id with Some hid -> hid | None -> entry.scope_id
          in
          match I.find_positive_ancestor_id state.query id_to_check with
          | Some id -> id
          | None -> 0)
    else 0
  in
  let progress_pct =
    if state.max_scope_id > 0 then
      float_of_int current_scope_id /. float_of_int state.max_scope_id *. 100.0
    else 0.0
  in

  (* Header *)
  let header =
    let line1 =
      match state.goto_input with
      | Some input ->
          (* Show goto input prompt *)
          NI.string
            A.(fg lightmagenta)
            (sanitize_for_notty (Printf.sprintf "Goto Scope ID: %s_" input))
      | None -> (
          match state.quiet_path_input with
          | Some input ->
              (* Show quiet_path input prompt *)
              NI.string
                A.(fg lightred)
                (sanitize_for_notty (Printf.sprintf "Quiet Path: %s_" input))
          | None -> (
              match state.search_input with
              | Some input ->
                  (* Show search input prompt *)
                  NI.string
                    A.(fg lightyellow)
                    (sanitize_for_notty (Printf.sprintf "Search: %s_" input))
              | None ->
                  (* Show run info and search status *)
                  let search_order_str =
                    match state.search_order with
                    | Query.AscendingIds -> "Asc"
                    | Query.DescendingIds -> "Desc"
                  in
                  let base_info =
                    Printf.sprintf
                      "Items: %d | Times: %s | Values First: %s | Search: %s | Entry: \
                       %d/%d (%.1f%%)"
                      (Array.length state.visible_items)
                      (if state.show_times then "ON" else "OFF")
                      (if state.values_first then "ON" else "OFF")
                      search_order_str current_scope_id state.max_scope_id progress_pct
                  in
                  (* Build chronological status string from event history. Shows searches
                     and quiet path changes in the order they occurred. *)
                  let chronological_status =
                    if state.status_history = [] then ""
                    else
                      let event_strings =
                        List.rev_map
                          (fun event ->
                            match event with
                            | I.SearchEvent (slot_num, search_type) -> (
                                (* Look up current search status *)
                                match I.SlotMap.find_opt slot_num state.search_slots with
                                | Some slot ->
                                    let count = Hashtbl.length slot.results in
                                    let color_name =
                                      match slot_num with
                                      | S1 -> "G"
                                      | S2 -> "C"
                                      | S3 -> "M"
                                      | S4 -> "Y"
                                    in
                                    let count_str =
                                      if !(slot.completed_ref) then
                                        Printf.sprintf "[%d]" count
                                      else Printf.sprintf "[%d...]" count
                                    in
                                    let search_desc =
                                      match search_type with
                                      | RegularSearch term -> sanitize_for_notty term
                                      | ExtractSearch { display_text; _ } ->
                                          sanitize_for_notty display_text
                                    in
                                    Printf.sprintf "%s:%s%s" color_name search_desc
                                      count_str
                                | None ->
                                    (* Slot was cleared/overwritten - shouldn't happen in
                                       normal flow *)
                                    "")
                            | QuietPathEvent qp_opt -> (
                                match qp_opt with
                                | Some qp -> Printf.sprintf "Q:%s" (sanitize_for_notty qp)
                                | None -> "Q:cleared"))
                          state.status_history
                      in
                      let filtered = List.filter (fun s -> s <> "") event_strings in
                      if filtered = [] then "" else " | " ^ String.concat " " filtered
                  in
                  NI.string
                    A.(fg lightcyan)
                    (sanitize_for_notty (base_info ^ chronological_status))))
    in
    NI.vcat [ line1; NI.string A.(fg white) (String.make width '-') ]
  in

  (* Content lines *)
  let visible_start = state.scroll_offset in
  let visible_end =
    min (visible_start + content_height) (Array.length state.visible_items)
  in

  let content_lines = ref [] in
  for i = visible_start to visible_end - 1 do
    let is_selected = i = state.cursor in
    let item = state.visible_items.(i) in
    let line =
      render_line ~width ~is_selected ~show_times:state.show_times ~margin_width
        ~search_slots:state.search_slots ~current_slot:state.current_slot
        ~query:state.query ~values_first:state.values_first item
    in
    content_lines := line :: !content_lines
  done;

  (* Pad if needed *)
  let padding_lines = content_height - (visible_end - visible_start) in
  for _ = 1 to padding_lines do
    content_lines := NI.string A.empty "" :: !content_lines
  done;

  let content = NI.vcat (List.rev !content_lines) in

  (* Footer *)
  let footer =
    let help_text =
      match state.goto_input with
      | Some _ ->
          "[Enter] Goto scope ID | [Esc] Cancel | [Backspace] Delete | [0-9] Type ID"
      | None -> (
          match state.quiet_path_input with
          | Some _ -> "[Enter] Confirm quiet path | [Esc] Cancel | [Backspace] Delete"
          | None -> (
              match state.search_input with
              | Some _ -> "[Enter] Confirm search | [Esc] Cancel | [Backspace] Delete"
              | None ->
                  "[↑/↓] Navigate | [Home/End] First/Last | [PgUp/PgDn] Page | [u/d] \
                   Quarter | [n/N] Next/Prev Match | [m/M] Goto+Expand | [Enter/Space] \
                   Expand | [f] Fold | [/] Search | [g] Goto | [Q] Quiet | [t] Times | \
                   [v] Values | [o] Order | [q] Quit"))
    in
    NI.vcat
      [
        NI.string A.(fg white) (String.make width '-');
        NI.string A.(fg lightcyan) help_text;
      ]
  in

  NI.vcat [ header; content; footer ]

(** Handle key events - converts Notty keys to commands and delegates to handle_command *)
let parse_key state event =
  (* Convert Notty key events to commands, prioritizing input modes *)
  match event with
  | None -> None
  | Some (`Resize _) -> None
  | Some `End -> Some I.Quit
  | Some (`Mouse _) -> None
  | Some (`Paste _) -> None
  | Some (`Key (key : Unescape.key)) -> (
      match state.I.quiet_path_input with
      | Some _ -> (
          match key with
          | `Escape, _ -> Some I.InputEscape
          | `Enter, _ -> Some InputEnter
          | `Backspace, _ -> Some InputBackspace
          | `ASCII c, _ when c >= ' ' && c <= '~' -> Some (InputChar c)
          | _ -> None)
      | None -> (
          match state.search_input with
          | Some _ -> (
              match key with
              | `Escape, _ -> Some InputEscape
              | `Enter, _ -> Some InputEnter
              | `Backspace, _ -> Some InputBackspace
              | `ASCII c, _ when c >= ' ' && c <= '~' -> Some (InputChar c)
              | _ -> None)
          | None -> (
              (* Normal navigation mode *)
              match key with
              | `ASCII 'q', _ | `Escape, _ -> Some Quit
              | `ASCII '/', _ -> Some (BeginSearch None)
              | `ASCII 'Q', _ -> Some (BeginQuietPath None)
              | `ASCII 'g', _ -> Some (BeginGoto None)
              | `Arrow `Up, _ | `ASCII 'k', _ -> Some (Navigate `Up)
              | `Arrow `Down, _ | `ASCII 'j', _ -> Some (Navigate `Down)
              | `Home, _ -> Some (Navigate `Home)
              | `End, _ -> Some (Navigate `End)
              | `Enter, _ | `ASCII ' ', _ -> Some ToggleExpansion
              | `ASCII 'f', _ -> Some Fold
              | `ASCII 't', _ -> Some ToggleTimes
              | `ASCII 'v', _ -> Some ToggleValues
              | `ASCII 'o', _ -> Some ToggleSearchOrder
              | `Page `Up, _ -> Some (Navigate `PageUp)
              | `Page `Down, _ -> Some (Navigate `PageDown)
              | `ASCII 'u', _ -> Some (Navigate `QuarterUp)
              | `ASCII 'd', _ -> Some (Navigate `QuarterDown)
              | `ASCII 'n', _ -> Some SearchNext
              | `ASCII 'N', _ -> Some SearchPrev
              | `ASCII 'm', _ -> Some GotoNextHighlight
              | `ASCII 'M', _ -> Some GotoPrevHighlight
              | _ -> None)))

let create_tui_callbacks () =
  let term = Term.create () in
  let command_stream state = parse_key state @@ event_with_timeout term 0.2 in
  let finalize () = Term.release term in
  let render_screen state ~width ~height =
    let image = render_screen state ~width ~height in
    Term.image term image
  in
  let output_size () = Term.size term in
  (term, command_stream, render_screen, output_size, finalize)
