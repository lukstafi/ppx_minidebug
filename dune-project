(lang dune 3.7)

(name ppx_minidebug)

(generate_opam_files true)

(source
 (github lukstafi/ppx_minidebug))

(authors "Lukasz Stafiniak")

(maintainers "Lukasz Stafiniak")

(license "LGPL-2.1-or-later")

(documentation https://github.com/lukstafi/ppx_minidebug/blob/main/README.md)

(version 0.1.4)

(package
 (name ppx_minidebug)
 (synopsis "Debug logs for selected functions and let-bindings")
 (description "A poor man's `ppx_debug` with formatted logs of let-bound values, function arguments and results.")
 (depends ocaml dune ppx_deriving ppxlib printbox printbox-text printbox-html ptime)
 (tags
  (logger debugger "printf debugging")))
