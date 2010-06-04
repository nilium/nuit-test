import nuit/[Types, Renderer, View]

TestView: class extends NView {
    init: func (frame: NRect) {
        super(frame)
    }
    
    draw: func (renderer: NRenderer) {
        renderer fillRect(bounds())
    }
}
