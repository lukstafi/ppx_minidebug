(lang dune 3.7)

(name ppx_minidebug)

(generate_opam_files true)

(source
 (github lukstafi/ppx_minidebug))

(authors "Lukasz Stafiniak")

(maintainers "Lukasz Stafiniak")

(license "LGPL-2.1-or-later")

(documentation https://lukstafi.github.io/ppx_minidebug/ppx_minidebug)

(version 0.3.3)

(package
 (name ppx_minidebug)
 (synopsis "Debug logs for selected functions and let-bindings")
 (description "A poor man's `ppx_debug` with formatted logs of let-bound values, function arguments and results.")
 (depends
  (ocaml (>= 4.08))
  dune ppx_deriving ppx_sexp_conv
  (ppxlib (>= 0.25.0))
  printbox printbox-text printbox-html ptime sexplib0
  (ppx_expect (and :with-test (>= v0.9.0))))
 (tags
  (logger debugger "printf debugging")))
