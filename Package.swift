// swift-tools-version:5.7.1
import PackageDescription

let package = Package(
	name: "Light-Untar",
	defaultLocalization: "en",
	platforms: [.iOS(.v13)],
	products: [
		.library(
			name: "Light-Untar",
			targets: ["Light-Untar"]),
	],
	targets: [
		.target(
			name: "Light-Untar",
			path: "Light-Untar",
			publicHeadersPath: ""),
	]
)
