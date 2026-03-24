# BengI

`BengI` is an interpreter for Thyrym, formerly called Beng: a pure functional programming language with some unusual characteristics:
* a context-aware grammar
* a statically duck-typed type system
* types as first-class objects
* arbitrarily specific types

The goal is to build a clean, readable, maintainable pure functional language that is highly optimizable at compilation rather than interpretation with a type system designed to make unhandled runtime failures impossible by forcing failure cases to be represented, checked, and handled explicitly.

At a high level, Thyrym treats declarations as both grammar rules and function signatures. A declaration describes how an operation looks in source code, what arguments it takes, and what it returns. A definition is that same declaration with executable behavior attached. Parsing is therefore not just syntax recognition: the interpreter builds context, resolves declarations and definitions, and uses those to decide what code means.

## Status

This repository is still a work in progress. The current interpreter already demonstrates the language model and several key mechanisms, but it is not yet a complete production implementation of Thyrym.

# Usage

## Requirements

- [GHC](https://www.haskell.org/ghc/)
- [cabal-install](https://www.haskell.org/cabal/)
- A local checkout of the unpublished `Utils` package used by this repository

## Setup

This project depends on an unpublished `Utils` package, so cloning this repository alone is not enough to build it.

1. Clone this repository.
1. Clone the `Utils` repository somewhere on the same machine.
1. Create a `cabal.project` file in this repository if you do not already have one.
1. Add both the `Utils` checkout and this repository to `packages:`.

Example:

```cabal
packages:
  .
  ../Utils
```

Adjust `../Utils` to the actual path of your local `Utils` checkout.

## Build

Use standard Cabal commands:

```bash
cabal build
```

If you want the executable specifically:

```bash
cabal build exe:BengI
```

## Test

Use standard Cabal test commands:

```bash
cabal test
```

The Cabal file currently defines these test suites:

- `parse-test`
- `build-test`
- `run-test`

You can also run one suite at a time, for example:

```bash
cabal test parse-test
```

## Install

To install the executable with Cabal:

```bash
cabal install
```

Depending on your Cabal configuration, the installed binary may be placed under Cabal's local bin directory.

## Run

The executable expects exactly one argument: the path to a Thyrym/Beng source file.

Thyrym is intended to support sequences of stateful operations in the future, in the same broad sense that Haskell programs can sequence effects. The current interpreter is much simpler: it evaluates the input and prints only the final value reached by that evaluation.

With Cabal:

```bash
cabal run exe:BengI -- "test input/simple math/2+3.beng"
```

This repository includes sample inputs under `test input`, including:

- `test input/simple math/2+3.beng`
- `test input/simple math/3+2+3.beng`
- `test input/simple strings.beng`
- `test input/scope/if.beng`

## Debug Logging

You can enable debug output with the Cabal flag:

```bash
cabal run --flags=var-debug exe:BengI -- "test input/simple math/2+3.beng"
```

This debug logging is provided through the `Utils` package.

Warning: `--flags=var-debug` produces a very large amount of logging output. It is useful for tracing parser, builder, and runtime behavior, but it is intentionally noisy and can easily flood the terminal.

# Technical Overview

## The core idea

Thyrym is not modeled as a language with a fixed grammar plus a separate function table. Instead, declarations are the grammar.

Each declaration describes:

- a pattern
- named arguments embedded inside that pattern
- a return type
- associativity and precedence information
- a way to build extra parsing context for later arguments when needed

Definitions extend declarations by attaching executable behavior. That makes a definition roughly equivalent to "a declaration plus implementation", while a declaration alone is closer to a forward declaration in C.

This is why the interpreter's "build" phase is more than ordinary parsing. It has to:

- parse source text against the declarations currently in scope
- resolve argument matches
- build or extend context when declarations introduce new operations
- validate type relationships while constructing operations

## Declarations as grammar rules

The pattern system is intentionally richer than a plain token sequence. It behaves somewhat like a regular expression, but with typed argument slots inside it. Those arguments do not merely match syntax. They match values or sub-operations according to the types the declaration expects.

In other words, a declaration is simultaneously:

- a grammar production
- a callable operation signature
- a type contract

That is one of the defining ideas of the project.

## Definitions and execution

At runtime, evaluation works by taking a built operation, locating its definition, binding its matched arguments by name, and executing the definition's behavior. If the result is itself another operation, evaluation continues until it reaches a non-operation value. In the current interpreter, that final value is what gets printed.

## Context-aware parsing

This project's parser is intentionally context-aware.

That is not just a convenience feature. It is part of the language model. Some declarations can influence what should be recognized later, including inside arguments. Because of that, building and interpretation are partially intertwined.

This means Thyrym is not aiming for a simple fixed grammar where the parser can be completely separated from semantic knowledge. The set of valid parses depends on declarations, definitions, and the context they construct.

## Static, capability-based typing

The project treats values and types through the same semantic framework rather than as completely separate worlds.

The important design point is that typechecking is static but structural in spirit. The question is not simply "does this value have the registered nominal type name X?" The deeper question is whether one value satisfies another by structure, arguments, return shape, primitive compatibility, and required properties.

That makes the system duck-typed in the sense that compatibility is based on capabilities and behavior, but static in the sense that those checks are explicit and enforced during building and validation rather than deferred to an untyped runtime.

The intended type system is also meant to be arbitrarily specific. Types are not limited to broad categories such as "integer" or "string"; they are intended to express semantic constraints on actual values. In principle, that means types can describe properties such as positivity, upper bounds, or required string formats, and have those constraints enforced rather than treated as mere documentation.

## The current implementation

The current interpreter is bootstrapped with a built-in context. At the moment, that built-in layer is where the language model is expressed concretely. It includes examples of:

- literal integer parsing
- string parsing
- boolean-like bits via `yes` and `no`
- infix arithmetic such as `+` and `-`
- string prefix checks
- scoped definition-like behavior
- conditional execution

The executable currently accepts one file path, interprets that file, and prints the final value produced by evaluation. Although the language is intended to grow toward richer sequencing of stateful operations, the present implementation's output behavior is still intentionally direct and limited to that final evaluated result.

## Current Limitations

This project is still evolving, so some parts of the implementation are intentionally incomplete or transitional. In particular:

- the language and repository naming are in transition from Beng to Thyrym
- the interpreter currently depends on an unpublished external `Utils` package
- some comments in the code explicitly mark temporary implementation strategies
- the executable output is simply the last value evaluated

Even so, the repository already shows the intended architecture clearly: declarations drive parsing, definitions drive execution, and type compatibility is enforced through capabilities rather than nominal registration.
