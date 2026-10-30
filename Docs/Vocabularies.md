# Vocabularies

SPARQLKit's vocabularies are RDF in, Swift out. Each target below holds the
RDF documents of one vocabulary; RDFKit's `RDFTranslatorPlugin` translates
them into the Swift they describe on every build, the way RDFKit's FOAF and
AliceProfile fixtures are built. The classes become Swift protocols and
classes, the properties typed accessors, and the individuals (the formats,
the entailment regimes, the languages and features of a service) module-level
instances of their classes, compared with `===`. No vocabulary is declared in
Swift, and no Swift declaration states an IRI.

| Target | Built on | What it is |
|---|---|---|
| `FOAF` | RDF, OWL | FOAF, which the format and entailment documents describe their author in |
| `Formats` | FOAF, RDF, OWL | Unique URIs for File Formats: `Formats.Format` and its 23 formats |
| `ServiceDescription` | Formats, RDF, OWL | SPARQL 1.2 Service Description: `sd:Service`, `sd:EntailmentRegime`, the languages and features |
| `EntailmentRegimes` | ServiceDescription, FOAF, RDF, OWL | Unique URIs for Semantic Web Entailment Regimes, each regime an `sd:EntailmentRegime` |
| `TestManifest`, `TestQuery`, `TestUpdate` | RDF, OWL | The W3C test manifest, query test and update test vocabularies |
| `SPARQLConformance` | TestManifest, TestQuery, TestUpdate, RDF, OWL | SPARQLKit's own conformance vocabulary |

## Sources

Each document is stored as its source served it, except where the table says
otherwise. Retrieved 2026-10-30 with curl.

| File | Source | sha256 |
|---|---|---|
| `Sources/FOAF/index.rdf` | <http://xmlns.com/foaf/spec/index.rdf>, the same bytes as RDFKit's `Tests/ParallelTests/Fixtures/FOAF/index.rdf` | `3d859b5d92a2c3d041545d014fa826f682ca06d056af8c7b31e32d930abf2bc5` |
| `Sources/Formats/Overview.ttl` | <https://www.w3.org/ns/formats/Overview.ttl> | `21d9e292f8b869aef4fe8e1419389e7dc1939d121d391d0102743d7b680fc493` |
| `Sources/Formats/<Format>.ttl` | `https://www.w3.org/ns/formats/<Format>` with `Accept: text/turtle` (303 to `https://www.w3.org/ns/formats/data/<Format>`), for each of the 23 formats `formats:Format rdfs:seeAlso` lists | see below |
| `Sources/ServiceDescription/sparql-service-description.ttl` | <http://www.w3.org/ns/sparql-service-description> with `Accept: text/turtle` | `a4e4ab035c909d4aeb140ab5807a3b49dfa0ecee587dc9109214ecfaff712878` |
| `Sources/EntailmentRegimes/Entailment.ttl` | <http://www.w3.org/ns/entailment/> with `Accept: text/turtle` | `41c3bebb8c02002d415f5ee533eff06ace387f0cbbd285594a71aafed44ea1ed` |
| `Sources/EntailmentRegimes/<Regime>.ttl` | `https://www.w3.org/ns/entailment/<Regime>` with `Accept: text/turtle`, for each regime `ent:Entailment rdfs:seeAlso` lists | see below |
| `Sources/EntailmentRegimes/sparql12-entailment-regimes.ttl` | Written for SPARQLKit: each regime SPARQL 1.2 Entailment Regimes defines (§2, §4 to §8.1) is the object of `sd:defaultEntailmentRegime` or `sd:entailmentRegime` (§1.4), whose range is `sd:EntailmentRegime` | `375b0df057de3b7f59c0a88ed5d99e3baaecf148af44bf472456e45095866227` |
| `Sources/TestManifest/test-manifest.ttl` | [`ns/test-manifest.ttl`](https://github.com/w3c/rdf-tests/blob/d01b141c65ddf8e5b615256f264111118bdb2134/ns/test-manifest.ttl) in github.com/w3c/rdf-tests at commit d01b141 | `15a589845733591309c5b88b4db62f03e86d444da448b6c0d6f31ba6953dbf94` |
| `Sources/TestQuery/test-query.ttl` | [`ns/test-query.ttl`](https://github.com/w3c/rdf-tests/blob/d01b141c65ddf8e5b615256f264111118bdb2134/ns/test-query.ttl) at the same commit | `dea66e1291db1651e27c4bf788a540d3b72c585e1f1422fdb957f7aa53354baa` |
| `Sources/TestUpdate/test-update.ttl` | [`ns/test-update.ttl`](https://github.com/w3c/rdf-tests/blob/d01b141c65ddf8e5b615256f264111118bdb2134/ns/test-update.ttl) at the same commit | `d561938401910276ef4ff1da224b56decbf1c63ca416ee939ed84b8aaa027c1f` |
| `Sources/SPARQLConformance/conformance.ttl` | Written for SPARQLKit: its manifests' test classes and expectations, and `mf:CSVResultFormatTest`, which the W3C CSV and TSV results suite uses and test-manifest.ttl does not declare | `a1f86ac290ea180aeb6ae5e8ed65411025d595a653695669f39931d999ad05d2` |

`https://www.w3.org/ns/formats/OWL_Manchester` is served the OWL Functional
Syntax document; `OWL_Manchester.ttl` is
<https://www.w3.org/ns/formats/data/OWL_Manchester.ttl>, which describes
`formats:OWL_Manchester`.

`SPARQL_Results_XML.ttl` as served (sha256
`6d2cd3b1d24e5e6d957e8adfed33a6846431c0cbff948f3855723a3abc7d2ab3`) is not
Turtle: line 22 writes `dc:title` and the document declares no `dc:` prefix
(RDF 1.2 Turtle §6.3: a prefixed name's prefix must be declared). The stored
document writes `dcterms:title` there, the term the RDF/XML representation of
the same document gives that triple; no other byte differs.

`OWL-RDF-Based.ttl` describes `ent:OWL-RDF-based`, with a lower-case `b`,
while SPARQL 1.2 Entailment Regimes §6 and `Entailment.ttl` name the regime
`ent:OWL-RDF-Based`. Both are translated as the documents give them; the
regime is `EntailmentRegimes.OWL-RDF-Based`.

`RDF.ttl` (sha256
`bf045cb94cbe9abff486bf6194a2029d658676cd6eed07c5e45b4b10f9db2ba6`) is stored
but excluded from its target, and `ent:RDF` is not yet stated an
`sd:EntailmentRegime`: RDFTranslator would name the individual `RDF`, a
module-level name that hides the RDF module the generated Swift refers to.

| Format document | sha256 |
|---|---|
| `JSON-LD.ttl` | `1616ed496599a14ded84e41105737cdaaddfaf8674255556f7a42dd5671efc59` |
| `LD_Patch.ttl` | `792e6b30d8fd2c4f9aafe16c455035fc3f27f79d43bb0088f2938ad7f97d697c` |
| `N-Quads.ttl` | `caefe369ceaed88b5154468827a92593ee5e86a66ea7a23ee6712f2e446e7fb5` |
| `N-Triples.ttl` | `1dfc7cd3ccf635d42e64ca827fc5e4ec7940085c6565fe8b9d5e4960e2f5e833` |
| `N3.ttl` | `6a326dbc99c17ec76fa2a8941a55d3fedc2ec89d0b570f55978459f30626ccae` |
| `OWL_Functional.ttl` | `2e9dcdb88eb60cc9e445f5d5b50cdcdea8948608d0932d015bacc970cee797f9` |
| `OWL_Manchester.ttl` | `394bf85331fe04570ebed47a1423b77a591da03bf02f839a2b819fd532b7a76d` |
| `OWL_XML.ttl` | `90d19e22436007a39f2de2d820aeba482f8a46ac62a96d46c80a60f613900342` |
| `POWDER-S.ttl` | `cd3f4f2508627b61173c59335ee5d2889d3620ecaf42c2d76628c4bdbc473378` |
| `POWDER.ttl` | `29c42fd201bfdb3636309a9199750a3cac2118b3d4ba1f401be76f23632b8677` |
| `PROV-N.ttl` | `2ddeb16540eb7056c44b56282bd177dabd7a5600f9f629081e0bffd6a08944f6` |
| `PROV-XML.ttl` | `f6cc6060eb9dd389756eb0fed9c34abc7c95f62a2e8853317c02cf9e375ee60a` |
| `RDF_JSON.ttl` | `1f199dafc24a83c95d35e08071ff49a0969ae07b48c71c00858927171e0d2be8` |
| `RDF_XML.ttl` | `53d9f0e412cdf93b493f6487402b8bc1ba17867757e0cee962e3922250182049` |
| `RDFa.ttl` | `9659749022fb1210675a5571ce1d1482f006a58cdb5e03474e1410fbcc405f51` |
| `RIF_XML.ttl` | `38939077fd01d54a191490b43eb41d89ac3f01c46cdd17e6059b0f41e565dcad` |
| `SPARQL_Results_CSV.ttl` | `7a05b3a3dcce9a8e1f55b5a3bd9f15471d933a4031c9bdb8eac3c2840d570a0f` |
| `SPARQL_Results_JSON.ttl` | `213f8082db96c03f84a8b53dbc7a804562711d3244982f7bcdf7c9fb25fa5f27` |
| `SPARQL_Results_TSV.ttl` | `4fc406c47438741a50c8e4d50a785b1cffdcbe5e4ea19115c4d2759012c54683` |
| `SPARQL_Results_XML.ttl` | `163338b8f3d0780369c676c94e1b204fc3443bcdbb426eb789d4614011deeb4f` |
| `TriG.ttl` | `32b26f60bad366de27955b4fd20f345f3b6f98cc9425b1ccc282208d2dbcbbde` |
| `Turtle.ttl` | `e383e38f7393bff007f9ebdabe0029c58b8ecc08850bd5fba26a0d23475e67b7` |
| `microdata.ttl` | `6569d82ec5b2036e4327859909b665731f26efea3e7eaa2c548e490f4d925737` |

| Regime document | sha256 |
|---|---|
| `D.ttl` | `bcd380e13016ed47e0e3c1d7e6720c083dbaac68580998c21e785a6257b81944` |
| `OWL-Direct.ttl` | `30863a8cf7a2f12f67576dd66a5c66b6f08ed3eb30d02547126a60a8596e6cec` |
| `OWL-RDF-Based.ttl` | `f0fb3e126a1a85854b2ae11574ddf738751d723502efd830220f9b287f73f914` |
| `RDF.ttl` | `bf045cb94cbe9abff486bf6194a2029d658676cd6eed07c5e45b4b10f9db2ba6` |
| `RDFS.ttl` | `1336bdeb92344cefd69d71cd22645fd453ee356b6c467debe9bea76873adcee3` |
| `RIF.ttl` | `93dda586f701b8bb5c9eec62a939e2da7d64eeba6d4f49e0d43811b68f232175` |
| `Simple.ttl` | `fd24b286f6ffa65254004d5b86a18c1b2bc86eceaac5a6ed79b596db97191914` |

Check them with:

    cd Sources
    shasum -a 256 */*.ttl FOAF/index.rdf
