#!/usr/bin/env swift
// 千手 App 图标生成器 —— 设计源文件（可复用）
//
// 概念「千手 · 指尖点击」:暖纸 squircle 底 + 陶土橙触点(涟漪扩散)
// + 一只手指从顶部按下(纸色+墨描边) + 底部三颗小触点(千手分身)。
// 亮/暗两套,同构换色。输出 1024×1024 PNG。
//
// 用法:swift Scripts/make_icon.swift [light|dark|all]
// 依赖:macOS 自带 AppKit/CoreGraphics,零第三方。
//
// 集成管线:
//   1. 生成 1024 主图 → 复制到 Qianshou/Support/Assets.xcassets/AppIcon.appiconset/
//      (icon-1024-light.png / icon-1024-dark.png,Contents.json 已声明 dark 变体)
//   2. xcodegen generate → xcodebuild(asset catalog 编译进 Assets.car)
//   注意:.icns 格式不支持深色变体,必须走 asset catalog(appearances: luminosity dark)。

import AppKit
import CoreGraphics

// MARK: - 色值(与 DesignTokens.swift 对齐)

func hex(_ v: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((v >> 16) & 0xFF) / 255,
            green: CGFloat((v >> 8) & 0xFF) / 255,
            blue: CGFloat(v & 0xFF) / 255,
            alpha: a)
}

struct Palette {
    // 背景
    let bgTop: CGColor          // 纸渐变顶
    let bgBottom: CGColor       // 纸渐变底
    let bgEdge: CGColor         // 背景外描边
    // 触点按钮
    let btnTop: CGColor         // 橙渐变顶
    let btnBottom: CGColor      // 橙渐变底
    let btnCore: CGColor        // 中心点(深橙)
    let ripple: CGColor         // 涟漪(纸色半透明)
    let btnShadow: CGColor      // 按钮投影
    // 手指
    let fingerFill: CGColor
    let fingerEdge: CGColor
    let knuckle: CGColor        // 指节线
    // 小触点
    let miniFill: CGColor
    let miniEdge: CGColor
}

let light = Palette(
    bgTop: hex(0xFDFCF9), bgBottom: hex(0xF0EDE4), bgEdge: hex(0xE2DCD0, 0.65),
    btnTop: hex(0xE0815F), btnBottom: hex(0xC96A4B), btnCore: hex(0xA64B2A),
    ripple: hex(0xFDFCF9, 0.62), btnShadow: hex(0x9A5A3E, 0.32),
    fingerFill: hex(0xFDFCF9), fingerEdge: hex(0x23211E),
    knuckle: hex(0x23211E, 0.34),
    miniFill: hex(0xD97757, 0.92), miniEdge: hex(0xFDFCF9, 0.9)
)

let dark = Palette(
    bgTop: hex(0x2C2924), bgBottom: hex(0x1B1916), bgEdge: hex(0x47423A, 0.8),
    btnTop: hex(0xE58B68), btnBottom: hex(0xD2704E), btnCore: hex(0x8F3E24),
    ripple: hex(0xFDFCF9, 0.66), btnShadow: hex(0x0E0C0A, 0.55),
    fingerFill: hex(0xF6F3EC), fingerEdge: hex(0x131110),
    knuckle: hex(0x131110, 0.4),
    miniFill: hex(0xE58B68), miniEdge: hex(0xF6F3EC, 0.85)
)

// MARK: - 绘制

let S: CGFloat = 1024
let R: CGFloat = 228          // squircle 近似圆角(Big Sur 约 22.3%)
let btnC = CGPoint(x: 512, y: 520)   // 触点圆心
let btnR: CGFloat = 215
let fingerW: CGFloat = 190           // 手指宽度
let fingerTip = CGPoint(x: 512, y: 400)  // 指尖圆头圆心
let knuckleY: CGFloat = 336          // 指节线位置

func drawIcon(_ p: Palette) -> CGImage {
    let cs = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(data: nil, width: Int(S), height: Int(S),
                        bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    // 翻转坐标:之后用「y 向下」的直觉坐标
    ctx.translateBy(x: 0, y: S)
    ctx.scaleBy(x: 1, y: -1)

    // 1. 背景 squircle + 内描边
    let bg = CGPath(roundedRect: CGRect(x: 0, y: 0, width: S, height: S),
                    cornerWidth: R, cornerHeight: R, transform: nil)
    ctx.addPath(bg)
    ctx.clip()
    let grad = CGGradient(colorsSpace: cs,
                          colors: [p.bgTop, p.bgBottom] as CFArray,
                          locations: [0, 1])!
    ctx.drawLinearGradient(grad, start: CGPoint(x: 512, y: 0), end: CGPoint(x: 512, y: S), options: [])
    ctx.setStrokeColor(p.bgEdge)
    ctx.setLineWidth(3)
    ctx.addPath(bg)
    ctx.strokePath()

    // 2. 小触点(千手分身)—— 先画,让按钮投影自然压过下方
    let minis: [(CGPoint, CGFloat)] = [(CGPoint(x: 252, y: 790), 30), (CGPoint(x: 772, y: 790), 30), (CGPoint(x: 512, y: 884), 28)]
    for (c, r) in minis {
        ctx.setFillColor(p.miniFill)
        ctx.fillEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
        ctx.setStrokeColor(p.miniEdge)
        ctx.setLineWidth(4)
        ctx.strokeEllipse(in: CGRect(x: c.x - r + 2, y: c.y - r + 2, width: r * 2 - 4, height: r * 2 - 4))
    }

    // 3. 中央触点按钮(投影 + 橙渐变 + 涟漪)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -16), blur: 34, color: p.btnShadow)
    let btn = CGRect(x: btnC.x - btnR, y: btnC.y - btnR, width: btnR * 2, height: btnR * 2)
    let btnGrad = CGGradient(colorsSpace: cs,
                             colors: [p.btnTop, p.btnBottom] as CFArray,
                             locations: [0, 1])!
    ctx.addEllipse(in: btn)
    ctx.clip()
    ctx.drawLinearGradient(btnGrad, start: CGPoint(x: 512, y: btn.minY), end: CGPoint(x: 512, y: btn.maxY), options: [])
    ctx.restoreGState()

    // 涟漪:两道扩散环 + 中心点
    ctx.setStrokeColor(p.ripple)
    ctx.setLineWidth(9)
    ctx.strokeEllipse(in: CGRect(x: 512 - 132, y: 520 - 132, width: 264, height: 264))
    ctx.setLineWidth(6)
    ctx.strokeEllipse(in: CGRect(x: 512 - 198, y: 520 - 198, width: 396, height: 396))
    ctx.setFillColor(p.btnCore)
    ctx.fillEllipse(in: CGRect(x: 512 - 33, y: 520 - 33, width: 66, height: 66))

    // 4. 手指:柱体 + 指尖圆头(顶部伸出画布外,形成「从顶部按下」)
    let f = p.fingerFill, e = p.fingerEdge
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -8), blur: 22, color: hex(0x000000, 0.16))
    let body = CGMutablePath()
    body.addRect(CGRect(x: fingerTip.x - fingerW / 2, y: -80, width: fingerW, height: fingerTip.y + 80))
    body.addEllipse(in: CGRect(x: fingerTip.x - fingerW / 2, y: fingerTip.y - fingerW / 2,
                               width: fingerW, height: fingerW))
    ctx.addPath(body)
    ctx.setFillColor(f)
    ctx.fillPath()
    ctx.restoreGState()

    // 手指描边(整体轮廓:左竖线 → 指尖半圆 → 右竖线)
    let outline = CGMutablePath()
    outline.move(to: CGPoint(x: fingerTip.x - fingerW / 2, y: -80))
    outline.addLine(to: CGPoint(x: fingerTip.x - fingerW / 2, y: fingerTip.y - fingerW / 2))
    outline.addArc(center: fingerTip, radius: fingerW / 2,
                   startAngle: .pi, endAngle: .pi * 2, clockwise: false)
    outline.addLine(to: CGPoint(x: fingerTip.x + fingerW / 2, y: -80))
    ctx.setStrokeColor(e)
    ctx.setLineWidth(3.5)
    ctx.setLineJoin(.round)
    ctx.addPath(outline)
    ctx.strokePath()

    // 指节弧线(俯视透视,微向下弯)
    let kn = CGMutablePath()
    kn.move(to: CGPoint(x: fingerTip.x - fingerW / 2 + 8, y: knuckleY))
    kn.addQuadCurve(to: CGPoint(x: fingerTip.x + fingerW / 2 - 8, y: knuckleY),
                    control: CGPoint(x: fingerTip.x, y: knuckleY + 16))
    ctx.setStrokeColor(p.knuckle)
    ctx.setLineWidth(3)
    ctx.addPath(kn)
    ctx.strokePath()

    return ctx.makeImage()!
}

// MARK: - 输出

func writePNG(_ img: CGImage, to path: String) throws {
    let rep = NSBitmapImageRep(cgImage: img)
    guard let data = rep.representation(using: .png, properties: [:]) else { return }
    try data.write(to: URL(fileURLWithPath: path))
}

let mode = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "all"
let outDir = "build/icon"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

func render(_ palette: Palette, _ name: String) throws {
    let img = drawIcon(palette)
    try writePNG(img, to: "\(outDir)/\(name)-1024.png")
    print("✓ \(name)-1024.png")
}

if mode == "light" || mode == "all" { try render(light, "light") }
if mode == "dark" || mode == "all" { try render(dark, "dark") }
