(lang dune 3.10)

(name ppx_minidebug)

(generate_opam_files true)

(source
 (github lukstafi/ppx_minidebug))

(authors "Lukasz Stafiniak")

(maintainers "Lukasz Stafiniak <lukstafi@gmail.com>")

(license "LGPL-2.1-or-later")

(documentation https://lukstafi.github.io/ppx_minidebug/ppx_minidebug)

(version 2.3.0)

(using mdx 0.4)

(package
 (name ppx_minidebug)
 (synopsis "Debug logs for selected functions and let-bindings")
 (description
  "Formatted logs of let-bound values, function arguments and results; `if` and `match` branches taken. Optionally, as collapsible HTML trees with highlights.")
 (depends
  ; With the release of 2.3.0, our dependencies (ppx_sexp_conv v0.17.1 due to ppxlib 0.36)
  ; force us to depend on OCaml >= 5.1.0, so it's a good opportunity to bump the minimum.
  (ocaml
   (>= 5.2.0))
  dune
  ppx_deriving
  ppx_sexp_conv
  (ppxlib
   (>= 0.36.0))
  (printbox
   (>= 0.12))
  (printbox-text
   (>= 0.12))
  (printbox-html
   (>= 0.12))
  (printbox-md
   (>= 0.12))
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
  (thread-local-storage
   (>= 0.2))
  (mdx
   (>= 2.5.0)))
 (tags
  (logger debugger "printf debugging")))
