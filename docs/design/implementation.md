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
internal whole-proposition patterns unavailable to source rules
```

`InvariantComparator` owns:

```text
semantic interpretation of concrete bits
operand type and width validation
context-independent atomic decisions
comparison-specific candidate applications with sound directions
```

Invariant expressions own or expose:

```text
their structural view and type
literal, variable, and symbolic invocation structure
enough identity and argument information for matching and substitution
```

`Context` owns:

```text
available Ops and operator precedence
established invariant assertions and explicit assumptions
append-only rule history, obviation status, and provenance
```

`NativeBitsType` owns:

```text
its exact bit width
its subject-accepting invariant template
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

This appendix records expected integration work, not finalized module or API design.

### NativeBitsType Construction

Adding a function-valued invariant field affects positional constructors such as:

```haskell
NativeBitsType 32
NativeBitsType 1
```

Construction helpers may reduce migration cost. Display and structural equality need the same
placeholder-instantiation technique already used by `NativeType.properties`.

`NativeBitsType.satisfies` must replace its narrower-than-or-equal width check with exact equality.
Any conversion is an explicit invocation with independently established properties.

### Thing And Category Integration

Source-representable invariant forms, comparators, expressions, variables, and rules need suitable
`Thing` integration and the existing `Eq`, `Show`, `Messagable`, `Typeable`, and parameterization
behavior.

The final representation must also provide recursively enforced general and solver-ready subsets.
`NativeBitsType.resolve` must traverse instantiated invariant templates when expressions contain
ordinary parameters. Proof failures must integrate with existing type-checking `Mismatch` values.

New modules and source-import cycles may require Cabal entries and `.hs-boot` declarations. Plan
those changes with the module layout rather than treating the old sketches as fixed locations.

### Context Integration

`Context.empty`, `Context.push`, and `Context.fromOps` must initialize or preserve append-only rule
history. A dedicated insertion API is preferable because `Context.push` currently means adding an
operator and updating precedence.

The former `pushInvariantRule` signature with separate premises and conclusions is obsolete. A new
API should accept one assertion, justification, and declaration mode such as ordinary proof-required
declaration versus explicit `assuming`. It should return insertion status and a stable rule ID while
preserving `Proven`, `Disproven`, and `Unproven` distinctions.

Insertion can mark an already established assertion as obviated. It rejects a disproven assertion
and admits an unproven assertion only under `assuming`. Conditional validation operates on the whole
implication rather than hypothetical premise injection.

Context merging is deferred. Existing `Context.concat` must not silently discard rule history if it
is later used with invariant-bearing contexts; imports may require ID remapping.

### Symbolic Invocation Isolation

Ordinary runtime arguments should be recursively concrete. Symbolic applications can contain
quantified variables and must preserve structure without execution. Options include a separate
`InvariantInvocation` or a category-parameterized invocation type. Changing only one outer argument
wrapper is insufficient if a composite `ConcreteThing` can hide symbolic children.

Closed symbolic expressions may eventually reduce through an existing execution path when proof
explicitly requests it and execution is valid. This is a proof optimization/base case, not a
general invariant evaluation API.

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

1. Add general invariant forms and native comparator definitions without type-checker integration.
2. Add `Thing` integration and structural views for source-representable invariant structures.
3. Prototype recursively enforced general and solver-ready categories, including `It` elimination.
4. Add subject-accepting `NativeBitsType` templates and construction/display helpers without yet
   relying on them for satisfaction.
5. Add append-only context assertions, metadata, stable IDs, provenance, and explicit assumption
   insertion policy.
6. Implement native atomic decisions and recursive compound decision propagation with histories.
7. Implement a small, sound normalization set and the guarded local fixed-point loop.
8. Define candidate application records and the three-way implication-direction contract.
9. Implement basic contextual search, fresh variables, branch-local bindings, backtracking, and
   loop/resource handling for a deliberately limited logical subset.
10. Expand application semantics through tests for conjunction, disjunction, negation, implication,
    and quantified forms; do not claim completeness before the architecture audit.
11. Add exact-width `NativeBitsValue` and `NativeBitsType` satisfaction using instantiated,
    solver-ready templates.
12. Add standalone type-declaration validation and nested vacuity, redundancy, and uninhabitability
    diagnostics.
13. Integrate symbolic operator return contracts without circular self-proof.
14. Add parser/build support for invariant declarations, quantifiers, `assuming`, and native
    comparator syntax.
15. Add standard-library comparison props, conversion contracts, and carefully staged float and
    fixed-width arithmetic support.
16. Validate portable contracts for pure source and foreign implementations, including relational
    extensionality and explicit trust provenance.
17. Prototype an observation IR with ordinary performed acts and public interfaces as roots, then
    add backward path-sensitive and relational propagation.
18. Add contract-compatible implementation selection and verify cross-host/target examples,
    exact-syntax requirements, branch thresholds, formatting, and separately compiled boundaries.
19. Remove unreachable runtime prop implementations only after reachability and public-boundary
    analysis, while preserving their static proof role.
20. Add non-semantic diagnostic behavior only after the diagnostic classification and the distinct
    guarantees of `unsafely once` and `unsafely each time` have been specified and tested.

## Related documents

- [Proof system](proof-system.md)
- [Observability, acts, and diagnostics](observability.md)
- [Unresolved proof design](../unresolved/proofs.md)
