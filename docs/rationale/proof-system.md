# Proof-System Rationale

[Proof design index](../design.md)

## A Fixed Logical Core

### Decision

The compiler owns the meanings of `and`, `or`, `not`, `if`, `for all`, and `for some`. Users may
state domain knowledge but may not redefine logic. Ordinary logical forms remain source-expressible;
compiler-only whole-formula metavariables are the exception.

The logical formula model does not expose source truth-constant constructors. Terminal decisions
are consumed by enclosing forms, with their justification retained for diagnostics. Names such as
`TrueInvariant` and `FalseInvariant` refer only to rejected legacy implementation possibilities.

### Rationale

A fixed logical core is necessary for sound proof and disproof. User-extensible domain rules remain
valuable, but allowing them to redefine implication, negation, or quantification would undermine the
meaning of every contract. Avoiding truth-constant proof nodes also keeps source propositions and
derivations focused on meaningful obligations rather than simplifier artifacts.

General and solver-ready formula categories are separate so the `it` template placeholder cannot
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

Every contextual application records an outcome-oriented direction:

- **May Prove** when the replacement implies the goal (`R -> G`);
- **May Disprove** when the goal implies the replacement (`G -> R`); or
- **May Prove or Disprove** when they are biimplicative (`R <-> G`).

These labels describe which eventual result may transfer. The actual solver judgments remain
`Proven`, `Disproven`, and `Unproven`.

### Rationale

A sufficient condition can prove a goal when established but cannot disprove the goal when false. A
necessary condition can disprove a goal when false but cannot prove it when true. Treating every
rewrite as equivalence would therefore make both proof and disproof unsound, especially when a rule
has an antecedent.

For example, **May Prove** transfers a proven `R` but not a disproven one. **May Disprove**
transfers a disproven `R` but not a proven one. Explicit direction makes this asymmetry part of the
application artifact and its diagnostics.

## Trust, Identity, And Provenance

### Decision

Deterministic extensional behavior is intrinsic to every pure operation: identical effective inputs
to the same resolved operation produce the same exact logical result. Pure implementations still
prove declared result Constraints without circularly using them. Foreign purity declarations and
explicit `assuming` declarations are visible trust boundaries. Rule history is append-only, with
stable IDs and derivation provenance.

### Rationale

Proofs are only useful when their evidence can be audited. Circular return-contract evidence would
let any implementation certify itself. Foreign code cannot generally be verified by this solver, so
its declaration must clearly carry responsibility for deterministic, side-effect-free behavior and
the asserted result properties. Likewise, unproven source assertions require conspicuous syntax.

Pure extensionality requires matching operation identity, bindings, captures, dispatch, and inputs;
it does not equate unrelated operations that share a return type. Exact bit equality supplies
foundational congruent substitution, while ordinary, approximate, IEEE, and cross-length numeric
equalities retain their narrower meanings.

Stable identities cannot depend on the current active-list position because rules may become
obviated while remaining relevant to diagnostics. Append-only history and nested assertion paths
preserve derivation links and source locations without making disjunctive children independent
facts.

## Three Proof Outcomes

### Decision

`Proven`, `Disproven`, and `Unproven` remain distinct judgments about a specific contextual goal.
Only an actual refutation supports `Disproven`; incomplete knowledge, resource exhaustion, and
nonproductive cycles yield `Unproven`.

### Rationale

Open-ended symbolic search is incomplete in practice. Treating lack of proof as false would be
unsound, while accepting it as true would hide trust. A required but unproven goal therefore needs
more evidence, a stronger context, or an explicit non-disproven assumption.

## Consumer-Directed Proof Imports

### Decision

A consumer may request the precise Proposition it needs from public module knowledge. Proof uses the
consumer's context plus public exported contracts and Propositions, never arbitrary private facts,
and introduces only the requested result into the local scope.

### Rationale

Consumers can depend on a weaker, more stable guarantee without copying a complex exporter theorem.
At the same time, private implementation premises remain encapsulated, and public operator types
continue to carry their complete declared Constraints.

## Related documents

- [Proof system](../design/proof-system.md)
- [Unresolved proof design](../unresolved/proofs.md)
