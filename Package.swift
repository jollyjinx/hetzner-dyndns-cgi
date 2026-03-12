// swift-tools-version: 6.2
import PackageDescription

let package = Package(name: "hetzner-dyndns-cgi",
                      platforms: [
                          .macOS(.v13),
                      ],
                      products: [
                          .library(name: "HetznerDynDNS",
                                   targets: ["HetznerDynDNS"]),
                          .executable(name: "hetzner-dyndns",
                                      targets: ["HetznerDynDNSCGI"]),
                      ],
                      targets: [
                          .target(name: "HetznerDynDNS",
                                  swiftSettings: [
                                      .enableExperimentalFeature("StrictConcurrency=complete"),
                                  ]),
                          .executableTarget(name: "HetznerDynDNSCGI",
                                            dependencies: ["HetznerDynDNS"],
                                            path: "Sources/HetznerDynDNSCGI",
                                            swiftSettings: [
                                                .enableExperimentalFeature("StrictConcurrency=complete"),
                                            ],
                                            linkerSettings: [
                                                .linkedLibrary("c", .when(platforms: [.linux])),
                                            ]),
                          .testTarget(name: "HetznerDynDNSTests",
                                      dependencies: ["HetznerDynDNS"]),
                      ])
