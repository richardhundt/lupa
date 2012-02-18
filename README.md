# NAME

Lupa - multi-paradigm object oriented, dynamic language

# SYNOPSIS

    lupa <file> [options]

# OVERVIEW

*NOTE:* This is alpha software and is therefore very likey to change

Lupa is a language which translates to Lua. The aim to provide a language which is fast and lean, can seamlessly call into existing Lua code and libraries, while providing a little more safety and features for programming in the large than stock Lua does.

Most of Lua's semantics shine through, such as Lua's for loops, 1-based arrays and string pattern matching.

However, Lupa adds several features, such as:

* classes with multiple inheritance
* parameterisable traits and mixins
* arithmetic assignment expressions
* switch-case statement
* language integrated grammars (via LPeg)
* bitwise operators
* continue statement
* string interpolation
* Array and Hash types
* short function literals
* try-catch blocks

## Dependencies

Lupa depends on LPeg, and either LuaJIT2, or Lua + LuaBitop (LJ2 has a bit library included)

# LANGUAGE

Syntactically Lupa belongs to the C family of languages, in that it has curly braces delimiting blocks and includes familiar constructs such as switch statements and while loops.

## Sample

```ActionScript
trait Pet(S) {
   // parameterised traits with lexical scoping
   has size = S
}
 
class Mammal {
   has blood = "warm"
}

class Named {
   // default property values are lazy expressions
   has name = error("A pet needs a name!")
}
 
// multiple inheritance with C3 resolution order and trait mixins
class Hamster from Mammal, Named with Pet("small") {

   method __init(name) {
      self.name = name
   }

   method greet(whom : String) {
      // string interpolation
      print("Hi ${whom}, I am ${self.name}, a ${self.size}, ${self.blood}, ${typeof self}!")
   }

   // class bodies have lexical scope
   var numbers = [ "one", "two", "three", "four", "five" ]

   method count(upto) {
      // short functions as postfix expressions
      upto.times -> { print(numbers[_]) }
   }
}
 
var rudy = Hamster("Rudy")
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

Future updates to guarded variables within a given scope cause the guard to be called with the value as argument to allow the guard to coerce the value or raise an exception. 

The above statement (loosely) translates to the following Lua snippet:

```Lua
local s = String("first")
```

## Assignment

Assignments can be simple binding expressions:

```ActionScript
everything.answer = 42
```
... or compound:

```ActionScript
a ||= 1
```

## Operators

Lupa has the following unary operators:

* `!` - not
* `#` - len
* `-` - unm
* `~` - bnot
* `@` - unpack

The following binary operators, grouped by precedence, from highest to lowest:

* `^^` - pow
* `*`, `/`, `%` - mul, div, mod
* `+`, `-`, `~` - add, sub, concat
* `>>`, `<<`, `>>>` - rshift, lshift, arshift
* `&` - band
* `^` - bxor
* `|` - bor
* `<=`, `>=`, `<`, `>`, `in`, `as` - le, ge, lt, gt, in, as
* `==`, `!=` - eq, ne
* `&&` - and
* `||` - or

## Patterns

Lupa integrates LPeg into the language and supports pattern literals delimited by a starting and ending `/`:

```ActionScript
var ident = / { [a-zA-Z_] ([a-zA-Z_0-9]+) } /
```

Patterns are also composable. Here the lexical pattern `a` is referenced from within the second pattern:

```ActionScript
var a = / '42' /
print(/ { 'answer' | <{a}> } /.match("42"))
```

Grammars are constructed in that nominal types can declare patterns as rules in their body. Here's the example macro expander from the LPeg website translated to Lupa:

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

## Scoping

Lupa has two kinds of scopes. The first is simple lexical scoping, which is seen in function and class bodies, and control structures.

The second kind of scope is the environment scope, which is modeled after Lua 5.2's _ENV idea, where symbols which are not declared in a compilation unit, are looked up in a special `__env` table, which delegates to Lua's `_G` global table.

At the top level of a script, class, object, trait and function declarations are bound to `__env`, while variable declarations remain lexical.

However, inside class, object and trait bodies, `__env` is only used for lookup, no declarations bind to the environment. All other declarations are lexical, including function declarations.

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

Nested function declarations are also lexical, however the differ from function literals in that inside a function declaration, the function itself is always visible, so can be called recursively:

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

Modules are simply Lupa source files. There are no additional namespaces constructs within the language to declare modules or packages. Modules return their `__env` table, so the can export any environment scoped symbol (this is likely to change).

Symbols can be imported using the `import` statement, which takes the form `import <name_list> from <dotted_path>`

```ActionScript
/*--- file: ./my/shapes.lu ---*/
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
        super::move(self, x, y)
        self.z = z
    }
}

/*--- file: test.lu ---*/
import Point, Point3D from my.shapes

var p = Point3D()
p.move(1, 2, 3)
```

