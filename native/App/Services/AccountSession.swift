import AuthenticationServices
import CryptoKit
import Foundation
import Observation
import Security
import SujiCore
import UIKit

@MainActor @Observable final class AccountSession: NSObject {
    typealias ScopeTransition = @MainActor (_ previousUserID: String?, _ nextUserID: String?) async throws -> Void

    enum Availability: Equatable {
        case localOnly
        case signedOut
        case signedIn
    }

    private(set) var availability: Availability
    private(set) var user: SupabaseUser?
    private(set) var pendingUser: SupabaseUser?
    private(set) var busy = false
    var error: String?
    var notice: String?

    var isConfigured: Bool { client != nil }
    var hasPendingAccountChange: Bool { pendingSession != nil }

    static let recoveryVerifierKey = "supabase-recovery-verifier"

    static func restoredUserID(bundle: Bundle = .main) -> String? {
        guard configuration(in: bundle) != nil else { return nil }
        let stored: String?
        do { stored = try KeychainStore.read("supabase-session") }
        catch { return nil }
        guard let value = stored,
              let data = value.data(using: .utf8),
              let record = try? JSONDecoder().decode(StoredAccountSession.self, from: data) else { return nil }
        return record.user.id
    }

    private let client: SupabaseClient?
    private let onScopeTransition: ScopeTransition
    private var accessTokenValue: String?
    private var refreshTokenValue: String?
    private var expiresAt: Date?
    private var pendingSession: SupabaseAuthSession?
    private var browserSession: ASWebAuthenticationSession?
    private let presentationAnchor = BrowserPresentationAnchor()

    init(bundle: Bundle = .main, urlSession: URLSession = .shared, onScopeTransition: @escaping ScopeTransition) {
        self.onScopeTransition = onScopeTransition
        if let configuration = Self.configuration(in: bundle) {
            client = SupabaseClient(configuration: configuration, session: urlSession)
            availability = .signedOut
        } else {
            client = nil
            availability = .localOnly
        }
        super.init()
        restoreLocalSession()
    }

    func initialize() async {
        guard isConfigured, user != nil else { return }
        do { _ = try await validAccessToken() }
        catch let failure as SupabaseClientError where failure.statusCode == 400 || failure.statusCode == 401 {
            do {
                try await leaveAccountScope(userID: user?.id)
                self.error = "登录已过期，请重新登录。"
            } catch { self.error = "登录已过期，但无法安全切换回本地册页：\(error.localizedDescription)" }
        } catch {
            self.error = "暂时无法刷新登录。已保留当前账户与本机册页，可稍后重试。\n\(error.localizedDescription)"
        }
    }

    func signIn(email: String, password: String) async {
        await run {
            let client = try self.configuredClient()
            let session = try await client.signIn(email: try self.validEmail(email), password: try self.validPassword(password))
            try await self.stage(session)
        }
    }

    func signUp(email: String, password: String) async {
        await run {
            let client = try self.configuredClient()
            let result = try await client.signUp(email: try self.validEmail(email), password: try self.validPassword(password))
            if let session = result.session {
                try await self.stage(session)
            } else {
                self.notice = "注册邮件已发送。请先在邮箱中完成确认，再回来登录。"
            }
        }
    }

    func sendPasswordReset(email: String) async {
        await run {
            let verifier = Self.codeVerifier()
            let previousVerifier = try KeychainStore.read(Self.recoveryVerifierKey)
            try KeychainStore.write(verifier, name: Self.recoveryVerifierKey)
            do {
                try await self.configuredClient().resetPassword(
                    email: try self.validEmail(email),
                    redirectURL: URL(string: "suji-native://auth/reset"),
                    codeChallenge: Self.codeChallenge(for: verifier)
                )
            } catch {
                do { try KeychainStore.write(previousVerifier, name: Self.recoveryVerifierKey) }
                catch { throw AccountFailure("重置邮件未发送，且无法恢复之前的安全校验信息。请重新发起密码重置。") }
                throw error
            }
            self.notice = "密码重置邮件已发送。请在这台设备上打开邮件链接，回到 App 设置新密码。"
        }
    }

    func signInWithGoogle() async {
        await run {
            let client = try self.configuredClient()
            let verifier = Self.codeVerifier()
            let challenge = Self.codeChallenge(for: verifier)
            let callback = URL(string: "suji-native://auth/callback")!
            let authorizationURL = try client.authorizationURL(provider: "google", redirectURL: callback, codeChallenge: challenge)
            let responseURL = try await self.openBrowser(url: authorizationURL, callbackScheme: callback.scheme!)
            guard responseURL.scheme?.lowercased() == callback.scheme?.lowercased(),
                  responseURL.host?.lowercased() == callback.host?.lowercased(),
                  responseURL.path == callback.path else {
                throw AccountFailure("Google 登录返回了无效的回调地址。")
            }
            let components = URLComponents(url: responseURL, resolvingAgainstBaseURL: false)
            let items = (components?.queryItems ?? []).reduce(into: [String: String]()) { result, item in
                result[item.name] = item.value ?? ""
            }
            if let message = items["error_description"] ?? items["error"] { throw AccountFailure(message) }
            guard let code = items["code"], !code.isEmpty else { throw AccountFailure("Google 登录没有返回授权码。") }
            try await self.stage(try await client.exchangeCode(code, verifier: verifier))
        }
    }

    func confirmPendingAccountChange() async {
        await run {
            guard let pendingSession = self.pendingSession else { return }
            let previousUserID = self.user?.id
            try await self.onScopeTransition(previousUserID, pendingSession.user.id)
            do {
                try self.persist(pendingSession)
            } catch {
                do { try await self.onScopeTransition(pendingSession.user.id, previousUserID) }
                catch { throw AccountFailure("钥匙串保存失败，且无法恢复之前的册页空间。请重新打开 App 后检查资料。") }
                throw error
            }
            self.pendingSession = nil
            self.pendingUser = nil
            self.notice = "已切换到 \(pendingSession.user.email ?? "这个账户")。"
        }
    }

    func cancelPendingAccountChange() async {
        guard let pendingSession else { return }
        self.pendingSession = nil
        pendingUser = nil
        try? await client?.signOut(accessToken: pendingSession.accessToken)
    }

    func signOut() async {
        await run {
            guard let user = self.user else { return }
            let token = self.accessTokenValue
            try await self.leaveAccountScope(userID: user.id)
            let remoteFailure: Error?
            if let token {
                do { try await self.configuredClient().signOut(accessToken: token); remoteFailure = nil }
                catch { remoteFailure = error }
            } else { remoteFailure = nil }
            self.notice = remoteFailure == nil
                ? "已退出账户，本机册页已切换到本地空间。"
                : "本机已退出并切换到本地册页。云端注销暂时未完成，服务端令牌会按有效期失效。"
        }
    }

    func fetchProfile() async throws -> SupabaseProfile? {
        guard let user else { throw AccountFailure("请先登录。") }
        let token = try await validAccessToken()
        return try await configuredClient().fetchProfile(userID: user.id, accessToken: token)
    }

    func pushProfile(from state: AppState) async throws -> SupabaseProfile {
        guard let user else { throw AccountFailure("请先登录。") }
        let patch = SupabaseProfilePatch(
            birthDate: state.birth?.date.map { ISO8601DateFormatter().string(from: $0) },
            gender: state.birth?.gender,
            birthCity: state.birth?.city,
            birthLongitude: state.birth?.longitude,
            apiProvider: Self.provider(for: state.providerURL),
            apiModel: state.model,
            apiBaseURL: state.providerURL,
            hasOnboarded: state.hasOnboarded
        )
        let token = try await validAccessToken()
        return try await configuredClient().upsertProfile(userID: user.id, patch: patch, accessToken: token)
    }

    func applying(_ profile: SupabaseProfile, to current: AppState) throws -> AppState {
        guard profile.id == user?.id else { throw AccountFailure("这份云端资料不属于当前账户。") }
        var updated = current
        let birth = try Self.birth(from: profile)
        if updated.birth != birth {
            updated.previousBirth = updated.birth
            updated.birth = birth
        }
        updated.hasOnboarded = profile.hasOnboarded
        updated.providerURL = profile.apiBaseURL.flatMap { $0.nilIfBlank } ?? "https://api.openai.com/v1"
        updated.model = profile.apiModel.flatMap { $0.nilIfBlank } ?? "gpt-4.1-mini"
        return updated
    }

    private func stage(_ session: SupabaseAuthSession) async throws {
        if session.user.id == user?.id {
            try persist(session)
            notice = "登录已更新。"
        } else {
            pendingSession = session
            pendingUser = session.user
        }
    }

    private func validAccessToken() async throws -> String {
        if let accessTokenValue, let expiresAt, expiresAt.timeIntervalSinceNow > 60 { return accessTokenValue }
        guard let refreshTokenValue else { throw AccountFailure("登录已过期，请重新登录。") }
        let session = try await configuredClient().refresh(refreshToken: refreshTokenValue)
        guard session.user.id == user?.id else { throw AccountFailure("刷新后的账户身份不一致。") }
        try persist(session)
        return session.accessToken
    }

    private func persist(_ session: SupabaseAuthSession) throws {
        let expiry = Date().addingTimeInterval(TimeInterval(session.expiresIn))
        let record = StoredAccountSession(accessToken: session.accessToken, refreshToken: session.refreshToken, expiresAt: expiry.timeIntervalSince1970, user: session.user)
        let encoded = try JSONEncoder().encode(record)
        guard let value = String(data: encoded, encoding: .utf8) else { throw AccountFailure("无法保存登录会话。") }
        // One Keychain value prevents a rotated access token from being paired
        // with an old refresh token or user identifier after a partial write.
        try KeychainStore.write(value, name: "supabase-session")
        accessTokenValue = session.accessToken
        refreshTokenValue = session.refreshToken
        expiresAt = expiry
        user = session.user
        availability = .signedIn
    }

    private func restoreLocalSession() {
        guard client != nil else { return }
        do {
            guard let value = try KeychainStore.read("supabase-session") else { return }
            guard let data = value.data(using: .utf8),
                  let record = try? JSONDecoder().decode(StoredAccountSession.self, from: data) else {
                throw AccountFailure("本机登录会话已损坏，请重新登录。")
            }
            accessTokenValue = record.accessToken
            refreshTokenValue = record.refreshToken
            expiresAt = Date(timeIntervalSince1970: record.expiresAt)
            user = record.user
            availability = .signedIn
        } catch { self.error = error.localizedDescription }
    }

    private func leaveAccountScope(userID: String?) async throws {
        try await onScopeTransition(userID, nil)
        do { try clearStoredSession() }
        catch {
            do { try await onScopeTransition(nil, userID) }
            catch { throw AccountFailure("钥匙串更新失败，且无法恢复账户册页空间。请重新打开 App 后检查资料。") }
            throw error
        }
    }

    private func clearStoredSession() throws {
        try KeychainStore.write(nil, name: "supabase-session")
        accessTokenValue = nil
        refreshTokenValue = nil
        expiresAt = nil
        user = nil
        pendingSession = nil
        pendingUser = nil
        availability = client == nil ? .localOnly : .signedOut
    }

    private func configuredClient() throws -> SupabaseClient {
        guard let client else { throw AccountFailure("此版本没有配置账户服务，所有内容只保存在本机。") }
        return client
    }

    private func validEmail(_ value: String) throws -> String {
        let email = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard email.contains("@"), !email.contains(" ") else { throw AccountFailure("请填写有效的邮箱地址。") }
        return email
    }

    private func validPassword(_ value: String) throws -> String {
        guard value.count >= 6 else { throw AccountFailure("密码至少需要 6 位。") }
        return value
    }

    private func run(_ operation: () async throws -> Void) async {
        guard !busy else { return }
        busy = true
        error = nil
        notice = nil
        defer { busy = false }
        do { try await operation() }
        catch ASWebAuthenticationSessionError.canceledLogin { }
        catch { self.error = error.localizedDescription }
    }

    private func openBrowser(url: URL, callbackScheme: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackScheme) { [weak self] url, error in
                self?.browserSession = nil
                if let error { continuation.resume(throwing: error) }
                else if let url { continuation.resume(returning: url) }
                else { continuation.resume(throwing: AccountFailure("登录窗口没有返回结果。")) }
            }
            session.presentationContextProvider = presentationAnchor
            session.prefersEphemeralWebBrowserSession = true
            browserSession = session
            guard session.start() else {
                browserSession = nil
                continuation.resume(throwing: AccountFailure("无法打开安全登录窗口。"))
                return
            }
        }
    }

    static func configuration(in bundle: Bundle) -> SupabaseConfiguration? {
        guard let url = bundle.url(forResource: "PublicConfig", withExtension: "plist"),
              let dictionary = NSDictionary(contentsOf: url) as? [String: Any] else { return nil }
        return SupabaseConfiguration(dictionary: dictionary)
    }

    private static func provider(for url: String) -> String {
        let host = URL(string: url)?.host?.lowercased() ?? ""
        if host.contains("openai") { return "openai" }
        if host.contains("deepseek") { return "deepseek" }
        return "custom"
    }

    private static func birth(from profile: SupabaseProfile) throws -> BirthProfile? {
        let values: [Any?] = [profile.birthDate, profile.gender, profile.birthCity, profile.birthLongitude]
        guard values.contains(where: { $0 != nil }) else { return nil }
        guard let rawDate = profile.birthDate,
              let date = ISO8601DateFormatter.accountFractional.date(from: rawDate) ?? ISO8601DateFormatter().date(from: rawDate),
              let gender = profile.gender,
              let city = profile.birthCity,
              let longitude = profile.birthLongitude else { throw AccountFailure("云端出生资料不完整，未覆盖本机内容。") }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let c = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        guard let year = c.year, let month = c.month, let day = c.day, let hour = c.hour, let minute = c.minute else {
            throw AccountFailure("云端出生日期无法读取，未覆盖本机内容。")
        }
        return try BirthProfile(year: year, month: month, day: day, hour: hour, minute: minute, gender: gender, city: city, longitude: longitude).validated()
    }

    private static func codeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64URLEncoded
    }

    private static func codeChallenge(for verifier: String) -> String {
        Data(SHA256.hash(data: Data(verifier.utf8))).base64URLEncoded
    }
}

@MainActor @Observable final class PasswordRecoverySession {
    private(set) var user: SupabaseUser?
    private(set) var ready = false
    private(set) var completed = false
    private(set) var busy = false
    var error: String?

    private let callbackURL: URL
    private let client: SupabaseClient?
    private var accessToken: String?
    private var task: Task<Void, Never>?

    init(url: URL, bundle: Bundle = .main, urlSession: URLSession = .shared) {
        callbackURL = url
        client = AccountSession.configuration(in: bundle).map { SupabaseClient(configuration: $0, session: urlSession) }
    }

    func prepare() async {
        guard !busy, !ready, !completed else { return }
        guard callbackURL.scheme?.lowercased() == "suji-native",
              callbackURL.host?.lowercased() == "auth",
              callbackURL.path == "/reset" else {
            error = "这不是有效的密码重置链接。"
            return
        }
        guard let client else {
            error = "此安装包没有配置账户服务，无法完成密码重置。"
            return
        }

        busy = true
        error = nil
        let operation = Task { @MainActor in
            do {
                let callback = try SupabaseRecoveryCallback(url: callbackURL)
                let token: String
                let expectedUserID: String?
                switch callback {
                case let .authorizationCode(code):
                    guard let verifier = try KeychainStore.read(AccountSession.recoveryVerifierKey), !verifier.isEmpty else {
                        throw AccountFailure("这封重置邮件不是在当前设备上发起的，或安全校验已过期。请重新发送重置邮件。")
                    }
                    let session = try await client.exchangeCode(code, verifier: verifier)
                    try Task.checkCancellation()
                    token = session.accessToken
                    expectedUserID = session.user.id
                case let .accessToken(value):
                    token = value
                    expectedUserID = nil
                }

                let verifiedUser = try await client.user(accessToken: token)
                try Task.checkCancellation()
                if let expectedUserID, verifiedUser.id != expectedUserID {
                    throw AccountFailure("重置链接返回的账户身份不一致。")
                }
                try KeychainStore.write(nil, name: AccountSession.recoveryVerifierKey)
                accessToken = token
                user = verifiedUser
                ready = true
            } catch is CancellationError {
            } catch {
                self.error = error.localizedDescription
                accessToken = nil
                user = nil
                ready = false
            }
            busy = false
        }
        task = operation
        await operation.value
        task = nil
    }

    func updatePassword(_ password: String, confirmation: String) async {
        guard !busy, ready, let client, let accessToken, let user else { return }
        guard password.count >= 6 else { error = "密码至少需要 6 位。"; return }
        guard password == confirmation else { error = "两次输入的密码不一致。"; return }

        busy = true
        error = nil
        let operation = Task { @MainActor in
            do {
                let updated = try await client.updatePassword(password, accessToken: accessToken)
                try Task.checkCancellation()
                guard updated.id == user.id else { throw AccountFailure("密码更新后的账户身份不一致。") }
                try? await client.signOut(accessToken: accessToken)
                self.accessToken = nil
                self.user = nil
                ready = false
                completed = true
            } catch is CancellationError {
            } catch {
                self.error = error.localizedDescription
            }
            busy = false
        }
        task = operation
        await operation.value
        task = nil
    }

    func clear() {
        task?.cancel()
        task = nil
        accessToken = nil
        user = nil
        ready = false
        try? KeychainStore.write(nil, name: AccountSession.recoveryVerifierKey)
    }
}

private final class BrowserPresentationAnchor: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow) ?? ASPresentationAnchor()
    }
}

private struct AccountFailure: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

private struct StoredAccountSession: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: TimeInterval
    let user: SupabaseUser
}

private extension Data {
    var base64URLEncoded: String {
        base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
}

private extension ISO8601DateFormatter {
    static let accountFractional: ISO8601DateFormatter = {
        let value = ISO8601DateFormatter()
        value.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return value
    }()
}

private extension String {
    var nilIfBlank: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        return value
    }
}
