import AppKit
let size = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
let ctx = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = ctx
NSColor(red: 0.96, green: 0.945, blue: 0.903, alpha: 1).setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: size, height: size)).fill()
let paper = NSBezierPath()
paper.move(to: NSPoint(x: 220, y: 174)); paper.line(to: NSPoint(x: 804, y: 174)); paper.line(to: NSPoint(x: 804, y: 704)); paper.line(to: NSPoint(x: 658, y: 850)); paper.line(to: NSPoint(x: 220, y: 850)); paper.close()
NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow(); shadow.shadowColor = NSColor.black.withAlphaComponent(0.14); shadow.shadowBlurRadius = 42; shadow.shadowOffset = NSSize(width: 0, height: -20); shadow.set()
NSColor(red: 0.995, green: 0.984, blue: 0.958, alpha: 1).setFill(); paper.fill()
NSGraphicsContext.restoreGraphicsState()
let fold = NSBezierPath(); fold.move(to: NSPoint(x: 658, y: 850)); fold.line(to: NSPoint(x: 658, y: 704)); fold.line(to: NSPoint(x: 804, y: 704)); fold.close()
NSColor(red: 0.855, green: 0.844, blue: 0.79, alpha: 1).setFill(); fold.fill()
let vermilion=NSColor(red: 0.644, green: 0.278, blue: 0.208, alpha: 1)
vermilion.setFill()
let sun=NSBezierPath(ovalIn: NSRect(x: 416, y: 454, width: 192, height: 192)); sun.fill()
let mask=NSBezierPath(rect: NSRect(x: 395, y: 445, width: 235, height: 80)); NSColor(red: 0.995, green: 0.984, blue: 0.958, alpha: 1).setFill(); mask.fill()
let horizon=NSBezierPath(); horizon.move(to:NSPoint(x:334,y:523));horizon.line(to:NSPoint(x:690,y:523));horizon.lineWidth=8;vermilion.setStroke();horizon.stroke()
let text="有 时" as NSString
let attrs:[NSAttributedString.Key:Any] = [.font: NSFont(name:"Songti SC",size:92) ?? NSFont.systemFont(ofSize:92), .foregroundColor:NSColor(red:0.16,green:0.176,blue:0.153,alpha:1)]
let bounds=text.size(withAttributes:attrs);text.draw(at:NSPoint(x:(1024-bounds.width)/2,y:280),withAttributes:attrs)
NSGraphicsContext.restoreGraphicsState()
try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
