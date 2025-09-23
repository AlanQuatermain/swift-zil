import Testing
@testable import ZEngine

@Suite("ZEngine Tests")
struct ZEngineTests {
    @Test("ZEngine module imports correctly")
    func zengineModuleImport() throws {
        // Just test that we can access types from the ZEngine module
        let location = SourceLocation.unknown
        #expect(location.file == "<unknown>")
    }
}