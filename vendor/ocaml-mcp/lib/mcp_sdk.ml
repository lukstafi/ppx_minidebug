open Mcp
open Jsonrpc

(* SDK version *)
let version = "0.1.0"
let src = Logs.Src.create "mcp.sdk" ~doc:"mcp.sdk logging"

module Log = (val Logs.src_log src : Logs.LOG)

(* Context for tools and resources *)
module Context = struct
  type t = {
    request_id : RequestId.t option;
    lifespan_context : (string * Json.t) list;
    progress_token : ProgressToken.t option;
  }

  let create ?request_id ?progress_token ?(lifespan_context = []) () =
    { request_id; lifespan_context; progress_token }

  let get_context_value ctx key = List.assoc_opt key ctx.lifespan_context

  let report_progress ctx value total =
    match (ctx.progress_token, ctx.request_id) with
    | Some token, Some _id ->
        let params =
          `Assoc
            [
              ("progress", `Float value);
              ("total", `Float total);
              ("progressToken", ProgressToken.yojson_of_t token);
            ]
        in
        Some
          (create_notification ~meth:Method.Progress ~params:(Some params) ())
    | _ -> None
end

(* Tools for the MCP server *)
module Tool = struct
  type handler = Context.t -> Json.t -> (Json.t, string) result

  type t = {
    name : string;
    description : string option;
    input_schema : Json.t; (* JSON Schema *)
    handler : handler;
  }

  let create ~name ?description ~input_schema ~handler () =
    { name; description; input_schema; handler }

  let to_json tool =
    let assoc =
      [ ("name", `String tool.name); ("inputSchema", tool.input_schema) ]
    in
    let assoc =
      match tool.description with
      | Some desc -> ("description", `String desc) :: assoc
      | None -> assoc
    in
    `Assoc assoc

  (* Convert to Mcp_rpc.ToolsList.Tool.t *)
  let to_rpc_tool_list_tool (tool : t) =
    Mcp_rpc.ToolsList.Tool.
      {
        name = tool.name;
        description = tool.description;
        input_schema = tool.input_schema;
        annotations = None;
        (* Could be extended to support annotations *)
      }

  (* Convert a list of Tool.t to the format needed for tools/list response *)
  let to_rpc_tools_list tools = List.map to_rpc_tool_list_tool tools

  (* Convert Mcp_rpc.ToolsCall response content to Mcp.content list *)
  let rpc_content_to_mcp_content content =
    List.map
      (function
        | Mcp_rpc.ToolsCall.ToolContent.Text t ->
            Mcp.Text { TextContent.text = t.text; annotations = None }
        | Mcp_rpc.ToolsCall.ToolContent.Image i ->
            Mcp.Image
              {
                ImageContent.mime_type = i.mime_type;
                data = i.data;
                annotations = None;
              }
        | Mcp_rpc.ToolsCall.ToolContent.Audio a ->
            Mcp.Audio
              {
                AudioContent.mime_type = a.mime_type;
                data = a.data;
                annotations = None;
              }
        | Mcp_rpc.ToolsCall.ToolContent.Resource r ->
            (* Create a simple text resource from the embedded resource *)
            let uri =
              match r with
              | { EmbeddedResource.resource = `Text tr; _ } -> tr.uri
              | { EmbeddedResource.resource = `Blob br; _ } -> br.uri
            in
            let text_content =
              match r with
              | { EmbeddedResource.resource = `Text tr; _ } -> tr.text
              | { EmbeddedResource.resource = `Blob br; _ } -> "Binary content"
            in
            let mime_type =
              match r with
              | { EmbeddedResource.resource = `Text tr; _ } -> tr.mime_type
              | { EmbeddedResource.resource = `Blob br; _ } -> br.mime_type
            in
            let text_resource =
              { TextResourceContents.uri; text = text_content; mime_type }
            in
            Mcp.Resource
              {
                EmbeddedResource.resource = `Text text_resource;
                annotations = None;
              })
      content

  (* Convert Mcp.content list to Mcp_rpc.ToolsCall.ToolContent.t list *)
  let mcp_content_to_rpc_content content =
    List.map
      (function
        | Mcp.Text t -> Mcp_rpc.ToolsCall.ToolContent.Text t
        | Mcp.Image img -> Mcp_rpc.ToolsCall.ToolContent.Image img
        | Mcp.Audio aud -> Mcp_rpc.ToolsCall.ToolContent.Audio aud
        | Mcp.Resource res ->
            let resource_data =
              match res.resource with
              | `Text txt -> `Text txt
              | `Blob blob -> `Blob blob
            in
            let resource =
              {
                EmbeddedResource.resource = resource_data;
                annotations = res.annotations;
              }
            in
            Mcp_rpc.ToolsCall.ToolContent.Resource resource)
      content

  (* Create a tool result with content *)
  let create_tool_result content ~is_error =
    `Assoc
      [
        ("content", `List (List.map Mcp.yojson_of_content content));
        ("isError", `Bool is_error);
      ]

  (* Create a tool error result with structured content *)
  let create_error_result error =
    Logs.err (fun m -> m "Error result: %s" error);
    create_tool_result [ Mcp.make_text_content error ] ~is_error:true

  (* Handle tool execution errors *)
  let handle_execution_error err =
    create_error_result (Printf.sprintf "Error executing tool: %s" err)

  (* Handle unknown tool error *)
  let handle_unknown_tool_error name =
    create_error_result (Printf.sprintf "Unknown tool: %s" name)

  (* Handle general tool execution exception *)
  let handle_execution_exception exn =
    create_error_result
      (Printf.sprintf "Internal error: %s" (Printexc.to_string exn))
end

(* Resources for the MCP server *)
module Resource = struct
  type handler = Context.t -> string list -> (string, string) result

  type t = {
    uri : string; (* For resources, this is the exact URI (no variables) *)
    name : string;
    description : string option;
    mime_type : string option;
    handler : handler;
  }

  let create ~uri ~name ?description ?mime_type ~handler () =
    (* Validate that the URI doesn't contain template variables *)
    if String.contains uri '{' || String.contains uri '}' then
      Logs.warn (fun m ->
          m
            "Resource '%s' contains template variables. Consider using \
             add_resource_template instead."
            uri);
    { uri; name; description; mime_type; handler }

  let to_json resource =
    let assoc =
      [ ("uri", `String resource.uri); ("name", `String resource.name) ]
    in
    let assoc =
      match resource.description with
      | Some desc -> ("description", `String desc) :: assoc
      | None -> assoc
    in
    let assoc =
      match resource.mime_type with
      | Some mime -> ("mimeType", `String mime) :: assoc
      | None -> assoc
    in
    `Assoc assoc

  (* Convert to Mcp_rpc.ResourcesList.Resource.t *)
  let to_rpc_resource_list_resource (resource : t) =
    Mcp_rpc.ResourcesList.Resource.
      {
        uri = resource.uri;
        name = resource.name;
        description = resource.description;
        mime_type = resource.mime_type;
        size = None;
        (* Size can be added when we have actual resource content *)
      }

  (* Convert a list of Resource.t to the format needed for resources/list response *)
  let to_rpc_resources_list resources =
    List.map to_rpc_resource_list_resource resources
end

(* Prompts for the MCP server *)
module Prompt = struct
  type argument = {
    name : string;
    description : string option;
    required : bool;
  }

  type message = { role : Role.t; content : content }

  type handler =
    Context.t -> (string * string) list -> (message list, string) result

  type t = {
    name : string;
    description : string option;
    arguments : argument list;
    handler : handler;
  }

  let create ~name ?description ?(arguments = []) ~handler () =
    { name; description; arguments; handler }

  let create_argument ~name ?description ?(required = false) () =
    { name; description; required }

  let to_json prompt =
    let assoc = [ ("name", `String prompt.name) ] in
    let assoc =
      match prompt.description with
      | Some desc -> ("description", `String desc) :: assoc
      | None -> assoc
    in
    let assoc =
      if prompt.arguments <> [] then
        let args =
          List.map
            (fun (arg : argument) ->
              let arg_assoc = [ ("name", `String arg.name) ] in
              let arg_assoc =
                match arg.description with
                | Some desc -> ("description", `String desc) :: arg_assoc
                | None -> arg_assoc
              in
              let arg_assoc =
                if arg.required then ("required", `Bool true) :: arg_assoc
                else arg_assoc
              in
              `Assoc arg_assoc)
            prompt.arguments
        in
        ("arguments", `List args) :: assoc
      else assoc
    in
    `Assoc assoc

  (* Convert argument to Mcp_rpc.PromptsList.PromptArgument.t *)
  let argument_to_rpc_prompt_argument (arg : argument) =
    Mcp_rpc.PromptsList.PromptArgument.
      {
        name = arg.name;
        description = arg.description;
        required = arg.required;
      }

  (* Convert to Mcp_rpc.PromptsList.Prompt.t *)
  let to_rpc_prompt_list_prompt (prompt : t) =
    Mcp_rpc.PromptsList.Prompt.
      {
        name = prompt.name;
        description = prompt.description;
        arguments = List.map argument_to_rpc_prompt_argument prompt.arguments;
      }

  (* Convert a list of Prompt.t to the format needed for prompts/list response *)
  let to_rpc_prompts_list prompts = List.map to_rpc_prompt_list_prompt prompts

  (* Convert message to Mcp_rpc.PromptMessage.t *)
  let message_to_rpc_prompt_message msg =
    { PromptMessage.role = msg.role; PromptMessage.content = msg.content }

  (* Convert a list of messages to the format needed for prompts/get response *)
  let messages_to_rpc_prompt_messages messages =
    List.map message_to_rpc_prompt_message messages
end

let make_tool_schema properties required =
  let props =
    List.map
      (fun (name, schema_type, description) ->
        ( name,
          `Assoc
            [
              ("type", `String schema_type); ("description", `String description);
            ] ))
      properties
  in
  let required_json = `List (List.map (fun name -> `String name) required) in
  `Assoc
    [
      ("type", `String "object");
      ("properties", `Assoc props);
      ("required", required_json);
    ]

(* Resource Templates for the MCP server *)
module ResourceTemplate = struct
  type handler = Context.t -> string list -> (string, string) result

  type t = {
    uri_template : string;
    name : string;
    description : string option;
    mime_type : string option;
    handler : handler;
  }

  let create ~uri_template ~name ?description ?mime_type ~handler () =
    { uri_template; name; description; mime_type; handler }

  let to_json resource_template =
    let assoc =
      [
        ("uriTemplate", `String resource_template.uri_template);
        ("name", `String resource_template.name);
      ]
    in
    let assoc =
      match resource_template.description with
      | Some desc -> ("description", `String desc) :: assoc
      | None -> assoc
    in
    let assoc =
      match resource_template.mime_type with
      | Some mime -> ("mimeType", `String mime) :: assoc
      | None -> assoc
    in
    `Assoc assoc

  (* Convert to Mcp_rpc.ResourceTemplatesList.ResourceTemplate.t *)
  let to_rpc_resource_template (template : t) =
    Mcp_rpc.ListResourceTemplatesResult.ResourceTemplate.
      {
        uri_template = template.uri_template;
        name = template.name;
        description = template.description;
        mime_type = template.mime_type;
      }

  (* Convert a list of ResourceTemplate.t to the format needed for resources/templates/list response *)
  let to_rpc_resource_templates_list templates =
    List.map to_rpc_resource_template templates
end

(* Main server type *)
type server = {
  name : string;
  version : string;
  protocol_version : string;
  lifespan_context : (string * Json.t) list;
  mutable capabilities : Json.t;
  mutable tools : Tool.t list;
  mutable resources : Resource.t list;
  mutable resource_templates : ResourceTemplate.t list;
  mutable prompts : Prompt.t list;
}

let name { name; _ } = name
let version { version; _ } = version
let capabilities { capabilities; _ } = capabilities
let lifespan_context { lifespan_context; _ } = lifespan_context
let protocol_version { protocol_version; _ } = protocol_version
let tools { tools; _ } = tools
let resources { resources; _ } = resources
let resource_templates { resource_templates; _ } = resource_templates
let prompts { prompts; _ } = prompts

(* Create a new server *)
let create_server ~name ?(version = "0.1.0") ?(protocol_version = "2024-11-05")
    () =
  {
    name;
    version;
    protocol_version;
    capabilities = `Assoc [];
    tools = [];
    resources = [];
    resource_templates = [];
    prompts = [];
    lifespan_context = [];
  }

(* Default capabilities for the server *)
let default_capabilities ?(with_tools = true) ?(with_resources = false)
    ?(with_resource_templates = false) ?(with_prompts = false) () =
  let caps = [] in
  let caps =
    if with_tools then ("tools", `Assoc [ ("listChanged", `Bool true) ]) :: caps
    else caps
  in
  let caps =
    if with_resources then
      ( "resources",
        `Assoc [ ("listChanged", `Bool true); ("subscribe", `Bool false) ] )
      :: caps
    else if not with_resources then
      ( "resources",
        `Assoc [ ("listChanged", `Bool false); ("subscribe", `Bool false) ] )
      :: caps
    else caps
  in
  let caps =
    if with_resource_templates then
      ("resourceTemplates", `Assoc [ ("listChanged", `Bool true) ]) :: caps
    else if not with_resource_templates then
      ("resourceTemplates", `Assoc [ ("listChanged", `Bool false) ]) :: caps
    else caps
  in
  let caps =
    if with_prompts then
      ("prompts", `Assoc [ ("listChanged", `Bool true) ]) :: caps
    else if not with_prompts then
      ("prompts", `Assoc [ ("listChanged", `Bool false) ]) :: caps
    else caps
  in
  `Assoc caps

(* Register a tool *)
let register_tool server tool =
  server.tools <- tool :: server.tools;
  tool

(* Create and register a tool in one step *)
let add_tool server ~name ?description ?(schema_properties = [])
    ?(schema_required = []) handler =
  let input_schema = make_tool_schema schema_properties schema_required in
  let handler' ctx args =
    try Ok (handler args) with exn -> Error (Printexc.to_string exn)
  in
  let tool =
    Tool.create ~name ?description ~input_schema ~handler:handler' ()
  in
  register_tool server tool

(* Register a resource *)
let register_resource server resource =
  server.resources <- resource :: server.resources;
  resource

(* Create and register a resource in one step *)
let add_resource server ~uri ~name ?description ?mime_type handler =
  let handler' _ctx params =
    try Ok (handler params) with exn -> Error (Printexc.to_string exn)
  in
  let resource =
    Resource.create ~uri ~name ?description ?mime_type ~handler:handler' ()
  in
  register_resource server resource

(* Register a resource template *)
let register_resource_template server template =
  server.resource_templates <- template :: server.resource_templates;
  template

(* Create and register a resource template in one step *)
let add_resource_template server ~uri_template ~name ?description ?mime_type
    handler =
  let handler' _ctx params =
    try Ok (handler params) with exn -> Error (Printexc.to_string exn)
  in
  let template =
    ResourceTemplate.create ~uri_template ~name ?description ?mime_type
      ~handler:handler' ()
  in
  register_resource_template server template

(* Register a prompt *)
let register_prompt server prompt =
  server.prompts <- prompt :: server.prompts;
  prompt

(* Create and register a prompt in one step *)
let add_prompt server ~name ?description ?(arguments = []) handler =
  let prompt_args =
    List.map
      (fun (name, desc, required) ->
        Prompt.create_argument ~name ?description:desc ~required ())
      arguments
  in
  let handler' _ctx args =
    try Ok (handler args) with exn -> Error (Printexc.to_string exn)
  in
  let prompt =
    Prompt.create ~name ?description ~arguments:prompt_args ~handler:handler' ()
  in
  register_prompt server prompt

(* Set server capabilities *)
let set_capabilities server capabilities = server.capabilities <- capabilities

(* Configure server with default capabilities based on registered components *)
let configure_server server ?with_tools ?with_resources ?with_resource_templates
    ?with_prompts () =
  let with_tools =
    match with_tools with Some b -> b | None -> server.tools <> []
  in
  let with_resources =
    match with_resources with Some b -> b | None -> server.resources <> []
  in
  let with_resource_templates =
    match with_resource_templates with
    | Some b -> b
    | None -> server.resource_templates <> []
  in
  let with_prompts =
    match with_prompts with Some b -> b | None -> server.prompts <> []
  in
  let capabilities =
    default_capabilities ~with_tools ~with_resources ~with_resource_templates
      ~with_prompts ()
  in
  set_capabilities server capabilities;
  server
