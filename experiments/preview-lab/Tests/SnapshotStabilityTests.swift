import SnapshotTesting
import SwiftUI
import XCTest
@testable import PreviewLab

/// 同じ見本を swift-snapshot-testing で撮り、機種や OS を変えて比べたときに通るかを見る
final class SnapshotStabilityTests: XCTestCase {
    @MainActor
    func testSyncBanners() {
        let record: SnapshotTestingConfiguration.Record =
            ProcessInfo.processInfo.environment["LAB_RECORD"] == "1" ? .all : .never
        withSnapshotTesting(record: record) {
            for sample in SyncSample.allCases {
                assertSnapshot(
                    of: SyncBanner(sample: sample).frame(width: 390),
                    as: .image(layout: .sizeThatFits),
                    named: sample.rawValue
                )
            }
            assertSnapshot(
                of: RecordList(),
                as: .image(layout: .device(config: .iPhone13)),
                named: "list-device"
            )
        }
    }
}

/// ImageRenderer で List を描けるかを見る
final class ImageRendererTests: XCTestCase {
    @MainActor
    func testRender() throws {
        let out = URL(fileURLWithPath: ProcessInfo.processInfo.environment["LAB_OUT"] ?? NSTemporaryDirectory())
        let views: [(String, AnyView)] = [
            ("banner", AnyView(SyncBanner(sample: .failed).frame(width: 390))),
            ("list", AnyView(RecordList().frame(width: 390, height: 400))),
        ]
        for (name, view) in views {
            let renderer = ImageRenderer(content: view)
            renderer.scale = 2
            let data = try XCTUnwrap(renderer.uiImage?.pngData())
            try data.write(to: out.appendingPathComponent("imagerenderer-\(name).png"))
        }
    }
}

/// ホストの回線の絞りがシミュレータの通信に効くかを見る
final class NetworkProbeTests: XCTestCase {
    func testProbe() async throws {
        let env = ProcessInfo.processInfo.environment
        let url = URL(string: env["LAB_URL"] ?? "https://example.com")!
        let label = env["LAB_NET_LABEL"] ?? "unlabeled"
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 8
        config.timeoutIntervalForResource = 8
        let start = Date()
        var line: String
        do {
            let (_, response) = try await URLSession(configuration: config).data(from: url)
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            line = "\(label): ok status=\(status)"
        } catch {
            line = "\(label): error=\((error as NSError).code) \((error as NSError).localizedDescription)"
        }
        line += String(format: " elapsed=%.2fs", Date().timeIntervalSince(start))
        print("LAB_NET \(line)")
        if let outPath = env["LAB_OUT"] {
            let file = URL(fileURLWithPath: outPath).appendingPathComponent("network.txt")
            let data = Data((line + "\n").utf8)
            if let handle = try? FileHandle(forWritingTo: file) {
                handle.seekToEndOfFile()
                handle.write(data)
                try handle.close()
            } else {
                try data.write(to: file)
            }
        }
    }
}
