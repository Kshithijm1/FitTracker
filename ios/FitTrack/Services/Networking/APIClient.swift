import Foundation

enum APIError: Error {
    case unauthorized
    case server(status: Int, message: String)
    case decoding
    case transport(Error)
}

/// Thin JSON/HTTP client for the Fastify backend. Handles the access-token
/// header and a single transparent refresh-and-retry on 401 so callers
/// (AuthService, SyncEngine) never deal with token expiry directly.
@MainActor
final class APIClient {
    static let shared = APIClient()

    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    /// Set by `AuthService` on sign-in/refresh; read on every authenticated request.
    var accessTokenProvider: (() -> String?)?
    var onUnauthorizedRetry: (() async -> Bool)? // returns true if refresh succeeded

    private init(session: URLSession = .shared) {
        self.session = session

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func request<Response: Decodable>(
        _ method: String,
        _ path: String,
        body: (some Encodable)? = Optional<EmptyBody>.none,
        authenticated: Bool = false,
        allowRetry: Bool = true
    ) async throws -> Response {
        var request = URLRequest(url: BackendConfig.baseURL.appendingPathComponent(path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body {
            request.httpBody = try encoder.encode(body)
        }
        if authenticated, let token = accessTokenProvider?() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.transport(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.decoding
        }

        if http.statusCode == 401, authenticated, allowRetry, let retryHandler = onUnauthorizedRetry {
            let refreshed = await retryHandler()
            if refreshed {
                return try await self.request(method, path, body: body, authenticated: authenticated, allowRetry: false)
            }
            throw APIError.unauthorized
        }

        guard (200..<300).contains(http.statusCode) else {
            let message = (try? decoder.decode(ErrorBody.self, from: data))?.error ?? "Request failed"
            throw APIError.server(status: http.statusCode, message: message)
        }

        if Response.self == EmptyResponse.self {
            return EmptyResponse() as! Response
        }
        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw APIError.decoding
        }
    }
}

struct EmptyBody: Encodable {}
struct EmptyResponse: Decodable {}
private struct ErrorBody: Decodable { let error: String }
