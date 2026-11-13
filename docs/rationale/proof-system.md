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

The Logical → Constraint → Proposition hierarchy is recursively enforced so the `it` template
placeholder cannot survive into proof search.

## Separate Solver Mechanisms

### Decision

One solver coordinates three conceptually separate mechanisms:

1. **Normalize** performs deterministic, meaning-preserving canonicalization without context search.
2. **Decide** performs depth-first, context-independent decisions.
3. **Apply** uses established contextual assertions to produce directed proof obligations.

### Rationale

The separation prevents native execution from replacing arbitrary symbolic proof, keeps
normalization deterministic, and makes contextual assumptions visible in derivations. It also lets
declaration validation inspect direct contradiction and vacuity without accidentally invoking an
unbounded contextual search.

Simplification normalizes first and then decides depth-first. It repeats only when decision reduces
the formula; normalization steps alone do not trigger another pass over an already normalized
formula. Contextual alternatives are then searched as separate branches with local bindings,
backtracking, and resource limits. Exhaustion or a cycle produces `Unproven`, never `Disproven`.

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

Source spelling is also insufficient identity because resolution is context-sensitive. Declarations
and their ordering, applicable Constraints, established proofs, and even contextual grammar may make
identical syntax at two loci denote distinct operators. Fixing one resolution per locus during
compilation preserves deterministic purity while still allowing relational arithmetic return
contracts and other context-specific declarations.

Stable identities cannot depend on the current active-list position because rules may become
obviated while remaining relevant to diagnostics. Append-only history and nested assertion paths
preserve derivation links and source locations without making disjunctive children independent
facts.

Quantified variable identity combines the original declaration with the proof-step index that
introduced or freshened it. This distinguishes repeated applications without treating display names
or declared types as identity. Alpha-equivalence remains available for cycle detection.

## Branch-Local Traces

### Decision

Every explored proof path has its own chronological trace, and each step ID is its zero-based index
within that trace. Normalization, nested decisions, and contextual applications all contribute
steps. A conclusive result returns only its proof or disproof path; `Unproven` retains the closest
attempts together with their residual formulas.

### Rationale

A global search-history trace would mix abandoned branches with the evidence for a conclusion.
Branch-local traces make backtracking functional and keep generated-variable identities tied to the
actual transformation that introduced them. Residual formulas make unsuccessful diagnostics useful
without letting a closeness heuristic influence soundness.

## Relational Return Alternatives

### Decision

Operations may use relational union return contracts to admit alternative representations while
constraining when each is valid. This supersedes unconditional conservative length selection when a
fit cannot be proven. Exact syntax and generalization remain open.

### Rationale

A relational union describes the operation's result without inventing a semantic boundary between
compile-time and runtime evaluation. It can permit a shorter representation when sufficient and
forbid it when the exact value requires a longer one, while leaving implementation selection subject
to the same contract.

## Proof-Root Context

### Decision

Applying a Proposition and checking nested type compatibility use the complete context available
where the current proof began, plus legitimately scoped branch-local knowledge. They do not use a
context truncated at the position of the Proposition being applied.

### Rationale

The context stack records lexical availability and resolution order, not a restriction that older
Propositions may rely only on older declarations. Truncation can hide valid newer operators,
Constraints, and established facts from recursive obligations. Explicit branch-local scope and
non-circularity checks address the actual soundness risks without discarding available knowledge.

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
