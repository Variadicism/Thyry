# Observability And Diagnostic Rationale

[Proof design index](../design.md)

## Static And Observable Contracts

### Decision

The complete static type remains authoritative for source checking and proof. Observation analysis
derives a second, optimization-oriented description of the properties and relationships generated
code must preserve.

### Rationale

A compiler need not materialize every intermediate bit pattern when no semantic observer can
distinguish it. Weakening the static type to justify that optimization would be unsound: contracts
continue to hold even when no runtime check exists. Keeping the two descriptions separate preserves
source reasoning while allowing implementation details to disappear.

Observation requirements are relational and path-sensitive. Later branches, ordinary acts, public
interfaces, and separate compilation can constrain earlier values, so requirements must propagate
backward and may need a graph rather than one independent type per value.

### Consequences

- Ordinary output must preserve promised relationships even without an explicit equality check.
- Public and FFI boundaries remain observation roots for unknown callers.
- Props used only for proof may be absent from generated code, but remain part of static checking.
- The terms and representation remain unresolved.

## Unsafe Diagnostics

### Decision

The intended model permits explicitly designated diagnostics to reveal selected implementation
details without adding value constraints to semantic observation analysis. This treatment does not
apply automatically to every unsafe act.

### Rationale

If every debug print forced an otherwise hidden value to be materialized and reconciled, adding
instrumentation would inhibit optimization and alter implementation choices. Non-semantic
diagnostics can instead expose an available approximation, disappear, move, or report that a value
was optimized out.

General unsafe effects are different. A file write can affect a later ordinary read, so ignoring it
can change the program's semantic behavior. The design therefore needs an explicit diagnostic
classification before this optimization is sound.

`unsafely once` and `unsafely each time` retain their established names and distinct semantics.
Their precise optimization guarantees are unresolved; the Haskell analogies are not definitions.

## Related documents

- [Observability, acts, and diagnostics](../design/observability.md)
- [Unresolved proof design](../unresolved/proofs.md)
