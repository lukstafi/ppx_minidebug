module Debug_runtime =
  (Debug_runtime_unix.Printf)(struct let v = "../../../debugger_show.log" end)
let foo (x : int) =
  (Debug_runtime.open_box ();
   (Debug_runtime.pp_printf () "@[\"%s\":%d:%d-%d:%d@ at time@ %s: %s@]@ "
      "test_debug_show.ml" 3 19 5 15 (Debug_runtime.timestamp_now ()) "foo";
    Debug_runtime.pp_printf () "%s = %s@ @ " "x" (([%show : int]) x));
   (let foo__res =
      let y : int =
        Debug_runtime.open_box ();
        Debug_runtime.pp_printf () "\"%s\":%d:%d:%s" "test_debug_show.ml" 4 6
          " ";
        (let y__res = (x + 1 : int) in
         Debug_runtime.pp_printf () "%s = %s@ @ " "y"
           (([%show : int]) y__res);
         Debug_runtime.close_box ~toplevel:false ();
         y__res) in
      [x; y; 2 * y] in
    Debug_runtime.pp_printf () "%s = %s@ @ " "foo"
      (([%show : int list]) foo__res);
    Debug_runtime.close_box ~toplevel:true ();
    foo__res) : int list)
let () = print_endline @@ (Int.to_string @@ (List.hd @@ (foo 7)))
type t = {
  first: int ;
  second: int }[@@deriving show]
let bar (x : t) =
  (Debug_runtime.open_box ();
   (Debug_runtime.pp_printf () "@[\"%s\":%d:%d-%d:%d@ at time@ %s: %s@]@ "
      "test_debug_show.ml" 10 19 10 73 (Debug_runtime.timestamp_now ()) "bar";
    Debug_runtime.pp_printf () "%s = %s@ @ " "x" (([%show : t]) x));
   (let bar__res =
      let y : int =
        Debug_runtime.open_box ();
        Debug_runtime.pp_printf () "\"%s\":%d:%d:%s" "test_debug_show.ml" 10
          37 " ";
        (let y__res = (x.first + 1 : int) in
         Debug_runtime.pp_printf () "%s = %s@ @ " "y"
           (([%show : int]) y__res);
         Debug_runtime.close_box ~toplevel:false ();
         y__res) in
      x.second * y in
    Debug_runtime.pp_printf () "%s = %s@ @ " "bar" (([%show : int]) bar__res);
    Debug_runtime.close_box ~toplevel:true ();
    bar__res) : int)
let () = print_endline @@ (Int.to_string @@ (bar { first = 7; second = 42 }))
