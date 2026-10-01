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

try renderNutrient(
    JSONDecoder().decode(
        [String: NutrientItem].self,
        from: Data(contentsOf: shared.appending(path: "nutrients.json"))
    )
)
.write(to: output.appending(path: "Nutrient.swift"), atomically: true, encoding: .utf8)

private struct Bounds: Decodable {
    let minimum: Double
    let maximum: Double
}

private struct NutrientItem: Decodable {
    let unit: String
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

private func renderNutrient(_ nutrients: [String: NutrientItem]) -> String {
    let names = nutrients.keys.sorted()
    let cases = names.map { "    case \(caseName(of: $0)) = \"\($0)\"" }
    let unitCases = names.map { name in
        "        case .\(caseName(of: name)): \"\(nutrients[name]!.unit)\""
    }
    return """
        // shared/nutrients.json から書き出した。直すときは JSON を直し、scripts/check ios --fix で書き出し直す

        /// 栄養の項目。rawValue は JSON のキー（サーバーの名前。単位を含む）
        public enum Nutrient: String, CaseIterable, Sendable, Hashable {
        \(cases.joined(separator: "\n"))

            /// 名前に含まれる単位の表記（`kcal`・`g`・`mg`・`µg`）
            public var unit: String {
                switch self {
        \(unitCases.joined(separator: "\n"))
                }
            }
        }

        """
}

/// 名前（単位を含む snake_case）を、先頭を小文字にした camelCase の case 名にする（`vitamin_b12_ug` → `vitaminB12Ug`）
private func caseName(of name: String) -> String {
    name.split(separator: "_").enumerated().map { index, word in
        index == 0 ? String(word) : word.prefix(1).uppercased() + word.dropFirst()
    }
    .joined()
}
