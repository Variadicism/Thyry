# Observability, Acts, And Diagnostics

[Proof design index](../design.md)

## Observation Analysis

### Static Contracts And Observation Analysis

#### Two Descriptions Of A Value

Every typeable value retains its full static type under the ordinary [contract](contracts.md) and
[type-validation](contracts.md#type-contracts-and-validation) rules. The static type contains all
applicable props, Constraints, approximation bounds, and relational guarantees. It is the
basis for source checking and proof and is never rewritten to excuse an optimization.

For a pure operation, that authoritative semantics includes one exact deterministic mapping from
effective inputs to logical results even when the static type exposes only a loose bound. The bound
is proof information, not a set from which each invocation or implementation may choose freely.

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
Optimization must preserve the operator selected for each code locus or an exactly equivalent
implementation of that resolved computation; matching source spelling at another locus is
insufficient evidence that the operations are interchangeable.

#### Observation Roots And Backward Propagation

The proposed analysis sequence is:

1. Parse and statically type-check the complete source program, discharge proof obligations, and
   validate implementation contracts.
2. Identify semantic observation roots: the visible results of performed ordinary acts, values
   crossing public APIs and separately compiled boundaries, FFI-visible behavior, and any
   language-defined observable failure, termination, concurrency, or resource behavior.
3. Propagate required predicates, representations, props, path conditions, and value relationships
   backward through all uses.
4. Select, specialize, or remove implementations while preserving exact pure semantics and those
   requirements.
5. Verify that generated observable behavior refines the complete source contracts. Repeat analysis
   when eliminating one use can eliminate further requirements.

This is a proposed architecture, not an implementation mandate. In particular, fixed-point
iteration, proof records for rewritten code, and summaries for separate compilation are unresolved.

If the sole semantic observation is `C > 8`, with `C := B + 5` and `B := A * 10`, analysis may push
the relevant predicate back through `B` to `A`. It need not materialize the complete logical
intermediate values or retain more physical precision than the exact final behavior and all
operation contracts require.

Likewise:

```text
R := Approximation(Theta)
if R > 0,
    print "Positive"
```

If the complete contracts and path context prove every legal `R` is positive, code may print the
message without materializing `R`. If `R`'s allowed range crosses zero, the range alone cannot prove
the branch. The compiler may not choose a different value within that range to force one side: the
resolved pure operation's exact semantics already determines `R` for the effective input.

#### What Preservation Requires

The compiler preserves the exact logical behavior of deterministic pure computation, not the
physical intermediates produced by one evaluation strategy. Instructions, registers, temporary
buffers, layouts, and unused intermediates may differ. Two distinct logical answers such as
`0.4999999` and `0.5000001` are not interchangeable results of one portable pure call merely because
both satisfy a broad bound, even if a current program does not print the value.

Observability is not limited to explicit equality tests. In the [`sin`
example](contracts.md#operator-return-contracts), once the branch proves identical effective inputs
to the same resolved pure operation, `R` and `C` have the same exact logical result by purity. The
compiler may reuse that result or compute it twice with exactly agreeing implementations; no
separate relational return Constraint is needed.

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

### Proof Knowledge Across Effects

Thyrym mutation occurs through acts and is described by affine transformations and resources. An
act's effect contract identifies the transformation and relevant Constraints. The proof system may
use ordinary operator contracts to relate before and after values, but a fact about one resource
version does not silently apply to a different version after mutation.

For example, if `x_before > 0` and an act establishes
`x_after = x_before - 1` under a valid precondition, the solver may establish
`x_after >= 0` but not necessarily `x_after > 0`. This is illustrative rather than proposed syntax.

The affine and effect system determines which resource version remains available and how effects
may interfere. Proof reasoning uses the version-specific values and relationships in those
contracts. External state can change independently, so possession of a handle or an earlier
observation does not preserve a fact unless resource and concurrency contracts establish the needed
stability.

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

The established unsafe-mode names are:

| Thyrym form | Closest Haskell analogy |
|---|---|
| `unsafely once` | `unsafePerformIO` |
| `unsafely each time` | `unsafeDupablePerformIO` |
| `unsafely recursively` | No analogy specified here |

Normative documentation and future source work must not rename these forms to `unsafePerformIO`,
`unsafe`, `debug`, or another invented spelling. The analogies are explanatory, not definitions.
The modes must not be conflated, and this plan does not claim that any mode unconditionally executes
an effect exactly once or permits arbitrary duplication. Their precise guarantees under
optimization and their separate interaction with diagnostics remain unresolved and must be checked
against the authoritative Thyrym definitions when that integration is implemented.

The compiler must not execute an unsafe mode during compilation. Its declared result types and
Constraints remain available for symbolic reasoning, but those contracts do not provide a concrete
result or imply that repeated performances of an act return identical values. Determinism of a pure
value that represents an act does not transfer to repeated performances of that act.

### Proposed Diagnostic Treatment

The intended debugging model is that explicitly diagnostic logging inside pure code does not impose
new semantic observation requirements on logged values. Such a diagnostic may require a valid
string-conversion prop during static checking and may reveal labeled physical implementation details
if the eventual facility permits that. Subject to the selected unsafe mode, it may also be moved,
omitted, or otherwise changed by optimization. It must not by itself force an otherwise unused
logical result or physical intermediate to be materialized.

For example, using placeholders rather than proposed Thyrym syntax:

```text
C := sin(0.5)
R := sin(Theta)
<diagnostic unsafe print> C
<diagnostic unsafe print> R
if Theta = 0.5,
    <ordinary print> (R = C)
```

If the branch establishes identical effective inputs, ordinary uses of `C` and `R` must reflect the
same exact logical result by purity. Diagnostic status is not an exemption that allows the two pure
calls to denote different answers. A future diagnostic may instead omit either value, report
`optimized out`, or explicitly identify nonsemantic physical details rather than present them as
different logical results.

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
