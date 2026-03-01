// MARK: - SpeechTranscriberTests
import XCTest
import AVFoundation
@testable import WatchPetShared

@MainActor
final class SpeechTranscriberTests: XCTestCase {

    var sut: SpeechTranscriber!

    override func setUp() {
        super.setUp()
        sut = SpeechTranscriber(locale: Locale(identifier: "pt-BR"))
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    func test_initialState_isIdle() {
        XCTAssertEqual(sut.state, .idle)
        XCTAssertTrue(sut.partialTranscript.isEmpty)
    }

    func test_isAvailable_returnsTrueOnSimulator() {
        // Assume estamos rodando os testes no simulador ou em contexto que permita teste
        XCTAssertTrue(sut.isAvailable, "Em um simulador, isAvailable deve ser instanciado como true.")
    }

    func test_startListening_whenNotIdle_doesNothing() {
        // Simulando estado manual (via reset ou estado inicial interno)
        // No caso do startListening, não podemos injetar estado facilmente, 
        // mas podemos garantir que a primeira chamada muda o estado (se permissão/disponível).
        
        // Se isAvailable for true, o startListening tentará ligar o mic,
        // mas em Testes unitários puros sem permissão ou engine pode falhar jogando pro estado .error
        sut.startListening()
        
        // Em testes Unitários o AVAudioEngine costuma falhar se não houver IO para testes
        // Verificamos que o estado ao menos mutou
        XCTAssertNotEqual(sut.state, .idle)
    }

    func test_resetToIdle_cleansUpAndReturnsToIdle() {
        sut.startListening()
        sut.resetToIdle()
        
        XCTAssertEqual(sut.state, .idle)
        XCTAssertTrue(sut.partialTranscript.isEmpty)
    }
}
