open Mcp
open Mcp_sdk

(* Helper for extracting string value from JSON *)
let get_string_param json name =
  match json with
  | `Assoc fields -> (
      match List.assoc_opt name fields with
      | Some (`String value) -> value
      | _ ->
          raise
            (Failure (Printf.sprintf "Missing or invalid parameter: %s" name)))
  | _ -> raise (Failure "Expected JSON object")

(* Create a server *)
let server =
  create_server ~name:"OCaml MCP Capitalizer" ~version:"0.1.0"
    ~protocol_version:"2024-11-05" ()
  |> fun server ->
  (* Set default capabilities *)
  configure_server server ~with_tools:true ~with_resources:true
    ~with_prompts:true ()

(* Define and register a capitalize tool *)
let _ =
  add_tool server ~name:"capitalize"
    ~description:"Capitalizes the provided text"
    ~schema_properties:[ ("text", "string", "The text to capitalize") ]
    ~schema_required:[ "text" ]
    (fun args ->
      try
        let text = get_string_param args "text" in
        let capitalized_text = String.uppercase_ascii text in
        TextContent.yojson_of_t
          TextContent.{ text = capitalized_text; annotations = None }
      with Failure msg ->
        Logs.err (fun m -> m "Error in capitalize tool: %s" msg);
        TextContent.yojson_of_t
          TextContent.
            { text = Printf.sprintf "Error: %s" msg; annotations = None })

(* Define and register a resource template example *)
let _ =
  add_resource_template server ~uri_template:"greeting://{name}"
    ~name:"Greeting" ~description:"Get a greeting for a name"
    ~mime_type:"text/plain" (fun params ->
      match params with
      | [ name ] ->
          Printf.sprintf "Hello, %s! Welcome to the OCaml MCP server." name
      | _ -> "Hello, world! Welcome to the OCaml MCP server.")

(* Define and register a prompt example *)
let _ =
  add_prompt server ~name:"capitalize-prompt"
    ~description:"A prompt to help with text capitalization"
    ~arguments:[ ("text", Some "The text to be capitalized", true) ]
    (fun args ->
      let text =
        try List.assoc "text" args with Not_found -> "No text provided"
      in
      [
        Prompt.
          {
            role = `User;
            content =
              Mcp.make_text_content
                "Please help me capitalize the following text:";
          };
        Prompt.{ role = `User; content = Mcp.make_text_content text };
        Prompt.
          {
            role = `Assistant;
            content = Mcp.make_text_content "Here's the capitalized version:";
          };
        Prompt.
          {
            role = `Assistant;
            content = Mcp.make_text_content (String.uppercase_ascii text);
          };
      ])

let () =
  Logs.set_reporter (Logs.format_reporter ());
  Eio_main.run @@ fun env -> Mcp_server.run_server env server
