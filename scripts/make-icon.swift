// Génère l'icône de l'application (bouclier, Mac et verrou) en PNG à toutes les tailles d'un .iconset.
// Usage : swift scripts/make-icon.swift <dossier.iconset>
// Le dessin est défini sur une grille de 1024 points, axe Y vers le bas.
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let canvas: CGFloat = 1024

func color(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

func linearGradient(_ context: CGContext, in path: CGPath, colors: [CGColor], from start: CGPoint, to end: CGPoint) {
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors as CFArray, locations: nil)!
    context.saveGState()
    context.addPath(path)
    context.clip()
    context.drawLinearGradient(gradient, start: start, end: end, options: [])
    context.restoreGState()
}

func shieldPath() -> CGPath {
    let path = CGMutablePath()
    path.move(to: CGPoint(x: 512, y: 215))
    path.addCurve(to: CGPoint(x: 765, y: 285), control1: CGPoint(x: 600, y: 265), control2: CGPoint(x: 690, y: 285))
    path.addLine(to: CGPoint(x: 765, y: 500))
    path.addCurve(to: CGPoint(x: 512, y: 835), control1: CGPoint(x: 765, y: 680), control2: CGPoint(x: 650, y: 780))
    path.addCurve(to: CGPoint(x: 259, y: 500), control1: CGPoint(x: 374, y: 780), control2: CGPoint(x: 259, y: 680))
    path.addLine(to: CGPoint(x: 259, y: 285))
    path.addCurve(to: CGPoint(x: 512, y: 215), control1: CGPoint(x: 334, y: 285), control2: CGPoint(x: 424, y: 265))
    path.closeSubpath()
    return path
}

func drawIcon(in context: CGContext) {
    // Fond : carré arrondi de la grille d'icônes macOS (824 points, marge de 100).
    let background = CGPath(
        roundedRect: CGRect(x: 100, y: 100, width: 824, height: 824),
        cornerWidth: 185, cornerHeight: 185, transform: nil
    )
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: 10), blur: 24, color: color(0x000000, alpha: 0.35))
    context.addPath(background)
    context.setFillColor(color(0x1E3A8A))
    context.fillPath()
    context.restoreGState()
    linearGradient(context, in: background, colors: [color(0x3B82F6), color(0x1E3A8A)],
                   from: CGPoint(x: 512, y: 100), to: CGPoint(x: 512, y: 924))

    // Bouclier.
    let shield = shieldPath()
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: 14), blur: 30, color: color(0x0B1530, alpha: 0.45))
    context.addPath(shield)
    context.setFillColor(color(0xE2E8F0))
    context.fillPath()
    context.restoreGState()
    linearGradient(context, in: shield, colors: [color(0xFFFFFF), color(0xCBD5E1)],
                   from: CGPoint(x: 512, y: 215), to: CGPoint(x: 512, y: 835))
    context.addPath(shield)
    context.setStrokeColor(color(0x94A3B8, alpha: 0.6))
    context.setLineWidth(6)
    context.strokePath()

    // Mac : écran, pied et socle.
    let bezel = CGPath(roundedRect: CGRect(x: 352, y: 330, width: 320, height: 215),
                       cornerWidth: 24, cornerHeight: 24, transform: nil)
    context.addPath(bezel)
    context.setFillColor(color(0x1E293B))
    context.fillPath()
    let screen = CGPath(roundedRect: CGRect(x: 366, y: 344, width: 292, height: 187),
                        cornerWidth: 12, cornerHeight: 12, transform: nil)
    linearGradient(context, in: screen, colors: [color(0x1E40AF), color(0x0F172A)],
                   from: CGPoint(x: 512, y: 344), to: CGPoint(x: 512, y: 531))

    let neck = CGMutablePath()
    neck.move(to: CGPoint(x: 487, y: 545))
    neck.addLine(to: CGPoint(x: 537, y: 545))
    neck.addLine(to: CGPoint(x: 550, y: 598))
    neck.addLine(to: CGPoint(x: 474, y: 598))
    neck.closeSubpath()
    context.addPath(neck)
    context.setFillColor(color(0x64748B))
    context.fillPath()
    context.addPath(CGPath(roundedRect: CGRect(x: 432, y: 596, width: 160, height: 20),
                           cornerWidth: 10, cornerHeight: 10, transform: nil))
    context.setFillColor(color(0x475569))
    context.fillPath()

    // Verrou sur l'écran.
    let shackle = CGMutablePath()
    shackle.move(to: CGPoint(x: 484, y: 432))
    shackle.addLine(to: CGPoint(x: 484, y: 413))
    shackle.addArc(center: CGPoint(x: 512, y: 413), radius: 28, startAngle: .pi, endAngle: 0, clockwise: false)
    shackle.addLine(to: CGPoint(x: 540, y: 432))
    context.addPath(shackle)
    context.setStrokeColor(color(0xE2E8F0))
    context.setLineWidth(14)
    context.setLineCap(.round)
    context.strokePath()

    let body = CGPath(roundedRect: CGRect(x: 467, y: 425, width: 90, height: 72),
                      cornerWidth: 14, cornerHeight: 14, transform: nil)
    linearGradient(context, in: body, colors: [color(0x4ADE80), color(0x16A34A)],
                   from: CGPoint(x: 512, y: 425), to: CGPoint(x: 512, y: 497))
    context.addEllipse(in: CGRect(x: 503, y: 448, width: 18, height: 18))
    context.addRect(CGRect(x: 508, y: 460, width: 8, height: 20))
    context.setFillColor(color(0x14532D))
    context.fillPath()
}

func renderPNG(pixels: Int, to url: URL) throws {
    let context = CGContext(
        data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    let scale = CGFloat(pixels) / canvas
    context.translateBy(x: 0, y: CGFloat(pixels))
    context.scaleBy(x: scale, y: -scale)
    drawIcon(in: context)

    let image = context.makeImage()!
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw CocoaError(.fileWriteUnknown)
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
}

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("Usage : swift scripts/make-icon.swift <dossier.iconset>\n".utf8))
    exit(1)
}
let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    try renderPNG(pixels: points, to: output.appendingPathComponent("icon_\(points)x\(points).png"))
    try renderPNG(pixels: points * 2, to: output.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
}
