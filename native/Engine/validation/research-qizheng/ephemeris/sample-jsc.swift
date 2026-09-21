// Research only: run on macOS with Swift and JavaScriptCore.
// Usage: swift sample-jsc.swift library-directory output-directory
import Foundation
import JavaScriptCore

guard CommandLine.arguments.count == 3 else { fatalError("Expected library and output directories") }
let library = URL(fileURLWithPath: CommandLine.arguments[1])
let output = URL(fileURLWithPath: CommandLine.arguments[2])
let context = JSContext()!
var failure: String?
context.exceptionHandler = { _, error in failure = error?.toString() }
context.evaluateScript(try String(contentsOf: library.appendingPathComponent("astronomy.browser.min.js"), encoding: .utf8))
if let failure { fatalError(failure) }
context.setObject(try String(contentsOf: output.appendingPathComponent("candidate.json"), encoding: .utf8),
                  forKeyedSubscript: "inputJSON" as NSString)
let result = context.evaluateScript("""
(function() {
  const started = Date.now();
  function coordinates(instant, body) {
    const date = new Date(instant), vector = Astronomy.GeoVector(body, date, true);
    const e = Astronomy.Ecliptic(vector);
    const q = Astronomy.EquatorFromVector(Astronomy.RotateVector(Astronomy.Rotation_EQJ_EQD(date), vector));
    return { longitude: e.elon, latitude: e.elat, rightAscensionDegrees: q.ra * 15, declination: q.dec };
  }
  const rows = JSON.parse(inputJSON).map(r => ({instant: r.instant, body: r.body, ...coordinates(r.instant, r.body)}));
  const checks = ['Sun','Moon','Mercury','Venus','Mars','Jupiter','Saturn'].map(body => {
    const a = coordinates('2026-09-20T04:00:00Z', body);
    const b = coordinates('2026-09-20T12:00:00+08:00', body);
    const c = coordinates('2026-09-19T21:00:00-07:00', body);
    return {body, equal: JSON.stringify(a) === JSON.stringify(b) && JSON.stringify(a) === JSON.stringify(c)};
  });
  return JSON.stringify({ rows, equalInstantChecks: checks, calculationMilliseconds: Date.now() - started });
})()
""")
if let failure { fatalError(failure) }
guard let json = result?.toString() else { fatalError("No result") }
try json.write(to: output.appendingPathComponent("jsc.json"), atomically: true, encoding: .utf8)
print("JavaScriptCore samples written; reference and runtime comparisons pending")
