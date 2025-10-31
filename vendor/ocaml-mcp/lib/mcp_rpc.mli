(** Mcp_message - High-level RPC message definitions for Model Context Protocol
*)

open Mcp
open Jsonrpc

(** Resources/List - Request to list available resources *)
module ResourcesList : sig
  (** Request parameters *)
  module Request : sig
    type t = { cursor : Cursor.t option  (** Optional pagination cursor *) }

    include Json.Jsonable.S with type t := t
  end

  (** Resource definition *)
  module Resource : sig
    type t = {
      uri : string;  (** Unique identifier for the resource *)
      name : string;  (** Human-readable name *)
      description : string option;  (** Optional description *)
      mime_type : string option;  (** Optional MIME type *)
      size : int option;  (** Optional size in bytes *)
    }

    include Json.Jsonable.S with type t := t
  end

  (** Response result *)
  module Response : sig
    type t = {
      resources : Resource.t list;  (** List of available resources *)
      next_cursor : Cursor.t option;  (** Optional cursor for the next page *)
    }

    include Json.Jsonable.S with type t := t
  end

  val create_request :
    ?cursor:Cursor.t -> ?id:RequestId.t -> unit -> JSONRPCMessage.t
  (** Create a resources/list request *)

  val create_response :
    id:RequestId.t ->
    resources:Resource.t list ->
    ?next_cursor:Cursor.t ->
    unit ->
    JSONRPCMessage.t
  (** Create a resources/list response *)
end

(** Resources/Templates/List - Request to list available resource templates *)
module ListResourceTemplatesRequest : sig
  type t = { cursor : Cursor.t option  (** Optional pagination cursor *) }

  include Json.Jsonable.S with type t := t
end

(** Resources/Templates/List - Response with resource templates *)
module ListResourceTemplatesResult : sig
  (** Resource Template definition *)
  module ResourceTemplate : sig
    type t = {
      uri_template : string;  (** URI template for the resource *)
      name : string;  (** Human-readable name *)
      description : string option;  (** Optional description *)
      mime_type : string option;  (** Optional MIME type *)
    }

    include Json.Jsonable.S with type t := t
  end

  type t = {
    resource_templates : ResourceTemplate.t list;
        (** List of available resource templates *)
    next_cursor : Cursor.t option;  (** Optional cursor for the next page *)
  }

  include Json.Jsonable.S with type t := t

  val create_request :
    ?cursor:Cursor.t -> ?id:RequestId.t -> unit -> JSONRPCMessage.t
  (** Create a resources/templates/list request *)

  val create_response :
    id:RequestId.t ->
    resource_templates:ResourceTemplate.t list ->
    ?next_cursor:Cursor.t ->
    unit ->
    JSONRPCMessage.t
  (** Create a resources/templates/list response *)
end

(** Resources/Read - Request to read resource contents *)
module ResourcesRead : sig
  (** Request parameters *)
  module Request : sig
    type t = { uri : string  (** URI of the resource to read *) }

    include Json.Jsonable.S with type t := t
  end

  (** Resource content *)
  module ResourceContent : sig
    type t =
      | TextResource of TextResourceContents.t  (** Text content *)
      | BlobResource of BlobResourceContents.t  (** Binary content *)

    include Json.Jsonable.S with type t := t
  end

  (** Response result *)
  module Response : sig
    type t = {
      contents : ResourceContent.t list;  (** List of resource contents *)
    }

    include Json.Jsonable.S with type t := t
  end

  val create_request : uri:string -> ?id:RequestId.t -> unit -> JSONRPCMessage.t
  (** Create a resources/read request *)

  val create_response :
    id:RequestId.t ->
    contents:ResourceContent.t list ->
    unit ->
    JSONRPCMessage.t
  (** Create a resources/read response *)
end

(** Tools/List - Request to list available tools *)
module ToolsList : sig
  (** Request parameters *)
  module Request : sig
    type t = { cursor : Cursor.t option  (** Optional pagination cursor *) }

    include Json.Jsonable.S with type t := t
  end

  (** Tool definition *)
  module Tool : sig
    type t = {
      name : string;  (** Unique identifier for the tool *)
      description : string option;  (** Human-readable description *)
      input_schema : Json.t;  (** JSON Schema defining expected parameters *)
      annotations : Json.t option;
          (** Optional properties describing tool behavior *)
    }

    include Json.Jsonable.S with type t := t
  end

  (** Response result *)
  module Response : sig
    type t = {
      tools : Tool.t list;  (** List of available tools *)
      next_cursor : Cursor.t option;  (** Optional cursor for the next page *)
    }

    include Json.Jsonable.S with type t := t
  end

  val create_request :
    ?cursor:Cursor.t -> ?id:RequestId.t -> unit -> JSONRPCMessage.t
  (** Create a tools/list request *)

  val create_response :
    id:RequestId.t ->
    tools:Tool.t list ->
    ?next_cursor:Cursor.t ->
    unit ->
    JSONRPCMessage.t
  (** Create a tools/list response *)
end

(** Tools/Call - Request to invoke a tool *)
module ToolsCall : sig
  (** Request parameters *)
  module Request : sig
    type t = {
      name : string;  (** Name of the tool to call *)
      arguments : Json.t;  (** Arguments for the tool invocation *)
    }

    include Json.Jsonable.S with type t := t
  end

  (** Tool content *)
  module ToolContent : sig
    type t =
      | Text of TextContent.t  (** Text content *)
      | Image of ImageContent.t  (** Image content *)
      | Audio of AudioContent.t  (** Audio content *)
      | Resource of EmbeddedResource.t  (** Resource content *)

    include Json.Jsonable.S with type t := t
  end

  (** Response result *)
  module Response : sig
    type t = {
      content : ToolContent.t list;
          (** List of content items returned by the tool *)
      is_error : bool;  (** Whether the result represents an error *)
    }

    include Json.Jsonable.S with type t := t
  end

  val create_request :
    name:string ->
    arguments:Json.t ->
    ?id:RequestId.t ->
    unit ->
    JSONRPCMessage.t
  (** Create a tools/call request *)

  val create_response :
    id:RequestId.t ->
    content:ToolContent.t list ->
    is_error:bool ->
    unit ->
    JSONRPCMessage.t
  (** Create a tools/call response *)
end

(** Prompts/List - Request to list available prompts *)
module PromptsList : sig
  (** Prompt argument *)
  module PromptArgument : sig
    type t = {
      name : string;  (** Name of the argument *)
      description : string option;  (** Description of the argument *)
      required : bool;  (** Whether the argument is required *)
    }

    include Json.Jsonable.S with type t := t
  end

  (** Prompt definition *)
  module Prompt : sig
    type t = {
      name : string;  (** Unique identifier for the prompt *)
      description : string option;  (** Human-readable description *)
      arguments : PromptArgument.t list;  (** Arguments for customization *)
    }

    include Json.Jsonable.S with type t := t
  end

  (** Request parameters *)
  module Request : sig
    type t = { cursor : Cursor.t option  (** Optional pagination cursor *) }

    include Json.Jsonable.S with type t := t
  end

  (** Response result *)
  module Response : sig
    type t = {
      prompts : Prompt.t list;  (** List of available prompts *)
      next_cursor : Cursor.t option;  (** Optional cursor for the next page *)
    }

    include Json.Jsonable.S with type t := t
  end

  val create_request :
    ?cursor:Cursor.t -> ?id:RequestId.t -> unit -> JSONRPCMessage.t
  (** Create a prompts/list request *)

  val create_response :
    id:RequestId.t ->
    prompts:Prompt.t list ->
    ?next_cursor:Cursor.t ->
    unit ->
    JSONRPCMessage.t
  (** Create a prompts/list response *)
end

(** Prompts/Get - Request to get a prompt with arguments *)
module PromptsGet : sig
  (** Request parameters *)
  module Request : sig
    type t = {
      name : string;  (** Name of the prompt to get *)
      arguments : (string * string) list;  (** Arguments for the prompt *)
    }

    include Json.Jsonable.S with type t := t
  end

  (** Response result *)
  module Response : sig
    type t = {
      description : string option;  (** Description of the prompt *)
      messages : PromptMessage.t list;  (** List of messages in the prompt *)
    }

    include Json.Jsonable.S with type t := t
  end

  val create_request :
    name:string ->
    arguments:(string * string) list ->
    ?id:RequestId.t ->
    unit ->
    JSONRPCMessage.t
  (** Create a prompts/get request *)

  val create_response :
    id:RequestId.t ->
    ?description:string ->
    messages:PromptMessage.t list ->
    unit ->
    JSONRPCMessage.t
  (** Create a prompts/get response *)
end

(** List Changed Notifications *)
module ListChanged : sig
  val create_resources_notification : unit -> JSONRPCMessage.t
  (** Create a resources/list_changed notification *)

  val create_tools_notification : unit -> JSONRPCMessage.t
  (** Create a tools/list_changed notification *)

  val create_prompts_notification : unit -> JSONRPCMessage.t
  (** Create a prompts/list_changed notification *)
end

(** Resource Updated Notification *)
module ResourceUpdated : sig
  (** Notification parameters *)
  module Notification : sig
    type t = { uri : string  (** URI of the updated resource *) }

    include Json.Jsonable.S with type t := t
  end

  val create_notification : uri:string -> unit -> JSONRPCMessage.t
  (** Create a resources/updated notification *)
end

(** Progress Notification *)
module Progress : sig
  (** Notification parameters *)
  module Notification : sig
    type t = {
      progress : float;  (** Current progress value *)
      total : float;  (** Total progress value *)
      progress_token : ProgressToken.t;  (** Token identifying the operation *)
    }

    include Json.Jsonable.S with type t := t
  end

  val create_notification :
    progress:float ->
    total:float ->
    progress_token:ProgressToken.t ->
    unit ->
    JSONRPCMessage.t
  (** Create a progress notification *)
end
