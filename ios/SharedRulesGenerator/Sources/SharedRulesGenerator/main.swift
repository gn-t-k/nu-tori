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

/// 下限は minimum（含む）か exclusiveMinimum（含まない）のどちらか。上限は maximum（含む）で、無ければ上限なし
private struct Bounds: Decodable {
    let lowerBound: LowerBound
    let maximum: Double?

    enum LowerBound {
        case unbounded
        case inclusive(Double)
        case exclusive(Double)
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        maximum = try container.decodeIfPresent(Double.self, forKey: .maximum)
        switch try (
            container.decodeIfPresent(Double.self, forKey: .minimum),
            container.decodeIfPresent(Double.self, forKey: .exclusiveMinimum)
        ) {
        case (nil, nil): lowerBound = .unbounded
        case (let minimum?, nil): lowerBound = .inclusive(minimum)
        case (nil, let exclusiveMinimum?): lowerBound = .exclusive(exclusiveMinimum)
        // 両方を書くと、サーバーは両方を当て、端末は片方しか当てず、判定が食い違う
        case (.some, .some):
            throw DecodingError.dataCorruptedError(
                forKey: .exclusiveMinimum, in: container,
                debugDescription: "minimum と exclusiveMinimum は片方だけ書く")
        }
    }

    private enum CodingKeys: String, CodingKey {
        case minimum, exclusiveMinimum, maximum
    }
}

private struct NutrientItem: Decodable {
    let unit: String
}

private func renderAcceptedRange(_ ranges: [String: Bounds]) -> String {
    let names = ranges.keys.sorted()
    let cases = names.map { "    case \($0)" }
    let boundsCases = names.map { name in
        let range = ranges[name]!
        let (lowerBound, includesLowerBound) =
            switch range.lowerBound {
            case .unbounded: ("-.infinity", true)
            case .inclusive(let minimum): ("\(minimum)", true)
            case .exclusive(let exclusiveMinimum): ("\(exclusiveMinimum)", false)
            }
        let upperBound = range.maximum.map { "\($0)" } ?? ".infinity"
        return """
                    case .\(name):
                        AcceptedBounds(
                            lowerBound: \(lowerBound), includesLowerBound: \(includesLowerBound), upperBound: \(upperBound))
            """
    }
    return """
        // shared/accepted-ranges.json から書き出した。直すときは JSON を直し、scripts/check ios --fix で書き出し直す

        public enum AcceptedRange {
        \(cases.joined(separator: "\n"))

            public var bounds: AcceptedBounds {
                switch self {
        \(boundsCases.joined(separator: "\n"))
                }
            }
        }

        /// 下限を含むかは範囲ごとに決まる。上限は含み、無い範囲では無限大
        public struct AcceptedBounds: Sendable {
            public let lowerBound: Double
            public let includesLowerBound: Bool
            public let upperBound: Double

            public func contains(_ value: Double) -> Bool {
                (includesLowerBound ? lowerBound <= value : lowerBound < value) && value <= upperBound
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
