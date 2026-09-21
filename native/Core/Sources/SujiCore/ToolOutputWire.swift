import Foundation

/// Decode a complete tool message before following its original JSON pointers.
/// Wire-only question references remain data; unlike receipt storage, this does
/// not require the question to be present because callers bind it separately.
enum ToolOutputWire {
    static func decode(_ raw:String, name:String = "", history:[ChatMessage] = [], callID:String = "") -> JSONValue? {
        guard let decoded=try? JSONDecoder().decode(JSONValue.self,from:Data(raw.utf8)),
              let shared=JSONValueTransport.expand(decoded),
              let layouts=LiuyaoConditionTransport.expand(shared),
              let expanded=QimenTimingTransport.expand(layouts) else { return nil }
        return CastSourceDirectory.expand(expanded,name:name,history:history,callID:callID)
    }

    /// `history` must end before this result. A directory later in the request
    /// cannot retroactively establish provenance for an earlier tool result.
    static func decode(_ message:ChatMessage, history:[ChatMessage]) -> JSONValue? {
        guard message.role == .tool, let raw=message.content else { return nil }
        let id=message.toolCallID ?? ""
        let calls=history.flatMap { $0.role == .assistant ? ($0.toolCalls ?? []) : [] }.filter { $0.id == id }
        return decode(raw,name:calls.count == 1 ? calls[0].name : "",history:history,callID:id)
    }

    /// Provider serialization preserves the directory verbatim, but a detached
    /// reference must fail before either API sends an incomplete evidence set.
    static func validateSourceReferences(_ history:[ChatMessage]) throws {
        for (index,message) in history.enumerated() where message.role == .tool {
            guard let raw=message.content,
                  case let .object(root)=try? JSONDecoder().decode(JSONValue.self,from:Data(raw.utf8)),
                  root["ruleSourcesFromDirectory"] != nil else { continue }
            guard decode(message,history:Array(history.prefix(index))) != nil else {
                throw ChatClientError.invalidConfiguration("A tool source reference requires its unique, verified same-round directory")
            }
        }
    }
}
