use nuit
use sdl
use glew

import nuit/[GUI, Types, Image, Renderer, FramedWindow, NinePatchDrawable]

import sdl
import glew

import TestRenderer
import TestView

/*** The Wooperton Plaza ***/

main: func(argc: Int, argv: String*) {
    event: SDLEvent
    running := true
    mousePosition: NPoint
    
    // sdl setup
    
    sdlInit(EnumSDLInitFlags initVideo)
    mainSurface := sdlSetVideoMode(800, 600, 32, EnumSDLSurfaceFlags opengl as UInt32 | EnumSDLGlattr doublebuffer as UInt32)
    if (mainSurface == null) {
        Exception new("Unable to set video mode") throw()
    }
    
    // gl setup
    glewInit()
    
    glClearColor(0.4, 0.4, 0.4, 1.0)
    
    glMatrixMode(GL_PROJECTION)
    glLoadIdentity()
    glMatrixMode(GL_MODELVIEW)
    glLoadIdentity()
    
    // gui setup
    
    gui := NGUI new()
    
    rd := TestRenderer new()
    gui setRenderer(rd)
    
    windowImage := NImage new(gui, "window.png", NSize new(256.0, 256.0), 2)
    windowDrawable := NNinePatchDrawable new(windowImage, NSize new(5.0, 24.0), NSize new(5.0, 5.0), 1.0)
    
    wnd := NFramedWindow new(gui, NRect new(25.0, 64.0, 512.0, 256.0)).
        setCaption("Wooperton").
        setDrawable(windowDrawable)
    
    // don't ask me why I haven't ported addWindow yet.
    gui _windows add(wnd)
    
    wnd = NFramedWindow new(gui, NRect new(25.0, 64.0, 512.0, 256.0)).
        setCaption("Razzle Dazzle Rootbeer").
        setDrawable(windowDrawable).
        addSubview(TestView new(gui, NRect new(24.0, 24.0, 128.0, 80.0)))
    gui _windows add(wnd)
    
    while (running) {
        
        /* using sdlWaitEvent will reduce the amount of CPU you're using and
        more or less block the loop for most things.  Can be handy. */
//        if (sdlWaitEvent(event&)) {
        while (sdlPollEvent(event&)) {
            match (event as UnionSDLEvent type) {
                case EnumSDLEventType quit => running = false
                
                case EnumSDLEventType mousebuttonup =>
                    // mousePosition set(event button x, event button y)
                    mousePosition x = event as UnionSDLEvent button as StructSDLMouseButtonEvent x
                    mousePosition y = event as UnionSDLEvent button as StructSDLMouseButtonEvent y
                    button := event as UnionSDLEvent button as StructSDLMouseButtonEvent button as Int
                    gui pushMouseReleasedEvent(button, mousePosition)
                    
                case EnumSDLEventType mousebuttondown =>
                    // mousePosition set(event button x, event button y)
                    mousePosition x = event as UnionSDLEvent button as StructSDLMouseButtonEvent x
                    mousePosition y = event as UnionSDLEvent button as StructSDLMouseButtonEvent y
                    button := event as UnionSDLEvent button as StructSDLMouseButtonEvent button as Int
                    gui pushMousePressedEvent(button, mousePosition)
                    
                case EnumSDLEventType mousemotion =>
                    // mousePosition set(event motion x, event motion y)
                    mousePosition x = event as UnionSDLEvent motion as StructSDLMouseMotionEvent x
                    mousePosition y = event as UnionSDLEvent motion as StructSDLMouseMotionEvent y
                    gui pushMouseMoveEvent(mousePosition)
                
                case =>
                    continue
            }
//        } else {
//            Exception new(null, "Error in sdlWaitEvent") throw()
        }
        
        glClear(GL_COLOR_BUFFER_BIT)
        
        gui draw()
        
        sdlGlSwapBuffers()
    }
    
    sdlQuit()
}
