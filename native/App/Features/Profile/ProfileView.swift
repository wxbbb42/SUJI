import SwiftUI
import SujiCore

struct ProfileView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.editNotebookBirth) private var editBirth
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("慢慢认识自己").font(SujiTheme.serif(32, relativeTo: .largeTitle))
                        .accessibilityAddTraits(.isHeader)
                    Text("资料、阅读与生活里的记录，都在这里。")
                        .font(.subheadline).foregroundStyle(SujiTheme.secondary)
                }.padding(.top, 12)

                NavigationLink {
                    NatalReadingReportView().id(profileRequestIdentity(store))
                } label: {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("我的册页").font(SujiTheme.serif(27, relativeTo: .title2))
                            Spacer(minLength: 16)
                            Image(systemName: "arrow.up.right").font(.title3)
                        }
                        Text(store.hasNatalDossier ? "已有本命资料 · 查看基础读盘" : store.state.birth == nil ? "从出生资料开始，读懂盘面的位置与关系" : "出生资料已保存 · 等待建立本命档案")
                            .font(.subheadline).foregroundStyle(SujiTheme.secondary).lineSpacing(5)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier(store.hasNatalDossier ? "profile.dossierReady" : "profile.dossierPending")
                    }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
                        .background(SujiTheme.surface, in: RoundedRectangle(cornerRadius: 24))
                        .contentShape(RoundedRectangle(cornerRadius: 24))
                }.buttonStyle(.plain).accessibilityIdentifier("profile.report")

                VStack(spacing: 0) {
                    Button(action: editBirth) {
                        profileRow("出生资料", subtitle: store.state.birth == nil ? "填写日期、时刻与地点" : "查看与修改已保存的资料", symbol: "person.text.rectangle")
                    }.buttonStyle(.plain).accessibilityIdentifier("profile.addBirth")
                    if store.state.birth != nil {
                        Divider().overlay(SujiTheme.line)
                        NavigationLink { CalibrationView() } label: {
                            profileRow("校准出生时辰", subtitle: "比较候选时辰，保留自己的判断", symbol: "clock.arrow.2.circlepath")
                        }
                    }
                }
                VStack(spacing: 0) {
                    NavigationLink { JournalListView() } label: {
                        profileRow("心情册页", subtitle: "\(store.state.journal.count) 份记录，都是生活的回声", symbol: "book.pages")
                    }
                    if store.state.birth != nil {
                        Divider().overlay(SujiTheme.line)
                        NavigationLink { RelationshipView() } label: {
                            profileRow("关系里的我们", subtitle: "双方资料与相处中的观察", symbol: "person.2")
                        }
                    }
                    Divider().overlay(SujiTheme.line)
                    NavigationLink { SettingsView() } label: {
                        profileRow("设置", subtitle: "账号、外观与本机归档", symbol: "slider.horizontal.3")
                    }.accessibilityIdentifier("profile.settings")
                }
                if let status = store.cloudProfileStatus {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(status).font(.footnote).foregroundStyle(SujiTheme.secondary)
                        Button("重试同步") { Task { await store.prepareAccount(); await store.syncBirthProfile() } }
                            .frame(minHeight: 44)
                    }
                }
                Text("传统文化提供观察的角度，不替你定义人生。")
                    .font(.footnote).foregroundStyle(SujiTheme.secondary).lineSpacing(5)
            }.padding(.horizontal, 24).padding(.bottom, 32)
                .frame(maxWidth: 640).frame(maxWidth: .infinity)
        }
        .background(SujiTheme.paper).foregroundStyle(SujiTheme.ink)
        .navigationTitle("我的").navigationBarTitleDisplayMode(.inline)
    }
    private func profileRow(_ title: String, subtitle: String, symbol: String) -> some View {
        HStack(spacing: 18) {
            Image(systemName: symbol).font(.title3.weight(.regular)).foregroundStyle(SujiTheme.secondary).frame(width: 26)
            VStack(alignment: .leading, spacing: 7) {
                Text(title).font(.headline.weight(.medium))
                Text(subtitle).font(.subheadline).foregroundStyle(SujiTheme.secondary)
            }.fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(SujiTheme.secondary)
        }.foregroundStyle(SujiTheme.ink).frame(maxWidth: .infinity, minHeight: 44).padding(.vertical, 16)
            .contentShape(Rectangle())
    }
}

struct PersonalitySection: View {
    let personality: Document
    let riZhu: Document
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("你的底色").font(.caption).tracking(2).foregroundStyle(SujiTheme.secondary)
            Text("传统解读 · 供自我观察").font(.caption).foregroundStyle(SujiTheme.secondary)
            Text(personality["coreTraits"].strings.first ?? "")
                .font(SujiTheme.serif(20, relativeTo: .body)).lineSpacing(6)
            Text(riZhu["description"].text).font(.body).lineSpacing(7).foregroundStyle(SujiTheme.secondary)
            DisclosureGroup("多了解一点") {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(Array(personality["coreTraits"].strings.dropFirst().enumerated()), id: \.offset) { _, trait in
                        Text(trait).font(.subheadline).foregroundStyle(SujiTheme.secondary)
                    }
                    Divider()
                    ForEach(personality["strengths"].strings, id: \.self) { Text($0).font(.subheadline) }
                    Divider()
                    Text(personality["emotionalPattern"].text).font(.subheadline).lineSpacing(6)
                }.padding(.top, 16)
            }.font(.subheadline)
        }.padding(.vertical, 12)
    }
}

struct BirthEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store
    var existing: BirthProfile?
    var required = false
    var onSave: (BirthProfile) async throws -> Void
    @State private var date = BirthProfile(year: 1995, month: 1, day: 1, hour: 12, minute: 0, gender: "女", city: "上海", longitude: 121.47).date!
    @State private var gender = "女"
    @State private var city = "上海"
    @State private var longitude = 121.47
    @State private var saving = false
    @State private var error: String?
    @State private var confirmedBirth = false
    @State private var showingAccount = false
    private var earliestBirth: Date { ISO8601DateFormatter().date(from: "1901-01-01T00:00:00+08:00")! }
    private let cities: [(String, Double)] = [("上海",121.47),("北京",116.40),("杭州",120.16),("成都",104.07),("广州",113.26),("深圳",114.06),("西安",108.94),("重庆",106.55),("武汉",114.31),("天津",117.20)]
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("公历出生日期与时间", selection: $date, in: earliestBirth...Date(), displayedComponents: [.date, .hourAndMinute]).environment(\.timeZone, TimeZone(secondsFromGMT: 8 * 3600)!)
                    LabeledContent("记录时区", value: "北京时间 UTC+8")
                    Picker("排盘性别", selection: $gender) { Text("女").tag("女"); Text("男").tag("男") }.pickerStyle(.segmented)
                } header: { Text("出生资料") } footer: { Text("填写出生记录上的公历和北京时间，性别用于传统排盘规则。暂未支持未知时刻或海外时区自动换算，请勿用默认时刻代替不确定的资料。") }
                Section {
                    LabeledContent("出生地点") { TextField("城市或地点", text: $city).multilineTextAlignment(.trailing).accessibilityLabel("出生地点").accessibilityIdentifier("birth.city") }
                    Menu("从常用城市填写") {
                        ForEach(cities, id: \.0) { item in Button(item.0) { city = item.0; longitude = item.1 } }
                    }
                    LabeledContent("出生地经度（°）") {
                        TextField("经度", value: $longitude, format: .number.precision(.fractionLength(2)))
                            .keyboardType(.numbersAndPunctuation).multilineTextAlignment(.trailing)
                            .accessibilityLabel("出生地经度，东经为正西经为负")
                    }
                } header: { Text("出生地点与时间口径") } footer: { Text("八字日柱和时柱按经度与均时差校正；年柱、月柱按民用时间与精确节气判断。紫微按填写的民用北京时间排盘。常用城市经度是市中心近似值，可自行修正。") }
                if existing == nil {
                    Section { Toggle("已核对出生日期、时刻和地点", isOn: $confirmedBirth).accessibilityIdentifier("birth.confirm") }
                }
                if let error { Section { Text(error).foregroundStyle(.red) } }
                if required, let status = store.cloudProfileStatus {
                    Section { Text(status).font(.footnote); Button("重试读取云端资料") { Task { await store.prepareAccount() } } }
                }
                Section { Text("保存后会建立本机本命档案，并将出生资料同步到账户。日签、日记与对话仍保存在本机。主动使用个性化 AI 解读时，相关命盘内容会经有时的服务发送给 DeepSeek。").font(.footnote).foregroundStyle(.secondary) }
            }.navigationTitle(required ? "建立你的档案" : "出生资料").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        if required { Button("账户") { showingAccount = true } }
                        else { Button("取消") { dismiss() }.disabled(saving) }
                    }
                    ToolbarItem(placement: .confirmationAction) { Button(saving ? "整理中…" : required ? "建立档案" : "保存") { Task { await save() } }.disabled(saving || (existing == nil && !confirmedBirth) || city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityIdentifier("birth.save") }
                }
                .sheet(isPresented: $showingAccount) { NavigationStack { AccountView(session: store.accountSession).toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { showingAccount = false } } } } }
        }.onAppear {
            if let existing { date = existing.date ?? date; gender = existing.gender; city = existing.city; longitude = existing.longitude }
        }
    }
    private func save() async {
        saving = true; defer { saving = false }
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!
        let c = calendar.dateComponents([.year,.month,.day,.hour,.minute], from: date)
        let birth = BirthProfile(year: c.year!, month: c.month!, day: c.day!, hour: c.hour!, minute: c.minute!, gender: gender, city: city, longitude: longitude)
        do { try birth.validated(); try await onSave(birth); if !required { dismiss() } } catch { self.error = error.localizedDescription }
    }
}

struct ChartDetailView: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let profile: Document
    @State private var selection: Int
    init(profile: Document, initialSelection: Int = 0) {
        self.profile = profile
        _selection = State(initialValue: initialSelection)
    }
    private let pillars = [("year","年柱"),("month","月柱"),("day","日柱"),("hour","时柱")]
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Picker("体系", selection: $selection) { Text("八字").tag(0); Text("紫微").tag(1) }.pickerStyle(.segmented)
                if selection == 0 {
                    ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: 0) {
                        ForEach(pillars, id: \.0) { key, label in
                            let pillar = profile["mingPan"]["siZhu"][key]
                            VStack(spacing: 16) {
                                Text(label).font(.caption).foregroundStyle(SujiTheme.secondary)
                                Text(pillar["ganZhi"]["gan"].text).font(SujiTheme.serif(35))
                                Text(pillar["ganZhi"]["zhi"].text).font(SujiTheme.serif(35))
                                Text(pillar["shiShen"].text).font(.caption).foregroundStyle(SujiTheme.secondary)
                                Text(pillar["ganZhi"]["naYin"].text).font(.caption2).foregroundStyle(SujiTheme.secondary)
                            }.frame(minWidth: typeSize.isAccessibilitySize ? 140 : 76, maxWidth: .infinity).padding(.vertical, 26).background(key == "day" ? SujiTheme.sage.opacity(0.1) : Color.clear)
                        }
                    }.background(SujiTheme.surface, in: RoundedRectangle(cornerRadius: 20))
                    }
                    Text("五行与取用").font(SujiTheme.serif(24))
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .top), count: typeSize.isAccessibilitySize ? 1 : 2), spacing: 16) {
                        element("日主", profile["mingPan"]["riZhu"]["wuXing"].text)
                        element("计数较多", profile["mingPan"]["wuXingStrength"]["strongest"].text)
                        element("计数较少", profile["mingPan"]["wuXingStrength"]["weakest"].text)
                        element("扶抑参考", profile["mingPan"]["wuXingStrength"]["yongShen"].text)
                    }
                    Text("五行计数来自当前天干与藏干权重，不能直接当作传统强弱；扶抑参考也不等同于格局用神。").font(.footnote).foregroundStyle(SujiTheme.secondary).lineSpacing(5)
                    if let trace = baziStrengthTrace(pillars: profile["mingPan"]["siZhu"], strength: profile["mingPan"]["wuXingStrength"], structure: profile["mingPan"]["riZhuStructure"]) {
                        BaziStrengthTraceView(trace: trace, identifier: "profile.strength.trace")
                    }
                    DisclosureGroup("结构与关系") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text((profile["mingPan"]["geJuV2"]["assessmentStatus"].text == "heuristic-candidate" ? "格局候选：" : "格局：") + profile["mingPan"]["geJuV2"]["name"].text)
                            Text("格局用神：" + profile["mingPan"]["geJuV2"]["yongShen"].text)
                            Text("格局用神取月令格局，采用《子平真诠》口径；上方的扶抑参考按五行强弱作简化判断。两种方法可能得到不同结果，需要结合各自依据阅读。").foregroundStyle(SujiTheme.secondary)
                            if !profile["mingPan"]["geJuV2"]["xiangShen"]["role"].text.isEmpty {
                                Text("相神作用：" + profile["mingPan"]["geJuV2"]["xiangShen"]["role"].text)
                            }
                            ForEach(profile["mingPan"]["geJuV2"]["conditions"].strings, id: \.self) { Text($0).foregroundStyle(SujiTheme.secondary) }
                            Text("格局是传统分类的参照，不是对人生的评分；当前规则仍含简化项。").foregroundStyle(SujiTheme.secondary)
                        }.font(.subheadline).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 16)
                    }
                    TiaoHouSourceView(document: profile["mingPan"]["tiaoHou"])
                } else {
                    Text(profile["ziweiPan"]["fiveElementsClass"].text).font(SujiTheme.serif(28))
                    Text("命宫在\(profile["ziweiPan"]["mingGongPosition"].text) · 身宫在\(profile["ziweiPan"]["shenGongPosition"].text)").font(.subheadline).foregroundStyle(SujiTheme.secondary)
                    Text("按民用北京时间排盘。点开宫位查看完整星曜、亮度与本命四化。").font(.footnote).foregroundStyle(SujiTheme.secondary).lineSpacing(5)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .top), count: typeSize.isAccessibilitySize ? 1 : 2), spacing: 12) {
                        ForEach(Array(profile["ziweiPan"]["palaces"].array.enumerated()), id: \.offset) { _, palace in
                            NavigationLink { ZiweiPalaceDetailView(palace: palace) } label: { ZiweiPalaceCard(palace: palace) }.buttonStyle(.plain)
                        }
                    }
                }
                ChartCalculationNote(profile: profile)
                Text("排盘使用本地传统算法；格局、应期等规则含简化项。结果用于文化体验与自我观察。").font(.footnote).foregroundStyle(SujiTheme.secondary).lineSpacing(5)
            }.padding(24)
        }.background(SujiTheme.paper).foregroundStyle(SujiTheme.ink).navigationTitle("命盘手稿").navigationBarTitleDisplayMode(.inline)
    }
    @ViewBuilder
    private func element(_ label: String, _ value: String) -> some View {
        if typeSize.isAccessibilitySize {
            HStack(alignment: .firstTextBaseline, spacing: 20) {
                Text(label).font(.body).foregroundStyle(SujiTheme.secondary).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 12)
                Text(value).font(SujiTheme.serif(28)).foregroundStyle(SujiTheme.sage)
            }.frame(maxWidth: .infinity).padding(.vertical, 12).accessibilityElement(children: .combine)
        } else {
            VStack(spacing: 14) {
                Text(value).font(SujiTheme.serif(28)).foregroundStyle(SujiTheme.sage)
                Text(label).font(.caption).foregroundStyle(SujiTheme.secondary)
            }.frame(maxWidth: .infinity).padding(.vertical, 15).accessibilityElement(children: .combine)
        }
    }
}

struct FortuneDetailView: View {
    @Environment(AppStore.self) private var store
    @State private var year = Calendar.current.component(.year, from: Date())
    @State private var annual: Document?
    @State private var annualIdentity: String?
    @State private var failure: String?
    @State private var loading = false
    private var requestIdentity: String { profileRequestIdentity(store) + ":" + String(year) }
    private var selected: Document? {
        if annualIdentity == requestIdentity, let annual, Int(annual["forecast"]["year"].number) == year { return annual }
        return nil
    }
    private var chart: Document { selected ?? Document(NSNull()) }
    private var qiYun: Document { chart["mingPan"]["qiYun"] }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Picker("参照流年", selection: $year) { ForEach((max(1901, (store.state.birth?.year ?? year)))...min(2100, Calendar.current.component(.year, from: Date()) + 10), id: \.self) { Text(String($0) + "年流年").tag($0) } }
                Text("流年以立春为界，年份是所选周期的标签。").font(.footnote).foregroundStyle(SujiTheme.secondary)
                if loading { ProgressView("正在整理所选年份") }
                if let failure { Text("这一年的资料未能载入：" + failure).font(.footnote).foregroundStyle(SujiTheme.secondary) }
                if let selected {
                    VStack(alignment: .leading, spacing: 16) {
                        if let start = profileBeijingDate(selected["forecast"]["annualCycle"]["startDate"].text),
                           let end = profileBeijingDate(selected["forecast"]["annualCycle"]["endDate"].text) {
                            Text("流年周期：" + start + " 起，至 " + end + " 前").font(.footnote).foregroundStyle(SujiTheme.secondary)
                            if selected["forecast"]["annualCycle"]["isActiveAtReference"].value as? Bool == false {
                                Text("当前时点属于 \(Int(selected["forecast"]["annualCycle"]["activeYearAtReference"].number)) 年流年；下方阅读的是所选周期。").font(.footnote).foregroundStyle(SujiTheme.secondary)
                            }
                        }
                        if let reference = profileBeijingDate(selected["forecast"]["referenceDate"].text) {
                            Text("年度参考时点：" + reference + "（北京时间）").font(.footnote).foregroundStyle(SujiTheme.secondary)
                        }
                        Text(statusDescription(selected["forecast"])).font(SujiTheme.serif(26)).foregroundStyle(SujiTheme.sage)
                        DisclosureGroup("\(String(year))年传统推演细节") {
                            VStack(alignment: .leading, spacing: 18) {
                                Text("以下文字来自简化传统规则，描述所选流年的观察角度，不是当前生活状态的测量或事件概率。").font(.footnote).foregroundStyle(SujiTheme.secondary)
                                Text(selected["timing"]["currentPhase"].text).font(.body).lineSpacing(7)
                                Text(selected["timing"]["advice"].text).font(.subheadline).lineSpacing(6).foregroundStyle(SujiTheme.secondary)
                                ForEach([("careerOutlook","工作与行动"),("relationshipOutlook","关系与沟通"),("keyAdvice","给自己的提醒")], id: \.0) { key, label in
                                    VStack(alignment: .leading, spacing: 8) { Text(label).font(.caption).foregroundStyle(SujiTheme.secondary); Text(selected["forecast"][key].text).font(.body).lineSpacing(6) }
                                }
                            }.padding(.top, 16)
                        }
                    }
                }
                Text("起运依据").font(.headline).padding(.top, 12)
                if let start = profileBeijingDate(qiYun["startDate"].text) {
                    Text("\(chart["mingPan"]["daYunDirection"].text) · 出生后 \(Int(qiYun["years"].number)) 年 \(Int(qiYun["months"].number)) 个月 \(Int(qiYun["days"].number)) 天 \(Int(qiYun["hours"].number)) 小时起运").font(.subheadline)
                    Text("首运开始：" + start).font(.subheadline)
                    if let term = profileBeijingDate(qiYun["termDate"].text) {
                        Text("参考节：" + qiYun["termName"].text + " · " + term).font(.footnote).foregroundStyle(SujiTheme.secondary)
                    }
                    Text("按年干阴阳与排盘性别定顺逆，以节计算，三日折一年；采用分钟换算口径。下方年龄是整岁参考，实际交运以日期时间为准。").font(.footnote).foregroundStyle(SujiTheme.secondary).lineSpacing(5)
                } else if !loading {
                    Text("当前结果未提供可复核的起运时刻，请重新整理出生资料。").font(.footnote).foregroundStyle(SujiTheme.secondary)
                }
                Text("大运册页").font(.headline).padding(.top, 16)
                ForEach(Array(chart["mingPan"]["daYunList"].array.enumerated()), id: \.offset) { _, item in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .firstTextBaseline, spacing: 22) {
                            Text(item["ganZhi"]["gan"].text + item["ganZhi"]["zhi"].text).font(SujiTheme.serif(28))
                            Text(item["period"].text).font(.subheadline)
                        }
                        Text(item["shiShen"].text).font(.caption).foregroundStyle(SujiTheme.secondary)
                        if let start = profileBeijingDate(item["startDate"].text), let end = profileBeijingDate(item["endDate"].text) {
                            Text(start + " 起，至 " + end + " 前").font(.footnote).foregroundStyle(SujiTheme.secondary)
                        }
                        if let selected, !item["startDate"].text.isEmpty,
                           item["startDate"].text == selected["forecast"]["daYun"]["startDate"].text {
                            Text("年度参考时点所在大运").font(.caption).foregroundStyle(SujiTheme.sage)
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 15)
                    Divider()
                }
                Text("年度解读使用一个参考时点；交运当年的时点前后可能属于不同大运。这些传统规则不决定人生，也不替代医疗、财务或重大生活决策。").font(.footnote).foregroundStyle(SujiTheme.secondary).lineSpacing(5)
            }.padding(24)
        }.background(SujiTheme.paper).foregroundStyle(SujiTheme.ink).navigationTitle("人生的节奏").navigationBarTitleDisplayMode(.inline)
            .task(id: requestIdentity) {
                let identity = requestIdentity
                annual = nil; annualIdentity = nil; failure = nil; loading = true
                guard let birth = store.state.birth else { loading = false; return }
                do {
                    let value = try await store.request(["command":"profile", "birth":store.birthJSON(birth), "year":year, "now":ISO8601DateFormatter().string(from: Date())])
                    try Task.checkCancellation()
                    guard identity == requestIdentity else { return }
                    annual = value; annualIdentity = identity; loading = false
                } catch is CancellationError { }
                catch { guard !Task.isCancelled, identity == requestIdentity else { return }; failure = error.localizedDescription; loading = false }
            }
    }
    private func statusDescription(_ forecast: Document) -> String {
        switch forecast["daYunStatus"].text {
        case "before-birth": return "参考时点早于出生时间"
        case "before-start": return "参考时点尚未起运"
        case "out-of-range": return "参考时点超出已生成的大运范围"
        case "missing-exact-dates": return "大运日期尚未核实"
        case "active": return "参照大运：" + forecast["daYun"]["ganZhi"]["gan"].text + forecast["daYun"]["ganZhi"]["zhi"].text
        default: return "请结合下方起运依据阅读"
        }
    }
}
