import Foundation

/// One camera shared by the live faces and the rounded sidewall mesh.
struct RadioCaseGeometry {
    let angle: Double
    let classic: Bool
    let width = 350.0
    let height = 392.0
    let camera = 900.0
    var depth: Double { classic ? 28 : 6 }
    var sine: Double { sin(angle * .pi / 180) }
    var cosine: Double { cos(angle * .pi / 180) }

    // Recede slightly while turning so perspective never clips the fixed panel.
    var fit: Double {
        let nearest = abs(sine) * width / 2 + abs(cosine) * depth / 2 - depth / 2
        let horizontal = abs(cosine) * width / 2 + abs(sine) * depth / 2
        return (camera - max(0, nearest)) / camera * min(1, (width / 2) / max(1, horizontal))
    }

    func project(x: Double, y: Double, z: Double) -> CGPoint {
        let rotatedX = cosine * x + sine * z
        let rotatedZ = -sine * x + cosine * z - depth / 2
        let scale = fit * camera / (camera - rotatedZ)
        return CGPoint(x: width / 2 + rotatedX * scale, y: height / 2 + y * scale)
    }

    struct FaceProjection {
        let a: Double, c: Double, d: Double, e: Double, f: Double, g: Double, i: Double
        func point(_ p: CGPoint) -> CGPoint {
            let denominator = g * p.x + i
            return CGPoint(x: (a * p.x + c) / denominator, y: (d * p.x + e * p.y + f) / denominator)
        }
    }

    func faceProjection(back: Bool) -> FaceProjection {
        let sign = back ? -1.0 : 1.0
        let z = sign * depth / 2
        let qx = sign * sine / camera
        let q0 = 1 - (z * cosine - depth / 2) / camera
        let a = width / 2 * qx + fit * sign * cosine
        let d = height / 2 * qx
        return FaceProjection(a: a, c: width / 2 * q0 + fit * z * sine - a * width / 2,
                              d: d, e: fit, f: height / 2 * q0 - fit * height / 2 - d * width / 2,
                              g: qx, i: q0 - qx * width / 2)
    }

    // Perspective makes the camera see neither face exactly edge-on: the faces
    // sit on opposite sides of the axis rather than passing through its center.
    func faceVisible(back: Bool) -> Bool {
        let sign = back ? -1.0 : 1.0
        return sign * cosine * (camera + depth / 2) > depth / 2 + 0.0001
    }

    func facePoint(_ point: CGPoint, back: Bool) -> CGPoint { faceProjection(back: back).point(point) }
}
