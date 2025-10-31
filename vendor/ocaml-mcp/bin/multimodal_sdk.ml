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

(* Helper for extracting integer value from JSON *)
let get_int_param json name =
  match json with
  | `Assoc fields -> (
      match List.assoc_opt name fields with
      | Some (`Int value) -> value
      | Some (`String value) -> int_of_string value
      | _ ->
          raise
            (Failure (Printf.sprintf "Missing or invalid parameter: %s" name)))
  | _ -> raise (Failure "Expected JSON object")

(* Base64 encoding - simplified version *)
module Base64 = struct
  let encode_char idx =
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/".[idx]

  let encode s =
    let len = String.length s in
    let result = Bytes.create ((len + 2) / 3 * 4) in

    let rec loop i j =
      if i >= len then j
      else
        let n =
          let n = Char.code s.[i] lsl 16 in
          let n =
            if i + 1 < len then n lor (Char.code s.[i + 1] lsl 8) else n
          in
          if i + 2 < len then n lor Char.code s.[i + 2] else n
        in
        Bytes.set result j (encode_char ((n lsr 18) land 63));
        Bytes.set result (j + 1) (encode_char ((n lsr 12) land 63));
        Bytes.set result (j + 2)
          (if i + 1 < len then encode_char ((n lsr 6) land 63) else '=');
        Bytes.set result (j + 3)
          (if i + 2 < len then encode_char (n land 63) else '=');
        loop (i + 3) (j + 4)
    in
    Bytes.sub_string result 0 (loop 0 0)
end

(* Generate a simple GIF format image *)
let generate_random_image width height =
  (* Ensure dimensions are reasonable *)
  let width = min 256 (max 16 width) in
  let height = min 256 (max 16 height) in

  (* Create a buffer for GIF data *)
  let buf = Buffer.create 1024 in

  (* GIF Header - "GIF89a" *)
  Buffer.add_string buf "GIF89a";

  (* Logical Screen Descriptor *)
  (* Width - 2 bytes little endian *)
  Buffer.add_char buf (Char.chr (width land 0xff));
  Buffer.add_char buf (Char.chr ((width lsr 8) land 0xff));

  (* Height - 2 bytes little endian *)
  Buffer.add_char buf (Char.chr (height land 0xff));
  Buffer.add_char buf (Char.chr ((height lsr 8) land 0xff));

  (* Packed fields - 1 byte:
     Global Color Table Flag - 1 bit (1)
     Color Resolution - 3 bits (7 = 8 bits per color)
     Sort Flag - 1 bit (0)
     Size of Global Color Table - 3 bits (2 = 8 colors) *)
  Buffer.add_char buf (Char.chr 0xF2);

  (* Background color index - 1 byte *)
  Buffer.add_char buf (Char.chr 0);

  (* Pixel aspect ratio - 1 byte *)
  Buffer.add_char buf (Char.chr 0);

  (* Global Color Table - 8 colors x 3 bytes (R,G,B) *)
  (* Simple 8-color palette *)
  Buffer.add_string buf "\xFF\xFF\xFF";
  (* White (0) *)
  Buffer.add_string buf "\xFF\x00\x00";
  (* Red (1) *)
  Buffer.add_string buf "\x00\xFF\x00";
  (* Green (2) *)
  Buffer.add_string buf "\x00\x00\xFF";
  (* Blue (3) *)
  Buffer.add_string buf "\xFF\xFF\x00";
  (* Yellow (4) *)
  Buffer.add_string buf "\xFF\x00\xFF";
  (* Magenta (5) *)
  Buffer.add_string buf "\x00\xFF\xFF";
  (* Cyan (6) *)
  Buffer.add_string buf "\x00\x00\x00";

  (* Black (7) *)

  (* Graphics Control Extension (optional) *)
  Buffer.add_char buf (Char.chr 0x21);
  (* Extension Introducer *)
  Buffer.add_char buf (Char.chr 0xF9);
  (* Graphic Control Label *)
  Buffer.add_char buf (Char.chr 0x04);
  (* Block Size *)
  Buffer.add_char buf (Char.chr 0x01);
  (* Packed field: 1 bit for transparency *)
  Buffer.add_char buf (Char.chr 0x00);
  (* Delay time (1/100s) - 2 bytes *)
  Buffer.add_char buf (Char.chr 0x00);
  Buffer.add_char buf (Char.chr 0x00);
  (* Transparent color index *)
  Buffer.add_char buf (Char.chr 0x00);

  (* Block terminator *)

  (* Image Descriptor *)
  Buffer.add_char buf (Char.chr 0x2C);
  (* Image Separator *)
  Buffer.add_char buf (Char.chr 0x00);
  (* Left position - 2 bytes *)
  Buffer.add_char buf (Char.chr 0x00);
  Buffer.add_char buf (Char.chr 0x00);
  (* Top position - 2 bytes *)
  Buffer.add_char buf (Char.chr 0x00);

  (* Image width - 2 bytes little endian *)
  Buffer.add_char buf (Char.chr (width land 0xff));
  Buffer.add_char buf (Char.chr ((width lsr 8) land 0xff));

  (* Image height - 2 bytes little endian *)
  Buffer.add_char buf (Char.chr (height land 0xff));
  Buffer.add_char buf (Char.chr ((height lsr 8) land 0xff));

  (* Packed fields - 1 byte - no local color table *)
  Buffer.add_char buf (Char.chr 0x00);

  (* LZW Minimum Code Size - 1 byte *)
  Buffer.add_char buf (Char.chr 0x03);

  (* Minimum code size 3 for 8 colors *)

  (* Generate a simple image - a checkerboard pattern *)
  let step = width / 8 in
  let image_data = Buffer.create (width * height / 4) in

  (* Very simple LZW compression - just store raw clear codes and color indexes *)
  (* Start with Clear code *)
  Buffer.add_char image_data (Char.chr 0x08);

  (* Clear code 8 *)

  (* For very simple encoding, we'll just use a sequence of color indexes *)
  for y = 0 to height - 1 do
    for x = 0 to width - 1 do
      (* Checkerboard pattern with different colors *)
      let color =
        if ((x / step) + (y / step)) mod 2 = 0 then 3 (* Blue *)
        else 1 (* Red *)
      in
      Buffer.add_char image_data (Char.chr color)
    done
  done;

  (* End with End of Information code *)
  Buffer.add_char image_data (Char.chr 0x09);

  (* Add image data blocks - GIF uses 255-byte max chunks *)
  let data = Buffer.contents image_data in
  let data_len = String.length data in
  let pos = ref 0 in

  while !pos < data_len do
    let chunk_size = min 255 (data_len - !pos) in
    Buffer.add_char buf (Char.chr chunk_size);
    for i = 0 to chunk_size - 1 do
      Buffer.add_char buf (String.get data (!pos + i))
    done;
    pos := !pos + chunk_size
  done;

  (* Zero-length block to end the image data *)
  Buffer.add_char buf (Char.chr 0x00);

  (* GIF Trailer *)
  Buffer.add_char buf (Char.chr 0x3B);

  (* Base64 encode the GIF data *)
  Base64.encode (Buffer.contents buf)

(* Helper to write 32-bit little endian integer *)
let write_int32_le buf n =
  Buffer.add_char buf (Char.chr (n land 0xff));
  Buffer.add_char buf (Char.chr ((n lsr 8) land 0xff));
  Buffer.add_char buf (Char.chr ((n lsr 16) land 0xff));
  Buffer.add_char buf (Char.chr ((n lsr 24) land 0xff))

(* Helper to write 16-bit little endian integer *)
let write_int16_le buf n =
  Buffer.add_char buf (Char.chr (n land 0xff));
  Buffer.add_char buf (Char.chr ((n lsr 8) land 0xff))

(* Generate a simple WAV file with sine wave *)
let generate_sine_wave_audio frequency duration =
  (* WAV header *)
  let sample_rate = 8000 in
  let num_samples = sample_rate * duration in
  let header_buf = Buffer.create 44 in

  (* Fill WAV header properly *)
  Buffer.add_string header_buf "RIFF";
  write_int32_le header_buf (36 + (num_samples * 2));
  (* File size minus 8 *)
  Buffer.add_string header_buf "WAVE";

  (* Format chunk *)
  Buffer.add_string header_buf "fmt ";
  write_int32_le header_buf 16;
  (* Format chunk size *)
  write_int16_le header_buf 1;
  (* PCM format *)
  write_int16_le header_buf 1;
  (* Mono *)
  write_int32_le header_buf sample_rate;
  (* Sample rate *)
  write_int32_le header_buf (sample_rate * 2);
  (* Byte rate *)
  write_int16_le header_buf 2;
  (* Block align *)
  write_int16_le header_buf 16;

  (* Bits per sample *)

  (* Data chunk *)
  Buffer.add_string header_buf "data";
  write_int32_le header_buf (num_samples * 2);

  (* Data size *)

  (* Generate sine wave samples *)
  let samples_buf = Buffer.create (num_samples * 2) in
  let amplitude = 16384.0 in
  (* 16-bit with headroom *)

  for i = 0 to num_samples - 1 do
    let t = float_of_int i /. float_of_int sample_rate in
    let value = amplitude *. sin (2.0 *. Float.pi *. frequency *. t) in
    let sample = int_of_float value in

    (* Convert to 16-bit little-endian *)
    let sample = if sample < 0 then sample + 65536 else sample in
    write_int16_le samples_buf sample
  done;

  (* Combine header and samples, then encode as Base64 *)
  let wav_data = Buffer.contents header_buf ^ Buffer.contents samples_buf in
  Base64.encode wav_data

(* Create a server *)
let server =
  create_server ~name:"OCaml MCP Multimodal Example" ~version:"0.1.0"
    ~protocol_version:"2024-11-05" ()
  |> fun server ->
  (* Set default capabilities *)
  configure_server server ~with_tools:true ~with_resources:true
    ~with_prompts:true ()

(* Define and register a multimodal tool that returns text, images, and audio *)
let _ =
  add_tool server ~name:"multimodal_demo"
    ~description:"Demonstrates multimodal content with text, image, and audio"
    ~schema_properties:
      [
        ("width", "integer", "Width of the generated image (pixels)");
        ("height", "integer", "Height of the generated image (pixels)");
        ("frequency", "integer", "Frequency of the generated audio tone (Hz)");
        ("duration", "integer", "Duration of the generated audio (seconds)");
        ("message", "string", "Text message to include");
      ]
    ~schema_required:[ "message" ]
    (fun args ->
      try
        (* Extract parameters with defaults if not provided *)
        let message = get_string_param args "message" in
        let width = try get_int_param args "width" with _ -> 128 in
        let height = try get_int_param args "height" with _ -> 128 in
        let frequency = try get_int_param args "frequency" with _ -> 440 in
        let duration = try get_int_param args "duration" with _ -> 1 in

        (* Generate image and audio data *)
        let image_data = generate_random_image width height in
        let audio_data =
          generate_sine_wave_audio (float_of_int frequency) duration
        in

        (* Create a multimodal tool result *)
        Tool.create_tool_result
          [
            Mcp.make_text_content message;
            Mcp.make_image_content image_data "image/gif";
            Mcp.make_audio_content audio_data "audio/wav";
          ]
          ~is_error:false
      with Failure msg ->
        Logs.err (fun m -> m "Error in multimodal tool: %s" msg);
        Tool.create_tool_result
          [ Mcp.make_text_content (Printf.sprintf "Error: %s" msg) ]
          ~is_error:true)

(* Define and register a tool for generating only images *)
let _ =
  add_tool server ~name:"generate_image"
    ~description:"Generates a random image with specified dimensions"
    ~schema_properties:
      [
        ("width", "integer", "Width of the generated image (pixels)");
        ("height", "integer", "Height of the generated image (pixels)");
      ]
    ~schema_required:[ "width"; "height" ]
    (fun args ->
      try
        let width = get_int_param args "width" in
        let height = get_int_param args "height" in

        if width < 1 || width > 1024 || height < 1 || height > 1024 then
          Tool.create_tool_result
            [
              Mcp.make_text_content
                "Error: Dimensions must be between 1 and 1024 pixels";
            ]
            ~is_error:true
        else
          let image_data = generate_random_image width height in
          Tool.create_tool_result
            [ Mcp.make_image_content image_data "image/gif" ]
            ~is_error:false
      with Failure msg ->
        Logs.err (fun m -> m "Error in generate_image tool: %s" msg);
        Tool.create_tool_result
          [ Mcp.make_text_content (Printf.sprintf "Error: %s" msg) ]
          ~is_error:true)

(* Define and register a tool for generating only audio *)
let _ =
  add_tool server ~name:"generate_audio"
    ~description:"Generates an audio tone with specified frequency and duration"
    ~schema_properties:
      [
        ("frequency", "integer", "Frequency of the tone in Hz (20-20000)");
        ("duration", "integer", "Duration of the tone in seconds (1-10)");
      ]
    ~schema_required:[ "frequency"; "duration" ]
    (fun args ->
      try
        let frequency = get_int_param args "frequency" in
        let duration = get_int_param args "duration" in

        if frequency < 20 || frequency > 20000 then
          Tool.create_tool_result
            [
              Mcp.make_text_content
                "Error: Frequency must be between 20Hz and 20,000Hz";
            ]
            ~is_error:true
        else if duration < 1 || duration > 10 then
          Tool.create_tool_result
            [
              Mcp.make_text_content
                "Error: Duration must be between 1 and 10 seconds";
            ]
            ~is_error:true
        else
          let audio_data =
            generate_sine_wave_audio (float_of_int frequency) duration
          in
          Tool.create_tool_result
            [ Mcp.make_audio_content audio_data "audio/wav" ]
            ~is_error:false
      with Failure msg ->
        Logs.err (fun m -> m "Error in generate_audio tool: %s" msg);
        Tool.create_tool_result
          [ Mcp.make_text_content (Printf.sprintf "Error: %s" msg) ]
          ~is_error:true)

(* Define and register a resource template example with multimodal content *)
let _ =
  add_resource_template server ~uri_template:"multimodal://{name}"
    ~name:"Multimodal Greeting"
    ~description:"Get a multimodal greeting with text, image and audio"
    ~mime_type:"application/json" (fun params ->
      match params with
      | [ name ] ->
          let greeting =
            Printf.sprintf "Hello, %s! Welcome to the multimodal MCP example."
              name
          in
          let image_data = generate_random_image 128 128 in
          let audio_data = generate_sine_wave_audio 440.0 1 in

          Printf.sprintf
            {|
        {
          "greeting": "%s",
          "image": {
            "data": "%s",
            "mimeType": "image/gif"
          },
          "audio": {
            "data": "%s",
            "mimeType": "audio/wav"
          }
        }
      |}
            greeting image_data audio_data
      | _ -> Printf.sprintf {|{"error": "Invalid parameters"}|})

(* Run the server with the default scheduler *)
let () =
  Logs.set_reporter (Logs.format_reporter ());
  Random.self_init ();
  (* Initialize random generator *)
  Eio_main.run @@ fun env -> Mcp_server.run_server env server
