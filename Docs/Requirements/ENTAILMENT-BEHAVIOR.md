# Entailment Behavior (Current Implementation)

This document clarifies what SPARQLKit currently does for entailment regimes.

## Current behavior

- SPARQLKit does not perform local entailment/inference over query results.
- `SPARQLQueryRequestOptions.requiredEntailmentRegime` is used as a client-side requirement gate. It is typed by the translated `sd:EntailmentRegime` protocol, `ServiceDescription.EntailmentRegime`, and its values are the translated regimes of the `EntailmentRegimes` module (such as `EntailmentRegimes.RDFS`), compared with `===`.
- If a service description (the translated `sd:Service`, `any ServiceDescription.Service`, as `SPARQLServiceDescriptionDecoder` decodes it) is provided:
  - query execution is rejected when the requested entailment regime is not advertised (`sd:defaultEntailmentRegime`, or the `sd:entailmentRegime` of a named graph of its default dataset or available graphs).
  - query execution proceeds when the requested entailment regime is advertised.
- If no service description is provided:
  - SPARQLKit does not block execution based on entailment regime.
  - the endpoint remains responsible for actual entailment semantics.

## Practical consequence

Behavior differences across entailment regimes currently come from endpoint capabilities and endpoint execution semantics, not from local reasoning in SPARQLKit.

## Future work

- Add explicit API support for attaching entailment requirement metadata to requests beyond capability checks.
- Add integration fixtures covering multiple endpoints/regimes to validate observable result differences.
