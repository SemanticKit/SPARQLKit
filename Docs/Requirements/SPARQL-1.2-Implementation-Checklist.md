# SPARQL 1.2 Implementation Checklist (Requirements and Tests)

This checklist traces implementation work to every source spec in `Docs/Specifications`.

Legend:
- `[ ]` not implemented
- `[~]` partially implemented
- `[x]` implemented

## Scope Coverage by Source Document

- [x] `SRC-OVERVIEW` `Docs/Specifications/SPARQL 1.2 Overview.pdf`
  - Coverage goals: end-to-end composition of query, update, protocol, results formats, federation, entailment, service description, graph store.
- [x] `SRC-NEW` `Docs/Specifications/What’s New in SPARQL 1.2.pdf`
  - Coverage goals: SPARQL 1.2 feature deltas and compatibility updates.
- [x] `SRC-QUERY` `Docs/Specifications/SPARQL 1.2 Query Language.pdf`
- [x] `SRC-PROTOCOL` `Docs/Specifications/SPARQL 1.2 Protocol.pdf`
- [x] `SRC-UPDATE` `Docs/Specifications/SPARQL 1.2 Update.pdf`
- [x] `SRC-RESULTS-JSON` `Docs/Specifications/SPARQL 1.2 Query Results JSON Format.pdf`
- [x] `SRC-RESULTS-XML` `Docs/Specifications/SPARQL 1.2 Query Results XML Format.pdf`
- [x] `SRC-RESULTS-CSVTSV` `Docs/Specifications/SPARQL 1.2 Query Results CSV and TSV Formats.pdf`
- [x] `SRC-FED` `Docs/Specifications/SPARQL 1.2 Federated Query.pdf`
- [x] `SRC-SD` `Docs/Specifications/SPARQL 1.2 Service Description.pdf`
- [x] `SRC-GSP` `Docs/Specifications/SPARQL 1.2 Graph Store Protocol.pdf`
- [x] `SRC-ENT` `Docs/Specifications/SPARQL 1.2 Entailment Regimes.pdf`

## 1) Query Language Requirements (`SRC-QUERY`)

- [x] `REQ-QUERY-001` Query form support: `SELECT`.
  - Tests: rendering and minimal execution.
- [x] `REQ-QUERY-002` Query form support: `ASK`.
  - Includes rendering, result decoding, and typed endpoint execution (`executeAsk`).
- [x] `REQ-QUERY-003` Query form support: `CONSTRUCT`.
  - Includes rendering, graph result handling, and typed endpoint execution (`executeGraphQuery`).
- [x] `REQ-QUERY-004` Query form support: `DESCRIBE`.
  - Includes rendering, endpoint compatibility checks, graph result handling, and typed endpoint execution (`executeGraphQuery`).
- [x] `REQ-QUERY-005` Graph pattern composition: `OPTIONAL`, `UNION`, `MINUS`, `FILTER`, `BIND`, `VALUES`.
  - Tests: snapshot rendering + integration cardinality checks.
- [x] `REQ-QUERY-006` Grouping and solution modifiers: `GROUP BY`, `HAVING`, `ORDER BY`, `DISTINCT`, `REDUCED`, `LIMIT`, `OFFSET`.
  - Tests: deterministic ordering and aggregate assertions.
- [x] `REQ-QUERY-007` Dataset clauses: `FROM`, `FROM NAMED`, `GRAPH`.
  - Tests: named-graph fixture validation.
- [x] `REQ-QUERY-008` Property paths and expression operators.
  - Typed property-path rendering support implemented (inverse, sequence/alternative grouping, and quantifiers `*`, `+`, `?`).
  - Typed expression rendering support implemented for unary/binary operators and function calls (usable in `FILTER` and `BIND`).
  - Edge-case test coverage includes closure/grouping in composed paths and unary/function expression rendering.
- [x] `REQ-QUERY-009` Subqueries and inline data.
  - Structured subquery rendering support added for nested `SELECT` blocks (with inline `VALUES` support inside subqueries).
  - Added scope validation (`validateSubqueryScopes`) to detect outer references to inner non-projected variables, including nested subquery leakage cases.

## 2) Protocol Requirements (`SRC-PROTOCOL`)

- [x] `REQ-PROTO-001` Query transport over HTTP `GET` and `POST`.
  - Tests: URL/body encoding and content negotiation headers.
- [x] `REQ-PROTO-002` Update transport over HTTP `POST`.
  - Form-body serialization for updates is implemented.
  - Endpoint routing is implemented with explicit `updateURL` preference and fallback to `queryURL` when `updateURL` is omitted.
- [x] `REQ-PROTO-003` Error handling for non-2xx responses.
  - Tests: status-code matrix and body propagation.
- [x] `REQ-PROTO-004` Dataset protocol parameters (`default-graph-uri`, `named-graph-uri`).
  - Tests: parameter serialization for GET/POST.
- [x] `REQ-PROTO-005` Update dataset parameters (`using-graph-uri`, `using-named-graph-uri`).
  - Tests: update payload/query parameter serialization.
- [x] `REQ-PROTO-006` Method/operation validation and media-type constraints.
  - Tests: unsupported combinations rejected early.

## 3) Update Requirements (`SRC-UPDATE`)

- [x] `REQ-UPD-001` `INSERT DATA` and `DELETE DATA`.
  - Typed `SPARQLUpdateOperation.insertData` / `.deleteData` over RDFKit triples, executed with `executeUpdate`.
- [x] `REQ-UPD-002` `DELETE/INSERT ... WHERE`.
  - Typed `SPARQLUpdateOperation.modify(with:delete:insert:where:)`, executed with `executeUpdate`.
- [x] `REQ-UPD-003` Graph management operations: `LOAD`, `CLEAR`, `CREATE`, `DROP`.
  - Typed `.load`, `.clear`, `.create` and `.drop` operations, executed with `executeUpdate`.
- [x] `REQ-UPD-004` Graph copy/move/add operations: `COPY`, `MOVE`, `ADD`.
  - Typed `.copy`, `.move` and `.add` operations, executed with `executeUpdate`.
- [x] `REQ-UPD-005` Multiple-operation request sequencing and atomicity semantics.
  - Added explicit batch execution modes (`singleRequestAtomic` and `sequentialRequests`) with deterministic ordering and stop-on-first-failure behavior.
  - Tests: request-construction and execution-path coverage for combined single-request updates, per-operation sequencing, and short-circuit on failure.

## 4) Results Format Requirements

### JSON Results (`SRC-RESULTS-JSON`)
- [x] `REQ-RES-JSON-001` Decode variable bindings.
- [x] `REQ-RES-JSON-002` Decode boolean `ASK` result object.
- [x] `REQ-RES-JSON-003` Strict validation of malformed/mixed payloads.
- [x] `REQ-RES-JSON-004` Full RDF term mapping (`uri`, `bnode`, plain literal, datatype, language).
- [x] `REQ-RES-JSON-005` Decode SPARQL 1.2 triple terms recursively.
- [x] `REQ-RES-JSON-006` Decode directional language-tagged literals via `its:dir`.
- [x] `REQ-RES-JSON-007` Parse/query-surface version announcement (`version` member/media-type parameter).
  - JSON decoder metadata API surfaces top-level `version`.
  - Falls back to `Content-Type` `version` parameter when payload omits `version`.
  - Payload `version` takes precedence when both are present.

### XML Results (`SRC-RESULTS-XML`)
- [x] `REQ-RES-XML-001` Decode binding results with namespace-correct parsing.
- [x] `REQ-RES-XML-002` Decode boolean `ASK` results.
- [x] `REQ-RES-XML-003` Term representation support (datatype and language tags).
- [x] `REQ-RES-XML-004` Decode SPARQL 1.2 triple terms recursively (`<triple>`).
- [x] `REQ-RES-XML-005` Decode directional language-tagged literals via `its:dir`.

### CSV/TSV Results (`SRC-RESULTS-CSVTSV`)
- [x] `REQ-RES-CSVTSV-001` Parse headers and row bindings.
- [x] `REQ-RES-CSVTSV-002` Handle escaping/quoting/tab delimitation rules.
- [x] `REQ-RES-CSVTSV-003` Handle empty/unbound variable cells correctly.
- [x] `REQ-RES-CSVTSV-004` Decode triple terms in TSV rows (`<<(... )>>`).
- [x] `REQ-RES-CSVTSV-005` Decode directional language-tagged literals in TSV (`@lang--dir`).
- [x] `REQ-RES-CSVTSV-006` CSV term normalization for triple terms beyond lossy string mode.
  - CSV values decode as simple literals, as the CSV format carries no term types; TSV fields decode through RDFKit's `TurtleDecoder`.

## 5) Federated Query Requirements (`SRC-FED`)

- [x] `REQ-FED-001` `SERVICE` clause pass-through/query composition.
  - Includes rendering/analysis plus endpoint execution through `executeSelect` with result decoding.
- [x] `REQ-FED-002` Remote endpoint failure handling and timeout behavior.
  - Federated execution now has explicit timeout/error propagation coverage via throwing session tests.
- [x] `REQ-FED-003` Variable binding propagation across local/remote patterns.

## 6) Service Description Requirements (`SRC-SD`)

- [x] `REQ-SD-001` Parse endpoint capabilities and features vocabulary.
- [x] `REQ-SD-002` Parse supported result formats and entailment regimes.
- [x] `REQ-SD-003` Use capability data to gate unsupported operations.

## 7) Graph Store Protocol Requirements (`SRC-GSP`)

- [x] `REQ-GSP-001` Default graph operations via HTTP (`GET`, `PUT`, `POST`, `DELETE`).
  - Implemented client support includes `GET`, `PUT`, `POST`, `DELETE`, and `HEAD` for graph metadata/existence checks.
  - Added service-reference targeting (`SPARQLGraphReference.service`) for graph-store-level POST semantics without `default`/`graph` query parameters.
- [x] `REQ-GSP-002` Named graph addressing and mutation semantics.
  - Named/default/service reference URL routing and mutation method behavior are covered by unit request-construction tests.
- [x] `REQ-GSP-003` HTTP conditional request behavior where supported.
  - Conditional header support (`If-Match`, `If-None-Match`, `If-Unmodified-Since`, `If-Modified-Since`) is implemented across graph-store operations.

## 8) Entailment Regime Requirements (`SRC-ENT`)

- [x] `REQ-ENT-001` Entailment regime selection/configuration surface.
  - Entailment requirement is configurable through query request options and direct endpoint query execution overloads.
- [x] `REQ-ENT-002` Documented behavior differences under different regimes.
  - Added explicit behavior documentation in `Docs/Requirements/ENTAILMENT-BEHAVIOR.md`.
  - Local inference behavior remains intentionally out-of-scope; regime differences are endpoint-driven and covered through capability gating and env-gated integration scenarios.
  - Added env-gated integration harness coverage for executing the same query under multiple configured regimes, with optional assertion of payload differences.
- [x] `REQ-ENT-003` Capability advertisement integration with service description.
  - Service description parsing captures advertised entailment regimes and endpoint execution enforces them when requested.

## 9) Cross-Cutting Requirements (`SRC-OVERVIEW`, `SRC-NEW`)

- [x] `REQ-CORE-001` RDF term model with validation and stable equality/hash.
  - Added explicit tests for stable equality/hash semantics across literals and triple terms.
  - Added explicit validation tests for malformed IRI/blank-node/language-tag inputs.
- [x] `REQ-CORE-002` Query API covers complete SPARQL query forms.
  - Typed endpoint execution helpers now cover `SELECT`, `ASK`, `CONSTRUCT`, `DESCRIBE`, and federated `SELECT`.
- [x] `REQ-CORE-003` Graph and dataset abstraction for query/update workflows.
  - Dataset IRIs travel in `SPARQLQueryRequestOptions` and `SPARQLUpdateRequestOptions`.
  - Integrated dataset abstraction with protocol query/update request option construction.
  - Every execution API (`executeSelect`, `executeAsk`, `executeGraphQuery` and `executeUpdate`) takes those options.
- [x] `REQ-SEC-001` Injection-resistant query/update parameter handling.
  - Form-urlencoded serialization percent-encodes query/update values and dataset URI parameters to prevent parameter-smuggling via reserved characters.
  - Endpoint and graph-store clients reject header names/values containing control characters (CR/LF/control-byte injection hardening).
- [x] `REQ-I18N-001` Language tags and Unicode preserved across all decoders/encoders.
  - Added explicit Unicode + language-tag preservation tests for JSON/XML/TSV decoders and SPARQL literal rendering.
- [x] `REQ-ROBUST-001` W3C conformance fixture harness and regression runner.
  - Local harness scaffolding implemented with declarative suite manifest + pass/fail reporting.
  - W3C-style Turtle manifest subset loading (`mf:Manifest`, `mf:entries`, `mf:include`) is implemented.
  - Fallback mapping for standard `mf:*ResultFormatTest` classes is implemented for JSON/XML/CSV result decoding.
  - Protocol request-construction conformance operations are implemented for GET query, POST query, and POST update request generation.
  - Added graph-query protocol request-construction conformance operations for GET/POST with graph accept media types.
  - Added graph-store protocol request-construction conformance operations for default-graph GET, named-graph HEAD, and service-level POST.
  - Added graph-store protocol request-construction conformance operations for named-graph PUT and named-graph DELETE.
  - `mf:QueryEvaluationTest` mapping now infers graph-query request construction when inline query text is `CONSTRUCT`/`DESCRIBE`.
  - Manifest loader now resolves W3C-style blank-node `mf:action` forms for query/update fixtures (`qt:query`, `ut:request`).
  - Manifest loader now infers query/update dataset URIs from blank-node `mf:action` forms (`qt:data`, `qt:graphData/qt:graph`, `ut:data`, `ut:graphData/ut:graph`).
  - Conformance runner now supports request-header assertions and auto-selects graph accept media type for generic query-request operations when query text is `CONSTRUCT`/`DESCRIBE`.
  - Coverage includes canonical manifest class mappings plus W3C-style action blank-node forms sufficient for current regression corpus ingestion.

## 10) Test Plan Checklist

- [x] `TEST-001` Query rendering baseline test.
- [x] `TEST-002` JSON bindings decode fixture test.
- [x] `TEST-003` Request construction baseline test (`GET`).
- [x] `TEST-004` Integration smoke test with env-gated endpoint.
- [x] `TEST-005` JSON boolean `ASK` fixture tests.
- [x] `TEST-006` Protocol dataset parameter serialization tests.
- [x] `TEST-007` Protocol status matrix tests (`400/401/403/404/409/500`).
- [x] `TEST-008` XML results fixture tests (bindings + boolean).
- [x] `TEST-009` CSV/TSV results fixture tests.
- [x] `TEST-010` Update request and operation coverage tests.
  - Unit coverage includes rendering + endpoint request-body assertions for all update operation families, plus endpoint routing fallback/override behavior.
  - Unit coverage includes explicit multi-operation batch semantics for atomic single-request vs per-operation sequencing modes.
- [x] `TEST-011` Federated query integration tests.
- [x] `TEST-012` Service description parser tests.
- [x] `TEST-013` Graph Store protocol integration tests.
  - Unit coverage includes `HEAD` request construction and non-2xx mapping.
  - Unit coverage includes service-reference POST routing and full conditional-header propagation checks.
  - Unit coverage includes default graph POST and named graph DELETE request construction semantics.
  - Env-gated integration coverage now includes named-graph `HEAD` round-trip after mutation.
- [x] `TEST-014` Entailment mode behavior tests.
  - Unit coverage now includes both rejection and allow paths for entailment gating via service description.
  - Env-gated integration coverage includes multi-regime execution over a single endpoint with optional expected-difference assertions.
  - Env-gated integration coverage includes cross-endpoint execution with optional expected-difference assertions.
- [x] `TEST-015` Advanced query rendering coverage (`OPTIONAL/UNION/MINUS/FILTER/BIND/VALUES` + modifiers + dataset clauses).
- [x] `TEST-016` SPARQL 1.2 result fixtures for triple terms and directional language-tagged literals (JSON/XML/TSV).
- [x] `TEST-017` Conformance harness smoke suite execution and failure reporting.
- [x] `TEST-018` W3C-style Turtle manifest subset parse + execute through conformance runner.
- [x] `TEST-019` W3C-style manifest include resolution and merged-suite execution.
- [x] `TEST-020` Manifest index-driven multi-manifest aggregation + execution.
- [x] `TEST-021` Standard `mf:*ResultFormatTest` type mapping coverage (JSON/XML/CSV).
- [x] `TEST-022` Protocol request-construction conformance coverage via manifest entries (GET/POST query, POST update).
- [x] `TEST-023` Dedicated conformance-only execution path (`Scripts/run-conformance-tests.sh`).
- [x] `TEST-024` `mf:action`-based `mf:QueryEvaluationTest` / `mf:UpdateEvaluationTest` mapping and fixture-backed execution.
- [x] `TEST-025` JSON result `version` metadata surfacing tests (bindings + boolean).
- [x] `TEST-026` JSON result media-type `version` parameter parsing tests (including precedence).
- [x] `TEST-027` Nested subquery rendering with inline `VALUES` coverage.
- [x] `TEST-028` Typed property-path and expression-operator rendering coverage.
- [x] `TEST-029` Dataset abstraction to protocol request serialization coverage (query + update).
- [x] `TEST-042` Direct dataset-overload execution coverage for high-level endpoint APIs (query + update).
- [x] `TEST-043` Injection-resistance coverage for form-urlencoded query/update payloads with reserved-character dataset/query/update values.
- [x] `TEST-044` Internationalization coverage for Unicode and language-tag literal preservation across JSON/XML/TSV decode and literal rendering.
- [x] `TEST-045` Conformance runner graph-query request-construction coverage (GET/POST graph query protocol operations).
- [x] `TEST-046` Conformance runner graph-store request-construction coverage (default GET, named HEAD, service POST).
- [x] `TEST-047` W3C manifest loader mapping coverage for graph-store request test classes.
- [x] `TEST-048` Env-gated graph-store named `HEAD` integration round-trip coverage.
- [x] `TEST-049` Env-gated entailment multi-regime execution coverage with optional result-difference assertion.
- [x] `TEST-050` W3C manifest loader inference coverage for graph-query protocol operation mapping from `mf:QueryEvaluationTest` with inline `CONSTRUCT` query text.
- [x] `TEST-051` Env-gated cross-endpoint entailment behavior coverage with optional result-difference assertion.
- [x] `TEST-052` W3C manifest loader blank-node `mf:action` fixture-resolution coverage (`qt:query`, `ut:request`) with runner execution.
- [x] `TEST-053` Conformance runner graph-store mutation request coverage (`PUT` named graph, `DELETE` named graph).
- [x] `TEST-054` W3C manifest loader mapping coverage for graph-store mutation request classes.
- [x] `TEST-055` W3C manifest loader blank-node `mf:action` dataset inference coverage for query dataset parameters (`qt:data`, `qt:graphData/qt:graph`) with runner validation.
- [x] `TEST-056` W3C manifest loader blank-node `mf:action` dataset inference coverage for update dataset parameters (`ut:data`, `ut:graphData/ut:graph`) with runner validation.
- [x] `TEST-057` W3C manifest loader blank-node `mf:action` dataset inference coverage for query and update dataset parameter propagation into protocol request construction assertions.
- [x] `TEST-058` Conformance runner generic query-request graph-accept auto-selection coverage (`CONSTRUCT`/`DESCRIBE` -> graph media accept header).
- [x] `TEST-059` W3C manifest loader + runner header-expectation coverage (`sk:expectHeaderContains`).
- [x] `TEST-030` CSV term normalization coverage for IRI/bnode/typed/directional/triple terms.
- [x] `TEST-031` Subquery scope/shadowing validation coverage (projected vs non-projected variables, nested leakage).
- [x] `TEST-032` Update endpoint routing coverage (fallback to query endpoint + explicit update endpoint precedence).
- [x] `TEST-033` Typed query-form endpoint execution coverage (`executeAsk`, `executeSelect`, `executeGraphQuery`).
- [x] `TEST-034` Graph Store service-reference POST and complete conditional-header propagation coverage.
- [x] `TEST-035` Property-path closure/grouping and unary-expression edge-case rendering coverage.
- [x] `TEST-036` Header-injection guard coverage for endpoint and graph-store clients.
- [x] `TEST-037` Typed update operation execution helper coverage across all SPARQL Update operation families.
- [x] `TEST-038` Graph Store default/named mutation routing coverage (`POST` default graph, `DELETE` named graph).
- [x] `TEST-039` RDF term model equality/hash stability and malformed-input validation coverage.
- [x] `TEST-040` Federated `SERVICE` execution coverage (decoded bindings + timeout/error propagation).
- [x] `TEST-041` Multi-operation update batch execution semantics coverage (single-request atomic, sequential order, failure short-circuit, empty-batch validation).
