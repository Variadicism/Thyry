# Invariants Plan

This document records the current plan for adding invariants to the Beng type system.
It is a design note, not an implementation.

## Goal

`NativeBitsType` should be able to carry zero or more invariants. An invariant is a
compile-time checked assertion about the bits represented by a `NativeBitsValue` that
befits that type.

Example intent:

```text
it (uint) < 7
```

This means any `NativeBitsValue` that befits the relevant `NativeBitsType` must contain
bits whose unsigned integer interpretation is less than `7`.

The feature should also support invariants involving ordinary Beng operations:

```text
sin(it) < 7
```

That should be provable if the current context has rules that imply enough facts about
`sin(it)`, such as `-1 <= sin(it)` and `sin(it) <= 1` under appropriate premises.

## Design Principles

- All runtime data is still bits.
- The semantic interpretation of bits belongs to the comparator, not to a separate domain type.
- Invariants are expressed through simple comparisons such as equality and less-than.
- Ranges, intervals, and similar concepts should be represented as ordinary invariants.
- Greater-than can be represented by swapping operands of less-than.
- Less-than-or-equal can be a syntax convenience or explicit comparator, but it can be
  reduced to the disjunction of less-than and equality if needed.
- Initial type satisfaction requires equal bit sizes. Future source-level implicit widening
  should appear as an explicit conversion `Op` in the built expression.
- There is no separate `InvariantFunction`; ordinary Beng `Op`s are the operations used in
  invariant expressions.
- All `Op`s are expected to become proof-capable through complete type information and
  contextual invariant rules.
- Invariant rules live in `Context`, alongside available `Op`s.
- Proof uses `Context` plus a branch-local proof-step stack; no bundled `ProofState` is needed.
- Logic such as transitivity and reflexivity should be built-in invariant rules, not hidden
  ad-hoc proof logic in comparators.
- Code-declared invariant rules are trusted assumptions. An unproven declaration may be
  accepted, but a declaration that is disproven by the current context must be rejected.
- The invariant system should be centered on proof and disproof, not a separate general-purpose
  invariant evaluation API.
- Everything representable in Beng code should be a `Thing`. That includes invariants,
  invariant rules, invariant comparators, invariant expressions, and invariant variables.

## Existing Structures To Reuse

`NativeBitsValue` currently represents concrete bits:

```haskell
data NativeBitsValue = NativeBitsValue {
	bytes :: ByteString,
	size :: Int }
```

`NativeBitsType` currently represents only a bit size:

```haskell
data NativeBitsType = NativeBitsType { size :: Int }
```

The plan is to extend it with invariant data:

```haskell
data NativeBitsType = NativeBitsType {
	size :: Int,
	invariants :: [SomeInvariant] }
```

The list is allowed to be empty because a bits type may have no extra refinements.

`Context` currently controls which operators are available:

```haskell
data Context = Context {
	precedence :: [Set Int],
	ops :: [SomeOperator] }
```

The plan is to extend it with invariant rules:

```haskell
data Context = Context {
	precedence :: [Set Int],
	ops :: [SomeOperator],
	invariantRules :: [InvariantRule] }
```

This keeps scoping consistent. If an invariant rule is declared in a scope, it is available
only in contexts that include that declaration. The rule store is append-only: obviated rules
remain in the list for identity and provenance. A new rule's local ID is the number of historical
rules already in that context.

`Invocation` is the existing representation that may be reused or adapted for operation
applications inside invariants:

```haskell
data Invocation op = Invocation {
	operator :: op,
	context :: Context,
	location :: SomeLocation,
	match :: SomeMatch,
	returnType :: SomeConcreteThing }
```

`Invocation` already contains the `Op`, its matched arguments, its return type, its context,
and its source location. `Beng.Invocations.getArgs` can recover the named arguments from
the invocation's `match`. Direct reuse is still under review because ordinary invocation
arguments may need to be recursively concrete while invariant expressions may contain `It` or
rule variables.

## Core Types

### Invariant

Invariants should be represented by a typeclass. The proof engine owns proof flow, but each
invariant form exposes a structural view and normalization hook.

```haskell
data SomeInvariant =
	forall invariant. Invariant invariant =>
		SomeInvariant invariant

class Thing invariant => Invariant invariant where
	invariantView :: invariant -> InvariantView

	normalizeInvariant ::
		Context ->
		invariant ->
		FallibleI InvariantMismatch SomeInvariant
```

The proof engine should not put `prove` on this typeclass. Keeping proof centralized ensures
that comparison, `And`, `Or`, loop tracking, diagnostics, and resource limits are handled
consistently.

### Invariant Forms

Atomic comparison invariants compare two invariant expressions through a comparator.

```haskell
data ComparisonInvariant comparator = ComparisonInvariant {
	leftExpression :: SomeInvariantExpression,
	comparator :: comparator,
	rightExpression :: SomeInvariantExpression }

data SomeComparisonInvariant =
	forall comparator. InvariantComparator comparator =>
		SomeComparisonInvariant (ComparisonInvariant comparator)
```

Compound invariants represent logical conjunction and disjunction.

```haskell
data AndInvariant = AndInvariant {
	invariants :: Populace2 SomeInvariant }

data OrInvariant = OrInvariant {
	invariants :: Populace2 SomeInvariant }
```

`Populace2` is used because `And` and `Or` should always contain at least two invariants. This
avoids unnecessary wrappers such as `And (it < 7)` and meaningless cases such as `Or []`.

Core instances:

```haskell
instance InvariantComparator comparator => Invariant (ComparisonInvariant comparator)
instance Invariant AndInvariant
instance Invariant OrInvariant
```

Smart constructors should avoid unnecessary compound wrappers:

```text
[] -> internal proven/no-goals state, not a user-facing invariant
[x] -> x
[x, y, ...] -> AndInvariant or OrInvariant
```

Goal proof semantics:

```text
AndInvariant is proven if every child invariant is proven.
AndInvariant is disproven if any child invariant is disproven.
AndInvariant is unproven if no child is disproven and at least one child is unproven.

OrInvariant is proven if any child invariant is proven.
OrInvariant is disproven if every child invariant is disproven.
OrInvariant is unproven if no child is proven and at least one child is unproven.
```

These rules describe an `AndInvariant` or `OrInvariant` when it is the current goal. Compound
invariants used as known assumptions have different elimination behavior:

```text
A known AndInvariant makes every child available in the same proof branch.

To use a known OrInvariant to prove a goal, create one branch per child assumption and prove the
same goal in every branch. No child of a known OrInvariant is independently known.
```

If any `OrInvariant` assumption branch cannot prove the goal, the combined result is normally
unproven. Disproving the combined implication additionally requires evidence that a failing branch
can describe an actual candidate rather than an impossible branch.

### InvariantView

The proof engine needs a common structural view for invariant forms.

```haskell
data InvariantView =
	ComparisonInvariantView SomeComparisonInvariant |
	AndInvariantView (Populace2 SomeInvariant) |
	OrInvariantView (Populace2 SomeInvariant)
```

### InvariantRule

An invariant rule derives one or more conclusions when all premises are proven.

```haskell
type InvariantRuleId = Natural

data InvariantRule = InvariantRule {
	ruleId :: InvariantRuleId,
	justification :: InvariantRuleJustification,
	premises :: [SomeInvariant],
	conclusions :: Populace SomeInvariant,
	obviatedBy :: Maybe InvariantId }
```

`ruleId` is assigned by `pushInvariantRule`, not by callers. Its value is the length of the
append-only historical rule list before insertion. An obviated rule remains in the list with
`obviatedBy = Just invariantId`, so its ID and justification remain available even though rule
search can skip it quickly. Active rules have `obviatedBy = Nothing`.

Rule variables are derived from `premises` and `conclusions`, similar to the way arguments are
derived from patterns that contain them. This avoids duplicated variable declarations that could
fall out of sync with the rule body.

`premises` is a list because rules may have zero premises. Such a rule represents an
always-available fact or axiom.

`conclusions` is a `Populace` because a rule with no conclusions is useless.

Every derived conclusion used to obviate another rule is itself added to the context first. This
allows `obviatedBy` to identify one established invariant even when deriving it required several
proof steps.

Examples of zero-premise rules:

```text
x unsignedIntegerEquals x
```

Examples of rules with premises:

```text
x < z if x < y and y < z
```

### InvariantRuleJustification

The rule itself should not have a direct `location` field because not all rules are declared
directly in source code. Instead, metadata belongs to the justification.

```haskell
data InvariantRuleJustification =
	DeclaredInvariantRule { location :: SomeLocation } |
	DerivedInvariantRule { sources :: Populace InvariantId }
```

There is no separate `AssumedInvariant` case. A known fact is a declared rule with zero
premises.

Built-in facts and axioms can use `Builtin` locations. Code-declared invariant rules can use
code locations.

Code-declared rules are trusted contracts. Rule insertion distinguishes three outcomes:

```text
Proven conclusion: retain the new rule as obviated by the existing proof.
Unproven conclusion: retain the new rule as an active trusted assumption.
Disproven conclusion: reject the declaration at its source location.
```

Insertion should be tentative so a new rule can also be rejected when it causes an affected
existing assumption to become disproven. Diagnostics should identify the new declaration and the
existing rule or rules that establish the contradiction. The exact validation of conditional
rules remains an active review point below.

### InvariantId

Derived rules should identify the invariants they came from. The ID must be independent of
`Context.invariantRules` ordering.

```haskell
data InvariantId = InvariantId {
	ruleId :: InvariantRuleId,
	conclusionPath :: InvariantPath }

data InvariantPath = InvariantPath [Int]
```

`InvariantPath` identifies a conclusion within a rule, including nested children inside
`AndInvariant` or `OrInvariant` conclusions if needed. Locations are recovered from the rule's
`justification`; they are not duplicated in `InvariantId`.

A path into an `OrInvariant` identifies a child for provenance only. It never makes that child an
independently known fact.

### InvariantVariable

Rules need declared variables.

```haskell
data InvariantVariable = InvariantVariable {
	name :: String,
	variableType :: SomeParameterizedThing }
```

Every invariant variable has a type. Untyped variables would make rule validation and
invocation argument checking ambiguous.

The term here is best thought of as a rule variable or logic variable. In a backward proof,
a variable that appears only in premises behaves like a witness variable.

Example:

```text
x < z if x < y and y < z
```

When proving `a < c`, `x` and `z` are bound by the conclusion. `y` is then discovered while
proving the premises, for example by finding known facts `a < b` and `b < c`.

### InvariantComparator

Comparators own the semantic interpretation of bits.

```haskell
data SomeInvariantComparator =
	forall comparator. InvariantComparator comparator =>
		SomeInvariantComparator comparator
```

The current provisional class signature is:

```haskell
class Thing comparator => InvariantComparator comparator where
		decideComparison ::
			Context ->
			ComparisonInvariant comparator ->
			FallibleI SomeProofFailure SomeInvariantProof

		applyComparison ::
			Context ->
			SomeComparisonInvariant ->
			ComparisonInvariant comparator ->
			FallibleI SomeComparisonApplicationFailure (Populace SomeInvariant)
```

```haskell
data SomeComparisonApplicationFailure =
	forall failure. ComparisonApplicationFailure failure =>
		SomeComparisonApplicationFailure failure

data SomeComparisonIrrelevance =
	forall irrelevance. ComparisonIrrelevance irrelevance =>
		SomeComparisonIrrelevance irrelevance

class (Show failure, Messagable failure) => ComparisonApplicationFailure failure where
	applicationCandidate :: failure -> SomeComparisonInvariant
	applicationTarget :: failure -> SomeComparisonInvariant

class ComparisonApplicationFailure irrelevance => ComparisonIrrelevance irrelevance

class
	(ComparisonApplicationFailure disproof, InvariantDisproof disproof) =>
	ComparisonApplicationDisproof disproof
```

`decideComparison` performs the basic comparison logic represented by the comparator. It uses
`InvariantExpressionView` so comparator implementations can be straightforward pattern matches.
It should only decide direct cases, such as two known bit literals or a comparator-specific
identity.

The comparator value is read from the typed `ComparisonInvariant comparator`, so the method does
not need a separate comparator argument.

`decideComparison` returns a proof on success and a proof failure on failure. The failure may be
unproven or disproven. The solver can continue after an unproven result, but can stop the branch
after a disproof. Invalid operands should return an appropriate proof failure; there is no separate
operand-validation method.

`applyComparison` asks whether a known comparison invariant or rule conclusion can help prove or
disprove a selected comparison goal. The `SomeComparisonInvariant` argument is the known fact or
rule conclusion, and the typed `ComparisonInvariant comparator` is the goal being transformed.
On success, it returns replacement goals. On failure, it returns either a disproof or an
irrelevance result. Irrelevance means the known fact is valid but not useful for that goal.

The bare replacement-goal return type does not yet record whether proving or disproving those
goals determines the selected goal. The active proposal wraps the replacement goals in a
`ComparisonApplication` whose relation records that implication direction.

`applyComparison` should also use `InvariantExpressionView`. For example, unsigned less-than can
inspect both sides of a known comparison and a goal comparison to decide whether the known
comparison is an upper bound, lower bound, contradiction, or irrelevant.

Comparator application owns relation-specific reasoning such as bounds, direction, equality,
and contradiction for that comparator. It should not hardcode semantics for specific `Op`s such
as `sin`; those should be represented by invariant rules involving those `Op`s.

`compareNativeBits` can exist as a private helper inside comparator implementations, but
it does not need to be a typeclass method. It is just one way for `decideComparison` to decide
`NativeBitsValueView` versus `NativeBitsValueView`.

Comparator families may include:

```haskell
data BitPatternEquals = BitPatternEquals
data BitPatternNotEquals = BitPatternNotEquals
data UnsignedIntegerEquals = UnsignedIntegerEquals { size :: Int }
data UnsignedIntegerNotEquals = UnsignedIntegerNotEquals { size :: Int }
data SignedIntegerEquals = SignedIntegerEquals { size :: Int }
data SignedIntegerNotEquals = SignedIntegerNotEquals { size :: Int }
data Float32Equals = Float32Equals
data Float32NotEquals = Float32NotEquals
data Float64Equals = Float64Equals
data Float64NotEquals = Float64NotEquals
data UnsignedIntegerLessThan = UnsignedIntegerLessThan { size :: Int }
data SignedIntegerLessThan = SignedIntegerLessThan { size :: Int }
data Float32LessThan = Float32LessThan
data Float64LessThan = Float64LessThan
```

Initial integer comparisons require operands with equal bit sizes. Comparators should reject
mixed-size operands rather than silently extending them.

Future source-level implicit widening should be represented in the built invariant expression by
an explicit conversion `Op`. Unsigned conversion operations can zero-extend, while signed
conversion operations can sign-extend. Their invariant rules, rather than the receiving
comparator, establish how the conversion affects numerical properties.

Float equality is not bitwise equality. In particular:

```text
-0.0 == 0.0
NaN != NaN
```

Raw bit equality may still exist as `BitPatternEquals`, but it should not be the default
meaning of equality.

Not-equals comparators should be explicit comparator families. Less-than can express
greater-than by swapping operands, and not-equals covers the major missing comparison category.
No generic negation type or comparator-negation method is currently planned.

### InvariantExpression

Invariant expressions should be represented by a typeclass.

```haskell
data SomeInvariantExpression =
	forall expression. InvariantExpression expression =>
		SomeInvariantExpression expression
```

```haskell
class Thing expression => InvariantExpression expression where
	invariantExpressionView :: expression -> InvariantExpressionView

	invariantType ::
		Context ->
		expression ->
		FallibleI InvariantMismatch SomeParameterizedThing
```

Likely instances if ordinary invocations can safely represent symbolic expressions:

```haskell
instance InvariantExpression It
instance InvariantExpression NativeBitsValue
instance InvariantExpression SomeInvocation
```

`NativeBitsValue` is a literal expression.

Under that design, `SomeInvocation` represents expressions such as `sin(it)` or `length(list)`.
A separate `InvariantInvocation` is the active alternative.

`It` represents the value being constrained by the enclosing `NativeBitsType`.

### InvariantThing

`It` and rule variables are placeholder values. They should be legal inside invariants, but
not legal as final concrete runtime values.

This is similar to the existing role of `Parameter`.

```haskell
data SomeInvariantThing =
	forall thing. InvariantThing thing =>
		SomeInvariantThing thing
```

```haskell
class InvariantExpression thing => InvariantThing thing
```

`Thing` may need a method similar to `asParameter`:

```haskell
asInvariantThing :: thing -> Maybe SomeInvariantThing
asInvariantThing _ = Nothing
```

Then `It` can be:

```haskell
data It = It {
	variableType :: SomeParameterizedThing }

instance Thing It
instance ParameterizedThing It
instance InvariantExpression It
instance InvariantThing It
```

`variableType` must describe the unrefined underlying value. It must not recursively contain the
same `NativeBitsType` invariants that contain this `It`.

But `It` should not be:

```haskell
instance ConcreteThing It
```

Rule variables follow the same pattern:

```haskell
instance Thing InvariantVariable
instance ParameterizedThing InvariantVariable
instance InvariantExpression InvariantVariable
instance InvariantThing InvariantVariable
```

This allows symbolic placeholders to be carried through invariant expressions without allowing
them to escape into ordinary runtime evaluation. Whether symbolic operation applications can use
ordinary `Invocation` values remains an active review point below.

### Representation As Things

Anything representable in Beng code should be a `Thing`. `It` and `InvariantVariable` must not be
`ConcreteThing`s because they are symbolic placeholders, not runtime values. The required
instances and other mechanical integration details are listed in the implementation appendix so
they do not obscure the proof design.

### InvariantExpressionView

The proof engine also needs a common structural view for invariant expressions. This lets both
the proof engine and comparators use straightforward pattern matching instead of ad-hoc casts.

```haskell
data InvariantExpressionView =
	ItExpressionView It |
	VariableExpressionView InvariantVariable |
	NativeBitsValueExpressionView NativeBitsValue |
	InvocationExpressionView SomeInvocation
```

Expression instances expose this view through `invariantExpressionView`.

The proof engine uses `InvariantExpressionView` for structural matching and invariant
transformations. Comparators use `InvariantExpressionView` for direct comparison decisions and
comparison application.

### ProofStep

Proof should pass `Context` and the active proof-step stack separately. The context is the
knowledge base; the active stack is branch-local recursion and diagnostic state.

```haskell
data SomeProofStep =
	forall proofStep. ProofStep proofStep =>
		SomeProofStep proofStep

class (Show proofStep, Messagable proofStep) => ProofStep proofStep where
	proofStepInvariant :: proofStep -> SomeInvariant
```

The active proof stack prevents infinite recursion. It can contain steps whose result is an
atomic comparison invariant or a compound `AndInvariant`/`OrInvariant`. This gives the same
loop-avoidance shape as `TypeTest`: if a normalized invariant is already being proven, the
current derivation branch is cyclic and therefore unproven. Other non-cyclic derivations for the
same goal should still be attempted.

Concrete proof-step types should represent root goals, normalization, rule application,
comparison application, and direct decisions. Their `Show` and `Messagable` instances provide
diagnostic text. When proof fails, the solver can show the active stack to explain the strongest
attempt.

Proof steps do not bind `It`. Concrete value checks rewrite invariants before proof, replacing
`It` with the concrete `NativeBitsValue` literal. Type-level checks keep `It` symbolic and prove
facts about it through candidate invariants and context rules.

`It` receives its unrefined type when its enclosing `NativeBitsType` invariant is constructed or
validated, rather than from proof state. Whether it also needs a subject identity remains an
active review point; the current proposal avoids one by allowing exactly one `It` subject per
proof.

### Closed Expression Reduction

The type system needs to prove or disprove invariants, not expose a general invariant evaluation
API. Closed expression reduction is still useful inside proof/disproof. For example, an
invocation whose arguments are all concrete may be reduced through the existing `runWith` path,
then compared by the relevant comparator.

### Normalization

Normalization is deterministic, built-in, semantics-preserving canonicalization. It should be
applied immediately after any proof step changes an invariant, so each later step works with the
simplest known form.

Example:

```text
x - 1 + 7*8 < 2*x + it
=> x + 55 < 2*x + it
=> 55 < x + it
=> -x + 55 < it
```

Normalization may include combining like terms, sorting terms into a canonical order, folding
constants, normalizing `>` into swapped `<`, and isolating `It` when that is sound and possible.

Normalization should be tightly controlled and not user-definable initially, because normalizers
run constantly, affect every proof, and can easily create loops or unsound simplifications.
Users can still declare ordinary invariant rules for domain-specific facts.

To keep normalization sound and useful:

```text
1. Normalize goals and rule conclusions before matching.
2. Retain the original invariant for diagnostics and possible fallback.
3. Only normalize within theories where the transformation is valid.
4. Avoid fixed-width arithmetic normalization unless overflow and underflow are handled.
5. Avoid aggressive float normalization initially.
6. Require each normalizer to reduce a complexity measure.
7. Make normalization idempotent: normalizing twice should equal normalizing once.
8. Treat assumption-dependent changes as applications, not normalization.
```

### Application And Rewriting

Application transforms one proof goal into replacement goals using a known fact or rule
conclusion. It should not be modeled as a public `Map InvariantVariable
SomeInvariantExpression`: variables are not the only possible targets. An application can target
a whole invariant or a larger subexpression.

Whole-goal application:

```text
current goals: G and Rest
rule: C if P1 and P2
C matches G
new goals: P1 and P2 and Rest
```

Subexpression application:

```text
current goals: G[oldExpression] and Rest
rule conclusion: oldExpression = newExpression
new goals: G[newExpression] and Rest
```

If the rule has premises, those premises are added as goals too:

```text
current goals: G[oldExpression] and Rest
rule: oldExpression = newExpression if P1 and P2
new goals: P1 and P2 and G[newExpression] and Rest
```

Example:

```text
known: y = 0
goal: x + y < 7
rewrite: x + y -> x
new goal: x < 7
```

Concrete `It` checks are also rewrites:

```text
known from value check: it = 8
goal: it < 7
rewrite: it -> 8
new goal: 8 < 7
```

The rewritten invariant is proven or disproven by the normal proof process. In the example
above, `8 < 7` is directly disproven by the unsigned integer less-than comparator.

Rewrites must be justified. Equality does not always permit arbitrary replacement in every
context because different comparators can have different semantics. For example, float equality
and bit-pattern equality treat `+0.0` and `-0.0` differently. A rewrite rule must therefore be
valid for the target expression and comparator context.

Comparator-specific application lives in `InvariantComparator.applyComparison`, which returns
`FallibleI SomeComparisonApplicationFailure (Populace SomeInvariant)`. Expression and
operator-specific application uses ordinary invariant rules whose expressions mention the
relevant `Op`s.

That return signature remains provisional pending the comparison-application direction review
point below.

This application and rewriting system still needs a more precise design before implementation.

### Proof Result

Proof results should be represented by typeclasses so signatures can state exactly which kinds
of results they allow.

```haskell
data SomeInvariantProof =
	forall proof. InvariantProof proof =>
		SomeInvariantProof proof

data SomeProofFailure =
	forall failure. ProofFailure failure =>
		SomeProofFailure failure

data SomeInvariantDisproof =
	forall disproof. InvariantDisproof disproof =>
		SomeInvariantDisproof disproof

class (Show result, Messagable result) => InvariantProofResult result where
	proofResultInvariant :: result -> SomeInvariant
	proofSteps :: result -> [SomeProofStep]

class InvariantProofResult result => InvariantProof result
class InvariantProofResult result => ProofFailure result
class ProofFailure result => InvariantDisproof result
class ProofFailure result => InvariantUnproven result
```

Concrete result types can represent proven, disproven, unproven, and resource-exhausted cases.
For type checking, unproven is usually still a mismatch because the checker could not prove that
the candidate satisfies the requirement.

`InvariantDisproof` should be used only when the system can establish falsehood, such as a direct
comparator result returning false for known bit values.

## How Type Satisfaction Should Use Invariants

### NativeBitsValue Satisfies NativeBitsType

Given a concrete value and a required bits type:

```text
candidate: NativeBitsValue
requirement: NativeBitsType
```

The flow should be:

```text
1. Require the value's bit size to equal the required type size.
2. Rewrite each requirement invariant by replacing `It` with the candidate `NativeBitsValue`.
3. Try to prove or disprove each rewritten invariant.
4. If every invariant is proven, the value satisfies the type.
5. If any invariant is disproven, the value does not satisfy the type.
6. If any invariant is unproven, report an invariant mismatch.
```

Example disproof:

```text
requirement invariant: it (uint8) < 7
candidate bits: 0x08
```

The checker rewrites `it < 7` to `0x08 < 7`. The comparator interprets `0x08` as unsigned
integer `8`. `8 < 7` is directly disproven, so the value does not satisfy the type.

No widening occurs as part of this satisfaction check. A future source-level implicit conversion
must be present as an explicit conversion invocation before the converted value is tested against
the wider type.

### NativeBitsType Satisfies NativeBitsType

Given a candidate type and a required type:

```text
candidate: NativeBitsType
requirement: NativeBitsType
```

The flow should be:

```text
1. Require the candidate and requirement bit sizes to be equal.
2. Add the candidate type's invariants as zero-premise rules to a local proof context.
3. For each requirement invariant, try to prove it from the local context.
4. If every requirement invariant is proven, the candidate type satisfies the required type.
5. If any requirement invariant is unproven, report an invariant mismatch.
```

Candidate invariants are not globally added to the original context. They are temporary known
facts about `It` during this satisfaction check.

When a candidate invariant is an `OrInvariant`, it is retained as one disjunctive fact. To prove a
requirement from it, the solver must prove that requirement separately under every child
assumption. It must not add the children as independent zero-premise facts.

## Proof Flow

Proving an invariant should be rule-driven. The core solver operations are:

```text
normalize: canonicalize invariants after each change
decide: ask the comparator whether a normalized invariant is directly proven or disproven
apply: use a known fact or rule conclusion to replace one goal with new goals
```

A proof branch can be modeled as one `SomeInvariant`. When there are multiple simultaneous goals,
that invariant should usually be an `AndInvariant`.

```text
AndInvariant = goal1 and goal2 and goal3 ...
```

In simple terms:

```text
1. Normalize the current invariant.
2. Mark this derivation branch unproven if the normalized invariant already appears in the active
   proof stack, then continue trying other derivations.
3. If the invariant is an `AndInvariant`, prove every child.
4. If an `OrInvariant` is the goal, prove at least one child.
5. If the invariant is a `ComparisonInvariant`, ask its comparator for a direct proof.
6. If the comparator proves or disproves the comparison directly, stop that branch.
7. If the comparator returns an unproven failure, search for applicable rules or known facts.
8. Apply a useful rule conclusion or known fact to the selected comparison.
9. Replace the selected comparison with the application's new invariants.
10. Normalize the result.
11. Continue until the invariant is proven, disproven, or no progress is possible.
```

Direct comparator proofs/disproofs are not the same as general proof logic. They are base cases
for the comparator's own semantics, such as comparing two known bit literals.

Rules such as reflexivity and transitivity should be ordinary built-in rules in the context.

## Rule Applicability And Application

Rule selection and application belong in the proof engine.

The proof engine searches available facts and rules. Comparators decide whether comparison facts
are useful through `applyComparison`. Expressions and `Op`-specific behavior are handled by
ordinary invariant rules and structural matching through `InvariantView` and
`InvariantExpressionView`.

For comparison facts, the proof engine should ask the selected goal's comparator to apply a
known fact or rule conclusion to that goal. The comparator can then decide whether the known fact
is an upper bound, lower bound, contradiction, equality rewrite, or irrelevant fact for that
goal.

Matching or transforming two comparison invariants roughly means:

```text
1. Their comparators must match or normalize to compatible comparators.
2. Their left expressions must match or transform compatibly.
3. Their right expressions must match or transform compatibly.
4. Any inferred rewrites must be consistent within the current proof branch.
```

Compound goals are handled by their goal proof semantics rather than by comparator application:

```text
AndInvariant expands into all child goals.
OrInvariant branches across child goals until one proves or all disprove.
```

Compound known facts use assumption elimination instead:

```text
A known AndInvariant exposes every child in the same branch.
A known OrInvariant creates one assumption branch per child, and the selected goal must prove in
every branch.
```

Matching or transforming expressions roughly means:

```text
1. A rule variable may match another expression if its type permits it.
2. A previously matched rule variable must transform consistently.
3. It matches only It. Concrete value checks replace It with a literal before proof.
4. NativeBitsValue literals match structurally or through comparator-specific direct decisions.
5. Invocations match if their operators match and their corresponding arguments match.
6. Declared rewrite facts, such as x + 0 = x, may transform larger expression trees.
```

For invocation matching, operator identity should use declaration location, mirroring existing
operator equality behavior. Invocation arguments can be read from `match` with
`Beng.Invocations.getArgs`.

When a rule conclusion covers the selected goal, the selected goal is not kept as an ordinary
goal. It is replaced by that rule's premises, plus any additional goals returned by the
application. The original goal should remain in derivation metadata for diagnostics.

When a rule conclusion rewrites only part of the selected goal, the selected goal is replaced by
the rewritten goal plus the rule's premises.

## Proof Example: Comparator Application

Known fact:

```text
x < 7
```

Goal:

```text
x < 8
```

The unsigned less-than comparator can apply the known fact to the goal because both facts use
the same lesser expression, `x`. The known fact gives an upper bound for `x`, and the goal asks
for a looser upper bound.

Application:

```text
current goal: x < 8
known fact: x < 7
new goal: 7 <= 8
```

Then `decideComparison` proves `7 <= 8` directly.

The same known fact does not help this goal:

```text
goal: x > 2
normalized goal: 2 < x
known fact: x < 7
```

The known fact gives an upper bound for `x`, but the normalized goal needs a lower bound for
`x`. `applyComparison` should return a `ComparisonIrrelevance` failure.

## Proof Example: Less-Than Transitivity

Context contains these zero-premise declared facts:

```text
a < b
b < c
```

Context also contains this built-in rule:

```text
variables: x, y, z
premises: x < y, y < z
conclusion: x < z
```

Goal:

```text
a < c
```

Proof flow:

```text
1. Select the goal a < c.
2. Apply the transitivity rule conclusion x < z to the goal.
3. The selected goal is replaced by the premises a < y and y < c.
4. The known fact a < b applies to a < y, binding y to b in this proof branch.
5. The remaining premise becomes b < c.
6. The known fact b < c proves the remaining premise.
7. All replacement goals are proven, so a < c is proven.
```

`y` is declared by the rule. During backward proof it acts like a witness variable because it
does not appear in the conclusion.

## Proof Example: Sin Bound

Assume a candidate `NativeBitsType` has these invariants:

```text
-2*pi <= it
it <= 2*pi
```

The local proof context gets zero-premise rules for those candidate facts.

Context contains a declared or built-in rule for `sin`:

```text
variables: x
premises: -2*pi <= x, x <= 2*pi
conclusions: -1 <= sin(x), sin(x) <= 1
```

Context also contains ordinary ordering rules such as transitivity.

Goal:

```text
sin(it) < 7
```

Proof flow:

```text
1. The proof engine searches rules that can help prove sin(it) < 7.
2. The sin-bound rule can produce sin(it) <= 1 after binding x = it.
3. Its premises become -2*pi <= it and it <= 2*pi.
4. Those premises are proven from the candidate type's local zero-premise facts.
5. The conclusion sin(it) <= 1 is now available for this proof branch.
6. A built-in ordering rule combines sin(it) <= 1 with the concrete fact 1 < 7.
7. Therefore sin(it) < 7 is proven.
```

The exact handling of `<=` is still open. It can be a convenience comparator or syntax lowered
into less-than plus equality.

## Disproof And Unknown Results

The system should distinguish disproven from unproven when it can do so.

Concrete disproof is straightforward:

```text
it (uint8) < 7
It = 8
8 < 7 is directly disproven by the unsigned integer less-than comparator
```

Type-level disproof is possible when known facts and the goal imply a direct falsehood.

Example:

```text
goal: Index < 7
known: 10 < Index
```

If both were true, transitivity would imply:

```text
10 < 7
```

The unsigned less-than comparator disproves `10 < 7`, so the original goal is disproven under
the known facts.

Another example:

```text
goal: Size <= 5
known: 7 <= Size
```

If both were true, transitivity would imply:

```text
7 <= 5
```

The comparator disproves `7 <= 5`, so `Size <= 5` is disproven under the known facts.

Type-level disproof is harder because the current plan does not include a model finder.

If the system cannot prove a requirement invariant from the candidate type's invariants and
the context rules, the result should usually be `Unproven`, not necessarily `Disproven`.

For type checking, both `Unproven` and `Disproven` are failures, but diagnostics can be more
precise when the system knows an invariant is false.

## Where The Logic Lives

The proof engine owns:

```text
normalization scheduling
rule search
rule variable freshening
unification
goal and premise transformation
recursive premise proof
loop detection through the active proof-step stack
```

`Invariant` owns:

```text
how to expose a structural InvariantView
how to normalize that invariant form
```

`InvariantComparator` owns:

```text
how two concrete NativeBitsValues are semantically compared
whether operand types and sizes are acceptable for that comparison
direct proof/disproof of comparator-specific base cases using InvariantExpressionView
relation-specific application of comparison facts to comparison goals
```

`InvariantExpression` owns:

```text
how to expose a structural InvariantExpressionView
how to infer its type
how to expose enough structure for matching, transformation, and direct comparator decisions
how to expose invocation and expression structure for rule application
```

`Context` owns:

```text
which Ops are available
which invariant rules are available
the append-only history and obviation status of its invariant rules
operator precedence for parsing
```

`NativeBitsType` owns:

```text
its bit size
the invariants that values of that type must satisfy
```

## Built-In Invariant Rules

Some logical rules should be built into the interpreter by adding them to the built-in context.

Examples:

```text
integer equality reflexivity
integer equality symmetry
integer equality transitivity
integer less-than transitivity
integer not-equals direct decisions
application of equal expressions inside compatible invariant expressions
algebraic applications such as x + 0 = x when the relevant zero premise is proven
```

Greater-than normalization by swapping less-than operands is more likely a built-in normalizer
than a context rule.

Float rules need care.

Unconditional float equality reflexivity is invalid because `NaN != NaN`.

Any float reflexivity rule must either exclude NaN through a premise or be avoided.

## Implementation Appendix

This appendix records Haskell integration and migration details that are required for an
implementation but are not part of the proof calculus itself.

### NativeBitsType Construction

Adding a field to `NativeBitsType` will affect many existing positional uses such as:

```haskell
NativeBitsType 32
NativeBitsType 1
```

Implementation should either update those uses or introduce construction helpers before making
the field change.

`NativeBitsType.satisfies` must replace the current narrower-than-or-equal size check with exact
size equality. Future widening belongs to explicit conversion invocations, not this instance.

### Thing Integration

Anything representable in Beng code should be a `Thing`. The invariant system should include
`Thing` instances for at least:

```haskell
instance Thing SomeInvariant
instance Thing ComparisonInvariant
instance Thing AndInvariant
instance Thing OrInvariant
instance Thing InvariantRule
instance Thing InvariantVariable
instance Thing SomeInvariantComparator
instance Thing SomeInvariantExpression
```

Concrete invariant, comparator, and expression types inherit this requirement through the
`Invariant`, `InvariantComparator`, and `InvariantExpression` class constraints. Each instance
must satisfy the existing `Eq`, `Show`, `Messagable`, `Typeable`, and `parameterize` requirements.
`It` and `InvariantVariable` must not be `ConcreteThing`s.

`NativeBitsType.resolve` must traverse its invariants once invariant expressions can contain
ordinary parameters. Invariant proof failures must also be represented by or converted into the
existing type-checking `Mismatch` result.

New modules and source-import cycles may require corresponding Cabal entries and `.hs-boot`
declarations. Those changes should be planned with the module layout rather than mixed into the
solver semantics.

### Context Integration

`Context.empty`, `Context.push`, and `Context.fromOps` will need to initialize or preserve the
append-only `invariantRules` list.

Invariant-context merging is not part of the initial implementation. The existing
`Context.concat` must not silently discard invariant rules if it is later used with an
invariant-bearing context; complete merge and ID-remapping behavior can be designed with imports.

There should be a separate function for adding invariant rules to a context, since `Context.push`
currently means pushing an operator and updating precedence.

```haskell
pushInvariantRule ::
	InvariantRuleJustification ->
	[SomeInvariant] ->
	Populace SomeInvariant ->
	Context ->
	FallibleI SomeInvariantDisproof (Context, InvariantRuleId)
```

`pushInvariantRule` assigns the historical rule count as the new `InvariantRuleId`. It never
deletes rules. When an existing proof already establishes the new conclusions, it stores the rule
with `obviatedBy = Just invariantId`. When the conclusions are unproven, it stores an active trusted
rule with `obviatedBy = Nothing`. When a conclusion is disproven, it rejects the declaration.

Insertion is tentative until the proof engine confirms that the new rule does not cause an
affected existing assumption to become disproven. The exact policy for conditional rules with
potentially conflicting conclusions is summarized in the active review points below.

### Symbolic Invocation Isolation

Symbolic invocations that contain `It` or rule variables must not be run as ordinary runtime
invocations. Whether ordinary match arguments should become `SomeConcreteThing` values and
symbolic applications should use a separate `InvariantInvocation` remains an active review point.

`Thing.asInvariantThing` can be used to reject invariant-only placeholders when ordinary code
expects concrete runtime values.

Composite `ConcreteThing` instances must preserve recursive concreteness so a symbolic value
cannot be hidden inside a concrete wrapper.

### Diagnostics

The proof engine should produce derivation data, even if diagnostics initially show only the
first failing goal. This will help explain why an invariant was accepted.

## Active Review Follow-Ups

These are the remaining numbered points from the design review. Settled review points have been
incorporated into the plan and removed from this list.

1. **Comparison-application direction**

   Overall discussion: an untagged replacement goal cannot say whether its proof or disproof
   determines the original goal.

   Latest question: is `ComparisonApplication` an input or output of `applyComparison`, how would
   `applyComparison` choose its relation, and how does it relate to the current replacement goals?

   Latest response: it would be the output wrapper around the current replacement goals. Each
   comparator case would select `ReplacementImpliesGoal`, `GoalImpliesReplacement`, or
   `ReplacementEquivalentToGoal` according to the sound implication used by that case.

2. **Conditional-rule consistency**

   Overall discussion: trusted rules may assume unproven conclusions, but must not assume a
   conclusion that the current context disproves.

   Latest question: if the context says `halts(Machine) = no`, should a conditional rule that can
   conclude `halts(Machine) = yes` be rejected regardless of whether its premises currently hold?

   Latest response: exact logic permits both rules when the condition is false, but the proposed
   conservative validator can assume the new rule's premises during validation. If that makes its
   conclusion conflict, reject it; if the premises are already disproven, reject the rule as
   unreachable. This avoids needing an exact satisfiability decision.

3. **Typed single-subject `It`**

   Overall discussion: `It` needs an unrefined type, while foreign `It` pollution can be avoided by
   restricting every proof to one constrained subject.

   Latest question: if general rules use variables, `It` occurs only in type invariants, candidate
   and requirement invariants share one subject, and concrete replacement targets only that
   subject, is a separate subject identity still necessary?

   Latest response: no identity is required initially if those restrictions are enforced. `It`
   can match only `It` in a proof environment containing exactly one subject, but it still needs
   an unrefined type for comparator and invocation validation.

4. **Concrete and symbolic invocations**

   Overall discussion: ordinary invocations should be recursively concrete, while invariant
   invocations may contain `It` or rule variables and must not run until closed.

   Latest question: would changing `Argument.value` from `SomeThing` to `SomeConcreteThing` close
   the execution hole?

   Latest response: it closes the direct hole if composite `ConcreteThing` instances also enforce
   recursive concreteness. It also means symbolic applications such as `sin(it)` need a separate
   `InvariantInvocation` or parameterized concrete/symbolic invocation types.

5. **Fresh rule variables and shared bindings**

   Overall discussion: every use of a rule needs independent temporary variables, and a witness
   discovered in one premise must update all remaining premises in that branch.

   Latest question: what do variable freshening and conclusion unification mean in simpler terms?

   Latest response: unification matches a rule conclusion such as `x < z` to a goal such as
   `a < c`, producing `x := a` and `z := c`. Freshening gives each rule use distinct temporary
   variables so a later `y := b` binding affects only that application. The proof engine needs a
   branch-local binding table and a fresh application ID.

## Other Open Questions

- What exact syntax declares invariants on `NativeBitsType`?
- What exact syntax declares general invariant rules in code?
- How is `It` written and scoped in source?
- Should `<=` be primitive, syntax convenience, or an `OrInvariant` containing `<` and `=`?
- Should derived invariants be memoized as temporary zero-premise rules during proof?
- How much contradiction detection is needed for uninhabited types?
- Should type checking distinguish `Unproven` from `Disproven` in user-facing errors?
- Should float comparisons initially support NaN and signed zero precisely, or be staged later?
- How should applying equal expressions inside arbitrary invocation expressions be constrained?
- How should proof search be bounded to avoid excessive branching?
- What strategy should choose which rules or known facts to apply first?
- How should the solver rank direct whole-goal applications versus subexpression applications?
- Should invariant rules respect context stack order for diagnostics, performance, or both?
- How should application validity account for comparator semantics such as float equality versus
  bit-pattern equality?

## Likely Implementation Phases

1. Add invariant type definitions without integrating them into type checking.
2. Add `Thing` instances for invariant structures that are representable in code.
3. Add the append-only `Context.invariantRules`, obviation tracking, and `pushInvariantRule`.
4. Add `InvariantExpression`, `InvariantThing`, `It`, and structural views.
5. Resolve the active review follow-ups and define the application and rewriting algorithm.
6. Add comparator types for integer equality and integer less-than.
7. Add a basic proof engine with normalization, rule search, matching, application, and
   active-proof-step loop detection.
8. Add built-in invariant rules for basic integer equality and less-than, including compound
   assumption behavior.
9. Add `NativeBitsType.invariants` and update existing construction sites.
10. Integrate invariant proof and exact-size checks into `NativeBitsType` satisfaction.
11. Add direct proof/disproof support for concrete `NativeBitsValue` satisfaction.
12. Add parser/build support for declaring invariants and invariant rules in Beng code.
