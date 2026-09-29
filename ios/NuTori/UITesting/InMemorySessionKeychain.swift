#if DEBUG
    import NuToriCore

    actor InMemorySessionKeychain: SessionKeychain {
        init(token: String?) {
            self.token = token
        }

        func sessionToken() async throws -> String? {
            token
        }

        func save(sessionToken: String) async throws {
            token = sessionToken
        }

        func deleteSessionToken() async throws {
            token = nil
        }

        private var token: String?
    }
#endif
