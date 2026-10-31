# Observability, Acts, And Diagnostics

[Proof design index](../design.md)

## Observation Analysis

### Static Contracts And Observation Analysis

#### Two Descriptions Of A Value

Every typeable value retains its full static type under the ordinary [contract](contracts.md) and
[type-validation](contracts.md#type-contracts-and-validation) rules. The static type contains all
applicable props, invariant constraints, approximation bounds, and relational guarantees. It is the
basis for source checking and proof and is never rewritten to excuse an optimization.

Observation analysis derives a second description for code generation: the properties and
relationships that must remain distinguishable to preserve the program's guaranteed external
behavior. This provisional **observable type** is an optimization artifact, not an alternate source
type. It can include:

- a predicate about one value, such as `R < 1`;
- the representation required by a consumer, such as the exact string produced when formatting
  `R`;
- a relationship, such as `Theta = 0.5` implying `R = C`;
- a fact needed by downstream control flow, an operation, a performed act, or an external caller;
  and
- an executable prop implementation when runtime code can actually invoke that prop.

Requirements can apply only on a particular path and can relate several values. A graph or set of
observation contracts may therefore be more accurate than one ordinary type attached independently
to every value. The representation and the final name remain open.

Contracts still hold when analysis finds no observer. In that case generated code may avoid
materializing a distinction, but source reasoning continues to use the complete static type.

#### Observation Roots And Backward Propagation

The proposed analysis sequence is:

1. Parse and statically type-check the complete source program, discharge proof obligations, and
   validate implementation contracts.
2. Identify semantic observation roots: the visible results of performed ordinary acts, values
   crossing public APIs and separately compiled boundaries, FFI-visible behavior, and any
   language-defined observable failure, termination, concurrency, or resource behavior.
3. Propagate required predicates, representations, props, path conditions, and value relationships
   backward through all uses.
4. Select, specialize, or remove implementations while maintaining those requirements.
5. Verify that generated observable behavior refines the complete source contracts. Repeat analysis
   when eliminating one use can eliminate further requirements.

This is a proposed architecture, not an implementation mandate. In particular, fixed-point
iteration, proof records for rewritten code, and summaries for separate compilation are unresolved.

If the sole semantic observation is `C > 8`, with `C := B + 5` and `B := A * 10`, analysis may push
the relevant predicate back through `B` to `A`. It need not preserve more precision in the three
intermediate values than that observation and all operation contracts require.

Likewise:

```text
R := Approximation(Theta)
if R > 0,
    print "Positive"
```

If the complete contracts and path context prove every legal `R` is positive, code may print the
message without materializing `R`. If `R`'s allowed range crosses zero, the range alone cannot prove
the branch. Whether an implementation may intentionally select a contract-valid result on one side
is part of the unresolved permitted-implementation-choice semantics and must account for every
contract, relationship, and effect.

#### What Preservation Requires

The compiler preserves the behavior guaranteed by the program, not the intermediate bits produced
by one hypothetical evaluation strategy. A hidden difference between `0.4999999` and `0.5000001`
can be irrelevant when no semantic observer can distinguish it. It is relevant when it can affect a
boundary comparison, exact equality, serialization, formatting, hashing, file contents, control
flow, or a required relationship between values.

Observability is not limited to explicit equality tests. Two ordinary prints can expose an equality
violation even when source code never prints `R = C`. In the [relational `sin`
example](contracts.md#operator-return-contracts), ordinary prints inside the equality branch
must not expose incompatible results. Generated code can arrange consistent values or outputs in
any way that honors the source contract.

An exported function or dynamically reachable prop can be observed by an unknown caller. Local
nonuse is therefore insufficient to erase behavior from a public ABI, module interface, or FFI
boundary. Separate compilation must conservatively preserve or explicitly summarize such
requirements.

### Runtime Prop Retention

After complete static checking, proof, and observation analysis, generated artifacts may omit a prop
implementation with no possible runtime caller. A prop used only to establish a type or proof can
justify optimization without carrying all proof machinery into the executable. This changes the
generated product, not the value's static type.

Reachability must account for dynamic prop dispatch, higher-order calls, exports, separate
compilation, foreign boundaries, reflection and serialization if supported, and retained diagnostic
conversion. A diagnostic conversion prop must exist and be valid during checking, but executable
conversion code is required only when the diagnostic can remain at runtime.

## Acts And Diagnostic Observations

### Ordinary Acts

An effect-producing operation such as `print`, a file write, or process creation returns **`an
act`**, comparable in purpose to a Haskell `IO` action. Constructing an act and performing it are
different. A performed ordinary act is a semantic observation root; constructing an unperformed act
does not by itself expose its argument.

An act demands the properties needed for its guaranteed observable behavior, not automatically
every mathematical constraint on every argument. Printing the result of `R > 0` observes that
predicate. Emitting a lossless representation or writing raw bits observes more. Printing both `R`
and `C` on a path where their equality is guaranteed can observe the relationship between them.
Formatting and other operations used to construct the act must still type-check and have valid prop
implementations.

### Unsafe Evaluation Modes

The exact established names are:

| Thyrym form | Closest Haskell analogy |
|---|---|
| `unsafely once` | `unsafePerformIO` |
| `unsafely each time` | `unsafeDupablePerformIO` |

Normative documentation and future source work must not rename these forms to `unsafePerformIO`,
`unsafe`, `debug`, or another invented spelling. The analogies are explanatory, not definitions.
The modes must not be conflated, and this plan does not claim that either unconditionally executes
an effect exactly once or permits arbitrary duplication. Their precise guarantees under
optimization and their separate interaction with diagnostics remain unresolved and must be checked
against the authoritative Thyrym definitions when that integration is implemented.

### Proposed Diagnostic Treatment

The intended debugging model is that explicitly diagnostic logging inside pure code does not impose
new observable constraints on logged values. Such a diagnostic may require a valid string-conversion
prop during static checking and may reveal an implementation-selected approximation if one happens
to be materialized. Subject to the selected unsafe mode, it may also be moved, omitted, or otherwise
changed by optimization. It must not by itself force the compiler to compute, retain, or reconcile
an otherwise unobservable exact intermediate.

For example, using placeholders rather than proposed Thyrym syntax:

```text
C := sin(0.5)
R := sin(Theta)
<diagnostic unsafe print> C
<diagnostic unsafe print> R
if Theta = 0.5,
    <ordinary print> (R = C)
```

Diagnostic logs could expose physical approximations such as `0.47942553` and `0.47942554` while
the ordinary output is `true`, because the ordinary behavior must preserve the abstract equality
contract and the diagnostics are not authoritative snapshots of abstract source values. This is a
deliberate and potentially surprising debugging tradeoff. Documentation must state conspicuously
that a diagnostic or its value may be optimized out; tooling may report `optimized out` instead.

This treatment is conditional. An arbitrary unsafe act is not necessarily a diagnostic. An unsafe
file write can affect a later ordinary read, and ignoring that dependency would change semantic
behavior unless the programmer has knowingly left the language guarantees. A sound design may need
an explicit diagnostic-act contract, capability, or library classification. No such classification
has yet been selected, so general unsafe execution must not automatically be treated as ignorable.

Diagnostic conversion also remains statically checked even if the diagnostic is later erased. Its
runtime conversion implementation need be retained only if the diagnostic itself remains, subject
to the unresolved behavior for conversion failure, cost, and a wholly optimized-away value.

## Related documents

- [Contracts and type validation](contracts.md)
- [Observability rationale](../rationale/observability-and-diagnostics.md)
- [Unresolved proof design](../unresolved/proofs.md)
