# FORAY

FORAY is a stack based or concatenative langauge inspired by Forth and Min (which is inspired by Forth, Factor, and Joy)

Foray files have the extension `.fr`

## TODO:

- [x] Lexer
- [] Parser
- [] Evaluater
- [] Repl

## Examples:

Define a variable:

```
> 10 :x
=>
> x
=> 10
```

Define a function and call it:

```
> (2 *) :double
=>
> 2 double;
=> 4
```

Prefixing the `:` to a symbol means to create a word in the dictionary and assign the top of the stack as its value.
Putting items between parenthesis '(' and ')' is to create a quoted list. Putting the ';' after a list means to unquote and apply it.
So what's happening is, you assign a list to a word, push the contents of the word onto the stack, then evaluate the list.

### Notes:

Conditionals:

```
true if ... else ... end

OR

true (...) (...) if
```

