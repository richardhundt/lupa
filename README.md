# NAME

Lupa - multi-paradigm object oriented, dynamic language

# SYNOPSIS

    lupa <file> [options]

# OVERVIEW

*NOTE:* This is alpha software and is therefore very likey to change

Lupa is a language which translates to Lua. So, bowing to the
mandatory justification of "why yet another language", here's the
reasoning. LuaJIT2 is fast. Very fast. I like fast in a language
runtime. LuaJIT2 also has a low memory footprint. Which is also
nice.

However, although a beautiful language, Lua is also very minimal.
I want a language with a bit more meat. More than that though,
I want a language which gives me the most syntactic and semantic
flexibility possible, while allowing me to write code which is
run-time safe. Not type safe, but rather constraint safe.

For syntactic and semantic flexibility, Lupa borrows an idea from
Scala in that infix and prefix operators are method calls.

For safety, Lupa provides compile-time symbol checks to catch typos,
and for the rest we have guard expressions.

Guard expressions are lexical or environment names which evaluate to
an object which implements a `coerce` method. For lexical variables,
this is invoked for each operation which updates the binding. For
example:

```ActionScript
var a : Number = 42
a = 69       // ok
a = 'cheese' // error cannot coerce 'cheese' to number
```

The compiler inserts calls to `Number#coerce` whenever it sees
an assignment to `a`. The same applies to function/method parameters
and return values. For example:

```ActionScript
function add(a : Number, b : Number) : Number {
    return a + b
}
var c = add(40, 2)
```

```ActionScript
class A {
    method >>+<<(a) {
        print("funky operator on: "+a)
    }
}

var a1 = A.new
var a2 = A.new
a1 >>+<< a2
```

Lupa borrows ideas from Scala in that (almost all) infix and prefix
operators are method calls, and supports single inheritance with
trait composition. For constraints, Lupa supports guard expressions.

Most of Lua's semantics shine through, such as Lua's for loops,
1-based arrays and string pattern matching.

However, Lupa adds several features, such as:

* classes with single inheritance
* parameterisable traits and mixins
* arithmetic assignment expressions
* switch-case statement
* language integrated grammars (via LPeg)
* bitwise operators
* continue statement
* string interpolation
* Array literals
* short function literals
* try-catch blocks

## Dependencies

Lupa depends on LPeg, and either LuaJIT2, or Lua + LuaBitop (LJ2 has a bit library included)

# LANGUAGE

Syntactically Lupa belongs to the C family of languages, in that
it has curly braces delimiting blocks and includes familiar constructs
such as switch statements and while loops.

## Sample

```ActionScript
trait Pet[T] {
   // parameterised traits with lexical scoping
   has size : T
}
 
class Mammal {
   has blood = "warm"
}

trait Named {
   // default property values are lazy expressions
   has name = error("A pet needs a name!")
}
 
// multiple inheritance with C3 resolution order and trait mixins
class Hamster from Mammal with Pet[Number], Named {

   // default initializer
   method init(name) {
      self.size = 42
      .name = name // short for self.name = name
   }

   method greet(whom : String) {
      // string interpolation
      print("Hi ${whom}, I am ${.name}, a ${.size}, ${.blood}, ${typeof self}!")
   }

   // class bodies have lexical scope
   var numbers = [ "one", "two", "three", "four", "five" ]

   method count(upto) {
      // short functions
      upto.times((_) => { print(numbers[_]) })

      // same thing, but `times' as infix operator
      upto times => print(numbers[_])
   }
}
 
var rudy = Hamster.new("Rudy")
rudy.greet("Jack")
rudy.count(5)
```

## Variables

Lexical variables are introduced with the `var` keyword, followed by a comma separated list of identifiers, and an optional `=` followed by a list of expressions.

```ActionScript
var a, b         // declare only
var c, d = 1, 2  // declare and assign
```

## Guards

Variable declarations may also include guard expressions:

```ActionScript
var s : String = "first"
```

Future updates to guarded variables within a given scope cause the
guard's `coerce` method to be called with the value as argument to
allow the guard to coerce the value or raise an exception.

The above statement (loosely) translates to the following Lua snippet:

```Lua
local s = String:coerce("first")
```

## Assignment

Assignments can be simple binding expressions:

```ActionScript
everything.answer = 42
```
... or compound:

```ActionScript
a += 1
```

## Operators

Most operators in Lupa are method calls. For example:

```ActionScript
a + 42
```

which is the same as:
```ActionScript
a.+(42)
```

This syntax applies to all method calls, so the following are equivalent:

```ActionScript
var d = Dog.new("Fido")
var d = Dog new "Fido"
10.times((i) => { print(i) })
10 times (i) => { print(i) }
10 times => print(_) // same as above
```

A notable exception are `===` and `!==` which are raw identity comparisons.

Infix operator precedences are determined by their first character and are
always left associative. In the order of highest to lowest precedence:

### Infix operator precedence

* alphanumeric word
* /, *, %
* +, -, ~
* :, ?
* =, !
* <, >
* ^
* &
* |

Prefix operators can also be defined as methods. The following may be used:

* @
* #
* -
* ~
* *

To define a prefix operator method, the method name must be suffixed
with an underscore. For example:
```ActionScript
class A {
    // unary minus
    method -_(b) {
        ...
    }
}
```

Additionally, postcircumfix operators are allowed in certain contexts. Array and
Table subscripts are actually defined as '_[]' and '_[]=' methods. These
can be used to implement your own collection:

```ActionScript
class NumberArray {
    has data = [ ]
    method _[](index) {
        .data[index]
    }
    method _[]=(index, value : Number) {
        .data[index] = value
    }
}
var nums = NumberArray.new
nums[1] = 42
```

## Identifiers

Indentifiers in Lupa come in two flavours. The first type are the
familiar type seen in most languages (currently `?` and `!` are
supported in the first and last positions respectively). The following
pattern describes these:

```
name = / (%alpha | "_" | "$" | "?") (%alnum | "_" | "$")* "!"? /
```

Other other kind of identifiers consist only of punctuation as described
earlier under Operators. These are used in method declarations:

```ActionScript
class Point {
    has x : Number = 0
    has y : Number = 0
    method +(b : Point) : Point {
        Point.new(.x + b.x, .y + b.y)
    }
}
```

## Patterns

Lupa integrates LPeg into the language and supports pattern literals
delimited by a starting and ending `/`:

```ActionScript
var ident = / { [a-zA-Z_] ([a-zA-Z_0-9]+) } /
```

Patterns are also composable. Here the lexical pattern `a` is
referenced from within the second pattern:

```ActionScript
var a = / '42' /
print(/ { 'answer' | <{a}> } /.match("42"))
```

Grammars are constructed in that nominal types can declare patterns
as rules in their body. Here's the example macro expander from the
LPeg website translated to Lupa:

```ActionScript
object Macro {

    rule text {
        {~ <item>* ~}
    }
    rule item {
        <macro> | [^()] | '(' <item>* ')'
    }
    rule arg {
        ' '* {~ (!',' <item>)* ~}
    }
    rule args {
        '(' <arg> (',' <arg>)* ')'
    }
    rule macro {
        | ('apply' <args>) -> '%1(%2)'
        | ('add'   <args>) -> '%1 + %2'
        | ('mul'   <args>) -> '%1 * %2'
    }
}

var s = "add(mul(a,b),apply(f,x))"
print(Macro.text(s))
```

The Lupa grammar is self bootstrapped, so hopefully that can serve
as a reference until I finish this document. ;)

## Scoping

Lupa has two kinds of scopes. The first is simple lexical scoping,
which is seen in function and class bodies, and control structures.

The second kind of scope is the environment scope, which is modeled
after Lua 5.2's _ENV idea, where symbols which are not declared in
a compilation unit, are looked up in a special `__env` table, which
delegates to Lua's `_G` global table.

At the top level of a script, class, object, trait and function
declarations are bound to `__env`, while variable declarations
remain lexical.

Inside class, object and trait bodies, only function declarations
bind to `__env`. Method and property declarations bind to `self`
(the class or object).

Inside function bodies, function declarations are lexical and are
*not* hoisted to the top of the scope, meaning they are only visible
after they are declared.

Variable declarations declared as `var` are always lexical. To declare
a variable bound to the environment, use `our`:

```ActionScript
var answer = 42  // ordinary lexical
our DEBUG = true // bound to environment
```

```ActionScript
// bound to the environment (__env.envfunc)
function envfunc() {
    // ...
}
// a lexical function
var localfunc = function() {
    // ...
}
class MyClass {
    // this function is only visible in this block
    function hidden() {
        // ...
    }
    method munge() {
        hidden()
    }
}
```

Nested function declarations are also lexical, however the differ
from function literals in that inside a function declaration, the
function itself is always visible, so can be called recursively:

```ActionScript
function outer() {

    // inner function is lexical
    function inner() {
        // inner itself is visible here
    }

    // not quite the same thing
    var inner = function() {
        // inner itself is not visible here
    }
}
```

## Modules

Modules are simply Lupa source files. There are no additional
namespaces constructs within the language to declare modules or
packages.

Symbols are not exported by default. To export symbols, the `export`
statement can be used. It has the form `export <name> [, <name>]*`
Symbols can be imported using the `import` statement, which takes
the form `import [<name> [, <name>] from <dotted_path>`.

For example:

```ActionScript
/*--- file: ./my/shapes.lu ---*/
export Point, Point3D

class Point {
    has x = 0
    has y = 0
    method move(x, y) {
        self.x = x
        self.y = y
    }
}
class Point3D from Point {
    has z = 0
    method move(x, y, z) {
        super.move(x, y)
        self.z = z
    }
}

/*--- file: test.lu ---*/
import Point, Point3D from my.shapes

var p = Point3D.new
p.move(1, 2, 3)
```

It is an error to attempt to export a symbol which is never declared,
or is declared but evaluates to `nil`.

