# Unresolved Proof Design

[Proof design index](../design.md)

The following questions remain deliberately unresolved.

## Proof System

1. **Generalized contextual application calculus.** Define exact proof and disproof transformations
   for deeply nested `and`, `or`, `not`, `if`, `for all`, and `for some`, while preserving the
   implication-direction contract.
2. **Exact Haskell representations.** Map the conceptual `LogicalFormula`, `LogicalComparison`,
   `LogicalComparator`, and `LogicalExpression` vocabulary onto recursive general/solver-ready
   categories, structural views, symbolic invocations, internal formula patterns, and existential
   wrappers. Legacy `Invariant*` sketches are not final APIs.
3. **Decision and transformation result types.** Design signatures that retain ordered nested
   provenance, bindings, paths, and application directions without treating current sketches as
   final APIs.
4. **Normalization inventory and termination.** Choose sound canonical forms and a matcher, define
   theory-specific arithmetic limits, and ensure the combined decision/normalization loop cannot
   oscillate.
5. **Quantifier algorithms.** Specify freshening, witness discovery, universal reasoning,
   capture-avoiding substitution, and branch-local binding behavior in difficult nested cases.
6. **Declaration consistency depth.** Decide how much contextual search to spend finding later
   conflicts, uninhabitable types, vacuity, and redundancy. Unknownness must remain distinct from
   contradiction.
7. **Source grammar.** Finalize Constraint and Proposition declarations beyond the illustrative
   `for all`/`for some`, `it`/`one`, `assuming`, and `(uint <)` terminology.
8. **Fresh symbolic subjects.** Specify construction and validation so type declarations use an
   arbitrary unrefined subject and cannot prove themselves circularly.
9. **Comparator-aware substitution.** Define which intrinsic comparators permit replacement inside
   each expression and comparator context, with which explicit conditions, especially for floats,
   signed zero, and raw bits.
10. **Search strategy.** Determine useful ordering among direct decisions, whole-goal applications,
    nested applications, and alternative branches without making heuristic failure a disproof.
11. **Context composition.** Design import and merge behavior, stable ID remapping, and diagnostic
    order for append-only rule histories.
12. **Architecture audit.** Test nested conditionals, quantifier order, negation, symbolic
    invocations, contradictory assumptions, NaN, and directional counterexamples before declaring
    the implementation design complete.
13. **Recursion and convergence.** Design sound induction support and reconcile pursuit convergence
    with proof-search resource and cycle handling without assuming that they must be either unified
    or separate mechanisms.
14. **Compile-time evaluation.** Specify safe portable execution policy, budgets, caching, and
    mechanics while keeping symbolic reasoning available for operators that cannot be executed.
    Define when compilation needs a uniquely determined exact result rather than bounded knowledge.
15. **Implementation alternatives.** Represent portable, native, foreign, and source implementations
    and verify their individual and relational compatibility with one authoritative contract.
16. **Foreign and unsafe provenance.** Define proof provenance and any optional foreign-contract
    validation without executing unsafe effects or treating validation as a replacement trust model.
17. **Preconditions and fallible results.** Design diagnostics and proof obligations for invalid
    domains and the boundary between provably excluded inputs and failures represented as values.

## Numeric Contracts And Equality

### Runtime and standard-library contracts

Define exact integer widths, overflow, signed arithmetic, division edge cases, floating-point NaN,
infinity, signed-zero behavior, rounding modes, fast-math permissions, trigonometric accuracy,
comparison implementations, and conversion operations with independently validated contracts.

### Exact and approximate equality syntax

Reconcile ordinary domain-specific Thyrym equality, approximate equivalence, intrinsic integer and
floating numerical comparisons, and bit identity. Define explicit applicability conditions for
sound intrinsic substitution without granting ordinary `=` foundational authority.

### Standard comparison laws

Define concrete standard-library equality and ordering laws at the Thyrym layer, including the
domains on which they hold, without treating them as intrinsic proof semantics.

## Observation Analysis

1. **Representation and naming.** Choose between a second type, a path-sensitive requirement graph,
   a value/relationship constraint set, or another IR. Define dependency and branch joins, and
   decide whether `observable type` or `observation contract` is the public or internal term.
2. **Formal implementation-refinement test.** Define when generated behavior is permitted by an
   approximation or relational contract, including when an implementation may select an arbitrary
   contract-valid result rather than the literal result of particular source code. Decide whether
   trusted FFI and proved source implementations differ here.
3. **Observation boundaries.** Decide exactly when formatting, raw representations, termination,
   exceptions, failures, concurrency, resource use, reflection, serialization, hashing, and foreign
   interaction are semantic observations.
4. **Separate compilation.** Define observation summaries for exported functions, dynamic props,
   public ABIs, and modules whose future callers are unavailable.
5. **Portable evaluation during compilation.** Specify the facilities used to execute or approximate
   safe portable operations while preserving target contracts, and when compilation must abstain
   from deciding a concrete result. Native or foreign code must not be run merely to prove its
   contract.
6. **Optimization feedback and auditability.** Decide whether observation propagation and
   optimization run to a fixed point and which proof records survive rewriting so transformations
   can be audited.
7. **Effect-state representation.** Design resource versions, snapshots, invalidation, effect
   dependencies, and the proof-context validity of before/after relationships.
8. **External mutation and concurrency.** Define synchronization, external-state stability,
   concurrent observations, and foreign mutation modeling.

## Diagnostics

### Unsafe evaluation modes

Specify separately what `unsafely once` and `unsafely each time` guarantee under optimization.
Decide whether a diagnostic act needs an explicit contract, capability, or library designation and
whether it must be barred from affecting files, process streams, global state, failure, or resource
exhaustion.

### Diagnostic conversion

Decide what happens when the logged value was fully optimized away, conversion is expensive or
fails, or conversion itself changes computation requirements. Determine when omission or an
`optimized out` report is permitted.

### Unsafe execution identity

Specify how the two unsafe modes affect cross-invocation identity and contract provenance without
executing either mode during compilation or inferring equality from a declared result type alone.

## Architecture And Integration

### Placement of shared semantics

For the Thyrym/Thyry repository split, decide which logic, numeric, contract, and evaluation
facilities belong in shared lower-level compiler/interpreter foundations rather than only in the
Thyrym-facing layer, so every stage uses coherent meanings.

### Public proof knowledge

Settle syntax for Proposition visibility, proof imports, and references to operators in requested
goals. Decide whether proof imports are special entries, ordinary Propositions, retained evidence,
or a combination, and how scoped dependencies survive compiled module boundaries.

Decide whether a request `from FILE` may succeed without using evidence from `FILE`; this is an open
language and architecture choice. Also design conflict diagnostics, dependency versioning, proof
caching, module import cycles, and incremental checking.

## Related documents

- [Contracts and type validation](../design/contracts.md)
- [Proof system](../design/proof-system.md)
- [Observability, acts, and diagnostics](../design/observability.md)
- [Implementation plan](../design/implementation.md)
