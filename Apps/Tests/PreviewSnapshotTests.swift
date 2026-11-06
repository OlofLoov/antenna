import SnapshottingTests

/// Renders every `#Preview` in the app. There are no test methods to write:
/// SnapshotPreviews adds one test per preview at runtime. With
/// `TEST_RUNNER_SNAPSHOTS_EXPORT_DIR` set, each preview is written as a PNG
/// to that directory.
final class PreviewSnapshotTests: SnapshotTest {}
