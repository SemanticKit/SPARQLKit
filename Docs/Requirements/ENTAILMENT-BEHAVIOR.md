# Entailment Behavior (Current Implementation)

This document clarifies what SPARQLKit currently does for entailment regimes.

## Current behavior

- SPARQLKit does not perform local entailment/inference over query results.
- `SPARQLQueryRequestOptions.requiredEntailmentRegime` is used as a client-side requirement gate.
- If a `SPARQLServiceDescription` is provided:
  - query execution is rejected when the requested entailment regime is not advertised.
  - query execution proceeds when the requested entailment regime is advertised.
- If no `SPARQLServiceDescription` is provided:
  - SPARQLKit does not block execution based on entailment regime.
  - the endpoint remains responsible for actual entailment semantics.

## Practical consequence

Behavior differences across entailment regimes currently come from endpoint capabilities and endpoint execution semantics, not from local reasoning in SPARQLKit.

## Future work

- Add explicit API support for attaching entailment requirement metadata to requests beyond capability checks.
- Add integration fixtures covering multiple endpoints/regimes to validate observable result differences.
