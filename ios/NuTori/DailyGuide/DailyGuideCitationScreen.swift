import SwiftUI

/// 1日の目安の出典。目標の画面と目標を決めるページの「1日の目安の出典 ›」から潜る。
/// 審査の 1.4.1（健康の勧めに出典を、アプリの中で見つけやすく）に応えて置いた（#900）。
/// 値は書かず、何の決まりにどの資料を使ったかだけを並べる。値と計算の決まりは出し方のページ（`site/src/pages/daily-guide-page.tsx`）に書き、出典の並びはそのページの「出典」の節とそろえる
struct DailyGuideCitationScreen: View {
    var body: some View {
        List {
            Section {
                Text("nu-tori は、推定消費カロリーと1日の目安を、次の資料をもとに出しています。資料の値をどう当てはめるかは、nu-tori が決めています。")
                Text(GoalSetupMedicalNote.medicalNote)
                    .foregroundStyle(.secondary)
            }
            ForEach(Self.topics) { topic in
                Section(topic.title) {
                    ForEach(topic.citations) { citation in
                        CitationRow(citation: citation)
                    }
                }
            }
            Section("nu-tori が決めたもの") {
                Text(
                    "次の決まりは、資料に拠らず nu-tori が決めています。毎週の見直しで1日の目安を変える幅、推定消費カロリーを直す割合、毎朝の体重のならし方、見直しに要る記録の日数、体重を保つ目標で保つ幅と戻す速さです。"
                )
            }
            Section {
                Link("計算の決まりをくわしく見る", destination: PublicPages.dailyGuide)
            }
        }
        .navigationTitle(Self.title)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("daily-guide-citation-screen")
    }

    /// 入口のリンクと画面の題で同じ文言にする
    static let title = "1日の目安の出典"

    private static let topics: [Topic] = [
        Topic(
            title: "推定消費カロリー",
            citations: [
                Citation(
                    use: "安静にしているときに使うカロリーの式（Mifflin-St Jeor の式）",
                    source: "Mifflin MD, St Jeor ST, et al. Am J Clin Nutr. 1990;51(2):241-247",
                    url: URL(string: "https://doi.org/10.1093/ajcn/51.2.241")!),
                Citation(
                    use: "ふだんの動きの多さに合わせて掛ける係数。この資料の身体活動レベルの幅から選んでいます",
                    source: "FAO/WHO/UNU. Human energy requirements. 2004（表 5.3）",
                    url: URL(string: "https://www.fao.org/4/y5686e/y5686e07.htm")!),
                Citation(
                    use: "歩数で動きの多さを分ける境",
                    source: "Tudor-Locke C, Bassett DR Jr. Sports Med. 2004;34(1):1-8",
                    url: URL(string: "https://doi.org/10.2165/00007256-200434010-00001")!),
                Citation(
                    use: "体重 1 kg の増減にあたるカロリー",
                    source: "Wishnofsky M. Am J Clin Nutr. 1958;6(5):542-546",
                    url: URL(string: "https://doi.org/10.1093/ajcn/6.5.542")!),
                Citation(
                    use: "上の値は、長く続けると体の使うカロリーが変わってずれることがあります。nu-tori は、毎週の見直しでこのずれを直します",
                    source: "Hall KD. Int J Obes. 2008;32(3):573-576",
                    url: URL(string: "https://doi.org/10.1038/sj.ijo.0803720")!),
            ]),
        Topic(
            title: "1日の目安",
            citations: [
                Citation(
                    use: "体重を減らす速さの上限。この資料が勧める幅の中から選んでいます",
                    source: "Helms ER, Aragon AA, Fitschen PJ. J Int Soc Sports Nutr. 2014;11:20",
                    url: URL(string: "https://doi.org/10.1186/1550-2783-11-20")!),
                Citation(
                    use: "体重を増やす速さの上限。この資料が勧める幅の中から選んでいます",
                    source: "Iraki J, Fitschen P, Espinar S, Helms E. Sports. 2019;7(7):154",
                    url: URL(string: "https://doi.org/10.3390/sports7070154")!),
                Citation(
                    use: "1日の目安の下限。この資料が女性に勧める量の幅の下端に合わせています",
                    source: "Jensen MD, et al. Circulation. 2014;129(25 Suppl 2):S102-S138",
                    url: URL(string: "https://doi.org/10.1161/01.cir.0000437739.71477.ee")!),
            ]),
        Topic(
            title: "P・F・C の目安",
            citations: [
                Citation(
                    use: "たんぱく質の量",
                    source: "Morton RW, et al. Br J Sports Med. 2018;52(6):376-384",
                    url: URL(string: "https://doi.org/10.1136/bjsports-2017-097608")!),
                Citation(
                    use: "脂質と炭水化物の割合",
                    source: "厚生労働省「日本人の食事摂取基準（2025年版）」",
                    url: URL(string: "https://www.mhlw.go.jp/stf/newpage_44138.html")!),
                Citation(
                    use: "グラムからカロリーへの換算",
                    source: "FAO. Food energy – methods of analysis and conversion factors. 2003",
                    url: URL(string: "https://www.fao.org/4/y5022e/y5022e04.htm")!),
            ]),
    ]

    private struct Topic: Identifiable {
        let title: String
        let citations: [Citation]

        var id: String { title }
    }

    private struct Citation: Identifiable {
        /// 何の決まりにこの資料を使ったか
        let use: String
        let source: String
        let url: URL

        var id: URL { url }
    }

    private struct CitationRow: View {
        let citation: Citation

        var body: some View {
            Link(destination: citation.url) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(citation.use)
                        .foregroundStyle(.primary)
                    Text(citation.source)
                        .font(.footnote)
                        .foregroundStyle(.tint)
                }
            }
        }
    }
}
