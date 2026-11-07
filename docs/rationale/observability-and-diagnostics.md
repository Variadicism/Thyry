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

This freedom applies to physical representation and unnecessary computation, not to logical result
selection. Every pure operation remains one deterministic mapping even when its declared
Constraints expose only a range. Observation analysis cannot choose another value in that range or
allow two implementations of one portable operation to disagree.

Observation requirements are relational and path-sensitive. Later branches, ordinary acts, public
interfaces, and separate compilation can constrain earlier values, so requirements must propagate
backward and may need a graph rather than one independent type per value.

### Consequences

- Ordinary output must preserve promised relationships even without an explicit equality check.
- Public and FFI boundaries remain observation roots for unknown callers.
- Props used only for proof may be absent from generated code, but remain part of static checking.
- Logical bit length and target materializability remain semantic even when code generation uses
  packed bits, registers, shared storage, or another physical representation.
- Identical effective inputs to the same resolved pure operation retain one exact logical result,
  whether computed, reused, folded, or left unmaterialized.
- The terms and representation remain unresolved.

## Unsafe Diagnostics

### Decision

The intended model permits explicitly designated diagnostics to reveal selected implementation
details without adding value constraints to semantic observation analysis. This treatment does not
apply automatically to every unsafe act.

### Rationale

If every debug print forced an otherwise hidden value to be materialized and reconciled, adding
instrumentation would inhibit optimization and alter implementation choices. Non-semantic
diagnostics can instead expose explicitly labeled physical implementation details, disappear, move,
or report that a value was optimized out. They cannot be used to excuse different logical results
for identical pure calls.

General unsafe effects are different. A file write can affect a later ordinary read, so ignoring it
can change the program's semantic behavior. The design therefore needs an explicit diagnostic
classification before this optimization is sound.

`unsafely once`, `unsafely each time`, and `unsafely recursively` retain their established names and
distinct semantics. Their precise optimization guarantees are unresolved; Haskell analogies are not
definitions.

No unsafe mode may be executed during compilation. Keeping its declared result contract available
for symbolic reasoning preserves useful knowledge without exposing compiler-host state or inventing
a concrete result. Pure determinism does not imply that repeated performances of an act agree.

## Versioned Effect Knowledge

### Decision

Proof facts about mutable resources apply to the resource versions identified by affine effect
contracts. They do not silently survive mutation or external interference.

### Rationale

Treating mutable state as timeless would let an earlier observation justify a false later claim.
Before/after contracts allow sound relational reasoning, while resource and concurrency contracts
state when an external fact remains stable.

## Related documents

- [Observability, acts, and diagnostics](../design/observability.md)
- [Unresolved proof design](../unresolved/proofs.md)
