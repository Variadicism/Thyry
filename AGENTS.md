# BengI Agent Notes

Follow the existing project style, even when another Haskell form would also be valid.

## Style

- Avoid partial functions like `head`. Prefer `uncons` and other complete functions.
- Avoid `error`. Prefer the `Fallible` type, which is a monad with constructors `Falue a` and `Error e`.
- Break lines that are longer than 100 characters where tabs are considered 4 characters long.
- Prefer `case` over function guards.
- Prefer `if ... then ... else` over `case` when branching only on `True` and `False`.
- Prefer `do` with `let` bindings over `where` clauses.
- Prefer `do` with `let` bindings over `let ... in`.
- Avoid introducing bindings inside conditions.
- Avoid monadic arrows or pattern-match conditions inside conditions when a preceding `case` is clearer.
- Keep helper logic close to its use when it is specific to one parsing or comparison path.
- Reuse shared semantic helpers when behavior is not specific to one module.
- Ensure that all lines underneath a case are indented further than the case declaration.

## Testing

- Use `Variadibuilder-Haskell test --prod` for routine test runs.
- Report the meaningful terminal result rather than raw command output.
