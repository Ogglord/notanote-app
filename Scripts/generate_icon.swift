#!/usr/bin/env swift

import AppKit
import Foundation
import CoreText

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Helpers
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/// Convert NSImage to PNG Data
func pngData(from image: NSImage) -> Data? {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff) else { return nil }
    return rep.representation(using: .png, properties: [:])
}

/// Draw a single character centered at a point
func drawLetter(
    _ ch: String,
    at center: CGPoint,
    fontSize: CGFloat,
    weight: NSFont.Weight = .heavy,
    color: NSColor = .white
) {
    let font = NSFont.systemFont(ofSize: fontSize, weight: weight)
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
    ]
    let str = NSAttributedString(string: ch, attributes: attributes)
    let strSize = str.size()
    let origin = NSPoint(
        x: center.x - strSize.width / 2,
        y: center.y - strSize.height / 2
    )
    str.draw(at: origin)
}

/// Create a linear gradient along a path by stroking
func strokeGradientPath(
    ctx: CGContext,
    from: CGPoint,
    through: CGPoint,
    to: CGPoint,
    lineWidth: CGFloat,
    colors: [CGColor],
    gradientStart: CGPoint,
    gradientEnd: CGPoint
) {
    let path = CGMutablePath()
    path.move(to: from)
    path.addLine(to: through)
    path.addLine(to: to)

    ctx.saveGState()
    let strokedPath = path.copy(strokingWithWidth: lineWidth, lineCap: .round, lineJoin: .round, miterLimit: 10)
    ctx.addPath(strokedPath)
    ctx.clip()

    let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: colors as CFArray,
        locations: nil
    )!
    ctx.drawLinearGradient(gradient, start: gradientStart, end: gradientEnd, options: [])
    ctx.restoreGState()
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - App Icon: "NOT" (dark, current)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    let inset = size * 0.08
    let cornerRadius = size * 0.22
    let innerRect = rect.insetBy(dx: inset, dy: inset)

    // Background gradient
    let bgPath = CGPath(roundedRect: innerRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    ctx.saveGState()
    ctx.addPath(bgPath)
    ctx.clip()

    let colors = [
        CGColor(srgbRed: 0.12, green: 0.12, blue: 0.28, alpha: 1.0),
        CGColor(srgbRed: 0.18, green: 0.16, blue: 0.42, alpha: 1.0),
        CGColor(srgbRed: 0.28, green: 0.22, blue: 0.55, alpha: 1.0),
    ]
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0.0, 0.5, 1.0])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: innerRect.minX, y: innerRect.maxY), end: CGPoint(x: innerRect.maxX, y: innerRect.minY), options: [])
    ctx.restoreGState()

    // Border
    ctx.saveGState()
    ctx.addPath(bgPath)
    ctx.setStrokeColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.12))
    ctx.setLineWidth(size * 0.012)
    ctx.strokePath()
    ctx.restoreGState()

    // Checkmark anchor points
    let nCenter = CGPoint(x: innerRect.minX + innerRect.width * 0.22, y: innerRect.minY + innerRect.height * 0.62)
    let oCenter = CGPoint(x: innerRect.minX + innerRect.width * 0.38, y: innerRect.minY + innerRect.height * 0.28)
    let tCenter = CGPoint(x: innerRect.minX + innerRect.width * 0.78, y: innerRect.minY + innerRect.height * 0.78)

    // Checkmark stroke behind letters
    ctx.saveGState()
    ctx.addPath(bgPath)
    ctx.clip()

    ctx.saveGState()
    ctx.setStrokeColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.15))
    ctx.setLineWidth(size * 0.055)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.move(to: nCenter)
    ctx.addLine(to: oCenter)
    ctx.addLine(to: tCenter)
    ctx.strokePath()
    ctx.restoreGState()

    // Letters
    let baseFontSize = size * 0.26
    drawLetter("N", at: nCenter, fontSize: baseFontSize)
    drawLetter("O", at: oCenter, fontSize: baseFontSize * 1.05)
    drawLetter("T", at: tCenter, fontSize: baseFontSize)

    // Accent circle around O
    let accentRadius = size * 0.115
    ctx.saveGState()
    ctx.setStrokeColor(CGColor(srgbRed: 0.65, green: 0.55, blue: 1.0, alpha: 0.35))
    ctx.setLineWidth(size * 0.012)
    ctx.strokeEllipse(in: CGRect(x: oCenter.x - accentRadius, y: oCenter.y - accentRadius, width: accentRadius * 2, height: accentRadius * 2))
    ctx.restoreGState()

    ctx.restoreGState()

    image.unlockFocus()
    return image
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - App Icon: Alternative (colorful, light background)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func drawAlternativeIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    let inset = size * 0.08
    let cornerRadius = size * 0.22
    let innerRect = rect.insetBy(dx: inset, dy: inset)

    // ── White/light background ──
    let bgPath = CGPath(roundedRect: innerRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    ctx.saveGState()
    ctx.addPath(bgPath)
    ctx.clip()
    ctx.setFillColor(CGColor(srgbRed: 0.97, green: 0.97, blue: 0.98, alpha: 1.0))
    ctx.fill(innerRect)
    ctx.restoreGState()

    // Subtle colored border (gradient from blue to orange along bottom-right)
    ctx.saveGState()
    ctx.addPath(bgPath)
    ctx.clip()
    let borderColors = [
        CGColor(srgbRed: 0.15, green: 0.55, blue: 0.85, alpha: 0.5),
        CGColor(srgbRed: 0.30, green: 0.75, blue: 0.45, alpha: 0.5),
        CGColor(srgbRed: 0.95, green: 0.55, blue: 0.15, alpha: 0.5),
    ]
    let borderGrad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: borderColors as CFArray, locations: [0.0, 0.5, 1.0])!
    // Draw border by stroking the path with the gradient
    let borderPath = bgPath.copy(strokingWithWidth: size * 0.025, lineCap: .round, lineJoin: .round, miterLimit: 10)
    ctx.saveGState()
    ctx.addPath(borderPath)
    ctx.clip()
    ctx.drawLinearGradient(borderGrad, start: CGPoint(x: innerRect.minX, y: innerRect.maxY), end: CGPoint(x: innerRect.maxX, y: innerRect.minY), options: [])
    ctx.restoreGState()
    ctx.restoreGState()

    // ── Clip to inner rect for content ──
    ctx.saveGState()
    ctx.addPath(bgPath)
    ctx.clip()

    // Key geometry points
    let cx = innerRect.midX
    let cy = innerRect.midY

    // The large "O" circle
    let oRadius = size * 0.28
    let oCenter = CGPoint(x: cx + size * 0.02, y: cy - size * 0.02)

    // Checkmark points (the check goes through the O circle)
    let checkStart = CGPoint(x: cx - size * 0.20, y: cy + size * 0.08)   // top of short arm
    let checkVertex = CGPoint(x: cx - size * 0.06, y: cy - size * 0.22)  // bottom vertex
    let checkEnd = CGPoint(x: cx + size * 0.26, y: cy + size * 0.28)     // top of long arm

    // ── Draw the O circle with gradient stroke (blue → green → orange) ──
    let oCirclePath = CGMutablePath()
    oCirclePath.addEllipse(in: CGRect(x: oCenter.x - oRadius, y: oCenter.y - oRadius, width: oRadius * 2, height: oRadius * 2))
    let oStrokeWidth = size * 0.045

    ctx.saveGState()
    let oStrokedPath = oCirclePath.copy(strokingWithWidth: oStrokeWidth, lineCap: .round, lineJoin: .round, miterLimit: 10)
    ctx.addPath(oStrokedPath)
    ctx.clip()
    let oGradColors = [
        CGColor(srgbRed: 0.10, green: 0.50, blue: 0.85, alpha: 1.0),   // blue
        CGColor(srgbRed: 0.15, green: 0.70, blue: 0.60, alpha: 1.0),   // teal
        CGColor(srgbRed: 0.40, green: 0.80, blue: 0.30, alpha: 1.0),   // green
        CGColor(srgbRed: 0.95, green: 0.65, blue: 0.15, alpha: 1.0),   // orange
    ]
    let oGrad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: oGradColors as CFArray, locations: [0.0, 0.35, 0.65, 1.0])!
    ctx.drawLinearGradient(oGrad, start: CGPoint(x: innerRect.minX, y: innerRect.maxY), end: CGPoint(x: innerRect.maxX, y: innerRect.minY), options: [])
    ctx.restoreGState()

    // ── Draw the checkmark with gradient (green) ──
    let checkWidth = size * 0.065
    let checkColors = [
        CGColor(srgbRed: 0.10, green: 0.55, blue: 0.75, alpha: 1.0),   // teal
        CGColor(srgbRed: 0.30, green: 0.75, blue: 0.35, alpha: 1.0),   // green
        CGColor(srgbRed: 0.55, green: 0.85, blue: 0.25, alpha: 1.0),   // lime
    ]
    strokeGradientPath(
        ctx: ctx,
        from: checkStart,
        through: checkVertex,
        to: checkEnd,
        lineWidth: checkWidth,
        colors: checkColors,
        gradientStart: CGPoint(x: checkStart.x, y: checkStart.y),
        gradientEnd: CGPoint(x: checkEnd.x, y: checkEnd.y)
    )

    // ── Draw the "N" letter (blue-to-teal gradient) ──
    let nFontSize = size * 0.38
    let nFont = NSFont.systemFont(ofSize: nFontSize, weight: .heavy)
    let nAttrs: [NSAttributedString.Key: Any] = [.font: nFont, .foregroundColor: NSColor.white]
    let nStr = NSAttributedString(string: "N", attributes: nAttrs)
    let nSize = nStr.size()
    let nOrigin = CGPoint(x: innerRect.minX + size * 0.08, y: cy - nSize.height * 0.35)

    // Draw N as a mask and fill with gradient
    ctx.saveGState()
    ctx.textMatrix = .identity
    let nLine = CTLineCreateWithAttributedString(nStr)
    ctx.textPosition = nOrigin
    _ = CTLineGetBoundsWithOptions(nLine, [])
    // Create clipping from the text glyphs
    ctx.textPosition = nOrigin
    let runs = CTLineGetGlyphRuns(nLine) as! [CTRun]
    for run in runs {
        let glyphCount = CTRunGetGlyphCount(run)
        var glyphs = [CGGlyph](repeating: 0, count: glyphCount)
        var positions = [CGPoint](repeating: .zero, count: glyphCount)
        CTRunGetGlyphs(run, CFRangeMake(0, glyphCount), &glyphs)
        CTRunGetPositions(run, CFRangeMake(0, glyphCount), &positions)
        let runFont = (CTRunGetAttributes(run) as Dictionary)[kCTFontAttributeName] as! CTFont
        if let glyphPaths = CTFontCreatePathForGlyph(runFont, glyphs[0], nil) {
            var t = CGAffineTransform(translationX: nOrigin.x + positions[0].x, y: nOrigin.y + positions[0].y)
            if let moved = glyphPaths.copy(using: &t) {
                ctx.addPath(moved)
            }
        }
    }
    ctx.clip()
    let nGradColors = [
        CGColor(srgbRed: 0.10, green: 0.45, blue: 0.80, alpha: 1.0),
        CGColor(srgbRed: 0.10, green: 0.60, blue: 0.75, alpha: 1.0),
        CGColor(srgbRed: 0.15, green: 0.72, blue: 0.65, alpha: 1.0),
    ]
    let nGrad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: nGradColors as CFArray, locations: nil)!
    let nGradRect = CGRect(x: nOrigin.x, y: nOrigin.y, width: nSize.width, height: nSize.height)
    ctx.drawLinearGradient(nGrad, start: CGPoint(x: nGradRect.minX, y: nGradRect.maxY), end: CGPoint(x: nGradRect.maxX, y: nGradRect.minY), options: [])
    ctx.restoreGState()

    // ── Draw the small "t" (orange) ──
    let tFontSize = size * 0.20
    let tCenter = CGPoint(x: cx + size * 0.30, y: cy + size * 0.12)
    drawLetter("t", at: tCenter, fontSize: tFontSize, weight: .bold, color: NSColor(srgbRed: 0.95, green: 0.55, blue: 0.15, alpha: 1.0))

    ctx.restoreGState() // restore clip

    image.unlockFocus()
    return image
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Menu Bar Icons (template images, black on transparent)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/// "not" style: V-checkmark with a small circle at the vertex
func drawMenuBarNOT(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    let black = CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1.0)
    let pad = size * 0.10

    // Checkmark anchor points
    let nPt = CGPoint(x: pad, y: size * 0.62)
    let oPt = CGPoint(x: size * 0.35, y: pad)
    let tPt = CGPoint(x: size - pad, y: size * 0.88)

    // Checkmark stroke
    ctx.saveGState()
    ctx.setStrokeColor(black)
    ctx.setLineWidth(size * 0.12)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.move(to: nPt)
    ctx.addLine(to: oPt)
    ctx.addLine(to: tPt)
    ctx.strokePath()
    ctx.restoreGState()

    // Small circle at the vertex (the "O")
    let circleRadius = size * 0.11
    ctx.saveGState()
    ctx.setStrokeColor(black)
    ctx.setLineWidth(size * 0.07)
    ctx.strokeEllipse(in: CGRect(
        x: oPt.x - circleRadius,
        y: oPt.y - circleRadius,
        width: circleRadius * 2,
        height: circleRadius * 2
    ))
    ctx.restoreGState()

    image.unlockFocus()
    return image
}

/// "alt" style: N with checkmark + circle (simplified)
func drawMenuBarAlt(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    let black = CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1.0)
    let pad = size * 0.06
    let strokeW = size * 0.09

    // Draw "N" using strokes
    let nLeft = pad
    let nRight = size * 0.45
    let nTop = size - pad
    let nBottom = pad + size * 0.05

    ctx.saveGState()
    ctx.setStrokeColor(black)
    ctx.setLineWidth(strokeW)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    // Left vertical
    ctx.move(to: CGPoint(x: nLeft, y: nBottom))
    ctx.addLine(to: CGPoint(x: nLeft, y: nTop))
    // Diagonal
    ctx.addLine(to: CGPoint(x: nRight, y: nBottom))
    // Right vertical
    ctx.addLine(to: CGPoint(x: nRight, y: nTop))
    ctx.strokePath()
    ctx.restoreGState()

    // Small checkmark extending from N
    let checkStart = CGPoint(x: nRight + size * 0.02, y: size * 0.55)
    let checkVertex = CGPoint(x: nRight + size * 0.12, y: pad)
    let checkEnd = CGPoint(x: size - pad, y: size * 0.78)

    ctx.saveGState()
    ctx.setStrokeColor(black)
    ctx.setLineWidth(strokeW * 0.85)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.move(to: checkStart)
    ctx.addLine(to: checkVertex)
    ctx.addLine(to: checkEnd)
    ctx.strokePath()
    ctx.restoreGState()

    // Small circle at vertex
    let cRadius = size * 0.08
    ctx.saveGState()
    ctx.setStrokeColor(black)
    ctx.setLineWidth(strokeW * 0.6)
    ctx.strokeEllipse(in: CGRect(
        x: checkVertex.x - cRadius,
        y: checkVertex.y - cRadius,
        width: cRadius * 2,
        height: cRadius * 2
    ))
    ctx.restoreGState()

    image.unlockFocus()
    return image
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Main
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

let outputDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."

// macOS icon sizes
let iconSizes: [(name: String, px: CGFloat)] = [
    ("icon_16x16", 16),
    ("icon_16x16@2x", 32),
    ("icon_32x32", 32),
    ("icon_32x32@2x", 64),
    ("icon_128x128", 128),
    ("icon_128x128@2x", 256),
    ("icon_256x256", 256),
    ("icon_256x256@2x", 512),
    ("icon_512x512", 512),
    ("icon_512x512@2x", 1024),
]

let fm = FileManager.default
try? fm.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

// ── Generate primary app icon ──
for entry in iconSizes {
    let img = drawIcon(size: entry.px)
    if let data = pngData(from: img) {
        let path = (outputDir as NSString).appendingPathComponent("\(entry.name).png")
        try! data.write(to: URL(fileURLWithPath: path))
        print("Generated \(entry.name).png (\(Int(entry.px))x\(Int(entry.px)))")
    }
}

// ── Generate alternative app icon (preview at 512px) ──
let altPreviewDir = (outputDir as NSString).deletingLastPathComponent
for entry in [("alt-icon-512", CGFloat(512)), ("alt-icon-256", CGFloat(256))] {
    let img = drawAlternativeIcon(size: entry.1)
    if let data = pngData(from: img) {
        let path = (altPreviewDir as NSString).appendingPathComponent("\(entry.0).png")
        try! data.write(to: URL(fileURLWithPath: path))
        print("Generated \(entry.0).png")
    }
}

// ── Generate menu bar icons (18pt = 18px @1x, 36px @2x) ──
let menuBarSizes: [(suffix: String, px: CGFloat)] = [
    ("", 18),
    ("@2x", 36),
]

for entry in menuBarSizes {
    // "not" style
    let notImg = drawMenuBarNOT(size: entry.px)
    if let data = pngData(from: notImg) {
        let path = (outputDir as NSString).appendingPathComponent("menubar-not\(entry.suffix).png")
        try! data.write(to: URL(fileURLWithPath: path))
        print("Generated menubar-not\(entry.suffix).png (\(Int(entry.px))x\(Int(entry.px)))")
    }

    // "alt" style
    let altImg = drawMenuBarAlt(size: entry.px)
    if let data = pngData(from: altImg) {
        let path = (outputDir as NSString).appendingPathComponent("menubar-alt\(entry.suffix).png")
        try! data.write(to: URL(fileURLWithPath: path))
        print("Generated menubar-alt\(entry.suffix).png (\(Int(entry.px))x\(Int(entry.px)))")
    }
}

print("Done! Icons written to \(outputDir)")
