# Proof Design

This documentation describes the planned static contracts, logical formula language, proof system,
and observation-driven optimization for Thyry, the engine underlying Thyrym. It is design
documentation, not an implementation or a final source-language specification.

The conceptual review is complete. Architecture design is the next phase; detailed Haskell types,
classes, functions, and migration planning follow that review. No complete grammar, final solver
algorithm, or compiler data representation is adopted here.

`NativeBitsType` is intended to describe compile-time-checked propositions about the bits
represented by a conforming `NativeBitsValue`. More generally, every typeable value has a complete
static contract. Implementations must satisfy that contract, while generated code only needs to
materialize distinctions that can reach a semantic observer. Every pure operation denotes a
deterministic mapping: the same resolved operation with identical effective inputs has one exact
logical result.

> The static type describes what a value promises. Observation analysis describes what generated
> code must make distinguishable to semantic observers. Properly designated diagnostic
> instrumentation may inspect a selected implementation without becoming a semantic observer.
> None of these distinctions permits different logical results for the same pure call.

The diagnostic part of that formulation is conditional on an explicit diagnostic facility. General
unsafe effects are not automatically non-semantic.

## Design

- [Contracts and type validation](design/contracts.md) covers portable operation contracts,
  symbolic reasoning versus execution, equality, preconditions, satisfaction, and validation.
- [Proof system](design/proof-system.md) covers logical formulas, contextual propositions, solver
  behavior, intrinsic bit/integer operations, scoped proof knowledge, and proof artifacts.
- [Observability, acts, and diagnostics](design/observability.md) covers compiler-derived
  observation requirements, versioned effect knowledge, ordinary acts, and proposed diagnostics.
- [Implementation plan](design/implementation.md) assigns responsibilities, records integration
  constraints, and gives likely implementation phases.

## Unresolved questions

- [Unresolved proof design](unresolved/proofs.md) collects open questions about proof algorithms,
  numeric contracts, module visibility, effects, observation analysis, diagnostics, and
  architecture.

## Rationale

- [Contract and equality rationale](rationale/contracts-and-equality.md) explains
  deterministic pure semantics, implementation freedom, and the separation of exact, approximate,
  IEEE, and bit equality.
- [Proof-system rationale](rationale/proof-system.md) explains the fixed logical core, solver
  separation, directional application, proof outcomes, trust, and consumer-directed imports.
- [Observability and diagnostic rationale](rationale/observability-and-diagnostics.md) explains the
  separation of static and observable contracts and the conditional treatment of diagnostics.

## Terminology and status

- A **static type** is authoritative and includes all relevant constraints, props, and
  relationships.
- A **Constraint** is a logical condition attached to a type.
- A **Proposition** is standalone contextual logical knowledge, including an `assuming` statement.
- Constraints and Propositions use shared `LogicalFormula`, `LogicalComparison`,
  `LogicalComparator`, and `LogicalExpression` proof machinery.
- A **pure contract** describes one exact deterministic mapping, although its declared Constraints
  and Propositions may expose only incomplete properties of that mapping. Pure implementations must
  implement the same mapping; foreign declarations are trusted boundaries.
- Portable, native, interpreted, precomputed, and compiler-host implementations of one portable
  pure operation must agree on its exact logical result. A platform-specific pure operation may
  define a different mapping for each supported target, but remains deterministic on the selected
  target and requires target-correct compile-time evaluation.
- Operator resolution is context-sensitive but fixed per code locus during compilation. Purity
  follows the resolved declaration and its bindings, not source spelling alone; runtime argument
  values never switch that resolution.
- Intrinsic operation names use **`bits`** for uninterpreted sequences, **`uint`** for unsigned
  interpretation, and **`sint`** for signed two's-complement interpretation.
- **Observable type** is provisional terminology for compiler-derived preservation requirements.
  **Observation contract** may be a more accurate name because requirements can be relational and
  path-sensitive. The representation and final name remain unresolved.
- Examples marked illustrative do not settle Thyrym grammar or Haskell APIs.

## Documentation history

These documents replace `scratch space/Proofs.md`, which combined all design, unresolved questions,
and rationale in one file. That file was previously named `Invariants.md`; the broader name
reflected that logical formulas are one part of the complete proof and contract design. Older
implementation sketches use names such as `Invariant` and `InvariantRule`; those names are legacy
illustrations rather than adopted terminology or final Haskell APIs.
