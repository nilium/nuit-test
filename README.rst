=========
nuit-test
=========

This is the beginning of a collection of test code for nuit-ooc.  I don't mean
test code as in unit testing or anything else like that, just tests, or samples
I suppose, that should help you perform your own tests of NUIT without having
to write up a whole renderer implementation and all that first.  Doing that
isn't fun, nobody wants to write a renderer unless they have to, so at the very
least I'm providing an incredibly simple renderer to test with.

To build this, you'll need a few things:
    * `nuit-ooc`_
    * `ooc-sdl`_
    * `ooc-sdl_image`_
    * `ooc-glew`_
    * SDL_
    * SDL_Image_ (and any libraries it requires, such as libz, libpng, etc.)
    * GLEW_
    * `window.png`_ from `NUIT.gfx`_ (or create your own two-frame window image)

Under Mac OS, you'll also have to link the Cocoa and OpenGL frameworks.  I've
provided a *buildtest* script that includes both, since I'm a Mac user and I'm
also incredibly lazy and don't feel like typing out those arguments every time.
You may want to do the same.

License
-------

This code is licensed under the BSD license.  However, I really don't care what
you do with the code, just please don't claim it's your own - this isn't the
sort of code that's good enough to 'steal' (so to speak).

::

 Copyright (c) 2010, Noel R. Cower
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without 
 modification, are permitted provided that the following conditions are met:
 
  * Redistributions of source code must retain the above copyright notice, this 
    list of conditions and the following disclaimer.
 
  * Redistributions in binary form must reproduce the above copyright notice, 
    this list of conditions and the following disclaimer in the documentation 
    and/or other materials provided with the distribution.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND 
 ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED 
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE 
 DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE 
 FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL 
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR 
 SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER 
 CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, 
 OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE 
 OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

.. _`nuit-ooc`: http://github.com/nilium/nuit-ooc
.. _`ooc-sdl`: http://github.com/nilium/ooc-sdl
.. _`ooc-sdl_image`: http://github.com/nilium/ooc-sdl_image
.. _`ooc-glew`: http://github.com/OneSadCookie/ooc-glew
.. _SDL: http://libsdl.org/
.. _`SDL_image`: http://www.libsdl.org/projects/SDL_image
.. _GLEW: http://glew.sourceforge.net/
.. _`NUIT.gfx`: http://github.com/nilium/NUIT.gfx
.. _`window.png`: http://github.com/nilium/NUIT.gfx/blob/master/window.png