// swift-tools-version: 6.2
import PackageDescription

let package = Package(name: "hetzner-dyndns-cgi",
                      platforms: [
                          .macOS(.v13),
                      ],
                      products: [
                          .executable(name: "hetzner-dyndns",
                                      targets: ["HetznerDynDNS"]),
                      ],
                      targets: [
                          .executableTarget(name: "HetznerDynDNS",
                                            swiftSettings: [
                                                .enableExperimentalFeature("StrictConcurrency=complete"),
                                            ],
                                            linkerSettings: [
                                                .linkedLibrary("c", .when(platforms: [.linux])),
                                            ]),
                          .testTarget(name: "HetznerDynDNSTests",
                                      dependencies: ["HetznerDynDNS"]),
                      ])
