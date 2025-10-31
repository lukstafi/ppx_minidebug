(* Mcp_message - High-level RPC message definitions for Model Context Protocol *)

open Mcp
open Jsonrpc

(* Resources/List *)
module ResourcesList = struct
  module Request = struct
    type t = { cursor : Cursor.t option }

    let yojson_of_t { cursor } =
      let assoc = [] in
      let assoc =
        match cursor with
        | Some c -> ("cursor", Cursor.yojson_of_t c) :: assoc
        | None -> assoc
      in
      `Assoc assoc

    let t_of_yojson = function
      | `Assoc fields ->
          let cursor =
            List.assoc_opt "cursor" fields |> Option.map Cursor.t_of_yojson
          in
          { cursor }
      | j -> Util.json_error "Expected object for ResourcesList.Request.t" j
  end

  module Resource = struct
    type t = {
      uri : string;
      name : string;
      description : string option;
      mime_type : string option;
      size : int option;
    }

    let yojson_of_t { uri; name; description; mime_type; size } =
      let assoc = [ ("uri", `String uri); ("name", `String name) ] in
      let assoc =
        match description with
        | Some desc -> ("description", `String desc) :: assoc
        | None -> assoc
      in
      let assoc =
        match mime_type with
        | Some mime -> ("mimeType", `String mime) :: assoc
        | None -> assoc
      in
      let assoc =
        match size with Some s -> ("size", `Int s) :: assoc | None -> assoc
      in
      `Assoc assoc

    let t_of_yojson = function
      | `Assoc fields as json ->
          let uri =
            match List.assoc_opt "uri" fields with
            | Some (`String s) -> s
            | _ -> Util.json_error "Missing or invalid 'uri' field" json
          in
          let name =
            match List.assoc_opt "name" fields with
            | Some (`String s) -> s
            | _ -> Util.json_error "Missing or invalid 'name' field" json
          in
          let description =
            List.assoc_opt "description" fields
            |> Option.map (function
                 | `String s -> s
                 | j -> Util.json_error "Expected string for description" j)
          in
          let mime_type =
            List.assoc_opt "mimeType" fields
            |> Option.map (function
                 | `String s -> s
                 | j -> Util.json_error "Expected string for mimeType" j)
          in
          let size =
            List.assoc_opt "size" fields
            |> Option.map (function
                 | `Int i -> i
                 | j -> Util.json_error "Expected int for size" j)
          in
          { uri; name; description; mime_type; size }
      | j -> Util.json_error "Expected object for ResourcesList.Resource.t" j
  end

  module Response = struct
    type t = { resources : Resource.t list; next_cursor : Cursor.t option }

    let yojson_of_t { resources; next_cursor } =
      let assoc =
        [ ("resources", `List (List.map Resource.yojson_of_t resources)) ]
      in
      let assoc =
        match next_cursor with
        | Some c -> ("nextCursor", Cursor.yojson_of_t c) :: assoc
        | None -> assoc
      in
      `Assoc assoc

    let t_of_yojson = function
      | `Assoc fields as json ->
          let resources =
            match List.assoc_opt "resources" fields with
            | Some (`List items) -> List.map Resource.t_of_yojson items
            | _ -> Util.json_error "Missing or invalid 'resources' field" json
          in
          let next_cursor =
            List.assoc_opt "nextCursor" fields |> Option.map Cursor.t_of_yojson
          in
          { resources; next_cursor }
      | j -> Util.json_error "Expected object for ResourcesList.Response.t" j
  end

  (* Request/response creation helpers *)
  let create_request ?cursor ?id () =
    let id = match id with Some i -> i | None -> `Int (Random.int 10000) in
    let params = Request.yojson_of_t { cursor } in
    JSONRPCMessage.create_request ~id ~meth:Method.ResourcesList
      ~params:(Some params) ()

  let create_response ~id ~resources ?next_cursor () =
    let result = Response.yojson_of_t { resources; next_cursor } in
    JSONRPCMessage.create_response ~id ~result
end

(* Resources/Templates/List *)
module ListResourceTemplatesRequest = struct
  type t = { cursor : Cursor.t option }

  let yojson_of_t { cursor } =
    let assoc = [] in
    let assoc =
      match cursor with
      | Some c -> ("cursor", Cursor.yojson_of_t c) :: assoc
      | None -> assoc
    in
    `Assoc assoc

  let t_of_yojson = function
    | `Assoc fields ->
        let cursor =
          List.assoc_opt "cursor" fields |> Option.map Cursor.t_of_yojson
        in
        { cursor }
    | j ->
        Util.json_error "Expected object for ListResourceTemplatesRequest.t" j
end

(* Resources/Templates/List Response *)
module ListResourceTemplatesResult = struct
  module ResourceTemplate = struct
    type t = {
      uri_template : string;
      name : string;
      description : string option;
      mime_type : string option;
    }

    let yojson_of_t { uri_template; name; description; mime_type } =
      let assoc =
        [ ("uriTemplate", `String uri_template); ("name", `String name) ]
      in
      let assoc =
        match description with
        | Some desc -> ("description", `String desc) :: assoc
        | None -> assoc
      in
      let assoc =
        match mime_type with
        | Some mime -> ("mimeType", `String mime) :: assoc
        | None -> assoc
      in
      `Assoc assoc

    let t_of_yojson = function
      | `Assoc fields as json ->
          let uri_template =
            match List.assoc_opt "uriTemplate" fields with
            | Some (`String s) -> s
            | _ -> Util.json_error "Missing or invalid 'uriTemplate' field" json
          in
          let name =
            match List.assoc_opt "name" fields with
            | Some (`String s) -> s
            | _ -> Util.json_error "Missing or invalid 'name' field" json
          in
          let description =
            List.assoc_opt "description" fields
            |> Option.map (function
                 | `String s -> s
                 | j -> Util.json_error "Expected string for description" j)
          in
          let mime_type =
            List.assoc_opt "mimeType" fields
            |> Option.map (function
                 | `String s -> s
                 | j -> Util.json_error "Expected string for mimeType" j)
          in
          { uri_template; name; description; mime_type }
      | j ->
          Util.json_error
            "Expected object for ListResourceTemplatesResult.ResourceTemplate.t"
            j
  end

  type t = {
    resource_templates : ResourceTemplate.t list;
    next_cursor : Cursor.t option;
  }

  let yojson_of_t { resource_templates; next_cursor } =
    let assoc =
      [
        ( "resourceTemplates",
          `List (List.map ResourceTemplate.yojson_of_t resource_templates) );
      ]
    in
    let assoc =
      match next_cursor with
      | Some c -> ("nextCursor", Cursor.yojson_of_t c) :: assoc
      | None -> assoc
    in
    `Assoc assoc

  let t_of_yojson = function
    | `Assoc fields as json ->
        let resource_templates =
          match List.assoc_opt "resourceTemplates" fields with
          | Some (`List items) -> List.map ResourceTemplate.t_of_yojson items
          | _ ->
              Util.json_error "Missing or invalid 'resourceTemplates' field"
                json
        in
        let next_cursor =
          List.assoc_opt "nextCursor" fields |> Option.map Cursor.t_of_yojson
        in
        { resource_templates; next_cursor }
    | j -> Util.json_error "Expected object for ListResourceTemplatesResult.t" j

  (* Request/response creation helpers *)
  let create_request ?cursor ?id () =
    let id = match id with Some i -> i | None -> `Int (Random.int 10000) in
    let params = ListResourceTemplatesRequest.yojson_of_t { cursor } in
    JSONRPCMessage.create_request ~id ~meth:Method.ResourceTemplatesList
      ~params:(Some params) ()

  let create_response ~id ~resource_templates ?next_cursor () =
    let result = yojson_of_t { resource_templates; next_cursor } in
    JSONRPCMessage.create_response ~id ~result
end

(* Resources/Read *)
module ResourcesRead = struct
  module Request = struct
    type t = { uri : string }

    let yojson_of_t { uri } = `Assoc [ ("uri", `String uri) ]

    let t_of_yojson = function
      | `Assoc fields as json ->
          let uri =
            match List.assoc_opt "uri" fields with
            | Some (`String s) -> s
            | _ -> Util.json_error "Missing or invalid 'uri' field" json
          in
          { uri }
      | j -> Util.json_error "Expected object for ResourcesRead.Request.t" j
  end

  module ResourceContent = struct
    type t =
      | TextResource of TextResourceContents.t
      | BlobResource of BlobResourceContents.t

    let yojson_of_t = function
      | TextResource tr -> TextResourceContents.yojson_of_t tr
      | BlobResource br -> BlobResourceContents.yojson_of_t br

    let t_of_yojson json =
      match json with
      | `Assoc fields ->
          if List.mem_assoc "text" fields then
            TextResource (TextResourceContents.t_of_yojson json)
          else if List.mem_assoc "blob" fields then
            BlobResource (BlobResourceContents.t_of_yojson json)
          else Util.json_error "Invalid resource content" json
      | j ->
          Util.json_error "Expected object for ResourcesRead.ResourceContent.t"
            j
  end

  module Response = struct
    type t = { contents : ResourceContent.t list }

    let yojson_of_t { contents } =
      `Assoc
        [ ("contents", `List (List.map ResourceContent.yojson_of_t contents)) ]

    let t_of_yojson = function
      | `Assoc fields as json ->
          let contents =
            match List.assoc_opt "contents" fields with
            | Some (`List items) -> List.map ResourceContent.t_of_yojson items
            | _ -> Util.json_error "Missing or invalid 'contents' field" json
          in
          { contents }
      | j -> Util.json_error "Expected object for ResourcesRead.Response.t" j
  end

  (* Request/response creation helpers *)
  let create_request ~uri ?id () =
    let id = match id with Some i -> i | None -> `Int (Random.int 10000) in
    let params = Request.yojson_of_t { uri } in
    JSONRPCMessage.create_request ~id ~meth:Method.ResourcesRead
      ~params:(Some params) ()

  let create_response ~id ~contents () =
    let result = Response.yojson_of_t { contents } in
    JSONRPCMessage.create_response ~id ~result
end

(* Tools/List *)
module ToolsList = struct
  module Request = struct
    type t = { cursor : Cursor.t option }

    let yojson_of_t { cursor } =
      let assoc = [] in
      let assoc =
        match cursor with
        | Some c -> ("cursor", Cursor.yojson_of_t c) :: assoc
        | None -> assoc
      in
      `Assoc assoc

    let t_of_yojson = function
      | `Assoc fields ->
          let cursor =
            List.assoc_opt "cursor" fields |> Option.map Cursor.t_of_yojson
          in
          { cursor }
      | j -> Util.json_error "Expected object for ToolsList.Request.t" j
  end

  module Tool = struct
    type t = {
      name : string;
      description : string option;
      input_schema : Json.t;
      annotations : Json.t option;
    }

    let yojson_of_t { name; description; input_schema; annotations } =
      let assoc = [ ("name", `String name); ("inputSchema", input_schema) ] in
      let assoc =
        match description with
        | Some desc -> ("description", `String desc) :: assoc
        | None -> assoc
      in
      let assoc =
        match annotations with
        | Some anno -> ("annotations", anno) :: assoc
        | None -> assoc
      in
      `Assoc assoc

    let t_of_yojson = function
      | `Assoc fields as json ->
          let name =
            match List.assoc_opt "name" fields with
            | Some (`String s) -> s
            | _ -> Util.json_error "Missing or invalid 'name' field" json
          in
          let description =
            List.assoc_opt "description" fields
            |> Option.map (function
                 | `String s -> s
                 | j -> Util.json_error "Expected string for description" j)
          in
          let input_schema =
            match List.assoc_opt "inputSchema" fields with
            | Some schema -> schema
            | None -> Util.json_error "Missing 'inputSchema' field" json
          in
          let annotations = List.assoc_opt "annotations" fields in
          { name; description; input_schema; annotations }
      | j -> Util.json_error "Expected object for ToolsList.Tool.t" j
  end

  module Response = struct
    type t = { tools : Tool.t list; next_cursor : Cursor.t option }

    let yojson_of_t { tools; next_cursor } =
      let assoc = [ ("tools", `List (List.map Tool.yojson_of_t tools)) ] in
      let assoc =
        match next_cursor with
        | Some c -> ("nextCursor", Cursor.yojson_of_t c) :: assoc
        | None -> assoc
      in
      `Assoc assoc

    let t_of_yojson = function
      | `Assoc fields as json ->
          let tools =
            match List.assoc_opt "tools" fields with
            | Some (`List items) -> List.map Tool.t_of_yojson items
            | _ -> Util.json_error "Missing or invalid 'tools' field" json
          in
          let next_cursor =
            List.assoc_opt "nextCursor" fields |> Option.map Cursor.t_of_yojson
          in
          { tools; next_cursor }
      | j -> Util.json_error "Expected object for ToolsList.Response.t" j
  end

  (* Request/response creation helpers *)
  let create_request ?cursor ?id () =
    let id = match id with Some i -> i | None -> `Int (Random.int 10000) in
    let params = Request.yojson_of_t { cursor } in
    JSONRPCMessage.create_request ~id ~meth:Method.ToolsList
      ~params:(Some params) ()

  let create_response ~id ~tools ?next_cursor () =
    let result = Response.yojson_of_t { tools; next_cursor } in
    JSONRPCMessage.create_response ~id ~result
end

(* Tools/Call *)
module ToolsCall = struct
  module Request = struct
    type t = { name : string; arguments : Json.t }

    let yojson_of_t { name; arguments } =
      `Assoc [ ("name", `String name); ("arguments", arguments) ]

    let t_of_yojson = function
      | `Assoc fields as json ->
          let name =
            match List.assoc_opt "name" fields with
            | Some (`String s) -> s
            | _ -> Util.json_error "Missing or invalid 'name' field" json
          in
          let arguments =
            match List.assoc_opt "arguments" fields with
            | Some json -> json
            | None -> Util.json_error "Missing 'arguments' field" json
          in
          { name; arguments }
      | j -> Util.json_error "Expected object for ToolsCall.Request.t" j
  end

  module ToolContent = struct
    type t =
      | Text of TextContent.t
      | Image of ImageContent.t
      | Audio of AudioContent.t
      | Resource of EmbeddedResource.t

    let yojson_of_t = function
      | Text t -> TextContent.yojson_of_t t
      | Image i -> ImageContent.yojson_of_t i
      | Audio a -> AudioContent.yojson_of_t a
      | Resource r -> EmbeddedResource.yojson_of_t r

    let t_of_yojson json =
      match json with
      | `Assoc fields -> (
          match List.assoc_opt "type" fields with
          | Some (`String "text") -> Text (TextContent.t_of_yojson json)
          | Some (`String "image") -> Image (ImageContent.t_of_yojson json)
          | Some (`String "audio") -> Audio (AudioContent.t_of_yojson json)
          | Some (`String "resource") ->
              Resource (EmbeddedResource.t_of_yojson json)
          | _ -> Util.json_error "Invalid or missing content type" json)
      | j -> Util.json_error "Expected object for ToolsCall.ToolContent.t" j
  end

  module Response = struct
    type t = { content : ToolContent.t list; is_error : bool }

    let yojson_of_t { content; is_error } =
      `Assoc
        [
          ("content", `List (List.map ToolContent.yojson_of_t content));
          ("isError", `Bool is_error);
        ]

    let t_of_yojson = function
      | `Assoc fields as json ->
          let content =
            match List.assoc_opt "content" fields with
            | Some (`List items) -> List.map ToolContent.t_of_yojson items
            | _ -> Util.json_error "Missing or invalid 'content' field" json
          in
          let is_error =
            match List.assoc_opt "isError" fields with
            | Some (`Bool b) -> b
            | _ -> false
          in
          { content; is_error }
      | j -> Util.json_error "Expected object for ToolsCall.Response.t" j
  end

  (* Request/response creation helpers *)
  let create_request ~name ~arguments ?id () =
    let id = match id with Some i -> i | None -> `Int (Random.int 10000) in
    let params = Request.yojson_of_t { name; arguments } in
    JSONRPCMessage.create_request ~id ~meth:Method.ToolsCall
      ~params:(Some params) ()

  let create_response ~id ~content ~is_error () =
    let result = Response.yojson_of_t { content; is_error } in
    JSONRPCMessage.create_response ~id ~result
end

(* Prompts/List *)
module PromptsList = struct
  module PromptArgument = struct
    type t = { name : string; description : string option; required : bool }

    let yojson_of_t { name; description; required } =
      let assoc = [ ("name", `String name) ] in
      let assoc =
        match description with
        | Some desc -> ("description", `String desc) :: assoc
        | None -> assoc
      in
      let assoc =
        if required then ("required", `Bool true) :: assoc else assoc
      in
      `Assoc assoc

    let t_of_yojson = function
      | `Assoc fields as json ->
          let name =
            match List.assoc_opt "name" fields with
            | Some (`String s) -> s
            | _ -> Util.json_error "Missing or invalid 'name' field" json
          in
          let description =
            List.assoc_opt "description" fields
            |> Option.map (function
                 | `String s -> s
                 | j -> Util.json_error "Expected string for description" j)
          in
          let required =
            match List.assoc_opt "required" fields with
            | Some (`Bool b) -> b
            | _ -> false
          in
          { name; description; required }
      | j ->
          Util.json_error "Expected object for PromptsList.PromptArgument.t" j
  end

  module Prompt = struct
    type t = {
      name : string;
      description : string option;
      arguments : PromptArgument.t list;
    }

    let yojson_of_t { name; description; arguments } =
      let assoc = [ ("name", `String name) ] in
      let assoc =
        match description with
        | Some desc -> ("description", `String desc) :: assoc
        | None -> assoc
      in
      let assoc =
        if arguments <> [] then
          ("arguments", `List (List.map PromptArgument.yojson_of_t arguments))
          :: assoc
        else assoc
      in
      `Assoc assoc

    let t_of_yojson = function
      | `Assoc fields as json ->
          let name =
            match List.assoc_opt "name" fields with
            | Some (`String s) -> s
            | _ -> Util.json_error "Missing or invalid 'name' field" json
          in
          let description =
            List.assoc_opt "description" fields
            |> Option.map (function
                 | `String s -> s
                 | j -> Util.json_error "Expected string for description" j)
          in
          let arguments =
            match List.assoc_opt "arguments" fields with
            | Some (`List items) -> List.map PromptArgument.t_of_yojson items
            | _ -> []
          in
          { name; description; arguments }
      | j -> Util.json_error "Expected object for PromptsList.Prompt.t" j
  end

  module Request = struct
    type t = { cursor : Cursor.t option }

    let yojson_of_t { cursor } =
      let assoc = [] in
      let assoc =
        match cursor with
        | Some c -> ("cursor", Cursor.yojson_of_t c) :: assoc
        | None -> assoc
      in
      `Assoc assoc

    let t_of_yojson = function
      | `Assoc fields ->
          let cursor =
            List.assoc_opt "cursor" fields |> Option.map Cursor.t_of_yojson
          in
          { cursor }
      | j -> Util.json_error "Expected object for PromptsList.Request.t" j
  end

  module Response = struct
    type t = { prompts : Prompt.t list; next_cursor : Cursor.t option }

    let yojson_of_t { prompts; next_cursor } =
      let assoc =
        [ ("prompts", `List (List.map Prompt.yojson_of_t prompts)) ]
      in
      let assoc =
        match next_cursor with
        | Some c -> ("nextCursor", Cursor.yojson_of_t c) :: assoc
        | None -> assoc
      in
      `Assoc assoc

    let t_of_yojson = function
      | `Assoc fields as json ->
          let prompts =
            match List.assoc_opt "prompts" fields with
            | Some (`List items) -> List.map Prompt.t_of_yojson items
            | _ -> Util.json_error "Missing or invalid 'prompts' field" json
          in
          let next_cursor =
            List.assoc_opt "nextCursor" fields |> Option.map Cursor.t_of_yojson
          in
          { prompts; next_cursor }
      | j -> Util.json_error "Expected object for PromptsList.Response.t" j
  end

  (* Request/response creation helpers *)
  let create_request ?cursor ?id () =
    let id = match id with Some i -> i | None -> `Int (Random.int 10000) in
    let params = Request.yojson_of_t { cursor } in
    JSONRPCMessage.create_request ~id ~meth:Method.PromptsList
      ~params:(Some params) ()

  let create_response ~id ~prompts ?next_cursor () =
    let result = Response.yojson_of_t { prompts; next_cursor } in
    JSONRPCMessage.create_response ~id ~result
end

(* Prompts/Get *)
module PromptsGet = struct
  module Request = struct
    type t = { name : string; arguments : (string * string) list }

    let yojson_of_t { name; arguments } =
      let args_json =
        `Assoc (List.map (fun (k, v) -> (k, `String v)) arguments)
      in
      `Assoc [ ("name", `String name); ("arguments", args_json) ]

    let t_of_yojson = function
      | `Assoc fields as json ->
          let name =
            match List.assoc_opt "name" fields with
            | Some (`String s) -> s
            | _ -> Util.json_error "Missing or invalid 'name' field" json
          in
          let arguments =
            match List.assoc_opt "arguments" fields with
            | Some (`Assoc args) ->
                List.map
                  (fun (k, v) ->
                    match v with
                    | `String s -> (k, s)
                    | _ ->
                        Util.json_error "Expected string value for argument" v)
                  args
            | _ -> []
          in
          { name; arguments }
      | j -> Util.json_error "Expected object for PromptsGet.Request.t" j
  end

  module Response = struct
    type t = { description : string option; messages : PromptMessage.t list }

    let yojson_of_t { description; messages } =
      let assoc =
        [ ("messages", `List (List.map PromptMessage.yojson_of_t messages)) ]
      in
      let assoc =
        match description with
        | Some desc -> ("description", `String desc) :: assoc
        | None -> assoc
      in
      `Assoc assoc

    let t_of_yojson = function
      | `Assoc fields as json ->
          let messages =
            match List.assoc_opt "messages" fields with
            | Some (`List items) -> List.map PromptMessage.t_of_yojson items
            | _ -> Util.json_error "Missing or invalid 'messages' field" json
          in
          let description =
            List.assoc_opt "description" fields
            |> Option.map (function
                 | `String s -> s
                 | j -> Util.json_error "Expected string for description" j)
          in
          { description; messages }
      | j -> Util.json_error "Expected object for PromptsGet.Response.t" j
  end

  (* Request/response creation helpers *)
  let create_request ~name ~arguments ?id () =
    let id = match id with Some i -> i | None -> `Int (Random.int 10000) in
    let params = Request.yojson_of_t { name; arguments } in
    JSONRPCMessage.create_request ~id ~meth:Method.PromptsGet
      ~params:(Some params) ()

  let create_response ~id ?description ~messages () =
    let result = Response.yojson_of_t { description; messages } in
    JSONRPCMessage.create_response ~id ~result
end

(* List Changed Notifications *)
module ListChanged = struct
  (* No parameters for these notifications *)

  let create_resources_notification () =
    JSONRPCMessage.create_notification ~meth:Method.ResourcesListChanged ()

  let create_tools_notification () =
    JSONRPCMessage.create_notification ~meth:Method.ToolsListChanged ()

  let create_prompts_notification () =
    JSONRPCMessage.create_notification ~meth:Method.PromptsListChanged ()
end

(* Resource Updated Notification *)
module ResourceUpdated = struct
  module Notification = struct
    type t = { uri : string }

    let yojson_of_t { uri } = `Assoc [ ("uri", `String uri) ]

    let t_of_yojson = function
      | `Assoc fields as json ->
          let uri =
            match List.assoc_opt "uri" fields with
            | Some (`String s) -> s
            | _ -> Util.json_error "Missing or invalid 'uri' field" json
          in
          { uri }
      | j ->
          Util.json_error "Expected object for ResourceUpdated.Notification.t" j
  end

  let create_notification ~uri () =
    let params = Notification.yojson_of_t { uri } in
    JSONRPCMessage.create_notification ~meth:Method.ResourcesUpdated
      ~params:(Some params) ()
end

(* Progress Notification *)
module Progress = struct
  module Notification = struct
    type t = {
      progress : float;
      total : float;
      progress_token : ProgressToken.t;
    }

    let yojson_of_t { progress; total; progress_token } =
      `Assoc
        [
          ("progress", `Float progress);
          ("total", `Float total);
          ("progressToken", ProgressToken.yojson_of_t progress_token);
        ]

    let t_of_yojson = function
      | `Assoc fields as json ->
          let progress =
            match List.assoc_opt "progress" fields with
            | Some (`Float f) -> f
            | _ -> Util.json_error "Missing or invalid 'progress' field" json
          in
          let total =
            match List.assoc_opt "total" fields with
            | Some (`Float f) -> f
            | _ -> Util.json_error "Missing or invalid 'total' field" json
          in
          let progress_token =
            match List.assoc_opt "progressToken" fields with
            | Some token -> ProgressToken.t_of_yojson token
            | _ ->
                Util.json_error "Missing or invalid 'progressToken' field" json
          in
          { progress; total; progress_token }
      | j -> Util.json_error "Expected object for Progress.Notification.t" j
  end

  let create_notification ~progress ~total ~progress_token () =
    let params = Notification.yojson_of_t { progress; total; progress_token } in
    JSONRPCMessage.create_notification ~meth:Method.Progress
      ~params:(Some params) ()
end

(* Type aliases for backward compatibility *)
type request = ResourcesList.Request.t
type response = ResourcesList.Response.t
type resource = ResourcesList.Resource.t
type resource_content = ResourcesRead.ResourceContent.t
type tool = ToolsList.Tool.t
type tool_content = ToolsCall.ToolContent.t
type prompt = PromptsList.Prompt.t
type prompt_argument = PromptsList.PromptArgument.t
