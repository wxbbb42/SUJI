import Foundation

/// The app talks only to its own authenticated backend. Provider credentials
/// and inference parameters belong to the Edge Function, never the app bundle.
public enum ManagedAI {
    public static let model = "deepseek-flash"

    public static func configuration(supabase: SupabaseConfiguration) throws -> ChatProviderConfiguration {
        guard supabase.url.scheme == "https", supabase.url.host != nil,
              supabase.url.user == nil, supabase.url.password == nil,
              supabase.url.query == nil, supabase.url.fragment == nil else {
            throw ChatClientError.invalidConfiguration("Invalid backend URL")
        }
        return ChatProviderConfiguration(
            baseURL: supabase.url.appendingPathComponent("functions/v1/suji-chat/chat/completions"),
            model: model, api: .chatCompletions, authentication: .bearer,
            publicAPIKey: supabase.anonKey
        )
    }
}
