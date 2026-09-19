import Foundation

/// Source-only recovery when generated prose cannot be checked. Never interprets,
/// recalculates, or repeats the rejected draft. The original chart remains reusable.
public enum ReadingFallback {
    public static func reply(history: [ChatMessage]) -> String {
        var lines: [String] = []
        func add(_ text: String) { if !text.isEmpty && !lines.contains(text) && lines.count < 16 { lines.append(text) } }
        func text(_ value: Any?) -> String { value as? String ?? "" }
        func pillar(_ value: Any?) -> String {
            if let value = value as? String { return value }
            let object = value as? [String: Any] ?? [:]
            return text(object["gan"]) + text(object["zhi"])
        }
        for message in history where message.role == .tool {
            guard let data = message.content?.data(using: .utf8),
                  let value = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any], value["error"] == nil else { continue }
            if let year = value["yearGanZhi"] as? String, let month = value["monthGanZhi"] as? String {
                add("本次时刻：\(year)年 · \(month)月 · \(text(value["dayGanZhi"]))日")
                if let term = value["solarTerm"] as? String { add("当前节气：" + term) }
            }
            if let bazi = value["bazi"] as? [String: Any], let pillars = bazi["pillars"] as? [String: Any] {
                let names = [("year", "年"), ("month", "月"), ("day", "日"), ("hour", "时")]
                let parts = names.compactMap { key, label -> String? in
                    guard let entry = pillars[key] as? [String: Any] else { return nil }
                    let stemBranch = pillar(entry["ganZhi"])
                    return stemBranch.isEmpty ? nil : label + "柱 " + stemBranch
                }
                if parts.count == 4 { add(parts.joined(separator: " · ")) }
            }
            if let palace = value["palace"] as? String, let main = value["mainStars"] as? [String] {
                add("\(palace) · \(text(value["ganZhi"]))；主星：\(main.isEmpty ? "无主星" : main.joined(separator: "、"))")
            }
            if let original = value["benGua"] as? [String: Any], let changed = value["bianGua"] as? [String: Any],
               let raw = value["lineValues"] as? [Int], raw.count == 6 {
                add("本卦：\(text(original["name"]))；变卦：\(text(changed["name"]))")
                add("原始爻值（初爻到上爻）：" + raw.map(String.init).joined(separator: "、"))
                if let moving = value["changingYao"] as? [Int] { add("动爻：" + (moving.isEmpty ? "无" : moving.map(String.init).joined(separator: "、"))) }
                add("本卦上\(text(original["upper"]))下\(text(original["lower"]))；变卦上\(text(changed["upper"]))下\(text(changed["lower"]))")
            }
            if let dun = value["yinYangDun"] as? String, let number = value["juNumber"] as? Int {
                add("\(dun)遁\(number)局 · \(text(value["yuan"]))元 · \(text(value["jieqi"]))")
                if let position = value["zhiFuPalaceId"] as? Int { add("值符：\(text(value["zhiFuStar"]))，落\(position)宫") }
                if let position = value["zhiShiPalaceId"] as? Int { add("值使：\(text(value["zhiShiMen"]))，落\(position)宫") }
            }
        }
        let introduction = "这次生成的解读未能与盘面核对一致，暂未采用。我先把已计算的事实留给你："
        guard !lines.isEmpty else { return "这次生成的解读未能与已有资料核对一致，暂未采用。已取得的计算记录保留在“计算依据”中；你可以重试解读，原盘不会重起。" }
        return introduction + "\n\n" + lines.map { "• " + $0 }.joined(separator: "\n") + "\n\n这些是排盘记录，不是对现实事件的预测。完整资料在“计算依据”中；重试会沿用原盘。"
    }
}
