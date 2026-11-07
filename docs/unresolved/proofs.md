# Unresolved Proof Design

[Proof design index](../design.md)

The following architecture, algorithm, syntax, standard-library, and effect-integration questions
remain deliberately unresolved. They are not conceptual blockers for the pure proof-engine
requirements.

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
9. **Comparator-aware substitution mechanics.** Exact `(bits =)` permits congruent substitution in
   pure expressions while preserving typing and resolved operation context. Cross-length numeric
   equality uses zero or sign extension followed by `(bits =)`, but does not equate the original
   representations. Design the matcher, applicability records, and search strategy for this settled
   policy.
10. **Search strategy.** Determine useful ordering among direct decisions, whole-goal applications,
    nested applications, and alternative branches without making heuristic failure a disproof.
11. **Context composition.** Design import and merge behavior, stable ID remapping, and diagnostic
    order for append-only rule histories.
12. **Architecture audit.** Test nested conditionals, quantifier order, negation, symbolic
    invocations, contradictory assumptions, mixed-width operations, and directional counterexamples
    before declaring the implementation design complete.
13. **Recursion and convergence.** Design sound induction support and reconcile pursuit convergence
    with proof-search resource and cycle handling without assuming that they must be either unified
    or separate mechanisms.
14. **Compile-time evaluation.** Specify safe exact execution policy, budgets, caching, and
    mechanics while keeping symbolic reasoning available for operators that cannot be executed. A
    portable operation requires its exact mapping; a platform-specific operation requires
    target-compatible semantics rather than a differing host implementation. Define when
    compilation needs the exact value rather than bounded knowledge.
15. **Implementation alternatives.** Represent portable, native, foreign, source, interpreted, and
    precomputed implementations. Design verification of exact logical-result agreement for one
    portable pure operation and target specialization for a platform-specific pure operation.
16. **Foreign and unsafe provenance.** Define proof provenance and any optional foreign-contract
    validation without executing unsafe effects or treating validation as a replacement trust model.
17. **Preconditions and fallible results.** Design diagnostics and proof obligations for invalid
    domains and the boundary between provably excluded inputs and failures represented as values.

## Numeric Contracts And Equality

### Formal intrinsic signatures

The semantic result-length and signedness rules are settled: lengths have an input-length floor,
shorter alternatives require proof, `Unproven` chooses the conservative length, and unsigned
subtraction becomes signed unless nonnegativity is proven. Design implementation signatures,
Constraint representation, diagnostics, and type-checking integration for those rules, including
mixed-length division and remainder and exact results near target limits.

### Target capability and dynamic lengths

Formalize `MaximumSupportedBitSequenceLength`, its default target profile, the result type of
`(bits length)`, runtime-dependent length Constraints, upper-bound inference, and logical sequences
that span allocations or use sharing. Arithmetic result lengths are proof-selected during type
checking rather than selected from runtime values; legitimate formulas may still depend on dynamic
input lengths. Distinguish a well-typed suspended operation from a demanded result whose full length
would exceed the target capability.

### Equality and standard-library mathematics

The intrinsic strategy is settled: exact equal-length `(bits =)` supplies congruent substitution,
and cross-length integer equality extends the shorter representation before applying it. Define
standard-library syntax and laws for generic numerical equality, approximate equivalence, modular
conveniences, and domain equality without enlarging the intrinsic kernel. Floating-point formats,
rounding, exceptional values, and contracts are separate standard-library design work. Empty
collection representations and additional mathematical operations are likewise deferred.

### Syntax details

Confirm formal declarations and parsing for concatenation, count-based extraction, shifts,
arithmetic families, and single-bit literals. `(bits length)` is selected; `++`, `*:`, and `:*` are
current communication spellings pending complete grammar work.

### C backend

Define portable lowering for arbitrary positive widths, exact signed and unsigned results, shifts,
multiword values, and projection-based modular calculations while preserving interpreter/C parity
and avoiding C undefined behavior.

### Operation projections

Specify trustworthy compositional rules for bounded extraction after supported arithmetic. Define
typing and validation when no rule applies, and consider later whether user-defined operators may
advertise proven projection laws.

## Observation Analysis

1. **Representation and naming.** Choose between a second type, a path-sensitive requirement graph,
   a value/relationship constraint set, or another IR. Define dependency and branch joins, and
   decide whether `observable type` or `observation contract` is the public or internal term.
2. **Formal implementation-refinement test.** Permissive value-level nondeterminism is rejected for
   pure operations: generated behavior must preserve the operation's exact deterministic mapping,
   even when declared Constraints are incomplete. Define the operational refinement algorithm and
   how it verifies physical representation freedom, exact implementation agreement, and trusted FFI
   boundaries.
3. **Observation boundaries.** Decide exactly when formatting, raw representations, termination,
   exceptions, failures, concurrency, resource use, reflection, serialization, hashing, and foreign
   interaction are semantic observations.
4. **Separate compilation.** Define observation summaries for exported functions, dynamic props,
   public ABIs, and modules whose future callers are unavailable.
5. **Exact evaluation during compilation.** Specify facilities for exact portable evaluation and
   target-compatible evaluation or emulation of platform-specific operations, plus when compilation
   must abstain from deciding a concrete result. Native or foreign code must not be run merely to
   prove its contract.
6. **Optimization feedback and auditability.** Decide whether observation propagation and
   optimization run to a fixed point and which proof records survive rewriting so transformations
   can be audited.
7. **Effect-state representation.** Design resource versions, snapshots, invalidation, effect
   dependencies, and the proof-context validity of before/after relationships.
8. **External mutation and concurrency.** Define synchronization, external-state stability,
   concurrent observations, and foreign mutation modeling.

## Diagnostics

### Unsafe evaluation modes

Specify separately what `unsafely once`, `unsafely each time`, and `unsafely recursively` guarantee
under optimization.
Decide whether a diagnostic act needs an explicit contract, capability, or library designation and
whether it must be barred from affecting files, process streams, global state, failure, or resource
exhaustion.

### Diagnostic conversion

Decide what happens when the logged value was fully optimized away, conversion is expensive or
fails, or conversion itself changes computation requirements. Determine when omission or an
`optimized out` report is permitted.

### Unsafe execution identity

Specify how the unsafe modes affect cross-invocation identity and contract provenance without
executing them during compilation or transferring pure-operation determinism to repeated act
performances.

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

### Suspended operation representation

Specify how an unevaluated operation preserves intrinsic identity, operands, bindings, wrappers, and
proof knowledge through higher-order use. Define when a consumer may inspect it and how return
materializability differs from representability of the operation value itself.

### Proof cache artifacts

Design dependency-aware proof memoization within one compilation and future module or intermediate
artifacts for cross-module and incremental reuse. Validity must account for definitions,
Propositions, assumptions, imports, visibility, and relevant context.

## Related documents

- [Contracts and type validation](../design/contracts.md)
- [Proof system](../design/proof-system.md)
- [Observability, acts, and diagnostics](../design/observability.md)
- [Implementation plan](../design/implementation.md)
