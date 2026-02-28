// MARK: - PersistenceController
// Stack CoreData compartilhado entre Watch e iPhone.
// Usa CloudKit opcional para sincronização iCloud gratuita (AyD v2.0, Seção 4.2).

import CoreData
import Foundation

public final class PersistenceController {

    public static let shared = PersistenceController()

    /// Container para uso em previews/testes — in-memory, sem persistência em disco.
    public static let preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        controller.loadSampleData()
        return controller
    }()

    public let container: NSPersistentContainer

    public var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    /// Background context para operações pesadas (imports, sync).
    public func newBackgroundContext() -> NSManagedObjectContext {
        let ctx = container.newBackgroundContext()
        ctx.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return ctx
    }

    public init(inMemory: Bool = false) {
        let modelURL = Bundle.module.url(forResource: "WatchPet", withExtension: "mom")!
        let model = NSManagedObjectModel(contentsOf: modelURL)!
        
        container = NSPersistentContainer(name: "WatchPet", managedObjectModel: model)

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }

        container.loadPersistentStores { _, error in
            if let error {
                // Em produção: reportar via crash analytics, não usar fatalError
                fatalError("CoreData falhou ao carregar: \(error.localizedDescription)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    // MARK: - Save Helper

    public func save(context: NSManagedObjectContext? = nil) {
        let ctx = context ?? viewContext
        guard ctx.hasChanges else { return }
        do {
            try ctx.save()
        } catch {
            print("⚠️ CoreData save error: \(error)")
        }
    }

    // MARK: - Sample Data (Preview)

    private func loadSampleData() {
        let ctx = viewContext

        // Notas de exemplo
        let note1 = CDNote(context: ctx)
        note1.id = UUID()
        note1.rawText = "Reunião amanhã às 14h com o time de design"
        note1.createdAt = Date()
        note1.updatedAt = Date()
        note1.category = "trabalho"
        note1.tags = ["reunião", "design"]
        note1.isSynced = false

        let note2 = CDNote(context: ctx)
        note2.id = UUID()
        note2.rawText = "Comprar proteína depois do treino"
        note2.createdAt = Date().addingTimeInterval(-3600)
        note2.updatedAt = Date().addingTimeInterval(-3600)
        note2.category = "saúde"
        note2.tags = ["compras"]
        note2.isSynced = false

        // Lembretes de exemplo
        let reminder1 = CDReminder(context: ctx)
        reminder1.id = UUID()
        reminder1.title = "Beber água"
        reminder1.triggerDate = Date().addingTimeInterval(1800)
        reminder1.repeatInterval = 3600
        reminder1.isProactive = true

        let reminder2 = CDReminder(context: ctx)
        reminder2.id = UUID()
        reminder2.title = "Remédio das 8h"
        reminder2.triggerDate = Calendar.current.date(
            bySettingHour: 8, minute: 0, second: 0, of: Date()
        ) ?? Date()
        reminder2.isProactive = false

        save(context: ctx)
    }
}
