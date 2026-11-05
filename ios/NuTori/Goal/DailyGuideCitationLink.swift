import NuToriCore
import SwiftUI

/// 1日の目安の出典に潜る入口
struct DailyGuideCitationLink: View {
    var body: some View {
        NavigationLink(value: TimelineNavigation.Route.dailyGuideCitation) {
            Text("\(DailyGuideCitationScreen.title) ›")
                .goalTextLinkStyle()
        }
        .accessibilityIdentifier("daily-guide-citation-link")
    }
}
