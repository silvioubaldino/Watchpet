# 🛠️ Setup do Projeto Xcode — WatchPet Fase 0

## 1. Criar o projeto no Xcode

```
File → New → Project → watchOS → Watch App
```

Configurações:
- Product Name: `WatchPet`
- Bundle Identifier: `com.seudominio.WatchPet`
- Team: sua Apple Developer Team
- ✅ Include Companion iPhone App
- Interface: SwiftUI
- Language: Swift
- ✅ Include Tests

---

## 2. Targets criados automaticamente

| Target | Bundle ID | OS |
|--------|-----------|-----|
| `WatchPet` | `com.seudominio.WatchPet` | iOS 17.0+ |
| `WatchPet Watch App` | `com.seudominio.WatchPet.watchkitapp` | watchOS 10.0+ |

---

## 3. Adicionar o Shared Framework

### Opção A: Swift Package local (recomendado)

1. File → Add Package Dependencies → Add Local...
2. Selecione a pasta raiz do projeto (onde está o `Package.swift`)
3. Adicione `WatchPetShared` em ambos os targets

### Opção B: Framework target no mesmo projeto

1. File → New → Target → Framework
2. Name: `WatchPetShared`
3. Em cada target, Build Phases → Link Binary → adicionar `WatchPetShared.framework`

---

## 4. Adicionar arquivos aos targets

| Arquivo | Target Watch | Target iOS |
|---------|:---:|:---:|
| `Shared/Sources/**/*.swift` | ✅ | ✅ |
| `WatchPet_Watch/Sources/**/*.swift` | ✅ | ❌ |
| `WatchPet_iOS/Sources/**/*.swift` | ❌ | ✅ |

---

## 5. Info.plist — Permissões

### Watch (WatchPet Watch App/Info.plist)

```xml
<key>NSMicrophoneUsageDescription</key>
<string>O WatchPet usa o microfone para ouvir seus comandos de voz.</string>

<key>NSSpeechRecognitionUsageDescription</key>
<string>O WatchPet transcreve seus comandos de voz para entender suas intenções.</string>
```

### iPhone (WatchPet/Info.plist)

```xml
<key>NSMicrophoneUsageDescription</key>
<string>O WatchPet usa o microfone para ouvir seus comandos de voz.</string>

<key>NSSpeechRecognitionUsageDescription</key>
<string>O WatchPet transcreve seus comandos de voz para entender suas intenções.</string>

<key>NSHealthShareUsageDescription</key>
<string>O WatchPet lê dados de saúde para check-ins de hidratação e atividade.</string>

<key>NSHealthUpdateUsageDescription</key>
<string>O WatchPet registra check-ins de hidratação no HealthKit.</string>
```

---

## 6. Entitlements

### Watch App.entitlements
```xml
<key>com.apple.security.network.client</key>
<true/>
<key>com.apple.developer.healthkit</key>
<true/>
```

### iOS App.entitlements
```xml
<key>com.apple.security.network.client</key>
<true/>
<key>com.apple.developer.healthkit</key>
<true/>
<key>com.apple.developer.authentication-services.autofill-credential-provider</key>
<true/>
```

---

## 7. Background Modes (iOS target)

Em Signing & Capabilities → + Capability → Background Modes:
- ✅ Background fetch
- ✅ Remote notifications (para BGProcessingTask do SyncEngine)

---

## 8. Build Settings recomendados

| Setting | Valor |
|---------|-------|
| Swift Language Version | Swift 5.9 |
| Deployment Target Watch | watchOS 10.0 |
| Deployment Target iOS | iOS 17.0 |
| SWIFT_STRICT_CONCURRENCY | targeted |

---

## 9. Substituir Mocks por implementações reais

Nos arquivos de App Entry Point, substituir:

```swift
// Antes (Fase 0 — preview/mock)
WatchAppContainer.preview

// Depois (Fase 1+)
WatchAppContainer(
    noteRepository: CoreDataNoteRepository(context: persistenceController.viewContext),
    reminderRepository: CoreDataReminderRepository(context: persistenceController.viewContext),
    // ...
)
```

---

## 10. Checklist Fase 0

- [ ] Projeto Xcode criado com targets Watch + iOS
- [ ] Shared framework configurado e buildando
- [ ] Permissões de microfone e speech recognition no Info.plist
- [ ] `WatchConnectivityBridge` ativo em ambos os targets
- [ ] Previews do avatar do pet funcionando no Simulator
- [ ] CI/CD configurado (GitHub Actions ou Xcode Cloud)
- [ ] Design tokens definidos (cores, tipografia, espaçamentos)
- [ ] Prototipagem do avatar em 3 estados (happy, thinking, celebrating)
