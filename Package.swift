// swift-tools-version: 6.0
import PackageDescription

let package = Package(name: "hetzner-dyndns-cgi",
                      platforms: [
                          .macOS(.v13),
                      ],
                      products: [
                          .executable(name: "hetzner-dyndns",
                                      targets: ["HetznerDynDNS"]),
                      ],
                      dependencies: [
                          .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.21.0"),
                      ],
                      targets: [
                          .executableTarget(name: "HetznerDynDNS",
                                            dependencies: [
                                                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                                            ],
                                            swiftSettings: [
                                                .enableExperimentalFeature("StrictConcurrency"),
                                            ],
                                            linkerSettings: [
                                                .linkedLibrary("c", .when(platforms: [.linux])),
                                            ]),
                      ])
