# Conformance Runner

Use this command to run only manifest-driven conformance tests:

```bash
./Scripts/run-conformance-tests.sh
```

This executes:
- `SPARQLConformanceHarnessTests`
- `SPARQLW3CManifestLoaderTests`

Use full package tests separately when needed:

```bash
swift test
```
