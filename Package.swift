// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TopMoviesCore",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [.library(name: "TopMoviesCore", targets: ["TopMoviesCore"])],
    targets: [
        .target(name: "TopMoviesCore", path: "TopMovies/Core"),
        .testTarget(name: "TopMoviesCoreTests", dependencies: ["TopMoviesCore"])
    ]
)
