final class CallLog: @unchecked Sendable {
    private(set) var events: [String] = []

    func record(_ event: String) {
        events.append(event)
    }
}
