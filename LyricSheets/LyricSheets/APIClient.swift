import Foundation

struct APIClient {
    static let shared = APIClient()

    // private let baseURL = URL(string: "http://127.0.0.1:8000")! //For local development
    private let baseURL = URL(string: "https://lyricsheets-api-lnfivdl47a-ue.a.run.app")!

    struct SuggestRequest: Codable {
        let userLyrics: String
        let contextFocus: String
        let contextFull: String
        var style: String? = nil
        var mood: String? = nil
        var scheme: String? = nil
        var syllables: String? = nil
        var sectionKind: String? = nil
        let temperature: Double
        let k: Int
        let minSim: Double
        let mmr: Bool
        let stream: Bool
    }

    struct SuggestResponse: Codable {
        let suggestion: String
    }

    func suggest(
        userLyrics: String,
        contextFocus: String,
        contextFull: String,
        options: InspireOptions = .empty
    ) async throws -> String {
        let body = SuggestRequest(
            userLyrics: userLyrics,
            contextFocus: contextFocus,
            contextFull: contextFull,
            style: options.style,
            mood: options.mood,
            scheme: options.scheme,
            syllables: options.syllables,
            sectionKind: options.sectionKind,
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
