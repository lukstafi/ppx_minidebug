[@@@ocaml.ppx.context
  {
    tool_name = "ppx_driver";
    include_dirs = [];
    hidden_include_dirs = [];
    load_path = ([], []);
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
module Debug_runtime = (val
  Minidebug_runtime.debug_flushing ~filename:"debugger_pp_flushing" ())
type t = {
  first: int ;
  second: int }[@@deriving show]
include
  struct
    let _ = fun (_ : t) -> ()
    let rec pp :
      Ppx_deriving_runtime.Format.formatter -> t -> Ppx_deriving_runtime.unit
      =
      ((let open! ((Ppx_deriving_runtime)[@ocaml.warning "-A"]) in
          fun fmt x ->
            Ppx_deriving_runtime.Format.fprintf fmt "@[<2>{ ";
            ((Ppx_deriving_runtime.Format.fprintf fmt "@[%s =@ "
                "Test_debug_pp.first";
              (Ppx_deriving_runtime.Format.fprintf fmt "%d") x.first;
              Ppx_deriving_runtime.Format.fprintf fmt "@]");
             Ppx_deriving_runtime.Format.fprintf fmt ";@ ";
             Ppx_deriving_runtime.Format.fprintf fmt "@[%s =@ " "second";
             (Ppx_deriving_runtime.Format.fprintf fmt "%d") x.second;
             Ppx_deriving_runtime.Format.fprintf fmt "@]");
            Ppx_deriving_runtime.Format.fprintf fmt "@ }@]")
      [@ocaml.warning "-39"][@ocaml.warning "-A"])
    and show : t -> Ppx_deriving_runtime.string =
      fun x -> Ppx_deriving_runtime.Format.asprintf "%a" pp x[@@ocaml.warning
                                                               "-32"]
    let _ = pp
    and _ = show
  end[@@ocaml.doc "@inline"][@@merlin.hide ]
type num = int[@@deriving show]
include
  struct
    let _ = fun (_ : num) -> ()
    let rec pp_num :
      Ppx_deriving_runtime.Format.formatter ->
        num -> Ppx_deriving_runtime.unit
      =
      ((let open! ((Ppx_deriving_runtime)[@ocaml.warning "-A"]) in
          fun fmt -> Ppx_deriving_runtime.Format.fprintf fmt "%d")
      [@ocaml.warning "-39"][@ocaml.warning "-A"])
    and show_num : num -> Ppx_deriving_runtime.string =
      fun x -> Ppx_deriving_runtime.Format.asprintf "%a" pp_num x[@@ocaml.warning
                                                                   "-32"]
    let _ = pp_num
    and _ = show_num
  end[@@ocaml.doc "@inline"][@@merlin.hide ]
let bar (x : t) : num=
  let __entry_id = Debug_runtime.get_entry_id () in
  ();
  (Debug_runtime.open_log ~fname:"test/test_debug_pp.ml" ~start_lnum:7
     ~start_colnum:17 ~end_lnum:9 ~end_colnum:14 ~message:"bar"
     ~entry_id:__entry_id;
   Debug_runtime.log_value_pp ?descr:(Some "x") ~entry_id:__entry_id ~pp
     ~is_result:false x);
  (match let y : num =
           let __entry_id = Debug_runtime.get_entry_id () in
           ();
           Debug_runtime.open_log ~fname:"test/test_debug_pp.ml"
             ~start_lnum:8 ~start_colnum:6 ~end_lnum:8 ~end_colnum:7
             ~message:"y" ~entry_id:__entry_id;
           (match x.first + 1 with
            | y as __res ->
                ((();
                  Debug_runtime.log_value_pp ?descr:(Some "y")
                    ~entry_id:__entry_id ~pp:pp_num ~is_result:true y);
                 Debug_runtime.close_log ~fname:"test/test_debug_pp.ml"
                   ~start_lnum:8 ~entry_id:__entry_id;
                 __res)
            | exception e ->
                (Debug_runtime.close_log ~fname:"test/test_debug_pp.ml"
                   ~start_lnum:8 ~entry_id:__entry_id;
                 raise e)) in
         x.second * y
   with
   | __res ->
       (Debug_runtime.log_value_pp ?descr:(Some "bar") ~entry_id:__entry_id
          ~pp:pp_num ~is_result:true __res;
        Debug_runtime.close_log ~fname:"test/test_debug_pp.ml" ~start_lnum:7
          ~entry_id:__entry_id;
        __res)
   | exception e ->
       (Debug_runtime.close_log ~fname:"test/test_debug_pp.ml" ~start_lnum:7
          ~entry_id:__entry_id;
        raise e))
let () = ignore @@ (bar { first = 7; second = 42 })
let baz (x : t) : num=
  let __entry_id = Debug_runtime.get_entry_id () in
  ();
  (Debug_runtime.open_log ~fname:"test/test_debug_pp.ml" ~start_lnum:13
     ~start_colnum:17 ~end_lnum:15 ~end_colnum:20 ~message:"baz"
     ~entry_id:__entry_id;
   Debug_runtime.log_value_pp ?descr:(Some "x") ~entry_id:__entry_id ~pp
     ~is_result:false x);
  (match let ({ first = y; second = z } as _yz) : t =
           let __entry_id = Debug_runtime.get_entry_id () in
           ();
           Debug_runtime.open_log ~fname:"test/test_debug_pp.ml"
             ~start_lnum:14 ~start_colnum:36 ~end_lnum:14 ~end_colnum:39
             ~message:"_yz" ~entry_id:__entry_id;
           (match { first = (x.first + 1); second = 3 } with
            | _yz as __res ->
                ((();
                  Debug_runtime.log_value_pp ?descr:(Some "_yz")
                    ~entry_id:__entry_id ~pp ~is_result:true _yz);
                 Debug_runtime.close_log ~fname:"test/test_debug_pp.ml"
                   ~start_lnum:14 ~entry_id:__entry_id;
                 __res)
            | exception e ->
                (Debug_runtime.close_log ~fname:"test/test_debug_pp.ml"
                   ~start_lnum:14 ~entry_id:__entry_id;
                 raise e)) in
         (x.second * y) + z
   with
   | __res ->
       (Debug_runtime.log_value_pp ?descr:(Some "baz") ~entry_id:__entry_id
          ~pp:pp_num ~is_result:true __res;
        Debug_runtime.close_log ~fname:"test/test_debug_pp.ml" ~start_lnum:13
          ~entry_id:__entry_id;
        __res)
   | exception e ->
       (Debug_runtime.close_log ~fname:"test/test_debug_pp.ml" ~start_lnum:13
          ~entry_id:__entry_id;
        raise e))
let () = ignore @@ (baz { first = 7; second = 42 })
let rec loop (depth : num) (x : t) : num=
  let __entry_id = Debug_runtime.get_entry_id () in
  ();
  ((Debug_runtime.open_log ~fname:"test/test_debug_pp.ml" ~start_lnum:19
      ~start_colnum:22 ~end_lnum:25 ~end_colnum:9 ~message:"loop"
      ~entry_id:__entry_id;
    Debug_runtime.log_value_pp ?descr:(Some "depth") ~entry_id:__entry_id
      ~pp:pp_num ~is_result:false depth);
   Debug_runtime.log_value_pp ?descr:(Some "x") ~entry_id:__entry_id ~pp
     ~is_result:false x);
  (match if depth > 6
         then x.first + x.second
         else
           if depth > 3
           then
             loop (depth + 1)
               { first = (x.second + 1); second = (x.first / 2) }
           else
             (let y : num =
                let __entry_id = Debug_runtime.get_entry_id () in
                ();
                Debug_runtime.open_log ~fname:"test/test_debug_pp.ml"
                  ~start_lnum:23 ~start_colnum:8 ~end_lnum:23 ~end_colnum:9
                  ~message:"y" ~entry_id:__entry_id;
                (match loop (depth + 1)
                         { first = (x.second - 1); second = (x.first + 2) }
                 with
                 | y as __res ->
                     ((();
                       Debug_runtime.log_value_pp ?descr:(Some "y")
                         ~entry_id:__entry_id ~pp:pp_num ~is_result:true y);
                      Debug_runtime.close_log ~fname:"test/test_debug_pp.ml"
                        ~start_lnum:23 ~entry_id:__entry_id;
                      __res)
                 | exception e ->
                     (Debug_runtime.close_log ~fname:"test/test_debug_pp.ml"
                        ~start_lnum:23 ~entry_id:__entry_id;
                      raise e)) in
              let z : num =
                let __entry_id = Debug_runtime.get_entry_id () in
                ();
                Debug_runtime.open_log ~fname:"test/test_debug_pp.ml"
                  ~start_lnum:24 ~start_colnum:8 ~end_lnum:24 ~end_colnum:9
                  ~message:"z" ~entry_id:__entry_id;
                (match loop (depth + 1)
                         { first = (x.second + 1); second = y }
                 with
                 | z as __res ->
                     ((();
                       Debug_runtime.log_value_pp ?descr:(Some "z")
                         ~entry_id:__entry_id ~pp:pp_num ~is_result:true z);
                      Debug_runtime.close_log ~fname:"test/test_debug_pp.ml"
                        ~start_lnum:24 ~entry_id:__entry_id;
                      __res)
                 | exception e ->
                     (Debug_runtime.close_log ~fname:"test/test_debug_pp.ml"
                        ~start_lnum:24 ~entry_id:__entry_id;
                      raise e)) in
              z + 7)
   with
   | __res ->
       (Debug_runtime.log_value_pp ?descr:(Some "loop") ~entry_id:__entry_id
          ~pp:pp_num ~is_result:true __res;
        Debug_runtime.close_log ~fname:"test/test_debug_pp.ml" ~start_lnum:19
          ~entry_id:__entry_id;
        __res)
   | exception e ->
       (Debug_runtime.close_log ~fname:"test/test_debug_pp.ml" ~start_lnum:19
          ~entry_id:__entry_id;
        raise e))
let () = ignore @@ (loop 0 { first = 7; second = 42 })
[1mFile "_none_", line 1[0m:
[1;35mWarning[0m 53 [misplaced-attribute]: the "ocaml.warning" attribute cannot appear in this context
