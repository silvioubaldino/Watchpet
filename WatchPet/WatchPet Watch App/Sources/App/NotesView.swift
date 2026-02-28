import WatchPetShared
import SwiftUI

struct NotesView: View {
    @EnvironmentObject var container: WatchAppContainer
    @State private var notes: [Note] = []
    
    var body: some View {
        List {
            if notes.isEmpty {
                Text("Nenhuma nota salva ainda. Fale com seu pet para anotar algo!")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
            } else {
                ForEach(notes) { note in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(note.rawText)
                            .font(.body)
                            .lineLimit(3)
                        
                        HStack {
                            if let category = note.category {
                                Text(category)
                                    .font(.system(size: 10))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.3))
                                    .cornerRadius(4)
                            }
                            
                            Spacer()
                            
                            Text(note.createdAt, style: .date)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            if note.isSynced {
                                Image(systemName: "checkmark.icloud.fill")
                                    .font(.caption2)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Notas")
        .onAppear {
            fetchNotes()
        }
    }
    
    private func fetchNotes() {
        Task {
            do {
                notes = try await container.fetchNotes.executeForAll()
            } catch {
                print("Failed to fetch notes: \(error)")
            }
        }
    }
}

#Preview {
    NotesView()
        .environmentObject(WatchAppContainer.preview)
}
