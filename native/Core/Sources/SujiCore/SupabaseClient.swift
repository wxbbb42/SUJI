import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct SupabaseConfiguration: Sendable, Equatable {
    public let url: URL
    public let anonKey: String

    public init(url: URL, anonKey: String) {
        self.url = url
        self.anonKey = anonKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public init?(dictionary: [String: Any]) {
        guard let rawURL = (dictionary["SUPABASE_URL"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              let url = URL(string: rawURL),
              url.scheme?.lowercased() == "https",
              url.host != nil,
              url.user == nil, url.password == nil, url.query == nil, url.fragment == nil,
              let anonKey = dictionary["SUPABASE_ANON_KEY"] as? String,
              !anonKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        self.init(url: url, anonKey: anonKey)
    }
}

public struct SupabaseUser: Codable, Sendable, Equatable {
    public let id: String
    public let email: String?

    public init(id: String, email: String?) {
        self.id = id
        self.email = email
    }
}

public struct SupabaseAuthSession: Codable, Sendable, Equatable {
    public let accessToken: String
    public let refreshToken: String
    public let expiresIn: Int
    public let tokenType: String
    public let user: SupabaseUser

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
        case user
    }
}

public struct SupabaseSignUpResult: Sendable, Equatable {
    public let user: SupabaseUser?
    public let session: SupabaseAuthSession?
    public let requiresEmailConfirmation: Bool
}

public enum SupabaseRecoveryCallback: Sendable, Equatable {
    case authorizationCode(String)
    case accessToken(String)

    public init(url: URL) throws {
        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let fragmentItems = url.fragment.flatMap { fragment in
            URLComponents(string: "?" + fragment)?.queryItems
        } ?? []
        let values = (queryItems + fragmentItems).reduce(into: [String: String]()) { result, item in
            result[item.name] = item.value ?? ""
        }

        if let message = values["error_description"]?.nonEmpty ?? values["error"]?.nonEmpty {
            throw SupabaseClientError(message: message)
        }
        if let code = values["code"]?.nonEmpty {
            self = .authorizationCode(code)
            return
        }
        guard values["type"] == "recovery", let accessToken = values["access_token"]?.nonEmpty else {
            throw SupabaseClientError(message: "密码重置链接无效或已经过期。")
        }
        self = .accessToken(accessToken)
    }
}

public struct SupabaseProfile: Codable, Sendable, Equatable {
    public let id: String
    public let birthDate: String?
    public let gender: String?
    public let birthCity: String?
    public let birthLongitude: Double?
    public let apiProvider: String?
    public let apiModel: String?
    public let apiBaseURL: String?
    public let hasOnboarded: Bool
    public let createdAt: String
    public let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case birthDate = "birth_date"
        case gender
        case birthCity = "birth_city"
        case birthLongitude = "birth_longitude"
        case apiProvider = "api_provider"
        case apiModel = "api_model"
        case apiBaseURL = "api_base_url"
        case hasOnboarded = "has_onboarded"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

public struct SupabaseProfilePatch: Encodable, Sendable, Equatable {
    public var birthDate: String?
    public var gender: String?
    public var birthCity: String?
    public var birthLongitude: Double?
    public var apiProvider: String?
    public var apiModel: String?
    public var apiBaseURL: String?
    public var hasOnboarded: Bool?
    public var clearBirth: Bool

    public init(birthDate: String? = nil, gender: String? = nil, birthCity: String? = nil, birthLongitude: Double? = nil, apiProvider: String? = nil, apiModel: String? = nil, apiBaseURL: String? = nil, hasOnboarded: Bool? = nil, clearBirth: Bool = false) {
        self.birthDate = birthDate
        self.gender = gender
        self.birthCity = birthCity
        self.birthLongitude = birthLongitude
        self.apiProvider = apiProvider
        self.apiModel = apiModel
        self.apiBaseURL = apiBaseURL
        self.hasOnboarded = hasOnboarded
        self.clearBirth = clearBirth
    }

    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        if clearBirth {
            for key in [CodingKeys.birthDate, .gender, .birthCity, .birthLongitude] { try values.encodeNil(forKey: key) }
        } else {
            try values.encodeIfPresent(birthDate, forKey: .birthDate)
            try values.encodeIfPresent(gender, forKey: .gender)
            try values.encodeIfPresent(birthCity, forKey: .birthCity)
            try values.encodeIfPresent(birthLongitude, forKey: .birthLongitude)
        }
        try values.encodeIfPresent(apiProvider, forKey: .apiProvider)
        try values.encodeIfPresent(apiModel, forKey: .apiModel)
        try values.encodeIfPresent(apiBaseURL, forKey: .apiBaseURL)
        try values.encodeIfPresent(hasOnboarded, forKey: .hasOnboarded)
    }

    enum CodingKeys: String, CodingKey {
        case birthDate = "birth_date"
        case gender
        case birthCity = "birth_city"
        case birthLongitude = "birth_longitude"
        case apiProvider = "api_provider"
        case apiModel = "api_model"
        case apiBaseURL = "api_base_url"
        case hasOnboarded = "has_onboarded"
    }
}

public struct SupabaseClientError: LocalizedError, Sendable, Equatable {
    public let statusCode: Int?
    public let code: String?
    public let message: String
    public var errorDescription: String? { message }

    public init(statusCode: Int? = nil, code: String? = nil, message: String) {
        self.statusCode = statusCode
        self.code = code
        self.message = message
    }
}

public final class SupabaseClient: @unchecked Sendable {
    public let configuration: SupabaseConfiguration
    private let session: URLSession

    public init(configuration: SupabaseConfiguration, session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session
    }

    public func signUp(email: String, password: String) async throws -> SupabaseSignUpResult {
        let data = try await request(path: "auth/v1/signup", method: "POST", body: Credentials(email: email, password: password))
        if let session = try? JSONDecoder().decode(SupabaseAuthSession.self, from: data) {
            return SupabaseSignUpResult(user: session.user, session: session, requiresEmailConfirmation: false)
        }
        let response = try JSONDecoder().decode(SignUpResponse.self, from: data)
        return SupabaseSignUpResult(user: response.user, session: response.session, requiresEmailConfirmation: response.session == nil)
    }

    public func signIn(email: String, password: String) async throws -> SupabaseAuthSession {
        let query = [URLQueryItem(name: "grant_type", value: "password")]
        let data = try await request(path: "auth/v1/token", query: query, method: "POST", body: Credentials(email: email, password: password))
        return try decodeSession(data)
    }

    public func resetPassword(email: String, redirectURL: URL? = nil, codeChallenge: String? = nil) async throws {
        var query: [URLQueryItem] = []
        if let redirectURL { query.append(URLQueryItem(name: "redirect_to", value: redirectURL.absoluteString)) }
        _ = try await request(
            path: "auth/v1/recover",
            query: query,
            method: "POST",
            body: Recovery(email: email, codeChallenge: codeChallenge, codeChallengeMethod: codeChallenge == nil ? nil : "s256")
        )
    }

    public func authorizationURL(provider: String, redirectURL: URL, codeChallenge: String) throws -> URL {
        guard provider == "google", !codeChallenge.isEmpty else {
            throw SupabaseClientError(message: "不支持这个登录方式。")
        }
        return try endpoint(path: "auth/v1/authorize", query: [
            URLQueryItem(name: "provider", value: provider),
            URLQueryItem(name: "redirect_to", value: redirectURL.absoluteString),
            URLQueryItem(name: "flow_type", value: "pkce"),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "s256")
        ])
    }

    public func exchangeCode(_ code: String, verifier: String) async throws -> SupabaseAuthSession {
        let data = try await request(path: "auth/v1/token", query: [URLQueryItem(name: "grant_type", value: "pkce")], method: "POST", body: PKCEExchange(authCode: code, codeVerifier: verifier))
        return try decodeSession(data)
    }

    public func refresh(refreshToken: String) async throws -> SupabaseAuthSession {
        let data = try await request(path: "auth/v1/token", query: [URLQueryItem(name: "grant_type", value: "refresh_token")], method: "POST", body: Refresh(refreshToken: refreshToken))
        return try decodeSession(data)
    }

    public func signOut(accessToken: String) async throws {
        _ = try await request(path: "auth/v1/logout", method: "POST", accessToken: accessToken)
    }

    public func user(accessToken: String) async throws -> SupabaseUser {
        let data = try await request(path: "auth/v1/user", method: "GET", accessToken: accessToken)
        return try JSONDecoder().decode(SupabaseUser.self, from: data)
    }

    public func updatePassword(_ password: String, accessToken: String) async throws -> SupabaseUser {
        let data = try await request(path: "auth/v1/user", method: "PUT", body: PasswordUpdate(password: password), accessToken: accessToken)
        return try JSONDecoder().decode(SupabaseUser.self, from: data)
    }

    public func fetchProfile(userID: String, accessToken: String) async throws -> SupabaseProfile? {
        let data = try await request(path: "rest/v1/profiles", query: [
            URLQueryItem(name: "id", value: "eq.\(userID)"),
            URLQueryItem(name: "select", value: "*")
        ], method: "GET", accessToken: accessToken)
        let profiles = try JSONDecoder().decode([SupabaseProfile].self, from: data)
        guard profiles.count <= 1 else { throw SupabaseClientError(message: "云端返回了重复的个人资料。") }
        return profiles.first
    }

    public func upsertProfile(userID: String, patch: SupabaseProfilePatch, accessToken: String) async throws -> SupabaseProfile {
        let body = ProfileUpsert(id: userID, patch: patch)
        let data = try await request(path: "rest/v1/profiles", query: [
            URLQueryItem(name: "on_conflict", value: "id"),
            URLQueryItem(name: "select", value: "*")
        ], method: "POST", body: body, accessToken: accessToken, additionalHeaders: ["Prefer": "resolution=merge-duplicates,return=representation"])
        guard let profile = try JSONDecoder().decode([SupabaseProfile].self, from: data).first else {
            throw SupabaseClientError(message: "云端没有返回保存后的个人资料。")
        }
        return profile
    }

    private func decodeSession(_ data: Data) throws -> SupabaseAuthSession {
        do { return try JSONDecoder().decode(SupabaseAuthSession.self, from: data) }
        catch { throw SupabaseClientError(message: "登录服务返回了无法识别的会话。") }
    }

    private func endpoint(path: String, query: [URLQueryItem] = []) throws -> URL {
        var url = configuration.url
        guard url.scheme?.lowercased() == "https", url.host != nil,
              url.user == nil, url.password == nil, url.query == nil, url.fragment == nil else {
            throw SupabaseClientError(message: "账户服务必须使用不含凭据或查询参数的 HTTPS 地址。")
        }
        guard !configuration.anonKey.isEmpty else { throw SupabaseClientError(message: "账户服务缺少公开访问密钥。") }
        for component in path.split(separator: "/") { url.appendPathComponent(String(component)) }
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw SupabaseClientError(message: "账户服务地址无效。")
        }
        if !query.isEmpty { components.queryItems = query }
        guard let result = components.url else { throw SupabaseClientError(message: "账户服务地址无效。") }
        return result
    }

    private func request(path: String, query: [URLQueryItem] = [], method: String, accessToken: String? = nil, additionalHeaders: [String: String] = [:]) async throws -> Data {
        var request = URLRequest(url: try endpoint(path: path, query: query))
        request.httpMethod = method
        request.setValue(configuration.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let accessToken { request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization") }
        for (name, value) in additionalHeaders { request.setValue(value, forHTTPHeaderField: name) }
        return try await perform(request)
    }

    private func request<Body: Encodable>(path: String, query: [URLQueryItem] = [], method: String, body: Body, accessToken: String? = nil, additionalHeaders: [String: String] = [:]) async throws -> Data {
        var request = URLRequest(url: try endpoint(path: path, query: query))
        request.httpMethod = method
        request.setValue(configuration.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let accessToken { request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization") }
        for (name, value) in additionalHeaders { request.setValue(value, forHTTPHeaderField: name) }
        request.httpBody = try JSONEncoder().encode(body)
        return try await perform(request)
    }

    private func perform(_ request: URLRequest) async throws -> Data {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw SupabaseClientError(message: "账户服务没有返回有效响应。") }
            guard (200..<300).contains(http.statusCode) else { throw error(from: data, statusCode: http.statusCode) }
            return data
        } catch let error as SupabaseClientError { throw error }
        catch is CancellationError { throw CancellationError() }
        catch { throw SupabaseClientError(message: "无法连接账户服务：\(error.localizedDescription)") }
    }

    private func error(from data: Data, statusCode: Int) -> SupabaseClientError {
        let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        let code = object?["error_code"] as? String ?? object?["code"] as? String ?? object?["error"] as? String
        let message = object?["msg"] as? String ?? object?["message"] as? String ?? object?["error_description"] as? String
        return SupabaseClientError(statusCode: statusCode, code: code, message: (message?.isEmpty == false ? message : nil) ?? "账户服务请求失败（HTTP \(statusCode)）。")
    }
}

private struct Credentials: Encodable { let email: String; let password: String }
private struct Recovery: Encodable {
    let email: String
    let codeChallenge: String?
    let codeChallengeMethod: String?
    enum CodingKeys: String, CodingKey {
        case email
        case codeChallenge = "code_challenge"
        case codeChallengeMethod = "code_challenge_method"
    }
}
private struct PasswordUpdate: Encodable { let password: String }
private struct Refresh: Encodable {
    let refreshToken: String
    enum CodingKeys: String, CodingKey { case refreshToken = "refresh_token" }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
private struct PKCEExchange: Encodable {
    let authCode: String
    let codeVerifier: String
    enum CodingKeys: String, CodingKey { case authCode = "auth_code"; case codeVerifier = "code_verifier" }
}
private struct SignUpResponse: Decodable { let user: SupabaseUser?; let session: SupabaseAuthSession? }

private struct ProfileUpsert: Encodable {
    let id: String
    let patch: SupabaseProfilePatch

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        if let value = patch.birthDate { try container.encode(value, forKey: .birthDate) } else { try container.encodeNil(forKey: .birthDate) }
        if let value = patch.gender { try container.encode(value, forKey: .gender) } else { try container.encodeNil(forKey: .gender) }
        if let value = patch.birthCity { try container.encode(value, forKey: .birthCity) } else { try container.encodeNil(forKey: .birthCity) }
        if let value = patch.birthLongitude { try container.encode(value, forKey: .birthLongitude) } else { try container.encodeNil(forKey: .birthLongitude) }
        if let value = patch.apiProvider { try container.encode(value, forKey: .apiProvider) } else { try container.encodeNil(forKey: .apiProvider) }
        if let value = patch.apiModel { try container.encode(value, forKey: .apiModel) } else { try container.encodeNil(forKey: .apiModel) }
        if let value = patch.apiBaseURL { try container.encode(value, forKey: .apiBaseURL) } else { try container.encodeNil(forKey: .apiBaseURL) }
        if let value = patch.hasOnboarded { try container.encode(value, forKey: .hasOnboarded) } else { try container.encodeNil(forKey: .hasOnboarded) }
    }

    enum CodingKeys: String, CodingKey {
        case id
        case birthDate = "birth_date"
        case gender
        case birthCity = "birth_city"
        case birthLongitude = "birth_longitude"
        case apiProvider = "api_provider"
        case apiModel = "api_model"
        case apiBaseURL = "api_base_url"
        case hasOnboarded = "has_onboarded"
    }
}
