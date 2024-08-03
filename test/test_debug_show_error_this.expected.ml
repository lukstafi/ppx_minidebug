let () =
  [%ocaml.error
    "ppx_minidebug: to avoid confusion, _this_ indicator is only allowed on let-bindings"];
  ()
