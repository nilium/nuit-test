use nuit
use sdl
use glew

import structs/LinkedList
import os/Time
import GUI, Types, Image, Font, Renderer, FramedWindow, Drawable,
       NinePatchDrawable, PaddedDrawable, ImageDrawable, MultiDrawable, View,
       Button, Skin, Checkbox, ScrollBar, ScrollView, Window, Radiobox

import sdl
import glew

import TestRenderer
import TestView

gluPerspective: extern func (fovy, aspect, znear, zfar: Double)
gluLookAt: extern func (eyeX, eyeY, eyeZ, centerX, centerY, centerZ, upX, upY, upZ: Double)

initGLState: func (w, h: Int) {
    glClearColor(0.4, 0.4, 0.4, 1.0)
    
    glMatrixMode(GL_PROJECTION)
    glLoadIdentity()
    
    gluPerspective(80.0, w as Float / h, 1.0, 60.0)
    //glOrtho(-w * 0.01, w * 0.01, -h * 0.01, h * 0.01, -10.0, 10.0)
    
    glMatrixMode(GL_MODELVIEW)
    glLoadIdentity()
    glTranslatef(0, 0, -8)
    //gluLookAt(0.0, 0.0, -30.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0)
    
    glAlphaFunc(GL_ALWAYS, 1.0)
    glDepthFunc(GL_ALWAYS)
    
    glViewport(0, 0, w, h)
}

/*** The Wooperton Plaza ***/

main: func(argc: Int, argv: String*) {
    event: SDLEvent
    running := true
    mousePosition: NPoint
    
    // sdl setup
    
    sdlInit(SDLInitFlags video)
    mainSurface := sdlSetVideoMode(800, 600, 32, SDLVideoFlags opengl | SDLVideoFlags doubleBuffer | SDLVideoFlags resizable)
    if (mainSurface == null) {
        Exception new("Unable to set video mode") throw()
    }
    
    // gl setup
    glewInit()
    initGLState(800, 600)
    
    // gui setup
    
    gui := NGUI new()
    
    rd := TestRenderer new()
    gui setRenderer(rd)
    
    windowImage := NImage new(gui, "window.png", NSize new(256.0, 256.0), 2)
    windowDrawable := NNinePatchDrawable new(windowImage, NSize new(5.0, 24.0), NSize new(5.0, 5.0), 1.0)
    cbDrawable := NImageDrawable new(NImage new(gui, "checkbox.png", NSize new(16.0, 16.0), 5))
    rbDrawable := NImageDrawable new(NImage new(gui, "radiobox.png", NSize new(64.0, 64.0), 5))
    btnDrawable := NNinePatchDrawable new(NImage new(gui, "button.png", NSize new(64.0, 64.0), 4), NSize new(10.0), NSize new(10.0), 1.0)
    vscrollDrawable := NNinePatchDrawable new(NImage new(gui, "vscroll.png", NSize new(100.0, 200.0), 2), NSize new(15.0), NSize new(15.0), 0.2)
    hscrollDrawable := NNinePatchDrawable new(NImage new(gui, "hscroll.png", NSize new(200.0, 100.0), 2), NSize new(15.0), NSize new(15.0), 0.2)
    vscPadDrawable := NImageDrawable new(NImage new(gui, "scrolldragger.png"), NImageScaling fillAspect, NImageAlignment center)
    vscDragDrawable := NNinePatchDrawable new(NImage new(gui, "vdragger.png", NSize new(100.0, 200.0), 2), NSize new(15.0), NSize new(15.0), 0.2)
    lst := LinkedList<NDrawable> new(). add(vscDragDrawable). add(vscPadDrawable)
    vscDrawable := NMultiDrawable new(lst)
    
    hscPadDrawable := NImageDrawable new(NImage new(gui, "hscrolldragger.png"), NImageScaling fillAspect, NImageAlignment center)
    hscDragDrawable := NNinePatchDrawable new(NImage new(gui, "hdragger.png", NSize new(200.0, 100.0), 2), NSize new(15.0), NSize new(15.0), 0.2)
    lst = LinkedList<NDrawable> new(). add(hscDragDrawable). add(hscPadDrawable)
    hscDrawable := NMultiDrawable new(lst)
    
    skin := NBasicSkin new().
        addDrawable("Shadow", NNinePatchDrawable new(NImage new(gui, "shadow.png"), NSize new(14.0, 14.0), NSize new(14.0, 14.0), 1.0)).
        addDrawable("FramedWindow", windowDrawable).
        addDrawable("VerticalScrollBar", vscrollDrawable).
        addDrawable("HorizontalScrollBar", hscrollDrawable).
        addDrawable("Radiobox", rbDrawable).
        addDrawable("Checkbox", cbDrawable).
        addDrawable("Button", btnDrawable).
        addFont("DefaultFont", NFont new(gui, "HelveticaNeue.ttc", 12, false, false)).
        addSize("FramedWindowResizer", NSize new(20.0)).
        addDrawable("VerticalScrollBarScrubber", vscDrawable).
        addDrawable("HorizontalScrollBarScrubber", hscDrawable)
    
    gui setSkin(skin)
    
    scr := NScrollView new(gui, NRect new(168.0, 24.0, 180.0, 180.0))
    scr retainCorner = false
    scr setContentView(NView new(gui, NSize new(512.0, 512.0) toRect()))
    scr contentView() addSubview(NRadiobox new(gui, NRect new(24.0, 24.0, 64.0, 16.0)).
                                  setCaption("Radio 1")
                                ). // addSubview
                      addSubview(NRadiobox new(gui, NRect new(96.0, 24.0, 64.0, 16.0)).
                                  setCaption("Radio 2")
                                ). // addSubview
                      addSubview(NRadiobox new(gui, NRect new(168.0, 24.0, 64.0, 16.0)).
                                  setCaption("Radio 3")
                                ). // addSubview
                      addSubview(NCheckbox new(gui, NRect new(24.0, 48.0, 64.0, 16.0)).
                                  setCaption("Check 1")
                                ).
                      addSubview(NCheckbox new(gui, NRect new(96.0, 48.0, 64.0, 16.0)).
                                  setCaption("Check 2")
                                ).
                      addSubview(NCheckbox new(gui, NRect new(168.0, 48.0, 64.0, 16.0)).
                                  setCaption("Check 3")
                                ).
                      addSubview(NButton new(gui, NRect new(24.0, 72.0, 128.0, 30.0)).
                                  setCaption("A button"))
    
    fwnd := NFramedWindow new(gui, NRect new(60.0, 30.0, 512.0, 256.0))
    fwnd as NFramedWindow setCaption("Razzle Dazzle Rootbeer").
           setContentView(scr)
    gui addWindow(fwnd)
    
    pointsArr := [
    //  x  y  z
        3, 3, 3,
        3, 3, -3,
        -3, 3, -3,
        -3, 3, 3,
        3, -3, 3,
        3, -3, -3,
        -3, -3, -3,
        -3, -3, 3
    ]
    points := pointsArr data as Int*
    
    while (running) {
        
        /* using sdlWaitEvent will reduce the amount of CPU you're using and
        more or less block the loop for most things.  Can be handy. */
//        if (sdlWaitEvent(event&)) {
        while (sdlPollEvent(event&)) {
            match (event as UnionSDLEvent type) {
                case SDLEventType quit => running = false
                
                case SDLEventType mousebuttonup =>
                    // mousePosition set(event button x, event button y)
                    mousePosition x = event as UnionSDLEvent button as StructSDLMouseButtonEvent x
                    mousePosition y = event as UnionSDLEvent button as StructSDLMouseButtonEvent y
                    button := event as UnionSDLEvent button as StructSDLMouseButtonEvent button as Int
                    gui pushMouseReleasedEvent(button, mousePosition)
                    
                case SDLEventType mousebuttondown =>
                    // mousePosition set(event button x, event button y)
                    mousePosition x = event as UnionSDLEvent button as StructSDLMouseButtonEvent x
                    mousePosition y = event as UnionSDLEvent button as StructSDLMouseButtonEvent y
                    button := event as UnionSDLEvent button as StructSDLMouseButtonEvent button as Int
                    gui pushMousePressedEvent(button, mousePosition)
                    
                case SDLEventType mousemotion =>
                    // mousePosition set(event motion x, event motion y)
                    mousePosition x = event as UnionSDLEvent motion as StructSDLMouseMotionEvent x
                    mousePosition y = event as UnionSDLEvent motion as StructSDLMouseMotionEvent y
                    gui pushMouseMoveEvent(mousePosition)
                
                case SDLEventType videoresize =>
                    w := event as UnionSDLEvent resize as StructSDLResizeEvent w
                    h := event as UnionSDLEvent resize as StructSDLResizeEvent h
                    
                    rd dispose()
                    mainSurface = sdlSetVideoMode(w, h, 32, SDLVideoFlags opengl | SDLVideoFlags doubleBuffer | SDLVideoFlags resizable)
                    rd = TestRenderer new()
                    gui setRenderer(rd)
                    initGLState(w, h)
                    
                case =>
                    continue
            }
//        } else {
//            Exception new(null, "Error in sdlWaitEvent") throw()
        }
        
//        "millisec: %D  microsec: %d  microtime: %D" format(Time millisec(), Time microsec(), Time microtime()) println()
        
        glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT)
        
        // cube thingy begin
        glRotatef(0.01, 0.1, 0.2, 0.3)
        glLineWidth(2.0)
        
        glBegin(GL_LINE_STRIP)
            glColor3f(1.0, 1.0, 1.0)
            for (i: Int in 0..4) glVertex3iv(points+(i*3))
            glVertex3iv(points)
            for (i: Int in 0..4) glVertex3iv(points+12+(i*3))
            glVertex3iv(points+12)
        glEnd()
        
        glBegin(GL_LINES)
            for (i: Int in 1..4) {
                glVertex3iv(points+3*i)
                glVertex3iv(points+12+3*i)
            }
        glEnd()
        // cube thingy end
        
        gui draw()
        
        sdlGLSwapBuffers()
    }
    
    sdlQuit()
}
