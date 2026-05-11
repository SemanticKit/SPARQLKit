import Testing
@testable import SPARQLKit

@Test
func updateRequestRendersCoreOperations() {
    let update = SPARQLUpdateRequest(
        operations: [
            .insertData(triples: ["<s> <p> <o> ."]),
            .deleteData(triples: ["<s> <p> <o> ."]),
            .deleteInsertWhere(
                delete: ["?s <old> ?o ."],
                insert: ["?s <new> ?o ."],
                wherePatterns: ["?s <old> ?o ."]
            )
        ]
    )

    let rendered = update.render()

    #expect(rendered.contains("INSERT DATA"))
    #expect(rendered.contains("DELETE DATA"))
    #expect(rendered.contains("WHERE {"))
}

@Test
func updateRequestRendersGraphManagementOperations() {
    let update = SPARQLUpdateRequest(
        operations: [
            .load(source: "http://example.org/source", intoGraph: "http://example.org/g"),
            .clear(target: .named("http://example.org/g"), silent: true),
            .create(graph: "http://example.org/new", silent: false),
            .drop(target: .default, silent: false),
            .copy(from: "http://example.org/a", to: "http://example.org/b", silent: false),
            .move(from: "http://example.org/a", to: "http://example.org/b", silent: true),
            .add(from: "http://example.org/a", to: "http://example.org/b", silent: false)
        ]
    )

    let rendered = update.render()

    #expect(rendered.contains("LOAD <http://example.org/source> INTO GRAPH <http://example.org/g>"))
    #expect(rendered.contains("CLEAR SILENT GRAPH <http://example.org/g>"))
    #expect(rendered.contains("CREATE GRAPH <http://example.org/new>"))
    #expect(rendered.contains("DROP DEFAULT"))
    #expect(rendered.contains("COPY GRAPH <http://example.org/a> TO GRAPH <http://example.org/b>"))
    #expect(rendered.contains("MOVE SILENT GRAPH <http://example.org/a> TO GRAPH <http://example.org/b>"))
    #expect(rendered.contains("ADD GRAPH <http://example.org/a> TO GRAPH <http://example.org/b>"))
}
