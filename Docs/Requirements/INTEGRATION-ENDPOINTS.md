# Integration Test Endpoints

This file tracks known SPARQL endpoints used for `SPARQLKitIntegrationTests`.

## Verified query endpoints

- `https://dbpedia.org/sparql`
- `https://data.getty.edu/media/sparql`

## Environment variable mapping

Set these before running:

```bash
export SPARQL_ENDPOINT_URL="https://dbpedia.org/sparql"
export SPARQL_UPDATE_ENDPOINT_URL="<update-endpoint-url>"
export SPARQL_GRAPH_STORE_URL="<graph-store-url>"
export SPARQL_FEDERATED_ENDPOINT_URL="<federated-query-endpoint-url>"
export SPARQL_TEST_GRAPH_IRI="http://example.org/sparqlkit/test-graph"
```

Entailment integration options:

```bash
export SPARQL_TEST_ENTAILMENT_REGIMES="http://www.w3.org/ns/entailment/Simple,http://www.w3.org/ns/entailment/RDFS"
export SPARQL_EXPECT_ENTAILMENT_DIFFERENCE="0"
export SPARQL_ENTAILMENT_ENDPOINT_A_URL="<endpoint-a-url>"
export SPARQL_ENTAILMENT_ENDPOINT_B_URL="<endpoint-b-url>"
export SPARQL_EXPECT_CROSS_ENDPOINT_ENTAILMENT_DIFFERENCE="0"
```

Federation optional strict checks:

```bash
export SPARQL_FEDERATED_ASSERT_BINDINGS="0"
export SPARQL_FEDERATED_SUBJECT_IRI="<known-subject-iri>"
```

With `SPARQL_FEDERATED_ASSERT_BINDINGS=1`, the subject must have a triple in
the federated endpoint's default graph, because the test's `SERVICE` pattern
matches the default graph.

## Local endpoint

[Oxigraph](https://github.com/oxigraph/oxigraph) serves every endpoint the
suite needs. Start it, then seed the federated subject:

```bash
oxigraph serve --location /tmp/oxigraph --bind 127.0.0.1:7878
curl -X POST http://127.0.0.1:7878/update --data-urlencode \
  'update=INSERT DATA { <http://example.org/sparqlkit/integration/sequence> <http://example.org/p> "seed" }'
```

Point `SPARQL_ENDPOINT_URL` and `SPARQL_FEDERATED_ENDPOINT_URL` at
`http://127.0.0.1:7878/query`, `SPARQL_UPDATE_ENDPOINT_URL` at `/update` and
`SPARQL_GRAPH_STORE_URL` at `/store`.

## Run command

```bash
swift test --filter SPARQLKitIntegrationTests
```
