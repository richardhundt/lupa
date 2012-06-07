![logo](https://github.com/richardhundt/lupa/wiki/lupa_logo.png)

# NAME

Lupa - multi-paradigm object oriented, dynamic language

# SYNOPSIS

    lupa <file>
        run the script
    lupa <file> -l
        list generated Lua

Lupa is an object-oriented language which targets the LuaJIT2 VM. It supports a rich feature set inspired by Ruby (property access via methods), Scala (operators are methods, traits), Perl 6 (has, method, does) and Falcon.

It also has some less commonly found features, such as parsing expression grammars (via LPeg) integrated into the language (instead of the traditional PCRE), and type guards.

## Features

Most of Lua's semantics shine through, such as Lua's for loops,
1-based arrays, first-class functions, and late binding.

However, Lupa adds several features, such as:

* classes with single inheritance
* parameterisable traits and mixin composition
* everything-is-an-object semantics
* static symbol resolution
* type guards and assertions
* language integrated grammars (via LPeg)
* operators as method calls
* continue statement
* string interpolation
* builtin Array type
* short function literals
* switch-case statement
* try-catch statement
* and more...


Here's a sample:

```
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
 
// single inheritance with trait mixins
class Hamster from Mammal with Pet[Number], Named {

  // default initializer
  method init(name) {
    self.size = 42
    .name = name // short for self.name = name
  }   

  method greet(whom : String) {
    // string interpolation
    print("Hi ${whom}, I am ${.name}!")
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

For more, check out:

* [Getting Started](lupa/wiki/Getting-Started)
* [Tutorial](lupa/wiki/Tutorial)


