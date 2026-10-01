import SnapshottingTests

/// SnapshotPreviews がどのプレビューを見つけ、trait を当てるかを見る
final class LabPreviewSnapshots: SnapshotTest {
    override class func snapshotPreviewModules() -> [String]? {
        ["PreviewLab"]
    }
}
