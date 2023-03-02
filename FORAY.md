# FORAY Language

## Brief Intro to Concatenative/Stack-Oriented Programming

A concatenative language is one that works by composing functions which all operate on the same piece of data.
A stack oriented language is one in which all inputs are either values which are pushed onto a stack, or operators that manipulate the stack.

A file or script in such a language is essentially a linear series of inputs being pushed into a stack. So if I write `1 2 3`, the stack will look like:

```
=> 1 2 3
```

Where `=>` represents the bottom of the stack, so `1` is at the bottom and `3` is at the top.

If I then write `+`, the program will pop the top two numbers off the stack, add them, then push the result, so the new stack will look like:

```
=> 1 5
```

## Types

- **Int:** A 64 bit integer

- **Float:** A 64 bit floating point number

- **Bool:** A boolean that is either "true" or "false"

- **Char:** A character

- **String:** A string, represented by an array of characters

- **List:** A list of any other types. When a list is eval'd by the `;` operator, it is essentially unpacked, and the contents of the list are pushed in order.

## Lists and Evaluation

The `(` and `)` symbols are "special" in that they are not values or operators but they enclose and define a list of values.
Anything can be put in a list, and it will not be evaluated. It is essentially a quoted list (for those familiar with Lisp).

```
> ( 1 2 + )
=> (1 2 +)
```

The list can be evaluated or 'unquoted' with the `;` operator.
Each item in the list is pushed to the stack, or if it is an operator it will perform its function.

```
> (1 2 +) ;
=> 3
> (dup *)
=> 3 (dup *)
> ;
=> 9
```

Thus lists are essentially equivalent to anonymous functions.

When a lists are evaluated, they introduce their own scope.
This means variables defined within a list go out of scope after the end of the list.
Also, variables will overshadows others with the same name in an outer scope.

```
> 1 :a (2 :a a); a
=> 2 1
```

## Variables and Functions

To define a item in the dictionary, simply prefix a `:` to the symbol you wrote, and it will pop the top value off the stack and assign it to the symbol.
Then, whenever the symbol is pushed, it will be substituted with its value.

```
> 2 :x
=>
> x x
=> 2 2
```

The `:` is another "special" token, in that it modifies the symbol in front of it instead of modifying the stack. It is not a standalone operator like `;`.

Functions are simply variables containing lists, and like lists can be evaluated with the operator `;`. You can put a space between the symbol and this operator, or not, it is always parsed seperately.

```
> (2 *) :double
=>
> 3 double;
=> 6
```

## Builtin Operators

There is a small suite of builtin operators in the language, that let you perform arithmatic, boolean operations, or stack operations, like swapping, dropping, etc.
Note that none of these operators require the eval operator (`;`) after it, even the ones that look like words.

`> 1 2 3 + swap` is correct.

`> 1 2 3 + swap;` is ***not*** correct.

`swap` and `;` are both **operators**, and operators are evaluated automatically unless in a list. This may seem strange at first but there is an important disctinction between an operator and a value, and variables are values, not operators.

Here are the builtin operators:

- Eval: `;`
- Arithmatic: `+`, `-`, `*`, `/`,
- Comparison: `>`, `>=`, `<`, `<=`, `=`, `!=`,
- Boolean: `&&`, `||`, `!`,
- Stack:
  * `drop`: Pops and discards the top value.
  * `swap`: Swaps the first and second value in the stack.
  * `dup`: Duplicates the top value and pushes it.
  * `rot`: Rotates the top three values in the stack. Ex: `1 2 3 rot` results in `3 1 2`.
- Conditional:
  * `if`: Takes three values off the stack in this order: `cond ifTrue ifFalse`. If the `cond` value is true, then `ifTrue` is evaluated, otherwise `ifFalse` is evaluated.
    Ex: `true (1) (2) if` results in `1`. 
- Composition:
  * `map`: Takes a list and a function and applies the function to each item in the list. Ex: `(1 2 3) (1 +) map` results in `(2 3 4)`.

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
