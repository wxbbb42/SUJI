import CoreGraphics

/// Gesture effort is independent of the height of the hidden quote.
enum PaperPeelInteraction {
    static let revealProgress: CGFloat = 0.32

    static func completionDistance(width: CGFloat) -> CGFloat {
        min(112, max(92, width * 0.29))
    }

    static func isPeelIntent(_ translation: CGSize) -> Bool {
        translation.width < -3 && translation.height < -3 &&
            -translation.width > -translation.height * 0.22
    }

    static func shouldReveal(at translation: CGSize, maximumDistance: CGFloat,
                             acquiredPeel: Bool, width: CGFloat, reduceMotion: Bool) -> Bool {
        // A drag returned to its origin is a cancellation, never a fresh tap.
        let excursion = max(maximumDistance, hypot(translation.width, translation.height))
        if excursion < 8 { return true }
        return acquiredPeel && !reduceMotion && progress(for: translation, width: width) >= revealProgress
    }

    static func progress(for translation: CGSize, width: CGFloat) -> CGFloat {
        let distance = -translation.width * 0.64 - translation.height * 0.7683749084919419
        return min(0.88, max(0, distance / completionDistance(width: width) * revealProgress))
    }
}
