import Foundation
import CryptoKit

/// Complete fixed rule metadata delivered beside its chart in the same request.
/// Saved receipts remain self-contained; references bind to one call and digest.
enum CastSourceDirectory {
    static let prefix="完整规则来源目录（同轮工具证据）：\n"
    private static let referenceKey="ruleSourcesFromDirectory"
    static func isMessage(_ message:ChatMessage)->Bool {message.role == .system && (message.content?.hasPrefix(prefix) ?? false)}
    static func isDirectory(_ message:ChatMessage)->Bool {isMessage(message)}
    private static func digest(_ value:JSONValue)->String {SHA256.hash(data:Data(ReadingVerificationEvidence.encoded(value).utf8)).map{String(format:"%02x",$0)}.joined()}
    static func message(receipt:ToolReceipt,callID:String?=nil)->ChatMessage? {
        guard ["cast_liuyao","setup_qimen","reassess_liuyao","reassess_qimen"].contains(receipt.name),let value=try? CastReceiptStorage.expanded(receipt.output),
              ReadingVerificationEvidence.encoded(value).utf16.count>28_000,case let .object(root)=value,root[referenceKey]==nil,
              case let .array(sources)=root["ruleSources"],!sources.isEmpty else{return nil}
        let metadata:JSONValue=["version":1,"toolCallID":.string(callID ?? receipt.callID),"toolName":.string(receipt.name),"sha256":.string(digest(.array(sources))),"ruleSources":.array(sources)]
        let content=prefix+JSONValueTransport.encode(ReadingVerificationEvidence.encoded(metadata))
        guard content.utf16.count<=32_000 else{return nil}
        return ChatMessage(role:.system,content:content)
    }
    private static func source(_ reference:JSONValue,name:String,history:[ChatMessage],callID:String)->JSONValue? {
        guard case let .object(ref)=reference,Set(ref.keys)==Set(["toolCallID","toolName","sha256"]),ref["toolCallID"] == .string(callID),ref["toolName"] == .string(name),case let .string(hash)=ref["sha256"] else{return nil}
        let start=history.lastIndex(where:{$0.role == .user}).map{$0+1} ?? 0
        let current=Array(history.dropFirst(start))
        let calls=current.enumerated().flatMap { index,message in (message.role == .assistant ? (message.toolCalls ?? []) : []).filter{$0.id==callID}.map{(index,$0)} }
        guard calls.count==1,calls[0].1.name==name else{return nil}
        let directories=current.enumerated().filter{isMessage($0.element)}.compactMap { index,message->(Int,JSONValue)? in
            guard let content=message.content,let packed=try? JSONDecoder().decode(JSONValue.self,from:Data(content.dropFirst(prefix.count).utf8)),
                  let value=JSONValueTransport.expand(packed),case let .object(root)=value,root["toolCallID"] == .string(callID) else{return nil}
            return (index,value)
        }
        guard directories.count==1,directories[0].0<calls[0].0,case let .object(root)=directories[0].1,Set(root.keys)==Set(["version","toolCallID","toolName","sha256","ruleSources"]),root["version"]==1,root["toolName"] == .string(name),root["sha256"] == .string(hash),case let .array(sources)=root["ruleSources"],!sources.isEmpty,digest(.array(sources))==hash else{return nil}
        return .array(sources)
    }
    static func project(_ value:JSONValue,name:String,history:[ChatMessage],callID:String)->JSONValue {
        guard case var .object(root)=value,root[referenceKey]==nil,let sources=root["ruleSources"] else{return value}
        let ref:JSONValue=["toolCallID":.string(callID),"toolName":.string(name),"sha256":.string(digest(sources))]
        guard source(ref,name:name,history:history,callID:callID)==sources else{return value}
        root.removeValue(forKey:"ruleSources");root[referenceKey]=ref;return .object(root)
    }
    static func expand(_ value:JSONValue,name:String,history:[ChatMessage],callID:String)->JSONValue? {
        guard case var .object(root)=value else{return value}
        guard let ref=root[referenceKey] else{return value}
        guard root["ruleSources"]==nil,let sources=source(ref,name:name,history:history,callID:callID) else{return nil}
        root.removeValue(forKey:referenceKey);root["ruleSources"]=sources;return .object(root)
    }
}
