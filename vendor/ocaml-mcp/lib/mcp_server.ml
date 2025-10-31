open Mcp
open Jsonrpc
open Mcp_sdk

let src = Logs.Src.create "mcp.sdk" ~doc:"mcp.sdk logging"

module Log = (val Logs.src_log src : Logs.LOG)

(* Create a proper JSONRPC error with code and data *)
let create_jsonrpc_error id code message ?data () =
  let error_code = ErrorCode.to_int code in
  let error_data = match data with Some d -> d | None -> `Null in
  create_error ~id ~code:error_code ~message ~data:(Some error_data) ()

(* Process initialize request *)
let handle_initialize server req =
  Log.debug (fun m -> m "Processing initialize request");
  let result =
    match req.JSONRPCMessage.params with
    | Some params ->
        let req_data = Initialize.Request.t_of_yojson params in
        Logs.debug (fun m ->
            m "Client info: %s v%s" req_data.client_info.name
              req_data.client_info.version);
        Log.debug (fun m ->
            m "Client protocol version: %s" req_data.protocol_version);

        (* Create initialize response *)
        let result =
          Initialize.Result.create ~capabilities:(capabilities server)
            ~server_info:
              Implementation.{ name = name server; version = version server }
            ~protocol_version:(protocol_version server)
            ~instructions:
              (Printf.sprintf "This server provides tools for %s." (name server))
            ()
        in
        Initialize.Result.yojson_of_t result
    | None ->
        Log.err (fun m -> m "Missing params for initialize request");
        `Assoc [ ("error", `String "Missing params for initialize request") ]
  in
  Some (create_response ~id:req.id ~result)

(* Process tools/list request *)
let handle_tools_list server (req : JSONRPCMessage.request) =
  Log.debug (fun m -> m "Processing tools/list request");
  let tools_list = Tool.to_rpc_tools_list (tools server) in
  let response =
    Mcp_rpc.ToolsList.create_response ~id:req.id ~tools:tools_list ()
  in
  Some response

(* Process prompts/list request *)
let handle_prompts_list server (req : JSONRPCMessage.request) =
  Log.debug (fun m -> m "Processing prompts/list request");
  let prompts_list = Prompt.to_rpc_prompts_list (prompts server) in
  let response =
    Mcp_rpc.PromptsList.create_response ~id:req.id ~prompts:prompts_list ()
  in
  Some response

(* Process resources/list request *)
let handle_resources_list server (req : JSONRPCMessage.request) =
  Log.debug (fun m -> m "Processing resources/list request");
  let resources_list = Resource.to_rpc_resources_list (resources server) in
  let response =
    Mcp_rpc.ResourcesList.create_response ~id:req.id ~resources:resources_list
      ()
  in
  Some response

(* Process resources/templates/list request *)
let handle_resource_templates_list server (req : JSONRPCMessage.request) =
  Log.debug (fun m -> m "Processing resources/templates/list request");
  let templates_list =
    ResourceTemplate.to_rpc_resource_templates_list (resource_templates server)
  in
  let response =
    Mcp_rpc.ListResourceTemplatesResult.create_response ~id:req.id
      ~resource_templates:templates_list ()
  in
  Some response

(* Utility module for resource template matching *)
module Resource_matcher = struct
  (* Define variants for resource handling result *)
  type resource_match =
    | DirectResource of Resource.t * string list
    | TemplateResource of ResourceTemplate.t * string list
    | NoMatch

  (* Extract parameters from a template URI *)
  let extract_template_vars template_uri uri =
    (* Simple template variable extraction - could be enhanced with regex *)
    let template_parts = String.split_on_char '/' template_uri in
    let uri_parts = String.split_on_char '/' uri in

    if List.length template_parts <> List.length uri_parts then None
    else
      (* Match parts and extract variables *)
      let rec match_parts tparts uparts acc =
        match (tparts, uparts) with
        | [], [] -> Some (List.rev acc)
        | th :: tt, uh :: ut ->
            (* Check if this part is a template variable *)
            if
              String.length th > 2
              && String.get th 0 = '{'
              && String.get th (String.length th - 1) = '}'
            then
              (* Extract variable value and continue *)
              match_parts tt ut (uh :: acc)
            else if th = uh then
              (* Fixed part matches, continue *)
              match_parts tt ut acc
            else
              (* Fixed part doesn't match, fail *)
              None
        | _, _ -> None
      in
      match_parts template_parts uri_parts []

  (* Find a matching resource or template for a URI *)
  let find_match server uri =
    (* Try direct resource match first *)
    match
      List.find_opt
        (fun resource -> resource.Resource.uri = uri)
        (resources server)
    with
    | Some resource -> DirectResource (resource, [])
    | None ->
        (* Try template match next *)
        let templates = resource_templates server in

        (* Try each template to see if it matches *)
        let rec try_templates templates =
          match templates with
          | [] -> NoMatch
          | template :: rest -> (
              match
                extract_template_vars template.ResourceTemplate.uri_template uri
              with
              | Some params -> TemplateResource (template, params)
              | None -> try_templates rest)
        in
        try_templates templates
end

(* Process resources/read request *)
let handle_resources_read server (req : JSONRPCMessage.request) =
  Log.debug (fun m -> m "Processing resources/read request");
  match req.JSONRPCMessage.params with
  | None ->
      Log.err (fun m -> m "Missing params for resources/read request");
      Some
        (create_jsonrpc_error req.id ErrorCode.InvalidParams
           "Missing params for resources/read request" ())
  | Some params -> (
      let req_data = Mcp_rpc.ResourcesRead.Request.t_of_yojson params in
      let uri = req_data.uri in
      Log.debug (fun m -> m "Resource URI: %s" uri);

      (* Find matching resource or template *)
      match Resource_matcher.find_match server uri with
      | Resource_matcher.DirectResource (resource, params) -> (
          (* Create context for this request *)
          let ctx =
            Context.create ?request_id:(Some req.id)
              ?progress_token:req.progress_token
              ~lifespan_context:
                [ ("resources/read", `Assoc [ ("uri", `String uri) ]) ]
              ()
          in

          Log.debug (fun m -> m "Handling direct resource: %s" resource.name);

          (* Call the resource handler *)
          match resource.handler ctx params with
          | Ok content ->
              (* Create text resource content *)
              let mime_type =
                match resource.mime_type with
                | Some mime -> mime
                | None -> "text/plain"
              in
              let text_resource =
                {
                  TextResourceContents.uri;
                  text = content;
                  mime_type = Some mime_type;
                }
              in
              let resource_content =
                Mcp_rpc.ResourcesRead.ResourceContent.TextResource text_resource
              in
              let response =
                Mcp_rpc.ResourcesRead.create_response ~id:req.id
                  ~contents:[ resource_content ] ()
              in
              Some response
          | Error err ->
              Log.err (fun m -> m "Error reading resource: %s" err);
              Some
                (create_jsonrpc_error req.id ErrorCode.InternalError
                   ("Error reading resource: " ^ err)
                   ()))
      | Resource_matcher.TemplateResource (template, params) -> (
          (* Create context for this request *)
          let ctx =
            Context.create ?request_id:(Some req.id)
              ?progress_token:req.progress_token
              ~lifespan_context:
                [ ("resources/read", `Assoc [ ("uri", `String uri) ]) ]
              ()
          in

          Log.debug (fun m ->
              m "Handling resource template: %s with params: [%s]" template.name
                (String.concat ", " params));

          (* Call the template handler *)
          match template.handler ctx params with
          | Ok content ->
              (* Create text resource content *)
              let mime_type =
                match template.mime_type with
                | Some mime -> mime
                | None -> "text/plain"
              in
              let text_resource =
                {
                  TextResourceContents.uri;
                  text = content;
                  mime_type = Some mime_type;
                }
              in
              let resource_content =
                Mcp_rpc.ResourcesRead.ResourceContent.TextResource text_resource
              in
              let response =
                Mcp_rpc.ResourcesRead.create_response ~id:req.id
                  ~contents:[ resource_content ] ()
              in
              Some response
          | Error err ->
              Log.err (fun m -> m "Error reading resource template: %s" err);
              Some
                (create_jsonrpc_error req.id ErrorCode.InternalError
                   ("Error reading resource template: " ^ err)
                   ()))
      | Resource_matcher.NoMatch ->
          Log.err (fun m -> m "Resource not found: %s" uri);
          Some
            (create_jsonrpc_error req.id ErrorCode.InvalidParams
               ("Resource not found: " ^ uri)
               ()))

(* Extract the tool name from params *)
let extract_tool_name params =
  match List.assoc_opt "name" params with
  | Some (`String name) ->
      Log.debug (fun m -> m "Tool name: %s" name);
      Some name
  | _ ->
      Log.err (fun m -> m "Missing or invalid 'name' parameter in tool call");
      None

(* Extract the tool arguments from params *)
let extract_tool_arguments params =
  match List.assoc_opt "arguments" params with
  | Some args ->
      Log.debug (fun m -> m "Tool arguments: %s" (Yojson.Safe.to_string args));
      args
  | _ ->
      Log.debug (fun m ->
          m "No arguments provided for tool call, using empty object");
      `Assoc [] (* Empty arguments is valid *)

(* Execute a tool *)
let execute_tool server ctx name args =
  try
    let tool = List.find (fun t -> t.Tool.name = name) (tools server) in
    Log.debug (fun m -> m "Found tool: %s" name);

    (* Call the tool handler *)
    match tool.handler ctx args with
    | Ok result ->
        Log.debug (fun m -> m "Tool execution succeeded");
        result
    | Error err -> Tool.handle_execution_error err
  with
  | Not_found -> Tool.handle_unknown_tool_error name
  | exn -> Tool.handle_execution_exception exn

(* Convert JSON tool result to RPC content format *)
let json_to_rpc_content json =
  match json with
  | `Assoc fields -> (
      match
        (List.assoc_opt "content" fields, List.assoc_opt "isError" fields)
      with
      | Some (`List content_items), Some (`Bool is_error) ->
          let mcp_content = List.map Mcp.content_of_yojson content_items in
          let rpc_content = Tool.mcp_content_to_rpc_content mcp_content in
          (rpc_content, is_error)
      | _ ->
          (* Fallback for compatibility with older formats *)
          let text = Yojson.Safe.to_string json in
          let text_content = { TextContent.text; annotations = None } in
          ([ Mcp_rpc.ToolsCall.ToolContent.Text text_content ], false))
  | _ ->
      (* Simple fallback for non-object results *)
      let text = Yojson.Safe.to_string json in
      let text_content = { TextContent.text; annotations = None } in
      ([ Mcp_rpc.ToolsCall.ToolContent.Text text_content ], false)

(* Process tools/call request *)
let handle_tools_call server req =
  Log.debug (fun m -> m "Processing tools/call request");
  match req.JSONRPCMessage.params with
  | Some (`Assoc params) -> (
      match extract_tool_name params with
      | Some name ->
          let args = extract_tool_arguments params in

          (* Create context for this request *)
          let ctx =
            Context.create ?request_id:(Some req.id)
              ?progress_token:req.progress_token
              ~lifespan_context:[ ("tools/call", `Assoc params) ]
              ()
          in

          (* Execute the tool *)
          let result_json = execute_tool server ctx name args in

          (* Convert JSON result to RPC format *)
          let content, is_error = json_to_rpc_content result_json in

          (* Create the RPC response *)
          let response =
            Mcp_rpc.ToolsCall.create_response ~id:req.id ~content ~is_error ()
          in

          Some response
      | None ->
          Some
            (create_jsonrpc_error req.id InvalidParams
               "Missing tool name parameter" ()))
  | _ ->
      Log.err (fun m -> m "Invalid params format for tools/call");
      Some
        (create_jsonrpc_error req.id InvalidParams
           "Invalid params format for tools/call" ())

(* Process ping request *)
let handle_ping (req : JSONRPCMessage.request) =
  Log.debug (fun m -> m "Processing ping request");
  Some (create_response ~id:req.JSONRPCMessage.id ~result:(`Assoc []))

(* Handle notifications/initialized *)
let handle_initialized (notif : JSONRPCMessage.notification) =
  Log.debug (fun m ->
      m
        "Client initialization complete - Server is now ready to receive \
         requests\n\
        \ Notification params: %s"
        (match notif.JSONRPCMessage.params with
        | Some p -> Yojson.Safe.to_string p
        | None -> "null"));
  None

(* Process a single message using the MCP SDK *)
let process_message server message =
  try
    Log.debug (fun m ->
        m "Processing message: %s" (Yojson.Safe.to_string message));
    match JSONRPCMessage.t_of_yojson message with
    | JSONRPCMessage.Request req -> (
        Log.debug (fun m ->
            m "Received request with method: %s" (Method.to_string req.meth));
        match req.meth with
        | Method.Initialize -> handle_initialize server req
        | Method.ToolsList -> handle_tools_list server req
        | Method.ToolsCall -> handle_tools_call server req
        | Method.PromptsList -> handle_prompts_list server req
        | Method.ResourcesList -> handle_resources_list server req
        | Method.ResourcesRead -> handle_resources_read server req
        | Method.ResourceTemplatesList ->
            handle_resource_templates_list server req
        | _ ->
            Log.err (fun m ->
                m "Unknown method received: %s" (Method.to_string req.meth));
            Some
              (create_jsonrpc_error req.id ErrorCode.MethodNotFound
                 ("Method not found: " ^ Method.to_string req.meth)
                 ()))
    | JSONRPCMessage.Notification notif -> (
        Log.debug (fun m ->
            m "Received notification with method: %s"
              (Method.to_string notif.meth));
        match notif.meth with
        | Method.Initialized -> handle_initialized notif
        | _ ->
            Log.debug (fun m ->
                m "Ignoring notification: %s" (Method.to_string notif.meth));
            None)
    | JSONRPCMessage.Response _ ->
        Log.err (fun m -> m "Unexpected response message received");
        None
    | JSONRPCMessage.Error _ ->
        Log.err (fun m -> m "Unexpected error message received");
        None
  with
  | Json.Of_json (msg, _) ->
      Log.err (fun m -> m "JSON error: %s" msg);
      (* Can't respond with error because we don't have a request ID *)
      None
  | Yojson.Json_error msg ->
      Log.err (fun m -> m "JSON parse error: %s" msg);
      (* Can't respond with error because we don't have a request ID *)
      None
  | exc ->
      Log.err (fun m ->
          m
            "Exception during message processing: %s\n\
             Backtrace: %s\n\
             Message was: %s"
            (Printexc.to_string exc)
            (Printexc.get_backtrace ())
            (Yojson.Safe.to_string message));
      None

(* Extract a request ID from a potentially malformed message *)
let extract_request_id json =
  try
    match json with
    | `Assoc fields -> (
        match List.assoc_opt "id" fields with
        | Some (`Int id) -> Some (`Int id)
        | Some (`String id) -> Some (`String id)
        | _ -> None)
    | _ -> None
  with _ -> None

(* Handle processing for an input line *)
let process_input_line server line =
  if line = "" then (
    Log.debug (fun m -> m "Empty line received, ignoring");
    None)
  else (
    Log.debug (fun m -> m "Raw input: %s" line);
    try
      let json = Yojson.Safe.from_string line in
      Log.debug (fun m -> m "Successfully parsed JSON");

      (* Process the message *)
      process_message server json
    with Yojson.Json_error msg ->
      Log.err (fun m -> m "Error parsing JSON: %s" msg);
      Log.err (fun m -> m "Input was: %s" line);
      None)

(* Send a response to the client *)
let send_response stdout response =
  let response_json = JSONRPCMessage.yojson_of_t response in
  let response_str = Yojson.Safe.to_string response_json in
  Log.debug (fun m -> m "Sending response: %s" response_str);

  (* Write the response followed by a newline *)
  Eio.Flow.copy_string response_str stdout;
  Eio.Flow.copy_string "\n" stdout

(* Run the MCP server with the given server configuration *)
let callback mcp_server _conn (request : Http.Request.t) body =
  match request.meth with
  | `POST -> (
      Log.debug (fun m -> m "Received POST request");
      let request_body_str =
        Eio.Buf_read.(parse_exn take_all) body ~max_size:max_int
      in
      match process_input_line mcp_server request_body_str with
      | Some mcp_response ->
          let response_json = JSONRPCMessage.yojson_of_t mcp_response in
          let response_str = Yojson.Safe.to_string response_json in
          Log.debug (fun m -> m "Sending MCP response: %s" response_str);
          let headers =
            Http.Header.of_list [ ("Content-Type", "application/json") ]
          in
          Cohttp_eio.Server.respond ~status:`OK ~headers
            ~body:(Cohttp_eio.Body.of_string response_str)
            ()
      | None ->
          Log.debug (fun m -> m "No MCP response needed");
          Cohttp_eio.Server.respond ~status:`No_content
            ~body:(Cohttp_eio.Body.of_string "")
            ())
  | _ ->
      Log.info (fun m ->
          m "Unsupported method: %s" (Http.Method.to_string request.meth));
      Cohttp_eio.Server.respond ~status:`Method_not_allowed
        ~body:(Cohttp_eio.Body.of_string "Only POST is supported")
        ()

let log_warning ex = Logs.warn (fun f -> f "%a" Eio.Exn.pp ex)

(** run the server using http transport *)
let run_server ?(port = 8080) ?(on_error = log_warning) env server =
  let net = Eio.Stdenv.net env in
  let addr = `Tcp (Eio.Net.Ipaddr.V4.loopback, port) in

  Log.info (fun m ->
      m "Starting http MCP server: %s v%s\n(protocol: v%s)" (name server)
        (version server) (protocol_version server));

  Eio.Switch.run @@ fun sw ->
  let server_spec = Cohttp_eio.Server.make ~callback:(callback server) () in

  let server_socket =
    Eio.Net.listen net ~sw ~backlog:128 ~reuse_addr:true addr
  in
  Log.info (fun m -> m "MCP HTTP Server listening on http://localhost:%d" port);

  Cohttp_eio.Server.run server_socket server_spec ~on_error

(** run the server using the stdio transport *)
let run_sdtio_server env server =
  let stdin = Eio.Stdenv.stdin env in
  let stdout = Eio.Stdenv.stdout env in

  Log.info (fun m ->
      m "Starting stdio MCP server: %s v%s (protocol v%s)" (name server)
        (version server) (protocol_version server));

  (* Enable exception backtraces *)
  Printexc.record_backtrace true;

  let buf = Eio.Buf_read.of_flow stdin ~initial_size:100 ~max_size:1_000_000 in

  (* Main processing loop *)
  try
    while true do
      Log.info (fun m -> m "Waiting for message...");
      let line = Eio.Buf_read.line buf in

      (* Process the input and send response if needed *)
      match process_input_line server line with
      | Some response -> send_response stdout response
      | None -> Log.info (fun m -> m "No response needed for this message")
    done
  with
  | End_of_file ->
      Log.debug (fun m -> m "End of file received on stdin");
      ()
  | Eio.Exn.Io _ as exn ->
      (* Only a warning since on Windows, once the client closes the connection, we normally fail with `I/O error while reading: Eio.Io Net Connection_reset Unix_error (Broken pipe, "stub_cstruct_read", "")` *)
      Log.warn (fun m ->
          m "I/O error while reading: %s" (Printexc.to_string exn));
      ()
  | exn ->
      Log.err (fun m ->
          m "Exception while reading: %s" (Printexc.to_string exn));
      ()
