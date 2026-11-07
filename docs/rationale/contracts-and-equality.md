# Contract And Equality Rationale

[Proof design index](../design.md)

## Deterministic Pure Semantics And Implementation Freedom

### Decision

Every pure operation denotes one deterministic mapping from its effective inputs to exact logical
results. Portable, native, interpreted, precomputed, and compiler-host implementations of one
portable operation must agree on that result. Declared Constraints may reveal only incomplete facts
about the mapping; they never license different results for identical pure calls.

### Rationale

A small exact bit/integer foundation makes portable deterministic mathematics possible, including
future standard-library floating point. A native implementation that differs from the portable
logical result needs an exact fallback, a restricted input domain on which it agrees, or an
explicitly platform-specific operation identity. A platform-specific pure operation remains
deterministic and must not be folded using incompatible host semantics.

This requirement concerns logical values, not identical machine execution. Instructions, registers,
temporary buffers, layouts, and unused intermediate representations may differ. Observation
analysis may avoid materializing distinctions that no source use demands, but it does not turn a
loose return bound into permission to choose another logical result.

Compile-time execution also does not prove general knowledge. Syntax construction requires sound
evidence for one exact string; determinism or one host-selected value alone cannot supply that
proof.

Separating reasoning from execution prevents the solver from performing unsafe acts or native FFI
merely to obtain evidence. Their declarations remain useful as trusted logical contracts without
pretending that execution is safe or that target-specific semantics can be obtained from an
incompatible host implementation.

### Consequences

- Evaluation stage and machine do not change one portable operation's exact logical result.
- Foreign declarations are trusted soundness boundaries.
- Foreign purity promises determinism and absence of hidden effects; ambient state must be fixed,
  explicit, or represented by an act.
- Platform-specific pure semantics require target-correct evaluation.
- Observation analysis may erase physical distinctions only while preserving deterministic source
  semantics and every declared obligation.

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

Proven equal-length `(bits =)` does authorize congruent substitution of the identical bit payload in
pure expressions while preserving typing and resolved operation context. Cross-length numeric
equality first zero-extends `uint` or sign-extends `sint` before exact bit comparison; it does not
make the original unequal-length representations interchangeable. Keeping the relations distinct
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
and software remain implementation choices only where they reproduce the selected operation's exact
logical result.

## Exact Arithmetic Rather Than Implicit Wrapping

### Decision

Intrinsic integer arithmetic widens to represent exact mathematical results. Explicit extraction,
not implicit overflow, requests modular low bits. Public result lengths are selected from proven
static facts and retain the input-length floor; they do not vary with each runtime result's number
of significant bits.

### Rationale

Silent wrapping would make mathematical contracts depend on incidental operand widths and expose C
overflow behavior. Exact results compose more predictably with proof-guided ranges. Retaining a
meaningful logical width still preserves representation intent, while optimization may choose a
narrower physical layout when no observer distinguishes it. Conservative static length selection
also keeps `(bits length)`, extraction, and shifts stable regardless of runtime values.

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
