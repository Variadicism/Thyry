# Proof-System Data Model Proposals

[Plan index](README.md)

The declarations below are non-compilable design sketches. Field names, constructors, wrappers,
module locations, constraints, and associated types remain subject to implementation design.

## Category Hierarchy

**Agreed architectural requirement:** formulas and expressions enforce the recursive hierarchy
Logical → Constraint → Proposition. Proposition children are recursively `It`-free; a marker on only
the outer node is insufficient.

**Candidate representation:** use explicit superclass relationships resembling:

```haskell
class Thing expression => LogicalExpression expression
class LogicalExpression expression => ConstraintExpression expression
class ConstraintExpression expression => PropositionExpression expression

class Thing formula => LogicalFormula formula
class LogicalFormula formula => ConstraintFormula formula
class ConstraintFormula formula => PropositionFormula formula
```

This sketch does not decide whether the last superclass relation is the best encoding. It expresses
the required subset relationship, not a permission to coerce an arbitrary Constraint containing
`It` into a Proposition.

**Candidate representation:** structural views should be parameterized by the admissible child
wrapper. A Proposition view recursively contains `SomePropositionExpression` or
`SomePropositionFormula` children. A Constraint view adds the `It` leaf. Do not use a one-node view
wrapper as the recursive child type: views inspect a node; children remain expressions or formulas.

Views must cover comparison, conjunction, disjunction, negation, implication, universal and
existential quantification, literals, variables, and symbolic user-defined invocations. They are not
limited to intrinsic bit operations.

**Open:** exact classes, associated types, view names, wrapper placement, and duplicate method-name
avoidance.

## `It` Substitution

**Agreed architectural requirement:** `withItAs` replaces all occurrences of `It` consistently and
returns a solver-ready Proposition expression or formula.

**Candidate representation:** accept an ordinary typeclass-polymorphic concrete replacement as an
input. Use an existential wrapper principally for the result when substitution can change the
concrete constructor type. Do not require the caller to wrap a known replacement merely because the
result is existential.

**Open:** exact signatures, traversal ownership, and handling of dependent types inside symbolic
invocations.

## Verdicts And Results

**Candidate representation:** reserve `ProofVerdict` for the three semantic judgments:

```haskell
data ProofVerdict = Proven | Unproven | Disproven
```

**Agreed architectural requirement:** a verdict is distinct from a complete result containing traces
or failed attempts.

**Candidate representation:** model a failed attempt and complete result approximately as:

```haskell
data FailedProof = FailedProof {
	steps :: [ProofStep],
	residual :: SomePropositionFormula }

data ProofResult =
	Conclusive {
		verdict :: ProofVerdict,
		steps :: [ProofStep] } |
	Inconclusive {
		attempts :: Populace FailedProof }
```

The conclusive constructor must only permit `Proven` or `Disproven`; enforce that invariant through
constructor design or smart construction rather than trusting callers. `Populace` is imported in the
current code from `Utils.Populace`; verify whether it enforces non-emptiness before relying on it.

**Open:** exact result constructors, invariant enforcement, and whether limit/cycle causes need
structured metadata in failed attempts.

## Steps And Trace Identity

**Agreed architectural requirement:** a proof trace is `[ProofStep]`. `ProofStepId` is exactly the
zero-based index of a step in that trace, step zero records the initial goal, and `ProofStep` does
not store its own ID. Do not allocate globally unique IDs across traces.

**Candidate representation:** define `ProofStepId` as an index-oriented newtype or alias, subject to
checking arithmetic and display needs. A `ProofStep` sum should represent at least:

- the initial goal;
- one normalization transformation;
- one individual nested decision;
- one simplification-level reduction if separate from its decision steps; and
- one contextual application.

Every transformation step stores its `before` value, rule/reason, and relevant path, location,
bindings, and provenance. Do not store a redundant `after` field in every step; the following step
or final result supplies the endpoint.

**Candidate representation:** normalization and decision intermediate records may resemble:

```haskell
data Normalization = Normalization {
	steps :: [NormalizationStep],
	result :: SomePropositionFormula }

data Decision =
	Undecided |
	Decided {
		verdict :: ProofVerdict,
		steps :: [DecisionStep] } |
	Reduced {
		steps :: [DecisionStep],
		result :: SomePropositionFormula }
```

`Decided` must not contain `Unproven`. The actual design may encode this more strongly. Use
`SimplificationStep` for steps emitted by `simplify`; do not introduce a second `LocalStep` synonym.

**Candidate representation:** a `Simplification` result carries either a conclusive verdict or the
residual formula together with its ordered `[SimplificationStep]`. Its exact constructors should
follow the decision representation once the decision rules are designed.

**Open:** exact step variants, formula-versus-expression payloads, rule identities, and how nested
paths are represented.

## Logical Variables

**Agreed architectural requirement:** one logical variable stores declaration origin, introducing
proof-step ID, and declared parameterized type. Its identity is origin plus step; type and display
name are not identity.

**Candidate representation:** start from:

```haskell
data LogicalVariable = LogicalVariable {
	origin :: SomeLocation,
	step :: ProofStepId,
	declaredType :: SomeParameterizedThing }
```

Do not add a separate `LogicalVariableId` record unless implementation needs justify it. Universal
and existential variables share this representation; their formula constructor supplies quantifier
kind. Dependent type occurrences must be freshened consistently with their binder.

**Open:** display-name storage, ordering, alpha-equivalence representation, and whether
`SomeParameterizedThing` is sufficient for all dependent declarations.

## Contextual Applications

**Agreed architectural requirement:** direction belongs to each application, not to a Proposition
declaration. Conceptual directions are May Prove, May Disprove, and May Prove or Disprove.

**Candidate representation:** tentative Haskell constructors are `MayProve`, `MayDisprove`, and
`Biimplicative`. An application may have a polymorphic transformed result:

```haskell
data Application a = Application {
	result :: a,
	direction :: ApplicationDirection,
	bindings :: LogicalBindings,
	target :: FormulaPath,
	justification :: ApplicationJustification }
```

**Open:** exact obligation type, antecedent handling, path/binding records, justification shape, and
whether one application can carry multiple separately directed obligations.

## Propositions And Context History

**Agreed architectural requirement:** admitted Propositions carry stable identity, assertion,
justification, obviation status, and provenance in append-only history. A nested path identifies a
component for diagnostics but does not establish a disjunct independently.

**Candidate representation:** use a context-local monotonically assigned proposition ID and a path
for nested components. Preserve source, intrinsic, derived, assumption, and foreign-trust reasons.

**Open:** exact IDs, merge/remapping behavior, visibility metadata, and whether history resides
directly in `Context` or in a referenced component.

## Symbolic Invocations And Type Alternatives

**Agreed architectural requirement:** symbolic invocations preserve resolved declaration identity
and recursively corresponding arguments, bindings, captures, return type, and location without
execution. Printed `show` output is not semantic identity.

**Candidate representation:** either parameterize the existing invocation representation by logical
category or introduce a separate symbolic invocation. Do not change ordinary `Eq Invocation` solely
to satisfy proof matching unless all existing uses require the new semantics.

**Agreed architectural requirement:** native bit values retain actual length; native bit types gain
subject-dependent Constraint templates, and the type system supports relational alternatives.
Existing `NativeOrType` may inform union integration, but a plain unconstrained union is
insufficient for a relational return contract.

**Open:** exact `NativeBitsType` fields, union representation, constructor helpers, and relationship
with `NativeOrType`.
