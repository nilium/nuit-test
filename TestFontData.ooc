use nuit, glew, freetype2

import structs/[HashMap, ArrayList]
import nuit/[Renderer, Types, Font]

import glew
import freetype2

import TestRenderer

/** FONT DATA **/

FontGlyph: class {
    fontData: TestFontData
    character: ULong
    glyph_index: Int
    page: GlyphPage = null
    size: NSize
    cell, uv: NRect
    bearing: NPoint
    advance: NPoint
    buffered := false
    
    init: func(=fontData, =character) {
        face := fontData face
        glyph_index = face getCharIndex(character)
        face loadGlyph(glyph_index, FTLoadFlag default)
        glyph := face@ glyph
        metrics := glyph@ metrics
        // invert Y bearing/advance since we draw from the top down
        bearing = NPoint new(metrics horiBearingX toFloat(), -metrics horiBearingY toFloat())
        advance = NPoint new(metrics horiAdvance toFloat(), -metrics vertAdvance toFloat())
        size = NSize new(metrics width toFloat(), metrics height toFloat())
        _buffer()
    }
    
    drawable?: func -> Bool { !(size width equals(0.0) || size height equals(0.0)) }
    
    draw: func (renderer: TestRenderer, origin: NPoint) {
        if (!drawable?()) {
            return
        }
        
        origin add(bearing)
        loc := NRect new(origin, size)
        
        glEnable(GL_TEXTURE_2D)
        glBindTexture(GL_TEXTURE_2D, page name)
        
        glBegin(GL_QUADS)
        glColor4fv(renderer current color red&)
        glTexCoord2f(uv left(), uv top())
        glVertex2f(loc left(), loc top())
        glTexCoord2f(uv right(), uv top())
        glVertex2f(loc right(), loc top())
        glTexCoord2f(uv right(), uv bottom())
        glVertex2f(loc right(), loc bottom())
        glTexCoord2f(uv left(), uv bottom())
        glVertex2f(loc left(), loc bottom())
        glEnd()
    }
    
    _buffer: func {
        if (buffered)
            return
        
        if (!drawable?()) {
            buffered = true
            return
        }
        
        page = fontData getPageForSize(size)
        origin := page pack(size)
        
        cell = NRect new(origin, size)
        
        oneOverWidth, oneOverHeight: Float
        oneOverWidth = 1.0 / page width
        oneOverHeight = 1.0 / page height
        
        uv = cell
        uv origin x *= oneOverWidth
        uv origin y *= oneOverHeight
        uv size width *= oneOverWidth
        uv size height *= oneOverHeight
        
        pRowLen, pAlign, pEnabled, pTex: Int
        pRedBias: Float
        glGetFloatv(GL_RED_BIAS, pRedBias&)
        glGetIntegerv(GL_UNPACK_ALIGNMENT, pAlign&)
        glGetIntegerv(GL_UNPACK_ROW_LENGTH, pRowLen&)
        glGetBooleanv(GL_TEXTURE_2D, pEnabled&)
        glGetIntegerv(GL_TEXTURE_BINDING_2D, pTex&)
        
        face := fontData face
        glyph := face@ glyph
        glyph render(FTRenderMode normal)
        bmp := glyph@ bitmap
        
        if (!pEnabled)
            glEnable(GL_TEXTURE_2D)
        glPixelStorei(GL_UNPACK_ALIGNMENT, 1)
        glPixelStorei(GL_UNPACK_ROW_LENGTH, bmp pitch)
        glPixelTransferf(GL_RED_BIAS, -1.0)
        
        glBindTexture(GL_TEXTURE_2D, page name)
        
        tx := origin x as Int
        ty := origin y as Int
        tw := size width as Int
        th := size height as Int
        glTexSubImage2D(GL_TEXTURE_2D, 0, tx, ty, tw, th, GL_ALPHA, GL_UNSIGNED_BYTE, bmp buffer)
        
        glPixelStorei(GL_UNPACK_ALIGNMENT, pAlign)
        glPixelStorei(GL_UNPACK_ROW_LENGTH, pRowLen)
        glPixelTransferf(GL_RED_BIAS, pRedBias)
        
        glBindTexture(GL_TEXTURE_2D, pTex)
        
        if (!pEnabled)
            glDisable(GL_TEXTURE_2D)
    }
}

// I didn't feel like doing proper glyph packing, so here's a half-assed form.
// You could probably replace this with a binary tree and it would pack a lot
// better, require fewer texture pages, etc.
GlyphPage: class {
    name: UInt
    width, height: Int
    x, y: Int
    rowHeight: Int = 0
    padding: Int = 2
    
    init: func(=width, =height) {
        penabled, ptex: Int
        glGetBooleanv(GL_TEXTURE_2D, penabled&)
        if (!penabled)
            glEnable(GL_TEXTURE_2D)
        
        glGetIntegerv(GL_TEXTURE_BINDING_2D, ptex&)
        nm: UInt
        glGenTextures(1, nm&)
        name = nm
        glBindTexture(GL_TEXTURE_2D, nm)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE)
        glTexImage2D(GL_TEXTURE_2D, 0, GL_ALPHA8, width, height, 0, GL_ALPHA, GL_UNSIGNED_BYTE, null)
        
        glBindTexture(GL_TEXTURE_2D, ptex)
        if (!penabled)
            glDisable(GL_TEXTURE_2D)
    }
    
    canFit?: func (sz: NSize) -> Bool {
        pad := NSize new(sz width + padding, sz height + padding)
        return ((x + pad width) < width) && ((y + pad height) < height) || (pad width < width && (y + pad height + rowHeight) < height)
    }
    
    pack: func (sz: NSize) -> NPoint {
        pad := NSize new(sz width + padding, sz height + padding)
        
        if (!(((x + pad width) < width) && ((y + pad height) < height))) {
            x = 0
            y += rowHeight
            rowHeight = pad height
        } else {
            if (rowHeight < pad height)
                rowHeight = pad height
        }
        
        origin := NPoint new(x as Float, y as Float)
        
        x += pad width
        
        return origin
    }
}

TestFontData: class extends NFontData {
    face: FTFace
    size: Int
    pgSize: Int = 0
    // I'm estimating that the average number of glyphs used by most
    // applications doesn't exceed 128 except in applications that do not use
    // English and similar languages (symbols-wise)
    glyphs := HashMap<ULong, FontGlyph> new(128)
    pages := ArrayList<GlyphPage> new(8)
    
    init: func(=size, =face) {
        // NOTE: this does not work well with unreasonably large font sizes
        // (larger than 128px is probably not going to yield very good results)
        pgSize = 256
        minsz := (size+2)*8
        while (pgSize < minsz) pgSize <<= 1
    }
    
    getGlyph: func(chr: ULong) -> FontGlyph {
        glyph := glyphs get(chr)
        if (!glyph) {
            glyph = FontGlyph new(this, chr)
            glyphs put(chr, glyph)
        }
        return glyph
    }
    
    getPageForSize: func (size: NSize) -> GlyphPage {
        page: GlyphPage = null
        iter := pages iterator()
        while (iter hasNext()) {
            page = iter next()
            if (page canFit?(size)) {
                return page
            }
        }
        
        page = GlyphPage new(pgSize, pgSize)
        pages add(page)
        return page
    }
    
    /**
        Returns the weight of the font (from 0.0 to 1.0).  Depending on the
        implementation, this may never be used, and should return 0.5 in such
        cases.
    */
    weight: func -> NFloat {
        0.5
    }

    /**
        Returns whether or not the font is bold.
    */
    isBold: func -> Bool {
        face isBold?()
    }

    /**
        Returns whether or not the font is italicized.
    */
    isItalic: func -> Bool {
        face isItalic?()
    }

    /**
        Returns whether or not the font can render the given character.
    */
    supportsGlyph: func (chr: ULong) -> Bool {
        getGlyph(chr) drawable?()
    }

    /**
        Returns the pixel size of the glyph for the character.

        In the event that the glyph is unsupported, a default size should be
        provided for that glyph.
    */
    glyphSize: func (chr: ULong) -> NSize {
        getGlyph(chr) size
    }

    /**
        Returns the relative horizontal and vertical position of the next
        character to follow the glyph without kerning.
    */
    glyphAdvance: func (chr: ULong) -> NPoint {
        getGlyph(chr) advance
    }

    /**
        Returns the kerning for the given glyph pairing.
    */
    glyphKerning: func (left, right: ULong) -> NPoint {
        vec: FTVector
        lg := face getCharIndex(left)
        rg := face getCharIndex(right)
        face getKerning(lg, rg, FTKerningMode default, vec&)
        return NPoint new(vec x toFloat(), vec y toFloat())
    }

    /**
        Returns the relative offset of the glyph from the baseline.
    */
    glyphBearing: func (chr: ULong) -> NPoint {
        getGlyph(chr) bearing
    }

    /**
        Returns what should be the minimum height of a line for the font.
    */
    lineHeight: func -> NFloat {
        face@ size@ metrics height toFloat()
    }

    /**
        Returns the font's baseline.
    */
    baseLine: func -> NFloat {
        (face@ ascender/64) as NFloat
    }
}
