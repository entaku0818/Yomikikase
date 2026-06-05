// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KokoroSwift",
    platforms: [
        .iOS(.v18), .macOS(.v14)
    ],
    products: [
        .library(
            name: "KokoroSwift",
            type: .dynamic,
            targets: ["KokoroSwift"]
        ),
    ],
    dependencies: [
        // 0.30.6 で _MTLTensorDomain 等の弱リンク修正(#354)が入りシミュレータビルド可能に。
        // 0.31 系へのAPIドリフトを避けるため 0.30.x に固定（元は exact 0.30.2）。
        .package(url: "https://github.com/ml-explore/mlx-swift", .upToNextMinor(from: "0.30.6")),
        // シミュレータビルド不能(_MTLTensorDomain未定義)を解消するため、mlx-swift 0.30.6+ の
        // 弱リンク修正(#354)を取り込んだフォークを使用。upstream(mlalma)が mlx を更新したら戻す。
        .package(url: "https://github.com/entaku0818/MisakiSwift", revision: "768ccd2000e09d315654c386a2307badf5376438"),
        .package(url: "https://github.com/mlalma/MLXUtilsLibrary.git", exact: "0.0.6"),
    ],
    targets: [
        .target(
            name: "KokoroSwift",
            dependencies: [
                .product(name: "MLX", package: "mlx-swift"),
                .product(name: "MLXNN", package: "mlx-swift"),
                .product(name: "MLXRandom", package: "mlx-swift"),
                .product(name: "MLXFFT", package: "mlx-swift"),
                .product(name: "MisakiSwift", package: "MisakiSwift"),
                .product(name: "MLXUtilsLibrary", package: "MLXUtilsLibrary"),
            ],
            resources: [
                .copy("../../Resources")
            ]
        ),
    ]
)
