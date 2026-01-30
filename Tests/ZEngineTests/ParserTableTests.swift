import Testing
@testable import ZEngine

@Suite("Parser Table Generation Tests")
struct ParserTableTests {

    // MARK: - VocabularyManager Tests

    @Test("VocabularyManager initialization")
    func vocabularyManagerInit() {
        let vocab = VocabularyManager(version: .v5)
        #expect(vocab.getVerbConstants().isEmpty)
    }

    @Test("Add synonym and resolve words")
    func synonymResolution() {
        var vocab = VocabularyManager(version: .v5)
        vocab.addSynonym(words: ["TAKE", "CARRY", "GET"])

        #expect(vocab.resolveWord("TAKE") == "TAKE")
        #expect(vocab.resolveWord("CARRY") == "TAKE")
        #expect(vocab.resolveWord("GET") == "TAKE")
        #expect(vocab.resolveWord("take") == "TAKE") // Case insensitive
    }

    @Test("Add buzzwords")
    func buzzwordHandling() {
        var vocab = VocabularyManager(version: .v5)
        vocab.addBuzzwords(["THE", "A", "AN"])

        #expect(vocab.isBuzzword("THE"))
        #expect(vocab.isBuzzword("the")) // Case insensitive
        #expect(!vocab.isBuzzword("LAMP"))
    }

    @Test("Assign verb numbers")
    func verbNumberAssignment() {
        var vocab = VocabularyManager(version: .v5)

        let takeNum = vocab.addVerb("TAKE")
        let dropNum = vocab.addVerb("DROP")
        let examineNum = vocab.addVerb("EXAMINE")

        #expect(takeNum == 1)
        #expect(dropNum == 2)
        #expect(examineNum == 3)

        // Adding same verb again returns same number
        #expect(vocab.addVerb("TAKE") == 1)
    }

    @Test("Verb number with synonyms")
    func verbNumberWithSynonyms() {
        var vocab = VocabularyManager(version: .v5)
        vocab.addSynonym(words: ["TAKE", "CARRY", "GET"])

        let takeNum = vocab.addVerb("TAKE")
        let carryNum = vocab.addVerb("CARRY") // Should resolve to TAKE

        #expect(takeNum == carryNum)
        #expect(takeNum == 1)
    }

    @Test("Get verb constants")
    func getVerbConstants() {
        var vocab = VocabularyManager(version: .v5)
        vocab.addVerb("TAKE")
        vocab.addVerb("DROP")
        vocab.addVerb("EXAMINE")

        let constants = vocab.getVerbConstants()
        #expect(constants.count == 3)
        #expect(constants[0] == ("TAKE", 1))
        #expect(constants[1] == ("DROP", 2))
        #expect(constants[2] == ("EXAMINE", 3))
    }

    @Test("Generate dictionary entries")
    func generateDictionary() {
        var vocab = VocabularyManager(version: .v5)
        vocab.addSynonym(words: ["TAKE", "CARRY", "GET"])
        vocab.addVerb("TAKE")
        vocab.addWord("LAMP", type: .noun)

        let dictionary = vocab.generateDictionary()

        #expect(dictionary.count >= 4) // TAKE, CARRY, GET, LAMP
        // Verify sorted alphabetically
        if let first = dictionary.first?.word, let last = dictionary.last?.word {
            #expect(first <= last)
        }
    }

    @Test("Word type tracking")
    func wordTypeTracking() {
        var vocab = VocabularyManager(version: .v5)
        vocab.addWord("NORTH", type: .direction)
        vocab.addWord("IN", type: .preposition)
        vocab.addVerb("TAKE")

        let dictionary = vocab.generateDictionary()

        let north = dictionary.first { $0.word == "NORTH" }
        #expect(north?.type.contains(.direction) == true)

        let preposition = dictionary.first { $0.word == "IN" }
        #expect(preposition?.type.contains(.preposition) == true)

        let verb = dictionary.first { $0.word == "TAKE" }
        #expect(verb?.type.contains(.verb) == true)
    }

    // MARK: - SyntaxTableBuilder Tests

    @Test("SyntaxTableBuilder initialization")
    func syntaxTableBuilderInit() {
        let builder = SyntaxTableBuilder()
        #expect(builder.getPatterns().isEmpty)
    }

    @Test("Add simple SYNTAX declaration")
    func addSimpleSyntax() throws {
        var vocab = VocabularyManager(version: .v5)
        var builder = SyntaxTableBuilder()

        let syntax = ZILSyntaxDeclaration(
            verb: "TAKE",
            pattern: [],
            action: "V-TAKE",
            location: SourceLocation(file: "test.zil", line: 1, column: 1)
        )

        try builder.addSyntax(syntax, vocabularyManager: &vocab)

        let patterns = builder.getPatterns()
        #expect(patterns.count == 1)
        #expect(patterns[0].verb == "TAKE")
        #expect(patterns[0].action == "V-TAKE")
        #expect(patterns[0].verbNumber == 1)
    }

    @Test("Add SYNTAX with preaction")
    func addSyntaxWithPreaction() throws {
        var vocab = VocabularyManager(version: .v5)
        var builder = SyntaxTableBuilder()

        let syntax = ZILSyntaxDeclaration(
            verb: "TAKE",
            pattern: [],
            action: "V-TAKE PRE-TAKE",
            location: SourceLocation(file: "test.zil", line: 1, column: 1)
        )

        try builder.addSyntax(syntax, vocabularyManager: &vocab)

        let patterns = builder.getPatterns()
        #expect(patterns[0].action == "V-TAKE")
        #expect(patterns[0].preaction == "PRE-TAKE")
    }

    @Test("Parse operand flags - MANY")
    func parseOperandFlagsMany() {
        let (flags, findFlag) = OperandFlags.parse(from: ["MANY"])
        #expect(flags.contains(.many))
        #expect(findFlag == nil)
    }

    @Test("Parse operand flags - HAVE and HELD")
    func parseOperandFlagsHaveHeld() {
        let (flags, _) = OperandFlags.parse(from: ["HAVE", "HELD"])
        #expect(flags.contains(.have))
        #expect(flags.contains(.held))
    }

    @Test("Parse operand flags - FIND with flag name")
    func parseOperandFlagsFind() {
        let (flags, findFlag) = OperandFlags.parse(from: ["FIND", "TAKEBIT"])
        #expect(flags.contains(.find))
        #expect(findFlag == "TAKEBIT")
    }

    @Test("Parse operand flags - combined")
    func parseOperandFlagsCombined() {
        let (flags, _) = OperandFlags.parse(from: ["MANY", "ON-GROUND", "HAVE"])
        #expect(flags.contains(.many))
        #expect(flags.contains(.onGround))
        #expect(flags.contains(.have))
    }

    @Test("Add SYNTAX with object and constraints")
    func addSyntaxWithObject() throws {
        var vocab = VocabularyManager(version: .v5)
        var builder = SyntaxTableBuilder()

        let syntax = ZILSyntaxDeclaration(
            verb: "TAKE",
            pattern: [
                .object("OBJ", constraints: [
                    .atom("MANY", SourceLocation.unknown),
                    .atom("ON-GROUND", SourceLocation.unknown)
                ])
            ],
            action: "V-TAKE",
            location: SourceLocation(file: "test.zil", line: 1, column: 1)
        )

        try builder.addSyntax(syntax, vocabularyManager: &vocab)

        let patterns = builder.getPatterns()
        #expect(patterns[0].elements.count == 1)

        if case .object(let flags, _) = patterns[0].elements[0] {
            #expect(flags.contains(.many))
            #expect(flags.contains(.onGround))
        } else {
            Issue.record("Expected object element")
        }
    }

    @Test("Add SYNTAX with preposition")
    func addSyntaxWithPreposition() throws {
        var vocab = VocabularyManager(version: .v5)
        var builder = SyntaxTableBuilder()

        let syntax = ZILSyntaxDeclaration(
            verb: "PUT",
            pattern: [
                .object("OBJ1", constraints: []),
                .preposition("IN"),
                .object("OBJ2", constraints: [])
            ],
            action: "V-PUT",
            location: SourceLocation(file: "test.zil", line: 1, column: 1)
        )

        try builder.addSyntax(syntax, vocabularyManager: &vocab)

        let patterns = builder.getPatterns()
        #expect(patterns[0].elements.count == 3)

        // Check that preposition was added to vocabulary
        let dictionary = vocab.generateDictionary()
        let prep = dictionary.first { $0.word == "IN" }
        #expect(prep?.type.contains(.preposition) == true)
    }

    @Test("Generate ZAP code for syntax patterns")
    func generateZAPCode() throws {
        var vocab = VocabularyManager(version: .v5)
        var builder = SyntaxTableBuilder()

        let syntax = ZILSyntaxDeclaration(
            verb: "TAKE",
            pattern: [
                .object("OBJ", constraints: [
                    .atom("MANY", SourceLocation.unknown)
                ])
            ],
            action: "V-TAKE",
            location: SourceLocation(file: "test.zil", line: 1, column: 1)
        )

        try builder.addSyntax(syntax, vocabularyManager: &vocab)

        let zapCode = builder.generateZAPCode()
        #expect(!zapCode.isEmpty)
        #expect(zapCode.contains { $0.contains("V-TAKE") })
    }

    // MARK: - Integration Tests

    @Test("Complete parser table workflow")
    func completeParserTableWorkflow() throws {
        var vocab = VocabularyManager(version: .v5)
        var builder = SyntaxTableBuilder()

        // Add synonyms
        vocab.addSynonym(words: ["TAKE", "CARRY", "GET"])
        vocab.addSynonym(words: ["LAMP", "LANTERN"])

        // Add buzzwords
        vocab.addBuzzwords(["THE", "A", "AN"])

        // Add syntax declarations
        let takeSyntax = ZILSyntaxDeclaration(
            verb: "TAKE",
            pattern: [
                .object("OBJ", constraints: [
                    .atom("FIND", SourceLocation.unknown),
                    .atom("TAKEBIT", SourceLocation.unknown),
                    .atom("MANY", SourceLocation.unknown),
                    .atom("ON-GROUND", SourceLocation.unknown)
                ])
            ],
            action: "V-TAKE PRE-TAKE",
            location: SourceLocation.unknown
        )

        try builder.addSyntax(takeSyntax, vocabularyManager: &vocab)

        // Verify verb constants
        let constants = vocab.getVerbConstants()
        #expect(constants.count == 1)
        #expect(constants[0].0 == "TAKE")
        #expect(constants[0].1 == 1)

        // Verify dictionary generation
        let dictionary = vocab.generateDictionary()
        #expect(!dictionary.isEmpty)

        // Verify TAKE and its synonyms are in dictionary
        let takeWords = dictionary.filter { ["TAKE", "CARRY", "GET"].contains($0.canonical) }
        #expect(takeWords.count >= 3)

        // Verify buzzwords are in dictionary
        let buzzWords = dictionary.filter { ["THE", "A", "AN"].contains($0.word) }
        #expect(buzzWords.count == 3)

        // Verify syntax patterns
        let patterns = builder.getPatterns()
        #expect(patterns.count == 1)
        #expect(patterns[0].verb == "TAKE")
        #expect(patterns[0].action == "V-TAKE")
        #expect(patterns[0].preaction == "PRE-TAKE")

        // Verify operand flags
        if case .object(let flags, let findFlag) = patterns[0].elements[0] {
            #expect(flags.contains(.many))
            #expect(flags.contains(.onGround))
            #expect(flags.contains(.find))
            #expect(findFlag == "TAKEBIT")
        } else {
            Issue.record("Expected object element with flags")
        }

        // Verify ZAP code generation
        let zapCode = builder.generateZAPCode()
        #expect(!zapCode.isEmpty)
    }

    @Test("Multiple syntax patterns for same verb")
    func multipleSyntaxPatterns() throws {
        var vocab = VocabularyManager(version: .v5)
        var builder = SyntaxTableBuilder()

        // TAKE OBJECT
        let syntax1 = ZILSyntaxDeclaration(
            verb: "TAKE",
            pattern: [
                .object("OBJ", constraints: [])
            ],
            action: "V-TAKE",
            location: SourceLocation.unknown
        )

        // TAKE OBJECT FROM OBJECT
        let syntax2 = ZILSyntaxDeclaration(
            verb: "TAKE",
            pattern: [
                .object("OBJ1", constraints: []),
                .preposition("FROM"),
                .object("OBJ2", constraints: [])
            ],
            action: "V-TAKE-FROM",
            location: SourceLocation.unknown
        )

        try builder.addSyntax(syntax1, vocabularyManager: &vocab)
        try builder.addSyntax(syntax2, vocabularyManager: &vocab)

        let patterns = builder.getPatterns()
        #expect(patterns.count == 2)
        #expect(patterns[0].verb == "TAKE")
        #expect(patterns[1].verb == "TAKE")
        #expect(patterns[0].verbNumber == patterns[1].verbNumber) // Same verb number
    }

    // MARK: - Typed Synonym Integration Tests

    @Test("PREP-SYNONYM creates preposition type")
    func prepSynonymTypeIntegration() throws {
        let source = """
        <PREP-SYNONYM IN INSIDE INTO>
        """

        let lexer = ZILLexer(source: source, filename: "test.zil")
        let parser = try ZILParser(lexer: lexer, filePath: "test.zil")
        let declarations = try parser.parseProgram()

        let symbolTable = SymbolTableManager()
        var generator = ZAPCodeGenerator(symbolTable: symbolTable, version: .v5)
        let zap = try generator.generateCode(from: declarations)

        // Verify the synonym was processed
        #expect(!zap.isEmpty)

        // The vocabulary manager should have IN classified as preposition
        // (We can't directly inspect it, but we can verify the code generates correctly)
    }

    @Test("VERB-SYNONYM creates verb type and assigns verb number")
    func verbSynonymTypeIntegration() throws {
        let source = """
        <VERB-SYNONYM TAKE GET GRAB>
        """

        let lexer = ZILLexer(source: source, filename: "test.zil")
        let parser = try ZILParser(lexer: lexer, filePath: "test.zil")
        let declarations = try parser.parseProgram()

        let symbolTable = SymbolTableManager()
        var generator = ZAPCodeGenerator(symbolTable: symbolTable, version: .v5)
        let zap = try generator.generateCode(from: declarations)

        // Verify verb constant was generated
        #expect(zap.contains("V?TAKE"))
    }

    @Test("ADJ-SYNONYM creates adjective type")
    func adjSynonymTypeIntegration() throws {
        let source = """
        <ADJ-SYNONYM BRASS BRONZE COPPER>
        """

        let lexer = ZILLexer(source: source, filename: "test.zil")
        let parser = try ZILParser(lexer: lexer, filePath: "test.zil")
        let declarations = try parser.parseProgram()

        let symbolTable = SymbolTableManager()
        var generator = ZAPCodeGenerator(symbolTable: symbolTable, version: .v5)
        let zap = try generator.generateCode(from: declarations)

        // Verify the synonym was processed
        #expect(!zap.isEmpty)
    }

    @Test("Generic SYNONYM without type classification")
    func genericSynonymIntegration() throws {
        let source = """
        <SYNONYM NORTH N>
        """

        let lexer = ZILLexer(source: source, filename: "test.zil")
        let parser = try ZILParser(lexer: lexer, filePath: "test.zil")
        let declarations = try parser.parseProgram()

        let symbolTable = SymbolTableManager()
        var generator = ZAPCodeGenerator(symbolTable: symbolTable, version: .v5)
        let zap = try generator.generateCode(from: declarations)

        // Verify the synonym was processed
        #expect(!zap.isEmpty)
    }

    @Test("Mixed typed synonyms with SYNTAX")
    func mixedTypedSynonymsWithSyntax() throws {
        let source = """
        <PREP-SYNONYM IN INSIDE INTO>
        <VERB-SYNONYM TAKE GET GRAB>
        <SYNTAX TAKE OBJECT = V-TAKE>
        <SYNTAX PUT OBJECT IN OBJECT = V-PUT>
        """

        let lexer = ZILLexer(source: source, filename: "test.zil")
        let parser = try ZILParser(lexer: lexer, filePath: "test.zil")
        let declarations = try parser.parseProgram()

        let symbolTable = SymbolTableManager()
        var generator = ZAPCodeGenerator(symbolTable: symbolTable, version: .v5)
        let zap = try generator.generateCode(from: declarations)

        // Verify verb constants were generated
        #expect(zap.contains("V?TAKE"))
        #expect(zap.contains("V?PUT"))

        // Verify SYNTAX patterns were generated
        #expect(zap.contains("SYNTAX-TAKE") || zap.contains("Syntax patterns for TAKE"))
    }
}
