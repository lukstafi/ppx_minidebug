module Debug_runtime =
  (Debug_runtime_unix.Printf)(struct let v = "../../../debugger_pp.log" end)
type t = {
  first: int ;
  second: int }[@@deriving show]
type num = int[@@deriving show]
let bar (x : t) =
  (Debug_runtime.open_box ();
   (Debug_runtime.pp_printf () "@[\"%s\":%d:%d-%d:%d@ at time@ %s: %s@]@ "
      "test_debug_pp.ml" 4 17 4 71 (Debug_runtime.timestamp_now ()) "bar";
    Debug_runtime.pp_printf () "%s = %a@ @ " "x" pp x);
   (let bar__res =
      let y : num =
        Debug_runtime.open_box ();
        Debug_runtime.pp_printf () "\"%s\":%d:%d:%s" "test_debug_pp.ml" 4 35
          " ";
        (let y__res = (x.first + 1 : num) in
         Debug_runtime.pp_printf () "%s = %a@ @ " "y" pp_num y__res;
         Debug_runtime.close_box ~toplevel:false ();
         y__res) in
      x.second * y in
    Debug_runtime.pp_printf () "%s = %a@ @ " "bar" pp_num bar__res;
    Debug_runtime.close_box ~toplevel:true ();
    bar__res) : num)
let () = print_endline @@ (Int.to_string @@ (bar { first = 7; second = 42 }))
