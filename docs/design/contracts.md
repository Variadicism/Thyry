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

Invariants may also mention ordinary Beng operations:

```text
sin(it) (float64 <) 7
```

Such an assertion may be provable when the context contains established laws that provide a
sufficient bound for `sin(it)`. The invocation is a symbolic expression in the proposition; the
proposition itself is not an executable operation.

More generally, every typeable value has a complete statically assigned type, including applicable
constraints and props. Implementations must satisfy that contract. The compiler may choose how and
where to evaluate pure expressions, and may erase implementation distinctions only when every
semantic observation still conforms to the complete source contract.

The central division of responsibility is:

> The static type describes what a value promises. Observation analysis describes what generated
> code must make distinguishable to semantic observers. Properly designated diagnostic
> instrumentation may inspect a selected implementation without becoming a semantic observer.

The final sentence is conditional on a diagnostic facility whose classification is not yet
designed. General unsafe effects cannot automatically receive diagnostic treatment.

## Terminology And Status

- A **static type** is the authoritative source-language type, including all relevant invariant
  constraints, props, and behavioral relationships. Optimization never weakens it.
- An **invariant** is a proposition in the [invariant
  language](proof-system.md#invariant-language). It may be part of a type contract or established
  contextual knowledge.
- An operation's **contract** states the allowed result and relationships to arguments and other
  values. A pure Beng function or prop implementation must prove its declared result contract. A
  foreign declaration is a trusted contract and is an explicit soundness boundary.
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
- The complete static contract remains authoritative even when no runtime check or observer exists.
- The evaluation stage and machine are intentionally unspecified for pure computations. Compilation
  on a host, execution on a target, interpretation, and another valid strategy are implementation
  choices rather than source-language properties.
- Generated code must preserve source-level relationships, path conditions, effects, public
  interfaces, and other semantic observations, not necessarily every physical intermediate bit
  pattern from one possible evaluation strategy.
- Observation requirements propagate backward through all uses. A later branch or act can constrain
  an earlier materialization.
- Exact equality and approximate equivalence are different relations. Approximate equivalence must
  not be used for transitive substitution as though it were exact equality.
- Code may explicitly introduce an unproven assertion only with conspicuous `assuming` syntax.
- No intentionally uninhabitable or never-type facility is being designed here. A type proven to
  have no possible values is an error.
- Anything representable in Beng code should generally be a `Thing`. Internal solver patterns and
  proof machinery need not be source-representable.
- The architecture should be mathematically sound and extensible. This plan does not attempt to
  enumerate every theorem-proving strategy or native decision case before implementation.

## Portable Operation Contracts

### Built-In, Source, And Foreign Implementations

Native comparisons, fixed-width arithmetic, division, transcendental functions, and other
operations need explicit contracts. The proof engine may directly decide concrete expressions when
their selected semantics permit it, such as unsigned comparison of two concrete integers. It may
also reason symbolically through normalization and established contextual rules. This does not
permit arbitrary symbolic applications to be replaced by native execution.

Standard-library operations may use foreign functions and native representations. In discussions
of these declarations, `uint*` denotes the family of unsigned integer types such as `uint8_t` and
`uint32_t`; it does not denote a C pointer. Different platforms may provide different foreign
implementations so long as each conforms to the declaration's contract. A suitable source-language
implementation may be used when no native implementation exists; absence of an FFI implementation
does not inherently require compilation to fail.

A pure source implementation must establish its return contract without circularly assuming that
same contract. A foreign declaration's author asserts that its implementation satisfies the
contract; the compiler does not independently prove foreign machine code correct. Reviewed shared
foreign libraries should be preferred because an incorrect declaration makes the program's proof
foundation unsound.

Contracts for integers and floats must explicitly address widths, overflow, signed arithmetic,
division edge cases, NaN, infinities, signed zero, rounding modes, and permitted fast-math behavior.
The design must not silently inherit undefined or implementation-defined C behavior.

### Contract Compatibility Across Host And Target

Pure evaluation performed by the compiler need not produce bits identical to evaluation on the
target. For an illustrative result contract:

```text
a float where it = 0.5 ± 0.000001
```

a host result of `0.4999999` and a target result of `0.5000001` may each satisfy their individual
bounds. Overlapping bounds do not make the values exactly equal, however, and individual validity is
insufficient when a relational contract requires two results to agree. Generated behavior must
satisfy all individual and relational obligations together.

This contract-compatible model avoids requiring identical math-library, CPU, OS, and host-compiler
floating-point bits. It does not give the compiler permission to expose contradictory ordinary
results within one program. It may choose different valid results when compiling programs whose
semantic observations differ, but only within the full contracts of each program.

### Compile-Time Execution Versus Exact Compile-Time Knowledge

Executing an expression during compilation is not the same as proving that every valid
implementation produces one exact value. Compile-time syntax construction, such as producing a
string that is substituted into operator syntax, requires a string proven equal to one exact value.
Portable exact integer and string operations may establish that fact. Merely obtaining one
floating-point approximation on the host does not.

Approximate computation at compilation remains permitted for other purposes when the resulting
program is contract-compatible. If constraints do not establish one exact syntax string, syntax
substitution must not proceed as though the host result supplied a proof.

### Equality Relations

The language needs a true equality relation suitable for substitution and transitive reasoning, and
a distinct approximate-equivalence relation with explicit error bounds. The spelling `~=` is only
illustrative here. Approximate equality is generally not transitive and must never silently replace
exact equality.

These relations must also remain distinct from representation identity and IEEE numerical
comparison. In examples imported from the Thyrym discussion, bare `=` means exact semantic equality;
it must not be confused with the planned `(bits =)` comparator or with `(float64 =)`, under which
NaN is not reflexive and signed zeros compare numerically equal. The exact source grammar and the
contexts in which each relation permits substitution remain open.

## Contract And Optimization Guardrails

1. **No circular evidence.** A function's return annotation cannot establish its own extensional or
   numerical contract. Use a separately checked implementation proof or a trusted FFI declaration.
2. **No approximate substitution.** Overlapping error intervals and approximate equivalence do not
   imply exact equality or authorize transitive replacement.
3. **No stage-dependent semantics.** Host compile-time and target runtime evaluation are
   implementation choices unless a separate source feature explicitly says otherwise.
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

## Type Contracts And Validation

### Type Templates, Satisfaction, And Contract Validation

#### NativeBitsValue Satisfies NativeBitsType

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

#### NativeBitsType Satisfies NativeBitsType

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

Quantifier domains match the declared argument types. The required return invariant must never be
used as evidence that the implementation satisfies itself. It must be established from separately
validated implementation behavior. Once validated, the return contract is available for downstream
reasoning.

A relational return contract can also state extensionality. In illustrative Thyrym notation, where
`Theta` is the argument and `it` is the result of this invocation:

```text
a float where
    for all Other Theta, a float,
        if Theta = Other Theta,
            it = sin(Other Theta)
```

The constrained result is `it`, not another occurrence of `sin(Theta)`. Exact binders and layout
must be reconciled with the final grammar. Like every return contract, this assertion needs evidence
from a validated pure implementation or a trusted foreign declaration and cannot prove itself.

Consider the following illustrative program:

```text
C := sin(0.5)
Theta :^^= a float read from stdin
R := sin(Theta)

if Theta = 0.5,
    print R
    print C
```

Within the branch, a validated extensional contract requires `R = C` at the abstract source level.
That remains true if `C` was evaluated on the compilation host and `R` would otherwise use a target
library. The compiler may reuse one result, specialize the branch, select compatible
implementations, or use another valid strategy; the source language guarantees no strategy.

The equality condition occurs after creation of `R`, but can still impose an obligation on how `R`
and `C` are materialized. Contract and observation analysis therefore cannot be only local or
forward. It must discover later, path-sensitive uses and propagate their requirements backward.

### Declaration Diagnostics

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

### Standard Library Comparison Props

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

## Related documents

- [Proof system](proof-system.md)
- [Contract and equality rationale](../rationale/contracts-and-equality.md)
- [Unresolved proof design](../unresolved/proofs.md)
