import Foundation
@main struct InteractionTests {
    static func main() {
        precondition(AntennaPull.opensRadio(CGSize(width: 4, height: -34)), "Pulling up to the detent must open the radio")
        precondition(!AntennaPull.opensRadio(CGSize(width: 0, height: -20)), "A partial pull must spring back")
        precondition(!AntennaPull.opensRadio(CGSize(width: 0, height: 60)), "Dragging down must not open")
        precondition(!AntennaPull.opensRadio(CGSize(width: 80, height: -40)), "A mostly horizontal drag must not count as a pull")
        precondition(!AntennaPull.opensRadio(CGSize(width: 0, height: 0)))
        print("PASS antenna pull detent, partial, downward, sideways and no-movement cases")

        precondition(RadioTurn.rotation(for: CGSize(width: -90, height: 5)) == -90)
        precondition(RadioTurn.rotation(for: CGSize(width: 90, height: -5)) == 90)
        precondition(RadioTurn.rotation(for: CGSize(width: 25, height: 100)) == 0)
        precondition(RadioTurn.rotation(for: CGSize(width: 400, height: 0)) == 180)
        print("PASS radio turn follows horizontal movement in both directions, ignores vertical drags and clamps")
        precondition(!RadioTurn.commits(CGSize(width: 79, height: 0)))
        precondition(RadioTurn.commits(CGSize(width: 80, height: 10)))
        precondition(RadioTurn.commits(CGSize(width: -80, height: 10)))
        precondition(!RadioTurn.commits(CGSize(width: 90, height: 120)))
        print("PASS short radio turns spring back; deliberate horizontal turns commit")
        precondition(RadioTurn.destination(from: 0, translation: CGSize(width: -100, height: 0), allowed: true) == -180)
        precondition(RadioTurn.destination(from: 180, translation: CGSize(width: 100, height: 0), allowed: true) == 360)
        precondition(RadioTurn.destination(from: 180, translation: CGSize(width: -100, height: 0), allowed: true) == 0)
        precondition(RadioTurn.destination(from: 180, translation: CGSize(width: -100, height: 0), allowed: false) == 180)
        precondition(RadioTurn.destination(from: 0, translation: CGSize(width: 10, height: 0), allowed: true) == 0)
        print("PASS radio turn destinations preserve direction; rejected saves return to the back")
        for angle in [-720.0, -360, 0, 360, 720] { precondition(RadioTurn.frontFacesViewer(angle)) }
        for angle in [-540.0, -180, 180, 540] { precondition(!RadioTurn.frontFacesViewer(angle)) }
        precondition(RadioTurn.frontFacesViewer(89) && !RadioTurn.frontFacesViewer(91))
        precondition(RadioTurn.frontFacesViewer(-89) && !RadioTurn.frontFacesViewer(-91))
        print("PASS front/back visibility at half-turns and in both rotation directions")

        for angle in [0.0, 180, -180, 360] {
            let geometry = RadioCaseGeometry(angle: angle, classic: true)
            let back = !RadioTurn.frontFacesViewer(angle)
            let corner = geometry.facePoint(CGPoint(x: 0, y: 0), back: back)
            precondition(abs(corner.x) < 0.001 && abs(corner.y) < 0.001, "Resting faces must retain the existing size and position")
        }
        for angle in stride(from: -360.0, through: 360.0, by: 3) {
            for classic in [true, false] {
                let geometry = RadioCaseGeometry(angle: angle, classic: classic)
                for x in [-175.0, 175] { for y in [-196.0, 196] { for z in [-geometry.depth / 2, geometry.depth / 2] {
                    let p = geometry.project(x: x, y: y, z: z)
                    precondition(p.x >= -0.001 && p.x <= 350.001 && p.y >= -0.001 && p.y <= 392.001, "A turning case must fit its window")
                } } }
                for back in [false, true] {
                    let sign = back ? -1.0 : 1.0
                    for point in [CGPoint(x: 0, y: 0), CGPoint(x: 350, y: 392), CGPoint(x: 40, y: 100)] {
                        let edge = geometry.project(x: sign * (point.x - 175), y: point.y - 196, z: sign * geometry.depth / 2)
                        let face = geometry.facePoint(point, back: back)
                        precondition(hypot(edge.x - face.x, edge.y - face.y) < 0.001, "Front/back faces must stay joined to the casing at every angle")
                    }
                }
            }
        }
        for angle in [-90.0, 90, 270] {
            let edge = RadioCaseGeometry(angle: angle, classic: true)
            precondition(!edge.faceVisible(back: false) && !edge.faceVisible(back: true), "Edge-on views must not leak mirrored face text")
        }
        precondition(RadioCaseGeometry(angle: 45, classic: true).faceVisible(back: false))
        precondition(RadioCaseGeometry(angle: 135, classic: true).faceVisible(back: true))
        let side = RadioCaseGeometry(angle: 90, classic: true)
        let a = side.project(x: -175, y: 0, z: -side.depth / 2)
        let b = side.project(x: -175, y: 0, z: side.depth / 2)
        precondition(abs(b.x - a.x) >= 24 && abs(b.x - a.x) <= 30, "The halfway view must show a slim, visible sidewall")
        print("PASS radio casing: resting dimensions, full-turn bounds, connected faces and midpoint thickness")
    }
}
