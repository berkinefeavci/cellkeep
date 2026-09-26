#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
menubar_dir="$repo_root/Sources/ChargeMate/Resources/Assets.xcassets/Menubar"

rm -rf "$menubar_dir"
mkdir -p "$menubar_dir"

swift - "$menubar_dir" <<'SWIFT'
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let arguments = CommandLine.arguments
guard arguments.count == 2 else {
    fputs("usage: make-menubar-icons.sh <output-directory>\n", stderr)
    exit(2)
}

let outputDirectory = URL(fileURLWithPath: arguments[1], isDirectory: true)
let states = ["charging", "paused", "discharging", "unplugged", "limited"]
let styles = ["native", "bold", "colored"]
let colors: [String: (CGFloat, CGFloat, CGFloat, CGFloat)] = [
    "charging": (0.18, 0.72, 0.35, 1),
    "paused": (0.18, 0.43, 0.86, 1),
    "discharging": (0.92, 0.50, 0.12, 1),
    "unplugged": (0.43, 0.46, 0.50, 1),
    "limited": (0.18, 0.72, 0.35, 1)
]

func cgColor(_ rgba: (CGFloat, CGFloat, CGFloat, CGFloat)) -> CGColor {
    CGColor(red: rgba.0, green: rgba.1, blue: rgba.2, alpha: rgba.3)
}

func roundedRect(_ context: CGContext, _ rect: CGRect, radius: CGFloat) {
    context.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
}

func drawGlyph(_ context: CGContext, state: String, style: String, color: CGColor) {
    let isBold = style == "bold"
    let isColored = style == "colored"
    let lineWidth: CGFloat = isBold ? 2.0 : 1.25
    let ink = isColored ? color : CGColor.black
    let clear = CGColor.clear

    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.setLineWidth(lineWidth)

    if isBold {
        context.setFillColor(ink)
        roundedRect(context, CGRect(x: 2, y: 3, width: 17, height: 10,), radius: 2.2)
        context.fillPath()
        context.setFillColor(isColored ? CGColor.white : clear)
    } else {
        context.setStrokeColor(ink)
        roundedRect(context, CGRect(x: 2.25, y: 3.25, width: 16.5, height: 9.5), radius: 1.8)
        context.strokePath()
        context.setStrokeColor(ink)
    }

    if isBold {
        switch state {
        case "charging":
            context.setFillColor(isColored ? CGColor.white : clear)
            context.move(to: CGPoint(x: 11.2, y: 4.8))
            context.addLine(to: CGPoint(x: 8.0, y: 8.5))
            context.addLine(to: CGPoint(x: 10.5, y: 8.5))
            context.addLine(to: CGPoint(x: 9.3, y: 11.2))
            context.addLine(to: CGPoint(x: 13.6, y: 7.0))
            context.addLine(to: CGPoint(x: 11.0, y: 7.0))
            context.closePath()
            context.fillPath()
        case "paused":
            context.setFillColor(isColored ? CGColor.white : clear)
            context.fill(CGRect(x: 7.5, y: 5.2, width: 2.2, height: 5.6))
            context.fill(CGRect(x: 11.3, y: 5.2, width: 2.2, height: 5.6))
        case "discharging":
            context.setFillColor(isColored ? CGColor.white : clear)
            context.move(to: CGPoint(x: 10.5, y: 5.0))
            context.addLine(to: CGPoint(x: 10.5, y: 9.3))
            context.addLine(to: CGPoint(x: 8.5, y: 9.3))
            context.addLine(to: CGPoint(x: 11.6, y: 11.4))
            context.addLine(to: CGPoint(x: 14.7, y: 9.3))
            context.addLine(to: CGPoint(x: 12.7, y: 9.3))
            context.addLine(to: CGPoint(x: 12.7, y: 5.0))
            context.closePath()
            context.fillPath()
        case "unplugged":
            context.setFillColor(isColored ? CGColor.white : clear)
            context.fillEllipse(in: CGRect(x: 8.2, y: 6.0, width: 5.6, height: 5.6))
        case "limited":
            context.setFillColor(isColored ? CGColor.white : clear)
            roundedRect(context, CGRect(x: 5.0, y: 7.0, width: 9.0, height: 2.0), radius: 1)
            context.fillPath()
        default:
            break
        }
    } else {
        context.setStrokeColor(ink)
        switch state {
        case "charging":
            context.move(to: CGPoint(x: 11.2, y: 4.9))
            context.addLine(to: CGPoint(x: 8.2, y: 8.4))
            context.addLine(to: CGPoint(x: 10.7, y: 8.4))
            context.addLine(to: CGPoint(x: 9.5, y: 11.1))
            context.addLine(to: CGPoint(x: 13.3, y: 7.0))
            context.addLine(to: CGPoint(x: 10.9, y: 7.0))
            context.strokePath()
        case "paused":
            context.move(to: CGPoint(x: 8.0, y: 5.5)); context.addLine(to: CGPoint(x: 8.0, y: 10.5)); context.strokePath()
            context.move(to: CGPoint(x: 12.0, y: 5.5)); context.addLine(to: CGPoint(x: 12.0, y: 10.5)); context.strokePath()
        case "discharging":
            context.move(to: CGPoint(x: 10.5, y: 5.0)); context.addLine(to: CGPoint(x: 10.5, y: 9.6)); context.strokePath()
            context.move(to: CGPoint(x: 8.6, y: 8.0)); context.addLine(to: CGPoint(x: 10.5, y: 10.2)); context.addLine(to: CGPoint(x: 12.4, y: 8.0)); context.strokePath()
        case "unplugged":
            context.strokeEllipse(in: CGRect(x: 8.4, y: 6.2, width: 5.2, height: 5.2))
        case "limited":
            context.move(to: CGPoint(x: 5.0, y: 8.0)); context.addLine(to: CGPoint(x: 14.0, y: 8.0)); context.strokePath()
        default:
            break
        }
    }

    context.setFillColor(ink)
    roundedRect(context, CGRect(x: 19.5, y: 6.0, width: 2.5, height: 4.0), radius: 1.0)
    context.fillPath()
}

func writePNG(state: String, style: String, scale: Int) throws {
    let width = 24 * scale
    let height = 16 * scale
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { throw NSError(domain: "MenubarIcons", code: 1) }

    context.scaleBy(x: CGFloat(scale), y: CGFloat(scale))
    context.translateBy(x: 0, y: 16)
    context.scaleBy(x: 1, y: -1)
    drawGlyph(context, state: state, style: style, color: cgColor(colors[state]!))

    guard let image = context.makeImage() else { throw NSError(domain: "MenubarIcons", code: 2) }
    let imageset = outputDirectory.appendingPathComponent("\(state)-\(style).imageset", isDirectory: true)
    try FileManager.default.createDirectory(at: imageset, withIntermediateDirectories: true)
    let filename = "menubar_\(state)_\(style)\(scale == 2 ? "@2x" : "").png"
    let destinationURL = imageset.appendingPathComponent(filename)
    guard let destination = CGImageDestinationCreateWithURL(destinationURL as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw NSError(domain: "MenubarIcons", code: 3)
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { throw NSError(domain: "MenubarIcons", code: 4) }
}

for state in states {
    for style in styles {
        try writePNG(state: state, style: style, scale: 1)
        try writePNG(state: state, style: style, scale: 2)
        let template = style == "native" || style == "bold"
        let imageset = outputDirectory.appendingPathComponent("\(state)-\(style).imageset")
        let contents = """
        {
          "images" : [
            { "filename" : "menubar_\(state)_\(style).png", "idiom" : "mac", "scale" : "1x", "size" : "24x16" },
            { "filename" : "menubar_\(state)_\(style)@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "24x16" }
          ],
          "info" : { "author" : "ChargeMate", "version" : 1 }\(template ? ",\n  \"properties\" : { \"template-rendering-intent\" : \"template\" }" : "")
        }
        """
        try contents.write(to: imageset.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
    }
}

let rootContents = """
{
  "info" : { "author" : "ChargeMate", "version" : 1 }
}
"""
try rootContents.write(to: outputDirectory.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
print("Generated 15 ChargeMate menu bar icon sets in \(outputDirectory.path)")
SWIFT
