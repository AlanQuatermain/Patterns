// swift-tools-version:5.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
	name: "Patterns",
	products: [
		.library(
			name: "Patterns",
			targets: ["Patterns"]),
		.executable(
			name: "unicode_properties",
			targets: ["unicode_properties", "Patterns"]),
	],
	dependencies: [
		.package(url: "https://github.com/apple/swift-argument-parser", from: "1.0.0"),
		.package(url: "https://github.com/apple/swift-se0270-range-set", from: "1.0.0"),
	],
	targets: [
		.target(
			name: "Patterns",
			dependencies: ["SE0270_RangeSet"],
			swiftSettings: [
				.define("DEBUG", .when(configuration: .debug)),
			]),
		.testTarget(
			name: "PatternsTests",
			dependencies: ["Patterns"],
			swiftSettings: [ // Move code that takes too long to build into 'LongTests'.
				.unsafeFlags(["-Xfrontend", "-warn-long-expression-type-checking=200"]),
			]),
		.testTarget(
			name: "PerformanceTests",
			dependencies: ["Patterns"],
			swiftSettings: [
				.define("DEBUG", .when(configuration: .debug)),
			]),
		.testTarget( // For code that takes a long time to build or run. Try to keep "PatternsTests" snappy.
			name: "LongTests",
			dependencies: ["Patterns"]),
		.target(
			name: "unicode_properties",
			dependencies: ["Patterns", "ArgumentParser"]),
	],
	swiftLanguageVersions: [.v5])
