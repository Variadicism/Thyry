# Proof-System Integration Plan

[Plan index](README.md)

Repository observations in this file describe the current checkout and must be reverified before
implementation.

## Existing Integration Points

### Things And Types

**Observed:** `src/Beng/Types/Things.hs` defines `Thing`, `ConcreteThing`,
`ParameterizedThing`, `SomeThing`, `SomeConcreteThing`, `SomeParameterizedThing`,
`NativeBitsValue`, `NativeBitsType`, `NativeOrType`, and `One`.

**Observed:** `NativeBitsValue` currently stores `bytes` and `size`; `NativeBitsType` stores only
`size`. `NativeOrType` stores at least two alternatives through `Populace2`.

**Observed:** `src/Beng/Things.hs` supplies instances. `NativeBitsType.satisfies` currently
delegates to length testing, while `NativeType` already has subject-accepting properties.
`NativeOrType` already implements candidate and requirement alternative satisfaction paths.

**Candidate migration:** add subject-dependent Constraint templates to bit types, introduce the
Logical/Constraint/Proposition hierarchy, and adapt satisfaction to structural alternatives followed
by Constraint implication. Reuse existing subject-instantiation patterns where semantically valid,
but do not represent relational unions as an unconstrained list of alternatives.

**Open:** constructor shape, helper constructors for existing fixed-length uses, display/equality,
resolution of parameterized templates, and exact interaction with `NativeOrType`.

### Invocations And Operator Identity

**Observed:** `src/Beng/Types/Invocations.hs` stores operator, `Context`, location, parse match, and
return type in `Invocation`. `src/Beng/Invocations.hs` can recover arguments and effective bindings.
Its existential invocation equality currently compares rendered values through `show`.

**Candidate migration:** either parameterize invocation contents by logical category or add a
separate symbolic invocation that preserves declaration identity and corresponding arguments.
Logical matching must not use rendered text as semantic identity.

**Open:** direct reuse, declaration identity source, capture storage, and whether ordinary runtime
invocation equality should change.

### Context

**Observed:** `src/Beng/Types/Build/Context.hs` stores precedence groups and an operator stack.
`src/Beng/Build/Context.hs` defines `empty`, `push`, `fromOps`, `concat`, and `fromThings`; newer
operators are prepended and receive first consideration.

**Candidate migration:** add append-only Proposition history, visibility/admission metadata, stable
IDs, provenance, and obviation without overloading operator `push`. Introduce a dedicated
Proposition admission path that preserves `Proven`, `Disproven`, and `Unproven` distinctions.

`concat` and import paths must not discard history. Merging may require ID remapping; keep that open
until module visibility and import rules are designed.

### Locations And Nonempty Collections

**Observed:** `SomeLocation` is defined in `src/Beng/Types/Locations.hs` and is already used for
operator declarations, bindings, and invocations.

**Observed:** current code imports `Populace` from `Utils.Populace` and `Populace2` from
`Utils.Populace.Populace2`. Verify `Populace` construction and nonempty guarantees before using it
for closest failed attempts.

### Build Configuration

**Observed:** `BengI.cabal` lists modules explicitly under common `other-modules` and enables the
project's existing extension set. New modules require Cabal entries. Cycles may require careful
module boundaries or existing `{-# SOURCE #-}` patterns.

**Agreed architectural requirement:** do not add language extensions without approval. Do not
introduce `.hs-boot` files merely to preserve a poor module split; first design ownership around the
Logical categories, proof artifacts, solver, and context integration.

## Proposed Module Responsibilities

All names are **Candidate representation**:

- a logical types module for formulas, expressions, variables, wrappers, and structural views;
- a proof artifacts module for verdicts, steps, traces, applications, and failed attempts;
- a normalization module;
- a decision module;
- a contextual application/search module; and
- an orchestration module for `simplify` and `prove`.

**Open:** exact module names and dependency direction. Keep compiler-internal patterns separate from
source-representable `Thing` values.

## Migration Worklist

1. **Candidate sequence:** add proof artifact and logical category prototypes without changing
   source parsing or type satisfaction.
2. Add structural views for all formula/expression leaves and compounds; test recursive `It`
   exclusion.
3. Add `withItAs` and tests for consistent replacement in nested formulas, invocations, and
   dependent types.
4. Add branch-local trace construction, step-index allocation, variable freshening, and
   alpha-equivalence support.
5. Add a small normalize-first simplifier and depth-first decision subset with exact step order.
6. Extend `Context` with Proposition admission/history and proof-root access; preserve all existing
   operator precedence behavior.
7. Add directional application candidates and iterative-deepening orchestration for a limited,
   explicitly documented logical subset.
8. Integrate fixed-value and type-to-type Constraint checking with existing `Mismatch` reporting.
9. Add symbolic return-contract validation without circular evidence.
10. Integrate relational union returns with type alternatives and operator resolution after their
    syntax and generalized semantics are settled.
11. Add source parsing/building only after the data model and validation paths are tested.
12. Add broader intrinsic operations, projection laws, imports, caching, effects, diagnostics, and
    backend work in later plans rather than treating them as blockers for the initial solver core.

This sequence is provisional. Change it when tests expose dependency constraints, but preserve the
permanent semantics.

## Deferred Follow-On Integration

The former implementation appendix also identified lower-level work that is not required to start
the pure solver core. Preserve it for later plans rather than silently treating it as complete:

**Candidate sequencing:**

- validate portable source contracts and retain explicit foreign trust boundaries;
- verify exact agreement among portable implementations and target semantics for platform-specific
  operations;
- prototype an observation IR rooted at performed acts and public interfaces, then add backward,
  path-sensitive, and relational propagation;
- select exact-behavior implementations across host/target and separate-compilation boundaries;
- remove runtime prop implementations only after reachability and public-boundary analysis;
- add diagnostic behavior only after all three unsafe execution modes are specified and tested;
- add lexical Proposition visibility and consumer-directed proof imports;
- integrate resource versions, effect contracts, external-state stability, and concurrency into
  proof-context validity;
- add safe exact compile-time execution separately from symbolic proof;
- preserve suspended operation identity and implement proof-validated bounded projections; and
- lower arbitrary positive bit lengths, shifts, exact arithmetic, and projections to C without
  signed-overflow or excessive-shift undefined behavior.

## Test Plan

Add focused tests for:

- recursive rejection of `It` from Proposition formulas and expressions;
- one-subject substitution across every occurrence in a Constraint;
- quantified identity across repeated applications and dependent types;
- normalize-before-decide ordering and no redundant normalization pass;
- multiple nested decision steps rather than one summary step;
- May Prove, May Disprove, and biimplicative result transfer;
- branch-local step indexes under backtracking;
- conclusive-only successful traces;
- tied closest `Unproven` attempts with residual formulas;
- proof-root context availability during nested type compatibility;
- absence of circular return-contract evidence;
- exact bit equality versus cross-length numeric equality substitution;
- relational union alternatives that reject an insufficient short result; and
- cycles, depth exhaustion, and timeouts yielding `Unproven`.

Use existing test-suite organization where practical and run `cabal test` for routine validation.

## Files Expected To Change During Implementation

This is an investigation list, not authorization to change every file:

- `src/Beng/Types/Things.hs`
- `src/Beng/Things.hs`
- `src/Beng/Types/Build/Context.hs`
- `src/Beng/Build/Context.hs`
- `src/Beng/Types/Invocations.hs`
- `src/Beng/Invocations.hs`
- type-test, operator-resolution, parser/build, and diagnostic modules reached from those paths
- `BengI.cabal`
- focused test modules under `src/Testing/Beng/`

Re-run repository searches before editing because constructor uses are distributed across source and
tests.
