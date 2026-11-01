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

Ordinary domain-specific Thyrym equality, approximate equivalence, intrinsic numerical equality,
and bit identity are separate relations. Approximate equivalence and ordinary `=` do not by
themselves authorize intrinsic substitution.

### Rationale

Tolerance-based comparisons are generally not transitive, so treating them as substitutive equality
would make proofs unsound. Ordinary Thyrym equality can also be intentionally narrower than
representation identity: two records may denote the same person by identifier while differing in
other fields. Replacing all of one record with the other would be invalid.

IEEE numerical equality has additional behavior—NaN is not reflexive and signed zeros compare
equal—that differs from bit identity. Substitution must therefore come only from intrinsic rules
whose explicit applicability conditions have been established.

Keeping the relations distinct lets each comparator own the correct interpretation of bits and
prevents rewrites such as replacing `+0.0` with `-0.0` in a bit-sensitive expression.

## Related documents

- [Contracts and type validation](../design/contracts.md)
- [Unresolved proof design](../unresolved/proofs.md)
