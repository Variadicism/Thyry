# Contracts And Type Validation

[Proof design index](../design.md)

## Goal

`NativeBitsType` should be able to describe zero or more compile-time checked assertions about the
bits represented by a `NativeBitsValue` that befits that type.

Example intent:

```text
it (uint <) 7
```

This means any `NativeBitsValue` that befits the relevant `NativeBitsType` must contain bits whose
unsigned integer interpretation is less than `7`.

Constraints may also mention ordinary Thyrym operators:

```text
sin(it) < 7
```

Such an assertion may be provable when the context contains established laws that provide a
sufficient bound for `sin(it)`. The invocation is a symbolic expression in the proposition; the
proposition itself is not an executable operation.

More generally, every typeable value has a complete statically assigned type, including applicable
constraints and props. Implementations must satisfy that contract. The compiler may choose how and
where to evaluate pure expressions, but a pure operation denotes one exact result for each tuple of
effective inputs under its selected program and target semantics. The compiler may erase physical
implementation distinctions only while preserving that deterministic mapping.

The central division of responsibility is:

> The static type describes what a value promises. Observation analysis describes what generated
> code must make distinguishable to semantic observers. Properly designated diagnostic
> instrumentation may inspect a selected implementation without becoming a semantic observer.
> Neither permits nondeterministic selection among values allowed by an incomplete Constraint.

The final sentence is conditional on a diagnostic facility whose classification is not yet
designed. General unsafe effects cannot automatically receive diagnostic treatment.

## Terminology And Status

- A **static type** is the authoritative source-language type, including all relevant Constraints,
  props, and behavioral relationships. Optimization never weakens it.
- A **Constraint** is a logical condition attached to a type. A **Proposition** is standalone
  contextual logical knowledge. Both use the [logical formula
  language](proof-system.md#logical-formula-language).
- A pure operation's **contract** includes its one deterministic mapping from effective inputs to
  exact logical results. Declared result Constraints and Propositions may describe only incomplete
  properties of that mapping. A pure Thyrym function or prop implementation must prove its declared
  result contract. A foreign declaration is trusted and is an explicit soundness boundary.
- **Observable type** is the provisional design term for the compiler-derived requirements that
  generated code must preserve for a value. **Observation contract** may be a more accurate internal
  name because requirements can be relational, path-sensitive, and graph-shaped. That naming and
  representation remain unresolved.
- A **semantic observation** constrains conforming generated behavior. Ordinary performed acts and
  public interfaces are examples. A **diagnostic observation**, if explicitly supported, reveals
  implementation-selected details without adding value constraints to observation analysis.
- Examples marked illustrative explain semantics only. They do not settle Thyrym grammar, binder
  spelling, or the Haskell API.

## Design Principles And Boundaries

- All runtime data is still bits.
- The semantic interpretation of bits belongs to the comparator, not to a separate runtime domain
  type.
- A Constraint or Proposition is a logical formula. Logical expressions may contain ordinary
  Thyrym operators, but logical formulas are not themselves executable operations.
- The compiler owns the meaning and fundamental laws of `and`, `or`, `not`, `if`, `for all`, and
  `for some`. Users may state domain-specific facts and assumptions, but may not redefine logic.
- Every ordinary logical form needed by proof reasoning should also be expressible in source.
  Compiler-internal whole-formula metavariables are the exception.
- Ranges and intervals are ordinary combinations of logical comparisons and logical forms.
- Direct `NativeBitsType` satisfaction requires equal logical bit lengths. This does not require
  intrinsic `sint`/`uint` arithmetic or ordering to use equal-width operands.
- There is no separate logical-function category. Ordinary Thyrym operators are used in logical
  expressions.
- Contextual knowledge lives in `Context`, alongside the available `Op`s.
- Proof uses `Context` plus branch-local bindings, history, and loop/resource tracking.
- Type/value satisfaction distinguishes `Proven`, `Disproven`, and `Unproven`. Failure to prove a
  required Constraint is a type mismatch, but is not automatically a disproof.
- The complete static contract remains authoritative even when no runtime check or observer exists.
- Every pure operation is deterministic and extensionally pure by definition. The same resolved
  operation, bindings, captures, dispatch evidence, and effective inputs imply the same exact
  logical result without an additional user-authored return Constraint.
- Evaluation stage and machine do not change a pure operation's selected semantics. Compilation on
  a host, execution on a target, interpretation, and optimization are implementation choices, but
  each must reproduce that operation's exact mapping.
- Generated code must preserve source-level relationships, path conditions, effects, public
  interfaces, exact pure results, and other semantic observations. It need not preserve every
  physical instruction, register, buffer, memory layout, or unused intermediate representation.
- Observation requirements propagate backward through all uses. A later branch or act can constrain
  an earlier materialization.
- Exact equality and approximate equivalence are different relations. Approximate equivalence must
  not be used for transitive substitution as though it were exact equality.
- Code may explicitly introduce an unproven assertion only with conspicuous `assuming` syntax.
- No intentionally uninhabitable or never-type facility is being designed here. A type proven to
  have no possible values is an error.
- Anything representable in Thyrym code should generally be a `Thing`. Internal solver patterns and
  proof machinery need not be source-representable.
- The architecture should be mathematically sound and extensible. This plan does not attempt to
  enumerate every theorem-proving strategy or native decision case before implementation.

## Portable Operation Contracts

### Built-In, Source, And Foreign Implementations

Intrinsic bit and integer operations and standard-library mathematical operators need explicit
contracts. The proof engine may directly decide concrete intrinsic expressions, such as unsigned
comparison of concrete integers, and reason symbolically through normalization and contextual
rules. This does not permit arbitrary symbolic applications to be replaced by native execution.

Standard-library operations may use foreign functions and native representations. In discussions
of these declarations, `uint*` denotes the family of unsigned integer types such as `uint8_t` and
`uint32_t`; it does not denote a C pointer. Different platforms may provide different foreign
implementations. For one portable pure operation, every selected implementation must produce the
same exact logical result; satisfying the same loose result Constraints is insufficient. A suitable
source-language implementation may be used when no native implementation exists; absence of an FFI
implementation does not inherently require compilation to fail.

A pure source implementation must establish that its body's resulting type satisfies the declared
result type and Constraints without circularly assuming that same contract. A foreign declaration's
author asserts that its implementation is side-effect-free, deterministic, and contract-correct;
the compiler does not independently prove foreign machine code. Hidden ambient inputs such as a
changing rounding mode must be fixed and restored, represented as effective inputs, or moved into
an act. Reviewed shared foreign libraries should be preferred because an incorrect declaration
makes the program's proof foundation unsound.

Intrinsic integer contracts define exact mathematical results, proof-selected lengths, signed
arithmetic, and division edge cases without inheriting C overflow or shift behavior. Floating-point
formats and arithmetic are standard-library concerns whose contracts must address NaN, infinities,
signed zero, subnormals, rounding, exceptions, and any separately defined deterministic fast-math
semantics.

### Symbolic Reasoning Versus Compile-Time Execution

The proof system may reason from a pure operator's declared contract even when its implementation
cannot safely be executed during compilation. Actual compile-time execution is a separate, stricter
capability: it requires an available, safe evaluator known to reproduce the exact required
semantics, including target specialization where applicable, plus the convergence and resource
evidence required for the demanded computation. Proving convergence does not itself require or
authorize compile-time evaluation.

The compiler must not execute acts through `unsafely once`, `unsafely each time`,
`unsafely recursively`, or another unsafe effect escape during compilation. Apparent purity does
not make the effect safe on the compiler host. The declared result type and Constraints remain
available for symbolic reasoning, but the compiler cannot obtain a concrete result by executing the
act.

Likewise, native or foreign implementations are not run during compilation to prove their own
contracts. Their declared argument and result contracts participate in reasoning as trusted
programmer assertions. Compilation that actually requires evaluation needs an exact evaluator for
the operation's selected semantics. A target-specific operation may use a target-compatible
evaluator or emulator; the compilation host's differing implementation is insufficient. Optional
foreign-contract validation tooling would not replace this trust boundary.

Operators have no silently undefined results. Provable preconditions must exclude invalid domains,
such as a zero divisor. Failures that cannot reliably be excluded beforehand, such as a file race,
must be represented in the result rather than treated as though no result exists.

### Exact Agreement Across Implementations

A portable pure operation has one exact logical result for each effective input. A source,
interpreter, compiler-host, target, native, or foreign implementation of that operation may differ
internally, but it must reproduce that result. If a portable implementation returns one NaN payload
and a native implementation returns another, they are not interchangeable merely because both
satisfy an `is NaN` Constraint.

A compiler may select a native instruction only for inputs on which exact agreement is established,
using an exact fallback elsewhere. Physical instructions, registers, temporary buffers, layouts,
and unused intermediates need not match.

A platform-specific pure operation may instead define exact semantics for each supported target.
It remains deterministic and side-effect-free on the selected target. Distinct targets may define
different mappings, but one compiled program cannot mix those answers under one operation identity,
and the host must not fold a target call using incompatible host behavior.

### Compile-Time Execution Versus Exact Compile-Time Knowledge

Executing an expression during compilation is not the same as proving that every valid
implementation produces one exact value. Compile-time syntax construction, such as producing a
string that is substituted into operator syntax, requires a string proven equal to one exact value.
Portable exact operations or a target-correct evaluator may establish that fact. Merely obtaining
one host approximation, or knowing that the deterministic result lies in a range, does not.

A separately defined approximation operation may be evaluated when its own deterministic semantics
are reproduced exactly. If Constraints do not establish one exact syntax string, syntax
substitution must not proceed as though determinism alone made that result known or computable.

### Equality Relations

The intrinsic proof foundation contains exactly bit equality plus signed and unsigned less-than.
Proven `A (bits =) B` means equal-length, identical bit sequences and authorizes congruent
substitution of those bit payloads in pure expressions while preserving typing, resolved operation
identity, bindings, and other applicability conditions.

Cross-length numerical equality first extends the shorter representation to the longer length—zero
extension for `uint`, sign extension for `sint`—then uses `(bits =)`. This numeric equality does not
make the original unequal-length representations substitutable in length-sensitive or bit-sensitive
operations. Floating-point numerical equality and approximate equivalence are likewise higher-level
relations. The spelling `~=` is established, but its exact tolerance semantics remain open.

Ordinary Thyrym `=` is a higher-level, potentially domain-specific operator. It may deliberately
ignore fields that are irrelevant to a domain's identity. Its truth can supply derived knowledge
through a validated contract or Proposition, but it does not merely by being true grant the solver
foundational substitution authority.

Only intrinsic logical comparators and rules may define foundational substitution behavior. Any
substitution needs explicit applicability conditions that the solver establishes first. A
standard-library IEEE equality can treat signed zeros differently from bit equality and is not
reflexive for NaN; its contract does not make floating-point comparison intrinsic. Exhaustive
substitution rules for exact bit identity are conceptually settled; their matcher and representation
remain architecture work. Higher-level exceptional-value behavior is not settled here.

## Contract And Optimization Guardrails

1. **No circular evidence.** A function's return annotation cannot establish its own numerical or
   other declared result properties. Use a separately checked implementation proof or a trusted FFI
   declaration. Extensional determinism follows from purity, not from that annotation.
2. **No approximate substitution.** Overlapping error intervals and approximate equivalence do not
   imply exact equality or authorize transitive replacement.
3. **No stage-dependent semantics.** Host compile-time and target runtime evaluation are
   implementation choices and must reproduce the selected exact mapping. Explicit platform-specific
   semantics select the target mapping rather than permitting accidental host behavior.
4. **No local-only observation analysis.** Later uses, branches, acts, and interfaces can impose
   requirements on earlier values.
5. **No loss of relational obligations.** Individually valid `R` and `C` can still violate an
   observable promise relating them.
6. **No unchecked expansion of trust.** Incorrect foreign contracts are an acknowledged soundness
   boundary and should be isolated in reviewed libraries.
7. **No conflation of type checking and materialization.** Erased diagnostics and props must have
   been statically valid even when their runtime values or implementations are unnecessary.
8. **No blanket exemption for unsafe effects.** Only explicitly defined diagnostic semantics may
   remove observation obligations; general unsafe effects can influence ordinary behavior.
9. **No silent omission of other behavior.** Exceptions, errors, nontermination, data races,
   external resources, and similar behavior limit elimination whenever the language defines them as
   observable.
10. **No varying result for one pure call.** Identical effective inputs to the same resolved pure
    operation have one exact logical result, even when its return Constraints describe only a range.
11. **No substitution by return type alone.** Two implementations satisfying the same incomplete
    Constraints are not interchangeable unless they implement the same exact pure mapping.

## Type Contracts And Validation

### Type Templates, Satisfaction, And Contract Validation

`it` in a type Constraint is a placeholder for the value being constrained, not an implicit
universal quantifier. For a particular unknown `it`, a goal such as `it < 7` is normally `Unproven`;
the existence of other values greater than seven does not refute that specific unknown value.
Standalone declaration validation over an explicitly arbitrary subject is a separate check.

#### NativeBitsValue Satisfies NativeBitsType

Given a concrete value and a required bits type:

```text
1. Require exact bit-length equality.
2. Instantiate each required Constraint template with the NativeBitsValue literal expression.
3. Confirm recursively that the resulting logical formulas are solver-ready.
4. Solve their conjunction using local simplification and contextual proof.
5. Proven means the value satisfies the refinement.
6. Disproven means it does not satisfy the refinement.
7. Unproven is a Constraint mismatch because satisfaction was not established.
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

#### NativeBitsType Satisfies NativeBitsType

Given a candidate type and required type:

```text
1. Require exact bit-length equality.
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

#### Type Declaration Validation

To validate a standalone type definition, instantiate its template with a fresh arbitrary symbolic
subject of the unrefined underlying type. Do not use the refined type object as a value and do not
assume the declaration's own constraint while proving its validity.

The arbitrary subject has careful semantics:

- proving its complete constraint false can establish that no value can inhabit the type;
- failing to prove the constraint true does not establish uninhabitability; and
- claiming universal vacuity requires proof that the constraint is always true.

Explicit quantification or equivalent treatment may be needed to preserve this arbitrary-subject
meaning in the final implementation.

#### Operator Return Contracts

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

Quantifier domains match the declared argument types. The required return Constraint must never be
used as evidence that the implementation satisfies itself. It must be established from separately
validated implementation behavior. Once validated, the return contract is available for downstream
reasoning.

Extensionality is not an optional relational return Constraint. Purity itself supplies the semantic
law that the same resolved operation with identical effective inputs returns the same exact logical
value. The solver still needs evidence that operation identities, bindings, captures, dispatch, and
inputs match. An explicit return Proposition remains useful for additional relationships that do not
follow from purity, and those relationships require ordinary validation without circular evidence.

Consider the following illustrative program:

```text
C := sin(0.5)
Theta :^^= a float read from stdin
R := sin(Theta)

if Theta = 0.5,
    print R
    print C
```

If the branch condition's validated equality establishes that `Theta` and `0.5` are identical
effective inputs to the same resolved pure `sin`, purity itself requires `R` and `C` to have the
same exact logical result. No special equality-in-return contract is needed. If `C` is evaluated
during compilation while `R` uses target code, both paths must implement the same exact `sin`
semantics. The compiler may reuse one result, specialize the branch, or use another equivalent
strategy; the source language guarantees no strategy.

The equality condition occurs after creation of `R`, but can still prove that an earlier invocation
had the same effective input. Contract and observation analysis therefore cannot be only local or
forward. It must discover later, path-sensitive uses and propagate their requirements backward.

### Declaration Diagnostics

A type-attached Constraint is intended to constrain its subject. Subject-independent facts belong
in contextual Propositions rather than incidental return refinements. Effects and mutations remain
modeled through Thyrym acts; proof knowledge applies to the specific resource versions identified
by their contracts rather than timeless mutable state.

Diagnostic policy:

- A provably uninhabitable complete type constraint is a compilation error.
- A provably vacuous type Constraint or redundant nested component is a warning.
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

### Standard Library Comparison Props

Intrinsic logical comparisons are distinct from ordinary user-defined `<` and `=` props. The
standard-library `<` operation is a normal executable operator. Its return type should relate the
returned bit to the intrinsic comparator without recursively calling the same `<` prop in its own
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

Signed props use the corresponding `sint` comparator. Floating-point comparison is defined in the
standard library from exact bit and integer foundations, with its behavior supplied by validated
contracts rather than an intrinsic floating comparator. Width alone does not identify a float
format: binary16 and bfloat16, for example, are both 16 bits with different layouts.

A return contract does not implement an operation. The runtime `Op` still requires a valid
implementation. The proof system reasons about established implementation properties without
confusing a native proposition with an executable boolean operation.

## Related documents

- [Proof system](proof-system.md)
- [Contract and equality rationale](../rationale/contracts-and-equality.md)
- [Unresolved proof design](../unresolved/proofs.md)
