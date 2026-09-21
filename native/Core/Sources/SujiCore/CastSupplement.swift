import Foundation

/// Native-selected lineage, never inferred from a message or supplied by a model.
/// Every revision keeps the first, immutable chart and the actual source entry.
public struct CastSupplement: Codable, Sendable, Equatable {
    public let sourceUserID: UUID
    public let original: ToolReceipt
    public let arguments: JSONValue
    public let referenceOnly: Bool
    public var derivedName: String { original.name == "cast_liuyao" ? "reassess_liuyao" : "reassess_qimen" }

    private init(sourceUserID: UUID, original: ToolReceipt, arguments: JSONValue, referenceOnly: Bool) {
        self.sourceUserID=sourceUserID; self.original=original; self.arguments=arguments; self.referenceOnly=referenceOnly
    }

    public static func select(entryID: UUID, callID: String, entries: [ConversationEntry], context: ToolContext) throws -> Self {
        guard entries.filter({$0.id == entryID}).count == 1,
              let entry = entries.first(where:{$0.id == entryID}), entry.role == "user", entry.toolContext == context,
              let receipts = entry.toolReceipts, receipts.filter({$0.callID == callID}).count == 1,
              let receipt = receipts.first(where:{$0.callID == callID}) else { throw Failure.invalid }
        if let link = entry.castSupplement {
            guard let confirmations = entry.confirmedCastQuestions, confirmations.count == 1, let confirmation = confirmations.first else { throw Failure.invalid }
            _ = try link.render(receipt:receipt,confirmation:confirmation,userID:entry.id,entries:entries,context:context)
            return Self(sourceUserID:link.sourceUserID,original:link.original,arguments:receipt.arguments,referenceOnly:confirmation.referenceOnly)
        }
        try validateOriginal(receipt,context:context)
        let confirmation = entry.confirmedCastQuestions?.first(where:{$0.call.name == receipt.name})
        if let confirmation { try confirmation.validate(userID:entry.id,context:context) }
        return Self(sourceUserID:entry.id,original:receipt,arguments:receipt.arguments,referenceOnly:confirmation?.referenceOnly ?? false)
    }

    public func validate(userID: UUID, entries: [ConversationEntry], context: ToolContext) throws {
        guard Set(entries.map(\.id)).count == entries.count,
              let sourceIndex = entries.firstIndex(where:{$0.id == sourceUserID}),
              let userIndex = entries.firstIndex(where:{$0.id == userID}), sourceIndex < userIndex else { throw Failure.invalid }
        let source=entries[sourceIndex], user=entries[userIndex]
        guard source.role == "user", user.role == "user", source.castSupplement == nil,
              source.toolContext == context, user.toolContext == context, user.castSupplement == self,
              source.date <= user.date, abs(source.date.timeIntervalSince(context.referenceDate)) < 1,
              source.toolReceipts?.filter({$0.callID == original.callID}) == [original],
              entries.flatMap({$0.toolReceipts ?? []}).filter({$0.callID == original.callID}).count == 1 else { throw Failure.invalid }
        try Self.validateOriginal(original,context:context)
        _ = try CastQuestionDraft(call:.init(id:"validation",name:original.name,arguments:arguments))
    }

    /// Validate all immutable fields before adapting a local view to the existing
    /// reference renderer. The stored receipt keeps its distinct derived name.
    public func render(receipt: ToolReceipt, confirmation: ConfirmedCastQuestion, userID: UUID,
                       entries: [ConversationEntry], context: ToolContext) throws -> String {
        try validate(userID:userID,entries:entries,context:context)
        try confirmation.validate(userID:userID,context:context)
        guard confirmation.call.name == original.name, receipt.name == derivedName, receipt.context == context,
              receipt.callID == confirmation.call.id, receipt.callID != original.callID,
              receipt.arguments == confirmation.call.arguments else { throw Failure.invalid }
        let source = try Self.object(original.output), revised = try Self.object(receipt.output)
        let revision: JSONValue = ["algorithm":"suji-cast-question-revision-1","sourceToolName":.string(original.name),"sourceCallID":.string(original.callID)]
        guard revised["questionRevision"] == revision, case let .object(args) = confirmation.call.arguments,
              revised["question"] == args["question"], revised["questionType"] == args["questionType"],
              revised["questionContext"] == .object(args.filter{["subject","event","timeHorizon"].contains($0.key)}) else { throw Failure.invalid }
        if original.name == "setup_qimen" {
            // Only the optional timing source belongs to the changed question.
            func originalSources(_ chart: [String:JSONValue]) throws -> [JSONValue] {
                guard case let .array(sources) = chart["ruleSources"] else { throw Failure.invalid }
                return sources.filter { ReadingVerificationEvidence.pointer("/id",in:$0) != "qimen-xdyy-timing-v1" }
            }
            guard try originalSources(source) == originalSources(revised),
                  (revised["timing"] != nil) == (args["timingRequest"] != nil) else { throw Failure.invalid }
        }
        let mutable = Set(["question","questionType","questionContext","yongShen","yingQi","questionRevision"] +
            (original.name == "cast_liuyao" ? ["roleRelations","efficacy"] : ["timing","ruleSources"]))
        guard source.filter({!mutable.contains($0.key)}) == revised.filter({!mutable.contains($0.key)}) else { throw Failure.invalid }
        try CastQuestionBinding.validate(.object(revised),method:original.name)
        var adapted=receipt;adapted.name=original.name
        guard let text=Self.referenceText(adapted,context:context) else { throw Failure.invalid }
        guard case let .string(question) = args["question"] else { throw Failure.invalid }
        let scope=confirmation.referenceOnly ? "本次仅核对盘面。" : "以下按补充后的资料核对候选及条件。"
        return "这是对同一次占问的补充，沿用原盘与原起盘时刻。原记录仍然保留。\(scope)\n\n补充后的问题：\(question)\n\n" + text
    }

    // Versioned transport contract shared by source and derived records. Checking
    // only the version would allow a forged boundary/provider policy on retry.
    private static let calendarPolicy: JSONValue = [
        "version":"suji-calendar-2", "provider":"lunar-javascript@1.7.7", "timezone":"UTC+08:00",
        "yearBoundary":"exact-lichun", "monthBoundary":"exact-jie", "dayBoundary":"zi-hour-23:00",
        "lunarDayBoundary":"civil-midnight", "solarTimeScope":"day-and-hour-only",
        "yun":"year-polarity-gender; jie; three-days-per-year; sect-2-minute-conversion", "supportedCivilYears":[1901,2100]
    ]

    private static func validateOriginal(_ receipt:ToolReceipt, context:ToolContext) throws {
        let root = try object(receipt.output)
        guard case let .object(provenance) = root["provenance"],
              provenance["referenceDate"] == root[receipt.name == "cast_liuyao" ? "castTime":"setupTime"],
              provenance["calendarPolicy"] == calendarPolicy else { throw Failure.invalid }
        try CastQuestionBinding.validate(.object(root),method:receipt.name)
        guard ["cast_liuyao","setup_qimen"].contains(receipt.name), receipt.context == context, context.isValid,
              try object(receipt.output)["questionRevision"] == nil,
              referenceText(receipt,context:context) != nil else { throw Failure.invalid }
    }
    private static func referenceText(_ receipt:ToolReceipt,context:ToolContext) -> String? {
        receipt.name == "cast_liuyao" ? LiuyaoReferenceReading.render(receipts:[receipt],context:context)?.text
            : QimenReferenceReading.render(receipts:[receipt],context:context)?.text
    }
    private static func object(_ output:String) throws -> [String:JSONValue] {
        guard case let .object(root) = try LiuyaoReceiptStorage.expanded(output) else { throw Failure.invalid };return root
    }
    private enum Failure: LocalizedError {
        case invalid
        var errorDescription:String? { "无法核对这次补充与原盘的关联。原记录已保留，请从有效的原盘重新选择。" }
    }
}
