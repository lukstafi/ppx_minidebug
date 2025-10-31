open Jsonrpc

(* Utility functions for JSON parsing *)
module Util = struct
  (* Helper to raise a Json.Of_json exception with formatted message *)
  let json_error fmt json =
    Printf.ksprintf (fun msg -> raise (Json.Of_json (msg, json))) fmt

  (* Extract a string field from JSON object or raise an error *)
  let get_string_field fields name json =
    match List.assoc_opt name fields with
    | Some (`String s) -> s
    | _ -> json_error "Missing or invalid '%s' field" json name

  (* Extract an optional string field from JSON object *)
  let get_optional_string_field fields name =
    List.assoc_opt name fields
    |> Option.map (function
         | `String s -> s
         | j -> json_error "Expected string for %s" j name)

  (* Extract an int field from JSON object or raise an error *)
  let get_int_field fields name json =
    match List.assoc_opt name fields with
    | Some (`Int i) -> i
    | _ -> json_error "Missing or invalid '%s' field" json name

  (* Extract a float field from JSON object or raise an error *)
  let get_float_field fields name json =
    match List.assoc_opt name fields with
    | Some (`Float f) -> f
    | _ -> json_error "Missing or invalid '%s' field" json name

  (* Extract a boolean field from JSON object or raise an error *)
  let get_bool_field fields name json =
    match List.assoc_opt name fields with
    | Some (`Bool b) -> b
    | _ -> json_error "Missing or invalid '%s' field" json name

  (* Extract an object field from JSON object or raise an error *)
  let get_object_field fields name json =
    match List.assoc_opt name fields with
    | Some (`Assoc obj) -> obj
    | _ -> json_error "Missing or invalid '%s' field" json name

  (* Extract a list field from JSON object or raise an error *)
  let get_list_field fields name json =
    match List.assoc_opt name fields with
    | Some (`List items) -> items
    | _ -> json_error "Missing or invalid '%s' field" json name

  (* Verify a specific string value in a field *)
  let verify_string_field fields name expected_value json =
    match List.assoc_opt name fields with
    | Some (`String s) when s = expected_value -> ()
    | _ ->
        json_error "Field '%s' missing or not equal to '%s'" json name
          expected_value
end

(* Error codes for JSON-RPC *)
module ErrorCode = struct
  type t =
    | ParseError (* -32700 - Invalid JSON *)
    | InvalidRequest (* -32600 - Invalid JSON-RPC request *)
    | MethodNotFound (* -32601 - Method not available *)
    | InvalidParams (* -32602 - Invalid method parameters *)
    | InternalError (* -32603 - Internal JSON-RPC error *)
    | ResourceNotFound
      (* -32002 - Custom MCP error: requested resource not found *)
    | AuthRequired (* -32001 - Custom MCP error: authentication required *)
    | CustomError of int (* For any other error codes *)

  (* Convert the error code to its integer representation *)
  let to_int = function
    | ParseError -> -32700
    | InvalidRequest -> -32600
    | MethodNotFound -> -32601
    | InvalidParams -> -32602
    | InternalError -> -32603
    | ResourceNotFound -> -32002
    | AuthRequired -> -32001
    | CustomError code -> code

  (* Get error message for standard error codes *)
  let to_message = function
    | ParseError -> "Parse error"
    | InvalidRequest -> "Invalid Request"
    | MethodNotFound -> "Method not found"
    | InvalidParams -> "Invalid params"
    | InternalError -> "Internal error"
    | ResourceNotFound -> "Resource not found"
    | AuthRequired -> "Authentication required"
    | CustomError _ -> "Error"
end

(* Protocol method types *)
module Method = struct
  (* Method type representing all MCP protocol methods *)
  type t =
    (* Initialization and lifecycle methods *)
    | Initialize
    | Initialized
    (* Resource methods *)
    | ResourcesList
    | ResourcesRead
    | ResourceTemplatesList
    | ResourcesSubscribe
    | ResourcesListChanged
    | ResourcesUpdated
    (* Tool methods *)
    | ToolsList
    | ToolsCall
    | ToolsListChanged
    (* Prompt methods *)
    | PromptsList
    | PromptsGet
    | PromptsListChanged
    (* Progress notifications *)
    | Progress

  (* Convert method type to string representation *)
  let to_string = function
    | Initialize -> "initialize"
    | Initialized -> "notifications/initialized"
    | ResourcesList -> "resources/list"
    | ResourcesRead -> "resources/read"
    | ResourceTemplatesList -> "resources/templates/list"
    | ResourcesSubscribe -> "resources/subscribe"
    | ResourcesListChanged -> "notifications/resources/list_changed"
    | ResourcesUpdated -> "notifications/resources/updated"
    | ToolsList -> "tools/list"
    | ToolsCall -> "tools/call"
    | ToolsListChanged -> "notifications/tools/list_changed"
    | PromptsList -> "prompts/list"
    | PromptsGet -> "prompts/get"
    | PromptsListChanged -> "notifications/prompts/list_changed"
    | Progress -> "notifications/progress"

  (* Convert string to method type *)
  let of_string = function
    | "initialize" -> Initialize
    | "notifications/initialized" -> Initialized
    | "resources/list" -> ResourcesList
    | "resources/read" -> ResourcesRead
    | "resources/templates/list" -> ResourceTemplatesList
    | "resources/subscribe" -> ResourcesSubscribe
    | "notifications/resources/list_changed" -> ResourcesListChanged
    | "notifications/resources/updated" -> ResourcesUpdated
    | "tools/list" -> ToolsList
    | "tools/call" -> ToolsCall
    | "notifications/tools/list_changed" -> ToolsListChanged
    | "prompts/list" -> PromptsList
    | "prompts/get" -> PromptsGet
    | "notifications/prompts/list_changed" -> PromptsListChanged
    | "notifications/progress" -> Progress
    | s -> failwith ("Unknown MCP method: " ^ s)
end

(* Common types *)

module Role = struct
  type t = [ `User | `Assistant ]

  let to_string = function `User -> "user" | `Assistant -> "assistant"

  let of_string = function
    | "user" -> `User
    | "assistant" -> `Assistant
    | s -> Util.json_error "Unknown role: %s" (`String s) s

  let yojson_of_t t = `String (to_string t)

  let t_of_yojson = function
    | `String s -> of_string s
    | j -> Util.json_error "Expected string for Role" j
end

module ProgressToken = struct
  type t = [ `String of string | `Int of int ]

  include (Id : Json.Jsonable.S with type t := t)
end

module RequestId = Id

module Cursor = struct
  type t = string

  let yojson_of_t t = `String t

  let t_of_yojson = function
    | `String s -> s
    | j -> Util.json_error "Expected string for Cursor" j
end

(* Annotations *)

module Annotated = struct
  type t = { annotations : annotation option }
  and annotation = { audience : Role.t list option; priority : float option }

  let yojson_of_annotation { audience; priority } =
    let assoc = [] in
    let assoc =
      match audience with
      | Some audience ->
          ("audience", `List (List.map Role.yojson_of_t audience)) :: assoc
      | None -> assoc
    in
    let assoc =
      match priority with
      | Some priority -> ("priority", `Float priority) :: assoc
      | None -> assoc
    in
    `Assoc assoc

  let annotation_of_yojson = function
    | `Assoc fields ->
        let audience =
          List.assoc_opt "audience" fields
          |> Option.map (function
               | `List items -> List.map Role.t_of_yojson items
               | j -> Util.json_error "Expected list for audience" j)
        in
        let priority =
          List.assoc_opt "priority" fields
          |> Option.map (function
               | `Float f -> f
               | j -> Util.json_error "Expected float for priority" j)
        in
        { audience; priority }
    | j -> Util.json_error "Expected object for annotation" j

  let yojson_of_t { annotations } =
    match annotations with
    | Some annotations ->
        `Assoc [ ("annotations", yojson_of_annotation annotations) ]
    | None -> `Assoc []

  let t_of_yojson = function
    | `Assoc fields ->
        let annotations =
          List.assoc_opt "annotations" fields |> Option.map annotation_of_yojson
        in
        { annotations }
    | j -> Util.json_error "Expected object for Annotated" j
end

(* Content types *)

module TextContent = struct
  type t = { text : string; annotations : Annotated.annotation option }

  let yojson_of_t { text; annotations } =
    let assoc = [ ("text", `String text); ("type", `String "text") ] in
    let assoc =
      match annotations with
      | Some annotations ->
          ("annotations", Annotated.yojson_of_annotation annotations) :: assoc
      | None -> assoc
    in
    `Assoc assoc

  let t_of_yojson = function
    | `Assoc fields as json ->
        let text = Util.get_string_field fields "text" json in
        Util.verify_string_field fields "type" "text" json;
        let annotations =
          List.assoc_opt "annotations" fields
          |> Option.map Annotated.annotation_of_yojson
        in
        { text; annotations }
    | j -> Util.json_error "Expected object for TextContent" j
end

module ImageContent = struct
  type t = {
    data : string;
    mime_type : string;
    annotations : Annotated.annotation option;
  }

  let yojson_of_t { data; mime_type; annotations } =
    let assoc =
      [
        ("type", `String "image");
        ("data", `String data);
        ("mimeType", `String mime_type);
      ]
    in
    let assoc =
      match annotations with
      | Some annotations ->
          ("annotations", Annotated.yojson_of_annotation annotations) :: assoc
      | None -> assoc
    in
    `Assoc assoc

  let t_of_yojson = function
    | `Assoc fields as json ->
        let data = Util.get_string_field fields "data" json in
        let mime_type = Util.get_string_field fields "mimeType" json in
        Util.verify_string_field fields "type" "image" json;
        let annotations =
          List.assoc_opt "annotations" fields
          |> Option.map Annotated.annotation_of_yojson
        in
        { data; mime_type; annotations }
    | j -> Util.json_error "Expected object for ImageContent" j
end

module AudioContent = struct
  type t = {
    data : string;
    mime_type : string;
    annotations : Annotated.annotation option;
  }

  let yojson_of_t { data; mime_type; annotations } =
    let assoc =
      [
        ("type", `String "audio");
        ("data", `String data);
        ("mimeType", `String mime_type);
      ]
    in
    let assoc =
      match annotations with
      | Some annotations ->
          ("annotations", Annotated.yojson_of_annotation annotations) :: assoc
      | None -> assoc
    in
    `Assoc assoc

  let t_of_yojson = function
    | `Assoc fields as json ->
        let data = Util.get_string_field fields "data" json in
        let mime_type = Util.get_string_field fields "mimeType" json in
        Util.verify_string_field fields "type" "audio" json;
        let annotations =
          List.assoc_opt "annotations" fields
          |> Option.map Annotated.annotation_of_yojson
        in
        { data; mime_type; annotations }
    | j -> Util.json_error "Expected object for AudioContent" j
end

module ResourceContents = struct
  type t = { uri : string; mime_type : string option }

  let yojson_of_t { uri; mime_type } =
    let assoc = [ ("uri", `String uri) ] in
    let assoc =
      match mime_type with
      | Some mime_type -> ("mimeType", `String mime_type) :: assoc
      | None -> assoc
    in
    `Assoc assoc

  let t_of_yojson = function
    | `Assoc fields as json ->
        let uri = Util.get_string_field fields "uri" json in
        let mime_type = Util.get_optional_string_field fields "mimeType" in
        { uri; mime_type }
    | j -> Util.json_error "Expected object for ResourceContents" j
end

module TextResourceContents = struct
  type t = { uri : string; text : string; mime_type : string option }

  let yojson_of_t { uri; text; mime_type } =
    let assoc = [ ("uri", `String uri); ("text", `String text) ] in
    let assoc =
      match mime_type with
      | Some mime_type -> ("mimeType", `String mime_type) :: assoc
      | None -> assoc
    in
    `Assoc assoc

  let t_of_yojson = function
    | `Assoc fields as json ->
        let uri = Util.get_string_field fields "uri" json in
        let text = Util.get_string_field fields "text" json in
        let mime_type = Util.get_optional_string_field fields "mimeType" in
        { uri; text; mime_type }
    | j -> Util.json_error "Expected object for TextResourceContents" j
end

module BlobResourceContents = struct
  type t = { uri : string; blob : string; mime_type : string option }

  let yojson_of_t { uri; blob; mime_type } =
    let assoc = [ ("uri", `String uri); ("blob", `String blob) ] in
    let assoc =
      match mime_type with
      | Some mime_type -> ("mimeType", `String mime_type) :: assoc
      | None -> assoc
    in
    `Assoc assoc

  let t_of_yojson = function
    | `Assoc fields as json ->
        let uri = Util.get_string_field fields "uri" json in
        let blob = Util.get_string_field fields "blob" json in
        let mime_type = Util.get_optional_string_field fields "mimeType" in
        { uri; blob; mime_type }
    | j -> Util.json_error "Expected object for BlobResourceContents" j
end

module EmbeddedResource = struct
  type t = {
    resource :
      [ `Text of TextResourceContents.t | `Blob of BlobResourceContents.t ];
    annotations : Annotated.annotation option;
  }

  let yojson_of_t { resource; annotations } =
    let resource_json =
      match resource with
      | `Text txt -> TextResourceContents.yojson_of_t txt
      | `Blob blob -> BlobResourceContents.yojson_of_t blob
    in
    let assoc = [ ("resource", resource_json); ("type", `String "resource") ] in
    let assoc =
      match annotations with
      | Some annotations ->
          ("annotations", Annotated.yojson_of_annotation annotations) :: assoc
      | None -> assoc
    in
    `Assoc assoc

  let t_of_yojson = function
    | `Assoc fields as json ->
        Util.verify_string_field fields "type" "resource" json;
        let resource_fields =
          match List.assoc_opt "resource" fields with
          | Some (`Assoc res_fields) -> res_fields
          | _ -> Util.json_error "Missing or invalid 'resource' field" json
        in
        let resource =
          if List.mem_assoc "text" resource_fields then
            `Text (TextResourceContents.t_of_yojson (`Assoc resource_fields))
          else if List.mem_assoc "blob" resource_fields then
            `Blob (BlobResourceContents.t_of_yojson (`Assoc resource_fields))
          else
            Util.json_error "Invalid resource content" (`Assoc resource_fields)
        in
        let annotations =
          List.assoc_opt "annotations" fields
          |> Option.map Annotated.annotation_of_yojson
        in
        { resource; annotations }
    | j -> Util.json_error "Expected object for EmbeddedResource" j
end

type content =
  | Text of TextContent.t
  | Image of ImageContent.t
  | Audio of AudioContent.t
  | Resource of EmbeddedResource.t

let yojson_of_content = function
  | Text t -> TextContent.yojson_of_t t
  | Image i -> ImageContent.yojson_of_t i
  | Audio a -> AudioContent.yojson_of_t a
  | Resource r -> EmbeddedResource.yojson_of_t r

let content_of_yojson = function
  | `Assoc fields as json -> (
      match List.assoc_opt "type" fields with
      | Some (`String "text") -> Text (TextContent.t_of_yojson json)
      | Some (`String "image") -> Image (ImageContent.t_of_yojson json)
      | Some (`String "audio") -> Audio (AudioContent.t_of_yojson json)
      | Some (`String "resource") ->
          Resource (EmbeddedResource.t_of_yojson json)
      | _ -> Util.json_error "Invalid or missing content type" json)
  | j -> Util.json_error "Expected object for content" j

(* Message types *)

module PromptMessage = struct
  type t = { role : Role.t; content : content }

  let yojson_of_t { role; content } =
    `Assoc
      [
        ("role", Role.yojson_of_t role); ("content", yojson_of_content content);
      ]

  let t_of_yojson = function
    | `Assoc fields as json ->
        let role =
          match List.assoc_opt "role" fields with
          | Some json -> Role.t_of_yojson json
          | None -> Util.json_error "Missing role field" json
        in
        let content =
          match List.assoc_opt "content" fields with
          | Some json -> content_of_yojson json
          | None -> Util.json_error "Missing content field" json
        in
        { role; content }
    | j -> Util.json_error "Expected object for PromptMessage" j
end

module SamplingMessage = struct
  type t = {
    role : Role.t;
    content :
      [ `Text of TextContent.t
      | `Image of ImageContent.t
      | `Audio of AudioContent.t ];
  }

  let yojson_of_t { role; content } =
    let content_json =
      match content with
      | `Text t -> TextContent.yojson_of_t t
      | `Image i -> ImageContent.yojson_of_t i
      | `Audio a -> AudioContent.yojson_of_t a
    in
    `Assoc [ ("role", Role.yojson_of_t role); ("content", content_json) ]

  let t_of_yojson = function
    | `Assoc fields as json ->
        let role =
          match List.assoc_opt "role" fields with
          | Some json -> Role.t_of_yojson json
          | None -> Util.json_error "Missing role field" json
        in
        let content_obj =
          match List.assoc_opt "content" fields with
          | Some (`Assoc content_fields) -> content_fields
          | _ -> Util.json_error "Missing or invalid content field" json
        in
        let content_type =
          match List.assoc_opt "type" content_obj with
          | Some (`String ty) -> ty
          | _ ->
              Util.json_error "Missing or invalid content type"
                (`Assoc content_obj)
        in
        let content =
          match content_type with
          | "text" -> `Text (TextContent.t_of_yojson (`Assoc content_obj))
          | "image" -> `Image (ImageContent.t_of_yojson (`Assoc content_obj))
          | "audio" -> `Audio (AudioContent.t_of_yojson (`Assoc content_obj))
          | _ ->
              Util.json_error "Invalid content type: %s" (`Assoc content_obj)
                content_type
        in
        { role; content }
    | j -> Util.json_error "Expected object for SamplingMessage" j
end

(* Implementation info *)

module Implementation = struct
  type t = { name : string; version : string }

  let yojson_of_t { name; version } =
    `Assoc [ ("name", `String name); ("version", `String version) ]

  let t_of_yojson = function
    | `Assoc fields as json ->
        let name = Util.get_string_field fields "name" json in
        let version = Util.get_string_field fields "version" json in
        { name; version }
    | j -> Util.json_error "Expected object for Implementation" j
end

(* JSONRPC Message types *)

module JSONRPCMessage = struct
  type notification = { meth : Method.t; params : Json.t option }

  type request = {
    id : RequestId.t;
    meth : Method.t;
    params : Json.t option;
    progress_token : ProgressToken.t option;
  }

  type response = { id : RequestId.t; result : Json.t }

  type error = {
    id : RequestId.t;
    code : int;
    message : string;
    data : Json.t option;
  }

  type t =
    | Notification of notification
    | Request of request
    | Response of response
    | Error of error

  let yojson_of_notification (n : notification) =
    let assoc =
      [
        ("jsonrpc", `String "2.0"); ("method", `String (Method.to_string n.meth));
      ]
    in
    let assoc =
      match n.params with
      | Some params -> ("params", params) :: assoc
      | None -> assoc
    in
    `Assoc assoc

  let yojson_of_request (r : request) =
    let assoc =
      [
        ("jsonrpc", `String "2.0");
        ("id", Id.yojson_of_t r.id);
        ("method", `String (Method.to_string r.meth));
      ]
    in
    let assoc =
      match r.params with
      | Some params ->
          let params_json =
            match params with
            | `Assoc fields ->
                let fields =
                  match r.progress_token with
                  | Some token ->
                      let meta =
                        `Assoc
                          [ ("progressToken", ProgressToken.yojson_of_t token) ]
                      in
                      ("_meta", meta) :: fields
                  | None -> fields
                in
                `Assoc fields
            | _ -> params
          in
          ("params", params_json) :: assoc
      | None -> assoc
    in
    `Assoc assoc

  let yojson_of_response (r : response) =
    `Assoc
      [
        ("jsonrpc", `String "2.0");
        ("id", Id.yojson_of_t r.id);
        ("result", r.result);
      ]

  let yojson_of_error (e : error) =
    let error_assoc =
      [ ("code", `Int e.code); ("message", `String e.message) ]
    in
    let error_assoc =
      match e.data with
      | Some data -> ("data", data) :: error_assoc
      | None -> error_assoc
    in
    `Assoc
      [
        ("jsonrpc", `String "2.0");
        ("id", Id.yojson_of_t e.id);
        ("error", `Assoc error_assoc);
      ]

  let yojson_of_t = function
    | Notification n -> yojson_of_notification n
    | Request r -> yojson_of_request r
    | Response r -> yojson_of_response r
    | Error e -> yojson_of_error e

  let notification_of_yojson = function
    | `Assoc fields ->
        let meth =
          match List.assoc_opt "method" fields with
          | Some (`String s) -> (
              try Method.of_string s
              with Failure msg -> Util.json_error "%s" (`String s) msg)
          | _ ->
              Util.json_error "Missing or invalid 'method' field"
                (`Assoc fields)
        in
        let params = List.assoc_opt "params" fields in
        { meth; params }
    | j -> Util.json_error "Expected object for notification" j

  let request_of_yojson = function
    | `Assoc fields ->
        let id =
          match List.assoc_opt "id" fields with
          | Some id_json -> Id.t_of_yojson id_json
          | _ -> Util.json_error "Missing or invalid 'id' field" (`Assoc fields)
        in
        let meth =
          match List.assoc_opt "method" fields with
          | Some (`String s) -> (
              try Method.of_string s
              with Failure msg -> Util.json_error "%s" (`String s) msg)
          | _ ->
              Util.json_error "Missing or invalid 'method' field"
                (`Assoc fields)
        in
        let params = List.assoc_opt "params" fields in
        let progress_token =
          match params with
          | Some (`Assoc param_fields) -> (
              match List.assoc_opt "_meta" param_fields with
              | Some (`Assoc meta_fields) -> (
                  match List.assoc_opt "progressToken" meta_fields with
                  | Some token_json ->
                      Some (ProgressToken.t_of_yojson token_json)
                  | None -> None)
              | _ -> None)
          | _ -> None
        in
        { id; meth; params; progress_token }
    | j -> Util.json_error "Expected object for request" j

  let response_of_yojson = function
    | `Assoc fields ->
        let id =
          match List.assoc_opt "id" fields with
          | Some id_json -> Id.t_of_yojson id_json
          | _ -> Util.json_error "Missing or invalid 'id' field" (`Assoc fields)
        in
        let result =
          match List.assoc_opt "result" fields with
          | Some result -> result
          | _ -> Util.json_error "Missing 'result' field" (`Assoc fields)
        in
        { id; result }
    | j -> Util.json_error "Expected object for response" j

  let error_of_yojson = function
    | `Assoc fields as json ->
        let id =
          match List.assoc_opt "id" fields with
          | Some id_json -> Id.t_of_yojson id_json
          | _ -> Util.json_error "Missing or invalid 'id' field" json
        in
        let error =
          match List.assoc_opt "error" fields with
          | Some (`Assoc error_fields) -> error_fields
          | _ -> Util.json_error "Missing or invalid 'error' field" json
        in
        let code =
          match List.assoc_opt "code" error with
          | Some (`Int code) -> code
          | _ ->
              Util.json_error "Missing or invalid 'code' field in error"
                (`Assoc error)
        in
        let message =
          match List.assoc_opt "message" error with
          | Some (`String msg) -> msg
          | _ ->
              Util.json_error "Missing or invalid 'message' field in error"
                (`Assoc error)
        in
        let data = List.assoc_opt "data" error in
        { id; code; message; data }
    | j -> Util.json_error "Expected object for error" j

  let t_of_yojson json =
    match json with
    | `Assoc fields ->
        let _jsonrpc =
          match List.assoc_opt "jsonrpc" fields with
          | Some (`String "2.0") -> ()
          | _ -> Util.json_error "Missing or invalid 'jsonrpc' field" json
        in
        if List.mem_assoc "method" fields then
          if List.mem_assoc "id" fields then Request (request_of_yojson json)
          else Notification (notification_of_yojson json)
        else if List.mem_assoc "result" fields then
          Response (response_of_yojson json)
        else if List.mem_assoc "error" fields then Error (error_of_yojson json)
        else Util.json_error "Invalid JSONRPC message format" json
    | j -> Util.json_error "Expected object for JSONRPC message" j

  let create_notification ?(params = None) ~meth () =
    Notification { meth; params }

  let create_request ?(params = None) ?(progress_token = None) ~id ~meth () =
    Request { id; meth; params; progress_token }

  let create_response ~id ~result = Response { id; result }

  let create_error ~id ~code ~message ?(data = None) () =
    Error { id; code; message; data }
end

(* MCP-specific request/response types *)

module Initialize = struct
  module Request = struct
    type t = {
      capabilities : Json.t; (* ClientCapabilities *)
      client_info : Implementation.t;
      protocol_version : string;
    }

    let yojson_of_t { capabilities; client_info; protocol_version } =
      `Assoc
        [
          ("capabilities", capabilities);
          ("clientInfo", Implementation.yojson_of_t client_info);
          ("protocolVersion", `String protocol_version);
        ]

    let t_of_yojson = function
      | `Assoc fields as json ->
          let capabilities =
            match List.assoc_opt "capabilities" fields with
            | Some json -> json
            | None -> Util.json_error "Missing capabilities field" json
          in
          let client_info =
            match List.assoc_opt "clientInfo" fields with
            | Some json -> Implementation.t_of_yojson json
            | None -> Util.json_error "Missing clientInfo field" json
          in
          let protocol_version =
            Util.get_string_field fields "protocolVersion" json
          in
          { capabilities; client_info; protocol_version }
      | j -> Util.json_error "Expected object for InitializeRequest" j

    let create ~capabilities ~client_info ~protocol_version =
      { capabilities; client_info; protocol_version }

    let to_jsonrpc ~id t =
      let params = yojson_of_t t in
      JSONRPCMessage.create_request ~id ~meth:Method.Initialize
        ~params:(Some params) ()
  end

  module Result = struct
    type t = {
      capabilities : Json.t; (* ServerCapabilities *)
      server_info : Implementation.t;
      protocol_version : string;
      instructions : string option;
      meta : Json.t option;
    }

    let yojson_of_t
        { capabilities; server_info; protocol_version; instructions; meta } =
      let assoc =
        [
          ("capabilities", capabilities);
          ("serverInfo", Implementation.yojson_of_t server_info);
          ("protocolVersion", `String protocol_version);
        ]
      in
      let assoc =
        match instructions with
        | Some instr -> ("instructions", `String instr) :: assoc
        | None -> assoc
      in
      let assoc =
        match meta with Some meta -> ("_meta", meta) :: assoc | None -> assoc
      in
      `Assoc assoc

    let t_of_yojson = function
      | `Assoc fields as json ->
          let capabilities =
            match List.assoc_opt "capabilities" fields with
            | Some json -> json
            | None -> Util.json_error "Missing capabilities field" json
          in
          let server_info =
            match List.assoc_opt "serverInfo" fields with
            | Some json -> Implementation.t_of_yojson json
            | None -> Util.json_error "Missing serverInfo field" json
          in
          let protocol_version =
            Util.get_string_field fields "protocolVersion" json
          in
          let instructions =
            Util.get_optional_string_field fields "instructions"
          in
          let meta = List.assoc_opt "_meta" fields in
          { capabilities; server_info; protocol_version; instructions; meta }
      | j -> Util.json_error "Expected object for InitializeResult" j

    let create ~capabilities ~server_info ~protocol_version ?instructions ?meta
        () =
      { capabilities; server_info; protocol_version; instructions; meta }

    let to_jsonrpc ~id t =
      JSONRPCMessage.create_response ~id ~result:(yojson_of_t t)
  end
end

module Initialized = struct
  module Notification = struct
    type t = { meta : Json.t option }

    let yojson_of_t { meta } =
      let assoc = [] in
      let assoc =
        match meta with Some meta -> ("_meta", meta) :: assoc | None -> assoc
      in
      `Assoc assoc

    let t_of_yojson = function
      | `Assoc fields ->
          let meta = List.assoc_opt "_meta" fields in
          { meta }
      | j -> Util.json_error "Expected object for InitializedNotification" j

    let create ?meta () = { meta }

    let to_jsonrpc t =
      let params =
        match yojson_of_t t with `Assoc [] -> None | json -> Some json
      in
      JSONRPCMessage.create_notification ~meth:Method.Initialized ~params ()
  end
end

(* Export the main interface for using the MCP protocol *)

let parse_message json = JSONRPCMessage.t_of_yojson json

let create_notification ?(params = None) ~meth () =
  JSONRPCMessage.create_notification ~params ~meth ()

let create_request ?(params = None) ?(progress_token = None) ~id ~meth () =
  JSONRPCMessage.create_request ~params ~progress_token ~id ~meth ()

let create_response = JSONRPCMessage.create_response
let create_error = JSONRPCMessage.create_error

(* Content type constructors *)
let make_text_content text = Text TextContent.{ text; annotations = None }

let make_image_content data mime_type =
  Image ImageContent.{ data; mime_type; annotations = None }

let make_audio_content data mime_type =
  Audio AudioContent.{ data; mime_type; annotations = None }

let make_resource_text_content uri text mime_type =
  Resource
    EmbeddedResource.
      {
        resource = `Text TextResourceContents.{ uri; text; mime_type };
        annotations = None;
      }

let make_resource_blob_content uri blob mime_type =
  Resource
    EmbeddedResource.
      {
        resource = `Blob BlobResourceContents.{ uri; blob; mime_type };
        annotations = None;
      }
