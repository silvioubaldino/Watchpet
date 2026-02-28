# 🐾 WatchPet

**Seu Companheiro Inteligente no Pulso**

> AyD v2.0 — Fase 0: Setup do Projeto

---

## Estrutura de Targets

```
WatchPet/
├── WatchPet_iOS/          # Companion app iPhone
│   └── Sources/
│       ├── App/           # Entry point, AppDelegate
│       ├── Features/
│       │   ├── Onboarding/
│       │   ├── Settings/
│       │   └── Integrations/
│       ├── Core/
│       │   ├── DI/        # Dependency injection container
│       │   └── Navigation/
│       └── DesignSystem/
│           ├── Components/
│           └── Tokens/
│
├── WatchPet_Watch/        # Apple Watch app
│   └── Sources/
│       ├── App/           # Entry point WatchApp
│       ├── Features/
│       │   ├── Voice/     # Pipeline de transcrição
│       │   ├── Pet/       # Avatar + Emotional Engine
│       │   ├── Reminders/ # Lembretes reativos e proativos
│       │   ├── Timers/    # Timer / Cronômetro / Pomodoro
│       │   ├── Notes/     # Bloco de notas por voz
│       │   └── Habits/    # Dashboard e check-ins
│       └── Core/
│           ├── DI/
│           └── Navigation/
│
└── Shared/                # Framework compartilhado
    └── Sources/
        ├── Domain/
        │   ├── Entities/  # Modelos de domínio puros
        │   ├── UseCases/  # Regras de negócio
        │   └── Repositories/ # Interfaces/Protocols
        ├── Data/
        │   ├── CoreData/  # Stack + NSManagedObjects
        │   └── Repositories/ # Implementações
        ├── Infrastructure/
        │   ├── Speech/    # SFSpeechRecognizer wrapper
        │   ├── LLM/       # CoreML model wrapper
        │   └── Haptics/   # WKHapticType helpers
        └── Integration/
            ├── Protocol/  # ConnectorProtocol
            ├── Registry/  # IntegrationRegistry
            ├── SyncQueue/ # Fila persistida
            ├── OAuth/     # OAuthManager
            └── Connectors/ # NotionConnector, GCalConnector...
```

## Requisitos

- Xcode 15.2+
- watchOS 10.0+ (Apple Watch Series 9 / Ultra 2 / SE 2ª gen)
- iOS 17.0+
- Swift 5.9+

## Fases de Desenvolvimento

| Fase | Descrição | Duração |
|------|-----------|---------|
| 0 | Setup, CI/CD, Design System, Avatar | 2 sem |
| 1 | MVP: Voz, Intenção, Lembretes, Timers, Pet | 6 sem |
| 2 | Notas, Memória, Sincronização iPhone | 4 sem |
| 3 | Proatividade, HealthKit | 3 sem |
| 4 | Integration Layer (Notion, GCal) | 5 sem |
| 5 | Personalidades, Dashboard, Polish | 4 sem |
| 6 | LLM Generativo, App Store | 4 sem |
