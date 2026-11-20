/// A Siri Remote press that a hold already acted on. On Apple TV the
/// release of a held select still reaches the button as a click, so a
/// control that does one thing on a click and another on a hold would do
/// both (tvos-shell/one-press-does-one-thing). The hold marks the press;
/// the click that ends it reads the mark and does nothing.
public struct HeldPress: Sendable {
    /// How long after the hold a click still counts as its release.
    public static let releaseWindow = Duration.milliseconds(1500)

    private var heldAt: ContinuousClock.Instant?

    public init() {}

    /// A hold of the press acted at `now`.
    public mutating func held(at now: ContinuousClock.Instant = .now) {
        heldAt = now
    }

    /// True once, for the click that ends a hold. Any later click, or one
    /// past the release window, is a click of its own.
    public mutating func takeRelease(at now: ContinuousClock.Instant = .now) -> Bool {
        defer { heldAt = nil }
        guard let heldAt else { return false }
        return now - heldAt < Self.releaseWindow
    }
}
