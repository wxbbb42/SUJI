import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest
@testable import SujiCore

final class SupabaseClientTests: XCTestCase {
    override func tearDown() {
        TestURLProtocol.handler = nil
        super.tearDown()
    }

    func testPasswordSignInBuildsRequestAndDecodesSession() async throws {
        let client = makeClient { request in
            XCTAssertEqual(request.url?.absoluteString, "https://project.supabase.co/auth/v1/token?grant_type=password")
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "apikey"), "anon-key")
            let body = try requestBody(request).jsonObject
            XCTAssertEqual(body["email"] as? String, "a@example.com")
            XCTAssertEqual(body["password"] as? String, "correct horse")
            return Self.response(request, status: 200, json: [
                "access_token": "access", "refresh_token": "refresh", "expires_in": 3600,
                "token_type": "bearer", "user": ["id": "user-1", "email": "a@example.com"]
            ])
        }
        let session = try await client.signIn(email: "a@example.com", password: "correct horse")
        XCTAssertEqual(session.accessToken, "access")
        XCTAssertEqual(session.refreshToken, "refresh")
        XCTAssertEqual(session.user.id, "user-1")
    }

    func testConfigurationRejectsInsecureOrCredentialBearingPublicURLs() throws {
        XCTAssertNil(SupabaseConfiguration(dictionary: ["SUPABASE_URL": "http://project.supabase.co", "SUPABASE_ANON_KEY": "anon-key"]))
        XCTAssertNil(SupabaseConfiguration(dictionary: ["SUPABASE_URL": "https://user:pass@project.supabase.co", "SUPABASE_ANON_KEY": "anon-key"]))

        let client = SupabaseClient(configuration: SupabaseConfiguration(url: try XCTUnwrap(URL(string: "http://project.supabase.co")), anonKey: "anon-key"))
        XCTAssertThrowsError(try client.authorizationURL(
            provider: "google",
            redirectURL: XCTUnwrap(URL(string: "suji-native://auth/callback")),
            codeChallenge: "challenge"
        ))
    }

    func testRefreshUsesRefreshTokenAndReturnsRotatedTokens() async throws {
        let client = makeClient { request in
            XCTAssertEqual(request.url?.query, "grant_type=refresh_token")
            XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
            XCTAssertEqual(try requestBody(request).jsonObject["refresh_token"] as? String, "old-refresh")
            return Self.response(request, status: 200, json: [
                "access_token": "new-access", "refresh_token": "new-refresh", "expires_in": 7200,
                "token_type": "bearer", "user": ["id": "user-1", "email": "a@example.com"]
            ])
        }
        let session = try await client.refresh(refreshToken: "old-refresh")
        XCTAssertEqual(session.accessToken, "new-access")
        XCTAssertEqual(session.refreshToken, "new-refresh")
    }

    func testProfileReadAndUpsertUseExistingProfilesSchema() async throws {
        var requests = 0
        let client = makeClient { request in
            requests += 1
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer access")
            if request.httpMethod == "GET" {
                XCTAssertTrue(request.url?.absoluteString.contains("/rest/v1/profiles?") == true)
                XCTAssertTrue(request.url?.absoluteString.contains("id=eq.user-1") == true)
                return Self.response(request, status: 200, json: [[
                    "id": "user-1", "birth_date": NSNull(), "gender": NSNull(), "birth_city": NSNull(),
                    "birth_longitude": NSNull(), "api_provider": NSNull(), "api_model": "gpt-4.1-mini",
                    "api_base_url": "https://api.openai.com/v1", "has_onboarded": true,
                    "created_at": "2026-01-01T00:00:00Z", "updated_at": "2026-01-01T00:00:00Z"
                ]])
            }
            XCTAssertEqual(request.value(forHTTPHeaderField: "Prefer"), "resolution=merge-duplicates,return=representation")
            let body = try requestBody(request).jsonObject
            XCTAssertEqual(body["id"] as? String, "user-1")
            XCTAssertTrue(body["birth_date"] is NSNull)
            XCTAssertNil(body["api_key"])
            XCTAssertNil(body["conversations"])
            return Self.response(request, status: 201, json: [[
                "id": "user-1", "birth_date": NSNull(), "gender": NSNull(), "birth_city": NSNull(),
                "birth_longitude": NSNull(), "api_provider": "custom", "api_model": "model",
                "api_base_url": "https://example.com/v1", "has_onboarded": true,
                "created_at": "2026-01-01T00:00:00Z", "updated_at": "2026-01-01T00:00:00Z"
            ]])
        }
        let profile = try await client.fetchProfile(userID: "user-1", accessToken: "access")
        XCTAssertEqual(profile?.apiModel, "gpt-4.1-mini")
        let updated = try await client.upsertProfile(userID: "user-1", patch: .init(apiProvider: "custom", apiModel: "model", apiBaseURL: "https://example.com/v1", hasOnboarded: true), accessToken: "access")
        XCTAssertEqual(updated.apiProvider, "custom")
        XCTAssertEqual(requests, 2)
    }

    func testErrorBodyIsSurfacedWithoutLeakingRequestCredential() async throws {
        let client = makeClient { request in
            Self.response(request, status: 400, json: ["error_code": "invalid_credentials", "msg": "Email or password is wrong"])
        }
        do {
            _ = try await client.signIn(email: "a@example.com", password: "do-not-echo")
            XCTFail("Expected failure")
        } catch let error as SupabaseClientError {
            XCTAssertEqual(error.statusCode, 400)
            XCTAssertTrue(error.localizedDescription.contains("Email or password is wrong"))
            XCTAssertFalse(error.localizedDescription.contains("do-not-echo"))
        }
    }

    func testPKCEAuthorizationAndExchangePreserveRedirectAndVerifier() async throws {
        let client = makeClient { request in
            XCTAssertEqual(request.url?.query, "grant_type=pkce")
            let body = try requestBody(request).jsonObject
            XCTAssertEqual(body["auth_code"] as? String, "returned-code")
            XCTAssertEqual(body["code_verifier"] as? String, "verifier-value")
            return Self.response(request, status: 200, json: [
                "access_token": "access", "refresh_token": "refresh", "expires_in": 3600,
                "token_type": "bearer", "user": ["id": "user-1", "email": "a@example.com"]
            ])
        }
        let redirect = try XCTUnwrap(URL(string: "suji-native://auth/callback"))
        let url = try client.authorizationURL(provider: "google", redirectURL: redirect, codeChallenge: "challenge")
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        XCTAssertEqual(query["provider"], "google")
        XCTAssertEqual(query["redirect_to"], redirect.absoluteString)
        XCTAssertEqual(query["flow_type"], "pkce")
        XCTAssertEqual(query["code_challenge"], "challenge")
        XCTAssertEqual(query["code_challenge_method"], "s256")
        _ = try await client.exchangeCode("returned-code", verifier: "verifier-value")
    }

    func testPasswordRecoveryUsesRedirectQueryAndPKCEBody() async throws {
        let client = makeClient { request in
            XCTAssertEqual(request.url?.path, "/auth/v1/recover")
            XCTAssertEqual(request.url?.query, "redirect_to=suji-native://auth/reset")
            let body = try requestBody(request).jsonObject
            XCTAssertEqual(body["email"] as? String, "a@example.com")
            XCTAssertEqual(body["code_challenge"] as? String, "challenge")
            XCTAssertEqual(body["code_challenge_method"] as? String, "s256")
            XCTAssertNil(body["redirect_to"])
            return Self.response(request, status: 200, json: [:])
        }

        try await client.resetPassword(
            email: "a@example.com",
            redirectURL: try XCTUnwrap(URL(string: "suji-native://auth/reset")),
            codeChallenge: "challenge"
        )
    }

    func testRecoveryCallbackAcceptsPKCEOrRecoveryTokenAndRejectsOtherLinks() throws {
        XCTAssertEqual(
            try SupabaseRecoveryCallback(url: XCTUnwrap(URL(string: "suji-native://auth/reset?code=returned-code"))),
            .authorizationCode("returned-code")
        )
        XCTAssertEqual(
            try SupabaseRecoveryCallback(url: XCTUnwrap(URL(string: "suji-native://auth/reset#type=recovery&access_token=recovery-token"))),
            .accessToken("recovery-token")
        )
        XCTAssertThrowsError(
            try SupabaseRecoveryCallback(url: XCTUnwrap(URL(string: "suji-native://auth/reset#type=signup&access_token=wrong-token")))
        )
    }

    func testRecoveryCredentialVerifiesUserAndUpdatesPassword() async throws {
        var requests = 0
        let client = makeClient { request in
            requests += 1
            XCTAssertEqual(request.url?.path, "/auth/v1/user")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer recovery-token")
            if request.httpMethod == "GET" {
                return Self.response(request, status: 200, json: ["id": "user-1", "email": "a@example.com"])
            }
            XCTAssertEqual(request.httpMethod, "PUT")
            XCTAssertEqual(try requestBody(request).jsonObject["password"] as? String, "new-password")
            return Self.response(request, status: 200, json: ["id": "user-1", "email": "a@example.com"])
        }

        let verified = try await client.user(accessToken: "recovery-token")
        let updated = try await client.updatePassword("new-password", accessToken: "recovery-token")
        XCTAssertEqual(verified, updated)
        XCTAssertEqual(requests, 2)
    }

    private func makeClient(handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)) -> SupabaseClient {
        TestURLProtocol.handler = handler
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [TestURLProtocol.self]
        return SupabaseClient(configuration: SupabaseConfiguration(url: URL(string: "https://project.supabase.co")!, anonKey: "anon-key"), session: URLSession(configuration: configuration))
    }

    private static func response(_ request: URLRequest, status: Int, json: Any) -> (HTTPURLResponse, Data) {
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        return (response, try! JSONSerialization.data(withJSONObject: json))
    }
}

private final class TestURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let (response, data) = try XCTUnwrap(Self.handler)(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}

private extension Data {
    var jsonObject: [String: Any] {
        get throws { try XCTUnwrap(JSONSerialization.jsonObject(with: self) as? [String: Any]) }
    }
}

private func requestBody(_ request: URLRequest) throws -> Data {
    if let data = request.httpBody { return data }
    guard let stream = request.httpBodyStream else { throw XCTSkip("URLProtocol did not expose the request body") }
    stream.open()
    defer { stream.close() }
    var output = Data()
    var buffer = [UInt8](repeating: 0, count: 4_096)
    while stream.hasBytesAvailable {
        let count = stream.read(&buffer, maxLength: buffer.count)
        if count <= 0 { break }
        output.append(buffer, count: count)
    }
    return output
}
