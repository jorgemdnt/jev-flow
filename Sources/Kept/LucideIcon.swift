import SwiftUI

enum LucideIcon: String {
    case clock
    case book
    case settings
    case option
    case alert
    case pencil

    fileprivate var drawings: [String] {
        switch self {
        case .clock:
            ["M12 6v6l4 2", "M12 2a10 10 0 1 0 0.01 0"]
        case .book:
            [
                "M4 19.5v-15A2.5 2.5 0 0 1 6.5 2H19a1 1 0 0 1 1 1v18a1 1 0 0 1-1 1H6.5a1 1 0 0 1 0-5H20",
                "m8 13 4-7 4 7",
                "M9.1 11h5.7",
            ]
        case .settings:
            [
                "M9.671 4.136a2.34 2.34 0 0 1 4.659 0 2.34 2.34 0 0 0 3.319 1.915 2.34 2.34 0 0 1 2.33 4.033 2.34 2.34 0 0 0 0 3.831 2.34 2.34 0 0 1-2.33 4.033 2.34 2.34 0 0 0-3.319 1.915 2.34 2.34 0 0 1-4.659 0 2.34 2.34 0 0 0-3.32-1.915 2.34 2.34 0 0 1-2.33-4.033 2.34 2.34 0 0 0 0-3.831A2.34 2.34 0 0 1 6.35 6.051a2.34 2.34 0 0 0 3.319-1.915",
                "M12 9a3 3 0 1 0 0.01 0",
            ]
        case .option:
            ["M3 3h6l6 18h6", "M14 3h7"]
        case .alert:
            [
                "M10.29 3.86 1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z",
                "M12 9v4",
                "M12 17h.01",
            ]
        case .pencil:
            [
                "M21.174 6.812a1 1 0 0 0-3.986-3.987L3.842 16.174a2 2 0 0 0-.5.83l-1.321 4.352a.5.5 0 0 0 .623.622l4.353-1.32a2 2 0 0 0 .83-.497z",
                "m15 5 4 4",
            ]
        }
    }
}

struct LucideMark: View {
    let icon: LucideIcon
    var size: CGFloat = 16
    var color: Color = .primary

    var body: some View {
        Canvas { context, canvas in
            let scale = canvas.width / 24
            var path = Path()
            for drawing in icon.drawings {
                path.addPath(SVGPath(drawing).path)
            }
            let scaled = path.applying(CGAffineTransform(scaleX: scale, y: scale))
            context.stroke(
                scaled,
                with: .color(color),
                style: StrokeStyle(lineWidth: max(1.25, 2 * scale), lineCap: .round, lineJoin: .round)
            )
        }
        .frame(width: size, height: size)
        .accessibilityLabel(icon.rawValue)
    }
}

/// Lucide path data, including arcs. ISC, lucide-static 0.544.0.
struct SVGPath {
    let path: Path

    init(_ data: String) {
        var path = Path()
        var index = data.startIndex
        var command: Character = "M"
        var current = CGPoint.zero
        var start = CGPoint.zero
        var cubicControl = CGPoint.zero
        var quadraticControl = CGPoint.zero

        func readNumber() -> CGFloat? {
            while index < data.endIndex, data[index].isWhitespace || data[index] == "," {
                index = data.index(after: index)
            }
            guard index < data.endIndex else { return nil }
            let head = data[index]
            guard head == "-" || head == "+" || head == "." || head.isNumber else { return nil }
            let begin = index
            if head == "-" || head == "+" { index = data.index(after: index) }
            var sawDot = false
            var sawExp = false
            while index < data.endIndex {
                let character = data[index]
                if character.isNumber {
                    index = data.index(after: index)
                } else if character == ".", !sawDot, !sawExp {
                    sawDot = true
                    index = data.index(after: index)
                } else if character == "e" || character == "E", !sawExp {
                    sawExp = true
                    index = data.index(after: index)
                    if index < data.endIndex, data[index] == "-" || data[index] == "+" {
                        index = data.index(after: index)
                    }
                } else {
                    break
                }
            }
            return CGFloat(Double(data[begin..<index]) ?? 0)
        }

        func point(_ relative: Bool, _ x: CGFloat, _ y: CGFloat) -> CGPoint {
            relative ? CGPoint(x: current.x + x, y: current.y + y) : CGPoint(x: x, y: y)
        }

        while index < data.endIndex {
            let character = data[index]
            if character.isLetter {
                command = character
                index = data.index(after: index)
            }
            let relative = command.isLowercase
            switch command.lowercased().first {
            case "m":
                guard let x = readNumber(), let y = readNumber() else { index = data.endIndex; break }
                current = point(relative, x, y)
                start = current
                path.move(to: current)
                command = relative ? "l" : "L"
            case "l":
                guard let x = readNumber(), let y = readNumber() else { break }
                current = point(relative, x, y)
                path.addLine(to: current)
            case "h":
                guard let x = readNumber() else { break }
                current = CGPoint(x: relative ? current.x + x : x, y: current.y)
                path.addLine(to: current)
            case "v":
                guard let y = readNumber() else { break }
                current = CGPoint(x: current.x, y: relative ? current.y + y : y)
                path.addLine(to: current)
            case "c":
                guard let x1 = readNumber(), let y1 = readNumber(),
                      let x2 = readNumber(), let y2 = readNumber(),
                      let x = readNumber(), let y = readNumber() else { break }
                let control1 = point(relative, x1, y1)
                cubicControl = point(relative, x2, y2)
                current = point(relative, x, y)
                path.addCurve(to: current, control1: control1, control2: cubicControl)
            case "s":
                guard let x2 = readNumber(), let y2 = readNumber(),
                      let x = readNumber(), let y = readNumber() else { break }
                let reflected = CGPoint(x: 2 * current.x - cubicControl.x, y: 2 * current.y - cubicControl.y)
                cubicControl = point(relative, x2, y2)
                current = point(relative, x, y)
                path.addCurve(to: current, control1: reflected, control2: cubicControl)
            case "q":
                guard let x1 = readNumber(), let y1 = readNumber(),
                      let x = readNumber(), let y = readNumber() else { break }
                quadraticControl = point(relative, x1, y1)
                current = point(relative, x, y)
                path.addQuadCurve(to: current, control: quadraticControl)
            case "a":
                guard let rx = readNumber(), let ry = readNumber(),
                      let rotation = readNumber(),
                      let large = readNumber(),
                      let sweep = readNumber(),
                      let x = readNumber(),
                      let y = readNumber() else { break }
                let end = point(relative, x, y)
                path.addPath(Self.arc(from: current, to: end, rx: rx, ry: ry, rotation: rotation, large: large != 0, sweep: sweep != 0))
                current = end
                cubicControl = current
            case "z":
                path.closeSubpath()
                current = start
            default:
                index = data.endIndex
            }
            cubicControl = command.lowercased().first == "c" || command.lowercased().first == "s" ? cubicControl : current
        }
        self.path = path
    }

    private static func arc(from start: CGPoint, to end: CGPoint, rx: CGFloat, ry: CGFloat, rotation: CGFloat, large: Bool, sweep: Bool) -> Path {
        var path = Path()
        path.move(to: start)
        guard rx > 0, ry > 0, start != end else {
            path.addLine(to: end)
            return path
        }
        let phi = rotation * .pi / 180
        let cosPhi = cos(phi)
        let sinPhi = sin(phi)
        let dx = (start.x - end.x) / 2
        let dy = (start.y - end.y) / 2
        let x1 = cosPhi * dx + sinPhi * dy
        let y1 = -sinPhi * dx + cosPhi * dy
        var rx = abs(rx)
        var ry = abs(ry)
        let lambda = (x1 * x1) / (rx * rx) + (y1 * y1) / (ry * ry)
        if lambda > 1 {
            let scale = sqrt(lambda)
            rx *= scale
            ry *= scale
        }
        let sign: CGFloat = (large == sweep) ? -1 : 1
        let numerator = max(0, rx * rx * ry * ry - rx * rx * y1 * y1 - ry * ry * x1 * x1)
        let denominator = rx * rx * y1 * y1 + ry * ry * x1 * x1
        let coef = sign * sqrt(numerator / max(denominator, 0.000_001))
        let cx1 = coef * rx * y1 / ry
        let cy1 = coef * -ry * x1 / rx
        let cx = cosPhi * cx1 - sinPhi * cy1 + (start.x + end.x) / 2
        let cy = sinPhi * cx1 + cosPhi * cy1 + (start.y + end.y) / 2
        func angle(_ ux: CGFloat, _ uy: CGFloat, _ vx: CGFloat, _ vy: CGFloat) -> CGFloat {
            let dot = ux * vx + uy * vy
            let length = sqrt(ux * ux + uy * uy) * sqrt(vx * vx + vy * vy)
            var angle = acos(min(1, max(-1, dot / max(length, 0.000_001))))
            if ux * vy - uy * vx < 0 { angle = -angle }
            return angle
        }
        let theta1 = angle(1, 0, (x1 - cx1) / rx, (y1 - cy1) / ry)
        var delta = angle((x1 - cx1) / rx, (y1 - cy1) / ry, (-x1 - cx1) / rx, (-y1 - cy1) / ry)
        if !sweep, delta > 0 { delta -= 2 * .pi }
        if sweep, delta < 0 { delta += 2 * .pi }
        let steps = max(8, Int(abs(delta) / (.pi / 8)))
        for step in 1...steps {
            let t = theta1 + delta * CGFloat(step) / CGFloat(steps)
            let x = cx + rx * cos(t) * cosPhi - ry * sin(t) * sinPhi
            let y = cy + rx * cos(t) * sinPhi + ry * sin(t) * cosPhi
            path.addLine(to: CGPoint(x: x, y: y))
        }
        return path
    }
}
