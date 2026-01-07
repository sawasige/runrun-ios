import SwiftUI
import MapKit

/// MKGradientPolylineRendererを使用したグラデーションルート表示
struct GradientRouteMapView: UIViewRepresentable {
    let routeSegments: [RouteSegment]
    let fastPace: TimeInterval
    let slowPace: TimeInterval
    let startCoordinate: CLLocationCoordinate2D?
    let goalCoordinate: CLLocationCoordinate2D?
    let kilometerPoints: [KilometerPoint]

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.mapType = .standard
        mapView.showsCompass = true
        mapView.showsScale = false  // デフォルトのスケールを非表示

        // セーフエリアのギリギリ内側にコンパスを配置
        let safeArea = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets ?? .zero
        mapView.insetsLayoutMarginsFromSafeArea = false
        mapView.layoutMargins = UIEdgeInsets(
            top: safeArea.top + 8,
            left: 8,
            bottom: safeArea.bottom + 8,
            right: 8
        )

        // カスタムスケールを右下に配置
        let scaleView = MKScaleView(mapView: mapView)
        scaleView.scaleVisibility = .adaptive  // ズーム時のみ表示
        scaleView.translatesAutoresizingMaskIntoConstraints = false
        mapView.addSubview(scaleView)
        NSLayoutConstraint.activate([
            scaleView.trailingAnchor.constraint(equalTo: mapView.trailingAnchor, constant: -16),
            scaleView.bottomAnchor.constraint(equalTo: mapView.safeAreaLayoutGuide.bottomAnchor, constant: -8)
        ])

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // 既存のオーバーレイとアノテーションをクリア
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations)

        guard !routeSegments.isEmpty else { return }

        // 全座標を収集（元のまま）
        var allCoordinates: [CLLocationCoordinate2D] = []
        for segment in routeSegments {
            allCoordinates.append(contentsOf: segment.coordinates)
        }

        guard allCoordinates.count >= 2 else { return }

        // 色のポイントだけ間引く（最大200色）
        let skipCount = max(1, routeSegments.count / 200)
        let sampledSegments = stride(from: 0, to: routeSegments.count, by: skipCount).map { routeSegments[$0] }

        // 事前に色とロケーションを計算
        let (colors, locations) = calculateColorsAndLocations(from: sampledSegments)

        // グラデーションポリラインを作成
        let polyline = GradientPolyline(coordinates: allCoordinates, count: allCoordinates.count)
        polyline.colors = colors
        polyline.locations = locations
        mapView.addOverlay(polyline)

        // スタート地点
        if let start = startCoordinate {
            let annotation = RouteAnnotation(coordinate: start, type: .start)
            mapView.addAnnotation(annotation)
        }

        // ゴール地点
        if let goal = goalCoordinate {
            let annotation = RouteAnnotation(coordinate: goal, type: .goal)
            mapView.addAnnotation(annotation)
        }

        // キロマーカー
        for point in kilometerPoints {
            let annotation = RouteAnnotation(coordinate: point.coordinate, type: .kilometer(point.kilometer))
            mapView.addAnnotation(annotation)
        }

        // 地図の表示範囲を調整
        let rect = polyline.boundingMapRect
        let padding = UIEdgeInsets(top: 80, left: 40, bottom: 80, right: 40)
        mapView.setVisibleMapRect(rect, edgePadding: padding, animated: false)
    }

    /// 色とロケーションを事前計算
    private func calculateColorsAndLocations(from segments: [RouteSegment]) -> ([UIColor], [CGFloat]) {
        guard !segments.isEmpty else {
            return ([.green], [])
        }

        var colors: [UIColor] = []
        var locations: [CGFloat] = []

        // 均等に配置
        let count = segments.count
        for (index, segment) in segments.enumerated() {
            let color = uiColor(for: segment)
            let location = CGFloat(index) / CGFloat(count)
            colors.append(color)
            locations.append(location)
        }

        // 最後のポイント
        if let lastSegment = segments.last {
            colors.append(uiColor(for: lastSegment))
            locations.append(1.0)
        }

        return (colors, locations)
    }

    private func uiColor(for segment: RouteSegment) -> UIColor {
        guard slowPace > fastPace else { return .yellow }

        let normalized = min(1.0, max(0.0, (segment.pacePerKm - fastPace) / (slowPace - fastPace)))
        let hue = 0.33 * (1.0 - normalized)
        return UIColor(hue: hue, saturation: 0.85, brightness: 0.9, alpha: 1.0)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? GradientPolyline {
                let renderer = MKGradientPolylineRenderer(polyline: polyline)
                renderer.lineWidth = 3
                renderer.setColors(polyline.colors, locations: polyline.locations)
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let routeAnnotation = annotation as? RouteAnnotation else { return nil }

            let identifier = routeAnnotation.reuseIdentifier
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)

            if annotationView == nil {
                annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.image = routeAnnotation.image
                annotationView?.centerOffset = CGPoint(x: 0, y: -16)
            } else {
                annotationView?.annotation = annotation
            }

            return annotationView
        }
    }
}

// MARK: - カスタムクラス

class GradientPolyline: MKPolyline {
    var colors: [UIColor] = []
    var locations: [CGFloat] = []
}

class RouteAnnotation: NSObject, MKAnnotation {
    enum AnnotationType {
        case start
        case goal
        case kilometer(Int)
    }

    let coordinate: CLLocationCoordinate2D
    let type: AnnotationType

    init(coordinate: CLLocationCoordinate2D, type: AnnotationType) {
        self.coordinate = coordinate
        self.type = type
    }

    var reuseIdentifier: String {
        switch type {
        case .start: return "StartAnnotation"
        case .goal: return "GoalAnnotation"
        case .kilometer: return "KilometerAnnotation"
        }
    }

    var image: UIImage {
        let size: CGFloat = 32
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { ctx in
            let rect = CGRect(x: 0, y: 0, width: size, height: size)

            // 背景円
            let backgroundColor: UIColor
            switch type {
            case .start: backgroundColor = .systemGreen
            case .goal: backgroundColor = .systemRed
            case .kilometer: backgroundColor = .systemOrange
            }
            backgroundColor.setFill()
            UIBezierPath(ovalIn: rect).fill()

            // アイコンまたはテキスト
            switch type {
            case .start:
                if let icon = UIImage(systemName: "flag.fill")?.withTintColor(.white, renderingMode: .alwaysOriginal) {
                    let iconSize: CGFloat = 16
                    let iconRect = CGRect(x: (size - iconSize) / 2, y: (size - iconSize) / 2, width: iconSize, height: iconSize)
                    icon.draw(in: iconRect)
                }
            case .goal:
                if let icon = UIImage(systemName: "flag.checkered")?.withTintColor(.white, renderingMode: .alwaysOriginal) {
                    let iconSize: CGFloat = 16
                    let iconRect = CGRect(x: (size - iconSize) / 2, y: (size - iconSize) / 2, width: iconSize, height: iconSize)
                    icon.draw(in: iconRect)
                }
            case .kilometer(let km):
                let text = "\(km)"
                let font = UIFont.systemFont(ofSize: 12, weight: .bold)
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: UIColor.white
                ]
                let textSize = text.size(withAttributes: attributes)
                let textRect = CGRect(
                    x: (size - textSize.width) / 2,
                    y: (size - textSize.height) / 2,
                    width: textSize.width,
                    height: textSize.height
                )
                text.draw(in: textRect, withAttributes: attributes)
            }
        }
    }
}
