# Proof Design

This documentation describes the planned static contracts, invariant proposition language, proof
system, and observation-driven optimization for the Thyrym interpreter. It is design documentation,
not an implementation or a final source-language specification.

`NativeBitsType` is intended to describe compile-time-checked propositions about the bits
represented by a conforming `NativeBitsValue`. More generally, every typeable value has a complete
static contract. Implementations must satisfy that contract, while generated code only needs to
materialize distinctions that can reach a semantic observer.

> The static type describes what a value promises. Observation analysis describes what generated
> code must make distinguishable to semantic observers. Properly designated diagnostic
> instrumentation may inspect a selected implementation without becoming a semantic observer.

The diagnostic part of that formulation is conditional on an explicit diagnostic facility. General
unsafe effects are not automatically non-semantic.

## Design

- [Contracts and type validation](design/contracts.md) covers portable operation contracts,
  equality, value and type satisfaction, return contracts, and declaration validation.
- [Proof system](design/proof-system.md) covers the invariant language, contextual rules, solver
  behavior, proof artifacts, and worked examples.
- [Observability, acts, and diagnostics](design/observability.md) covers compiler-derived
  observation requirements, runtime prop retention, ordinary acts, and proposed diagnostic
  behavior.
- [Implementation plan](design/implementation.md) assigns responsibilities, records integration
  constraints, and gives likely implementation phases.

## Unresolved questions

- [Unresolved proof design](unresolved/proofs.md) collects open questions about proof algorithms,
  numeric contracts, observation analysis, diagnostics, and architectural placement.

## Rationale

- [Contract and equality rationale](rationale/contracts-and-equality.md) explains
  contract-compatible evaluation and the separation of exact, approximate, IEEE, and bit equality.
- [Proof-system rationale](rationale/proof-system.md) explains the fixed logical core, solver
  separation, directional application, trust boundaries, identity, and provenance.
- [Observability and diagnostic rationale](rationale/observability-and-diagnostics.md) explains the
  separation of static and observable contracts and the conditional treatment of diagnostics.

## Terminology and status

- A **static type** is authoritative and includes all relevant constraints, props, and
  relationships.
- An **invariant** is a proposition used in a type contract or as contextual knowledge.
- A **contract** describes allowed results and relationships. Pure implementations prove their
  contracts; foreign declarations are trusted boundaries.
- **Observable type** is provisional terminology for compiler-derived preservation requirements.
  **Observation contract** may be a more accurate name because requirements can be relational and
  path-sensitive. The representation and final name remain unresolved.
- Examples marked illustrative do not settle Thyrym grammar or Haskell APIs.

## Documentation history

These documents replace `scratch space/Proofs.md`, which combined all design, unresolved questions,
and rationale in one file. That file was previously named `Invariants.md`; the broader name
reflected that invariant propositions are one part of the complete proof and contract design. The
restructure does not rename `Invariant`, `InvariantRule`, or related implementation concepts.
