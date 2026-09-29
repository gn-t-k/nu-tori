struct SessionRequestBody: Decodable {
    let idToken: String
    let nonce: String
    let authorizationCode: String
    let timeZone: String?
}
