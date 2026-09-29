import Foundation

let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    FileHandle.standardError.write(
        Data("使い方: SharedRulesGenerator <shared のディレクトリ> <書き出す先のディレクトリ>\n".utf8))
    exit(2)
}
let shared = URL(filePath: arguments[1], directoryHint: .isDirectory)
let output = URL(filePath: arguments[2], directoryHint: .isDirectory)

try renderAcceptedRange(
    JSONDecoder().decode(
        [String: Bounds].self,
        from: Data(contentsOf: shared.appending(path: "accepted-ranges.json"))
    )
)
.write(to: output.appending(path: "AcceptedRange.swift"), atomically: true, encoding: .utf8)

private struct Bounds: Decodable {
    let minimum: Double
    let maximum: Double
}

private func renderAcceptedRange(_ ranges: [String: Bounds]) -> String {
    let names = ranges.keys.sorted()
    let cases = names.map { "    case \($0)" }
    let boundsCases = names.map { name in
        let range = ranges[name]!
        return "        case .\(name): \(range.minimum)...\(range.maximum)"
    }
    return """
        // shared/accepted-ranges.json から書き出した。直すときは JSON を直し、scripts/check ios --fix で書き出し直す

        public enum AcceptedRange {
        \(cases.joined(separator: "\n"))

            public var bounds: ClosedRange<Double> {
                switch self {
        \(boundsCases.joined(separator: "\n"))
                }
            }
        }

        """
}
