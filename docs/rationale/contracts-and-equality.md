# Contract And Equality Rationale

[Proof design index](../design.md)

## Contracts Rather Than Bit Identity

### Decision

Safe, portable pure evaluation may occur on the compilation host, on the target, or by another
valid strategy. Symbolic reasoning can use a declared contract even when no implementation may be
executed during compilation. Conformance is defined by the complete contract, not by requiring
every implementation to produce identical intermediate bits.

### Rationale

Native math libraries, CPUs, operating systems, and compiler hosts can produce different valid
floating-point approximations. Requiring bit-identical results would impose disproportionate
portability and performance costs. Explicit contracts make the allowed variation visible while
retaining source-level guarantees.

Individual bounds are insufficient when values have a relational contract. If equal inputs promise
equal abstract outputs, generated code must preserve that relationship wherever it can be observed.
Contract compatibility therefore permits hidden representational variation, not contradictory
ordinary behavior.

Compile-time execution also does not prove exact knowledge. Syntax construction requires proof of
one exact string; one host-selected floating-point result cannot supply that proof.

Separating reasoning from execution prevents the solver from performing unsafe acts or native FFI
merely to obtain evidence. Their declarations remain useful as trusted logical contracts without
pretending that execution is safe or that a result is host-independent.

### Consequences

- Evaluation stage and machine are not source-language properties.
- Foreign declarations are trusted soundness boundaries.
- Platform edge cases require explicit contracts rather than inherited C behavior.
- Observation analysis may erase hidden distinctions only after preserving every individual and
  relational obligation.

## Exact And Approximate Equality

### Decision

Ordinary domain-specific Thyrym equality, approximate equivalence, derived numerical equality, and
intrinsic bit identity are separate relations. Approximate equivalence and ordinary `=` do not by
themselves authorize intrinsic substitution.

### Rationale

Tolerance-based comparisons are generally not transitive, so treating them as substitutive equality
would make proofs unsound. Ordinary Thyrym equality can also be intentionally narrower than
representation identity: two records may denote the same person by identifier while differing in
other fields. Replacing all of one record with the other would be invalid.

IEEE numerical equality has additional behavior—NaN is not reflexive and signed zeros compare
equal—that differs from bit identity. It belongs in a standard-library floating-point contract, not
the intrinsic kernel. Substitution must come only from intrinsic rules whose explicit applicability
conditions have been established.

Keeping the relations distinct lets each comparator own the correct interpretation of bits and
prevents rewrites such as replacing `+0.0` with `-0.0` in a bit-sensitive expression.

## A Small Exact Intrinsic Foundation

### Decision

The intrinsic operation set covers exact bit-sequence behavior and `sint`/`uint` integer
interpretations. Floating point and richer mathematics are standard-library definitions built from
that foundation.

### Rationale

A small exact kernel gives the interpreter and C backend one portable meaning to decide and reason
about. IEEE formats can still receive precise proof-backed contracts without making every format,
rounding mode, exception model, or approximate variant trusted compiler semantics. Native hardware
and software libraries remain implementation choices when they satisfy those contracts.

## Exact Arithmetic Rather Than Implicit Wrapping

### Decision

Intrinsic integer arithmetic widens to represent exact mathematical results. Explicit extraction,
not implicit overflow, requests modular low bits.

### Rationale

Silent wrapping would make mathematical contracts depend on incidental operand widths and expose C
overflow behavior. Exact results compose more predictably with proof-guided ranges. Retaining a
meaningful logical width still preserves representation intent, while optimization may choose a
narrower physical layout when no observer distinguishes it.

## Bounded Extraction From Operation Values

### Decision

An intrinsic extractor may inspect a suspended operation and prove a bounded equivalent computation
without materializing an oversized intermediate result.

### Rationale

Rejecting every expression with an abstract result wider than the target would reject computations
whose demanded projection is fully representable. Making supported projection laws part of the
intrinsic semantics preserves correctness without relying on an optional optimizer pattern. The
rule remains operation-specific, so unsupported projections still need another proof or fail.

## Related documents

- [Contracts and type validation](../design/contracts.md)
- [Unresolved proof design](../unresolved/proofs.md)
