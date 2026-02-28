// swift-tools-version: 5.9
// MARK: - WatchPet Shared Framework
// Framework compartilhado entre WatchPet_Watch e WatchPet_iOS.
// No Xcode: adicionar como Swift Package local ou framework target.

import PackageDescription

let package = Package(
    name: "WatchPetShared",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10),
    ],
    products: [
        .library(
            name: "WatchPetShared",
            targets: ["WatchPetShared"]
        ),
    ],
    targets: [
        .target(
            name: "WatchPetShared",
            path: "Shared/Sources",
            resources: [
                .process("Data/CoreData/WatchPet.xcdatamodel")
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "WatchPetSharedTests",
            dependencies: ["WatchPetShared"],
            path: "Tests"
        ),
    ]
)
