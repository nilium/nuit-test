use nuit
use sdl
use sdl_image
use glew

import structs/[Stack, HashMap]
import nuit/[GUI, View, Types, Image, Renderer, FramedWindow, Drawable, NinePatchDrawable, TiledImageDrawable, PaddedDrawable, MultiDrawable]

import sdl
import sdl_image

import glew

import os/Time


/** IMAGE DATA **/
TestImageData: class extends NImageData {
    _name: UInt
    _size: NSize
    
    size: func -> NSize {_size}
}


/*** TEST RENDERER ***/
TestRenderState: cover {
    color: NColor
    drawing_region: NRect
    origin: NPoint
    clipped := false
    
    apply: func (rend: NRenderer) {
        if (clipped) {
            screen := rend screenSize()
            glEnable(GL_SCISSOR_TEST)
            glScissor(drawing_region x() as Int,
                    (screen height - drawing_region y() - drawing_region height()) as Int,
                    drawing_region width() as Int,
                    drawing_region height() as Int)
        } else {
            glDisable(GL_SCISSOR_TEST)
        }
    }
}

TestRenderer: class extends NRenderer {
    /* TODO: anything missing */
    
    states: Stack<TestRenderState>
    current: TestRenderState
    acquired: Int = 0
    
    init: func {
        states = Stack<TestRenderState> new()
        current drawing_region size = screenSize()
        current color = NColor white()
    }
    
    fillColor: func -> NColor {current color}
    
    setFillColor: func (color: NColor) {
        current color = color
    }
    
    screenSize: func -> NSize {
	    info := sdlGetVideoInfo()
	    return NSize new(
	        info@ as StructSDLVideoInfo currentW as NFloat,
	        info@ as StructSDLVideoInfo currentH as NFloat)
	}
    
    loadImage: func (url: String) -> NImage {
        img := NImage new(url)
        _bufferImage(img)
        img frameSize = img size()
        img frameCount = 1
        return img
    }
    
    // TODO
    loadImageWithFrames: func (url: String, frameSize: NSize, frameCount: Int) -> NImage {
        img := loadImage(url)
        img frameSize = frameSize
        img frameCount = frameCount
        return img
    }
    
    _bufferImage: func (image: NImage) {
        if (image data != null && image data instanceOf(TestImageData))
            return
        
        data := TestImageData new()
        surf := imgLoad(image url)
        if (surf == null) {
            Exception new(This, "Couldn't load image at \""+image url+"\"") throw()
        }
        sdlLockSurface(surf)
        data _size set(surf@ as StructSDLSurface w as NFloat, surf@ as StructSDLSurface h as NFloat)
        fmt := surf@ as StructSDLSurface format@ as StructSDLPixelFormat
        glFormat := GL_RGBA
        components := 4
        if (fmt bitsPerPixel == 32) {
            if (fmt rmask != 0xff000000)
                glFormat = GL_BGRA
        } else if (fmt bitsPerPixel == 24) {
            components = 3
            if (fmt rmask == 0xff000000)
                glFormat = GL_RGB
            else
                glFormat = GL_BGR
        } else {
            sdlUnlockSurface(surf)
            sdlFreeSurface(surf)
            Exception new(This, "Invalid pixel format for image at \""+image url+"\"") throw()
        }
        
        glEnable(GL_TEXTURE_2D)
        glGenTextures(1, data _name&)
        glBindTexture(GL_TEXTURE_2D, data _name)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE)
            
        glTexImage2D(GL_TEXTURE_2D, 0, components, data _size width as Int, data _size height as Int, 0, glFormat, GL_UNSIGNED_BYTE, surf@ as StructSDLSurface pixels)
        image data = data
        sdlUnlockSurface(surf)
        sdlFreeSurface(surf)
    }
    
    saveState: func {
        states push(current)
    }
    
    restoreState: func {
        current = states pop()
        if (0 < acquired) current apply(this)
    }
    
    acquire: func {
        acquired += 1
        
        if (1 < acquired)
            return
        
        glPushAttrib(GL_ENABLE_BIT|GL_SCISSOR_BIT|GL_TEXTURE_BIT|GL_DEPTH_BUFFER_BIT|GL_COLOR_BUFFER_BIT)
        glMatrixMode(GL_PROJECTION)
        glPushMatrix()
        glLoadIdentity()
        sz := screenSize()
        glOrtho(0.0 as Double, sz width as Double, 0.0 as Double, sz height as Double, -10.0 as Double, 10.0 as Double)
        glMatrixMode(GL_MODELVIEW)
        glPushMatrix()
        glLoadIdentity()
        glTranslatef(0.0, sz height, 0.0)
        glScalef(1.0, -1.0, 1.0)
        
        glDepthFunc(GL_ALWAYS)
        glEnable(GL_BLEND)
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
        
        current apply(this)
    }
    
    release: func {
        if (acquired == 0)
            Exception new(This, "Attempt to release unacquired renderer") throw()
        
        acquired -= 1
        
        if (acquired == 0) {
            glMatrixMode(GL_PROJECTION)
            glPopMatrix()
            glMatrixMode(GL_MODELVIEW)
            glPopMatrix()
            glPopAttrib()
        }
    }
    
    fillRect: func (rect: NRect) {
        glDisable(GL_TEXTURE_2D)
        rect origin add(current origin)
        glBegin(GL_QUADS)
        glColor4fv(current color red&)
        glVertex2f(rect left(), rect top())
        glVertex2f(rect right(), rect top())
        glVertex2f(rect right(), rect bottom())
        glVertex2f(rect left(), rect bottom())
        glEnd()
    }
    
    setDrawingOrigin: func (origin: NPoint) { current origin = origin }
    
    drawingOrigin: func -> NPoint { current origin }
    
	drawImage: func (image: NImage, frame: Int, inRect: NRect) {
	    drawSubimage(image, frame, NRect new(NPoint zero(), image frameSize()), inRect)
	}
	
	drawSubimage: func (image: NImage, frame: Int, subimage, inRect: NRect) {
	    _bufferImage(image)
	    
	    glEnable(GL_TEXTURE_2D)
	    glBindTexture(GL_TEXTURE_2D, image data as TestImageData _name)
	    
	    inRect origin add(current origin)
	    inRect origin add(NSize min(inRect size, NSize zero()) toPoint())
	    inRect size width = inRect size width abs()
	    inRect size height = inRect size height abs()
	    
	    isize := image size()
	    scale := image frameSize()
	    
	    widthDiv := (isize width / scale width) as Int
	    column := frame % widthDiv
	    row := (frame - column) / widthDiv
	    
	    subimage origin x += column * scale width
	    subimage origin y += row * scale height
	    
	    isize set(1.0 / isize width, 1.0 / isize height)
	    subimage origin x *= isize width
	    subimage origin y *= isize height
	    subimage size width *= isize width
	    subimage size height *= isize height
	    
        glBegin(GL_QUADS)
        glColor4fv(current color red&)
        glTexCoord2f(subimage left(), subimage top())
        glVertex2f(inRect left(), inRect top())
        glTexCoord2f(subimage right(), subimage top())
        glVertex2f(inRect right(), inRect top())
        glTexCoord2f(subimage right(), subimage bottom())
        glVertex2f(inRect right(), inRect bottom())
        glTexCoord2f(subimage left(), subimage bottom())
        glVertex2f(inRect left(), inRect bottom())
        glEnd()
	}
	
	clippingRegion: func -> NRect {current drawing_region}
	setClippingRegion: func (drawing_region: NRect) {
	    current drawing_region = drawing_region
	    if (0 < acquired) current apply(this)
	}
	
	enableClipping: func {
	    current clipped = true
	    if (0 < acquired) current apply(this)
	}
    
    disableClipping: func {
	    current clipped = false
	    if (0 < acquired) current apply(this)
	}
    
}

TestView: class extends NView {
    init: func (frame: NRect) {
        super(frame)
    }
    
    draw: func (renderer: NRenderer) {
        renderer fillRect(bounds())
    }
}

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
    gui makeActive()
    
    rd := TestRenderer new()
    gui setRenderer(rd)
    
    windowImage := rd loadImageWithFrames("window.png", NSize new(256.0, 256.0), 2)
    windowDrawable := NNinePatchDrawable new(windowImage, NSize new(5.0, 24.0), NSize new(5.0, 5.0), 1.0)
    
    wnd := NFramedWindow new(NRect new(25.0, 64.0, 512.0, 256.0))
    // until skins are added, this unfortunately has to be done for every window
    // (because I'm still faffing about with yajl and trying to avoid rolling
    // my own parser for my own format)
    wnd _drawable = windowDrawable
    // don't ask me why I haven't ported addWindow yet.
    gui _windows add(wnd)
    
    wnd = NFramedWindow new(NRect new(25.0, 64.0, 512.0, 256.0))
    wnd _drawable = windowDrawable
    gui _windows add(wnd)
    wnd addSubview(TestView new(NRect new(24.0, 24.0, 128.0, 80.0)))
    
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
