# BengI

This is the interpreter for the work in progress programming language, \English (pronounced "backslash English", nicknamed "Beng", pronounced like "bang").

Project-specific agent and style guidance lives in `AGENTS.md`.

## Installation

This program can be compiled with the [Glasgow Haskell Compiler (GHC)](https://www.haskell.org/ghc/).

Compilation of this program requires some Cabal packages, including but not limited to `transformers-either-0.1.1`. In the future, a Cabal-compliant file will be added to this repository with an accurate specification of the required packages.

Compilation of this program requires Variadicism's [Haskell Utils](https://bitbucket.org/Variadicism/haskell-utils/src/master/). In the future, this may come packaged with this repository in some convenient way.

To use this interpreter in debug mode, compile `BengI.hs` with the GHC preprocessor definition option `-DDEBUG`. This will print debug information to stdout as the program executes.

## Usage

To use this interpreter, compile `BengI.hs`, then execute the executable produced with a single argument: a file with \English code (conventionally named with the ".beng" extension).

## WIP: current limitations

This interpreter is an early work in progress. Currently, its limits are severe:

* The only ops recognized are the literal values "2" and "3" and the operator "`<Addend>+<Augend>`".
* Whitespace is not currently recognized as valid characters in code; any whitespace will result in an error.
* All values are ints.
* There is no backtracking; if it matches an op, it will continue from there and fail if it can't parse the next part even if it could parse a different op first in order to parse the rest correctly.
* No new ops can be declared in the program; only ops declared in the interpreter (`knownOps` in `BengI.hs`) work.
* There is no operator precedence; everything is purely left associative.
