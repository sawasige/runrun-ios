import SwiftUI
import MapKit

/// タイムライン用のMapKitベースのルートサムネイル表示
struct RouteThumbnailView: View {
    let route: SimplifiedRoute?
    var maxWidth: CGFloat = .infinity
    var maxHeight: CGFloat = 250
    var strokeWidth: CGFloat = 3

    @Environment(\.colorScheme) private var colorScheme
    @State private var snapshotImage: UIImage?
    @State private var isLoading = false

    private var strokeColor: UIColor {
        UIColor.tintColor
    }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let size = CGSize(width: width, height: height)

            ZStack {
                // 背景
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.secondarySystemBackground))

                if let image = snapshotImage {
                    // 地図スナップショット
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: width, height: height)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else if route != nil {
                    // ローディング
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    // プレースホルダー（ルートなし）
                    placeholderView
                }
            }
            .frame(width: width, height: height)
            .task(id: SnapshotKey(route: route, colorScheme: colorScheme)) {
                guard let route = route, !route.coordinates.isEmpty else {
                    snapshotImage = nil
                    return
                }
                await generateSnapshot(route: route, size: size)
            }
        }
        .frame(height: maxHeight)
        .frame(maxWidth: maxWidth)
    }

    private var placeholderView: some View {
        VStack(spacing: 4) {
            Image(systemName: "map")
                .font(.title3)
                .foregroundStyle(.tertiary)
        }
    }

    /// MKMapSnapshotterで地図画像を生成
    @MainActor
    private func generateSnapshot(route: SimplifiedRoute, size: CGSize) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        let bbox = route.boundingBox

        // 地図の表示範囲を計算（5%のパディング、地名が読めるように狭めに）
        let latPadding = bbox.latSpan * 0.05
        let lonPadding = bbox.lonSpan * 0.05

        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: bbox.centerLat, longitude: bbox.centerLon),
            span: MKCoordinateSpan(
                latitudeDelta: bbox.latSpan + latPadding * 2,
                longitudeDelta: bbox.lonSpan + lonPadding * 2
            )
        )

        let options = MKMapSnapshotter.Options()
        options.region = region
        options.size = size // 等倍で生成（地名を読みやすく）
        options.mapType = .standard
        options.showsBuildings = false
        options.pointOfInterestFilter = .includingAll // 地名を表示

        let snapshotter = MKMapSnapshotter(options: options)

        do {
            let snapshot = try await snapshotter.start()
            let image = drawRoute(on: snapshot, route: route)
            snapshotImage = image
        } catch {
            // スナップショット生成失敗時は何もしない
        }
    }

    /// スナップショット画像上にルートを描画
    private func drawRoute(on snapshot: MKMapSnapshotter.Snapshot, route: SimplifiedRoute) -> UIImage {
        let image = snapshot.image

        UIGraphicsBeginImageContextWithOptions(image.size, true, image.scale)
        defer { UIGraphicsEndImageContext() }

        // 地図画像を描画
        image.draw(at: .zero)

        guard let context = UIGraphicsGetCurrentContext() else {
            return image
        }

        // ルートを描画
        context.setStrokeColor(strokeColor.cgColor)
        context.setLineWidth(strokeWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        let coordinates = route.coordinates
        for (index, coord) in coordinates.enumerated() {
            let point = snapshot.point(for: CLLocationCoordinate2D(
                latitude: coord.latitude,
                longitude: coord.longitude
            ))

            if index == 0 {
                context.move(to: point)
            } else {
                context.addLine(to: point)
            }
        }

        context.strokePath()

        return UIGraphicsGetImageFromCurrentImageContext() ?? image
    }
}

// MARK: - Snapshot Key

/// taskのidとして使用するキー（routeとcolorSchemeの両方を監視）
private struct SnapshotKey: Equatable {
    let route: SimplifiedRoute?
    let colorScheme: ColorScheme
}

#Preview("With Route") {
    let coordinates: [SimplifiedRoute.Coordinate] = [
        .init(latitude: 35.6908, longitude: 139.7561),
        .init(latitude: 35.6852, longitude: 139.7446),
        .init(latitude: 35.6778, longitude: 139.7490),
        .init(latitude: 35.6786, longitude: 139.7567),
        .init(latitude: 35.6899, longitude: 139.7598),
    ]
    let bbox = SimplifiedRoute.BoundingBox(
        minLat: 35.6778, maxLat: 35.6908,
        minLon: 139.7446, maxLon: 139.7598
    )
    let route = SimplifiedRoute(coordinates: coordinates, boundingBox: bbox)

    return VStack(spacing: 20) {
        RouteThumbnailView(route: route)
            .padding()

        RouteThumbnailView(route: nil)
            .padding()
    }
}

#Preview("No Route") {
    RouteThumbnailView(route: nil)
        .padding()
}
