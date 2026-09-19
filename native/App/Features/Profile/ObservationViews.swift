import SwiftUI
import SujiCore

struct CalibrationView: View {
    @Environment(AppStore.self) private var store
    @State private var candidates: [Document] = []
    @State private var loading = false
    @State private var error: String?
    @State private var selected: Int?
    @State private var confirm = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("给模糊的时刻，\n多一点参照。").font(SujiTheme.serif(29)).lineSpacing(10)
                Text("比较前后一个时辰的候选盘。传统事件线索并不能验证真实出生时间，优先参考出生证明或家人的记录。").font(.subheadline).foregroundStyle(SujiTheme.secondary).lineSpacing(7)
                if loading { ProgressView("正在比较三个时辰") }
                if let error { Text(error).font(.subheadline).foregroundStyle(SujiTheme.secondary) }
                if !candidates.isEmpty {
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
                        HStack {
                            Text(["前一时辰","原时辰","后一时辰"][min(index,2)]).font(.headline)
                            Spacer(); Text(String(format: "%02d:00", Int(candidate["hour"].number))).font(.system(.title3, design: .serif))
                        }
                        Text("时柱 \(candidate["hourPillar"]["gan"].text)\(candidate["hourPillar"]["zhi"].text) · 命宫 \(candidate["mingGong"].text)").font(.subheadline).foregroundStyle(SujiTheme.secondary)
                        DisclosureGroup("查看历年差异线索") {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(candidate["events"].dictionary.keys.sorted().suffix(8), id: \.self) { year in
                                    let event = candidate["events"][year].text
                                    if event != "none" { Text("\(year) · \(event)").font(.caption).foregroundStyle(SujiTheme.secondary) }
                                }
                            }.padding(.top, 12)
                        }.font(.footnote)
                        Button("采用这个时辰") { selected = index; confirm = true }.font(.subheadline)
                    }.padding(22).background(SujiTheme.surface, in: RoundedRectangle(cornerRadius: 20))
                }
                if store.state.previousBirth != nil { Button("恢复上一次出生资料") { if let old = store.state.previousBirth { Task { try? await store.updateBirth(old) } } }.font(.subheadline) }
            }.padding(24)
        }.background(SujiTheme.paper).navigationTitle("时辰参照").navigationBarTitleDisplayMode(.inline)
            .task { await load() }
            .confirmationDialog("更新出生时间，并重新生成命盘？", isPresented: $confirm, titleVisibility: .visible) {
                Button("确认采用") { Task { await apply() } }
            }
    }
    private func load() async {
        guard let birth = store.state.birth else { return }; loading = true; defer { loading = false }
        do { candidates = try await store.request(["command":"candidates","birth":store.birthJSON(birth)]).array }
        catch { self.error = error.localizedDescription == "NIGHT_ZISHI_UNSUPPORTED" ? "23:00–23:59 的夜子时暂不支持此校准方式，请优先查阅原始出生记录。" : error.localizedDescription }
    }
    private func apply() async {
        guard let selected, candidates.indices.contains(selected), var birth = store.state.birth,
              let date = ISO8601DateFormatter().date(from: candidates[selected]["birthDate"].text) ?? ISO8601DateFormatter.fractional.date(from: candidates[selected]["birthDate"].text) else { return }
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let c = calendar.dateComponents([.year,.month,.day,.hour,.minute], from: date)
        birth.year = c.year!; birth.month = c.month!; birth.day = c.day!; birth.hour = c.hour!; birth.minute = c.minute!
        do { try await store.updateBirth(birth); await load() } catch { self.error = error.localizedDescription }
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
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                Image(systemName: "person.2").font(.system(size: 45, weight: .ultraLight)).foregroundStyle(SujiTheme.sage).padding(.top, 20)
                Text("两个人，\n各有自己的季节。").font(SujiTheme.serif(30)).lineSpacing(10)
                Text("了解彼此的不同，把关系交还给日常里的沟通和选择。").font(.body).foregroundStyle(SujiTheme.secondary).lineSpacing(7)
                Button(partner == nil ? "填写对方的出生资料" : "修改对方资料") { editor = true }.buttonStyle(.borderedProminent).buttonBorderShape(.capsule)
                if let partner { Text(partner.label + " · " + partner.city).font(.caption).foregroundStyle(SujiTheme.secondary) }
                if let result {
                    Text("传统关系线索").font(.headline)
                    Text(result["dayGanCompatibility"].text + " · " + result["dayZhiCompatibility"].text).font(SujiTheme.serif(25))
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
        }.background(SujiTheme.paper).navigationTitle("关系里的我们").navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $editor) { BirthEditor(existing: partner) { value in
                guard let birth = store.state.birth else { throw EngineError.execution("请先填写自己的出生资料") }
                result = try await store.request(["command":"relationship","birth":store.birthJSON(birth),"partner":store.birthJSON(value)])
                partner = value
            } }
    }
}
