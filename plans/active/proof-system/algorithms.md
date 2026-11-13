# Proof-System Algorithm Plan

[Plan index](README.md)

This file translates settled control flow into implementation responsibilities. The exact inference
rules and Haskell signatures remain open.

## Top-Level Responsibilities

**Agreed architectural requirement:** use one public conceptual path through `prove`, `simplify`,
and `search`. Do not expose both `search` and a near-duplicate `searchApplications` without a
demonstrated separation of responsibility.

- `prove` owns simplification, recursive candidate exploration, backtracking, verdict transfer, and
  closest-failure selection.
- `simplify` owns normalization-before-decision iteration and its ordered steps.
- `normalize` owns deterministic context-free canonicalization.
- `decide` owns depth-first context-free evaluation and logical decision.
- `search` owns enumeration of contextual applications, not recursive proof of their obligations.
- `apply` owns one sound transformation with its bindings, target, and direction.

**Open:** exact signatures, monadic context, and whether formula and expression variants share one
interface.

## Simplification

**Agreed architectural requirement:** the order is:

```text
simplify(goal, trace):
    normalized, normalizationSteps := normalize(goal)
    append each normalization step to trace
    decision := decideDepthFirst(normalized)
    append each individual decision step to trace

    if decision settles the whole formula:
        return its verdict and trace

    if decision produces a residual:
        recurse on the residual

    otherwise:
        return the normalized residual and trace
```

Do not normalize again merely because normalization emitted steps. It has reached normal form. A
new pass occurs only after decision changes the formula.

Normalization steps and decision steps must be appended in the order in which they occur. If either
activity introduces a variable, allocate the variable with the index of the step being constructed,
not through later renumbering.

**Open:** normalization rules, decision rules, exact reduction endpoints, and guards against a buggy
normalizer or decision/reduction cycle.

## Depth-First Decision

**Agreed architectural requirement:** attempt constituent expressions and subformulas before their
enclosing form, with sound short-circuiting. A decided child may be consumed without constructing a
truth-constant AST node.

A multi-child reduction records one decision step per decided child or intrinsic expression. It
must not collapse all nested work into one rule ID. Expression decisions may return concrete values;
formula decisions return truth judgments or a residual formula.

**Open:** connective tables, path representation, intrinsic arithmetic evaluation, and exact
partial-reduction result types.

## Normalization

**Agreed architectural requirement:** normalization is deterministic, context-independent,
meaning-preserving, and convergent. It may increase expression size and must not use arbitrary
contextual equality.

**Candidate implementation:** begin with a deliberately small set of unquestionably oriented rules,
such as double-negation elimination, after their interactions are tested. Keep rule identity and the
`before` node for each application.

**Open:** De Morgan orientation, canonical child ordering, associativity, quantifier normalization,
tautology treatment, and theory-specific arithmetic normalization.

## Contextual Search

**Agreed architectural requirement:** search starts with the complete proposition context available
where the current proof began, from most recent to oldest and filtered by scope and visibility. A
located older Proposition does not truncate the context for matching, nested type satisfaction, or
recursive obligations.

Legitimate branch-local bindings and assumptions may extend the proof-root context. Their scope and
non-circularity must be explicit. Candidate Constraint implication during nested type satisfaction
is local knowledge, not a mutation of the root context.

**Agreed architectural requirement:** each application is an alternative immutable branch. Do not
rewrite all matches into one shared goal, and do not split a conjunction when doing so loses shared
variables, cross-dependencies, or quantifier scope.

**Candidate algorithm:** use iterative deepening by contextual application count. Within one depth,
enumerate established Propositions most-recent-first and preserve deterministic match order where
practical.

Cycle detection compares normalized, alpha-equivalent goals together with relevant contextual
knowledge. A cycle, exhausted depth/resource budget, timeout, or no candidate is `Unproven`.

**Open:** candidate prioritization, relevant-context fingerprint, nested-goal enumeration, and the
complete application calculus.

## Directional Result Transfer

**Agreed architectural requirement:** for original goal `G` and replacement obligation `R`:

| Direction | Guarantee | `R` proven | `R` disproven |
|---|---|---|---|
| May Prove | `R => G` | `G` proven | inconclusive |
| May Disprove | `G => R` | inconclusive | `G` disproven |
| May Prove or Disprove | `G <=> R` | `G` proven | `G` disproven |

An `Unproven` replacement is always inconclusive. Antecedents, negation, nested polarity, and
quantifiers can change the required direction; do not infer direction from the Proposition alone.

**Open:** exact transformation rules for each logical position.

## Quantifiers And Freshening

**Agreed architectural requirement:** every application freshens quantified declarations. All
occurrences of one declaration, including occurrences in dependent types, receive the same new
variable. Different applications receive different variables.

Universal declared-type Constraints behave as implications; existential declared-type Constraints
behave as conjunctions. Structural domains remain separate from these logical Constraints.

**Open:** binder opening, witness search, dependency ordering, temporary assumptions, and
capture-avoiding substitution algorithms.

## Trace Branching And Failed Attempts

**Agreed architectural requirement:** branch by immutable trace extension. A conclusive proof or
disproof discards abandoned attempts from its returned trace. `Unproven` returns a nonempty
collection of the closest attempts, each with its residual formula; retain all ties.

**Candidate closeness heuristic:** prefer fewer or smaller genuine residual obligations after local
simplification, then shorter application depth. Keep the score outside verdict logic.

**Open:** initial metric, tie explosion limits, and structured reasons for cycle/resource failure.
Debug logging may record every path independently of returned traces.

## Type Satisfaction

**Agreed architectural requirement:** validate declarations and property invocations before proof.
Then separate structural compatibility from logical implication.

For type-to-type satisfaction:

1. pair structurally compatible alternatives;
2. create a fresh subject for each relevant underlying domain;
3. instantiate candidate and required Constraint templates with the same subject;
4. add candidate Constraints as branch-local knowledge; and
5. prove required Constraints for every candidate value.

Nested checks retain the proof-root context. Do not use the unvalidated return contract of a
symbolic invocation as evidence for itself, although the invocation may occur in the goal.

**Open:** relational union coverage, uninhabitability handling, diagnostics, and integration with
the existing fallible `Mismatch` path.

## First Iteration Boundaries

- No cross-trace result caching.
- No elaborate proposition indexing or heuristic prioritization.
- No claim of complete connective or quantifier support.
- No dependence on future pursuit/convergence implementation.
- No unsafe, foreign, or target-incompatible execution for proof.
