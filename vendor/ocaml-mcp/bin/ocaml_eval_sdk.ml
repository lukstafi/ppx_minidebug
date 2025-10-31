open Mcp_sdk
open Mcp_rpc

(* Set up the formatter for capturing evaluation output *)
let capture_output f =
  let buffer = Buffer.create 1024 in
  let fmt = Format.formatter_of_buffer buffer in
  let result = f fmt in
  Format.pp_print_flush fmt ();
  (result, Buffer.contents buffer)

(* Helper for extracting string value from JSON *)
let get_string_param json name =
  match json with
  | `Assoc fields -> (
      match List.assoc_opt name fields with
      | Some (`String value) -> value
      | _ -> failwith (Printf.sprintf "Missing or invalid parameter: %s" name))
  | _ -> failwith "Expected JSON object"

(* Initialize the OCaml toploop with standard libraries *)
let initialize_toploop () =
  (* Initialize the toplevel environment *)
  Toploop.initialize_toplevel_env ();

  (* Set up the toplevel as if using the standard OCaml REPL *)
  Clflags.nopervasives := false;
  Clflags.real_paths := true;
  Clflags.recursive_types := false;
  Clflags.strict_sequence := false;
  Clflags.applicative_functors := true;

  (* Return success message *)
  "OCaml evaluation environment initialized"

(* Evaluate an OCaml toplevel phrase *)
let evaluate_phrase phrase =
  (* Parse the input text as a toplevel phrase *)
  let lexbuf = Lexing.from_string phrase in

  (* Capture both success/failure status and output *)
  try
    let parsed_phrase = !Toploop.parse_toplevel_phrase lexbuf in
    let success, output =
      capture_output (fun fmt -> Toploop.execute_phrase true fmt parsed_phrase)
    in

    (* Return structured result with status and captured output *)
    if success then
      `Assoc [ ("success", `Bool true); ("output", `String output) ]
    else
      `Assoc
        [
          ("success", `Bool false);
          ("error", `String "Execution failed");
          ("output", `String output);
        ]
  with e ->
    (* Handle parsing or other errors with more detailed messages *)
    let error_msg =
      match e with
      | Syntaxerr.Error err ->
          let msg =
            match err with
            | Syntaxerr.Unclosed _ -> "Syntax error: Unclosed delimiter"
            | Syntaxerr.Expecting _ ->
                "Syntax error: Expecting a different token"
            | Syntaxerr.Not_expecting _ -> "Syntax error: Unexpected token"
            | Syntaxerr.Applicative_path _ ->
                "Syntax error: Invalid applicative path"
            | Syntaxerr.Variable_in_scope _ -> "Syntax error: Variable in scope"
            | Syntaxerr.Other _ -> "Syntax error"
            | _ -> "Syntax error (unknown kind)"
          in
          msg
      | Lexer.Error (err, _) ->
          let msg =
            match err with
            | Lexer.Illegal_character _ -> "Lexer error: Illegal character"
            | Lexer.Illegal_escape _ -> "Lexer error: Illegal escape sequence"
            | Lexer.Unterminated_comment _ ->
                "Lexer error: Unterminated comment"
            | Lexer.Unterminated_string -> "Lexer error: Unterminated string"
            | Lexer.Unterminated_string_in_comment _ ->
                "Lexer error: Unterminated string in comment"
            | Lexer.Invalid_literal _ -> "Lexer error: Invalid literal"
            | _ -> "Lexer error (unknown kind)"
          in
          msg
      | _ -> Printexc.to_string e
    in
    `Assoc [ ("success", `Bool false); ("error", `String error_msg) ]

(* Create evaluation server *)
let server =
  create_server ~name:"OCaml Evaluation Server" ~version:"0.1.0" ()
  |> fun server ->
  (* Set default capabilities *)
  configure_server server ~with_tools:true ()

(* Toplevel environment state management *)
let toplevel_initialized = ref false

(* Initialize OCaml toplevel on first use *)
let ensure_toploop_initialized () =
  if not !toplevel_initialized then
    let _ = initialize_toploop () in
    toplevel_initialized := true

(* Register eval tool *)
let _ =
  add_tool server ~name:"ocaml_eval"
    ~description:"Evaluates OCaml toplevel phrases and returns the result"
    ~schema_properties:[ ("code", "string", "OCaml code to evaluate") ]
    ~schema_required:[ "code" ]
    (fun args ->
      ensure_toploop_initialized ();

      try
        (* Extract code parameter *)
        let code = get_string_param args "code" in

        (* Execute the code *)
        let result = evaluate_phrase code in

        (* Return formatted result *)
        let success =
          match result with
          | `Assoc fields -> (
              match List.assoc_opt "success" fields with
              | Some (`Bool true) -> true
              | _ -> false)
          | _ -> false
        in

        let output =
          match result with
          | `Assoc fields -> (
              match List.assoc_opt "output" fields with
              | Some (`String s) -> s
              | _ -> (
                  match List.assoc_opt "error" fields with
                  | Some (`String s) -> s
                  | _ -> "Unknown result"))
          | _ -> "Unknown result"
        in

        (* Create a tool result with colorized output *)
        Tool.create_tool_result
          [ Mcp.make_text_content output ]
          ~is_error:(not success)
      with Failure msg ->
        Logs.err (fun m -> m "Error in OCaml eval tool: %s" msg);
        Tool.create_tool_result
          [ Mcp.make_text_content (Printf.sprintf "Error: %s" msg) ]
          ~is_error:true)

(* Run the server with the default scheduler *)
let () =
  Logs.set_reporter (Logs.format_reporter ());
  Eio_main.run @@ fun env -> Mcp_server.run_server env server
