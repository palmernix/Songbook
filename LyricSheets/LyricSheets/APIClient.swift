import Foundation

struct APIClient {
    static let shared = APIClient()

    #if DEBUG
    private let baseURL = URL(string: "http://127.0.0.1:8000")!
    #else
    private let baseURL = URL(string: "https://your-api.example.com")!
    #endif

    struct SuggestRequest: Codable {
        let userLyrics: String
        let contextFocus: String
        let contextFull: String
        let style: String
        let mood: String
        let scheme: String
        let syllables: String
        let sectionKind: String?
        let songId: String?
        let temperature: Double
        let k: Int
        let minSim: Double
        let mmr: Bool
        let stream: Bool
    }

    struct SuggestResponse: Codable {
        let suggestion: String
    }

    func suggest(userLyrics: String, contextFocus: String, contextFull: String) async throws -> String {
        let body = SuggestRequest(
            userLyrics: userLyrics,
            contextFocus: contextFocus,
            contextFull: contextFull,
            style: "indie folk",
            mood: "neutral",
            scheme: "ABAB",
            syllables: "8-10",
            sectionKind: "verse",
            songId: nil,
            temperature: 0.9,
            k: 6,
            minSim: 0.18,
            mmr: true,
            stream: false
        )
        let url = baseURL.appendingPathComponent("suggest")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let decoded = try JSONDecoder().decode(SuggestResponse.self, from: data)
        return decoded.suggestion
    }
}