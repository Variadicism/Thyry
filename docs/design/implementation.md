# Implementation Architecture

[Proof design index](../design.md)

This document assigns enduring system responsibilities and component boundaries without prescribing
one implementation language or transient migration sequence.

## Solver Coordination

The solver coordinates three separate activities:

- **Normalization** performs deterministic, context-independent, meaning-preserving
  canonicalization of formulas and expressions, returning the corresponding kind and recording each
  transformation.
- **Decision** works depth-first and context-independently, deciding intrinsic expressions and
  logical forms where possible. It records every individual nested decision.
- **Contextual application** searches established Propositions and produces alternative directed
  obligations rather than destructively rewriting one shared goal.

Conceptually, `simplify` runs normalization before decision and repeats only after decision reduces
the formula. `search` finds contextual alternatives. `prove` controls recursive exploration,
backtracking, and interpretation of application directions. These names describe responsibilities,
not frozen implementation interfaces.

Proof exploration owns fresh variable identities, typed matching, capture-avoiding substitution,
branch-local bindings, cycle and resource handling, and derivation artifacts. Iterative deepening is
favored for contextual search. Exhaustion, a cycle, or a timeout remains `Unproven`.

## Logical Representation

Logical expressions and formulas expose their structure while preserving the recursive hierarchy
from general Logical values through Constraint templates to solver-ready Propositions. Solver entry
must guarantee that no `It` remains anywhere in a Proposition.

The representation must include literals, quantified variables, and symbolic invocations. Symbolic
invocations preserve resolved operator identity, arguments, bindings, captures, result type, and
other applicability evidence without executing the operation.

Compiler-owned logical machinery defines the meanings of `and`, `or`, `not`, `if`, `for all`, and
`for some`. It also owns intrinsic decisions and normalization rules. Source Propositions may add
domain knowledge but cannot redefine this logical core.

## Context And Proof Availability

The compilation context owns available operators and precedence, established Propositions and
explicit assumptions, visibility, and stable provenance. Proposition history remains append-only so
obviation does not invalidate identities used by diagnostics and derivations.

Contextual search begins with the complete context available at the proof root, ordered from most
recent to oldest and filtered by scope and visibility. Applying an older Proposition does not
truncate the context used for nested type compatibility or its resulting obligations. Recursive
reasoning may add scoped branch-local knowledge, subject to non-circularity safeguards.

Operator resolution assigns one stable operation identity to each code locus during compilation.
Resolution may use grammar, declarations, ordering, Constraints, and established proof knowledge,
but runtime argument values never select another operator.

## Type And Contract Validation

Type checking establishes structural compatibility separately from logical Constraint implication.
Constraint templates are instantiated with one shared subject before proof. Type declarations and
all property invocations are checked for well-formedness before proof search.

Types are first-class values. Quantified variables may range over types, and dependent declarations
may refer to earlier variables. Their structural domains and logical Constraints both participate in
reasoning.

Return-contract validation may mention the symbolic invocation being checked, but the invocation's
unvalidated return contract is not established evidence. Pure extensionality is intrinsic once the
resolved operation and effective inputs are known to match.

Relational union return contracts describe valid alternative representations without introducing a
compile-time-versus-runtime semantic distinction. Type checking, resolution, and code generation
must preserve the relationship that selects or excludes alternatives.

## Intrinsics And Code Generation

The intrinsic bit and integer layer owns exact portable semantics, target-capability checks,
concrete evaluation, symbolic relationships, and operation-specific projection laws. Physical
storage and C lowering are code-generation responsibilities and do not define intrinsic meaning.

Implementation selection may choose source, interpreted, native, foreign, or precomputed paths only
when they reproduce the selected operation's exact semantics. Platform-specific operations require
target-correct compile-time evaluation or abstention.

Observation analysis may avoid materializing unobserved values, but it may not alter static
contracts, resolved operation identity, or exact pure results. Effects and diagnostics retain the
separate architecture described in [observability](observability.md).

## Proof Traces And Diagnostics

Every explored branch has an independent chronological trace. Normalization, decision, and
application all contribute steps. Step IDs are branch-local indexes, and generated variable
identities refer to those indexes.

A conclusive result returns only its successful proof or disproof path. `Unproven` returns a
nonempty collection of the closest attempts, each paired with its residual formula. Closeness is a
diagnostic heuristic and cannot affect soundness. Full exploration logs, when enabled, are separate
from returned traces.

## Related Documents

- [Proof system](proof-system.md)
- [Contracts and type validation](contracts.md)
- [Observability, acts, and diagnostics](observability.md)
- [Unresolved proof design](../unresolved/proofs.md)
