import SwiftUI
import SujiCore

struct ProfileView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var editingBirth = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("我的册页").font(SujiTheme.serif(34))
                                .fixedSize(horizontal: false, vertical: true)
                            Text("慢慢认识，也温柔以待。").font(.subheadline).foregroundStyle(SujiTheme.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                        if !typeSize.isAccessibilitySize { SujiSeal(text: "自观").padding(.top, 8) }
                    }.padding(.top, 20)
                    if let birth = store.state.birth {
                        Button { editingBirth = true } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(birth.label).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                                    Text("\(birth.city) · 北京时间 · \(birth.gender)").font(.caption).foregroundStyle(SujiTheme.secondary).fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer(); Image(systemName: "pencil").foregroundStyle(SujiTheme.secondary)
                            }.padding(20).background(SujiTheme.surface, in: RoundedRectangle(cornerRadius: 20))
                        }.buttonStyle(.plain)
                    } else {
                        VStack(alignment: .leading, spacing: 20) {
                            Text("从一份出生资料开始").font(SujiTheme.serif(24))
                            Text("借传统历法作一面镜子，看看自己的性格与节奏。资料优先保存在本机。").font(.subheadline).foregroundStyle(SujiTheme.secondary).lineSpacing(6)
                            Button("填写出生资料") { editingBirth = true }.buttonStyle(.borderedProminent).buttonBorderShape(.capsule)
                                .accessibilityIdentifier("profile.addBirth")
                        }.padding(24).frame(maxWidth: .infinity, alignment: .leading).background(SujiTheme.surface, in: RoundedRectangle(cornerRadius: 24))
                    }
                    if store.computing { ProgressView("正在整理你的册页…").frame(maxWidth: .infinity).padding() }
                    if let profile = store.profile {
                        PersonalitySection(personality: profile["personality"], riZhu: profile["mingPan"]["riZhu"])
                        NavigationLink { ChartDetailView(profile: profile) } label: { profileRow("命盘手稿", subtitle: "四柱 · 五行 · 紫微十二宫", symbol: "square.grid.3x3") }
                        NavigationLink { FortuneDetailView(profile: profile) } label: { profileRow("人生的节奏", subtitle: "大运与流年，作为观察的线索", symbol: "chart.xyaxis.line") }
                        NavigationLink { CalibrationView() } label: { profileRow("校准出生时辰", subtitle: "比较候选时辰，保留自己的判断", symbol: "clock.arrow.2.circlepath") }
                        NavigationLink { RelationshipView() } label: { profileRow("关系里的我们", subtitle: "理解差异，练习更好的相处", symbol: "person.2") }
                    }
                    NavigationLink { JournalListView() } label: { profileRow("心情册页", subtitle: "\(store.state.journal.count) 份记录，都是生活的回声", symbol: "book.pages") }
                    Text("传统文化提供观察的角度，不替你定义人生。").font(.footnote).foregroundStyle(SujiTheme.secondary).lineSpacing(5).padding(.vertical, 12)
                }.padding(.horizontal, 24).padding(.bottom, 32)
            }.background(SujiTheme.paper).foregroundStyle(SujiTheme.ink).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { NavigationLink { SettingsView() } label: { Image(systemName: "slider.horizontal.3") }.accessibilityLabel("设置") } }
                .sheet(isPresented: $editingBirth) { BirthEditor(existing: store.state.birth) { birth in try await store.updateBirth(birth) } }
        }
    }
    private func profileRow(_ title: String, subtitle: String, symbol: String) -> some View {
        HStack(spacing: 18) {
            Image(systemName: symbol).font(.title3.weight(.light)).foregroundStyle(SujiTheme.secondary).frame(width: 26)
            VStack(alignment: .leading, spacing: 7) { Text(title).font(.headline.weight(.medium)); Text(subtitle).font(.caption).foregroundStyle(SujiTheme.secondary) }
            Spacer(); Image(systemName: "chevron.right").font(.caption).foregroundStyle(SujiTheme.secondary)
        }.foregroundStyle(SujiTheme.ink).padding(.vertical, 12)
    }
}

struct PersonalitySection: View {
    let personality: Document
    let riZhu: Document
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("你的底色").font(.caption).tracking(2).foregroundStyle(SujiTheme.secondary)
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
    var existing: BirthProfile?
    var onSave: (BirthProfile) async throws -> Void
    @State private var date = BirthProfile(year: 1995, month: 1, day: 1, hour: 12, minute: 0, gender: "女", city: "上海", longitude: 121.47).date!
    @State private var gender = "女"
    @State private var city = "上海"
    @State private var longitude = 121.47
    @State private var saving = false
    @State private var error: String?
    private let cities: [(String, Double)] = [("上海",121.47),("北京",116.40),("杭州",120.16),("成都",104.07),("广州",113.26),("深圳",114.06),("西安",108.94),("重庆",106.55),("武汉",114.31),("天津",117.20)]
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("出生日期与时间", selection: $date, in: ...Date(), displayedComponents: [.date, .hourAndMinute]).environment(\.timeZone, TimeZone(identifier: "Asia/Shanghai")!)
                    Picker("排盘性别", selection: $gender) { Text("女").tag("女"); Text("男").tag("男") }.pickerStyle(.segmented)
                } header: { Text("出生资料") } footer: { Text("按出生记录上的北京时间填写。性别用于传统排盘规则。") }
                Section {
                    Picker("出生城市", selection: $city) { ForEach(cities, id: \.0) { Text($0.0).tag($0.0) }; if !cities.contains(where: { $0.0 == city }) { Text(city).tag(city) } }
                        .onChange(of: city) { _, value in if let item = cities.first(where: { $0.0 == value }) { longitude = item.1 } }
                    TextField("经度", value: $longitude, format: .number.precision(.fractionLength(2))).keyboardType(.numbersAndPunctuation)
                } header: { Text("真太阳时") } footer: { Text("按经度校正出生时刻。可修改经度，东经为正、西经为负；当前引擎以北京时间为基准。") }
                if let error { Section { Text(error).foregroundStyle(.red) } }
                Section { Text("资料保存在本机。使用个性化 AI 解读时，相关命盘内容会发送给你选择的模型服务。").font(.footnote).foregroundStyle(.secondary) }
            }.navigationTitle("出生资料").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() }.disabled(saving) }
                    ToolbarItem(placement: .confirmationAction) { Button(saving ? "整理中…" : "保存") { Task { await save() } }.disabled(saving).accessibilityIdentifier("birth.save") }
                }
        }.onAppear {
            if let existing { date = existing.date ?? date; gender = existing.gender; city = existing.city; longitude = existing.longitude }
        }
    }
    private func save() async {
        saving = true; defer { saving = false }
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let c = calendar.dateComponents([.year,.month,.day,.hour,.minute], from: date)
        let birth = BirthProfile(year: c.year!, month: c.month!, day: c.day!, hour: c.hour!, minute: c.minute!, gender: gender, city: city, longitude: longitude)
        do { try birth.validated(); try await onSave(birth); dismiss() } catch { self.error = error.localizedDescription }
    }
}

struct ChartDetailView: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let profile: Document
    @State private var selection = 0
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
                    Text("五行线索").font(SujiTheme.serif(24))
                    HStack {
                        element("日主", profile["mingPan"]["riZhu"]["wuXing"].text)
                        element("较显", profile["mingPan"]["wuXingStrength"]["strongest"].text)
                        element("较弱", profile["mingPan"]["wuXingStrength"]["weakest"].text)
                        element("用神", profile["mingPan"]["wuXingStrength"]["yongShen"].text)
                    }
                    Text(profile["mingPan"]["trueSolarTimeDesc"].text).font(.footnote).foregroundStyle(SujiTheme.secondary)
                    DisclosureGroup("结构与关系") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("格局：" + profile["mingPan"]["geJuV2"]["name"].text)
                            Text("用神：" + profile["mingPan"]["geJuV2"]["yongShen"].text)
                            Text("格局是传统分类的参照，不是对人生的评分。").foregroundStyle(SujiTheme.secondary)
                        }.font(.subheadline).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 16)
                    }
                } else {
                    Text(profile["ziweiPan"]["fiveElementsClass"].text).font(SujiTheme.serif(28))
                    LazyVGrid(columns: [GridItem(.flexible()),GridItem(.flexible())], spacing: 12) {
                        ForEach(Array(profile["ziweiPan"]["palaces"].array.enumerated()), id: \.offset) { _, palace in
                            VStack(alignment: .leading, spacing: 12) {
                                HStack { Text(palace["name"].text).font(.headline); Spacer(); Text(palace["ganZhi"].text).font(.caption).foregroundStyle(SujiTheme.secondary) }
                                Text(palace["mainStars"].array.map { $0["name"].text }.joined(separator: " · ")).font(SujiTheme.serif(20)).frame(minHeight: 28, alignment: .topLeading)
                                Text(palace["minorStars"].array.prefix(5).map { $0["name"].text }.joined(separator: " ")).font(.caption).foregroundStyle(SujiTheme.secondary)
                            }.frame(maxWidth: .infinity, alignment: .leading).padding(18).background(SujiTheme.surface, in: RoundedRectangle(cornerRadius: 18))
                        }
                    }
                }
                Text("排盘使用本地传统算法；格局、应期等规则含简化项。结果用于文化体验与自我观察。").font(.footnote).foregroundStyle(SujiTheme.secondary).lineSpacing(5)
            }.padding(24)
        }.background(SujiTheme.paper).navigationTitle("命盘手稿").navigationBarTitleDisplayMode(.inline)
    }
    private func element(_ label: String, _ value: String) -> some View { VStack(spacing: 14) { Text(value).font(SujiTheme.serif(28)).foregroundStyle(SujiTheme.sage); Text(label).font(.caption).foregroundStyle(SujiTheme.secondary) }.frame(maxWidth: .infinity).padding(.vertical, 15) }
}

struct FortuneDetailView: View {
    @Environment(AppStore.self) private var store
    let profile: Document
    @State private var year = Calendar.current.component(.year, from: Date())
    @State private var annual: Document?
    @State private var failure: String?
    private var selected: Document { annual ?? profile }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Picker("参照年份", selection: $year) { ForEach((max(1900, (store.state.birth?.year ?? year)))...min(2100, Calendar.current.component(.year, from: Date()) + 10), id: \.self) { Text(String($0) + "年").tag($0) } }
                if let failure { Text(failure).font(.footnote).foregroundStyle(SujiTheme.secondary) }
                Text(selected["timing"]["currentPhase"].text).font(SujiTheme.serif(27)).lineSpacing(8)
                Text(selected["timing"]["advice"].text).font(.body).lineSpacing(7).foregroundStyle(SujiTheme.secondary)
                Text("大运册页").font(.headline).padding(.top, 16)
                ForEach(Array(profile["mingPan"]["daYunList"].array.enumerated()), id: \.offset) { _, item in
                    HStack(spacing: 22) {
                        Text(item["ganZhi"]["gan"].text + item["ganZhi"]["zhi"].text).font(SujiTheme.serif(28)).frame(width: 70)
                        VStack(alignment: .leading, spacing: 6) { Text(item["period"].text); Text(item["shiShen"].text).font(.caption).foregroundStyle(SujiTheme.secondary) }
                        Spacer()
                    }.padding(.vertical, 15)
                    Divider()
                }
                DisclosureGroup("\(String(year))年传统推演细节") {
                    VStack(alignment: .leading, spacing: 18) {
                        ForEach([("careerOutlook","工作与行动"),("relationshipOutlook","关系与沟通"),("keyAdvice","给自己的提醒")], id: \.0) { key, label in
                            VStack(alignment: .leading, spacing: 8) { Text(label).font(.caption).foregroundStyle(SujiTheme.secondary); Text(selected["forecast"][key].text).font(.body).lineSpacing(6) }
                        }
                    }.padding(.top, 16)
                }
                Text("这些节奏不决定你的人生，也不替代医疗、财务或重大生活决策。").font(.footnote).foregroundStyle(SujiTheme.secondary)
            }.padding(24)
        }.background(SujiTheme.paper).navigationTitle("人生的节奏").navigationBarTitleDisplayMode(.inline)
            .task(id: year) {
                guard let birth = store.state.birth else { return }
                do { let value = try await store.request(["command":"forecast", "birth":store.birthJSON(birth), "year":year]); try Task.checkCancellation(); annual = value; failure = nil }
                catch is CancellationError { }
                catch { failure = error.localizedDescription }
            }
    }
}
