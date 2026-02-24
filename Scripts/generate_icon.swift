#!/usr/bin/env swift

import AppKit
import Foundation

/// Draws the LogSeq Todos app icon at a given size
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

    // --- Background: rounded rect with gradient ---
    let bgPath = CGPath(roundedRect: innerRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    ctx.saveGState()
    ctx.addPath(bgPath)
    ctx.clip()

    let colors = [
        CGColor(srgbRed: 0.20, green: 0.40, blue: 0.85, alpha: 1.0),  // deep blue
        CGColor(srgbRed: 0.35, green: 0.55, blue: 0.95, alpha: 1.0),  // mid blue
        CGColor(srgbRed: 0.25, green: 0.75, blue: 0.90, alpha: 1.0),  // teal
    ]
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0.0, 0.5, 1.0])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: innerRect.minX, y: innerRect.maxY), end: CGPoint(x: innerRect.maxX, y: innerRect.minY), options: [])
    ctx.restoreGState()

    // --- Subtle inner shadow / border ---
    ctx.saveGState()
    ctx.addPath(bgPath)
    ctx.setStrokeColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.15))
    ctx.setLineWidth(size * 0.015)
    ctx.strokePath()
    ctx.restoreGState()

    // --- Draw todo list lines ---
    let white = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1.0)
    let whiteLight = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.5)

    let lineX = innerRect.minX + size * 0.32
    let lineEndX = innerRect.maxX - size * 0.12
    let lineWidth = size * 0.028
    let lineSpacing = size * 0.145

    let checkboxX = innerRect.minX + size * 0.12
    let checkboxSize = size * 0.10

    // Three todo items
    let topY = innerRect.maxY - size * 0.26

    for i in 0..<3 {
        let y = topY - CGFloat(i) * lineSpacing

        // Checkbox circle
        let cbRect = CGRect(x: checkboxX, y: y - checkboxSize / 2, width: checkboxSize, height: checkboxSize)

        if i == 0 {
            // First item: completed (filled circle with checkmark)
            ctx.saveGState()
            ctx.setFillColor(white)
            ctx.fillEllipse(in: cbRect)
            ctx.restoreGState()

            // Draw checkmark inside
            ctx.saveGState()
            ctx.setStrokeColor(CGColor(srgbRed: 0.25, green: 0.50, blue: 0.90, alpha: 1.0))
            ctx.setLineWidth(size * 0.025)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            let checkStart = CGPoint(x: cbRect.minX + checkboxSize * 0.22, y: cbRect.midY)
            let checkMid = CGPoint(x: cbRect.minX + checkboxSize * 0.42, y: cbRect.minY + checkboxSize * 0.25)
            let checkEnd = CGPoint(x: cbRect.maxX - checkboxSize * 0.18, y: cbRect.maxY - checkboxSize * 0.22)
            ctx.move(to: checkStart)
            ctx.addLine(to: checkMid)
            ctx.addLine(to: checkEnd)
            ctx.strokePath()
            ctx.restoreGState()

            // Strikethrough line (completed task)
            ctx.saveGState()
            ctx.setStrokeColor(whiteLight)
            ctx.setLineWidth(lineWidth)
            ctx.setLineCap(.round)
            ctx.move(to: CGPoint(x: lineX, y: y))
            ctx.addLine(to: CGPoint(x: lineEndX - size * 0.06, y: y))
            ctx.strokePath()
            ctx.restoreGState()
        } else {
            // Uncompleted items: open circle
            ctx.saveGState()
            ctx.setStrokeColor(white)
            ctx.setLineWidth(size * 0.02)
            ctx.strokeEllipse(in: cbRect.insetBy(dx: size * 0.01, dy: size * 0.01))
            ctx.restoreGState()

            // Line text representation
            let lineLength: CGFloat = i == 1 ? (lineEndX - lineX) : (lineEndX - lineX) * 0.7
            ctx.saveGState()
            ctx.setStrokeColor(white)
            ctx.setLineWidth(lineWidth)
            ctx.setLineCap(.round)
            ctx.move(to: CGPoint(x: lineX, y: y))
            ctx.addLine(to: CGPoint(x: lineX + lineLength, y: y))
            ctx.strokePath()
            ctx.restoreGState()
        }
    }

    // --- Small LogSeq-inspired graph nodes at bottom-right ---
    let nodeRadius = size * 0.025
    let n1 = CGPoint(x: innerRect.maxX - size * 0.18, y: innerRect.minY + size * 0.18)
    let n2 = CGPoint(x: innerRect.maxX - size * 0.10, y: innerRect.minY + size * 0.26)
    let n3 = CGPoint(x: innerRect.maxX - size * 0.22, y: innerRect.minY + size * 0.30)

    // Edges
    ctx.saveGState()
    ctx.setStrokeColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.4))
    ctx.setLineWidth(size * 0.012)
    ctx.move(to: n1); ctx.addLine(to: n2); ctx.strokePath()
    ctx.move(to: n1); ctx.addLine(to: n3); ctx.strokePath()
    ctx.move(to: n2); ctx.addLine(to: n3); ctx.strokePath()
    ctx.restoreGState()

    // Nodes
    for pt in [n1, n2, n3] {
        ctx.saveGState()
        ctx.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.8))
        ctx.fillEllipse(in: CGRect(x: pt.x - nodeRadius, y: pt.y - nodeRadius, width: nodeRadius * 2, height: nodeRadius * 2))
        ctx.restoreGState()
    }

    image.unlockFocus()
    return image
}

/// Convert NSImage to PNG Data
func pngData(from image: NSImage) -> Data? {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff) else { return nil }
    return rep.representation(using: .png, properties: [:])
}

// ---- Main ----

let outputDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."

// macOS icon sizes: 16, 32, 64, 128, 256, 512, 1024
let sizes: [(name: String, px: CGFloat)] = [
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

for entry in sizes {
    let img = drawIcon(size: entry.px)
    if let data = pngData(from: img) {
        let path = (outputDir as NSString).appendingPathComponent("\(entry.name).png")
        try! data.write(to: URL(fileURLWithPath: path))
        print("Generated \(entry.name).png (\(Int(entry.px))x\(Int(entry.px)))")
    }
}

print("Done! Icons written to \(outputDir)")
