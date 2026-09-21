import SwiftUI
import SujiCore

struct CalibrationView: View {
    @Environment(AppStore.self) private var store
    @State private var candidateResults: [Document] = []
    @State private var loadedIdentity: String?
    @State private var loading = false
    @State private var error: String?
    @State private var selected: Int?
    @State private var confirm = false
    @State private var applying = false
    private var requestIdentity: String { profileRequestIdentity(store) }
    private var candidates: [Document] { loadedIdentity == requestIdentity ? candidateResults : [] }
    private let systems = [("bazi", "八字"), ("ziwei", "紫微")]
    private var comparisonYears: [String] {
        let years = Set(candidates.flatMap { candidate in systems.flatMap { candidate["eventsBySystem"][$0.0].dictionary.keys } })
        return years.sorted().filter { year in
            Set(candidates.map { candidate in systems.map { event(candidate, system: $0.0, year: year) }.joined(separator: "|") }).count > 1
        }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("给模糊的时刻，\n多一点参照。").font(SujiTheme.serif(29)).lineSpacing(10)
                Text("比较前后一个时辰的候选盘。候选中的整点是排盘参照值，不是查明的出生时间；传统线索不能验证真实出生时间，优先参考出生证明或家人的记录。").font(.subheadline).foregroundStyle(SujiTheme.secondary).lineSpacing(7)
                if loading { ProgressView("正在比较三个时辰") }
                if let error { Text(error).font(.subheadline).foregroundStyle(SujiTheme.secondary) }
                if !candidates.isEmpty {
                    if comparisonYears.isEmpty {
                        Text("当前规则没有找到可区分候选的年度线索。资料不足时，保留原始出生记录。").font(.subheadline).foregroundStyle(SujiTheme.secondary)
                    } else {
                        DisclosureGroup("候选有差异的年份（\(comparisonYears.count)）") {
                            VStack(alignment: .leading, spacing: 22) {
                                Text("相同线索不提供区分能力。下列差异是传统规则产生的候选描述，不是已发生事件或置信概率。").font(.footnote).foregroundStyle(SujiTheme.secondary)
                                ForEach(comparisonYears, id: \.self) { year in
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text(year + "年").font(.headline)
                                        ForEach(Array(candidates.enumerated()), id: \.offset) { index, candidate in
                                            Text(candidateName(index) + "：" + eventSummary(candidate, year: year)).font(.footnote).foregroundStyle(SujiTheme.secondary)
                                        }
                                    }
                                }
                            }.padding(.top, 14)
                        }.font(.subheadline)
                    }
                    NavigationLink("用经历作参照") {
                        ReflectionView(title: "让经历慢慢说", key: "calibration:" + (store.state.birth?.label ?? ""),
                            context: Document(candidates.map(\.value)).json,
                            instruction: "这是出生时辰参照访谈。比较提供的三个候选盘，先围绕候选事件差异提出一个开放问题，等待回答，再问下一题；最多五个问题。用户可回答不确定，不能把无回应视为吻合。最后逐个说明候选支持与不支持的线索，资料不足就直说。不虚构概率、不声称能验证出生时间、不修改用户资料。提醒回到候选页自行决定。",
                            opening: "从一个容易回答的问题开始，陪我比较这三个出生时辰。",
                            privacy: "开始后，候选盘与您主动补充的经历会经有时的服务发送给 DeepSeek。建议仅供参照，采用时辰需要你另行确认。")
                    }.font(.headline)
                }
                ForEach(Array(candidates.enumerated()), id: \.offset) { index, candidate in
                    VStack(alignment: .leading, spacing: 14) {
                        Text(candidateName(index)).font(.headline)
                        Text(profileBeijingDate(candidate["birthDate"].text) ?? "候选日期未能读取").font(.subheadline)
                        Text("民用北京时间 · 候选排盘参照值").font(.caption).foregroundStyle(SujiTheme.secondary)
                        Text("时柱 \(candidate["hourPillar"]["gan"].text)\(candidate["hourPillar"]["zhi"].text) · 命宫 \(candidate["mingGong"].text)").font(.subheadline).foregroundStyle(SujiTheme.secondary)
                        DisclosureGroup("查看历年差异线索") {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(eventYears(candidate), id: \.self) { year in
                                    Text("\(year) · " + eventSummary(candidate, year: year)).font(.caption).foregroundStyle(SujiTheme.secondary)
                                }
                                if eventYears(candidate).isEmpty { Text("没有返回年度线索。").font(.caption).foregroundStyle(SujiTheme.secondary) }
                            }.padding(.top, 12)
                        }.font(.footnote)
                        Button("采用这个时辰") { selected = index; confirm = true }.font(.subheadline).disabled(applying)
                    }.padding(22).background(SujiTheme.surface, in: RoundedRectangle(cornerRadius: 20))
                }
                if store.state.previousBirth != nil { Button("恢复上一次出生资料") { Task { await restore() } }.font(.subheadline).disabled(applying) }
            }.padding(24)
        }.background(SujiTheme.paper).foregroundStyle(SujiTheme.ink).navigationTitle("时辰参照").navigationBarTitleDisplayMode(.inline)
            .task(id: requestIdentity) { await load() }
            .confirmationDialog("更新出生时间，并重新生成命盘？", isPresented: $confirm, titleVisibility: .visible) {
                Button("确认采用") { Task { await apply() } }
            } message: {
                Text("原记录：\(store.state.birth?.label ?? "未填写")\n将采用：\(selected.flatMap { candidates.indices.contains($0) ? profileBeijingDate(candidates[$0]["birthDate"].text) : nil } ?? "未选择")\n候选整点会替换原记录的小时和分钟。此选择不表示该时刻已被验证，可恢复上一次资料。")
            }
    }
    private func load() async {
        let identity = requestIdentity
        candidateResults = []; loadedIdentity = nil; error = nil; selected = nil; confirm = false
        guard let birth = store.state.birth else { loading = false; return }
        loading = true
        defer { if identity == requestIdentity { loading = false } }
        do {
            let result = try await store.request(["command":"candidates","birth":store.birthJSON(birth)]).array
            try Task.checkCancellation()
            guard identity == requestIdentity else { return }
            candidateResults = result; loadedIdentity = identity
        } catch is CancellationError { }
        catch {
            guard !Task.isCancelled, identity == requestIdentity else { return }
            self.error = error.localizedDescription == "NIGHT_ZISHI_UNSUPPORTED" ? "23:00–23:59 的夜子时暂不支持此校准方式，请优先查阅原始出生记录。" : error.localizedDescription
        }
    }
    private func apply() async {
        guard !applying, loadedIdentity == requestIdentity, let selected, candidates.indices.contains(selected), var birth = store.state.birth else { return }
        guard let date = ISO8601DateFormatter().date(from: candidates[selected]["birthDate"].text) ?? ISO8601DateFormatter.fractional.date(from: candidates[selected]["birthDate"].text) else { error = "候选日期未能读取，原资料没有更改。"; return }
        applying = true; defer { applying = false }
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!
        let c = calendar.dateComponents([.year,.month,.day,.hour,.minute], from: date)
        birth.year = c.year!; birth.month = c.month!; birth.day = c.day!; birth.hour = c.hour!; birth.minute = c.minute!
        let scope = store.scopeRevision
        do { try await store.updateBirth(birth) }
        catch { if scope == store.scopeRevision { self.error = error.localizedDescription } }
    }
    private func restore() async {
        guard !applying, let old = store.state.previousBirth else { return }
        applying = true; defer { applying = false }
        let scope = store.scopeRevision
        do { try await store.updateBirth(old) }
        catch { if scope == store.scopeRevision { self.error = error.localizedDescription } }
    }
    private func candidateName(_ index: Int) -> String { ["前一时辰", "原时辰", "后一时辰"][min(index, 2)] }
    private func event(_ candidate: Document, system: String, year: String) -> String {
        let value = candidate["eventsBySystem"][system][year].text
        return value == "none" ? "" : value
    }
    private func eventYears(_ candidate: Document) -> [String] {
        Set(systems.flatMap { candidate["eventsBySystem"][$0.0].dictionary.keys }).sorted().filter { year in systems.contains { !event(candidate, system: $0.0, year: year).isEmpty } }
    }
    private func eventSummary(_ candidate: Document, year: String) -> String {
        systems.map { system, label in
            let value = event(candidate, system: system, year: year)
            return label + "：" + (value.isEmpty ? "未见该类线索" : value)
        }.joined(separator: "；")
    }
}
extension ISO8601DateFormatter {
    static var fractional: ISO8601DateFormatter { let value = ISO8601DateFormatter(); value.formatOptions = [.withInternetDateTime,.withFractionalSeconds]; return value }
}

struct RelationshipView: View {
    @Environment(AppStore.self) private var store
    @State private var partner: BirthProfile?
    @State private var result: Document?
    @State private var editor = false
    @State private var error: String?
    private var requestIdentity: String { profileRequestIdentity(store) }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                Image(systemName: "person.2").font(.system(size: 45, weight: .ultraLight)).foregroundStyle(SujiTheme.sage).padding(.top, 20)
                Text("两个人，\n各有自己的季节。").font(SujiTheme.serif(30)).lineSpacing(10)
                Text("了解彼此的不同，把关系交还给日常里的沟通和选择。").font(.body).foregroundStyle(SujiTheme.secondary).lineSpacing(7)
                Button(partner == nil ? "填写对方的出生资料" : "修改对方资料") { editor = true }.buttonStyle(.borderedProminent).buttonBorderShape(.capsule)
                Text("对方资料仅用于本次临时比较，离开此页面后需要重新填写。").font(.footnote).foregroundStyle(SujiTheme.secondary)
                if let partner { Text(partner.label + " · " + partner.city).font(.caption).foregroundStyle(SujiTheme.secondary) }
                if let result {
                    Text("传统关系线索").font(.headline)
                    VStack(alignment: .leading, spacing: 14) {
                        if !result["firstDayPillar"]["gan"].text.isEmpty {
                            Text("你的日柱：" + result["firstDayPillar"]["gan"].text + result["firstDayPillar"]["zhi"].text).font(.subheadline)
                            Text("对方日柱：" + result["secondDayPillar"]["gan"].text + result["secondDayPillar"]["zhi"].text).font(.subheadline)
                        } else {
                            Text("你的日主：" + result["first"]["gan"].text).font(.subheadline)
                            Text("对方日主：" + result["second"]["gan"].text).font(.subheadline)
                        }
                        Text("日干关系：" + result["dayGanCompatibility"].text).font(SujiTheme.serif(23))
                        Text("日支关系：" + result["dayZhiCompatibility"].text).font(SujiTheme.serif(23))
                    }
                    Text("你的底色：" + result["first"]["description"].text).font(.body).lineSpacing(7)
                    Text("对方的底色：" + result["second"]["description"].text).font(.body).lineSpacing(7)
                    Text("试着各自回答：当压力来临，我更希望被倾听，还是一起想办法？把需求说具体，比猜测更有用。").font(.body).lineSpacing(7).padding(22).background(SujiTheme.surface, in: RoundedRectangle(cornerRadius: 20))
                    Text(result["note"].text).font(.footnote).foregroundStyle(SujiTheme.secondary)
                    NavigationLink("聊聊我们的相处") {
                        ReflectionView(title: "关系里的练习", key: "relationship:" + (store.state.birth?.label ?? "") + ":" + (partner?.label ?? ""), context: result.json,
                            instruction: "先明确传统干支描述只是反思角度，不能评价关系质量、兼容性或预测分手。结合两个人的实际差异给一项具体沟通练习，再询问用户目前遇到的相处情境。不要编造对方的感受。",
                            opening: "给我们一个更理解彼此的小练习。",
                            privacy: "开始后，上方的双方传统关系线索与您补充的情境会经有时的服务发送给 DeepSeek。")
                    }
                }
                if let error { Text(error).foregroundStyle(SujiTheme.secondary) }
            }.padding(24)
        }.background(SujiTheme.paper).foregroundStyle(SujiTheme.ink).navigationTitle("关系里的我们").navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $editor) { BirthEditor(existing: partner) { value in
                guard let birth = store.state.birth else { throw EngineError.execution("请先填写自己的出生资料") }
                let identity = requestIdentity
                let comparison = try await store.request(["command":"relationship","birth":store.birthJSON(birth),"partner":store.birthJSON(value)])
                guard identity == requestIdentity else { throw EngineError.execution("你的出生资料已改变，请重新填写对方资料后比较。") }
                result = comparison; partner = value
            } }
            .onChange(of: requestIdentity) { _, _ in result = nil; partner = nil; editor = false; error = nil }
    }
}
