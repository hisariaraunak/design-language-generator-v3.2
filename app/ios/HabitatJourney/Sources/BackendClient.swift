import Foundation
import Security

enum BackendError: LocalizedError {
    case invalidResponse
    case server(Int, String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "The server returned an unreadable response."
        case let .server(_, message): message
        }
    }
}

struct SessionDTO: Codable, Sendable {
    let token: String
    let userID: String
    let expiresAt: String
    enum CodingKeys: String, CodingKey { case token; case userID = "user_id"; case expiresAt = "expires_at" }
}

struct FoodDTO: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let detail: String
    let emoji: String
    let calories: Int
    let protein: Double
    let carbs: Double
    let fat: Double
    let fiber: Double
    let isVerified: Bool
    enum CodingKeys: String, CodingKey { case id, name, detail, emoji, calories, protein, carbs, fat, fiber; case isVerified = "is_verified" }

    var local: Food { Food(name: name, detail: detail, emoji: emoji, calories: calories, macros: .init(protein: protein, carbs: carbs, fat: fat, fiber: fiber)) }
}

actor BackendClient {
    static let shared = BackendClient()
    private let session: URLSession
    private let baseURL: URL?
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(session: URLSession = .shared, baseURL: URL? = BackendConfiguration.baseURL) {
        self.session = session
        self.baseURL = baseURL
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }

    var isConfigured: Bool { baseURL != nil }

    func register(email: String, password: String, displayName: String) async throws {
        let body = ["email": email, "password": password, "display_name": displayName]
        let response: SessionDTO = try await request("v1/auth/register", method: "POST", body: body, authenticated: false)
        try TokenVault.save(response.token)
    }

    func login(email: String, password: String) async throws {
        let response: SessionDTO = try await request("v1/auth/login", method: "POST", body: ["email": email, "password": password], authenticated: false)
        try TokenVault.save(response.token)
    }

    func foods(query: String = "") async throws -> [FoodDTO] {
        try await request("v1/foods?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")
    }

    func logout() async throws {
        let _: EmptyResponse = try await request("v1/auth/logout", method: "POST")
        TokenVault.clear()
    }

    private func request<Response: Decodable, Body: Encodable>(_ path: String, method: String = "GET", body: Body? = Optional<String>.none, authenticated: Bool = true) async throws -> Response {
        guard let baseURL, let url = URL(string: path, relativeTo: baseURL) else { throw BackendError.server(0, "Backend sync is not configured.") }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body { request.httpBody = try encoder.encode(body); request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        if authenticated, let token = TokenVault.load() { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw BackendError.invalidResponse }
        guard 200..<300 ~= http.statusCode else {
            let detail = (try? decoder.decode(APIError.self, from: data).detail) ?? "The request failed."
            throw BackendError.server(http.statusCode, detail)
        }
        if data.isEmpty, Response.self == EmptyResponse.self { return EmptyResponse() as! Response }
        return try decoder.decode(Response.self, from: data)
    }
}

private struct APIError: Decodable { let detail: String }
private struct EmptyResponse: Codable { init() {} }

enum BackendConfiguration {
    static var baseURL: URL? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "HJBackendBaseURL") as? String, !value.isEmpty else { return nil }
        return URL(string: value.hasSuffix("/") ? value : value + "/")
    }
}

enum TokenVault {
    private static let service = "com.habitatjourney.app"
    private static let account = "api-session"

    static func save(_ token: String) throws {
        clear()
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account, kSecValueData as String: Data(token.utf8), kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        guard SecItemAdd(query as CFDictionary, nil) == errSecSuccess else { throw BackendError.server(0, "The secure session could not be saved.") }
    }

    static func load() -> String? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account, kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func clear() {
        SecItemDelete([kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account] as CFDictionary)
    }
}
