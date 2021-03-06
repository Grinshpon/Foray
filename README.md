# FORAY

FORAY is a stack based or concatenative langauge inspired by [Forth](http://www.forth.org/) and [Min](https://min-lang.org/) (which is inspired by Forth, [Factor](https://factorcode.org/), and [Joy](http://www.kevinalbrecht.com/code/joy-mirror/joy.html))

Foray files have the extension `.fr`

Read [FORAY.md](./FORAY.md) for the language design and basics.

## Building and Running Instructions

Clone the project then run `zig build` to compile or `zig build run` to compile and run. Running with no arguments launches a repl. Running with a file given as an argument will look for and run that file.

## TODO:

- [x] Lexer (still have to parse chars and strings)
- [x] Parser
- [ ] Evaluater
  - [x] Basic Evaluation
  - [x] Builtin operator functionality (WIP)
- [ ] Repl
  - [x] Basic REPL
  - [ ] Features like history, etc
- [ ] Standard Library
- [ ] Actual error handling and not just a bunch of `try`'s

## Examples:

### Define a variable:

```
> 10 :x
=>
> x
=> 10
```

### Define a function and call it:

```
> (2 *) :double
=>
> 2 double;
=> 4
```

Prefixing the `:` to a symbol means to create a word in the dictionary and assign the top of the stack as its value.
Putting items between parenthesis '(' and ')' is to create a quoted list. Putting the ';' after a list means to unquote and apply it.
So what's happening is, you assign a list to a word, push the contents of the word onto the stack, then evaluate the list.

### Factorial

```
( dup 1 <= 
  (drop 1)
  (dup 1 - dup rot * swap 1 - fac; *)
  if
) :fac
```
