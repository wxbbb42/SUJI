import Foundation

/// Lossless storage and transport for bounded conditional calendar rows.
/// It shares exact timestamp strings and trigger arrays, never derives or drops a date.
enum QimenTimingTransport {
    private static let key="qimenTimingDateRows"
    private static let columns=["unit","ganZhi","branch","startsAt","endsAt","eligibleStart","eligibleEnd","triggerIds","firstWindow"]
    private static let format="If timestamps is an object, expand each offset to canonical ISO UTC milliseconds at base + offset * stepMilliseconds. At /timing/dates map each row to columns. Columns 3–6 are zero-based indices into timestamps; column 7 is an index into triggerSets. Other columns are literal values. Preserve every row and array order; remove qimenTimingDateRows and use original evidence pointers after expansion."
    private static func valid(_ row:[String:JSONValue]) -> Bool {
        guard Set(row.keys)==Set(columns),case let .string(unit)=row["unit"],["year","month","day","hour"].contains(unit),
              case let .string(gz)=row["ganZhi"],gz.count==2,case let .string(branch)=row["branch"],branch.count==1,
              case .bool=row["firstWindow"],case let .array(triggers)=row["triggerIds"],!triggers.isEmpty,
              triggers.allSatisfy({ if case let .string(id)=$0 { return !id.isEmpty };return false }) else { return false }
        return columns[3...6].allSatisfy { if case let .string(t)=row[$0] { return !t.isEmpty };return false }
    }
    private static func milliseconds(_ text:String)->Int64? {
        let f=ISO8601DateFormatter();f.formatOptions=[.withInternetDateTime,.withFractionalSeconds]
        guard text.utf8.count==24,let date=f.date(from:text),f.string(from:date)==text else{return nil}
        return Int64((date.timeIntervalSince1970*1000).rounded())
    }
    private static func timestamp(_ milliseconds:Int64)->String? {
        guard (-62135596800000...253402300799999).contains(milliseconds) else{return nil}
        let f=ISO8601DateFormatter();f.formatOptions=[.withInternetDateTime,.withFractionalSeconds]
        let text=f.string(from:Date(timeIntervalSince1970:Double(milliseconds)/1000))
        guard Self.milliseconds(text)==milliseconds else{return nil};return text
    }
    private static func compactTimes(_ times:[JSONValue])->JSONValue {
        let millis=times.compactMap { if case let .string(t)=$0{return milliseconds(t)};return nil }
        guard millis.count==times.count,let base=millis.min(),let baseText=timestamp(base) else{return .array(times)}
        func gcd(_ a:Int64,_ b:Int64)->Int64 {var a=a,b=b;while b != 0 {(a,b)=(b,a%b)};return a}
        let step=millis.reduce(Int64(0)){gcd($0,$1-base)}
        guard step>0 else{return .array(times)}
        let grid:JSONValue=["base":.string(baseText),"stepMilliseconds":.integer(step),"offsets":.array(millis.map{.integer(($0-base)/step)})]
        guard expandTimes(grid)==times,ReadingVerificationEvidence.encoded(grid).utf8.count<ReadingVerificationEvidence.encoded(times).utf8.count else{return .array(times)}
        return grid
    }
    private static func expandTimes(_ value:JSONValue)->[JSONValue]? {
        if case let .array(times)=value{return times}
        guard case let .object(grid)=value,Set(grid.keys)==Set(["base","stepMilliseconds","offsets"]),
              case let .string(text)=grid["base"],let base=milliseconds(text),
              case let .integer(step)=grid["stepMilliseconds"],step>0,
              case let .array(offsets)=grid["offsets"],!offsets.isEmpty,offsets.count<=1024 else{return nil}
        var times:[JSONValue]=[]
        for offset in offsets {
            guard case let .integer(index)=offset,index>=0 else{return nil}
            let (delta,multiplyOverflow)=index.multipliedReportingOverflow(by:step)
            let (millis,addOverflow)=base.addingReportingOverflow(delta)
            guard !multiplyOverflow,!addOverflow,let text=timestamp(millis) else{return nil}
            times.append(.string(text))
        }
        return times
    }
    static func encode(_ raw:String)->String {
        guard let value=try? JSONDecoder().decode(JSONValue.self,from:Data(raw.utf8)),case var .object(root)=value,root[key]==nil,
              case var .object(timing)=root["timing"],case let .array(dates)=timing["dates"],(2...256).contains(dates.count) else { return raw }
        var timestamps:[JSONValue]=[],sets:[JSONValue]=[],rows:[JSONValue]=[]
        for date in dates {
            guard case let .object(fields)=date,valid(fields) else { return raw }
            var row=columns.map { fields[$0]! }
            for i in 3...6 {
                if let index=timestamps.firstIndex(of:row[i]) { row[i] = .integer(Int64(index)) }
                else { timestamps.append(row[i]);row[i] = .integer(Int64(timestamps.count-1)) }
            }
            if let index=sets.firstIndex(of:row[7]) { row[7] = .integer(Int64(index)) }
            else { sets.append(row[7]);row[7] = .integer(Int64(sets.count-1)) }
            rows.append(.array(row))
        }
        timing["dates"] = .array(rows);root["timing"] = .object(timing)
        root[key] = ["version":1,"columns":.array(columns.map(JSONValue.string)),"timestamps":compactTimes(timestamps),"triggerSets":.array(sets),"format":.string(format)]
        let packed=ReadingVerificationEvidence.encoded(JSONValue.object(root))
        return packed.utf16.count<raw.utf16.count && packed.utf8.count<raw.utf8.count ? packed:raw
    }
    static func expand(_ value:JSONValue)->JSONValue? {
        guard case var .object(root)=value else { return value }
        guard let metadata=root[key] else {
            if case let .array(dates)=ReadingVerificationEvidence.pointer("/timing/dates",in:value),dates.contains(where:{if case .array=$0{return true};return false}) { return nil }
            return value
        }
        guard case let .object(m)=metadata,Set(m.keys)==Set(["version","columns","timestamps","triggerSets","format"]),m["version"]==1,
              m["columns"] == .array(columns.map(JSONValue.string)),m["format"] == .string(format),
              let encodedTimes=m["timestamps"],let times=expandTimes(encodedTimes),!times.isEmpty,times.count<=1024,
              case let .array(sets)=m["triggerSets"],!sets.isEmpty,sets.count<=256,
              case var .object(timing)=root["timing"],case let .array(rows)=timing["dates"],(2...256).contains(rows.count) else { return nil }
        let strings=times.compactMap { if case let .string(s)=$0,!s.isEmpty { return s };return nil }
        guard strings.count==times.count,Set(strings).count==times.count else { return nil }
        for (i,set) in sets.enumerated() {
            guard case let .array(ids)=set,!ids.isEmpty,ids.allSatisfy({ if case let .string(s)=$0{return !s.isEmpty};return false }),!sets.prefix(i).contains(set) else { return nil }
        }
        var dates:[JSONValue]=[],usedTimes=Set<Int>(),usedSets=Set<Int>()
        for row in rows {
            guard case var .array(fields)=row,fields.count==columns.count else { return nil }
            for i in 3...7 {
                let table=i==7 ? sets:times
                guard case let .integer(index)=fields[i],index>=0,index<table.count else { return nil }
                fields[i]=table[Int(index)]
                if i==7 {usedSets.insert(Int(index))}else{usedTimes.insert(Int(index))}
            }
            let restored=Dictionary(uniqueKeysWithValues:zip(columns,fields))
            guard valid(restored) else { return nil };dates.append(.object(restored))
        }
        guard usedTimes.count==times.count,usedSets.count==sets.count else { return nil }
        timing["dates"] = .array(dates);root["timing"] = .object(timing);root.removeValue(forKey:key)
        return .object(root)
    }
}
