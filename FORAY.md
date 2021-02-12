# FORAY Language

## Grammar

```
expr ::= literal | list | symbol | define | eval

literal ::= int | float | bool | char | string

symbol ::= valid-symbol+ [0-9 | valid-symbol ]*

valid-symbol ::= [a-z | A-Z | * | / | + | - | = | ! | ?]

define ::= ":" symbol

eval ::= ";"

list ::= "(" expr* ")"
```

## Types

- **Int:** A 64 bit integer

- **Float:** A 64 bit floating point number

- **Bool:** A boolean that is either "true" or "false"

- **Char:** A character

- **String:** A string, represented by an array of characters

- **List:** A list of any other types. When a list is eval'd by the `;` operator, it is essentially unpacked, and the contents of the list are pushed in order.

## Variables, Functions, and Evaluation

To define a item in the dictionary, simply prefix a `:` to the symbol you wrote, and it will pop the top value off the stack and assign it to the symbol.
Then, whenever the symbol is pushed, it will be substituted with its value.

```
> 1 2 3 :x
=> 1 2
> x
=> 1 2 3
```

Functions are just variables containing lists, than can be evaluated with `;`.

```
> (2 *) :double
=>
> 3 double;
=> 6
```

Literal lists can also be evaluated, creating an anonymous function.
This may not seem to have much of a purpose, but it will since lexical scoping is planned.

```
> 1 (1 +);
=> 2
```
