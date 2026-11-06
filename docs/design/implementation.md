# Implementation Plan

[Proof design index](../design.md)

## Where Responsibilities Live

The solver owns:

```text
recursive local decision/normalization scheduling
contextual rule search and candidate enumeration
fresh variable identities, typed matching, and capture-avoiding substitution
branch-local bindings and backtracking
goal and obligation transformation
recursive proof and disproof interpretation by implication direction
loop and resource-limit handling
composition of derivation artifacts
```

Compiler-owned logical machinery owns:

```text
the fixed semantics of and, or, not, if, for all, and for some
intrinsic logical decisions and meaning-preserving normalizations
internal whole-formula patterns unavailable to source rules
```

An intrinsic `LogicalComparator` owns the following responsibilities. Existing
`InvariantComparator` references are legacy prototype names:

```text
semantic interpretation of concrete bits
operand type and width validation
context-independent atomic decisions
comparison-specific candidate applications with sound directions
```

The intrinsic bit/integer operation layer owns exact portable semantics, target-capability checks,
concrete evaluation, symbolic result and length relationships, and operation-specific projection
rules. Physical storage and C lowering belong to code generation, not intrinsic meaning.

Logical expressions own or expose:

```text
their structural view and type
literal, variable, and symbolic invocation structure
enough identity and argument information for matching and substitution
```

`Context` owns:

```text
available Ops and operator precedence
established Propositions and explicit assumptions
append-only rule history, obviation status, and provenance
```

`NativeBitsType` owns:

```text
its exact bit width
its subject-accepting Constraint template
```

Static contract validation owns:

```text
checking source implementations against declared result contracts
recording trusted foreign declarations as explicit trust boundaries
keeping all constraints and props in the authoritative static type
distinguishing exact proof from a host-selected concrete result
```

Observation analysis owns:

```text
discovering semantic roots, including performed acts and public interfaces
backward, relational, and path-sensitive requirement propagation
separate-compilation summaries or conservative boundary requirements
tracking which executable prop implementations remain reachable
```

Implementation selection and code generation own:

```text
choosing host, target, foreign, or source implementations within validated contracts
preserving every derived observation requirement together
removing unobservable materializations and unreachable runtime prop code
retaining proof or audit evidence required for transformation verification
```

The future act/diagnostic classification owns the boundary between semantic effects and
non-semantic instrumentation. Until that boundary is specified, observation analysis must not infer
that arbitrary unsafe execution is diagnostic.

## Implementation Appendix

This appendix records legacy integration sketches, not finalized architecture, modules, or APIs.
Names beginning with `Invariant` describe the current prototype and must be reconciled with the
conceptual `Logical*`, Constraint, and Proposition vocabulary before Haskell design is adopted.

### Architecture Before Haskell Design

The next phase must first define data flow among proof goals, contextual Propositions, operator
contracts, proof results, source modules, effect versions, observation requirements, and provenance.
It must also reconcile pursuit convergence with proof-search resource and cycle handling without
prejudging whether they use unified or separate internal mechanisms.

Only after that architectural review should the design map these concepts into Haskell data types,
typeclasses, functions, and modules or plan migration of the existing prototype.

### NativeBitsType Construction

Adding a function-valued Constraint field affects positional constructors such as:

```haskell
NativeBitsType 32
NativeBitsType 1
```

Construction helpers may reduce migration cost. Display and structural equality need the same
placeholder-instantiation technique already used by `NativeType.properties`.

`NativeBitsType.satisfies` must replace its narrower-than-or-equal width check with exact equality.
Any conversion is an explicit invocation with independently established properties.

### Thing And Category Integration

Source-representable logical formulas, comparators, expressions, variables, and Propositions need
suitable `Thing` integration and the existing `Eq`, `Show`, `Messagable`, `Typeable`, and
parameterization behavior.

The final representation must also provide recursively enforced general and solver-ready subsets.
`NativeBitsType.resolve` must traverse instantiated Constraint templates when expressions contain
ordinary parameters. Proof failures must integrate with existing type-checking `Mismatch` values.

New modules and source-import cycles may require Cabal entries and `.hs-boot` declarations. Plan
those changes with the module layout rather than treating the old sketches as fixed locations.

### Context Integration

`Context.empty`, `Context.push`, and `Context.fromOps` must initialize or preserve append-only rule
history. A dedicated insertion API is preferable because `Context.push` currently means adding an
operator and updating precedence.

The former `pushInvariantRule` signature with separate premises and conclusions is an obsolete
legacy API. A replacement should accept one Proposition, justification, and declaration mode such
as ordinary proof-required declaration versus explicit `assuming`. It should return insertion
status and a stable rule ID while preserving `Proven`, `Disproven`, and `Unproven` distinctions.

Insertion can mark an already established assertion as obviated. It rejects a disproven assertion
and admits an unproven assertion only under `assuming`. Conditional validation operates on the whole
implication rather than hypothetical premise injection.

Context merging is deferred. Existing `Context.concat` must not silently discard rule history if it
is later used with Proposition-bearing contexts; imports may require ID remapping.

### Operation Values And Symbolic Isolation

Materialized runtime values remain recursively concrete, but an operation is itself a first-class
value and can remain suspended. Symbolic applications can contain quantified variables and must
preserve structure without execution. Options include a separate logical invocation or a
category-parameterized invocation type. The former `InvariantInvocation` name is legacy. Changing
only one outer wrapper is insufficient if a composite value can hide symbolic children.

Intrinsic extraction must be able to inspect a suspended built-in operation, retain its identity and
operands through relevant higher-order use, apply a justified projection rule, and validate a
bounded equivalent computation. This path is source semantics rather than an optional optimizer
heuristic. It does not make every operation projectable or every unmaterializable result valid.

Closed symbolic expressions may eventually reduce through a dedicated safe, portable execution
path when the compile-time evaluation policy permits it. This is a proof optimization or base case,
not a general formula evaluator, and it must never execute unsafe acts or native FFI merely to prove
a contract.

### Solver Safety And Diagnostics

Local simplification needs fixed-point and oscillation protection. Contextual search needs active
branch tracking, fresh application identities, backtracking, and resource bounds. Initial
implementations may be conservative; timeout and loop outcomes stay `Unproven`.

Derivation data should exist even if initial diagnostics display only the strongest failed path.
Nested decision paths and source/derived justifications are important for declaration warnings and
contradiction errors.

Avoid premature indexing, memoization, elaborate prioritization, and exhaustive native decision
inventories before semantics and interfaces have tests. Such optimizations must not change proof
meaning.

## Likely Implementation Phases

The order may change as representation experiments expose dependencies.

1. Add general logical formula forms and intrinsic comparator definitions without type-checker
   integration.
2. Add `Thing` integration and structural views for source-representable logical structures.
3. Prototype recursively enforced general and solver-ready categories, including `It` elimination.
4. Add subject-accepting `NativeBitsType` Constraint templates and construction/display helpers
   without yet relying on them for satisfaction.
5. Add append-only contextual Propositions, metadata, stable IDs, provenance, and explicit
   assumption insertion policy.
6. Implement native atomic decisions and recursive compound decision propagation with histories.
7. Implement a small, sound normalization set and the guarded local fixed-point loop.
8. Define candidate application records and the three-way implication-direction contract.
9. Implement basic contextual search, fresh variables, branch-local bindings, backtracking, and
   loop/resource handling for a deliberately limited logical subset.
10. Expand application semantics through tests for conjunction, disjunction, negation, implication,
    and quantified forms; do not claim completeness before the architecture audit.
11. Add exact-width `NativeBitsValue` and `NativeBitsType` satisfaction using instantiated,
    solver-ready Constraint templates.
12. Add standalone type-declaration validation and nested vacuity, redundancy, and uninhabitability
    diagnostics.
13. Integrate symbolic operator return contracts without circular self-proof.
14. Add parser/build support for Constraints, Propositions, quantifiers, `assuming`, and intrinsic
    comparator syntax.
15. Add exact arbitrary-width `sint`/`uint` arithmetic, intrinsic bit operations, target logical
    width capability, and proof-guided result sizing. Build floating-point behavior in the standard
    library rather than the intrinsic kernel.
16. Validate portable contracts for pure source implementations and record foreign declarations as
    explicit trust boundaries, including relational compatibility across implementations.
17. Prototype an observation IR with ordinary performed acts and public interfaces as roots, then
    add backward path-sensitive and relational propagation.
18. Add contract-compatible implementation selection and verify cross-host/target examples,
    exact-syntax requirements, branch thresholds, formatting, and separately compiled boundaries.
19. Remove unreachable runtime prop implementations only after reachability and public-boundary
    analysis, while preserving their static proof role.
20. Add non-semantic diagnostic behavior only after the diagnostic classification and the distinct
    guarantees of `unsafely once` and `unsafely each time` have been specified and tested.
21. Add lexical Proposition visibility and consumer-directed proof imports using only selected
    public module knowledge plus the importing context.
22. Integrate affine resource versions, effect contracts, external-state stability, and concurrent
    observations into proof-context validity.
23. Add safe portable compile-time execution separately from symbolic proof. Never execute unsafe
    acts or native FFI merely to prove contracts.
24. Preserve suspended operation identity through higher-order paths and implement proof-validated
    bounded extraction for supported arithmetic projections.
25. Lower arbitrary positive widths, shifts, exact arithmetic, and projections portably to C while
    avoiding signed overflow and excessive-shift undefined behavior.

## Related documents

- [Proof system](proof-system.md)
- [Observability, acts, and diagnostics](observability.md)
- [Unresolved proof design](../unresolved/proofs.md)
