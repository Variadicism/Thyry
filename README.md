# BengI

This is the interpreter for the work in progress programming language, \English (pronounced "backslash English", nicknamed "Beng", pronounced like "bang").

To use this interpreter, compile `BengI.hs`, then execute the executable produced with a single argument: a file with \English code (conventionally named with the ".beng" extension).

## WIP: current limitations

This interpreter is an early work in progress. Currently, its limits are severe:

* The only ops recognized are the literal values "2" and "3" and the operator "`<Addend>+<Augend>`".
* Whitespace is not currently recognized as valid characters in code; any whitespace will result in an error.
* All values are ints.
* There is no backtracking; if it matches an op, it will continue from there and fail if it can't parse the next part even if it could parse a different op first in order to parse the rest correctly.
* No new ops can be declared in the program; only ops declared in the interpreter (`knownOps` in `BengI.hs`) work.
* There is no operator precedence; everything is purely left associative.
