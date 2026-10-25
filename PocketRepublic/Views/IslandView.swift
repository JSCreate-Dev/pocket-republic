import SwiftUI

struct IslandView: View {
    let tiles: [(Int, Int, String)] = [(0,0,"🏛️"), (1,0,"🏠"), (2,0,"🌴"), (3,0,"🏠"), (0,1,"🌾"), (1,1,"🏪"), (2,1,"🏠"), (3,1,"🌴"), (0,2,"🌴"), (1,2,"🏥"), (2,2,"🌾"), (3,2,"⚓")]
    var body: some View { GeometryReader { geo in ZStack {
        LinearGradient(colors: [.cyan.opacity(0.6), .blue.opacity(0.65)], startPoint: .top, endPoint: .bottom)
        ForEach(0..<4, id: \.self) { x in ForEach(0..<3, id: \.self) { y in
            let cx = geo.size.width/2 + CGFloat(x-y)*43 - 22
            let cy = CGFloat(42 + (x+y)*25)
            let diamond = Path { p in p.move(to: CGPoint(x:cx,y:cy)); p.addLine(to: CGPoint(x:cx+43,y:cy+24)); p.addLine(to: CGPoint(x:cx,y:cy+48)); p.addLine(to: CGPoint(x:cx-43,y:cy+24)); p.closeSubpath() }
            diamond.fill(Color(red: 0.26 + Double((x+y)%2)*0.05, green: 0.62, blue: 0.35))
            diamond.stroke(.green.opacity(0.6), lineWidth: 1)
        } }
        ForEach(tiles.indices, id: \.self) { i in let t = tiles[i]; Text(t.2).font(.system(size: 27)).position(x:geo.size.width/2 + CGFloat(t.0-t.1)*43-22, y: CGFloat(38+(t.0+t.1)*25)) }
    } }.accessibilityLabel("Stylized isometric island with farms, homes, clinic, town hall and docks") }
}
