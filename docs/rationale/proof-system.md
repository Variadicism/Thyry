# Proof-System Rationale

[Proof design index](../design.md)

## A Fixed Logical Core

### Decision

The compiler owns the meanings of `and`, `or`, `not`, `if`, `for all`, and `for some`. Users may
state domain knowledge but may not redefine logic. Ordinary logical forms remain source-expressible;
compiler-only whole-proposition metavariables are the exception.

The proposition model does not expose `TrueInvariant` or `FalseInvariant`. Terminal decisions are
consumed by enclosing forms, with their justification retained for diagnostics.

### Rationale

A fixed logical core is necessary for sound proof and disproof. User-extensible domain rules remain
valuable, but allowing them to redefine implication, negation, or quantification would undermine the
meaning of every contract. Avoiding truth-constant proof nodes also keeps source propositions and
derivations focused on meaningful obligations rather than simplifier artifacts.

General and solver-ready invariant categories are separate so the `it` template placeholder cannot
survive recursively into proof search.

## Separate Solver Mechanisms

### Decision

One solver coordinates three conceptually separate mechanisms:

1. **Decide** performs direct, context-independent decisions.
2. **Normalize** performs deterministic, meaning-preserving canonicalization without context search.
3. **Apply** uses established contextual assertions to produce directed proof obligations.

### Rationale

The separation prevents native execution from replacing arbitrary symbolic proof, keeps
normalization deterministic, and makes contextual assumptions visible in derivations. It also lets
declaration validation inspect direct contradiction and vacuity without accidentally invoking an
unbounded contextual search.

Decision and normalization iterate to a guarded local fixed point. Contextual alternatives are then
searched as separate branches with local bindings, backtracking, and resource limits. Exhaustion or
a cycle produces `Unproven`, never `Disproven`.

## Directional Contextual Applications

### Decision

Every contextual application records whether its replacement obligation implies the goal, the goal
implies the replacement, or the two are biimplicative.

### Rationale

A sufficient condition can prove a goal when established but cannot disprove the goal when false. A
necessary condition can disprove a goal when false but cannot prove it when true. Treating every
rewrite as equivalence would therefore make both proof and disproof unsound, especially when a rule
has an antecedent.

For example, if `R -> G`, proving `R` proves `G`, while disproving `R` is inconclusive. If `G -> R`,
disproving `R` disproves `G`, while proving `R` is inconclusive. Explicit direction makes this
asymmetry part of the application artifact and its diagnostics.

## Trust, Identity, And Provenance

### Decision

Pure implementations prove their contracts without using those same contracts as circular evidence.
Foreign declarations and explicit `assuming` declarations are visible trust boundaries. Rule
history is append-only, with stable IDs and derivation provenance.

### Rationale

Proofs are only useful when their evidence can be audited. Circular return-contract evidence would
let any implementation certify itself. Foreign code cannot generally be verified by this solver, so
its declaration must clearly carry responsibility for the asserted contract. Likewise, unproven
source assertions require conspicuous syntax.

Stable identities cannot depend on the current active-list position because rules may become
obviated while remaining relevant to diagnostics. Append-only history and nested assertion paths
preserve derivation links and source locations without making disjunctive children independent
facts.

## Related documents

- [Proof system](../design/proof-system.md)
- [Unresolved proof design](../unresolved/proofs.md)
