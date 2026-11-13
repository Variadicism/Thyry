# Proof System

[Proof design index](../design.md)

## Logical Formula Language

The enduring vocabulary is `LogicalFormula`, `LogicalComparison`, `LogicalComparator`, and
`LogicalExpression`. A **Constraint** attaches a formula template to a type; a **Proposition** is a
standalone contextual statement. They share logical machinery but have different admissible
contents and uses.

### Logical, Constraint, And Proposition Categories

Formulas and expressions form a conceptual hierarchy:

1. **Logical** values are the general category and may contain the special `It` placeholder.
2. **Constraint** values are type-constraint templates in which `It` denotes one consistently
   chosen subject.
3. **Proposition** values are solver-ready and contain no `It` recursively.

The distinction applies recursively, including nested logical forms, comparison operands, symbolic
invocations, and dependent type references. Merely labeling an outer formula as a Proposition is
insufficient if one of its descendants can still contain `It`.

Instantiating a Constraint replaces every occurrence of `It` with the same solver-ready subject and
produces a Proposition. This is the conceptual responsibility named `withItAs`; its exact interface
is not specified here. Solver-ready does not mean directly decidable or runtime-executable:
quantified variables and symbolic operator invocations remain valid Proposition expressions.

Multiple Constraints attached to one type denote their conjunction. An empty collection adds no
logical refinement.

`NativeBitsValue` retains the actual length of its concrete bits. `NativeBitsType` describes values
through subject-dependent Constraint templates rather than fundamentally only a fixed integer
length; type combinations can express structural alternatives. The exact representation is not part
of the long-lived architecture.

### Core Model

#### Logical Formula Forms

The formula language contains:

```text
comparison
and
or
not
if
for all
for some
```

These forms can nest arbitrarily. Source terminology is `for all` and `for some`. Constraints and
Propositions use this same logical formula language; there is no narrower rule-only language.

Quantifier representation must preserve scope, variable identity, declaration order, dependent
types, and capture-avoiding substitution. Conjunction and disjunction should contain at least two
children. Construction should avoid unnecessary one-child wrappers. An empty conjunction or
disjunction is an internal construction case, not a user-facing logical formula.

Do not add user-expressible truth-constant formula forms. A simplification or proof step may decide
a formula as true or false, but its enclosing logical form consumes that decision before
reconstructing any remaining formula. For example:

```text
A and true  -> A
A and false -> whole conjunction disproven
A or true   -> whole disjunction proven
A or false  -> A
```

Justification for the eliminated child is retained for diagnostics without creating a displayed
`true` or `false` proof node.

#### Logical Conveniences

Negation and operand reversal remove the need for several primitive comparison families. For the
total intrinsic `uint` and `sint` orderings:

```text
a > b  := b < a
a <= b := not (b < a)
a >= b := not (a < b)
```

For equal-length bit sequences, bit inequality is `not (a (bits =) b)`. Cross-length numeric
equality zero-extends the shorter `uint` or sign-extends the shorter `sint` to the longer length,
then uses `(bits =)`. These are source conveniences or lowerings, not separate primitive
comparators. Each expansion must retain its selected intrinsic interpretation, not use an ordinary
user-defined Thyrym operator merely because it has the same glyph.

Do not universally lower `not (a < b)` to `a >= b` without establishing the ordering laws in use.
A standard-library IEEE relation with NaN is one example where the two can differ; that does not
make IEEE comparison intrinsic.

#### Structural Views

The solver must be able to inspect every logical form and expression kind, including literals,
variables, and symbolic invocations, without weakening the recursive category guarantees. The
architecture does not prescribe a view representation. Structural inspection must not reintroduce
`It` into solver-ready Propositions.

#### Intrinsic Bit And Integer Foundation

Thyry intrinsically understands a small foundation of pure, exact operations on bit sequences and
their signed or unsigned integer interpretations. A built-in has portable mathematical or bit-level
semantics independent of target hardware and C behavior. The solver can decide concrete intrinsic
applications and reason symbolically about unknown operands. The standard library builds richer
mathematics, including floating-point formats, above this foundation.

Built-in names use `bits` for uninterpreted sequences, `uint` for unsigned interpretation, and
`sint` for signed two's-complement interpretation. User-facing libraries may use different terms;
in particular, `integer` retains its mathematical meaning rather than naming the signed built-ins.

The interpreter and C backend must agree on these semantics. LLVM may inspire implementation
choices, but its semantics are not a language dependency. Intrinsics also need not be the idiomatic
user-facing operators: ordinary libraries can provide overloaded and English-like forms.

##### Bit Sequence Domain And Target Capability

An intrinsic bit sequence has an arbitrary positive logical length. Zero-bit sequences are excluded;
a library can model empty collections separately. Lengths may be known only at runtime, so dynamic
concatenation and extraction are valid when their proof obligations can be discharged.

Bit order is conceptually left to right, with the most significant integer bit on the left. This
does not prescribe byte order, memory layout, or physical storage. The compiler may use packed bits,
registers, arrays, sharing, multiple allocations, or another representation while preserving the
logical length and observable contract. Individual `yes` and `no` literals plus concatenation are
sufficient construction primitives; repetition needs no intrinsic.

Use **length** for the count of bits in an ordered sequence, **width** when discussing an integer
representation or machine operation, and **size** for physical storage or allocation.

Each target defines `MaximumSupportedBitSequenceLength`, written `M`: the greatest logical length of
a bit-sequence value that can be materialized for that target. `M` is a compiler and representation
capability, not the amount of installed or currently free memory, and a logical sequence may span
multiple allocations. Runtime allocation failure remains a separate resource concern.

Pointer or byte-count width does not directly determine the width needed to count bits. On an
8-bit-byte target, a hypothetical 32-bit byte count can require a 35-bit bit count; a 64-bit byte
count can require 67 bits. When complete target information is unavailable, a documented
conservative profile such as a 64-bit bit-count capability is acceptable, but is not a universal
language limit.

The bit-length result must be wide enough to represent every possible length in its domain. For
known finite `M`, the minimum general width is:

```text
max(1, ceil(log2(M + 1)))
```

Constraints may establish tighter bounds for particular values. Compilation always uses the target
capability even when proof evaluation runs on another host. Integer interpretations inherit the
same maximum bit-sequence length. An `M`-bit `uint` ranges from `0` through `2^M - 1`, and an
`M`-bit `sint` ranges from `-2^(M-1)` through `2^(M-1) - 1`.

##### Core Bit Operations

The following operations are intrinsic. Spellings communicate the selected design but do not stand
in for complete declarations or type signatures.

| Operation | Spelling | Semantics and restrictions |
|---|---|---|
| Bit equality | `(bits =)` | Exact comparison of equally sized sequences. |
| Bitwise AND | `(bits &)` | Pointwise AND of equal-length operands. |
| Bitwise OR | `(bits \|)` | Pointwise OR of equal-length operands. |
| Bitwise XOR | `(bits ^)` | Pointwise XOR of equal-length operands. |
| Bitwise NOT | `(bits ~)` | Pointwise inversion. |
| Concatenation | `(bits ++)` | Left operand followed by right; lengths add. |
| Left prefix | `(bits *:)` | Take a positive count from the left. |
| Right suffix | `(bits :*)` | Take a positive count from the right. |
| Left shift | `(bits <<)` | Fixed-length, zero-filling; discard shifted-out bits. |
| Logical right shift | `(uint >>)` | Fixed-length, zero-filling right shift. |
| Arithmetic right shift | `(sint >>)` | Two's-complement sign-filling right shift. |
| Bit length | `(bits length)` | Return length as a wide-enough `uint`. |

Extraction takes a count rather than an inclusive index and requires:

```text
1 <= count and count <= length(source)
```

Single-bit and arbitrary positive-length results are supported. Prefix and suffix extraction compose
to express interior slicing. The `++`, `*:`, and `:*` spellings were chosen for readability; `#` was
rejected because of its association with comments.

Shift amounts must be nonnegative and strictly smaller than the source length. Shifting by the
length or more is not a valid intrinsic application. The source length is preserved. A left shift
constrains the rightmost shifted-in bits to zero; a logical right shift constrains the leftmost bits
to zero; an arithmetic right shift constrains them to the source sign bit. Portable lowering must
not inherit C's excessive-shift or signed-shift behavior.

Uninterpreted binary bit operations require equal lengths and do not infer zero or sign padding.
Rotation, byte swapping, population count, zero or sign extension, repetition, and arbitrary
interior slicing need no separate intrinsic; libraries can define them from these foundations, and
the optimizer may recognize the resulting patterns.

Intrinsic proof and normalization knowledge includes relationships such as
`length(A ++ B) = length(A) + length(B)`, extraction lengths and reconstruction, and the effects of
shifts and bitwise operations. Bitwise binary results retain their shared operand length, NOT
retains its source length, extraction has the requested positive length, and shifts retain the
source length. These are facts about the listed operations, not requests for more built-ins.

##### Exact Integer Arithmetic

Intrinsic `uint` and `sint` arithmetic denotes exact mathematical results rather than fixed-length
wrapping. Explicit low-bit extraction requests modular behavior. The intrinsic arithmetic families
include addition, subtraction, multiplication, division, and remainder.

Arithmetic supports different operand lengths when interpretation is unambiguous, conceptually
zero-extending `uint` values and sign-extending `sint` values. Signed and unsigned families remain
distinct because interpretation, signedness, and return relationships differ. Lengths may be
arbitrary positive lengths within target capability; there is no intrinsic 8-, 16-, 32-, or 64-bit
limit. Unary arithmetic negation needs no intrinsic because subtraction from zero expresses it.

Arithmetic return contracts may use relational union types when more than one representation is
valid. For example, the following illustrative contract permits an eight- or nine-bit sum while
forbidding the shorter alternative when the value needs a ninth bit:

```text
8 bits or 9 bits where not (A + B >= 256 and Length of it = 8)
```

The relationship constrains the selected result; it does not classify one alternative as a
compile-time result and the other as a runtime result. The exact syntax and general rules for these
unions remain unresolved. In particular, this design supersedes the older rule that `Unproven`
overflow automatically selected one unconditional conservative length.

At each source locus, context-sensitive resolution still selects one specific operator during
compilation. That choice may depend on available declarations, ordering, Constraints, and
established proofs, but not on runtime argument values. A relational return type does not make
operator identity runtime-dependent.

Arithmetic never silently truncates, wraps, or inherits C signed-overflow behavior. A backend may
use unsigned instructions, multiple machine words, or another representation only when it preserves
the exact arithmetic result and the selected relational contract.

##### Division, Remainder, And Ordering

Division requires proof that the divisor is nonzero. Signed division truncates toward zero, with
the corresponding remainder convention. The minimum signed value divided by `-1` yields its exact
positive negation; its return contract must admit a representation that can contain that result.
Arithmetic right shift is sign-filling and is not a substitute for truncation-toward-zero division
on negative values.
All demanded result lengths remain subject to target materialization capability. Established
Constraints, control-flow refinements, contextual Propositions, or an explicit non-disproven
assumption may discharge a precondition; `Unproven` alone never does.

`(uint <)` and `(sint <)` are distinct intrinsic ordering comparisons. They accept differing operand
lengths and compare numeric interpretations after conceptual zero or sign extension. Other ordering
forms are derivable from logical connectives. Together with `(bits =)`, these are the complete
intrinsic logical comparator set.

One equal-length `(bits =)` intrinsic is sufficient. Separate `sint` and `uint` equality intrinsics
would add no information for equal-length representations. Cross-length numeric equality extends
the shorter operand according to its selected integer interpretation, then applies `(bits =)`. It
does not authorize substituting the original unequal-length representation in a length-sensitive or
bit-sensitive operation.

Other comparisons, minimum and maximum, and absolute value are derivable and need no additional
intrinsics. Solver normalization or established Propositions may expose their relationships.

Intrinsic comparators provide context-independent concrete decisions and candidate applications
relating established comparisons to goals. Exact signatures for decision and application remain
open; applications must expose obligations, bindings, justification, and implication direction.

Source Constraints may state relationships involving the same arithmetic operation whose result
they constrain because the compiler supplies the primitive semantics. This does not permit a
user-defined operation to use its own promised return Constraint as circular evidence.

##### Operations As Values And Bounded Extraction

Thyrym operations are first-class values, and a nullary operation can be treated implicitly as its
result. Intrinsic extraction may inspect an unevaluated operation returning bits rather than first
materializing that operation's entire result.

This distinction permits a valid composition whose abstract intermediate result exceeds `M` when
the final demanded extraction is representable. For a hypothetical target with `M = 8`:

```text
(A (uint +) B) (bits :*) 8
```

If `A = 255` and `B = 1`, the exact sum needs nine bits, but its low eight bits are `00000000`.
The extractor can recognize intrinsic unsigned addition and establish a projection law such as:

```text
rightBits(N, uintAdd(A, B)) = (A + B) mod 2^N
```

Multiplication admits a similar law:

```text
rightBits(N, uintMul(A, B))
    = ((A mod 2^N) * (B mod 2^N)) mod 2^N
```

The compiler can then construct and validate a bounded equivalent computation without materializing
the oversized result. Source validity depends on this proof-backed intrinsic behavior, not on an
opaque optimizer noticing a pattern. A backend may use native wrapping unsigned operations or
multiword computation when either reproduces the exact bounded result.

Representability of the suspended operation is distinct from materializability of its result. `M`
applies when a bit-sequence value must be materialized, not automatically to every abstract
intermediate described by an operation value. The compiler must preserve intrinsic identity,
operands, bindings, and proof knowledge through relevant higher-order use.

Because intrinsic extraction can recognize other intrinsic operations directly, this design does
not require new user-visible metadata on every built-in.

Projection is operation-specific. Truncating operands before division generally does not preserve
the quotient's low bits, so the compiler must use another justified computation or reject the
demand. User-defined operators advertising proven projection laws are a possible future extension,
not a requirement of the intrinsic foundation.

##### Floating Point Is A Standard-Library Concern

Floating-point arithmetic and comparison are not intrinsic operations. IEEE formats and behavior
can be defined in the standard library from exact bit and integer primitives, initially for
binary32 and binary64 if practical. Width does not identify format: binary16 and bfloat16 are both
16 bits but have different layouts.

The compiler may select native CPU or GPU instructions only where they reproduce the exact logical
result of the standard-library operation's portable definition. Otherwise it needs exact emulation
or explicitly platform-specific semantics; a loose return bound cannot excuse disagreement. A
portable bit/integer definition supplies a host-independent mathematical baseline. Berkeley
SoftFloat is a possible backend or test reference, not formal proof; its rounding mode, exception
state, and 64-bit-integer requirements need deliberate integration with Thyry's pure model.

Exact IEEE behavior, approximate variants, fast math, restricted exceptional-value support, and
other choices need distinct contracts, and every pure variant remains deterministic. A separately
defined approximate result cannot replace a promised bit-exact result. Rounding modes, NaNs,
infinities, signed zero, subnormals, and exception reporting remain standard-library design topics
rather than reasons to enlarge the intrinsic kernel.

Foreign interoperability, external resources, and I/O acts remain existing language mechanisms,
not missing mathematical intrinsics.

#### Logical Expressions, Variables, And Symbolic Invocations

Logical expressions include concrete bit literals, explicitly scoped quantified variables, and
symbolic operation applications.

Every quantified variable records its original declaration identity or location, the proof step
that introduced or freshened it, and its declared parameterized type. Variable identity consists of
the declaration origin together with the introducing proof-step ID. A display name and declared type
do not constitute identity.

Freshening the same declaration in two applications produces distinct variables. Within one
application, every occurrence—including references in dependent parameterized types—must receive
the same fresh identity. Substitution is capture-avoiding. Alpha-equivalence is separate from
identity and is used when comparing goals for search-cycle detection.

Universal and existential binders use the same kind of variable; the enclosing `for all` or
`for some` supplies the quantifier kind. Types are first-class values, so variables may range over
types and later declarations may use earlier bound values or types as parameters. No special
`type of A` expression is needed.

Constraints from a quantified variable's declared type remain part of the reasoning. Universal
constraints act as implications, while existential constraints act as conjunctions. Structural
domains and logical Constraints remain distinct, and neither may be silently discarded.

Symbolic applications such as `sin(x)` are propositions about operation results. They must preserve
operator identity, bindings, argument structure, captures, dispatch evidence, and result type
without running merely because they occur in a formula. An intrinsic consumer such as bounded
extraction may inspect a suspended operation and prove an equivalent bounded computation without
evaluating the original full result. Runtime `Invocation` may be reused, parameterized, or separated
into a symbolic representation; preserving operation identity and the materialization boundary is
the requirement.

Every pure operation is deterministic and extensional by definition. Once proof establishes the
same resolved pure operation and identical effective inputs, the invocations have the same exact
logical result without an extra return Proposition. This does not make different operators with the
same syntax or result type identical, and an ordinary domain equality does not establish matching
bit payloads unless its validated semantics say so. A bare operator declaration and an invocation
with bound arguments are also different expressions.

Resolution itself is context-sensitive but not runtime-dependent. Each code locus resolves during
compilation using the surrounding grammar, available declarations and ordering, Constraints, and
established proofs. Identical syntax at another locus may resolve to another declaration. Purity is
therefore keyed to the resolved operation identity and effective inputs rather than spelling alone.

Operator identity must use declaration identity rather than a printed rendering. Its exact
representation and interaction with invocation equality are not specified here.

#### `one` And `it`

Keep the source-level roles distinct:

- `one` is the subject used for `NativeType` property declarations and definitions.
- `it` is the placeholder used when writing or displaying Constraints attached to a type.

`It` is not an existential witness, an implicit universal quantifier, or a logic variable for the
solver to bind. It is removed when the type's Constraint template is instantiated. The solver
accepts only recursively `It`-free formulas.

For display and structural equality, instantiate the template with a designated `It`. For proof,
instantiate it with the actual subject expression. To validate a standalone type declaration,
instantiate it with a fresh, unconstrained symbolic expression of the unrefined underlying type.
Do not pass the type object as though it were a runtime value, and do not assume the type's own
refinements while validating those refinements.

The architectural requirement is recursive removal of `It` before solver entry, not any particular
implementation category or wrapper.

## Propositions And Context

### Propositions With Metadata

A contextual Proposition is an arbitrary logical formula plus metadata. It does not have separate
`premises` and `conclusions` fields. The proposition itself contains implication and quantifiers:

```text
for all x, y, z:
    if x < y and y < z then x < z
```

Variables are explicitly bound by quantifiers rather than inferred from separate premise and
conclusion lists. Closed facts and rules are logically valid. An unused quantified variable, such
as `for all x: 5 < 7`, should produce a warning rather than make the assertion invalid.

#### Trust And Assumption Policy

Source declarations distinguish proof from trust:

```text
Proven assertion: admit as established knowledge; a duplicate may be marked obviated.
Disproven assertion: reject at its source location.
Unproven assertion: admit only through explicit `assuming` syntax.
```

An assumption is the programmer's explicit responsibility and is available only within its lexical
scope. An assumption that established knowledge disproves is a compilation error. A contradiction
that becomes detectable later must also be rejected with provenance where possible, although the
compiler cannot guarantee detection of every inconsistency among arbitrary assumptions.

Once admitted, a trusted foreign contract participates in ordinary proof reasoning with the same
logical status as other established contracts. Its trust provenance remains attached for auditing
and diagnostics rather than creating a weaker class of logical fact.

A conditional assertion is validated as a whole implication. In classical logic, `if P then Q` is
false only when `P` holds and `Q` fails. A conclusion that conflicts with established facts under an
antecedent proven false does not make the implication false. An antecedent that is merely unproven
is not thereby false.

Consequently, the former conservative proposal to assume a conditional's premises during insertion
and reject any hypothetical conflict is discarded. Validation may reject the implication when it
can establish the antecedent and disprove the consequent, but must not conflate impossibility,
unknownness, and contradiction.

#### Provenance And Identity

Proposition identities remain stable within append-only context history and do not depend on active
list positions. Nested paths may identify a component for derivation and diagnostics, but do not
turn a child of a disjunction into independently established knowledge.

Justifications preserve source or intrinsic locations, derivation links, and trust provenance.
Compiler-owned decisions and normalizations also record their reasons. Exact record representations
are not specified here.

### Compiler Logic Versus Contextual Libraries

Fundamental logical simplification is fixed by the compiler. There is no separate configurable
“fundamental logical inference rules” subsystem. Users cannot replace conjunction, negation,
implication, or quantifier semantics.

Built-in contextual assertions can still provide mathematical or domain knowledge, such as:

```text
bit equality symmetry and transitivity
integer less-than transitivity
exact arithmetic laws under the correct domain and materialization premises
properties of explicit conversion operations
domain bounds for standard-library or foreign operations
```

These assertions use the same contextual application machinery as user-authored established rules
and assumptions. They must respect intrinsic semantics and the contracts of higher-level
operations. In particular, unconditional float equality reflexivity is invalid for a
standard-library IEEE numerical equality because NaN is not equal to itself.

Ordinary Thyrym equality and other user-defined comparisons remain above this intrinsic foundation.
Their contracts and established Propositions can provide derived knowledge, but cannot redefine
logical connectives, comparator semantics, or substitution authority. Standard-library laws that
relate domain equality to ordering likewise belong in the Thyrym layer rather than the intrinsic
proof foundation.

Proven `A (bits =) B` directly authorizes congruent substitution of those identical bit sequences in
pure expressions, provided expression typing, resolved operation identity, bindings, and other
applicability conditions remain valid. This foundational rule does not turn Apply into a general
algebraic simplifier or grant the same authority to ordinary `=`, approximate equality, IEEE
numerical equality, or cross-length numeric equality between the original representations.

### Lexical Scope, Visibility, And Proof Imports

Operator resolution and proof search both use contextual knowledge that grows and shrinks with
lexical scopes. Existing `using FILE, DO` and selective `using STUFF from FILE, DO` forms can place
imports in a local block rather than permanently extending a file's context.

At file or module scope, standalone Propositions—including those introduced with `assuming`—may be
private or exportable independently of operator visibility. An assumption inside an operator body
remains local to that body and is not a top-level export candidate. Private Propositions may justify
an implementation or a public contract, but arbitrary external proof queries must never use them as
premises.

An exported operator carries its complete public declared type and Constraints. Callers need no
separate Proposition to recover a guarantee already present in that type. Additional public
Propositions relating several operators are optional knowledge and need not accompany every import
of those operators.

A proof import requests the precise goal the consumer needs rather than matching one exported
declaration. Conceptually, and without settling syntax, a form like:

```text
using proof that P from FILE, DO
```

asks the solver to establish `P` from the importing scope's existing context together with only the
selected module's public operator contracts and exported Propositions. `P` may be weaker than one
exported theorem or may follow from several public facts and mathematical rules already in the
caller's context. Private facts in the selected module are unavailable to this query.

On success, only the requested `P` becomes available in the importing block, with the dependencies
needed for its scoped validity and provenance. Importing it is subject to ordinary contradiction
checks. `Unproven` never causes a proof import to be accepted as an assumption.

More generally, a derived Proposition remains valid only while the premises used to establish it
remain available, unless sound reasoning has discharged those dependencies.

For example, if a module publicly establishes that every rectangle width is positive, a caller may
request only nonnegativity. That weaker request can reduce dependence on an unnecessarily strong
theorem. It does not erase a stronger Constraint already exposed in an imported operator's type or
weaken another operator's argument preconditions.

Public knowledge from multiple sources may combine. A caller could derive
`cosine(0) > cosine(pi)` from a public strict-decrease theorem and suitable ordering facts even when
no module exports that exact formula. Conversely, a private assumption about rectangle height must
not satisfy an external query unless the module deliberately exports an appropriate theorem.

## Solver

### Three Solver Mechanisms

One solver orchestrates normalization, decision, and contextual application. Conceptually,
`simplify` coordinates the first two, `search` finds contextual alternatives, and `prove` controls
recursive exploration and verdict interpretation. These are responsibilities rather than frozen
implementation interfaces.

#### Normalize

Normalization is compiler-defined, context-independent, deterministic, meaning-preserving
canonicalization. It always produces another formula rather than a truth constant. Examples
include:

```text
not (not P) -> P
P and (if P then Q) -> P and Q
```

The second transformation is a bi-implication:

```text
P and (if P then Q) <-> P and Q
```

By contrast, dropping `P` as well is only one-way:

```text
P and (if P then Q) -> Q
```

That one-way consequence is not normalization.

Normalizers may use compiler-internal formula metavariables that match an arbitrary formula.
These are not exposed as source-level proposition variables, so user rules cannot redefine logic.

Normalization must not search `Context` or require unproven prerequisites. Domain-specific
equalities and mathematical laws belong to contextual application. Normalizers must be sound in
the selected theory, deterministic, idempotent at a fixed point, and oriented to avoid oscillation.
Operation domains, representation-sensitive bit behavior, and higher-level contracts prevent
blindly applying real-number algebra.

#### Decide

Decision is compiler-defined, direct, and context-independent. It proceeds depth-first through
constituent expressions and subformulas before deciding their enclosing form, while permitting
sound short-circuiting. Intrinsic comparators decide atomic comparisons when their operands provide
enough information. Compiler-owned logical patterns can also decide propositions such as
`P and not P`, where `P` may be an arbitrary nested proposition.

A decision attempt may settle the whole formula, partially reduce it, or make no progress. A
partial reduction records every individual nested decision with its rule and affected path; one
summary rule is insufficient when several children were decided. Expression decisions may produce
values, while formula decisions produce truth judgments. Exact result representations remain open.

No progress is not evidence that the formula is false. A terminal decision does not construct a
truth-constant formula. Decided children are consumed by their enclosing logical forms, with their
individual reasons retained in the trace.

#### Apply

Application consults established contextual assertions and transforms a goal into obligations with
an explicit logical direction. It covers whole goals and nested expressions, but there is no fourth
subsystem for equality rewriting. Substitution authority comes from intrinsic logical semantics and
rules with explicit applicability conditions. Contextual Propositions may establish those
conditions or provide derived knowledge, but an ordinary Thyrym equality does not define a new
substitution rule. Exact `(bits =)` is the foundational congruence rule; contextual knowledge and
normalization handle deeper algebraic consequences.

This matters for relations such as standard-library float numerical equality and intrinsic bit
identity. Replacing `+0.0` with `-0.0` in an arbitrary bit-sensitive expression is unsound even
though they are numerically equal under IEEE equality.

### Local Simplification Fixed Point

Local simplification is independently callable so source declaration validation can identify direct
and nested vacuity or contradiction without contextual search.

It proceeds in this order:

```text
1. Normalize the current formula to normal form, recording each transformation in order.
2. Run depth-first decision over the normalized formula and its constituents.
3. If decision settles the formula, return Proven or Disproven.
4. If decision produces a residual formula, repeat from normalization on that residual.
5. If decision makes no progress, return the normalized residual as locally Unproven.
```

Normalization is not repeated merely because it produced trace steps: it has already reached normal
form. A new pass occurs only after decision reduces the formula. The history records each rule,
bindings, affected path or subexpression, and justification. Normalization and combined iteration
require termination safeguards.

### Contextual Proof Search

After local simplification leaves a residual goal, `search` finds contextual applications and
`prove` explores them:

```text
1. Check branch-local cycle and resource limits.
2. Enumerate applicable contextual assertions from most recent to oldest, subject to scope and
   visibility. One assertion may yield multiple applications.
3. Record each application's obligation, direction, bindings, target path, and justification.
4. Explore applications as separate immutable branches; do not accumulate unrelated rewrites into
   one goal or split a conjunction in a way that loses cross-dependencies or quantifier scope.
5. Recursively prove each candidate, beginning again with normalization and decision.
6. Interpret a conclusive result according to that application's direction.
7. Backtrack when a branch is inconclusive and retain the closest failed attempts.
```

A loop, timeout, exhausted resource budget, or lack of a matching path yields `Unproven`, not
`Disproven`. An application need not pass a speculative complexity-progress test. Soundness,
applicability, fixed-point termination, and global cycle/resource guards are the controls.

Branch-local cycle detection compares normalized, alpha-equivalent goals together with the relevant
context. Iterative deepening is favored over unrestricted depth-first wandering; application count
is a suitable initial depth measure. The closeness heuristic for unsuccessful paths is diagnostic
only and must never alter the verdict.

Application and nested type-compatibility checks use the context in which the current proof began,
not a context prefix truncated at the proposition being applied. Recursive reasoning may add
properly scoped branch-local bindings and assumptions, but must not admit circular evidence.

Encountering the original goal again through a cycle such as `A -> B` and `B -> A` does not prove
either formula. A nonproductive cycle remains `Unproven` unless independent evidence closes it.

#### Outcome-Direction Contract

For replacement obligations `R` and original goal `G`:

| Direction | Logical guarantee | If `R` is proven | If `R` is disproven |
|---|---|---|---|
| **May Prove** | `R -> G` | `G` proven | Inconclusive |
| **May Disprove** | `G -> R` | Inconclusive | `G` disproven |
| **May Prove or Disprove** | `G <-> R` | `G` proven | `G` disproven |

An unproven replacement is inconclusive in all three cases. “May” identifies which eventual solver
outcome the direction can transfer; it is not itself a proof result. The actual judgments remain
`Proven`, `Disproven`, and `Unproven`. These are conceptual labels rather than prescribed
constructor names.

Direction remains important when a rule itself has a condition. If the rule has antecedent `P`,
its consequent comparison applies to `G`, and the comparison application produces `R`, then:

- for **May Prove** (`R -> G`), `P and R` is a sufficient obligation;
- for **May Disprove** (`G -> R`), `if P then R` is a necessary obligation; and
- **May Prove or Disprove** may require two separately directed implications.

Using `P and R` for the necessary direction could unsoundly disprove `G` merely because `P` is
false. The generalized algorithm for deeply nested logical forms is deferred, but it must preserve
this constraint.

#### Compound And Quantified Knowledge

The architecture must support the established logical behavior even though the complete inference
calculus is not specified here:

- A known conjunction exposes all conjuncts in the same branch.
- A known disjunction does not expose either child unconditionally. Proving a consequence from it
  may require proving that consequence under every alternative.
- Contextual application must handle compound goals and applications useful for both proof and
  disproof, not only atomic comparisons.
- Negation and implication must preserve their ordinary proof/disproof directions.
- Quantifier scopes and order matter. `for all x: for some y: y = x` differs from
  `for some y: for all x: y = x`.
- Each rule application gets fresh variable identities. Bindings are branch-local, type-checked,
  capture-avoiding, and shared consistently within the scope of that application.
- Existential witnesses may be discovered by matching established facts rather than blind value
  enumeration.

For example, transitivity can be written as:

```text
for all a, b:
    if for some y: a < y and y < b
    then a < b
```

A necessary condition derived while testing a goal is not automatically biimplicative with that
goal. If the condition is disproven, it disproves the goal only when the recorded direction says
that the goal implies the condition.

### Recursion, Pursuits, And Search Cycles

Mutually recursive operators and Constraints remain subject to Thyrym's pursuit and convergence
requirements. Proof that an operator converges is not by itself proof that its value satisfies its
declared return contract; that result obligation still needs independent evidence.

Both pursuit convergence and proof-search cycle/resource handling are required capabilities. This
design does not assert that they are fundamentally separate mechanisms or that they must share one
mechanism. Their architectural relationship, including any sound induction support, remains open.

### Proof Results And Artifacts

The solver needs at least these semantic outcomes:

```text
Proven
Disproven
Unproven
```

Each outcome concerns one specific goal under its relevant context and quantification. `Disproven`
requires an actual refutation, counterexample, or logically established negation. Exhausting rules,
knowledge, time, or resources yields `Unproven`. When a program requires the goal, `Unproven` is
insufficient unless the programmer introduces an explicit, non-disproven `assuming` premise.

Each explored path has its own chronologically ordered proof trace. Normalization, decision, and
contextual application all append individual steps. A step records the formula or expression before
the transformation, the rule or reason, and relevant path, location, bindings, and provenance. The
final result or residual supplies the endpoint, so each step need not duplicate an `after` value.

A proof-step ID is the zero-based index of that step in its trace. Step zero is the initial goal.
The same index may identify different steps in different branches, and a step does not redundantly
store its own ID. Variables introduced by a transformation refer to the actual introducing step
index, so trace construction and variable construction must remain consistent.

Successful proof and disproof results retain only the conclusive path. An `Unproven` result retains
a nonempty collection of the closest attempts; every attempt contains both its trace and its final
unresolved formula. All ties are retained. Optional debug logs may record every explored path, but
they are separate from returned proof traces.

Useful proof artifacts record:

```text
the rule or native decision used
fresh and matched bindings
the targeted formula and nested path
the justification and source provenance
the implication direction for contextual applications
branch-local loop/resource information
```

There is no cross-trace result cache in the initial architecture. Future memoization must preserve
every relevant contextual dependency and must not compromise trace and variable identity.

Avoid displaying trivial intermediates unless needed to explain a result. Source validation must
still be able to identify terminal whole formulas and vacuous, contradictory, or redundant nested
components.

A future module or intermediate artifact may carry validated proofs and their dependency information
for cross-module and incremental reuse. Reuse is sound only while definitions, Propositions,
assumptions, imports, visibility, target capabilities, and every other dependency remain compatible.
The exact artifact and invalidation design is unresolved.

### Proof Examples

#### Comparison Application

Known fact and goal:

```text
known: x (uint <) 7
goal:  x (uint <) 8
```

The unsigned comparator can propose an application because the lesser expressions match. One
possible replacement expresses that the requested bound is not less than the known upper bound:

```text
R: not (8 (uint <) 7)
direction: May Prove (R -> G)
```

Direct decision proves `R`, so the goal is proven. The same fact is irrelevant to a goal requiring
a lower bound such as `2 (uint <) x` unless other established knowledge connects the bounds.

This is an illustrative application, not a complete specification of integer bound reasoning.

More generally, given established `A (uint <) B`, analogous signed applications include:

| Goal `G` | Replacement `R` | Direction |
|---|---|---|
| `A < C` | `B < C` | **May Prove** |
| `B < C` | `A < C` | **May Disprove** |
| `C < B` | `C < A` | **May Prove** |
| `C < A` | `C < B` | **May Disprove** |

These are direct comparison applications, not a request for a large built-in algebraic rewrite
inventory. Each application retains its signed or unsigned interpretation.

#### Less-Than Transitivity

Context contains:

```text
a < b
b < c

for all x, z:
    if for some y: x < y and y < z
    then x < z
```

To prove `a < c`, an application of the conditional's consequent creates a sufficient obligation
that includes its antecedent. Matching established facts can discover `y = b`. The two conjuncts
then prove, so the conditional establishes the goal.

Every application receives a fresh identity for `y`; a witness discovered here does not leak into
another use of transitivity.

#### Bound On An Operation

Assume the candidate type establishes:

```text
-2*pi <= subject
subject <= 2*pi
```

and context contains an established law:

```text
for all x:
    if -2*pi <= x and x <= 2*pi
    then -1 <= sin(x) and sin(x) <= 1
```

To prove `sin(subject) < 7`, contextual application can instantiate `x` with `subject`, discharge
the two range obligations from candidate knowledge, and use the upper bound with ordinary ordering
knowledge to establish the goal. Each `<=` above is logical shorthand under the selected ordering
and equality interpretation, including any required integer extension.

This example does not imply that `sin` is executed by the proof engine. Its mathematical behavior
comes from established assertions about the symbolic invocation.

#### Directional Type-Level Disproof

Known fact and goal:

```text
known: 10 < Index
goal:  Index < 7
```

If the goal held, transitivity would require `10 < 7`. This is a **May Disprove** (`G -> R`)
application. The integer comparator disproves the replacement, so the direction contract permits
the solver to disprove the goal.

Without that direction, a false derived condition would not by itself justify disproof. If no sound
path proves a goal or proves a necessary condition false, the result remains `Unproven`.

#### Conditional Consistency

Suppose established knowledge says:

```text
halts(Machine) = no
```

The assertion `if P then halts(Machine) = yes` is not disproven merely because its consequent
conflicts with that fact. If `P` is proven false, the implication is true. If `P` is unproven, the
implication may remain unproven. It is disproven only when the solver establishes `P` and disproves
the consequent.

## Related documents

- [Contracts and type validation](contracts.md)
- [Implementation architecture](implementation.md)
- [Proof-system rationale](../rationale/proof-system.md)
- [Unresolved proof design](../unresolved/proofs.md)
