import Foundation

enum NotionError: LocalizedError {
    case offline
    case badToken
    case noAccess
    case server(Int, String)
    case badResponse

    var errorDescription: String? {
        switch self {
        case .offline: "No internet right now. SpendScan will try again next time you open it."
        case .badToken: "Notion didn't accept the secret. Copy it again from your Notion integration."
        case .noAccess: "SpendScan can't see that Notion page. In Notion, open the page, tap ••• → Connections, and add your SpendScan integration."
        case .server(let code, let message): "Notion returned an error (\(code)): \(message)"
        case .badResponse: "Notion sent back something unexpected."
        }
    }
}

/// A small client for the Notion REST API. It only ever talks to api.notion.com over HTTPS.
struct NotionClient {
    let token: String

    private static let baseURL = URL(string: "https://api.notion.com/v1/")!
    private static let apiVersion = "2022-06-28"
    private static let offlineCodes: [URLError.Code] = [
        .notConnectedToInternet, .networkConnectionLost, .timedOut,
        .cannotFindHost, .cannotConnectToHost, .dataNotAllowed,
    ]

    /// No cache, no cookies: nothing from Notion is written to disk by URLSession.
    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 30
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()

    /// Checks the secret works.
    func checkToken() async throws {
        _ = try await send("GET", "users/me")
    }

    /// Creates the receipts database inside a page the integration can see. Returns its id.
    func createReceiptsDatabase(inPage pageID: String) async throws -> String {
        let categoryOptions = NotionSchema.categoryOptions
        let body: [String: Any] = [
            "parent": ["type": "page_id", "page_id": pageID],
            "title": [NotionValue.text("SpendScan receipts")],
            "properties": [
                NotionSchema.merchant: ["title": [String: Any]()],
                NotionSchema.date: ["date": [String: Any]()],
                NotionSchema.total: ["number": ["format": "pound"]],
                NotionSchema.category: ["select": ["options": categoryOptions]],
                NotionSchema.itemCategories: ["multi_select": ["options": categoryOptions]],
                NotionSchema.items: ["rich_text": [String: Any]()],
                NotionSchema.itemCount: ["number": ["format": "number"]],
                NotionSchema.vat: ["number": ["format": "pound"]],
                NotionSchema.payment: ["rich_text": [String: Any]()],
                NotionSchema.source: ["select": [String: Any]()],
                NotionSchema.categorisedBy: ["rich_text": [String: Any]()],
                NotionSchema.receiptID: ["rich_text": [String: Any]()],
            ],
        ]
        let json = try await send("POST", "databases", body: body)
        guard let id = json["id"] as? String else { throw NotionError.badResponse }
        return id
    }

    /// Checks the saved database still exists and is shared with the integration.
    func databaseExists(_ databaseID: String) async -> Bool {
        (try? await send("GET", "databases/\(databaseID)")) != nil
    }

    /// Adds one receipt as a page. Returns the new page id.
    func createPage(databaseID: String, properties: [String: Any], children: [[String: Any]]) async throws -> String {
        let body: [String: Any] = [
            "parent": ["database_id": databaseID],
            "properties": properties,
            "children": children,
        ]
        let json = try await send("POST", "pages", body: body)
        guard let id = json["id"] as? String else { throw NotionError.badResponse }
        return id
    }

    /// Moves a page to Notion's trash (used when a receipt is deleted in the app).
    func archivePage(_ pageID: String) async throws {
        _ = try await send("PATCH", "pages/\(pageID)", body: ["archived": true])
    }

    // MARK: - Transport

    private func send(_ method: String, _ path: String, body: [String: Any]? = nil, attempt: Int = 0) async throws -> [String: Any] {
        var request = URLRequest(url: Self.baseURL.appendingPathComponent(path))
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(Self.apiVersion, forHTTPHeaderField: "Notion-Version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await Self.session.data(for: request)
        } catch let error as URLError where Self.offlineCodes.contains(error.code) {
            throw NotionError.offline
        }

        guard let http = response as? HTTPURLResponse else { throw NotionError.badResponse }
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]

        switch http.statusCode {
        case 200..<300:
            return json
        case 401:
            throw NotionError.badToken
        case 403, 404:
            throw NotionError.noAccess
        case 429, 502, 503, 504:
            // Notion allows about 3 requests a second. Wait as asked, then try again (up to 3 times).
            guard attempt < 3 else { throw NotionError.server(http.statusCode, "Too many requests") }
            let wait = Double(http.value(forHTTPHeaderField: "Retry-After") ?? "") ?? Double(attempt + 1)
            try await Task.sleep(for: .seconds(min(wait, 30)))
            return try await send(method, path, body: body, attempt: attempt + 1)
        default:
            throw NotionError.server(http.statusCode, json["message"] as? String ?? "Unknown error")
        }
    }
}

/// Turns a Notion page link (or a bare id) into the 32-character page id.
enum NotionLink {
    static func pageID(from text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let withoutQuery = trimmed.split(separator: "?").first.map(String.init) ?? trimmed
        let last = withoutQuery.split(separator: "/").last.map(String.init) ?? withoutQuery
        let hex = last.replacingOccurrences(of: "-", with: "")
        guard hex.count >= 32 else { return nil }
        let id = String(hex.suffix(32))
        guard id.allSatisfy(\.isHexDigit) else { return nil }
        return id
    }
}
