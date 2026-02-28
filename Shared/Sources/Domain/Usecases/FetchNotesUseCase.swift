// MARK: - FetchNotesUseCase
// (AyD v2.0, Seção 3.1 - Phase 2)
// Lê as notas gravadas localmente.

import Foundation

public final class FetchNotesUseCase {

    private let noteRepository: NoteRepository

    public init(noteRepository: NoteRepository) {
        self.noteRepository = noteRepository
    }

    public func executeForAll() async throws -> [Note] {
        try await noteRepository.fetchAll()
    }
    
    public func executeForToday() async throws -> [Note] {
        try await noteRepository.fetchByDate(Date())
    }
    
    public func executeSearch(query: String) async throws -> [Note] {
        try await noteRepository.search(query: query)
    }
}
