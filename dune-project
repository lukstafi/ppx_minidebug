(lang dune 3.7)

(name ppx_minidebug)

(generate_opam_files true)

(source
 (github lukstafi/ppx_minidebug))

(authors "Lukasz Stafiniak")

(maintainers "Lukasz Stafiniak")

(license "LGPL-2.1-or-later")

(documentation https://github.com/lukstafi/ppx_minidebug/blob/main/README.md)

(package
 (name ppx_minidebug)
 (synopsis "Debug logs for selected functions and let-bindings")
 (description "A poor man's `ppx_debug` with formatted logs of let-bound values, function arguments and results.")
 (depends ocaml dune)
 (tags
  (logger debugger "printf debugging")))

(package
 (name minidebug_runtime)
 (synopsis "Backends for `ppx_minidebug` style loggers")
 (description "You can use `let module Debug_runtime = Minidebug_runtime.F(...) in ...` to localize the debug file.")
 (depends ocaml dune printbox printbox-text ptime)
 (tags
  (logger debugger "printf debugging")))
