(** MCP - Model Context Protocol implementation

    The Model Context Protocol (MCP) is a standardized protocol for AI agents to
    exchange context with servers. This module provides the core OCaml
    implementation of MCP including all message types, content representations,
    and serialization functionality.

    MCP Architecture:
    - Uses JSON-RPC 2.0 as its underlying message format with UTF-8 encoding
    - Follows a client-server model where clients (often LLM-integrated
      applications) communicate with MCP servers
    - Supports multiple transport methods including stdio and streamable HTTP
    - Implements a three-phase connection lifecycle: initialization, operation,
      and shutdown
    - Provides capability negotiation during initialization to determine
      available features
    - Offers four primary context exchange mechanisms: 1. Resources:
      Server-exposed data that provides context to language models 2. Tools:
      Server-exposed functionality that can be invoked by language models 3.
      Prompts: Server-defined templates for structuring interactions with models
      4. Sampling: Client-exposed ability to generate completions from LLMs
    - Supports multimodal content types: text, images, audio, and embedded
      resources
    - Includes standardized error handling with defined error codes

    This implementation follows Protocol Revision 2025-03-26. *)

open Jsonrpc

(** Utility functions for JSON parsing *)
module Util : sig
  val json_error : ('a, unit, string, 'b) format4 -> Json.t -> 'a
  (** Helper to raise a Json.Of_json exception with formatted message
      @param fmt Format string for the error message
      @param json JSON value to include in the exception
      @return Never returns, always raises an exception
      @raise Json.Of_json with the formatted message and JSON value *)

  val get_string_field : (string * Json.t) list -> string -> Json.t -> string
  (** Extract a string field from JSON object or raise an error
      @param fields Assoc list of fields from JSON object
      @param name Field name to extract
      @param json Original JSON for error context
      @return The string value of the field
      @raise Json.Of_json if the field is missing or not a string *)

  val get_optional_string_field :
    (string * Json.t) list -> string -> string option
  (** Extract an optional string field from JSON object
      @param fields Assoc list of fields from JSON object
      @param name Field name to extract
      @return Some string if present and a string, None if missing
      @raise Json.Of_json if the field exists but is not a string *)

  val get_int_field : (string * Json.t) list -> string -> Json.t -> int
  (** Extract an int field from JSON object or raise an error
      @param fields Assoc list of fields from JSON object
      @param name Field name to extract
      @param json Original JSON for error context
      @return The int value of the field
      @raise Json.Of_json if the field is missing or not an int *)

  val get_float_field : (string * Json.t) list -> string -> Json.t -> float
  (** Extract a float field from JSON object or raise an error
      @param fields Assoc list of fields from JSON object
      @param name Field name to extract
      @param json Original JSON for error context
      @return The float value of the field
      @raise Json.Of_json if the field is missing or not a float *)

  val get_bool_field : (string * Json.t) list -> string -> Json.t -> bool
  (** Extract a boolean field from JSON object or raise an error
      @param fields Assoc list of fields from JSON object
      @param name Field name to extract
      @param json Original JSON for error context
      @return The boolean value of the field
      @raise Json.Of_json if the field is missing or not a boolean *)

  val get_object_field :
    (string * Json.t) list -> string -> Json.t -> (string * Json.t) list
  (** Extract an object field from JSON object or raise an error
      @param fields Assoc list of fields from JSON object
      @param name Field name to extract
      @param json Original JSON for error context
      @return The object as an assoc list
      @raise Json.Of_json if the field is missing or not an object *)

  val get_list_field : (string * Json.t) list -> string -> Json.t -> Json.t list
  (** Extract a list field from JSON object or raise an error
      @param fields Assoc list of fields from JSON object
      @param name Field name to extract
      @param json Original JSON for error context
      @return The list items
      @raise Json.Of_json if the field is missing or not a list *)

  val verify_string_field :
    (string * Json.t) list -> string -> string -> Json.t -> unit
  (** Verify a specific string value in a field
      @param fields Assoc list of fields from JSON object
      @param name Field name to check
      @param expected_value The expected string value
      @param json Original JSON for error context
      @raise Json.Of_json if the field is missing or not equal to expected_value
  *)
end

(** Error codes for JSON-RPC *)
module ErrorCode : sig
  (** Standard JSON-RPC error codes with MCP-specific additions *)
  type t =
    | ParseError  (** -32700 - Invalid JSON *)
    | InvalidRequest  (** -32600 - Invalid JSON-RPC request *)
    | MethodNotFound  (** -32601 - Method not available *)
    | InvalidParams  (** -32602 - Invalid method parameters *)
    | InternalError  (** -32603 - Internal JSON-RPC error *)
    | ResourceNotFound
        (** -32002 - Custom MCP error: requested resource not found *)
    | AuthRequired  (** -32001 - Custom MCP error: authentication required *)
    | CustomError of int  (** For any other error codes *)

  val to_int : t -> int
  (** Convert the error code to its integer representation
      @param code The error code to convert
      @return The integer error code as defined in the JSON-RPC spec *)

  val to_message : t -> string
  (** Get error message for standard error codes
      @param code The error code to get message for
      @return A standard message for the error code *)
end

(** MCP Protocol Methods - Algebraic data type representing all MCP methods *)
module Method : sig
  (** Method type representing all MCP protocol methods *)
  type t =
    (* Initialization and lifecycle methods *)
    | Initialize  (** Start the MCP lifecycle *)
    | Initialized  (** Signal readiness after initialization *)
    (* Resource methods *)
    | ResourcesList  (** Discover available resources *)
    | ResourcesRead  (** Retrieve resource contents *)
    | ResourceTemplatesList  (** List available resource templates *)
    | ResourcesSubscribe  (** Subscribe to resource changes *)
    | ResourcesListChanged  (** Resource list has changed *)
    | ResourcesUpdated  (** Resource has been updated *)
    (* Tool methods *)
    | ToolsList  (** Discover available tools *)
    | ToolsCall  (** Invoke a tool *)
    | ToolsListChanged  (** Tool list has changed *)
    (* Prompt methods *)
    | PromptsList  (** Discover available prompts *)
    | PromptsGet  (** Retrieve a prompt template with arguments *)
    | PromptsListChanged  (** Prompt list has changed *)
    (* Progress notifications *)
    | Progress  (** Progress update for long-running operations *)

  val to_string : t -> string
  (** Convert method type to string representation
      @param meth The method to convert
      @return
        The string representation of the method (e.g., "initialize",
        "resources/list") *)

  val of_string : string -> t
  (** Convert string to method type
      @param s The string representation of the method
      @return The corresponding method type
      @raise Failure if the string is not a valid MCP method *)
end

(** Common types *)

(** Roles for conversation participants *)
module Role : sig
  type t = [ `User | `Assistant ]
  (** Role represents conversation participants in MCP messages. Roles can be
      either 'user' or 'assistant', determining the source of each message in a
      conversation. *)

  include Json.Jsonable.S with type t := t
end

(** Progress tokens for long-running operations *)
module ProgressToken : sig
  type t = [ `String of string | `Int of int ]
  (** Progress tokens identify long-running operations and enable servers to
      provide progress updates to clients. This is used to track operations that
      may take significant time to complete. *)

  include Json.Jsonable.S with type t := t
end

(** Request IDs *)
module RequestId : sig
  type t = [ `String of string | `Int of int ]
  (** Request IDs uniquely identify JSON-RPC requests, allowing responses to be
      correlated with their originating requests. They can be either string or
      integer values. *)

  include Json.Jsonable.S with type t := t
end

(** Cursors for pagination *)
module Cursor : sig
  type t = string
  (** Cursors enable pagination in list operations for resources, tools, and
      prompts. When a server has more items than can be returned in a single
      response, it provides a cursor for the client to retrieve subsequent
      pages. *)

  include Json.Jsonable.S with type t := t
end

(** Annotations for objects *)
module Annotated : sig
  type t = { annotations : annotation option }
  (** Annotations provide metadata for content objects, allowing role-specific
      targeting and priority settings. *)

  and annotation = {
    audience : Role.t list option;
        (** Optional list of roles that should receive this content *)
    priority : float option;  (** Optional priority value for this content *)
  }

  include Json.Jsonable.S with type t := t
end

(** Text content - Core textual message representation in MCP *)
module TextContent : sig
  type t = {
    text : string;  (** The actual text content as a UTF-8 encoded string *)
    annotations : Annotated.annotation option;
        (** Optional annotations for audience targeting and priority.
            Annotations can restrict content visibility to specific roles
            (user/assistant) and indicate relative importance of different
            content elements. *)
  }
  (** TextContent represents plain text messages in MCP conversations. This is
      the most common content type used for natural language interactions
      between users and assistants. Text content is used in prompts, tool
      results, and model responses.

      In JSON-RPC, this is represented as:
      {v
      {
        "type": "text",
        "text": "The text content of the message"
      }
      v}

      For security, implementations must sanitize text content to prevent
      injection attacks or unauthorized access to resources. *)

  include Json.Jsonable.S with type t := t
end

(** Image content - Visual data representation in MCP *)
module ImageContent : sig
  type t = {
    data : string;
        (** Base64-encoded image data. All binary image data must be encoded
            using standard base64 encoding (RFC 4648) to safely transmit within
            JSON. *)
    mime_type : string;
        (** MIME type of the image (e.g., "image/png", "image/jpeg",
            "image/gif", "image/svg+xml"). This field is required and must
            accurately represent the image format to ensure proper handling by
            clients. *)
    annotations : Annotated.annotation option;
        (** Optional annotations for audience targeting and priority.
            Annotations can restrict content visibility to specific roles
            (user/assistant) and indicate relative importance of different
            content elements. *)
  }
  (** ImageContent enables including visual information in MCP messages,
      supporting multimodal interactions where visual context is important.

      Images can be used in several scenarios:
      - As user inputs for visual understanding tasks
      - As context for generating descriptions or analysis
      - As outputs from tools that generate visualizations
      - As part of prompt templates with visual components

      In JSON-RPC, this is represented as:
      {v
      {
        "type": "image",
        "data": "base64-encoded-image-data",
        "mimeType": "image/png"
      }
      v}

      The data MUST be base64-encoded to ensure safe transmission in JSON.
      Common mime types include image/png, image/jpeg, image/gif, and
      image/svg+xml. *)

  include Json.Jsonable.S with type t := t
end

(** Audio content - Sound data representation in MCP *)
module AudioContent : sig
  type t = {
    data : string;
        (** Base64-encoded audio data. All binary audio data must be encoded
            using standard base64 encoding (RFC 4648) to safely transmit within
            JSON. *)
    mime_type : string;
        (** MIME type of the audio (e.g., "audio/wav", "audio/mp3", "audio/ogg",
            "audio/mpeg"). This field is required and must accurately represent
            the audio format to ensure proper handling by clients. *)
    annotations : Annotated.annotation option;
        (** Optional annotations for audience targeting and priority.
            Annotations can restrict content visibility to specific roles
            (user/assistant) and indicate relative importance of different
            content elements. *)
  }
  (** AudioContent enables including audio information in MCP messages,
      supporting multimodal interactions where audio context is important.

      Audio can be used in several scenarios:
      - As user inputs for speech recognition or audio analysis
      - As context for transcription or sound classification tasks
      - As outputs from tools that generate audio samples
      - As part of prompt templates with audio components

      In JSON-RPC, this is represented as:
      {v
      {
        "type": "audio",
        "data": "base64-encoded-audio-data",
        "mimeType": "audio/wav"
      }
      v}

      The data MUST be base64-encoded to ensure safe transmission in JSON.
      Common mime types include audio/wav, audio/mp3, audio/ogg, and audio/mpeg.
  *)

  include Json.Jsonable.S with type t := t
end

(** Base resource contents - Core resource metadata in MCP *)
module ResourceContents : sig
  type t = {
    uri : string;
        (** URI that uniquely identifies the resource.

            Resources use standard URI schemes including:
            - file:// - For filesystem-like resources
            - https:// - For web-accessible resources
            - git:// - For version control integration

            The URI serves as a stable identifier even if the underlying content
            changes. *)
    mime_type : string option;
        (** Optional MIME type of the resource content to aid in client
            rendering. Common MIME types include text/plain, application/json,
            image/png, etc. For directories, the XDG MIME type inode/directory
            may be used. *)
  }
  (** ResourceContents provides basic metadata for resources in MCP.

      Resources are server-exposed data that provides context to language
      models, such as files, database schemas, or application-specific
      information. Each resource is uniquely identified by a URI.

      The MCP resources architecture is designed to be application-driven, with
      host applications determining how to incorporate context based on their
      needs.

      In the protocol, resources are discovered via the 'resources/list'
      endpoint and retrieved via the 'resources/read' endpoint. Servers that
      support resources must declare the 'resources' capability during
      initialization. *)

  include Json.Jsonable.S with type t := t
end

(** Text resource contents - Textual resource data *)
module TextResourceContents : sig
  type t = {
    uri : string;
        (** URI that uniquely identifies the resource. This URI can be
            referenced in subsequent requests to fetch updates. *)
    text : string;
        (** The actual text content of the resource as a UTF-8 encoded string.
            This may be sanitized by the server to remove sensitive information.
        *)
    mime_type : string option;
        (** Optional MIME type of the text content to aid in client rendering.
            Common text MIME types include: text/plain, text/markdown,
            text/x-python, application/json, text/html, text/csv, etc. *)
  }
  (** TextResourceContents represents a text-based resource in MCP.

      Text resources are used for sharing code snippets, documentation, logs,
      configuration files, and other textual information with language models.

      The server handles access control and security, ensuring that only
      authorized resources are shared with clients.

      In JSON-RPC, this is represented as:
      {v
      {
        "uri": "file:///example.txt",
        "mimeType": "text/plain",
        "text": "Resource content"
      }
      v} *)

  include Json.Jsonable.S with type t := t
end

(** Binary resource contents - Binary resource data *)
module BlobResourceContents : sig
  type t = {
    uri : string;
        (** URI that uniquely identifies the resource. This URI can be
            referenced in subsequent requests to fetch updates. *)
    blob : string;
        (** Base64-encoded binary data using standard base64 encoding (RFC
            4648). This encoding ensures that binary data can be safely
            transmitted in JSON. *)
    mime_type : string option;
        (** Optional MIME type of the binary content to aid in client rendering.
            Common binary MIME types include: image/png, image/jpeg,
            application/pdf, audio/wav, video/mp4, application/octet-stream,
            etc. *)
  }
  (** BlobResourceContents represents a binary resource in MCP.

      Binary resources allow sharing non-textual data like images, audio files,
      PDFs, and other binary formats with language models that support
      processing such content.

      In JSON-RPC, this is represented as:
      {v
      {
        "uri": "file:///example.png",
        "mimeType": "image/png",
        "blob": "base64-encoded-data"
      }
      v}

      Binary data MUST be properly base64-encoded to ensure safe transmission in
      JSON payloads. *)

  include Json.Jsonable.S with type t := t
end

(** Embedded resource - Resource included directly in messages *)
module EmbeddedResource : sig
  type t = {
    resource :
      [ `Text of TextResourceContents.t | `Blob of BlobResourceContents.t ];
        (** The resource content, either as text or binary blob. *)
    annotations : Annotated.annotation option;
        (** Optional annotations for audience targeting and priority.
            Annotations can restrict resource visibility to specific roles
            (user/assistant) and indicate relative importance of different
            content elements. *)
  }
  (** EmbeddedResource allows referencing server-side resources directly in MCP
      messages, enabling seamless incorporation of managed content.

      Embedded resources can be included in:
      - Tool results to provide rich context
      - Prompt templates to include reference materials
      - Messages to provide additional context to language models

      In contrast to direct content (TextContent, ImageContent, AudioContent),
      embedded resources have the advantage of being persistently stored on the
      server with a stable URI, allowing later retrieval and updates through the
      resources API.

      For example, a tool might return an embedded resource containing a chart
      or a large dataset that the client can later reference or update. *)

  include Json.Jsonable.S with type t := t
end

(** Content type used in messages - Unified multimodal content representation in
    MCP *)
type content =
  | Text of TextContent.t
      (** Text content for natural language messages. This is the most common
          content type for user-assistant interactions. *)
  | Image of ImageContent.t
      (** Image content for visual data. Used for sharing visual context in
          multimodal conversations. *)
  | Audio of AudioContent.t
      (** Audio content for audio data. Used for sharing audio context in
          multimodal conversations. *)
  | Resource of EmbeddedResource.t
      (** Resource content for referencing server-side resources. Used for
          incorporating managed server content with stable URIs. *)

val yojson_of_content : content -> Json.t
(** Convert content to Yojson representation
    @param content The content to convert
    @return JSON representation of the content *)

val content_of_yojson : Json.t -> content
(** Convert Yojson representation to content
    @param json JSON representation of content
    @return Parsed content object *)

(** Message for prompts - Template messages in the MCP prompts feature *)
module PromptMessage : sig
  type t = {
    role : Role.t;
        (** The role of the message sender (user or assistant). Prompt templates
            typically alternate between user and assistant messages to create a
            conversation structure. *)
    content : content;
        (** The message content, which can be text, image, audio, or resource.
            This unified content type supports rich multimodal prompts. *)
  }
  (** PromptMessage represents a message in an MCP prompt template, containing a
      role and content which can be customized with arguments.

      Prompt messages are part of prompt templates exposed by servers through
      the prompts/get endpoint. They define structured conversation templates
      that can be instantiated with user-provided arguments.

      The prompt feature is designed to be user-controlled, with prompts
      typically exposed through UI elements like slash commands that users can
      explicitly select.

      In JSON-RPC, prompt messages are represented as:
      {v
      {
        "role": "user",
        "content": {
          "type": "text",
          "text": "Please review this code: ${code}"
        }
      }
      v}

      Where $code would be replaced with a user-provided argument. *)

  include Json.Jsonable.S with type t := t
end

(** Message for sampling - Messages used in LLM completion requests *)
module SamplingMessage : sig
  type t = {
    role : Role.t;
        (** The role of the message sender (user or assistant). Typically, a
            sampling request will contain multiple messages representing a
            conversation history, with alternating roles. *)
    content :
      [ `Text of TextContent.t
      | `Image of ImageContent.t
      | `Audio of AudioContent.t ];
        (** The message content, restricted to text, image, or audio (no
            resources). Resources are not included since sampling messages
            represent the actual context window for the LLM, not template
            definitions. *)
  }
  (** SamplingMessage represents a message in an MCP sampling request, used for
      AI model generation based on a prompt.

      The sampling feature allows clients to expose language model capabilities
      to servers, enabling servers to request completions from the client's LLM.
      This is effectively the reverse of the normal MCP flow, with the server
      requesting generative capabilities from the client.

      Sampling messages differ from prompt messages in that they don't support
      embedded resources, as they represent the actual context window being sent
      to the LLM rather than template definitions.

      Clients that support sampling must declare the 'sampling' capability
      during initialization. *)

  include Json.Jsonable.S with type t := t
end

(** Implementation information *)
module Implementation : sig
  type t = {
    name : string;  (** Name of the implementation *)
    version : string;  (** Version of the implementation *)
  }
  (** Implementation provides metadata about client and server implementations,
      used during the initialization phase to identify each party. *)

  include Json.Jsonable.S with type t := t
end

(** JSONRPC message types - Core message protocol for MCP

    MCP uses JSON-RPC 2.0 as its underlying messaging protocol. All MCP messages
    are encoded as JSON-RPC 2.0 messages with UTF-8 encoding, following the
    standard JSON-RPC message formats with some MCP-specific extensions.

    MCP defines four message types: 1. Notifications: One-way messages that
    don't expect a response 2. Requests: Messages that expect a corresponding
    response 3. Responses: Replies to requests with successful results 4.
    Errors: Replies to requests with error information

    These can be transported over multiple transport mechanisms:
    - stdio: Communication over standard input/output
    - Streamable HTTP: HTTP POST/GET with SSE for server streaming
    - Custom transports: Implementation-specific transports

    Messages may be sent individually or as part of a JSON-RPC batch. *)
module JSONRPCMessage : sig
  type notification = {
    meth : Method.t;
        (** Method for the notification, using the Method.t type to ensure type
            safety. Examples: Method.Initialized, Method.ResourcesUpdated *)
    params : Json.t option;
        (** Optional parameters for the notification as arbitrary JSON. The
            structure depends on the specific notification method. *)
  }
  (** Notification represents a JSON-RPC notification (one-way message without a
      response).

      Notifications are used for events that don't require a response, such as:
      - The 'initialized' notification completing initialization
      - Resource change notifications
      - Progress updates for long-running operations
      - List changed notifications for tools, resources, and prompts

      In JSON-RPC, notifications are identified by the absence of an 'id' field:
      {v
      {
        "jsonrpc": "2.0",
        "method": "notifications/resources/updated",
        "params": {
          "uri": "file:///project/src/main.rs"
        }
      }
      v} *)

  type request = {
    id : RequestId.t;
        (** Unique identifier for the request, which will be echoed in the
            response. This can be a string or integer and should be unique
            within the session. *)
    meth : Method.t;
        (** Method for the request, using the Method.t type to ensure type
            safety. Examples: Method.Initialize, Method.ResourcesRead,
            Method.ToolsCall *)
    params : Json.t option;
        (** Optional parameters for the request as arbitrary JSON. The structure
            depends on the specific request method. *)
    progress_token : ProgressToken.t option;
        (** Optional progress token for long-running operations. If provided,
            the server can send progress notifications using this token to
            inform the client about the operation's status. *)
  }
  (** Request represents a JSON-RPC request that expects a response.

      Requests are used for operations that require a response, such as:
      - Initialization
      - Listing resources, tools, or prompts
      - Reading resources
      - Calling tools
      - Getting prompts

      In JSON-RPC, requests include an 'id' field that correlates with the
      response:
      {v
      {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "resources/read",
        "params": {
          "uri": "file:///project/src/main.rs"
        }
      }
      v} *)

  type response = {
    id : RequestId.t;
        (** ID matching the original request, allowing clients to correlate
            responses with their originating requests, especially important when
            multiple requests are in flight. *)
    result : Json.t;
        (** Result of the successful request as arbitrary JSON. The structure
            depends on the specific request method that was called. *)
  }
  (** Response represents a successful JSON-RPC response to a request.

      Responses are sent in reply to requests and contain the successful result.
      Each response must include the same ID as its corresponding request.

      In JSON-RPC, responses include the 'id' field matching the request:
      {v
      {
        "jsonrpc": "2.0",
        "id": 1,
        "result": {
          "contents": [
            {
              "uri": "file:///project/src/main.rs",
              "mimeType": "text/x-rust",
              "text": "fn main() {\n    println!(\"Hello world!\");\n}"
            }
          ]
        }
      }
      v} *)

  type error = {
    id : RequestId.t;
        (** ID matching the original request, allowing clients to correlate
            errors with their originating requests. *)
    code : int;
        (** Error code indicating the type of error, following the JSON-RPC
            standard. Common codes include:
            - -32700: Parse error
            - -32600: Invalid request
            - -32601: Method not found
            - -32602: Invalid params
            - -32603: Internal error
            - -32002: Resource not found (MCP-specific)
            - -32001: Authentication required (MCP-specific) *)
    message : string;
        (** Human-readable error message describing the issue. This should be
            concise but informative enough for debugging. *)
    data : Json.t option;
        (** Optional additional error data as arbitrary JSON. This can provide
            more context about the error, such as which resource wasn't found or
            which parameter was invalid. *)
  }
  (** Error represents an error response to a JSON-RPC request.

      Errors are sent in reply to requests when processing fails. Each error
      must include the same ID as its corresponding request.

      MCP defines several standard error codes:
      - Standard JSON-RPC errors (-32700 to -32603)
      - MCP-specific errors (-32002 for resource not found, etc.)

      In JSON-RPC, errors follow this structure:
      {v
      {
        "jsonrpc": "2.0",
        "id": 1,
        "error": {
          "code": -32002,
          "message": "Resource not found",
          "data": {
            "uri": "file:///nonexistent.txt"
          }
        }
      }
      v} *)

  (** Union type for all JSON-RPC message kinds, providing a single type that
      can represent any MCP message. *)
  type t =
    | Notification of notification
    | Request of request
    | Response of response
    | Error of error

  val yojson_of_notification : notification -> Json.t
  (** Convert notification to Yojson representation
      @param notification The notification to convert
      @return JSON representation of the notification *)

  val yojson_of_request : request -> Json.t
  (** Convert request to Yojson representation
      @param request The request to convert
      @return JSON representation of the request *)

  val yojson_of_response : response -> Json.t
  (** Convert response to Yojson representation
      @param response The response to convert
      @return JSON representation of the response *)

  val yojson_of_error : error -> Json.t
  (** Convert error to Yojson representation
      @param error The error to convert
      @return JSON representation of the error *)

  val yojson_of_t : t -> Json.t
  (** Convert any message to Yojson representation
      @param message The message to convert
      @return JSON representation of the message *)

  val notification_of_yojson : Json.t -> notification
  (** Convert Yojson representation to notification
      @param json JSON representation of a notification
      @return Parsed notification object
      @raise Parse error if the JSON is not a valid notification *)

  val request_of_yojson : Json.t -> request
  (** Convert Yojson representation to request
      @param json JSON representation of a request
      @return Parsed request object
      @raise Parse error if the JSON is not a valid request *)

  val response_of_yojson : Json.t -> response
  (** Convert Yojson representation to response
      @param json JSON representation of a response
      @return Parsed response object
      @raise Parse error if the JSON is not a valid response *)

  val error_of_yojson : Json.t -> error
  (** Convert Yojson representation to error
      @param json JSON representation of an error
      @return Parsed error object
      @raise Parse error if the JSON is not a valid error *)

  val t_of_yojson : Json.t -> t
  (** Convert Yojson representation to any message
      @param json JSON representation of any message type
      @return Parsed message object
      @raise Parse error if the JSON is not a valid message *)

  val create_notification : ?params:Json.t option -> meth:Method.t -> unit -> t
  (** Create a new notification message
      @param params Optional parameters for the notification
      @param meth Method name for the notification
      @return A new JSON-RPC notification message *)

  val create_request :
    ?params:Json.t option ->
    ?progress_token:ProgressToken.t option ->
    id:RequestId.t ->
    meth:Method.t ->
    unit ->
    t
  (** Create a new request message
      @param params Optional parameters for the request
      @param progress_token Optional progress token for long-running operations
      @param id Unique identifier for the request
      @param meth Method name for the request
      @return A new JSON-RPC request message *)

  val create_response : id:RequestId.t -> result:Json.t -> t
  (** Create a new response message
      @param id ID matching the original request
      @param result Result of the successful request
      @return A new JSON-RPC response message *)

  val create_error :
    id:RequestId.t ->
    code:int ->
    message:string ->
    ?data:Json.t option ->
    unit ->
    t
  (** Create a new error message
      @param id ID matching the original request
      @param code Error code indicating the type of error
      @param message Human-readable error message
      @param data Optional additional error data
      @return A new JSON-RPC error message *)
end

(** Initialize request/response - The first phase of the MCP lifecycle

    The initialization phase is the mandatory first interaction between client
    and server. During this phase, the protocol version is negotiated and
    capabilities are exchanged to determine which optional features will be
    available during the session.

    This follows a strict sequence: 1. Client sends an InitializeRequest
    containing its capabilities and protocol version 2. Server responds with an
    InitializeResult containing its capabilities and protocol version 3. Client
    sends an InitializedNotification to signal it's ready for normal operations

    The Initialize module handles steps 1 and 2 of this process. *)
module Initialize : sig
  (** Initialize request *)
  module Request : sig
    type t = {
      capabilities : Json.t;
          (** ClientCapabilities that define supported optional features. This
              includes which optional protocol features the client supports,
              such as 'roots' (filesystem access), 'sampling' (LLM generation),
              and any experimental features. *)
      client_info : Implementation.t;
          (** Client implementation details (name and version) used for
              identification and debugging. Helps servers understand which
              client they're working with. *)
      protocol_version : string;
          (** MCP protocol version supported by the client, formatted as
              YYYY-MM-DD according to the MCP versioning scheme. Example:
              "2025-03-26" *)
    }
    (** InitializeRequest starts the MCP lifecycle, negotiating capabilities and
        protocol versions between client and server. This is always the first
        message sent by the client and MUST NOT be part of a JSON-RPC batch.

        The client SHOULD send the latest protocol version it supports. If the
        server does not support this version, it will respond with a version it
        does support, and the client must either use that version or disconnect.
    *)

    include Json.Jsonable.S with type t := t

    val create :
      capabilities:Json.t ->
      client_info:Implementation.t ->
      protocol_version:string ->
      t
    (** Create a new initialization request
        @param capabilities
          Client capabilities that define supported optional features
        @param client_info Client implementation details
        @param protocol_version MCP protocol version supported by the client
        @return A new initialization request *)

    val to_jsonrpc : id:RequestId.t -> t -> JSONRPCMessage.t
    (** Convert to JSON-RPC message
        @param id Unique request identifier
        @param t Initialization request
        @return JSON-RPC message containing the initialization request *)
  end

  (** Initialize result *)
  module Result : sig
    type t = {
      capabilities : Json.t;
          (** ServerCapabilities that define supported optional features. This
              declares which server features are available, including:
              - prompts: Server provides prompt templates
              - resources: Server provides readable resources
              - tools: Server exposes callable tools
              - logging: Server emits structured log messages

              Each capability may have sub-capabilities like:
              - listChanged: Server will notify when available items change
              - subscribe: Clients can subscribe to individual resources *)
      server_info : Implementation.t;
          (** Server implementation details (name and version) used for
              identification and debugging. Helps clients understand which
              server they're working with. *)
      protocol_version : string;
          (** MCP protocol version supported by the server, formatted as
              YYYY-MM-DD. If the server supports the client's requested version,
              it responds with the same version. Otherwise, it responds with a
              version it does support. *)
      instructions : string option;
          (** Optional instructions for using the server. These can provide
              human-readable guidance on how to interact with this specific
              server implementation. *)
      meta : Json.t option;
          (** Optional additional metadata as arbitrary JSON. Can contain
              server-specific information not covered by the standard fields. *)
    }
    (** InitializeResult is the server's response to an initialization request,
        completing capability negotiation and establishing the protocol version.

        After receiving this message, the client must send an
        InitializedNotification. The server should not send any requests other
        than pings and logging before receiving the initialized notification. *)

    include Json.Jsonable.S with type t := t

    val create :
      capabilities:Json.t ->
      server_info:Implementation.t ->
      protocol_version:string ->
      ?instructions:string ->
      ?meta:Json.t ->
      unit ->
      t
    (** Create a new initialization result
        @param capabilities
          Server capabilities that define supported optional features
        @param server_info Server implementation details
        @param protocol_version MCP protocol version supported by the server
        @param instructions Optional instructions for using the server
        @param meta Optional additional metadata
        @return A new initialization result *)

    val to_jsonrpc : id:RequestId.t -> t -> JSONRPCMessage.t
    (** Convert to JSON-RPC message
        @param id ID matching the original request
        @param t Initialization result
        @return JSON-RPC message containing the initialization result *)
  end
end

(** Initialized notification - Completes the initialization phase of the MCP
    lifecycle *)
module Initialized : sig
  module Notification : sig
    type t = {
      meta : Json.t option;
          (** Optional additional metadata as arbitrary JSON. Can contain
              client-specific information not covered by the standard fields. *)
    }
    (** InitializedNotification is sent by the client after receiving the
        initialization response, indicating it's ready to begin normal
        operations. This completes the three-step initialization process, after
        which both client and server can freely exchange messages according to
        the negotiated capabilities.

        Only after this notification has been sent should the client begin
        normal operations like listing resources, calling tools, or requesting
        prompts. *)

    include Json.Jsonable.S with type t := t

    val create : ?meta:Json.t -> unit -> t
    (** Create a new initialized notification
        @param meta Optional additional metadata
        @return A new initialized notification *)

    val to_jsonrpc : t -> JSONRPCMessage.t
    (** Convert to JSON-RPC message
        @param t Initialized notification
        @return JSON-RPC message containing the initialized notification *)
  end
end

val parse_message : Json.t -> JSONRPCMessage.t
(** Parse a JSON message into an MCP message

    This function takes a raw JSON value and parses it into a structured MCP
    message. It's the primary entry point for processing incoming JSON-RPC
    messages in the MCP protocol.

    The function determines the message type (notification, request, response,
    or error) based on the presence and values of specific fields:
    - A message with "method" but no "id" is a notification
    - A message with "method" and "id" is a request
    - A message with "id" and "result" is a response
    - A message with "id" and "error" is an error

    @param json
      The JSON message to parse, typically received from the transport layer
    @return The parsed MCP message as a structured JSONRPCMessage.t value
    @raise Parse error if the JSON cannot be parsed as a valid MCP message *)

val create_notification :
  ?params:Json.t option -> meth:Method.t -> unit -> JSONRPCMessage.t
(** Create a new notification message

    Notifications are one-way messages that don't expect a response. This is a
    convenience wrapper around JSONRPCMessage.create_notification.

    Common notifications in MCP include:
    - "notifications/initialized" - Sent after initialization
    - "notifications/progress" - Updates on long-running operations
    - "notifications/resources/updated" - Resource content changed
    - "notifications/prompts/list_changed" - Available prompts changed
    - "notifications/tools/list_changed" - Available tools changed

    @param params Optional parameters for the notification as a JSON value
    @param meth Method type for the notification
    @return A new JSON-RPC notification message *)

val create_request :
  ?params:Json.t option ->
  ?progress_token:ProgressToken.t option ->
  id:RequestId.t ->
  meth:Method.t ->
  unit ->
  JSONRPCMessage.t
(** Create a new request message

    Requests are messages that expect a corresponding response. This is a
    convenience wrapper around JSONRPCMessage.create_request.

    Common requests in MCP include:
    - "initialize" - Start the MCP lifecycle
    - "resources/list" - Discover available resources
    - "resources/read" - Retrieve resource contents
    - "tools/list" - Discover available tools
    - "tools/call" - Invoke a tool
    - "prompts/list" - Discover available prompts
    - "prompts/get" - Retrieve a prompt template

    @param params Optional parameters for the request as a JSON value
    @param progress_token
      Optional progress token for long-running operations that can report
      progress updates
    @param id
      Unique identifier for the request, used to correlate with the response
    @param meth Method type for the request
    @return A new JSON-RPC request message *)

val create_response : id:RequestId.t -> result:Json.t -> JSONRPCMessage.t
(** Create a new response message

    Responses are sent in reply to requests and contain successful results. This
    is a convenience wrapper around JSONRPCMessage.create_response.

    Each response must include the same ID as its corresponding request to allow
    the client to correlate them, especially when multiple requests are in
    flight simultaneously.

    @param id ID matching the original request
    @param result Result of the successful request as a JSON value
    @return A new JSON-RPC response message *)

val create_error :
  id:RequestId.t ->
  code:int ->
  message:string ->
  ?data:Json.t option ->
  unit ->
  JSONRPCMessage.t
(** Create a new error message

    Errors are sent in reply to requests when processing fails. This is a
    convenience wrapper around JSONRPCMessage.create_error.

    MCP uses standard JSON-RPC error codes as well as some protocol-specific
    codes:
    - -32700: Parse error (invalid JSON)
    - -32600: Invalid request (malformed JSON-RPC)
    - -32601: Method not found
    - -32602: Invalid parameters
    - -32603: Internal error
    - -32002: Resource not found (MCP-specific)
    - -32001: Authentication required (MCP-specific)

    @param id ID matching the original request
    @param code Error code indicating the type of error
    @param message Human-readable error message describing the issue
    @param data Optional additional error data providing more context
    @return A new JSON-RPC error message *)

val make_text_content : string -> content
(** Create a new text content object
    @param text The text content
    @return A content value with the text *)

val make_image_content : string -> string -> content
(** Create a new image content object
    @param data Base64-encoded image data
    @param mime_type MIME type of the image (e.g., "image/png", "image/jpeg")
    @return A content value with the image *)

val make_audio_content : string -> string -> content
(** Create a new audio content object
    @param data Base64-encoded audio data
    @param mime_type MIME type of the audio (e.g., "audio/wav", "audio/mp3")
    @return A content value with the audio *)

val make_resource_text_content : string -> string -> string option -> content
(** Create a new text resource content object
    @param uri URI that uniquely identifies the resource
    @param text The text content of the resource
    @param mime_type Optional MIME type of the text content
    @return A content value with the text resource *)

val make_resource_blob_content : string -> string -> string option -> content
(** Create a new binary resource content object
    @param uri URI that uniquely identifies the resource
    @param blob Base64-encoded binary data
    @param mime_type Optional MIME type of the binary content
    @return A content value with the binary resource *)
