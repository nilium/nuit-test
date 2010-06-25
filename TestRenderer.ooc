use nuit, sdl, sdl_image, glew, freetype2

import nuit/[Types, Renderer, Image, Font]

import structs/[Stack, HashMap, LinkedList]

import freetype2
import sdl
import sdl_image
import glew

import TestFontData

/** IMAGE DATA **/
TestImageData: class extends NImageData {
    url: String
    name: UInt
    size: NSize
    
    init: super func
    
    size: func -> NSize {size}
    
    dispose: func {
        glDeleteTextures(1, name&)
    }
}


/*** TEST RENDERER ***/
TestRenderState: cover {
    color: NColor
    drawing_region: NRect
    origin: NPoint
    clipped := false
    scale := NSize new(1.0, 1.0)
    
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
    ftlib: FTLibrary = null
    
    init: func {
        states = Stack<TestRenderState> new()
        current drawing_region size = screenSize()
        current color = NColor white()
        current scale = 1.0 as NSize
        if (ftlib initFreeType() != 0)
            Exception new(This, "Unable to init FreeType2") throw()
    }
    
    dispose: func {
        if (ftlib != null) {
            ftlib done()
            ftlib = null
        }
        
        for (fnt: TestFontData in _bufferedFonts)
            fnt dispose()
        _bufferedFonts clear()
        
        for (img: TestImageData in _bufferedImages)
            img dispose()
        _bufferedImages clear()
    }
    
    __destroy__: func {
        if (ftlib != null)
            ftlib done()
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
	
	loadFont: func (fnt: NFont) -> Bool {
	    if (fnt data && fnt data renderer() == this)
            return true
	    
	    _loadFont(fnt)
	    return true
	}
    
    loadImage: func (img: NImage) -> Bool {
        if (img data && img data renderer() == this)
            return true
        _bufferImage(img)
        return true
    }
    
    _bufferedFonts := LinkedList<TestFontData> new()
    _loadFont: func (font: NFont) {
        url := font url
        bold := font bold
        italic := font italic
        face: FTFace
	    if (ftlib newFace(url, 0, face&) != 0)
	        Exception new(This, "Unable to load font face at `%s`" format(url)) throw()
	    
	    faceIdx := 1
	    faces := face@ num_faces
	    while (!(bold == face isBold?() && italic == face isItalic?()) && faceIdx < faces) {
	        face done()
	        if (ftlib newFace(url, faceIdx, face&) != 0)
    	        Exception new(This, "Unable to load font face at `%s`" format(url)) throw()
    	    faceIdx += 1
	    }
	    if (!(bold == face isBold?() && italic == face isItalic?())) {
	        face done()
	        Exception new(This, "Unable to load font face at `%s` with requested style (bold:%d italic:%d)" format(url, bold, italic)) throw()
	    }
	    
	    height := font height()
	    face setPixelSizes(0, height)
	    
	    font data = TestFontData new(this, height, face)
	    _bufferedFonts add(font data)
    }
    
    _bufferedImages := HashMap<String, TestImageData> new(32)
    _bufferImage: func (image: NImage) {
        data := _bufferedImages get(image url)
        if (data) {
            "Using cached image data for `%s`" format(data url) println()
            image data = data
            return
        }
        
        data = TestImageData new(this)
        
        data url = image url clone()
        
        surf := imgLoad(image url)
        if (surf == null) {
            Exception new(This, "Couldn't load image at \""+image url+"\"") throw()
        }
        sdlLockSurface(surf)
        data size set(surf@ as StructSDLSurface w as NFloat, surf@ as StructSDLSurface h as NFloat)
        fmt := surf@ as StructSDLSurface format@ as StructSDLPixelFormat
        glFormat := GL_RGBA
        components := 4
        if (fmt bitsPerPixel == 32) {
            if (fmt rmask != 0x000000ff)
                glFormat = GL_BGRA
        } else if (fmt bitsPerPixel == 24) {
            components = 3
            if (fmt rmask == 0x000000ff)
                glFormat = GL_RGB
            else
                glFormat = GL_BGR
        } else {
            sdlUnlockSurface(surf)
            sdlFreeSurface(surf)
            Exception new(This, "Invalid pixel format for image at \""+image url+"\"") throw()
        }
        
        glEnable(GL_TEXTURE_2D)
        glGenTextures(1, data name&)
        glBindTexture(GL_TEXTURE_2D, data name)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE)
            
        glTexImage2D(GL_TEXTURE_2D, 0, components, data size width as Int, data size height as Int, 0, glFormat, GL_UNSIGNED_BYTE, surf@ as StructSDLSurface pixels)
        image data = data
        sdlUnlockSurface(surf)
        sdlFreeSurface(surf)
        
        _bufferedImages put(image url, data)
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
	    if (!loadImage(image))
	        return
	        
        frame = frame % image frames()
	    
	    glEnable(GL_TEXTURE_2D)
	    glBindTexture(GL_TEXTURE_2D, image data as TestImageData name)
	    
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
	    
	    inRect origin x *= current scale width
	    inRect origin y *= current scale height
	    inRect size width *= current scale width
	    inRect size height *= current scale height
	    
	    inRect origin add(current origin)
	    
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
	
	drawText: func (text: String, font: NFont, point: NPoint) {
	    if (font == null)
	        return
	    
	    if (!loadFont(font))
	        return
	    
	    point = point * scale() + current origin
	    
	    data := font data as TestFontData
	    
	    lastChr: ULong = 0
	    iter := text iterator()
	    while (iter hasNext()) {
	        chr := iter next()
	        
	        kerned := point
	        kerned add(data glyphKerning(lastChr, chr) * scale())
	        glyph := data getGlyph(chr)
	        glyph draw(this, kerned)
	        point x += glyph advance x * scale() width
	        
	        lastChr = chr
	    }
	}
    
    setScale: func (scale: NSize) {
        current scale = scale
    }
    
    scale: func -> NSize { current scale }
}
