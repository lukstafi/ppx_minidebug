[@@@ocaml.ppx.context
  {
    tool_name = "ppx_driver";
    include_dirs = [];
    load_path = [];
    open_modules = [];
    for_package = None;
    debug = false;
    use_threads = false;
    use_vmthreads = false;
    recursive_types = false;
    principal = false;
    transparent_modules = false;
    unboxed_types = false;
    unsafe_string = false;
    cookies = []
  }]
module Debug_runtime = (Minidebug_runtime.Flushing)((val
  Minidebug_runtime.debug_ch "debugger_show_interrupts.log"))
;;()
let rec loop_exceeded (x : int) =
  (let __entry_id = Debug_runtime.get_entry_id () in
   ();
   if Debug_runtime.exceeds_max_children ()
   then
     (Debug_runtime.log_value_show ~descr:"loop_exceeded"
        ~entry_id:__entry_id ~v:"<max_num_children exceeded>";
      failwith "ppx_minidebug: max_num_children exceeded")
   else
     ((Debug_runtime.open_log_preamble_full
         ~fname:"test/test_debug_interrupts.ml" ~start_lnum:7
         ~start_colnum:33 ~end_lnum:9 ~end_colnum:55 ~message:"loop_exceeded"
         ~entry_id:__entry_id;
       Debug_runtime.log_value_show ~descr:"x" ~entry_id:__entry_id
         ~v:(((let open! ((Ppx_deriving_runtime)[@ocaml.warning "-A"]) in
                 fun x ->
                   Ppx_deriving_runtime.Format.asprintf "%a"
                     (fun fmt -> Ppx_deriving_runtime.Format.fprintf fmt "%d")
                     x)[@ocaml.warning "-A"]) x));
      if Debug_runtime.exceeds_max_nesting ()
      then
        (Debug_runtime.log_value_show ~descr:"loop_exceeded"
           ~entry_id:__entry_id ~v:"<max_nesting_depth exceeded>";
         Debug_runtime.close_log ();
         failwith "ppx_minidebug: max_nesting_depth exceeded")
      else
        (match let z : int =
                 let __entry_id = Debug_runtime.get_entry_id () in
                 ();
                 if Debug_runtime.exceeds_max_children ()
                 then
                   (Debug_runtime.log_value_show ~descr:"z"
                      ~entry_id:__entry_id ~v:"<max_num_children exceeded>";
                    failwith "ppx_minidebug: max_num_children exceeded")
                 else
                   (Debug_runtime.open_log_preamble_brief
                      ~fname:"test/test_debug_interrupts.ml" ~pos_lnum:8
                      ~pos_colnum:6 ~message:"z" ~entry_id:__entry_id;
                    if Debug_runtime.exceeds_max_nesting ()
                    then
                      (Debug_runtime.log_value_show ~descr:"z"
                         ~entry_id:__entry_id
                         ~v:"<max_nesting_depth exceeded>";
                       Debug_runtime.close_log ();
                       failwith "ppx_minidebug: max_nesting_depth exceeded")
                    else
                      (match (x - 1) / 2 with
                       | z as __res ->
                           ((();
                             Debug_runtime.log_value_show ~descr:"z"
                               ~entry_id:__entry_id
                               ~v:(((let open! ((Ppx_deriving_runtime)
                                       [@ocaml.warning "-A"]) in
                                       fun x ->
                                         Ppx_deriving_runtime.Format.asprintf
                                           "%a"
                                           (fun fmt ->
                                              Ppx_deriving_runtime.Format.fprintf
                                                fmt "%d") x)
                                     [@ocaml.warning "-A"]) z));
                            Debug_runtime.close_log ();
                            __res)
                       | exception e -> (Debug_runtime.close_log (); raise e))) in
               if x <= 0 then 0 else z + (loop_exceeded (z + (x / 2)))
         with
         | __res ->
             (Debug_runtime.log_value_show ~descr:"loop_exceeded"
                ~entry_id:__entry_id
                ~v:(((let open! ((Ppx_deriving_runtime)[@ocaml.warning "-A"]) in
                        fun x ->
                          Ppx_deriving_runtime.Format.asprintf "%a"
                            (fun fmt ->
                               Ppx_deriving_runtime.Format.fprintf fmt "%d")
                            x)[@ocaml.warning "-A"]) __res);
              Debug_runtime.close_log ();
              __res)
         | exception e -> (Debug_runtime.close_log (); raise e))) : int)
let () =
  try print_endline @@ (Int.to_string @@ (loop_exceeded 17))
  with | _ -> print_endline "Raised exception."
let bar () =
  (let __entry_id = Debug_runtime.get_entry_id () in
   ();
   if Debug_runtime.exceeds_max_children ()
   then
     (Debug_runtime.log_value_show ~descr:"bar" ~entry_id:__entry_id
        ~v:"<max_num_children exceeded>";
      failwith "ppx_minidebug: max_num_children exceeded")
   else
     (Debug_runtime.open_log_preamble_full
        ~fname:"test/test_debug_interrupts.ml" ~start_lnum:15
        ~start_colnum:19 ~end_lnum:19 ~end_colnum:6 ~message:"bar"
        ~entry_id:__entry_id;
      if Debug_runtime.exceeds_max_nesting ()
      then
        (Debug_runtime.log_value_show ~descr:"bar" ~entry_id:__entry_id
           ~v:"<max_nesting_depth exceeded>";
         Debug_runtime.close_log ();
         failwith "ppx_minidebug: max_nesting_depth exceeded")
      else
        (match for i = 0 to 100 do
                 let _baz : int =
                   let __entry_id = Debug_runtime.get_entry_id () in
                   ();
                   if Debug_runtime.exceeds_max_children ()
                   then
                     (Debug_runtime.log_value_show ~descr:"_baz"
                        ~entry_id:__entry_id ~v:"<max_num_children exceeded>";
                      failwith "ppx_minidebug: max_num_children exceeded")
                   else
                     (Debug_runtime.open_log_preamble_brief
                        ~fname:"test/test_debug_interrupts.ml" ~pos_lnum:17
                        ~pos_colnum:8 ~message:"_baz" ~entry_id:__entry_id;
                      if Debug_runtime.exceeds_max_nesting ()
                      then
                        (Debug_runtime.log_value_show ~descr:"_baz"
                           ~entry_id:__entry_id
                           ~v:"<max_nesting_depth exceeded>";
                         Debug_runtime.close_log ();
                         failwith "ppx_minidebug: max_nesting_depth exceeded")
                      else
                        (match i * 2 with
                         | _baz as __res ->
                             ((();
                               Debug_runtime.log_value_show ~descr:"_baz"
                                 ~entry_id:__entry_id
                                 ~v:(((let open! ((Ppx_deriving_runtime)
                                         [@ocaml.warning "-A"]) in
                                         fun x ->
                                           Ppx_deriving_runtime.Format.asprintf
                                             "%a"
                                             (fun fmt ->
                                                Ppx_deriving_runtime.Format.fprintf
                                                  fmt "%d") x)
                                       [@ocaml.warning "-A"]) _baz));
                              Debug_runtime.close_log ();
                              __res)
                         | exception e ->
                             (Debug_runtime.close_log (); raise e))) in
                 ()
               done
         with
         | __res ->
             (Debug_runtime.log_value_show ~descr:"bar" ~entry_id:__entry_id
                ~v:(((let open! ((Ppx_deriving_runtime)[@ocaml.warning "-A"]) in
                        fun x ->
                          Ppx_deriving_runtime.Format.asprintf "%a"
                            (fun fmt ->
                               fun () ->
                                 Ppx_deriving_runtime.Format.pp_print_string
                                   fmt "()") x)[@ocaml.warning "-A"]) __res);
              Debug_runtime.close_log ();
              __res)
         | exception e -> (Debug_runtime.close_log (); raise e))) : unit)
let () = try bar () with | _ -> print_endline "Raised exception."
