import Foundation
import SujiCore

extension AppStore {
    func makeThemeBinding(_ theme: BaziLifeTheme) throws -> BaziThemeBinding {
        guard let birth = state.birth, let payload = natalPayloadRevision, hasNatalDossier else { throw ToolOrchestratorError.staleContext }
        let context = try ToolContext(birth: birth, engineRevision: payload, referenceDate: Date(), mode: "命理")
        return BaziThemeBinding(ownerID: scopeKey, scopeRevision: scopeRevision, birthRevision: birthRevision,
            birthFingerprint: context.birthFingerprint, bundleRevision: engineRevision, payloadRevision: payload,
            snapshotID: theme.snapshotID, contentVersion: theme.contentVersion, themeID: theme.themeID)
    }
    func validateThemeBinding(_ binding: BaziThemeBinding) throws {
        let context = try ToolContext(birth: state.birth, engineRevision: natalPayloadRevision ?? "", referenceDate: Date(), mode: "命理")
        guard binding.isWellFormed, state.birth != nil, binding.ownerID == scopeKey,
              binding.scopeRevision == scopeRevision, binding.birthRevision == birthRevision,
              binding.birthFingerprint == context.birthFingerprint, binding.bundleRevision == engineRevision,
              binding.payloadRevision == natalPayloadRevision, binding.themeID == BaziLifeThemeCompiler.themeID,
              binding.contentVersion == BaziLifeThemeCompiler.contentVersion else { throw ToolOrchestratorError.staleContext }
    }
    func currentBaziTheme() async throws -> BaziLifeTheme {
        let scope = scopeRevision, generation = birthRevision
        guard let birth = state.birth else { throw ToolOrchestratorError.staleContext }
        let dossier = try await ensureNatalDossier()
        guard scope == scopeRevision, generation == birthRevision, state.birth == birth else { throw CancellationError() }
        let reports = try NatalReadingCompiler.natal(dossier: dossier, ownerID: scopeKey, birth: birth,
            engineRevision: engineRevision, enginePayloadRevision: natalPayloadRevision ?? "")
        guard let report = reports.first(where: { $0.system == .bazi }) else { throw EngineContract.Failure.invalid }
        return try BaziLifeThemeCompiler.compile(report: report)
    }
}
