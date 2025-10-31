(** MCP SDK - Model Context Protocol SDK for OCaml *)

open Mcp
open Jsonrpc

val version : string
(** SDK version *)

(** Context for tools and resources *)
module Context : sig
  type t

  val create :
    ?request_id:RequestId.t ->
    ?progress_token:ProgressToken.t ->
    ?lifespan_context:(string * Json.t) list ->
    unit ->
    t

  val get_context_value : t -> string -> Json.t option
  val report_progress : t -> float -> float -> JSONRPCMessage.t option
end

(** Tools for the MCP server *)
module Tool : sig
  type handler = Context.t -> Json.t -> (Json.t, string) result

  type t = {
    name : string;
    description : string option;
    input_schema : Json.t;
    handler : handler;
  }

  val create :
    name:string ->
    ?description:string ->
    input_schema:Json.t ->
    handler:handler ->
    unit ->
    t

  val to_json : t -> Json.t

  val to_rpc_tool_list_tool : t -> Mcp_rpc.ToolsList.Tool.t
  (** Convert to Mcp_rpc.ToolsList.Tool.t *)

  val to_rpc_tools_list : t list -> Mcp_rpc.ToolsList.Tool.t list
  (** Convert a list of Tool.t to the format needed for tools/list response *)

  val rpc_content_to_mcp_content :
    Mcp_rpc.ToolsCall.ToolContent.t list -> Mcp.content list
  (** Convert Mcp_rpc.ToolsCall response content to Mcp.content list *)

  val mcp_content_to_rpc_content :
    Mcp.content list -> Mcp_rpc.ToolsCall.ToolContent.t list
  (** Convert Mcp.content list to Mcp_rpc.ToolsCall.ToolContent.t list *)

  val create_tool_result : Mcp.content list -> is_error:bool -> Json.t
  (** Create a tool result with content *)

  val create_error_result : string -> Json.t
  (** Create a tool error result with structured content *)

  val handle_execution_error : string -> Json.t
  (** Handle tool execution errors *)

  val handle_unknown_tool_error : string -> Json.t
  (** Handle unknown tool error *)

  val handle_execution_exception : exn -> Json.t
  (** Handle general tool execution exception *)
end

(** Resources for the MCP server *)
module Resource : sig
  type handler = Context.t -> string list -> (string, string) result

  type t = {
    uri : string;
    name : string;
    description : string option;
    mime_type : string option;
    handler : handler;
  }

  val create :
    uri:string ->
    name:string ->
    ?description:string ->
    ?mime_type:string ->
    handler:handler ->
    unit ->
    t

  val to_json : t -> Json.t

  val to_rpc_resource_list_resource : t -> Mcp_rpc.ResourcesList.Resource.t
  (** Convert to Mcp_rpc.ResourcesList.Resource.t *)

  val to_rpc_resources_list : t list -> Mcp_rpc.ResourcesList.Resource.t list
  (** Convert a list of Resource.t to the format needed for resources/list
      response *)
end

(** Resource Templates for the MCP server *)
module ResourceTemplate : sig
  type handler = Context.t -> string list -> (string, string) result

  type t = {
    uri_template : string;
    name : string;
    description : string option;
    mime_type : string option;
    handler : handler;
  }

  val create :
    uri_template:string ->
    name:string ->
    ?description:string ->
    ?mime_type:string ->
    handler:handler ->
    unit ->
    t

  val to_json : t -> Json.t

  val to_rpc_resource_template :
    t -> Mcp_rpc.ListResourceTemplatesResult.ResourceTemplate.t
  (** Convert to Mcp_rpc.ResourceTemplatesList.ResourceTemplate.t *)

  val to_rpc_resource_templates_list :
    t list -> Mcp_rpc.ListResourceTemplatesResult.ResourceTemplate.t list
  (** Convert a list of ResourceTemplate.t to the format needed for
      resources/templates/list response *)
end

(** Prompts for the MCP server *)
module Prompt : sig
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

  val create :
    name:string ->
    ?description:string ->
    ?arguments:argument list ->
    handler:handler ->
    unit ->
    t

  val create_argument :
    name:string -> ?description:string -> ?required:bool -> unit -> argument

  val to_json : t -> Json.t

  val argument_to_rpc_prompt_argument :
    argument -> Mcp_rpc.PromptsList.PromptArgument.t
  (** Convert argument to Mcp_rpc.PromptsList.PromptArgument.t *)

  val to_rpc_prompt_list_prompt : t -> Mcp_rpc.PromptsList.Prompt.t
  (** Convert to Mcp_rpc.PromptsList.Prompt.t *)

  val to_rpc_prompts_list : t list -> Mcp_rpc.PromptsList.Prompt.t list
  (** Convert a list of Prompt.t to the format needed for prompts/list response
  *)

  val message_to_rpc_prompt_message : message -> PromptMessage.t
  (** Convert message to Mcp_rpc.PromptMessage.t *)

  val messages_to_rpc_prompt_messages : message list -> PromptMessage.t list
  (** Convert a list of messages to the format needed for prompts/get response
  *)
end

type server
(** Main server type *)

val name : server -> string
val version : server -> string
val protocol_version : server -> string
val capabilities : server -> Json.t
val tools : server -> Tool.t list
val resources : server -> Resource.t list
val resource_templates : server -> ResourceTemplate.t list
val prompts : server -> Prompt.t list

val create_server :
  name:string -> ?version:string -> ?protocol_version:string -> unit -> server
(** Create a new server *)

val default_capabilities :
  ?with_tools:bool ->
  ?with_resources:bool ->
  ?with_resource_templates:bool ->
  ?with_prompts:bool ->
  unit ->
  Json.t
(** Default capabilities for the server *)

val add_tool :
  server ->
  name:string ->
  ?description:string ->
  ?schema_properties:(string * string * string) list ->
  ?schema_required:string list ->
  (Json.t -> Json.t) ->
  Tool.t
(** Create and register a tool in one step *)

val add_resource :
  server ->
  uri:string ->
  name:string ->
  ?description:string ->
  ?mime_type:string ->
  (string list -> string) ->
  Resource.t
(** Create and register a resource in one step *)

val add_resource_template :
  server ->
  uri_template:string ->
  name:string ->
  ?description:string ->
  ?mime_type:string ->
  (string list -> string) ->
  ResourceTemplate.t
(** Create and register a resource template in one step *)

val add_prompt :
  server ->
  name:string ->
  ?description:string ->
  ?arguments:(string * string option * bool) list ->
  ((string * string) list -> Prompt.message list) ->
  Prompt.t
(** Create and register a prompt in one step *)

val configure_server :
  server ->
  ?with_tools:bool ->
  ?with_resources:bool ->
  ?with_resource_templates:bool ->
  ?with_prompts:bool ->
  unit ->
  server
(** Configure server with default capabilities based on registered components *)

val make_tool_schema : (string * string * string) list -> string list -> Json.t
