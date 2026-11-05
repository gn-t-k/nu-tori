import SwiftUI

struct DailyGuideExplanationLink: View {
    var body: some View {
        Link("1日の目安が、あなたの体に合っていく仕組み", destination: PublicPages.dailyGuide)
            .goalTextLinkStyle()
            .accessibilityIdentifier("daily-guide-explanation-link")
    }
}
