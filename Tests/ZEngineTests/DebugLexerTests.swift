import Testing
@testable import ZEngine

@Suite("Debug Lexer Tests")
struct DebugLexerTests {

    @Test("Tokenize RTRUE")
    func tokenizeRTRUE() throws {
        let source = "<RTRUE>"
        let lexer = ZILLexer(source: source, filename: "debug.zil")
        var tokens: [ZILToken] = []

        repeat {
            let token = try lexer.nextToken()
            tokens.append(token)
        } while !tokens.last!.type.isEOF

        // Print tokens for debugging
        for token in tokens {
            print("Token: \(token.type) value: '\(token.value)' at \(token.location)")
        }

        #expect(tokens.count == 4) // < RTRUE > EOF
        #expect(tokens[0].type == .leftAngle)
        if case .atom(let name) = tokens[1].type {
            #expect(name == "RTRUE")
        } else {
            #expect(Bool(false), "Second token should be RTRUE atom")
        }
        #expect(tokens[2].type == .rightAngle)
        #expect(tokens[3].type.isEOF)
    }

    @Test("Tokenize simple routine")
    func tokenizeSimpleRoutine() throws {
        let source = "<ROUTINE TEST () <RTRUE>>"
        let lexer = ZILLexer(source: source, filename: "debug.zil")
        var tokens: [ZILToken] = []

        repeat {
            let token = try lexer.nextToken()
            tokens.append(token)
        } while !tokens.last!.type.isEOF

        // Print tokens for debugging
        for (index, token) in tokens.enumerated() {
            print("Token \(index): \(token.type) value: '\(token.value)' at \(token.location)")
        }

        // Should have: < ROUTINE TEST ( ) < RTRUE > > EOF
        #expect(tokens.count == 10)
    }
}

extension TokenType {
    var isEOF: Bool {
        switch self {
        case .endOfFile:
            return true
        default:
            return false
        }
    }
}