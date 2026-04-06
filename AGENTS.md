# BengI Agent Notes

Follow the existing project style, even when another Haskell form would also be valid.

## Style

- Avoid partial functions like `head`. Prefer `uncons` and other complete functions.
- Avoid `error`. Prefer the `Fallible` type, which is a monad with constructors `Falue a` and `Error e`.
- Break lines that are longer than 100 characters where tabs are considered 4 characters long.
- Prefer record name punning; avoid `{ operator = operator }`, for example.
- Prefer `case` over function guards.
- Prefer `if ... then ... else` over `case` when branching only on `True` and `False`.
- Prefer `do` with `let` bindings over `where` clauses.
- Prefer `do` with `let` bindings over `let ... in`.
- Prefer function chaining over explicit argument naming; for example, prefer `f = a . b . c` over `f x = a $ b $ c x`.
- When a function with a type signature is defined by function chaining, put parentheses around the implicit arguments and the return type; for example, if `f = a . b` where `a :: A -> F` and `b :: X -> A`, then write the type signature of `f` as `f :: (X -> F)` because the argument of type `X` is not explicit in the definition.
	- This is for human comprehensibility when reading the definition; by Haskell syntax rules, these parentheses are optional and do not change the semantic meaning.
- Avoid `let` or monadic bindings inside branching constructs such as guards, case alternatives, or if conditions.
- Keep helper logic close to its use when it is specific to one parsing or comparison path.
- Reuse shared semantic helpers when behavior is not specific to one module.
- Ensure that all lines underneath a case alternative are indented further than the case alternative.
- Do not introduce new extensions without requesting permission. Existing extensions are listed under "default-extensions" in the project's `.cabal` file.
- Avoid qualified imports for imports with names that are unlikely to conflict. For example, `OMap` can be imported by itself rather than qualifying as `OMap.OMap`.

## Testing

- Use `cabal test` for routine test runs.
- Report the meaningful terminal result rather than raw command output.
