import Types, Renderer, View

TestView: class extends NView {
    init: super func
    
    draw: func (renderer: NRenderer) {
        renderer fillRect(bounds())
    }
}
