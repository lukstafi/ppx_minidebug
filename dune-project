(lang dune 3.7)

(name ppx_minidebug)

(generate_opam_files true)

(source
 (github lukstafi/ppx_minidebug))

(authors "Lukasz Stafiniak")

(maintainers "Lukasz Stafiniak")

(license "LGPL-2.1-or-later")

(documentation https://lukstafi.github.io/ppx_minidebug/ppx_minidebug)

(version 2.0.1)

(package
 (name ppx_minidebug)
 (synopsis "Debug logs for selected functions and let-bindings")
 (description
  "Formatted logs of let-bound values, function arguments and results; `if` and `match` branches taken. Optionally, as collapsible HTML trees with highlights.")
 (depends
  (ocaml
   (>= 4.13))
  dune
  ppx_deriving
  ppx_sexp_conv
  (ppxlib
   (>= 0.26.0))
  (printbox
   (>= 0.11))
  (printbox-text
   (>= 0.11))
  (printbox-html
   (= 0.11))
  (printbox-md
   (>= 0.11))
  ptime
  (mtime
   (>= 2.0))
  re
  sexplib0
  (ppx_expect
   (and
    :with-test
    (>= v0.9.0)))
  (odoc :with-doc)
  ; FIXME(#17): continuous integration in opam-repository triggers this dependency.
  md2mld)
 (tags
  (logger debugger "printf debugging")))
