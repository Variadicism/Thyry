# Invariants Plan

This document records the current plan for adding invariants to the Beng type system. It is a
design note, not an implementation or a final source-language specification.

The invariant language now has an intended logical vocabulary and a high-level solver cycle. The
exact Haskell representation, generalized application calculus, and several validation and search
algorithms remain open design work.

## Goal

`NativeBitsType` should be able to describe zero or more compile-time checked assertions about the
bits represented by a `NativeBitsValue` that befits that type.

Example intent:

```text
it (uint <) 7
```

This means any `NativeBitsValue` that befits the relevant `NativeBitsType` must contain bits whose
unsigned integer interpretation is less than `7`.

Invariants may also mention ordinary Beng operations:

```text
sin(it) (float64 <) 7
```

Such an assertion may be provable when the context contains established laws that provide a
sufficient bound for `sin(it)`. The invocation is a symbolic expression in the proposition; the
proposition itself is not an executable operation.

## Design Principles And Boundaries

- All runtime data is still bits.
- The semantic interpretation of bits belongs to the comparator, not to a separate runtime domain
  type.
- An invariant is a logical proposition. Invariant expressions may contain ordinary Beng `Op`s,
  but logical propositions are not themselves executable operations.
- The compiler owns the meaning and fundamental laws of `and`, `or`, `not`, `if`, `for all`, and
  `for some`. Users may state domain-specific facts and assumptions, but may not redefine logic.
- Every ordinary logical form needed by invariant reasoning should also be expressible in source.
  Compiler-internal proposition-pattern metavariables are the exception.
- Ranges and intervals are ordinary combinations of comparison invariants and logical forms.
- Initial type satisfaction requires equal bit sizes. Future implicit source conversions must
  appear as explicit conversion `Op`s in the constructed expression.
- There is no separate `InvariantFunction`. Ordinary Beng `Op`s are used in invariant expressions.
- Contextual knowledge lives in `Context`, alongside the available `Op`s.
- Proof uses `Context` plus branch-local bindings, history, and loop/resource tracking.
- Type/value satisfaction distinguishes `Proven`, `Disproven`, and `Unproven`. Failure to prove a
  required invariant is a type mismatch, but is not automatically a disproof.
- Code may explicitly introduce an unproven assertion only with conspicuous `assuming` syntax.
- No intentionally uninhabitable or never-type facility is being designed here. A type proven to
  have no possible values is an error.
- Anything representable in Beng code should generally be a `Thing`. Internal solver patterns and
  proof machinery need not be source-representable.
- The architecture should be mathematically sound and extensible. This plan does not attempt to
  enumerate every theorem-proving strategy or native decision case before implementation.

## Existing Structures To Reuse

`NativeBitsValue` represents concrete bits:

```haskell
data NativeBitsValue = NativeBitsValue {
	bytes :: ByteString,
	size :: Int }
```

`NativeBitsType` currently represents a bit size:

```haskell
data NativeBitsType = NativeBitsType { size :: Int }
```

Its invariant representation should follow the existing subject-accepting property design of
`NativeType`, rather than storing already-instantiated propositions:

```haskell
data NativeType = NativeType { properties :: SomeThing -> [SomeOperator] }
data One = One
```

The conceptual extension is therefore similar to:

```haskell
data NativeBitsType = NativeBitsType {
	size :: Int,
	invariants :: SomeInvariantExpression -> [SomeInvariant] }
```

This is illustrative, not a settled signature. In particular, the final types must enforce the
difference between general invariant templates and solver-ready invariants described below. A list
of type invariants denotes their conjunction. An empty list means no additional refinement.

As with `NativeType.properties`, display and structural equality can instantiate the function with
a designated placeholder. Solver use instead instantiates it with an actual subject expression.

`Context` currently controls available operators:

```haskell
data Context = Context {
	precedence :: [Set Int],
	ops :: [SomeOperator] }
```

It should be extended with invariant rules:

```haskell
data Context = Context {
	precedence :: [Set Int],
	ops :: [SomeOperator],
	invariantRules :: [InvariantRule] }
```

The rule store remains append-only for stable identity and provenance. Obviated rules stay in the
historical list and can be skipped during search. A new rule's local ID is the number of historical
rules already in that context.

The existing `Invocation` representation may inform symbolic invocation design:

```haskell
data Invocation op = Invocation {
	operator :: op,
	context :: Context,
	location :: SomeLocation,
	match :: SomeMatch,
	returnType :: SomeConcreteThing }
```

`Beng.Invocations.getArgs` can recover named arguments from an invocation's `match`. Direct reuse
is not decided: runtime invocations should be recursively concrete, while symbolic invariant
invocations may contain quantified variables and must not execute merely because they are present
in a proposition.

## Core Model

### General And Solver-Ready Categories

The representation must enforce a recursive distinction analogous to `Thing` and its specialized
subsets:

- **General invariants** may contain the display/template placeholder `It` and support ordinary
  structural operations such as showing, equality, and inspection.
- **Solver-ready invariants** contain no unresolved `It` anywhere, including inside nested logical
  forms, comparison operands, or symbolic invocations.
- Solver-ready does not mean decidable and does not mean runtime-executable. Quantified variables
  and symbolic operation applications remain valid solver expressions.

Logical forms and atomic expressions should be parameterized, directly or indirectly, by this
category so readiness propagates recursively. Existential wrappers can preserve heterogeneous
children. An unchecked marker instance on a compound value is insufficient because a nested child
could still contain `It`.

The exact Haskell encoding is open. The sketches below omit category parameters when they would
obscure the semantic point.

### Invariant Forms

The invariant model contains:

```text
ComparisonInvariant
AndInvariant
OrInvariant
NotInvariant
IfInvariant
ForAllInvariant
ForSomeInvariant
```

These forms can nest arbitrarily. Source terminology is `for all` and `for some`. Rules and type
invariants use this same proposition language; there is no narrower rule-only language.

Illustrative shapes are:

```haskell
data ComparisonInvariant comparator = ComparisonInvariant {
	leftExpression :: SomeInvariantExpression,
	comparator :: comparator,
	rightExpression :: SomeInvariantExpression }

data AndInvariant = AndInvariant {
	invariants :: Populace2 SomeInvariant }

data OrInvariant = OrInvariant {
	invariants :: Populace2 SomeInvariant }

data NotInvariant = NotInvariant {
	invariant :: SomeInvariant }

data IfInvariant = IfInvariant {
	antecedent :: SomeInvariant,
	consequent :: SomeInvariant }

data ForAllInvariant = ForAllInvariant {
	variable :: InvariantVariable,
	invariant :: SomeInvariant }

data ForSomeInvariant = ForSomeInvariant {
	variable :: InvariantVariable,
	invariant :: SomeInvariant }
```

These declarations are not final APIs. Quantifier representation in particular must preserve
scope, variable identity, order, and capture-avoiding substitution.

`AndInvariant` and `OrInvariant` should contain at least two children. Construction should avoid
unnecessary one-child wrappers. An empty conjunction or disjunction is an internal construction
case, not a user-facing invariant.

Do not add user-expressible `TrueInvariant` or `FalseInvariant` constructors. A simplification or
proof step may decide a proposition as true or false, but its enclosing logical form consumes that
decision before reconstructing any remaining invariant. For example:

```text
A and true  -> A
A and false -> whole conjunction disproven
A or true   -> whole disjunction proven
A or false  -> A
```

Justification for the eliminated child is retained for diagnostics without creating a displayed
`true` or `false` proof node.

### Logical Conveniences

General negation removes the need for several primitive comparison families:

```text
a > b  := b < a
a != b := not (a = b)
a <= b := a < b or a = b
a >= b := b < a or a = b
```

These are source conveniences or lowerings, not separate primitive comparators. The equality and
ordering interpretation in each expansion must be the selected native interpretation.

Do not universally lower `not (a < b)` to `a >= b`. They differ for IEEE NaN. Under IEEE
semantics, both `a < b` and `a >= b` can be false.

### Structural Views

The solver needs structural views for invariants and invariant expressions so it can inspect
existential wrappers without ad-hoc casts. An expanded `InvariantView` must cover all seven forms,
and an expression view must cover literals, variables, and symbolic invocations.

The exact view types depend on the general/solver-ready category design and are not settled. Any
design must prevent a structural view from bypassing the recursive no-`It` guarantee at solver
entry.

### Invariant Comparators

Comparators own the semantic interpretation of bits. Native comparator families initially include:

```text
Bit-pattern equality, parameterized by width
Unsigned integer less-than, parameterized by width
Signed integer less-than, parameterized by width
IEEE float32 equality and less-than
IEEE float64 equality and less-than
```

Separate unsigned and signed integer equality is unnecessary for equal-width bit patterns.
Primitive greater-than, not-equals, less-than-or-equal, and greater-than-or-equal comparators are
also unnecessary because the logical forms above express them.

Illustrative source syntax treats interpretation and relation as one parenthesized comparator:

```text
a (uint <) b
a (int <) b
a (float32 <) b
a (float64 <) b
a (bits =) b
```

The parenthesized unit may consist of multiple lexer tokens. It is a logical comparator object,
not a cast applied only to the left operand. It interprets both operands and validates their widths.

Integer comparisons initially require equal-width operands. Comparators reject mixed widths rather
than extending silently. Future widening uses explicit conversion operations, whose established
properties explain zero extension, sign extension, or another conversion behavior.

IEEE numerical equality is not bit-pattern equality:

```text
-0.0 (float64 =) 0.0
not (NaN (float64 =) NaN)
```

Raw equality remains available as `(bits =)`. Float less-than is false when an operand is NaN.
Float rules must not assume reflexivity of IEEE numerical equality.

An `InvariantComparator` supplies at least two kinds of knowledge:

- context-independent direct decisions about atomic comparisons when possible; and
- comparison-specific candidate applications that relate a known comparison to a goal.

The older `decideComparison` and `applyComparison` names remain useful, but their exact signatures
are not settled. `decideComparison` must not consult contextual rules. `applyComparison` must expose
the application's obligations, bindings, justification, and implication direction rather than
returning untagged replacement goals.

Comparator implementations may use private helpers to compare concrete `NativeBitsValue`s. Native
decision support can grow incrementally and need not claim completeness.

### Invariant Expressions, Variables, And Symbolic Invocations

Invariant expressions include concrete bit literals, explicitly scoped quantified variables, and
symbolic operation applications. The exact class and existential wrappers remain open.

Every quantified value variable has a type:

```haskell
data InvariantVariable = InvariantVariable {
	name :: String,
	variableType :: SomeParameterizedThing }
```

This is a conceptual shape. Implementations also need identities that distinguish shadowed or
freshened variables independently of display names.

Symbolic applications such as `sin(x)` are propositions about operation results. They must preserve
operator identity, bindings, argument structure, and result type, but must not run until they are
closed and execution is explicitly requested by an appropriate path. Runtime `Invocation` may be
reused, parameterized, or separated into a symbolic representation; preserving this boundary is
the requirement.

The same pure invocation with the same operator identity, bindings, and arguments denotes the same
value. Unrelated invocations are not assumed unequal, but equality between them requires proof. A
bare operator declaration and an invocation with bound arguments are different expressions.

Operator identity should use declaration identity/location consistently with existing operator
equality behavior.

### `one` And `it`

Keep the source-level roles distinct:

- `one` is the subject used for `NativeType` property declarations and definitions.
- `it` is the placeholder used when writing or displaying invariants attached to a type.

`It` is not an existential witness or a logic variable for the solver to bind. It is removed when
the type's invariant template is instantiated. The solver accepts only recursively `It`-free
invariants.

For display and structural equality, instantiate the template with a designated `It`. For proof,
instantiate it with the actual subject expression. To validate a standalone type declaration,
instantiate it with a fresh, unconstrained symbolic expression of the unrefined underlying type.
Do not pass the type object as though it were a runtime value, and do not assume the type's own
refinements while validating those refinements.

Existing code establishes that `One` is a `Thing`, `ConcreteThing`, and `ParameterizedThing`.
Whether a similarly represented `It` should be a `ConcreteThing` depends on the chosen category
encoding. The architectural requirement is recursive removal before solver entry, not a particular
subclass declaration.

## Rules Are Invariants With Metadata

An invariant rule is an arbitrary invariant assertion plus metadata. It does not have separate
`premises` and `conclusions` fields:

```haskell
type InvariantRuleId = Natural

data InvariantRule = InvariantRule {
	ruleId :: InvariantRuleId,
	justification :: InvariantRuleJustification,
	assertion :: SomeInvariant,
	obviatedBy :: Maybe InvariantId }
```

This is an illustrative declaration. The proposition itself contains implication and quantifiers:

```text
for all x, y, z:
    if x < y and y < z then x < z
```

Variables are explicitly bound by quantifiers rather than inferred from separate premise and
conclusion lists. Closed facts and rules are logically valid. An unused quantified variable, such
as `for all x: 5 < 7`, should produce a warning rather than make the assertion invalid.

### Trust And Assumption Policy

Source declarations distinguish proof from trust:

```text
Proven assertion: admit as established knowledge; a duplicate may be marked obviated.
Disproven assertion: reject at its source location.
Unproven assertion: admit only through explicit `assuming` syntax.
```

An assumption is the programmer's explicit responsibility. Later established contradictions are
rejected with provenance where possible, but the compiler cannot guarantee global consistency for
arbitrary assumptions.

A conditional assertion is validated as a whole implication. In classical logic, `if P then Q` is
false only when `P` holds and `Q` fails. A conclusion that conflicts with established facts under an
antecedent proven false does not make the implication false. An antecedent that is merely unproven
is not thereby false.

Consequently, the former conservative proposal to assume a conditional's premises during insertion
and reject any hypothetical conflict is discarded. Validation may reject the implication when it
can establish the antecedent and disprove the consequent, but must not conflate impossibility,
unknownness, and contradiction.

### Provenance And Identity

Rule IDs remain stable within append-only context history. Invariants established from rules need
identities independent of active-list ordering:

```haskell
data InvariantId = InvariantId {
	ruleId :: InvariantRuleId,
	assertionPath :: InvariantPath }

data InvariantPath = InvariantPath [Int]
```

Names are illustrative. A path can identify a nested component for derivation and diagnostics, but
does not turn a child of an `OrInvariant` into an independently known fact.

Justifications should preserve source or builtin locations and derivation links:

```haskell
data InvariantRuleJustification =
	DeclaredInvariantRule { location :: SomeLocation } |
	DerivedInvariantRule { sources :: Populace InvariantId }
```

Additional justification forms may be needed for compiler-owned decisions and normalizations.
Locations belong to justifications rather than directly to every rule.

## Three Solver Mechanisms

One solver orchestrates three cooperating mechanisms.

### Decide

Decision is compiler-defined, direct, and context-independent. Native comparators decide atomic
comparisons when their operands provide enough information. Compiler-owned logical patterns can
also decide propositions such as `P and not P`, where `P` may be an arbitrary nested proposition.

A decision returns `Proven` or `Disproven`; it does not construct a truth-constant invariant. Child
decisions are consumed by the enclosing logical form and retain their parent/path context.

### Normalize

Normalization is compiler-defined, context-independent, deterministic, meaning-preserving
canonicalization. It always produces another invariant rather than a truth constant. Examples
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

Normalizers may use compiler-internal proposition metavariables that match an arbitrary invariant.
These are not exposed as source-level proposition variables, so user rules cannot redefine logic.

Normalization must not search `Context` or require unproven prerequisites. Domain-specific
equalities and mathematical laws belong to contextual application. Normalizers must be sound in
the selected theory, deterministic, idempotent at a fixed point, and oriented to avoid oscillation.
Fixed-width overflow and IEEE behavior prevent blindly applying real-number algebra.

### Apply

Application consults established contextual assertions and transforms a goal into obligations with
an explicit logical direction. It covers whole goals and nested expressions, but there is no fourth
subsystem for equality rewriting. A substitution must be justified by native semantics,
normalization, or an ordinary contextual assertion with a sound direction.

This matters for relations such as float numerical equality and bit identity. Replacing `+0.0`
with `-0.0` in an arbitrary bit-sensitive expression is unsound even though they are numerically
equal under IEEE equality.

## Local Simplification Fixed Point

The decision/normalization phase must be independently callable, or its history must be reliably
separable from contextual proof history. A callable local phase is preferred because source
declaration validation needs to identify direct and nested vacuity or contradiction.

Local simplification proceeds recursively:

```text
1. Run decision over the invariant and its children.
2. Consume terminal child decisions in their enclosing logical forms.
3. Return a whole-invariant terminal, or a possibly reduced invariant, with ordered history.
4. Normalize the remaining invariant recursively, recording transformations and justifications.
5. Repeat decision followed by normalization until terminal or at a combined fixed point.
```

The history records the rule identity, bindings, affected path/subexpression, and justification.
The combined cycle must have a termination guard in addition to well-oriented rules.

## Contextual Proof Search

After local simplification reaches a fixed point without deciding the goal:

```text
1. Check branch-local loop and resource limits.
2. Find applicable contextual assertions and construct possible transformed obligations before
   spending time proving their conditions.
3. Enumerate candidate applications. Each candidate records obligations, implication direction,
   bindings, target path, and justification. One rule may yield multiple matches.
4. Explore candidates as separate branches with branch-local bindings and backtracking. Do not
   destructively accumulate unrelated candidate rewrites into one goal.
5. Recursively solve each candidate's obligations, restarting with local simplification.
6. Interpret the result according to the application's implication direction.
7. Try other paths when one is inconclusive.
8. Return Proven, Disproven, or Unproven with provenance.
```

A loop, timeout, exhausted resource budget, or lack of a matching path yields `Unproven`, not
`Disproven`. An application need not pass a speculative complexity-progress test. Soundness,
applicability, fixed-point termination, and global cycle/resource guards are the controls.

### Implication-Direction Contract

For replacement obligations `R` and original goal `G`:

| Direction | If `R` is proven | If `R` is disproven |
|---|---|---|
| `ReplacementImpliesGoal` (`R -> G`) | `G` proven | Inconclusive |
| `GoalImpliesReplacement` (`G -> R`) | Inconclusive | `G` disproven |
| `Biimplicative` (`G <-> R`) | `G` proven | `G` disproven |

An unproven replacement is inconclusive. `Biimplicative` is preferred over `Equivalent` to avoid
confusion with a language equality comparator.

Direction remains important when a rule itself has a condition. If the rule has antecedent `P`,
its consequent comparison applies to `G`, and the comparison application produces `R`, then:

- for sufficient `R -> G`, `P and R` is a sufficient obligation;
- for necessary `G -> R`, `if P then R` is a necessary obligation; and
- a biimplicative comparison application may require two separately directed implications.

Using `P and R` for the necessary direction could unsoundly disprove `G` merely because `P` is
false. The generalized algorithm for deeply nested logical forms is deferred, but it must preserve
this constraint.

### Compound And Quantified Knowledge

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

## Proof Results And Artifacts

The solver needs at least these semantic outcomes:

```text
Proven
Disproven
Unproven
```

Resource exhaustion and cycle detection may have more specific `Unproven` result types. Typeclass
wrappers similar to `InvariantProof`, `InvariantDisproof`, and `InvariantUnproven` may let
signatures restrict acceptable outcomes, but exact Haskell sums and classes are not finalized.

Decision, normalization, and application may use distinct result types if the solver composes them
into coherent history. Useful proof artifacts record:

```text
the rule or native decision used
fresh and matched bindings
the targeted invariant and nested path
the justification and source provenance
the implication direction for contextual applications
branch-local loop/resource information
```

Avoid displaying trivial intermediates unless needed to explain a result. Source validation must
still be able to identify terminal whole invariants and vacuous, contradictory, or redundant nested
components.

## Type Templates, Satisfaction, And Contract Validation

### NativeBitsValue Satisfies NativeBitsType

Given a concrete value and a required bits type:

```text
1. Require exact bit-width equality.
2. Instantiate each required invariant template with the NativeBitsValue literal expression.
3. Confirm recursively that the resulting invariants are solver-ready.
4. Solve their conjunction using local simplification and contextual proof.
5. Proven means the value satisfies the refinement.
6. Disproven means it does not satisfy the refinement.
7. Unproven is an invariant mismatch because satisfaction was not established.
```

Example:

```text
requirement template: it (uint <) 7
candidate bits: 0x08
instantiated goal: 0x08 (uint <) 7
```

The unsigned comparator interprets `0x08` as `8` and directly disproves the comparison.

No widening occurs in satisfaction. A future source conversion must already be represented as an
explicit invocation before its result is tested against a wider type.

### NativeBitsType Satisfies NativeBitsType

Given a candidate type and required type:

```text
1. Require exact bit-width equality.
2. Create one fresh unconstrained symbolic subject of the shared unrefined bits type.
3. Instantiate both types' templates with that same subject.
4. Use the candidate constraint as local established knowledge.
5. Prove the required constraint for that subject.
6. Proven means every candidate value must meet the requirement.
7. Disproven or Unproven means type satisfaction fails, with distinct diagnostics when possible.
```

Candidate facts are local to the satisfaction check and do not mutate the original context. A
candidate disjunction remains one disjunctive assertion; its children are not inserted as separate
facts.

The common fresh subject replaces the old plan in which the solver matched a special `It`. Both
templates have already been instantiated before proof begins.

### Type Declaration Validation

To validate a standalone type definition, instantiate its template with a fresh arbitrary symbolic
subject of the unrefined underlying type. Do not use the refined type object as a value and do not
assume the declaration's own constraint while proving its validity.

The arbitrary subject has careful semantics:

- proving its complete constraint false can establish that no value can inhabit the type;
- failing to prove the constraint true does not establish uninhabitability; and
- claiming universal vacuity requires proof that the constraint is always true.

Explicit quantification or equivalent treatment may be needed to preserve this arbitrary-subject
meaning in the final implementation.

### Operator Return Contracts

For an operator declared to return a refined type, instantiate the return template with the actual
symbolic invocation and its bound arguments:

```text
f(x, y) (uint <) 10
```

Checking that an implementation honors the contract for arbitrary inputs is conceptually:

```text
for all x, y:
    f(x, y) (uint <) 10
```

Quantifier domains match the declared argument types. The required return invariant must never be
used as evidence that the implementation satisfies itself. It must be established from separately
validated implementation behavior. Once validated, the return contract is available for downstream
reasoning.

## Declaration Diagnostics

A type-attached invariant is intended to constrain its subject. Subject-independent assertions
belong in contextual rules rather than incidental return refinements. Effects and mutations remain
modeled through Beng's `Act` mechanism; they do not require special mutation-related invariant
exceptions.

Diagnostic policy:

- A provably uninhabitable complete type constraint is a compilation error.
- A provably vacuous type invariant or redundant nested component is a warning.
- A provably dead branch is a warning unless it makes the complete constraint impossible.
- An unused quantified variable is a warning.
- An inconclusive check must not be reported as vacuity, redundancy, or uninhabitability.
- Universally true contextual mathematical rules remain useful and are not banned as vacuous.

Examples, assuming integer semantics:

```text
it = it and it < 10              -- first component vacuous; warn
it < 10 and it < 20              -- second conjunct redundant if proven; warn
it < 10 and 7 < 5                -- complete constraint false; error
it < 10 or 7 < 5                 -- false branch redundant; warn
it < 10 or 5 < 7                 -- complete constraint true/vacuous; warn
it = 3 or (it < 2 and 7 < 5)     -- dead branch; warn
it < 5 and it > 10               -- complete constraint impossible if proven; error
```

The independently callable local simplifier and its detailed history catch direct cases. Stronger
redundancy and contradiction checks may invoke contextual proof afterward. Context-free
normalizers must not silently perform arbitrary context search merely to produce warnings.

## Proof Examples

### Comparison Application

Known fact and goal:

```text
known: x (uint <) 7
goal:  x (uint <) 8
```

The unsigned comparator can propose an application because the lesser expressions match. One
possible replacement expresses that the known upper bound is no greater than the requested bound:

```text
R: 7 (uint <) 8 or 7 (bits =) 8
direction: ReplacementImpliesGoal
```

Direct decision proves `R`, so the goal is proven. The same fact is irrelevant to a goal requiring
a lower bound such as `2 (uint <) x` unless other established knowledge connects the bounds.

This is an illustrative application, not a complete specification of integer bound reasoning.

### Less-Than Transitivity

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

### Bound On An Operation

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
knowledge to establish the goal. Each `<=` above is logical shorthand for `< or =` under the
selected interpretation.

This example does not imply that `sin` is executed by the proof engine. Its mathematical behavior
comes from established assertions about the symbolic invocation.

### Directional Type-Level Disproof

Known fact and goal:

```text
known: 10 < Index
goal:  Index < 7
```

If the goal held, transitivity would require `10 < 7`. This is a
`GoalImpliesReplacement` application. The integer comparator disproves the replacement, so the
direction contract permits the solver to disprove the goal.

Without that direction, a false derived condition would not by itself justify disproof. If no sound
path proves a goal or proves a necessary condition false, the result remains `Unproven`.

### Conditional Consistency

Suppose established knowledge says:

```text
halts(Machine) = no
```

The assertion `if P then halts(Machine) = yes` is not disproven merely because its consequent
conflicts with that fact. If `P` is proven false, the implication is true. If `P` is unproven, the
implication may remain unproven. It is disproven only when the solver establishes `P` and disproves
the consequent.

## Standard Library Comparison Props

Built-in semantic comparison invariants are distinct from ordinary user-defined `<` and `=` props.
The standard-library `<` operation is a normal executable `Op`. Its return type should relate the
returned bit to the built-in comparator without recursively calling the same `<` prop in its own
contract.

For an unsigned comparison returning one-bit `yes` or `no`:

```text
if A (uint <) B then it (bits =) yes
and
if not (A (uint <) B) then it (bits =) no
```

An equivalent form is:

```text
(it (bits =) yes and A (uint <) B)
or
(it (bits =) no and not (A (uint <) B))
```

Signed and IEEE float props use the corresponding comparator. For floats, `<` returns `no` when an
operand is NaN. Ordinary operator resolution selects the semantic declaration; width alone does
not determine unsigned, signed, or floating interpretation.

A return contract does not implement an operation. The runtime `Op` still requires a valid
implementation. The proof system reasons about established implementation properties without
confusing a native proposition with an executable boolean operation.

## Where Responsibilities Live

The solver owns:

```text
recursive local decision/normalization scheduling
contextual rule search and candidate enumeration
fresh variable identities, typed matching, and capture-avoiding substitution
branch-local bindings and backtracking
goal and obligation transformation
recursive proof and disproof interpretation by implication direction
loop and resource-limit handling
composition of derivation artifacts
```

Compiler-owned logical machinery owns:

```text
the fixed semantics of and, or, not, if, for all, and for some
intrinsic logical decisions and meaning-preserving normalizations
internal whole-proposition patterns unavailable to source rules
```

`InvariantComparator` owns:

```text
semantic interpretation of concrete bits
operand type and width validation
context-independent atomic decisions
comparison-specific candidate applications with sound directions
```

Invariant expressions own or expose:

```text
their structural view and type
literal, variable, and symbolic invocation structure
enough identity and argument information for matching and substitution
```

`Context` owns:

```text
available Ops and operator precedence
established invariant assertions and explicit assumptions
append-only rule history, obviation status, and provenance
```

`NativeBitsType` owns:

```text
its exact bit width
its subject-accepting invariant template
```

## Compiler Logic Versus Contextual Libraries

Fundamental logical simplification is fixed by the compiler. There is no separate configurable
“fundamental logical inference rules” subsystem. Users cannot replace conjunction, negation,
implication, or quantifier semantics.

Built-in contextual assertions can still provide mathematical or domain knowledge, such as:

```text
bit equality symmetry and transitivity
integer less-than transitivity
safe algebraic laws under the correct overflow premises
properties of explicit conversion operations
domain bounds for standard-library or foreign operations
```

These assertions use the same contextual application machinery as user-authored established rules
and assumptions. They must respect machine arithmetic and comparator semantics. In particular,
unconditional float equality reflexivity is invalid under IEEE numeric equality because NaN is not
equal to itself.

## Implementation Appendix

This appendix records expected integration work, not finalized module or API design.

### NativeBitsType Construction

Adding a function-valued invariant field affects positional constructors such as:

```haskell
NativeBitsType 32
NativeBitsType 1
```

Construction helpers may reduce migration cost. Display and structural equality need the same
placeholder-instantiation technique already used by `NativeType.properties`.

`NativeBitsType.satisfies` must replace its narrower-than-or-equal width check with exact equality.
Any conversion is an explicit invocation with independently established properties.

### Thing And Category Integration

Source-representable invariant forms, comparators, expressions, variables, and rules need suitable
`Thing` integration and the existing `Eq`, `Show`, `Messagable`, `Typeable`, and parameterization
behavior.

The final representation must also provide recursively enforced general and solver-ready subsets.
`NativeBitsType.resolve` must traverse instantiated invariant templates when expressions contain
ordinary parameters. Proof failures must integrate with existing type-checking `Mismatch` values.

New modules and source-import cycles may require Cabal entries and `.hs-boot` declarations. Plan
those changes with the module layout rather than treating the old sketches as fixed locations.

### Context Integration

`Context.empty`, `Context.push`, and `Context.fromOps` must initialize or preserve append-only rule
history. A dedicated insertion API is preferable because `Context.push` currently means adding an
operator and updating precedence.

The former `pushInvariantRule` signature with separate premises and conclusions is obsolete. A new
API should accept one assertion, justification, and declaration mode such as ordinary proof-required
declaration versus explicit `assuming`. It should return insertion status and a stable rule ID while
preserving `Proven`, `Disproven`, and `Unproven` distinctions.

Insertion can mark an already established assertion as obviated. It rejects a disproven assertion
and admits an unproven assertion only under `assuming`. Conditional validation operates on the whole
implication rather than hypothetical premise injection.

Context merging is deferred. Existing `Context.concat` must not silently discard rule history if it
is later used with invariant-bearing contexts; imports may require ID remapping.

### Symbolic Invocation Isolation

Ordinary runtime arguments should be recursively concrete. Symbolic applications can contain
quantified variables and must preserve structure without execution. Options include a separate
`InvariantInvocation` or a category-parameterized invocation type. Changing only one outer argument
wrapper is insufficient if a composite `ConcreteThing` can hide symbolic children.

Closed symbolic expressions may eventually reduce through an existing execution path when proof
explicitly requests it and execution is valid. This is a proof optimization/base case, not a
general invariant evaluation API.

### Solver Safety And Diagnostics

Local simplification needs fixed-point and oscillation protection. Contextual search needs active
branch tracking, fresh application identities, backtracking, and resource bounds. Initial
implementations may be conservative; timeout and loop outcomes stay `Unproven`.

Derivation data should exist even if initial diagnostics display only the strongest failed path.
Nested decision paths and source/derived justifications are important for declaration warnings and
contradiction errors.

Avoid premature indexing, memoization, elaborate prioritization, and exhaustive native decision
inventories before semantics and interfaces have tests. Such optimizations must not change proof
meaning.

## Open Design Work

The following issues remain deliberately unresolved:

1. **Generalized contextual application calculus.** Define exact proof and disproof transformations
   for deeply nested `and`, `or`, `not`, `if`, `for all`, and `for some`, while preserving the
   implication-direction contract.
2. **Exact Haskell representations.** Settle recursive general/solver-ready categories, expanded
   structural views, symbolic invocations, internal proposition patterns, and existential wrappers.
3. **Decision and transformation result types.** Design signatures that retain ordered nested
   provenance, bindings, paths, and application directions without treating sketches as final APIs.
4. **Normalization inventory and termination.** Choose sound canonical forms and a matcher, define
   theory-specific arithmetic limits, and ensure the combined decision/normalization loop cannot
   oscillate.
5. **Quantifier algorithms.** Specify freshening, witness discovery, universal reasoning,
   capture-avoiding substitution, and branch-local binding behavior in difficult nested cases.
6. **Declaration consistency depth.** Decide how much contextual search to spend finding later
   conflicts, uninhabitable types, vacuity, and redundancy. Unknownness must remain distinct from
   contradiction.
7. **Source grammar.** Finalize type-invariant and rule declarations beyond the agreed illustrative
   `for all`/`for some`, `it`/`one`, `assuming`, and `(uint <)`-style terminology.
8. **Fresh symbolic subjects.** Specify construction and validation so type declarations use an
   arbitrary unrefined subject and cannot prove themselves circularly.
9. **Comparator-aware substitution.** Define which contextual equalities permit replacement inside
   each expression and comparator context, especially for floats, signed zero, and raw bits.
10. **Search strategy.** Determine useful ordering among direct decisions, whole-goal applications,
    nested applications, and alternative branches without making heuristic failure a disproof.
11. **Context composition.** Design import/merge behavior, stable ID remapping, and diagnostic order
    for append-only rule histories.
12. **Runtime and standard-library integration.** Define comparison implementations, float widths,
    overflow behavior, and conversion operations with independently validated contracts.
13. **Architecture audit.** Test nested conditionals, quantifier order, negation, symbolic
    invocations, contradictory assumptions, NaN, and directional counterexamples before declaring
    the implementation design complete.

## Likely Implementation Phases

The order may change as representation experiments expose dependencies.

1. Add general invariant forms and native comparator definitions without type-checker integration.
2. Add `Thing` integration and structural views for source-representable invariant structures.
3. Prototype recursively enforced general and solver-ready categories, including `It` elimination.
4. Add subject-accepting `NativeBitsType` templates and construction/display helpers without yet
   relying on them for satisfaction.
5. Add append-only context assertions, metadata, stable IDs, provenance, and explicit assumption
   insertion policy.
6. Implement native atomic decisions and recursive compound decision propagation with histories.
7. Implement a small, sound normalization set and the guarded local fixed-point loop.
8. Define candidate application records and the three-way implication-direction contract.
9. Implement basic contextual search, fresh variables, branch-local bindings, backtracking, and
   loop/resource handling for a deliberately limited logical subset.
10. Expand application semantics through tests for conjunction, disjunction, negation, implication,
    and quantified forms; do not claim completeness before the architecture audit.
11. Add exact-width `NativeBitsValue` and `NativeBitsType` satisfaction using instantiated,
    solver-ready templates.
12. Add standalone type-declaration validation and nested vacuity, redundancy, and uninhabitability
    diagnostics.
13. Integrate symbolic operator return contracts without circular self-proof.
14. Add parser/build support for invariant declarations, quantifiers, `assuming`, and native
    comparator syntax.
15. Add standard-library comparison props, conversion contracts, and carefully staged float and
    fixed-width arithmetic support.
