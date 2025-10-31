open Mcp_sdk

(* Helper module for working with markdown book chapters *)
module BookChapter = struct
  type t = { id : string; title : string; contents : string }

  (* Book chapters as a series of markdown files *)
  let chapters =
    [
      {
        id = "chapter1";
        title = "# Introduction to OCaml";
        contents =
          {|
# Introduction to OCaml

OCaml is a general-purpose, multi-paradigm programming language which extends the Caml dialect of ML with object-oriented features.

## Key Features

- **Strong Static Typing**: Catch errors at compile time rather than runtime
- **Type Inference**: No need to annotate every variable with a type
- **Pattern Matching**: Express complex control flow in a clear and concise way
- **Functional Programming**: First-class functions and immutability
- **Module System**: Powerful abstraction capabilities with modules and functors
- **Performance**: Native code compilation with excellent performance characteristics

## History

OCaml was created in 1996 by Xavier Leroy, Jérôme Vouillon, Damien Doligez, and Didier Rémy at INRIA in France. It evolved from the Caml language, which itself was an implementation of ML.

## Why OCaml?

OCaml offers a unique combination of features that make it particularly well-suited for certain domains:

- **Program Correctness**: The strong type system catches many errors at compile time
- **Symbolic Computing**: Excellent for manipulating complex data structures and symbolic expressions
- **Systems Programming**: Can be used for low-level systems programming with high safety guarantees
- **Web Development**: Modern frameworks like Dream make web development straightforward

In the following chapters, we'll explore the language features in depth and learn how to leverage OCaml's strengths for building robust, maintainable software.
|};
      };
      {
        id = "chapter2";
        title = "# Basic Syntax and Types";
        contents =
          {|
# Basic Syntax and Types

OCaml has a clean, consistent syntax that emphasizes readability and minimizes boilerplate.

## Variables and Basic Types

In OCaml, variables are immutable by default. Once a value is bound to a name, that binding cannot change.

```ocaml
(* Binding a value to a name *)
let x = 42
let greeting = "Hello, World!"

(* OCaml has type inference *)
(* These are equivalent: *)
let x = 42
let x : int = 42
```

## Basic Types

- `int`: Integer numbers
- `float`: Floating-point numbers
- `bool`: Boolean values (`true` or `false`)
- `char`: Single characters
- `string`: Text strings
- `unit`: The empty tuple, written `()`

## Functions

Functions in OCaml are first-class values:

```ocaml
(* A simple function *)
let add x y = x + y

(* With type annotations *)
let add (x : int) (y : int) : int = x + y

(* Anonymous (lambda) function *)
let increment = fun x -> x + 1

(* Partial application *)
let add5 = add 5
let fifteen = add5 10  (* equals 15 *)
```

## Control Flow

OCaml uses expressions rather than statements for control flow:

```ocaml
(* If expression *)
let abs x =
  if x < 0 then -x else x

(* Match expression (pattern matching) *)
let describe_sign x =
  match x with
  | x when x < 0 -> "negative"
  | 0 -> "zero"
  | _ -> "positive"
```

## Recursion

Functions need the `rec` keyword to be recursive:

```ocaml
(* Recursive function *)
let rec factorial n =
  if n <= 1 then 1 else n * factorial (n - 1)

(* Mutually recursive functions *)
let rec is_even n =
  if n = 0 then true else is_odd (n - 1)
and is_odd n =
  if n = 0 then false else is_even (n - 1)
```

This introduction to basic syntax sets the foundation for understanding OCaml's more advanced features, which we'll explore in the next chapters.
|};
      };
      {
        id = "chapter3";
        title = "# Data Structures";
        contents =
          {|
# Data Structures

OCaml provides several built-in data structures and makes it easy to define custom ones.

## Tuples

Tuples are fixed-length collections of values that can have different types:

```ocaml
(* A pair of an int and a string *)
let person = (42, "Alice")

(* Extracting values with pattern matching *)
let (age, name) = person

(* Accessing elements *)
let age = fst person  (* For pairs only *)
let name = snd person  (* For pairs only *)
```

## Records

Records are named collections of values:

```ocaml
(* Defining a record type *)
type person = {
  name: string;
  age: int;
  email: string option;
}

(* Creating a record *)
let alice = {
  name = "Alice";
  age = 42;
  email = Some "alice@example.com";
}

(* Accessing fields *)
let alices_name = alice.name

(* Functional update (creates a new record) *)
let alice_birthday = { alice with age = alice.age + 1 }
```

## Variants

Variants (also called algebraic data types) represent values that can be one of several cases:

```ocaml
(* Defining a variant type *)
type shape =
  | Circle of float  (* radius *)
  | Rectangle of float * float  (* width, height *)
  | Triangle of float * float * float  (* sides *)

(* Creating variants *)
let my_circle = Circle 2.5
let my_rectangle = Rectangle (4.0, 6.0)

(* Pattern matching with variants *)
let area shape =
  match shape with
  | Circle r -> Float.pi *. r *. r
  | Rectangle (w, h) -> w *. h
  | Triangle (a, b, c) ->
      let s = (a +. b +. c) /. 2.0 in
      sqrt (s *. (s -. a) *. (s -. b) *. (s -. c))
```

## Lists

Lists are immutable linked lists of elements of the same type:

```ocaml
(* Creating lists *)
let empty = []
let numbers = [1; 2; 3; 4; 5]
let constructed = 1 :: 2 :: 3 :: []

(* Pattern matching with lists *)
let rec sum_list lst =
  match lst with
  | [] -> 0
  | head :: tail -> head + sum_list tail

(* Common list functions *)
let doubled = List.map (fun x -> x * 2) numbers
let evens = List.filter (fun x -> x mod 2 = 0) numbers
let sum = List.fold_left (+) 0 numbers
```

## Arrays

Arrays provide mutable, fixed-size collections with O(1) random access:

```ocaml
(* Creating arrays *)
let arr = [|1; 2; 3; 4; 5|]

(* Accessing elements (0-indexed) *)
let first = arr.(0)

(* Modifying elements *)
let () = arr.(0) <- 10

(* Array functions *)
let doubled = Array.map (fun x -> x * 2) arr
```

## Option Type

The option type represents values that might be absent:

```ocaml
(* Option type *)
type 'a option = None | Some of 'a

(* Using options *)
let safe_divide x y =
  if y = 0 then None else Some (x / y)

(* Working with options *)
match safe_divide 10 2 with
| None -> print_endline "Division by zero"
| Some result -> Printf.printf "Result: %d\n" result
```

These data structures form the backbone of OCaml programming and allow for expressing complex data relationships in a type-safe way.
|};
      };
      {
        id = "chapter4";
        title = "# Modules and Functors";
        contents =
          {|
# Modules and Functors

OCaml's module system is one of its most powerful features. It allows for organizing code into reusable components with clear interfaces.

## Basic Modules

A module is a collection of related definitions (types, values, submodules, etc.):

```ocaml
(* Defining a module *)
module Math = struct
  let pi = 3.14159
  let square x = x *. x
  let cube x = x *. x *. x
end

(* Using a module *)
let area_of_circle r = Math.pi *. Math.square r
```

## Module Signatures

Module signatures define the interface of a module, hiding implementation details:

```ocaml
(* Defining a signature *)
module type MATH = sig
  val pi : float
  val square : float -> float
  val cube : float -> float
end

(* Implementing a signature *)
module Math : MATH = struct
  let pi = 3.14159
  let square x = x *. x
  let cube x = x *. x *. x

  (* This is hidden because it's not in the signature *)
  let private_helper x = x +. 1.0
end
```

## Functors

Functors are functions from modules to modules, allowing for higher-order modularity:

```ocaml
(* Module signature for collections *)
module type COLLECTION = sig
  type 'a t
  val empty : 'a t
  val add : 'a -> 'a t -> 'a t
  val mem : 'a -> 'a t -> bool
end

(* Functor that creates a set implementation given an element type with comparison *)
module MakeSet (Element : sig type t val compare : t -> t -> int end) : COLLECTION with type 'a t = Element.t list = struct
  type 'a t = Element.t list

  let empty = []

  let rec add x lst =
    match lst with
    | [] -> [x]
    | y :: ys ->
        let c = Element.compare x y in
        if c < 0 then x :: lst
        else if c = 0 then lst  (* Element already exists *)
        else y :: add x ys

  let rec mem x lst =
    match lst with
    | [] -> false
    | y :: ys ->
        let c = Element.compare x y in
        if c = 0 then true
        else if c < 0 then false
        else mem x ys
end

(* Creating an integer set *)
module IntElement = struct
  type t = int
  let compare = Int.compare
end

module IntSet = MakeSet(IntElement)

(* Using the set *)
let my_set = IntSet.empty
             |> IntSet.add 3
             |> IntSet.add 1
             |> IntSet.add 4
             |> IntSet.add 1  (* Duplicate, not added *)

let has_three = IntSet.mem 3 my_set  (* true *)
let has_five = IntSet.mem 5 my_set   (* false *)
```

## First-Class Modules

OCaml also supports first-class modules, allowing modules to be passed as values:

```ocaml
(* Module type for number operations *)
module type NUMBER = sig
  type t
  val zero : t
  val add : t -> t -> t
  val to_string : t -> string
end

(* Implementations for different number types *)
module Int : NUMBER with type t = int = struct
  type t = int
  let zero = 0
  let add = (+)
  let to_string = string_of_int
end

module Float : NUMBER with type t = float = struct
  type t = float
  let zero = 0.0
  let add = (+.)
  let to_string = string_of_float
end

(* Function that works with any NUMBER module *)
let sum_as_string (type a) (module N : NUMBER with type t = a) numbers =
  let sum = List.fold_left N.add N.zero numbers in
  N.to_string sum

(* Using first-class modules *)
let int_sum = sum_as_string (module Int) [1; 2; 3; 4]
let float_sum = sum_as_string (module Float) [1.0; 2.5; 3.7]
```

## Open and Include

OCaml provides ways to bring module contents into scope:

```ocaml
(* Open brings module contents into scope temporarily *)
let area =
  let open Math in
  pi *. square 2.0

(* Local opening with the modern syntax *)
let area = Math.(pi *. square 2.0)

(* Include actually extends a module with another module's contents *)
module ExtendedMath = struct
  include Math
  let tau = 2.0 *. pi
  let circumference r = tau *. r
end
```

The module system enables OCaml programmers to build highly modular, reusable code with clear boundaries between components.
|};
      };
      {
        id = "chapter5";
        title = "# Advanced Features";
        contents =
          {|
# Advanced Features

OCaml offers several advanced features that set it apart from other languages. This chapter explores some of the more powerful language constructs.

## Polymorphic Variants

Unlike regular variants, polymorphic variants don't need to be predefined:

```ocaml
(* Using polymorphic variants directly *)
let weekend = `Saturday | `Sunday
let is_weekend day =
  match day with
  | `Saturday | `Sunday -> true
  | `Monday .. `Friday -> false

(* Can be used in mixed contexts *)
let shape_area = function
  | `Circle r -> Float.pi *. r *. r
  | `Rectangle (w, h) -> w *. h
  | `Triangle (b, h) -> 0.5 *. b *. h
  | `Regular_polygon(n, s) when n >= 3 ->
      let apothem = s /. (2.0 *. tan (Float.pi /. float_of_int n)) in
      n *. s *. apothem /. 2.0
  | _ -> failwith "Invalid shape"
```

## Objects and Classes

OCaml supports object-oriented programming:

```ocaml
(* Simple class definition *)
class point x_init y_init =
  object (self)
    val mutable x = x_init
    val mutable y = y_init

    method get_x = x
    method get_y = y
    method move dx dy = x <- x + dx; y <- y + dy
    method distance_from_origin =
      sqrt (float_of_int (x * x + y * y))

    (* Private method *)
    method private to_string =
      Printf.sprintf "(%d, %d)" x y

    (* Calling another method *)
    method print = print_endline self#to_string
  end

(* Using a class *)
let p = new point 3 4
let () = p#move 2 1
let d = p#distance_from_origin
```

## Generalized Algebraic Data Types (GADTs)

GADTs provide more type control than regular variants:

```ocaml
(* A GADT for type-safe expressions *)
type _ expr =
  | Int : int -> int expr
  | Bool : bool -> bool expr
  | Add : int expr * int expr -> int expr
  | Eq : 'a expr * 'a expr -> bool expr

(* Type-safe evaluation *)
let rec eval : type a. a expr -> a = function
  | Int n -> n
  | Bool b -> b
  | Add (e1, e2) -> eval e1 + eval e2
  | Eq (e1, e2) -> eval e1 = eval e2

(* These expressions are statically type-checked *)
let e1 = Add (Int 1, Int 2)         (* OK: int expr *)
let e2 = Eq (Int 1, Int 2)          (* OK: bool expr *)
(* let e3 = Add (Int 1, Bool true)  (* Type error! *) *)
(* let e4 = Eq (Int 1, Bool true)   (* Type error! *) *)
```

## Type Extensions

OCaml allows extending existing types:

```ocaml
(* Original type *)
type shape = Circle of float | Rectangle of float * float

(* Extending the type in another module *)
type shape += Triangle of float * float * float

(* Pattern matching must now handle unknown cases *)
let area = function
  | Circle r -> Float.pi *. r *. r
  | Rectangle (w, h) -> w *. h
  | Triangle (a, b, c) ->
      let s = (a +. b +. c) /. 2.0 in
      sqrt (s *. (s -. a) *. (s -. b) *. (s -. c))
  | _ -> failwith "Unknown shape"
```

## Effects and Effect Handlers

OCaml 5 introduced algebraic effects for managing control flow:

```ocaml
(* Defining an effect *)
type _ Effect.t += Ask : string -> string Effect.t

(* Handler for the Ask effect *)
let prompt_user () =
  Effect.Deep.try_with
    (fun () ->
        let name = Effect.perform (Ask "What is your name?") in
        Printf.printf "Hello, %s!\n" name)
    { Effect.Deep.effc = fun (type a) (effect : a Effect.t) ->
        match effect with
        | Ask prompt -> fun k ->
            Printf.printf "%s " prompt;
            let response = read_line () in
            k response
        | _ -> None }
```

## Higher-Ranked Polymorphism

Using the `Obj.magic` escape hatch (with caution):

```ocaml
(* This would normally not be permitted due to rank-2 polymorphism *)
let apply_to_all_types f =
  let magic_f : 'a -> string = Obj.magic f in
  [
    magic_f 42;
    magic_f "hello";
    magic_f 3.14;
    magic_f true;
  ]

(* Usage - with great care! *)
let result = apply_to_all_types (fun x -> Printf.sprintf "Value: %s" (Obj.magic x))
```

## Metaprogramming with PPX

OCaml's PPX system enables powerful metaprogramming:

```ocaml
(* With ppx_deriving *)
type person = {
  name: string;
  age: int;
  email: string option;
} [@@deriving show, eq, ord]

(* With ppx_sexp_conv *)
type config = {
  server: string;
  port: int;
  timeout: float;
} [@@deriving sexp]

(* With ppx_let for monadic operations *)
let computation =
  [%m.let
    let* x = get_value_from_db "key1" in
    let* y = get_value_from_db "key2" in
    return (x + y)
  ]
```

## Modules for Advanced Typing

Using modules to encode complex type relationships:

```ocaml
(* Phantom types for added type safety *)
module SafeString : sig
  type 'a t

  (* Constructors for different string types *)
  val of_raw : string -> [`Raw] t
  val sanitize : [`Raw] t -> [`Sanitized] t
  val validate : [`Sanitized] t -> [`Validated] t option

  (* Operations that require specific string types *)
  val to_html : [`Sanitized] t -> string
  val to_sql : [`Validated] t -> string

  (* Common operations for all string types *)
  val length : _ t -> int
  val concat : _ t -> _ t -> [`Raw] t
end = struct
  type 'a t = string

  let of_raw s = s
  let sanitize s = String.map (function '<' | '>' -> '_' | c -> c) s
  let validate s = if String.length s > 0 then Some s else None

  let to_html s = s
  let to_sql s = "'" ^ String.map (function '\'' -> '\'' | c -> c) s ^ "'"

  let length = String.length
  let concat s1 s2 = s1 ^ s2
end
```

These advanced features make OCaml a uniquely powerful language for expressing complex programs with strong guarantees about correctness.
|};
      };
    ]

  (* Get a chapter by ID *)
  let get_by_id id =
    try Some (List.find (fun c -> c.id = id) chapters) with Not_found -> None

  (* Get chapter titles *)
  let get_all_titles () = List.map (fun c -> (c.id, c.title)) chapters
end

(* Create a server *)
let server =
  create_server ~name:"OCaml MCP Book Resource Example" ~version:"0.1.0" ()
  |> fun server ->
  (* Set default capabilities *)
  configure_server server ~with_tools:false ~with_resources:true
    ~with_resource_templates:true ~with_prompts:false ()

(* Add a resource template to get book chapters *)
let _ =
  add_resource_template server ~uri_template:"book/chapter/{id}"
    ~name:"Chapter Resource"
    ~description:"Get a specific chapter from the OCaml book by its ID"
    ~mime_type:"text/markdown" (fun params ->
      match params with
      | [ id ] -> (
          match BookChapter.get_by_id id with
          | Some chapter -> chapter.contents
          | None ->
              Printf.sprintf "# Error\n\nChapter with ID '%s' not found." id)
      | _ -> "# Error\n\nInvalid parameters. Expected chapter ID.")

(* Add a regular resource to get table of contents (no variables) *)
let _ =
  add_resource server ~uri:"book/toc" ~name:"Table of Contents"
    ~description:"Get the table of contents for the OCaml book"
    ~mime_type:"text/markdown" (fun _params ->
      let titles = BookChapter.get_all_titles () in
      let toc =
        "# OCaml Book - Table of Contents\n\n"
        ^ (List.mapi
             (fun i (id, title) ->
               Printf.sprintf "%d. [%s](book/chapter/%s)\n" (i + 1)
                 (String.sub title 2 (String.length title - 2))
                 (* Remove "# " prefix *)
                 id)
             titles
          |> String.concat "")
      in
      toc)

(* Add a regular resource for a complete book (no variables) *)
let _ =
  add_resource server ~uri:"book/complete" ~name:"Full contents"
    ~description:"Get the complete OCaml book as a single document"
    ~mime_type:"text/markdown" (fun _params ->
      let chapter_contents =
        List.map (fun c -> c.BookChapter.contents) BookChapter.chapters
      in
      let content =
        "# The OCaml Book\n\n*A comprehensive guide to OCaml programming*\n\n"
        ^ String.concat "\n\n---\n\n" chapter_contents
      in
      content)

(* Run the server with the default scheduler *)
let () = Eio_main.run @@ fun env -> Mcp_server.run_server env server
