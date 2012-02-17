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
* ternary expressions
* switch-case statement
* language integrated grammars (via LPeg)
* bitwise operators
* continue statement
* string interpolation
* Array and Hash types
* short function literals
* try-catch blocks

# LANGUAGE

Syntactically Lupa belongs to the C family of languages, in that it has curly braces delimiting blocks and includes familiar constructs such as switch statements and while loops.

## SAMPLE

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
      // short functions as infix expressions
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

