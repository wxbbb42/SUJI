import SwiftUI

/// The page bends around a moving diagonal cylinder. Each clipped strip gets
/// its own affine projection; the entire page is never rotated as a rigid card.
struct PaperCurlSurface<Front: View>: View, Animatable {
    nonisolated var progress: CGFloat
    @ViewBuilder var front: () -> Front
    @Environment(\.colorScheme) private var colorScheme

    nonisolated var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        Canvas { context, size in
            guard let symbol = context.resolveSymbol(id: "calendar-front") else { return }
            let geometry = PaperCurlGeometry(size: size, progress: progress)
            let flatPath = geometry.path(for: geometry.clippedPolygon(lower: -.infinity, upper: geometry.fold))
            var flatContext = context
            flatContext.clip(to: flatPath)
            flatContext.draw(symbol, at: .zero, anchor: .topLeading)

            let strips = geometry.strips(count: 56)
            // Blur one composed silhouette, not each overlapping strip.
            var shadow = context
            shadow.opacity = colorScheme == .dark ? 0.25 : 0.13
            shadow.addFilter(.blur(radius: 2 + geometry.radius * 0.15))
            shadow.drawLayer { mask in
                for strip in strips {
                    let projected = strip.path.applying(strip.transform).offsetBy(dx: 0, dy: 3)
                    mask.fill(projected, with: .color(.black))
                }
            }

            for strip in strips {
                var layer = context
                layer.concatenate(strip.transform)
                layer.clip(to: strip.path)
                if strip.isBack {
                    layer.fill(strip.path, with: .color(SujiTheme.surface))
                    layer.fill(strip.path, with: .color(SujiTheme.line.opacity(colorScheme == .dark ? 0.48 : 0.16)))
                    var inkThroughPaper = layer
                    inkThroughPaper.opacity = 0.025
                    inkThroughPaper.draw(symbol, at: .zero, anchor: .topLeading)
                } else {
                    layer.draw(symbol, at: .zero, anchor: .topLeading)
                }
                layer.fill(strip.path, with: .color(.black.opacity(strip.shade)))
                if strip.highlight > 0 {
                    layer.fill(strip.path, with: .color(.white.opacity(strip.highlight * (colorScheme == .dark ? 1.35 : 1))))
                }
            }
        } symbols: {
            front().tag("calendar-front")
        }
        .opacity(1 - max(0, min(1, (progress - 0.78) / 0.22)))
        .allowsHitTesting(false)
    }
}

/// Pure geometry, independent of gesture state and SwiftUI rendering. A convex
/// clip keeps every strip inside the source leaf before cylinder projection.
struct PaperCurlGeometry {
    static let normal = CGPoint(x: 0.64, y: 0.7683749084919419)
    let size: CGSize
    let progress: CGFloat

    var extent: CGFloat { size.width * Self.normal.x + size.height * Self.normal.y }
    var radius: CGFloat { 7 + 17 * sin(min(1, max(0, progress)) * .pi) }
    // The resting corner and active peel share one continuous surface.
    var fold: CGFloat { extent - 31 - max(0, min(1, progress)) * (extent + 140 - 31) }

    struct Strip {
        let path: Path
        let transform: CGAffineTransform
        let isBack: Bool
        let shade: Double
        let highlight: Double
    }

    func strips(count: Int) -> [Strip] {
        let start = max(0, fold)
        guard count > 0, extent > start else { return [] }
        let arcEnd = fold + .pi * radius
        // Sample the curved region finely; the turned tail is a single flat strip.
        var boundaries = [start]
        for index in 1...max(2, count) {
            let boundary = fold + CGFloat(index) / CGFloat(max(2, count)) * .pi * radius
            if boundary > start && boundary < extent { boundaries.append(boundary) }
        }
        if arcEnd > start && arcEnd < extent && boundaries.last != arcEnd { boundaries.append(arcEnd) }
        boundaries.append(extent)
        return zip(boundaries, boundaries.dropFirst()).compactMap { lower, upper in
            let polygon = clippedPolygon(lower: lower - 0.12, upper: upper + 0.12)
            guard polygon.count > 2 else { return nil }
            let middle = (lower + upper) / 2 - fold
            let angle = min(.pi, max(0, middle / radius))
            let back = angle > .pi / 2
            let shade = 0.10 * pow(sin(angle), 4) + (back ? 0.012 : 0)
            let highlight = 0.085 * pow(max(0, cos(angle - 0.4)), 8)
            return Strip(path: path(for: polygon), transform: transform(lower: lower, upper: upper),
                         isBack: back, shade: shade, highlight: highlight)
        }
    }

    func clippedPolygon(lower: CGFloat, upper: CGFloat) -> [CGPoint] {
        let corners = [CGPoint.zero, CGPoint(x: size.width, y: 0),
                       CGPoint(x: size.width, y: size.height), CGPoint(x: 0, y: size.height)]
        return clip(clip(corners, boundary: upper, keepLower: true), boundary: lower, keepLower: false)
    }

    func path(for polygon: [CGPoint]) -> Path {
        Path { path in
            guard let first = polygon.first else { return }
            path.move(to: first)
            polygon.dropFirst().forEach { path.addLine(to: $0) }
            path.closeSubpath()
        }
    }

    private func position(_ distance: CGFloat) -> (plane: CGFloat, height: CGFloat) {
        let arcLength = .pi * radius
        if distance > arcLength { return (-(distance - arcLength), 2 * radius) }
        let angle = max(0, distance) / radius
        return (radius * sin(angle), radius * (1 - cos(angle)))
    }

    private func transform(lower: CGFloat, upper: CGFloat) -> CGAffineTransform {
        let first = position(lower - fold)
        let last = position(upper - fold)
        let delta = max(0.0001, upper - lower)
        let scale = (last.plane - first.plane) / delta
        let liftScale = (last.height - first.height) / delta
        let planeOffset = fold + first.plane - scale * lower
        let liftOffset = first.height - liftScale * lower
        let n = Self.normal
        // The slight vertical height projection makes the lifted edge read as
        // volume. Source text bends with the front; the reverse is blank paper.
        return CGAffineTransform(
            a: 1 + (scale - 1) * n.x * n.x,
            b: (scale - 1) * n.y * n.x - 0.18 * liftScale * n.x,
            c: (scale - 1) * n.x * n.y,
            d: 1 + (scale - 1) * n.y * n.y - 0.18 * liftScale * n.y,
            tx: n.x * planeOffset,
            ty: n.y * planeOffset - 0.18 * liftOffset
        )
    }

    private func clip(_ polygon: [CGPoint], boundary: CGFloat, keepLower: Bool) -> [CGPoint] {
        guard !polygon.isEmpty else { return [] }
        if boundary == .infinity { return keepLower ? polygon : [] }
        if boundary == -.infinity { return keepLower ? [] : polygon }
        func signedDistance(_ point: CGPoint) -> CGFloat {
            let value = point.x * Self.normal.x + point.y * Self.normal.y - boundary
            return keepLower ? value : -value
        }
        var result: [CGPoint] = []
        var previous = polygon[polygon.count - 1]
        var previousDistance = signedDistance(previous)
        for point in polygon {
            let distance = signedDistance(point)
            if (distance <= 0) != (previousDistance <= 0) {
                let fraction = previousDistance / (previousDistance - distance)
                result.append(CGPoint(
                    x: previous.x + (point.x - previous.x) * fraction,
                    y: previous.y + (point.y - previous.y) * fraction
                ))
            }
            if distance <= 0 { result.append(point) }
            previous = point
            previousDistance = distance
        }
        return result
    }
}
