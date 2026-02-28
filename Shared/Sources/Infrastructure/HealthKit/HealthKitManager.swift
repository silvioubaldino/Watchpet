// MARK: - HealthKitManager
// (AyD v2.0, Seção 3.1 - Phase 3)
// Gerencia permissões e escritas no HealthKit (Água, etc).

import Foundation
import HealthKit

public final class HealthKitManager {
    
    public static let shared = HealthKitManager()
    
    private let healthStore = HKHealthStore()
    
    public var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }
    
    // Tipos de dados que queremos ler/escrever
    private var waterType: HKQuantityType? {
        HKQuantityType.quantityType(forIdentifier: .dietaryWater)
    }
    
    public func requestAuthorization() async throws -> Bool {
        guard isAvailable, let water = waterType else { return false }
        
        let typesToShare: Set = [water]
        let typesToRead: Set = [water]
        
        try await healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead)
        return true
    }
    
    /// Adiciona registro de água consumida (ml)
    public func logWater(ml: Double) async throws {
        guard isAvailable, let water = waterType else {
            throw NSError(domain: "HealthKitManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "HealthKit indisponível ou tipo não suportado"])
        }
        
        let quantity = HKQuantity(unit: HKUnit.literUnit(with: .milli), doubleValue: ml)
        let sample = HKQuantitySample(type: water, quantity: quantity, start: Date(), end: Date())
        
        try await healthStore.save(sample)
    }
}
