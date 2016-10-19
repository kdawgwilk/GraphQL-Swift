import PackageDescription

let package = Package(
    name: "GraphQL",
    targets: [
        Target(name: "Spec", dependencies: [.Target(name: "GraphQL")]),
    ],
    dependencies: [
        .Package(url: "https://github.com/Quick/Quick.git", majorVersion: 0, minor: 10),
        // Core extensions, type-aliases, and functions that facilitate common tasks
        .Package(url: "https://github.com/vapor/core.git", majorVersion: 1)
    ]
)
