# Active Proof-System Implementation Plan

**Status:** Active planning material. Do not treat this directory as language semantics or a stable
API reference.

The permanent design under [`docs/`](../../../docs/design.md) is authoritative. This directory
translates that design into candidate Haskell structures, algorithm responsibilities, repository
integration work, and implementation sequencing. If a proposal here conflicts with permanent
design, stop and reconcile the conflict rather than changing semantics to fit the proposal.

## Status Labels

Every material proposal uses one of these labels:

- **Agreed architectural requirement** — required behavior or responsibility, even if its Haskell
  spelling is unsettled.
- **Candidate representation** — a useful starting shape that may change during implementation.
- **Open** — requires rule design, repository investigation, or implementation feedback.

Repository facts in `integration.md` use **Observed** and must be reverified before editing. That is
not a proposal status. A naming preference is not a finalized signature.

## Scope

This plan covers the first Haskell proof-engine implementation:

- Logical, Constraint, and Proposition formula/expression categories;
- `It` substitution and solver-readiness enforcement;
- proof verdicts, traces, generated-variable identity, and failed attempts;
- normalize-first simplification, depth-first decision, and contextual search;
- type satisfaction, `Context`, symbolic invocation, and operator-resolution integration;
- relational union return types and existing native bit values/types;
- migration, tests, and Cabal/module integration.

It does not settle the source grammar, complete inference-rule inventories, observation analysis,
effects, floating-point libraries, C lowering, or proof-cache artifacts.

## Required Reading

Read these permanent documents before implementing:

1. [`docs/design/proof-system.md`](../../../docs/design/proof-system.md)
2. [`docs/design/contracts.md`](../../../docs/design/contracts.md)
3. [`docs/design/implementation.md`](../../../docs/design/implementation.md)
4. [`docs/unresolved/proofs.md`](../../../docs/unresolved/proofs.md)
5. [`docs/rationale/proof-system.md`](../../../docs/rationale/proof-system.md)

Then read this plan in order:

1. [`data-model.md`](data-model.md)
2. [`algorithms.md`](algorithms.md)
3. [`integration.md`](integration.md)

## Settled Dependencies

- **Agreed architectural requirement:** simplification normalizes before depth-first decision and
  repeats only after decision reduces the formula.
- **Agreed architectural requirement:** contextual applications are alternatives with
  per-application proof/disproof direction.
- **Agreed architectural requirement:** traces are branch-local ordinary Haskell lists; step IDs are
  zero-based indexes in one trace.
- **Agreed architectural requirement:** a conclusive result keeps only its conclusive path;
  `Unproven` keeps all closest tied attempts with residual formulas.
- **Agreed architectural requirement:** variable identity is declaration origin plus introducing
  proof-step index.
- **Agreed architectural requirement:** nested compatibility checks use the proof-root context plus
  legitimate branch-local knowledge, not a context truncated at a located Proposition.
- **Agreed architectural requirement:** relational union return contracts supersede unconditional
  conservative arithmetic result lengths.

## Open Decisions Before Full Implementation

- Exact depth-first decision rules and partial-reduction representation.
- Complete normalization inventory and canonical orientation.
- General contextual-application calculus, including nested polarity and quantifiers.
- Quantifier opening, witness selection, local assumptions, and dependent-type scope.
- Exact classes, associated types, existential wrappers, leaves, modules, and field names.
- Relational union syntax and generalized arithmetic contracts.
- Failed-path closeness heuristic and resource defaults.

Implement only a deliberately limited rule subset until those decisions are made. Tests must state
that limit rather than implying completeness.

## Implementer Instructions

1. Re-read current declarations before editing; repository structures may have changed since this
   plan was written.
2. Preserve existing style and avoid new language extensions without approval.
3. Keep semantics in permanent docs and implementation discoveries in this plan until they are
   proven durable.
4. Do not use an unvalidated return contract as evidence for itself.
5. Do not execute symbolic invocations, unsafe acts, or foreign code merely to prove a contract.
6. Keep branch traces immutable and assign variable IDs when their introducing steps are created.
7. Prefer a direct `Context` parameter and functional trace accumulation. Do not add a
   `ProofEnvironment` or large search-state wrapper without a demonstrated need.
8. Run `cabal test` during implementation and add focused tests before widening the supported rule
   set.

## Completion And Archival Conditions

Keep this plan under `plans/active/` during implementation. Move it to
`plans/archive/proof-system/` after all of the following are true:

- the implemented rule subset and known limitations are tested;
- exact Haskell interfaces are discoverable from code;
- lasting semantic or architectural discoveries have been reconciled into `docs/`;
- unresolved language/rule questions remain recorded under `docs/unresolved/`;
- migration work is complete and obsolete compatibility paths are removed; and
- the permanent docs have been checked against observed implementation behavior.

Archived plans are historical context, not current API or semantic authority. Preserve them so
future work can understand prior implementation decisions and avoid regressions.
