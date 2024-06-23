module vintageconsole;

nothrow @nogc @safe:

import core.memory;
import core.stdc.stdlib: realloc, free;

import std.utf: byDchar;
import std.math: abs, exp;


/** 
    An individual cell of text-mode buffer.

    Either you access it or use the `print` functions.

    The first four bytes are a Unicode codepoint, conflated with a grapheme
    and font "glyph". There is only one font, and it's 8x8, not all codepoints
    exist.

    The next 4-bit are foreground color in a 16 color palette.
    The next 4-bit are background color in a 16 color palette.
    Each glyph is rendered fully opaque, in those two colors.
*/
static struct VCCharData
{
    ///
    dchar glyph     = 32;

    /// Low nibble = foreground color
    /// High nibble = background color
    ubyte color     = 8;  
    
    /// Style of that character
    VCStyle style; 
}


/** 
    Character styles.
 */
alias VCStyle = ubyte;

enum : VCStyle
{
    VCnone      = 0, /// no style
    VCshiny     = 1, /// <shiny>, emissive light

    // NOT IMPLEMENTED YET:
    VCbold      = 2, /// <b> or <strong>, not implemented
    VCunderline = 4, /// <u>, not implemented
    VCblink     = 8, /// <blink>, not implemented
    
}

/**
    Predefined palettes (default: vintage is loaded).
    You can either load a predefined palette, or change colors individually.
 */
enum VCPalette
{
    vintage,      ///
    campbell,     ///
    oneHalfLight, ///
    tango,        ///
}

/**
    Rectangle.
    Note: in vintage-console, rectangles exist in:
    - text space (0,0)-(columns x rows)
    - post/blur/output space (0,0)-(outW x outH)
*/
struct VCRect
{

nothrow:
@nogc:
@safe:
pure:
    int x1; ///
    int y1; ///
    int x2; ///
    int y2; ///

    bool isEmpty() const
    {
        return x1 == x2 || y1 == y2;
    }
}

/// Selected vintage font.
/// There is only one font, our goal it provide a Unicode 8x8 font suitable
/// for most languages, others were removed. 
/// A text mode with `dchar` as input.
enum VCFont
{
    // 8x8 fonts
    pcega, /// A font dumped from BIOS around 2003, then extended.
}

/// How to blend on output buffer?
enum VCBlendMode
{
    /// Blend console content to output, using alpha.
    sourceOver,

    /// Copy console content to output.
    copy,
}

/// How to align vertically the console in output buffer.
/// Default: center.
enum VCHorzAlign
{
    left,
    center,
    right
}

/// How to align vertically the console in output buffer.
/// Default: middle.
enum VCVertAlign
{
    top,
    middle,
    bottom
}

/// Various options to change behaviour of the library.
struct VCOptions
{
    VCBlendMode blendMode = VCBlendMode.sourceOver; ///
    VCHorzAlign halign    = VCHorzAlign.center; ///
    VCVertAlign valign    = VCVertAlign.middle; ///

    /// The output buffer is considered unchanged between calls.
    /// It is considered our changes are still there and not erased,
    /// unless the size of the buffer has changed, or its location.
    /// In this case we can draw less.
    bool allowOutCaching = true;

    /// Palette color of the borderColor;
    ubyte borderColor = 0;
}


/** 
    Main API of the vintage-console library.

    Note: none of the `VCConsole` functions are thread-safe. Either call them
          single-threaded, or synchronize externally.
*/
struct VCConsole
{
public:
nothrow:
@nogc:


    // ███████╗███████╗████████╗██╗   ██╗██████╗ 
    // ██╔════╝██╔════╝╚══██╔══╝██║   ██║██╔══██╗
    // ███████╗█████╗     ██║   ██║   ██║██████╔╝
    // ╚════██║██╔══╝     ██║   ██║   ██║██╔═══╝ 
    // ███████║███████╗   ██║   ╚██████╔╝██║   


    /**
        Set/get size of text buffer.
        Mandatory call.
        Warning: this clears the screen like calling `cls`.

        See_also: outbuf
     */
    void size(int columns, int rows)
    {
        updateTextBufferSize(columns, rows);
        updateBackBufferSize();
    }
    ///ditto
    int[2] size() pure const
    {
        return [_columns, _rows];
    }

    /**
        Given selected font and size of console screen, give a suggested output
        buffer size (in pixels).
        However, this library will manage to render in whatever buffer size you 
        give, so this is completely optional.
    */
    int suggestedWidth()
    {
        return _columns * charWidth();
    }
    ///ditto
    int suggestedHeight()
    {
        return _rows * charHeight();
    }

    /**
        Get number of text columns.
     */
    int columns() pure const { return _columns; }

    /**
        Get number of text rows.
     */
    int rows() pure const { return _columns; }



    // ███████╗████████╗██╗   ██╗██╗     ███████╗
    // ██╔════╝╚══██╔══╝╚██╗ ██╔╝██║     ██╔════╝
    // ███████╗   ██║    ╚████╔╝ ██║     █████╗
    // ╚════██║   ██║     ╚██╔╝  ██║     ██╔══╝
    // ███████║   ██║      ██║   ███████╗███████╗


    /** 
        Save/restore state, that includes:
        - foreground color
        - background color
        - cursor position
        - character style

        Warning: This won't report stack errors. Pair your save/restore calls,
                 else endure display bugs.
    */
    void save() pure
    {
        if (_stateCount == STATE_STACK_DEPTH)
        {
            // No more state depth, silently break
            return;
        }
        _state[_stateCount] = _state[_stateCount-1];
        _stateCount += 1;
    }
    ///ditto
    void restore() pure
    {
        // stack underflow is ignored.
        if (_stateCount >= 0)
            _stateCount -= 1;
    }

    /**
        Set/get font selection.
        But well, there is only one font.
     */
    void font(VCFont font)
    {
        if (_font != font)
        {
            _dirtyAllChars = true;
            _dirtyValidation = true;
            _font = font;
        }
        updateBackBufferSize(); // if internal size changed
    }
    ///ditto
    VCFont font() pure const
    { 
        return _font; 
    }

    /**
        Get width/height of a character with current font and scale, in pixels.
    */
    int charWidth() pure const
    {
        return fontCharSize(_font)[0];
    }
    ///ditto
    int charHeight() pure const
    {
        return fontCharSize(_font)[1];
    }

    /**
        Load a palette preset.
    */
    void palette(VCPalette palette)
    {
        for (int entry = 0; entry < 16; ++entry)
        {
            uint col = PALETTE_DATA[palette][entry];
            ubyte r = 0xff & (col >>> 16);
            ubyte g = 0xff & (col >>> 8);
            ubyte b = 0xff & col;
            ubyte a = 0xff;
            setPaletteEntry(entry, r, g, b, a);
        }
    }

    /**
        Set/get palette entries.
        Params: entry Palette index, must be 0 <= entry <= 15
                r Red value, 0 to 255
                g Green value, 0 to 255
                b Blue value, 0 to 255
                a Alpha value, 0 to 255. As background color, alpha is always
                  considered 255.
     */
    void setPaletteEntry(int entry, ubyte r, ubyte g, ubyte b, ubyte a) pure
    {
        rgba_t color = rgba_t(r, g, b, a);
        if (_palette[entry] != color)
        {
            _palette[entry]      = color;
            _paletteDirty[entry] = true;
            _dirtyValidation = true;
        }
    }
    ///ditto
    void getPaletteEntry(int entry, 
                         out ubyte r, 
                         out ubyte g, 
                         out ubyte b, 
                         out ubyte a) pure const
    {
        r = _palette[entry & 15].r;
        g = _palette[entry & 15].g;
        b = _palette[entry & 15].b;
        a = _palette[entry & 15].a;
    }

    /**
        Set foreground color.
     */
    void fg(int fg) pure
    {
        assert(fg >= 0 && fg < 16);
        current.fg = cast(ubyte)fg;
    }

    /**
        Set background color.
     */
    void bg(int bg) pure
    {
        assert(bg >= 0 && bg < 16);
        current.bg = cast(ubyte)bg;
    }

    /**
        Set character attributes aka style.
     */
    void style(VCStyle s) pure
    {
        current.style = s;
    }

    /** 
        Set other options.
     */
    void options(VCOptions options)
    {
        _options = options;

        // TODO: invalidate right stuff
    }

    /// ████████╗███████╗██╗  ██╗████████╗
    /// ╚══██╔══╝██╔════╝╚██╗██╔╝╚══██╔══╝
    ///    ██║   █████╗   ╚███╔╝    ██║   
    ///    ██║   ██╔══╝   ██╔██╗    ██║   
    ///    ██║   ███████╗██╔╝ ██╗   ██║   
    ///    ╚═╝   ╚══════╝╚═╝  ╚═╝   ╚═╝


    /**
        Access char buffer directly.
        Returns: One single character data.
     */
    ref VCCharData charAt(int col, int row) pure return
    {
        return _text[col + row * _columns];
    }
    /**
        Access char buffer directly.
        Returns: Consecutive character data, columns x rows items.
                 Characters are stores row-major.
     */
    VCCharData[] characters() pure return
    {
        return _text;
    }

    /**
        Print text to console at current cursor position.
        Text input MUST be UTF-8 or Unicode codepoint.
        
        See_also: `render()`
    */
    void print(const(char)[] s) pure
    {
        foreach(dchar ch; s.byDchar())
        {
            print(ch);            
        }
    }
    ///ditto
    void print(const(wchar)[] s) pure
    {
        foreach(dchar ch; s.byDchar())
        {
            print(ch);            
        }
    }
    ///ditto
    void print(const(dchar)[] s) pure
    {
        foreach(dchar ch; s)
        {
            print(ch);            
        }
    }
    ///ditto
    void print(dchar ch) pure
    {
        int col = current.ccol;
        int row = current.crow;

        if (validPosition(col, row))
        {
            VCCharData* cdata = &_text[col + row * _columns];
            cdata.glyph = ch;
            cdata.color = (current.fg & 0x0f) | ((current.bg & 0x0f) << 4);
            cdata.style = current.style;
            _dirtyValidation = true;
        }

        current.ccol += 1;

        if (current.ccol >= _columns)
        {
            newline();
        }
    }
    ///ditto
    void println(const(char)[] s) pure
    {
        print(s);
        newline();
    }
    ///ditto
    void println(const(wchar)[] s) pure
    {
        print(s);
        newline();
    }
    ///ditto
    void println(const(dchar)[] s) pure
    {
        print(s);
        newline();
    }
    ///ditto
    void newline() pure
    {
        current.ccol = 0;
        current.crow += 1;

        // Should we scroll everything up?
        while (current.crow >= _rows)
        {
            _dirtyValidation = true;

            for (int row = 0; row < _rows - 1; ++row)
            {
                for (int col = 0; col < _columns; ++col)
                {
                    charAt(col, row) = charAt(col, row + 1);
                }
            }

            for (int col = 0; col < _columns; ++col)
            {
                charAt(col, _rows-1) = VCCharData.init;
            }

            current.crow -= 1;
        }
    }

    /**
        `cls` clears the screen, filling it with spaces.
    */
    void cls() pure
    {
        // Set all char data to grey space
        _text[] = VCCharData.init;
        current.ccol = 0;
        current.crow = 0;
        _dirtyValidation = true;
    }

    /** 
        Change text cursor position. -1 indicate "keep".
        Do nothing for each dimension separately, if position is out of bounds.
    */
    void locate(int x = -1, int y = -1)
    {
        column(x);
        row(y);
    }
    ///ditto
    void column(int x)
    {
        if ((x >= 0) && (x < _columns)) 
            current.ccol = x;
    }
    ///ditto
    void row(int y)
    {
        if ((y >= 0) && (y < _rows))
            current.crow = y;
    }

    /**
        Print text to console at current cursor position, encoded in the CCL
        language (same as in console-colors DUB package).
        Text input MUST be UTF-8 or Unicode codepoint.

        Accepted tags:
        - <COLORNAME> such as:
          <black> <red>      <green>   <orange>
          <blue>  <magenta>  <cyan>    <lgrey> 
          <grey>  <lred>     <lgreen>  <yellow>
          <lblue> <lmagenta> <lcyan>   <white>

        each corresponding to color 0 to 15 in the palette.

        Unknown tags have no effect and are removed.
        Tags CAN'T have attributes.
        Here, CCL is modified to be ALWAYS VALID.

        - STYLE tags, such as:
        <strong>, <b>, <u>, <blink>, <shiny>

        Escaping:
        - To pass '<' as text and not a tag, use &lt;
        - To pass '>' as text and not a tag, use &gt;
        - To pass '&' as text not an entity, use &amp;

        See_also: `print`
    */
    void cprint(const(char)[] s) pure
    {
        CCLInterpreter interp;
        interp.initialize(&this);
        interp.interpret(s);
    }
    ///ditto
    void cprintln(const(char)[] s) pure
    {
        cprint(s);
        newline();
    }

    // ██████╗ ███████╗███╗   ██╗██████╗ ███████╗██████╗ ██╗███╗   ██╗ ██████╗ 
    // ██╔══██╗██╔════╝████╗  ██║██╔══██╗██╔════╝██╔══██╗██║████╗  ██║██╔════╝ 
    // ██████╔╝█████╗  ██╔██╗ ██║██║  ██║█████╗  ██████╔╝██║██╔██╗ ██║██║  ███╗
    // ██╔══██╗██╔══╝  ██║╚██╗██║██║  ██║██╔══╝  ██╔══██╗██║██║╚██╗██║██║   ██║
    // ██║  ██║███████╗██║ ╚████║██████╔╝███████╗██║  ██║██║██║ ╚████║╚██████╔╝
    // ╚═╝  ╚═╝╚══════╝╚═╝  ╚═══╝╚═════╝ ╚══════╝╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝ ╚═════╝ 

    /**
        Setup output buffer.
        Mandatory call, before being able to call `render`.
    */
    void outbuf(void* pixels, int width, int height, ptrdiff_t pitchBytes) 
        @system // memory-safe if pixels in that image addressable
    {
        if (_outPixels != pixels || _outW != width  
            || _outH != height || _outPitch != pitchBytes)
        {
            _outPixels = pixels;
            _outW = width;
            _outH = height;
            _outPitch = pitchBytes;

            // Consider output dirty
            _dirtyOut = true;

            // resize post buffer(s)
            updatePostBufferSize(width, height);
        }
    }

    /**
        Render console to output buffer.

        Depending on the options, only the rectangle in `getUpdateRect()`
        will get updated.

        Here is the flow of information:
           _text: CharData (dimension of console, eg: 80x25)
        => _back: RGBA (console x char size) 
        => _post, _blur, _emissive: RGBA (out buf size)
        => outbuf: RGBA

    */
    void render() 
        @system // memory-safe if `outputBuffer()` was called and memory-safe
    {
        // 0. Invalidate characters that need redraw in _back buffer.
        // After that, _charDirty tells if a character need redraw.
        VCRect textRect = invalidateChars();

        // 1. Draw chars in original size, only those who changed.
        drawAllChars(textRect);

        // from now on, consider _text and _back is up-to-date.
        // this information of recency is still in textRect and _charDirty.
        _dirtyAllChars = false;
        _cache[] = _text[];

        // Recompute placement of text in post buffer.
        recomputeLayout();

        // 2. Apply scale, character margins, etc.
        // Take characters in _back and put them in _post, into the final 
        // resolution.
        // This ony needs done for _charDirty.
        // Borders are drawn if _dirtyPost is true.
        // _dirtyPost get cleared after that.
        // Return rectangle that changed
        VCRect postRect = backToPost(textRect);

        // A dirty border color can affect out and post buffers redraw
        _paletteDirty[] = false;

        // 3. Effect go here. Blur, screen simulation, etc.
        //    So, effect are applied in final resolution size.
        applyEffects(postRect);

        // 4. Blend into out buffer.
        postToOut(textRect);
    }

    // <dirty rectangles> 

    /**
        Return if there are pending updates to draw, to reflect changes
        in text buffer content, colors, style or font used.
        
        This answer is not valid if you use printing or styling functions
        before calling `render()`.
     */
    bool hasPendingUpdate()
    {
        VCRect r = getUpdateRect();
        return (r.x2 - r.x1) != 0 && (r.y2 - r.y1) != 0;
    }

    /**
        (Optional call)

        Returns the rectangle (in pixels coordinates of the output buffer)
        which is going to be updated next if `render()` was called.
        This is useful to trigger a partial redraw.

        In case of nothing to redraw, it's width and height will be zero.
        You may also call `hasPendingUpdate()`.

        This rectangle is not valid if you use printing or styling functions
        before calling `render()`, change console size, change output buffer,
        change font, etc.
     */
    VCRect getUpdateRect()
    {
        if (_dirtyOut || (!_options.allowOutCaching) )
        {
            return VCRect(0, 0, _outW, _outH);
        }

        VCRect textRect = invalidateChars();

        if (textRect.isEmpty)
            return VCRect(0, 0, 0, 0);

        recomputeLayout();

        VCRect r = transformRectToOutputCoord(textRect);

        // extend it to account for blur
        return extendByFilterWidth(r);
    }

    // </dirty rectangles> 


    ~this() @trusted
    {
        free(_text.ptr); // free all text buffers
        free(_back.ptr); // free all pixel buffers
        free(_post.ptr);
        free(_charDirty.ptr);
    }

private:

    // By default, EGA text mode, correspond to a 320x200.
    VCFont _font    = VCFont.pcega;
    int _columns    = -1;
    int _rows       = -1;

    VCOptions _options = VCOptions.init;

    VCCharData[] _text  = null; // text buffer
    VCCharData[] _cache = null; // cached text buffer, if different then dirty
    bool[] _charDirty = null; // true if character need to redraw in _back

    // Palette
    rgba_t[16] _palette = 
    [
        rgba_t(  0,   0,   0, 255), rgba_t(128,   0,   0, 255),
        rgba_t(  0, 128,   0, 255), rgba_t(128, 128,   0, 255),
        rgba_t(  0,   0, 128, 255), rgba_t(128,   0, 128, 255),
        rgba_t(  0, 128, 128, 255), rgba_t(192, 192, 192, 255),
        rgba_t(128, 128, 128, 255), rgba_t(255,   0,   0, 255),
        rgba_t(  0, 255,   0, 255), rgba_t(255, 255,   0, 255),
        rgba_t(  0,   0, 255, 255), rgba_t(255,   0, 255, 255),
        rgba_t(  0, 255, 255, 255), rgba_t(255, 255, 255, 255),
    ];

    bool _dirtyAllChars   = true; // all chars need redraw (font change typically)
    bool _dirtyValidation = true; // if _charDirty already computed

    bool _dirtyPost   = true; // if out-sized buffers must be redrawn entirely
    bool _dirtyOut   = true; // if out-sized buffers must be redrawn entirely

    bool[16] _paletteDirty; // true if this color changed
    VCRect _lastBounds; // last computed dirty rectangle

    // Size of bitmap backing buffer.
    // In this buffer, every character is rendered next to each other.
    int _backWidth  = -1;
    int _backHeight = -1;
    rgba_t[] _back  = null;

    // A buffer for effects, same size as out buffer (including borders)
    // in this buffer, scale is applied, margins, and character margins
    // So its content depends upon outbuffer size.
    int _postWidth  = -1;
    int _postHeight = -1;
    rgba_t[] _post  = null; 

    rgba_t[] _blur  = null; // a buffer that is a copy of _post, with 
                            // blur applied

    // if true, whole blur must be redone
    bool _dirtyBlur = false;
    int _filterWidth; // filter width of gaussian blur, in pixels
    float[MAX_FILTER_WIDTH] _gaussianKernel;
    enum MAX_FILTER_WIDTH = 63; // presumably this is too slow beyond that

    // Note: those two buffers are fake-linear, premul alpha, unsigned 16-bit
    rgba16_t[] _emit  = null;  // emissive color
    rgba16_t[] _emitH  = null; // emissive color, horz-blurred, transposed

    static struct State
    {
        ubyte bg       = 0;
        ubyte fg       = 8;
        int ccol = 0; // curor col  (X position)
        int crow = 0; // cursor row (Y position)
        VCStyle style = 0;

        // for the CCL interpreter
        const(char)[] lastAppliedTag;
        int inputPos; // position of the opening tag in input chars.
    }

    enum STATE_STACK_DEPTH = 32;
    State[STATE_STACK_DEPTH] _state;
    int _stateCount = 1;

    ref State current() pure return
    {
        return _state[_stateCount - 1];
    }

    bool validPosition(int col, int row) pure const
    {
        return (cast(uint)col < _columns) && (cast(uint)row < _rows);
    }

    // Output buffer description
    void* _outPixels;
    int _outW;
    int _outH;
    ptrdiff_t _outPitch;

    // out and post scale and margins.
    // if any change, then post and out buffer must be redrawn
    int _outScaleX     = -1;
    int _outScaleY     = -1;
    int _outMarginLeft = -1;
    int _outMarginTop  = -1;
    int _charMarginX   = -1;
    int _charMarginY   = -1;

    // depending on font, console size and outbuf size, compute
    // the scaling and margins it needs.
    // Invalidate out and post buffer if that changed.
    void recomputeLayout()
    {
        int cw = charWidth();
        int ch = charHeight();
        int columns = _columns;
        int rows = _rows;
        int outW = _outW;
        int outH = _outH;
        int scaleX = _outW / (_columns * cw);
        int scaleY = _outH / (_rows    * ch);
        if (scaleX < 1) scaleX = 1;
        if (scaleY < 1) scaleY = 1;
        int scale = (scaleX < scaleY) ? scaleX : scaleY;
        int remainX = outW - (columns * cw) * scale;
        int remainY = outH - (rows    * ch) * scale;
        assert(remainX <= outW);
        assert(remainY <= outH);
        if (remainX < 0) remainX = 0;
        if (remainY < 0) remainY = 0;

        int marginLeft;
        int marginTop;
        final switch(_options.halign)
        {
            case VCHorzAlign.left:    marginLeft = 0; break;
            case VCHorzAlign.center:  marginLeft = (remainX+1)/2; break;
            case VCHorzAlign.right:   marginLeft = remainX; break;
        }

        final switch(_options.valign)
        {
            case VCVertAlign.top:     marginTop = 0; break;
            case VCVertAlign.middle:  marginTop = remainY/2; break;
            case VCVertAlign.bottom:  marginTop = remainY; break;
        }


        int charMarginX = 0; // not implemented
        int charMarginY = 0; // not implemented

        if (_outMarginLeft != marginLeft
            || _outMarginTop != marginTop
            || _charMarginX != charMarginX
            || _charMarginY != charMarginY 
            || _outScaleX != scale
            || _outScaleY != scale)
        {
            _dirtyOut = true;
            _dirtyPost = true;
            _outMarginLeft = marginLeft;
            _outMarginTop = marginTop;
            _charMarginX = charMarginX;
            _charMarginY = charMarginY;
            _outScaleX = scale;
            _outScaleY = scale;

            updateFilterSize(scale * cw * 2); // FUTURE: tune in order to maximize beauty
        }
    }

    // r is in text console coordinates
    // transform it in pixel coordinates
    VCRect transformRectToOutputCoord(VCRect r)
    {
        if (r.isEmpty)
            return r;
        int cw = charWidth();
        int ch = charHeight();
        r.x1 *= cw * _outScaleX; 
        r.x2 *= cw * _outScaleX;
        r.y1 *= ch * _outScaleY; 
        r.y2 *= ch * _outScaleY;
        r.x1 += _outMarginLeft;
        r.x2 += _outMarginLeft;
        r.y1 += _outMarginTop;
        r.y2 += _outMarginTop;
        return r;
    }

    // extend rect in output coordinates, by filter radius

    VCRect extendByFilterWidth(VCRect r)
    {
        int filterRadius = _filterWidth/2;
        r.x1 -= filterRadius;
        r.x2 += filterRadius;
        r.y1 -= filterRadius;
        r.y2 += filterRadius;
        if (r.x1 < 0) r.x1 = 0;
        if (r.y1 < 0) r.y1 = 0;
        if (r.x2 > _outW) r.x2 = _outW;
        if (r.y2 > _outH) r.y2 = _outH;
        return r;
    }

    // since post and output have same coordinates
    alias transformRectToPostCoord = transformRectToOutputCoord;

    void updateTextBufferSize(int columns, int rows) @trusted
    {
        if (_columns != columns || _rows != rows)
        {
            int cells = columns * rows;
            size_t bytes = cells * VCCharData.sizeof;
            void* p = realloc_c17(_text.ptr, bytes * 2);
            _text = (cast(VCCharData*)p)[0..cells];
            _cache = (cast(VCCharData*)p)[cells..2*cells];
            _charDirty = (cast(bool*) realloc_c17(_charDirty.ptr, cells * bool.sizeof))[0..cells];
            _columns = columns;
            _rows    = rows;
            _dirtyAllChars = true;
        }
        _text[] = VCCharData.init;
    }

    void updateBackBufferSize() @trusted
    {
        int width  = columns * charWidth;
        int height = rows    * charHeight;
        if (width != _backWidth || height != _backHeight)
        {
            _dirtyAllChars = true;
            size_t pixels = width * height;
            size_t bytesPerBuffer = pixels * 4;
            void* p = realloc_c17(_back.ptr, bytesPerBuffer);
            _back = (cast(rgba_t*)p)[0..pixels];
            _backHeight = height;
            _backWidth = width;
        }
    }

    void updatePostBufferSize(int width, int height) @trusted
    {
        if (width != _postWidth || height != _postHeight)
        {
            size_t pixels = width * height;
            size_t bytesPerBuffer = pixels * 4;
            void* p = realloc_c17(_post.ptr, bytesPerBuffer * 6);
            _post  = (cast(rgba_t*)p)[0..pixels];
            _blur  = (cast(rgba_t*)p)[pixels..pixels*2];
            _emit  = (cast(rgba16_t*)p)[pixels..pixels*2];
            _emitH = (cast(rgba16_t*)p)[pixels*2..pixels*4];
            _postWidth = width;
            _postHeight = height;
            _dirtyPost = true;
        }
    }

    void updateFilterSize(int filterSize)
    {
        // must be odd
        if ( (filterSize % 2) == 0 )
            filterSize++;

        // max filter size
        if (filterSize > MAX_FILTER_WIDTH)
            filterSize = MAX_FILTER_WIDTH;

        if (filterSize != _filterWidth)
        {
            _filterWidth = filterSize;

            double sigma = (filterSize - 1) / 6.0;
            double mu = 0.0;
            makeGaussianKernel(filterSize, sigma, mu, _gaussianKernel[]);
            _dirtyBlur = true;
        }
    }

    // Reasons to redraw: 
    //  - their fg or bg color changed
    //  - their fg or bg color PALETTE changed
    //  - glyph displayed changed
    //  - font changed
    //  - size changed
    //
    // Returns: the rectangle that need to change, in text buffer coordinates
    VCRect invalidateChars()
    {
        // the validation results itself might not need to be recomputed
        if (!_dirtyValidation)
            return _lastBounds;
        _dirtyValidation = false;

        VCRect bounds;
        bounds.x1 = _columns+1;
        bounds.y1 = _rows+1;
        bounds.x2 = -1;
        bounds.y2 = -1;

        if (_dirtyAllChars)
        {
            _charDirty[] = true;
            bounds.x1 = 0;
            bounds.y1 = 0;
            bounds.x2 = _columns;
            bounds.y2 = _rows;
        }
        else
        {
            for (int row = 0; row < _rows; ++row)
            {
                for (int col = 0; col < _columns; ++col)
                {
                    int icell = col + row * _columns;
                    VCCharData text  =  _text[icell];
                    VCCharData cache =  _cache[icell];
                    bool redraw = false;
                    if (text != cache)
                        redraw = true;
                    else if (_paletteDirty[text.color & 0x0f])
                        redraw = true;
                    else if (_paletteDirty[text.color >>> 4])
                        redraw = true;
                    if (redraw)
                    {
                        if (bounds.x1 > col  ) bounds.x1 = col;
                        if (bounds.y1 > row  ) bounds.y1 = row;
                        if (bounds.x2 < col+1) bounds.x2 = col+1;
                        if (bounds.y2 < row+1) bounds.y2 = row+1;
                    }
                    _charDirty[icell] = redraw;
                }
            }
            // make rect empty if nothing found
            if (bounds.x2 == -1)
            {
                bounds = VCRect(0, 0, 0, 0);
            }
        }
        _lastBounds = bounds;
        return bounds;
    }

    // Draw all chars from _text to _back, no caching yet
    void drawAllChars(VCRect textRect)
    {
        for (int row = textRect.y1; row < textRect.y2; ++row)
        {
            for (int col = textRect.x1; col < textRect.x2; ++col)
            {
                if (_charDirty[col + _columns * row])
                    drawChar(col, row);
            }
        }
    }

    // Draw from _back to _post
    // Returns changed rect, in pixels
    VCRect backToPost(VCRect textRect) @trusted
    {
        bool drawBorder = false;

        VCRect postRect = transformRectToPostCoord(textRect);

        if (_dirtyPost)
        {
            drawBorder = true;
        }
        if (_paletteDirty[_options.borderColor])
            drawBorder = true;

        if (drawBorder)
        {
            // PERF: only draw the black borders
            _post[] = _palette[_options.borderColor];
            postRect = VCRect(0, 0, _postWidth, _postHeight);
            textRect = VCRect(0, 0, _columns, _rows);
        }

        // Which chars to copy, with scale and margins applied?
        for (int row = textRect.y1; row < textRect.y2; ++row)
        {
            for (int col = textRect.x1; col < textRect.x2; ++col)
            {
                int charIndex = col + _columns * row;
                if ( ! ( _charDirty[charIndex] || _dirtyPost) )
                    continue; // Character didn't change, _post is up-to-date

                bool shiny = (_text[charIndex].style & VCshiny) != 0;
                copyCharBackToPost(col, row, shiny);
            }
        }
        _dirtyPost = false;
        return postRect;
    }

    void copyCharBackToPost(int col, int row, bool shiny) @trusted
    {
        int cw = charWidth();
        int ch = charHeight();

        int backPitch = _columns * cw;

        for (int y = row*ch; y < (row+1)*ch; ++y)
        {
            const(rgba_t)* backScan = &_back[backPitch * y];
            for (int x = col*cw; x < (col+1)*cw; ++x)
            {
                rgba_t fg = backScan[x];
                for (int yy = 0; yy < _outScaleY; ++yy)
                {
                    int posY = y * _outScaleY + yy + _outMarginTop;
                    if (posY >= _outH)
                        continue;
                    
                    int start = posY * _outW;
                    rgba_t[]   postScan = _post[start..start+_outW];
                    rgba16_t[] emitScan = _emit[start..start+_outW];

                    for (int xx = 0; xx < _outScaleX; ++xx)
                    {
                        int outX = x * _outScaleX + xx + _outMarginLeft;
                        if (outX >= _outW)
                            continue;

                        // copy pixel from _back buffer to _post
                        postScan[outX] = fg;

                        // but also write its emissiveness
                        emitScan[outX] = rgba16_t(0, 0, 0, 0);
                        if (shiny)
                        {
                            // premul and pow^2, better for blur
                            emitScan[outX].r = fg.r * fg.a;
                            emitScan[outX].g = fg.g * fg.a;
                            emitScan[outX].b = fg.b * fg.a;
                            emitScan[outX].a = fg.a * fg.a;
                        }
                    }
                }
            }
        }
    }

    // Draw from _post to _out
    void postToOut(VCRect textRect) @trusted
    {
        VCRect changeRect = transformRectToOutputCoord(textRect);

        // Extend it to account for blur
        changeRect = extendByFilterWidth(changeRect);

        if ( (!_options.allowOutCaching) || _dirtyOut)
        {
            // No caching-case, redraw everything we now from _post.
            // The buffer content wasn't preserved, so we do it again.
            changeRect = VCRect(0, 0, _outW, _outH); 
        }

        for (int y = changeRect.y1; y < changeRect.y2; ++y)
        {
            const(rgba_t)* postScan = &_blur[_postWidth * y];
            rgba_t*         outScan = cast(rgba_t*)(_outPixels + _outPitch * y);

            for (int x = changeRect.x1; x < changeRect.x2; ++x)
            {
                // Read one pixel, make potentially several in output
                // with nearest resampling
                rgba_t fg = postScan[x];
                final switch (_options.blendMode) with (VCBlendMode)
                {
                    case copy:
                        outScan[x] = fg;
                        break;

                    case sourceOver:
                        outScan[x] = blendColor(fg, outScan[x], fg.a);
                        break;
                }
            }
        }

        _dirtyOut = false;
    }


    void drawChar(int col, int row) @trusted
    {
        VCCharData cdata = charAt(col, row);

        int cw = charWidth();
        int ch = charHeight();
        ubyte fgi = cdata.color & 15;
        ubyte bgi = cdata.color >>> 4;
        rgba_t fgCol = _palette[ cdata.color &  15 ];
        rgba_t bgCol = _palette[ cdata.color >>> 4 ];
        const(ubyte)[] glyphData = getGlyphData(_font, cdata.glyph);
        assert(glyphData.length == 8);

        for (int y = 0; y < ch; ++y)
        {
            const int yback = row * ch + y;
            const int bits  = glyphData[y];

            rgba_t* pixels  = &_back[(_columns * cw) * yback + (col * cw)];
            if (bits == 0)
                pixels[0..cw] = bgCol; // speed-up empty lines 
            else
            {   
                for (int x = 0; x < cw; ++x)
                {
                    bool on = (bits >> (cw - 1 - x)) & 1;
                    pixels[x] = on ? fgCol : bgCol;
                }
            }
        }
    }

    // copy _post to _blur (same space)
    // _blur is _post + filtered _emissive
    void applyEffects(VCRect updateRect) @trusted
    {
        if (_dirtyBlur)
        {
            updateRect = VCRect(0, 0, _outW, _outH);
            _dirtyBlur = false;
        }

        // PERF: transpose intermediate buffer _emissiveH
        // PERF: alpha useless in _emissive
        // PERF: alpha useless in _emissiveH

        int fWidthDiv2 = _filterWidth / 2;

        // blur emissive horizontally, from _emissive to _emissiveH
        for (int y = updateRect.y1; y < updateRect.y2; ++y)
        {
            rgba16_t* emissiveScan  = &_emit[_postWidth * y]; 
            rgba16_t* emissiveHScan = &_emitH[_postWidth * y]; 
            for (int x = updateRect.x1; x < updateRect.x2; ++x)
            {  
                if (x < 0) continue;
                if (x >= _postWidth) continue;

                float r = 0, g = 0, b = 0;
                float[] kernel = _gaussianKernel;
                for (int n = -fWidthDiv2; n <= fWidthDiv2; ++n)
                {
                    int xe = x + n;
                    if (xe < 0) continue;
                    if (xe >= _postWidth) continue;
                    rgba16_t emissive = emissiveScan[xe];
                    float factor = _gaussianKernel[fWidthDiv2 + n];
                    r += emissive.r * factor;
                    g += emissive.g * factor;
                    b += emissive.b * factor;
                }
                emissiveHScan[x].r = cast(ushort)r;
                emissiveHScan[x].g = cast(ushort)g;
                emissiveHScan[x].b = cast(ushort)b;
            }
        }

        // Note: updateRect is now extended horizontally by fWidthDiv2 on each
        // sides, since the update rect of _emissiveH is larger.

        for (int y = updateRect.y1; y < updateRect.y2; ++y)
        {
 
            const(rgba_t)* postScan = &_post[_postWidth * y];
            rgba_t*        blurScan = &_blur[_postWidth * y];

            for (int x = updateRect.x1 - fWidthDiv2; x < updateRect.x2 + fWidthDiv2; ++x)
            {
                // blur vertically
                float r = 0, g = 0, b = 0;
                if (x < 0) continue;
                if (x >= _postWidth) continue;

                for (int n = -fWidthDiv2; n <= fWidthDiv2; ++n)
                {
                    int ye = y + n;
                    if (ye < 0) continue;
                    if (ye >= _postHeight) continue;
                    rgba16_t emitH = _emitH[_postWidth * ye + x];
                    float factor = _gaussianKernel[fWidthDiv2 + n];
                    r += emitH.r * factor;
                    g += emitH.g * factor;
                    b += emitH.b * factor;
                }

                static ubyte clamp_0_255(float t)
                {
                    int u = cast(int)t;
                    if (u > 255) u = 255;
                    if (u < 0) u = 0;
                    return cast(ubyte)u;
                }

                // TODO tune
                enum float BLUR_AMOUNT = 1.05 / 255.0f;//0.01;//.52892;

                rgba_t post = postScan[x];
                post.r = clamp_0_255(post.r + r * BLUR_AMOUNT);
                post.g = clamp_0_255(post.g + g * BLUR_AMOUNT);
                post.b = clamp_0_255(post.b + b * BLUR_AMOUNT);
                blurScan[x] = post;
            }
        }
    }
}

private:

struct rgba_t
{
    ubyte r, g, b, a;
}

struct rgba16_t
{
    ushort r, g, b, a;
}

void* realloc_c17(void* p, size_t size) @system
{
    if (size == 0)
    {
        free(p);
        return null;
    }
    return realloc(p, size);
}


rgba_t blendColor(rgba_t fg, rgba_t bg, ubyte alpha) pure
{
    ubyte invAlpha = cast(ubyte)(~cast(int)alpha);
    rgba_t c = void;
    c.r = cast(ubyte) ( ( (fg.r * alpha) + (bg.r * invAlpha)  ) / ubyte.max );
    c.g = cast(ubyte) ( ( (fg.g * alpha) + (bg.g * invAlpha)  ) / ubyte.max );
    c.b = cast(ubyte) ( ( (fg.b * alpha) + (bg.b * invAlpha)  ) / ubyte.max );
    c.a = cast(ubyte) ( ( (fg.a * alpha) + (bg.a * invAlpha)  ) / ubyte.max );
    return c;
}



static immutable uint[16][VCPalette.max+1] PALETTE_DATA =
[
    // Vintaage
    [ 0x000000, 0x800000, 0x008000, 0x808000, 
      0x000080, 0x800080, 0x008080, 0xc0c0c0,        
      0x808080, 0xff0000, 0x00ff00, 0xffff00,
      0x0000ff, 0xff00ff, 0x00ffff, 0xffffff ],      

    // Campbell
    [ 0x0c0c0c, 0xc50f1f, 0x13a10e, 0xc19c00, 
      0x0037da, 0x881798, 0x3a96dd, 0xcccccc,
      0x767676, 0xe74856, 0x16c60c, 0xf9f1a5,
      0x3b78ff, 0xb4009e, 0x61d6d6, 0xf2f2f2 ],

    // OneHalfLight
    [ 0x383a42, 0xe45649, 0x50a14f, 0xc18301, 
      0x0184bc, 0xa626a4, 0x0997b3, 0xfafafa,
      0x4f525d, 0xdf6c75, 0x98c379, 0xe4c07a,
      0x61afef, 0xc577dd, 0x56b5c1, 0xffffff ],

    // Tango
    [ 0x000000, 0xcc0000, 0x4e9a06, 0xc4a000,
      0x3465a4, 0x75507b, 0x06989a, 0xd3d7cf,
      0x555753, 0xef2929, 0x8ae234, 0xfce94f,
      0x729fcf, 0xad7fa8, 0x34e2e2, 0xeeeeec ],
];

alias VCRangeFlags = int;
enum : VCRangeFlags
{
    // the whole range has the same glyph
    VCSingleGlyph = 1
}

struct VCUnicodeRange
{
    dchar start, stop;
    const(ubyte)[] glyphData;
    VCRangeFlags flags = 0;
}

struct VCFontDesc
{
    int[2] charSize;
    VCUnicodeRange[] fontData;
}

int[2] fontCharSize(VCFont font) pure
{
    return BUILTIN_FONTS[font].charSize;
}

const(ubyte)[] getGlyphData(VCFont font, dchar glyph) pure
{
    assert(font == VCFont.pcega);
    const(VCUnicodeRange)[] fontData = BUILTIN_FONTS[font].fontData;

    int ch = 8;
    for (size_t r = 0; r < fontData.length; ++r)
    {
        if (glyph >= fontData[r].start && glyph < fontData[r].stop)
        {
            VCRangeFlags flags = fontData[r].flags;
            
            if ( (flags & VCSingleGlyph) != 0)
                return fontData[r].glyphData[0..ch];

            uint index = glyph - fontData[r].start;
            return fontData[r].glyphData[index*ch..index*ch+ch];
        }
    }

    // Return notdef glyph
    return NOT_DEF[0..8];
}


static immutable VCFontDesc[VCFont.max + 1] BUILTIN_FONTS =
[
    VCFontDesc([8, 8], 
        [ 
            VCUnicodeRange(0x0000, 0x0020, CONTROL_CHARS, VCSingleGlyph),
            VCUnicodeRange(0x0020, 0x0080, LOWER_ANSI)
        ])
];


// Note: not sure what font it is, I dumped that from BIOS memory years ago
static immutable ubyte[8] CONTROL_CHARS =
[
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // Note: all control chars have that same glyph
];
    
static immutable ubyte[8] NOT_DEF =
[
    0x78, 0xcc, 0x0c, 0x18, 0x30, 0x00, 0x30, 0x00, // ?
];

static immutable ubyte[96 * 8] LOWER_ANSI =
[    
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // U+0020 Space
    0x30, 0x78, 0x78, 0x30, 0x30, 0x00, 0x30, 0x00, // U+0021
    0x6c, 0x6c, 0x6c, 0x00, 0x00, 0x00, 0x00, 0x00, // U+0022
    0x6c, 0x6c, 0xfe, 0x6c, 0xfe, 0x6c, 0x6c, 0x00, // U+0023
    0x30, 0x7c, 0xc0, 0x78, 0x0c, 0xf8, 0x30, 0x00, // U+0024
    0x00, 0xc6, 0xcc, 0x18, 0x30, 0x66, 0xc6, 0x00, // U+0025
    0x38, 0x6c, 0x38, 0x76, 0xdc, 0xcc, 0x76, 0x00, // U+0026
    0x60, 0x60, 0xc0, 0x00, 0x00, 0x00, 0x00, 0x00, // U+0027
    0x18, 0x30, 0x60, 0x60, 0x60, 0x30, 0x18, 0x00, // U+0028
    0x60, 0x30, 0x18, 0x18, 0x18, 0x30, 0x60, 0x00, // U+0029
    0x00, 0x66, 0x3c, 0xff, 0x3c, 0x66, 0x00, 0x00, // U+002A
    0x00, 0x30, 0x30, 0xfc, 0x30, 0x30, 0x00, 0x00, // U+002B
    0x00, 0x00, 0x00, 0x00, 0x00, 0x30, 0x30, 0x60, // U+002C
    0x00, 0x00, 0x00, 0xfc, 0x00, 0x00, 0x00, 0x00, // U+002D
    0x00, 0x00, 0x00, 0x00, 0x00, 0x30, 0x30, 0x00, // U+002E
    0x06, 0x0c, 0x18, 0x30, 0x60, 0xc0, 0x80, 0x00, // U+002F
    0x7c, 0xc6, 0xce, 0xde, 0xf6, 0xe6, 0x7c, 0x00, // U+0030
    0x30, 0x70, 0x30, 0x30, 0x30, 0x30, 0xfc, 0x00, // U+0031
    0x78, 0xcc, 0x0c, 0x38, 0x60, 0xcc, 0xfc, 0x00, // U+0032
    0x78, 0xcc, 0x0c, 0x38, 0x0c, 0xcc, 0x78, 0x00, // U+0033
    0x1c, 0x3c, 0x6c, 0xcc, 0xfe, 0x0c, 0x1e, 0x00, // U+0034
    0xfc, 0xc0, 0xf8, 0x0c, 0x0c, 0xcc, 0x78, 0x00, // U+0035
    0x38, 0x60, 0xc0, 0xf8, 0xcc, 0xcc, 0x78, 0x00, // U+0036
    0xfc, 0xcc, 0x0c, 0x18, 0x30, 0x30, 0x30, 0x00, // U+0037
    0x78, 0xcc, 0xcc, 0x78, 0xcc, 0xcc, 0x78, 0x00, // U+0038
    0x78, 0xcc, 0xcc, 0x7c, 0x0c, 0x18, 0x70, 0x00, // U+0039
    0x00, 0x30, 0x30, 0x00, 0x00, 0x30, 0x30, 0x00, // U+003A
    0x00, 0x30, 0x30, 0x00, 0x00, 0x30, 0x30, 0x60, // U+003B
    0x18, 0x30, 0x60, 0xc0, 0x60, 0x30, 0x18, 0x00, // U+003C
    0x00, 0x00, 0xfc, 0x00, 0x00, 0xfc, 0x00, 0x00, // U+003D
    0x60, 0x30, 0x18, 0x0c, 0x18, 0x30, 0x60, 0x00, // U+003E
    0x78, 0xcc, 0x0c, 0x18, 0x30, 0x00, 0x30, 0x00, // U+003F ?
    0x7c, 0xc6, 0xde, 0xde, 0xde, 0xc0, 0x78, 0x00, // U+0040
    0x30, 0x78, 0xcc, 0xcc, 0xfc, 0xcc, 0xcc, 0x00, // U+0041
    0xfc, 0x66, 0x66, 0x7c, 0x66, 0x66, 0xfc, 0x00, // U+0042
    0x3c, 0x66, 0xc0, 0xc0, 0xc0, 0x66, 0x3c, 0x00, // U+0043
    0xf8, 0x6c, 0x66, 0x66, 0x66, 0x6c, 0xf8, 0x00, // U+0044
    0xfe, 0x62, 0x68, 0x78, 0x68, 0x62, 0xfe, 0x00, // U+0045
    0xfe, 0x62, 0x68, 0x78, 0x68, 0x60, 0xf0, 0x00, // U+0046
    0x3c, 0x66, 0xc0, 0xc0, 0xce, 0x66, 0x3e, 0x00, // U+0047
    0xcc, 0xcc, 0xcc, 0xfc, 0xcc, 0xcc, 0xcc, 0x00, // U+0048
    0x78, 0x30, 0x30, 0x30, 0x30, 0x30, 0x78, 0x00, // U+0049
    0x1e, 0x0c, 0x0c, 0x0c, 0xcc, 0xcc, 0x78, 0x00, // U+004A
    0xe6, 0x66, 0x6c, 0x78, 0x6c, 0x66, 0xe6, 0x00, // U+004B
    0xf0, 0x60, 0x60, 0x60, 0x62, 0x66, 0xfe, 0x00, // U+004C
    0xc6, 0xee, 0xfe, 0xfe, 0xd6, 0xc6, 0xc6, 0x00, // U+004D
    0xc6, 0xe6, 0xf6, 0xde, 0xce, 0xc6, 0xc6, 0x00, // U+004E
    0x38, 0x6c, 0xc6, 0xc6, 0xc6, 0x6c, 0x38, 0x00, // U+004F
    0xfc, 0x66, 0x66, 0x7c, 0x60, 0x60, 0xf0, 0x00, // U+0050
    0x78, 0xcc, 0xcc, 0xcc, 0xdc, 0x78, 0x1c, 0x00, // U+0051
    0xfc, 0x66, 0x66, 0x7c, 0x6c, 0x66, 0xe6, 0x00, // U+0052
    0x78, 0xcc, 0xe0, 0x70, 0x1c, 0xcc, 0x78, 0x00, // U+0053
    0xfc, 0xb4, 0x30, 0x30, 0x30, 0x30, 0x78, 0x00, // U+0054
    0xcc, 0xcc, 0xcc, 0xcc, 0xcc, 0xcc, 0xfc, 0x00, // U+0055
    0xcc, 0xcc, 0xcc, 0xcc, 0xcc, 0x78, 0x30, 0x00, // U+0056
    0xc6, 0xc6, 0xc6, 0xd6, 0xfe, 0xee, 0xc6, 0x00, // U+0057
    0xc6, 0xc6, 0x6c, 0x38, 0x38, 0x6c, 0xc6, 0x00, // U+0058
    0xcc, 0xcc, 0xcc, 0x78, 0x30, 0x30, 0x78, 0x00, // U+0059
    0xfe, 0xc6, 0x8c, 0x18, 0x32, 0x66, 0xfe, 0x00, // U+005A
    0x78, 0x60, 0x60, 0x60, 0x60, 0x60, 0x78, 0x00, // U+005B
    0xc0, 0x60, 0x30, 0x18, 0x0c, 0x06, 0x02, 0x00, // U+005C
    0x78, 0x18, 0x18, 0x18, 0x18, 0x18, 0x78, 0x00, // U+005D
    0x10, 0x38, 0x6c, 0xc6, 0x00, 0x00, 0x00, 0x00, // U+005E
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xff, // U+005F
    0x30, 0x30, 0x18, 0x00, 0x00, 0x00, 0x00, 0x00, // U+0060
    0x00, 0x00, 0x78, 0x0c, 0x7c, 0xcc, 0x76, 0x00, // U+0061
    0xe0, 0x60, 0x60, 0x7c, 0x66, 0x66, 0xdc, 0x00, // U+0062
    0x00, 0x00, 0x78, 0xcc, 0xc0, 0xcc, 0x78, 0x00, // U+0063
    0x1c, 0x0c, 0x0c, 0x7c, 0xcc, 0xcc, 0x76, 0x00, // U+0064
    0x00, 0x00, 0x78, 0xcc, 0xfc, 0xc0, 0x78, 0x00, // U+0065
    0x38, 0x6c, 0x60, 0xf0, 0x60, 0x60, 0xf0, 0x00, // U+0066
    0x00, 0x00, 0x76, 0xcc, 0xcc, 0x7c, 0x0c, 0xf8, // U+0067
    0xe0, 0x60, 0x6c, 0x76, 0x66, 0x66, 0xe6, 0x00, // U+0068
    0x30, 0x00, 0x70, 0x30, 0x30, 0x30, 0x78, 0x00, // U+0069
    0x0c, 0x00, 0x0c, 0x0c, 0x0c, 0xcc, 0xcc, 0x78, // U+006A
    0xe0, 0x60, 0x66, 0x6c, 0x78, 0x6c, 0xe6, 0x00, // U+006B
    0x70, 0x30, 0x30, 0x30, 0x30, 0x30, 0x78, 0x00, // U+006C
    0x00, 0x00, 0xcc, 0xfe, 0xfe, 0xd6, 0xc6, 0x00, // U+006D
    0x00, 0x00, 0xf8, 0xcc, 0xcc, 0xcc, 0xcc, 0x00, // U+006E
    0x00, 0x00, 0x78, 0xcc, 0xcc, 0xcc, 0x78, 0x00, // U+006F
    0x00, 0x00, 0xdc, 0x66, 0x66, 0x7c, 0x60, 0xf0, // U+0070
    0x00, 0x00, 0x76, 0xcc, 0xcc, 0x7c, 0x0c, 0x1e, // U+0071
    0x00, 0x00, 0xdc, 0x76, 0x66, 0x60, 0xf0, 0x00, // U+0072
    0x00, 0x00, 0x7c, 0xc0, 0x78, 0x0c, 0xf8, 0x00, // U+0073
    0x10, 0x30, 0x7c, 0x30, 0x30, 0x34, 0x18, 0x00, // U+0074
    0x00, 0x00, 0xcc, 0xcc, 0xcc, 0xcc, 0x76, 0x00, // U+0075
    0x00, 0x00, 0xcc, 0xcc, 0xcc, 0x78, 0x30, 0x00, // U+0076
    0x00, 0x00, 0xc6, 0xd6, 0xfe, 0xfe, 0x6c, 0x00, // U+0077
    0x00, 0x00, 0xc6, 0x6c, 0x38, 0x6c, 0xc6, 0x00, // U+0078
    0x00, 0x00, 0xcc, 0xcc, 0xcc, 0x7c, 0x0c, 0xf8, // U+0079
    0x00, 0x00, 0xfc, 0x98, 0x30, 0x64, 0xfc, 0x00, // U+007A
    0x1c, 0x30, 0x30, 0xe0, 0x30, 0x30, 0x1c, 0x00, // U+007B
    0x18, 0x18, 0x18, 0x00, 0x18, 0x18, 0x18, 0x00, // U+007C
    0xe0, 0x30, 0x30, 0x1c, 0x30, 0x30, 0xe0, 0x00, // U+007D
    0x76, 0xdc, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // U+007E
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // U+007F Delete
];

/* CP437 upper range
    0x00, 0x10, 0x38, 0x6c, 0xc6, 0xc6, 0xfe, 0x00,
    0x78, 0xcc, 0xc0, 0xcc, 0x78, 0x18, 0x0c, 0x78,
    0x00, 0xcc, 0x00, 0xcc, 0xcc, 0xcc, 0x7e, 0x00,
    0x1c, 0x00, 0x78, 0xcc, 0xfc, 0xc0, 0x78, 0x00,
    0x7e, 0xc3, 0x3c, 0x06, 0x3e, 0x66, 0x3f, 0x00,
    0xcc, 0x00, 0x78, 0x0c, 0x7c, 0xcc, 0x7e, 0x00,
    0xe0, 0x00, 0x78, 0x0c, 0x7c, 0xcc, 0x7e, 0x00,
    0x30, 0x30, 0x78, 0x0c, 0x7c, 0xcc, 0x7e, 0x00,
    0x00, 0x00, 0x78, 0xc0, 0xc0, 0x78, 0x0c, 0x38,
    0x7e, 0xc3, 0x3c, 0x66, 0x7e, 0x60, 0x3c, 0x00,
    0xcc, 0x00, 0x78, 0xcc, 0xfc, 0xc0, 0x78, 0x00,
    0xe0, 0x00, 0x78, 0xcc, 0xfc, 0xc0, 0x78, 0x00,
    0xcc, 0x00, 0x70, 0x30, 0x30, 0x30, 0x78, 0x00,
    0x7c, 0xc6, 0x38, 0x18, 0x18, 0x18, 0x3c, 0x00,
    0xe0, 0x00, 0x70, 0x30, 0x30, 0x30, 0x78, 0x00,
    0xc6, 0x38, 0x6c, 0xc6, 0xfe, 0xc6, 0xc6, 0x00,
    0x30, 0x30, 0x00, 0x78, 0xcc, 0xfc, 0xcc, 0x00,
    0x1c, 0x00, 0xfc, 0x60, 0x78, 0x60, 0xfc, 0x00,
    0x00, 0x00, 0x7f, 0x0c, 0x7f, 0xcc, 0x7f, 0x00,
    0x3e, 0x6c, 0xcc, 0xfe, 0xcc, 0xcc, 0xce, 0x00,
    0x78, 0xcc, 0x00, 0x78, 0xcc, 0xcc, 0x78, 0x00,
    0x00, 0xcc, 0x00, 0x78, 0xcc, 0xcc, 0x78, 0x00,
    0x00, 0xe0, 0x00, 0x78, 0xcc, 0xcc, 0x78, 0x00,
    0x78, 0xcc, 0x00, 0xcc, 0xcc, 0xcc, 0x7e, 0x00,
    0x00, 0xe0, 0x00, 0xcc, 0xcc, 0xcc, 0x7e, 0x00,
    0x00, 0xcc, 0x00, 0xcc, 0xcc, 0x7c, 0x0c, 0xf8,
    0xc3, 0x18, 0x3c, 0x66, 0x66, 0x3c, 0x18, 0x00,
    0xcc, 0x00, 0xcc, 0xcc, 0xcc, 0xcc, 0x78, 0x00,
    0x18, 0x18, 0x7e, 0xc0, 0xc0, 0x7e, 0x18, 0x18,
    0x38, 0x6c, 0x64, 0xf0, 0x60, 0xe6, 0xfc, 0x00,
    0xcc, 0xcc, 0x78, 0xfc, 0x30, 0xfc, 0x30, 0x30,
    0xf8, 0xcc, 0xcc, 0xfa, 0xc6, 0xcf, 0xc6, 0xc7,
    0x0e, 0x1b, 0x18, 0x3c, 0x18, 0x18, 0xd8, 0x70,
    0x1c, 0x00, 0x78, 0x0c, 0x7c, 0xcc, 0x7e, 0x00,
    0x38, 0x00, 0x70, 0x30, 0x30, 0x30, 0x78, 0x00,
    0x00, 0x1c, 0x00, 0x78, 0xcc, 0xcc, 0x78, 0x00,
    0x00, 0x1c, 0x00, 0xcc, 0xcc, 0xcc, 0x7e, 0x00,
    0x00, 0xf8, 0x00, 0xf8, 0xcc, 0xcc, 0xcc, 0x00,
    0xfc, 0x00, 0xcc, 0xec, 0xfc, 0xdc, 0xcc, 0x00,
    0x3c, 0x6c, 0x6c, 0x3e, 0x00, 0x7e, 0x00, 0x00,
    0x38, 0x6c, 0x6c, 0x38, 0x00, 0x7c, 0x00, 0x00,
    0x30, 0x00, 0x30, 0x60, 0xc0, 0xcc, 0x78, 0x00,
    0x00, 0x00, 0x00, 0xfc, 0xc0, 0xc0, 0x00, 0x00,
    0x00, 0x00, 0x00, 0xfc, 0x0c, 0x0c, 0x00, 0x00,
    0xc3, 0xc6, 0xcc, 0xde, 0x33, 0x66, 0xcc, 0x0f,
    0xc3, 0xc6, 0xcc, 0xdb, 0x37, 0x6f, 0xcf, 0x03,
    0x18, 0x18, 0x00, 0x18, 0x18, 0x18, 0x18, 0x00,
    0x00, 0x33, 0x66, 0xcc, 0x66, 0x33, 0x00, 0x00,
    0x00, 0xcc, 0x66, 0x33, 0x66, 0xcc, 0x00, 0x00,
    0x22, 0x88, 0x22, 0x88, 0x22, 0x88, 0x22, 0x88,
    0x55, 0xaa, 0x55, 0xaa, 0x55, 0xaa, 0x55, 0xaa,
    0xdb, 0x77, 0xdb, 0xee, 0xdb, 0x77, 0xdb, 0xee,
    0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18,
    0x18, 0x18, 0x18, 0x18, 0xf8, 0x18, 0x18, 0x18,
    0x18, 0x18, 0xf8, 0x18, 0xf8, 0x18, 0x18, 0x18,
    0x36, 0x36, 0x36, 0x36, 0xf6, 0x36, 0x36, 0x36,
    0x00, 0x00, 0x00, 0x00, 0xfe, 0x36, 0x36, 0x36,
    0x00, 0x00, 0xf8, 0x18, 0xf8, 0x18, 0x18, 0x18,
    0x36, 0x36, 0xf6, 0x06, 0xf6, 0x36, 0x36, 0x36,
    0x36, 0x36, 0x36, 0x36, 0x36, 0x36, 0x36, 0x36,
    0x00, 0x00, 0xfe, 0x06, 0xf6, 0x36, 0x36, 0x36,
    0x36, 0x36, 0xf6, 0x06, 0xfe, 0x00, 0x00, 0x00,
    0x36, 0x36, 0x36, 0x36, 0xfe, 0x00, 0x00, 0x00,
    0x18, 0x18, 0xf8, 0x18, 0xf8, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0xf8, 0x18, 0x18, 0x18,
    0x18, 0x18, 0x18, 0x18, 0x1f, 0x00, 0x00, 0x00,
    0x18, 0x18, 0x18, 0x18, 0xff, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0xff, 0x18, 0x18, 0x18,
    0x18, 0x18, 0x18, 0x18, 0x1f, 0x18, 0x18, 0x18,
    0x00, 0x00, 0x00, 0x00, 0xff, 0x00, 0x00, 0x00,
    0x18, 0x18, 0x18, 0x18, 0xff, 0x18, 0x18, 0x18,
    0x18, 0x18, 0x1f, 0x18, 0x1f, 0x18, 0x18, 0x18,
    0x36, 0x36, 0x36, 0x36, 0x37, 0x36, 0x36, 0x36,
    0x36, 0x36, 0x37, 0x30, 0x3f, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x3f, 0x30, 0x37, 0x36, 0x36, 0x36,
    0x36, 0x36, 0xf7, 0x00, 0xff, 0x00, 0x00, 0x00,
    0x00, 0x00, 0xff, 0x00, 0xf7, 0x36, 0x36, 0x36,
    0x36, 0x36, 0x37, 0x30, 0x37, 0x36, 0x36, 0x36,
    0x00, 0x00, 0xff, 0x00, 0xff, 0x00, 0x00, 0x00,
    0x36, 0x36, 0xf7, 0x00, 0xf7, 0x36, 0x36, 0x36,
    0x18, 0x18, 0xff, 0x00, 0xff, 0x00, 0x00, 0x00,
    0x36, 0x36, 0x36, 0x36, 0xff, 0x00, 0x00, 0x00,
    0x00, 0x00, 0xff, 0x00, 0xff, 0x18, 0x18, 0x18,
    0x00, 0x00, 0x00, 0x00, 0xff, 0x36, 0x36, 0x36,
    0x36, 0x36, 0x36, 0x36, 0x3f, 0x00, 0x00, 0x00,
    0x18, 0x18, 0x1f, 0x18, 0x1f, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x1f, 0x18, 0x1f, 0x18, 0x18, 0x18,
    0x00, 0x00, 0x00, 0x00, 0x3f, 0x36, 0x36, 0x36,
    0x36, 0x36, 0x36, 0x36, 0xff, 0x36, 0x36, 0x36,
    0x18, 0x18, 0xff, 0x18, 0xff, 0x18, 0x18, 0x18,
    0x18, 0x18, 0x18, 0x18, 0xf8, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x1f, 0x18, 0x18, 0x18,
    0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
    0x00, 0x00, 0x00, 0x00, 0xff, 0xff, 0xff, 0xff,
    0xf0, 0xf0, 0xf0, 0xf0, 0xf0, 0xf0, 0xf0, 0xf0,
    0x0f, 0x0f, 0x0f, 0x0f, 0x0f, 0x0f, 0x0f, 0x0f,
    0xff, 0xff, 0xff, 0xff, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x76, 0xdc, 0xc8, 0xdc, 0x76, 0x00,
    0x00, 0x78, 0xcc, 0xf8, 0xcc, 0xf8, 0xc0, 0xc0,
    0x00, 0xfc, 0xcc, 0xc0, 0xc0, 0xc0, 0xc0, 0x00,
    0x00, 0xfe, 0x6c, 0x6c, 0x6c, 0x6c, 0x6c, 0x00,
    0xfc, 0xcc, 0x60, 0x30, 0x60, 0xcc, 0xfc, 0x00,
    0x00, 0x00, 0x7e, 0xd8, 0xd8, 0xd8, 0x70, 0x00,
    0x00, 0x66, 0x66, 0x66, 0x66, 0x7c, 0x60, 0xc0,
    0x00, 0x76, 0xdc, 0x18, 0x18, 0x18, 0x18, 0x00,
    0xfc, 0x30, 0x78, 0xcc, 0xcc, 0x78, 0x30, 0xfc,
    0x38, 0x6c, 0xc6, 0xfe, 0xc6, 0x6c, 0x38, 0x00,
    0x38, 0x6c, 0xc6, 0xc6, 0x6c, 0x6c, 0xee, 0x00,
    0x1c, 0x30, 0x18, 0x7c, 0xcc, 0xcc, 0x78, 0x00,
    0x00, 0x00, 0x7e, 0xdb, 0xdb, 0x7e, 0x00, 0x00,
    0x06, 0x0c, 0x7e, 0xdb, 0xdb, 0x7e, 0x60, 0xc0,
    0x38, 0x60, 0xc0, 0xf8, 0xc0, 0x60, 0x38, 0x00,
    0x78, 0xcc, 0xcc, 0xcc, 0xcc, 0xcc, 0xcc, 0x00,
    0x00, 0xfc, 0x00, 0xfc, 0x00, 0xfc, 0x00, 0x00,
    0x30, 0x30, 0xfc, 0x30, 0x30, 0x00, 0xfc, 0x00,
    0x60, 0x30, 0x18, 0x30, 0x60, 0x00, 0xfc, 0x00,
    0x18, 0x30, 0x60, 0x30, 0x18, 0x00, 0xfc, 0x00,
    0x0e, 0x1b, 0x1b, 0x18, 0x18, 0x18, 0x18, 0x18,
    0x18, 0x18, 0x18, 0x18, 0x18, 0xd8, 0xd8, 0x70,
    0x30, 0x30, 0x00, 0xfc, 0x00, 0x30, 0x30, 0x00,
    0x00, 0x76, 0xdc, 0x00, 0x76, 0xdc, 0x00, 0x00,
    0x38, 0x6c, 0x6c, 0x38, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x18, 0x18, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x18, 0x00, 0x00, 0x00,
    0x0f, 0x0c, 0x0c, 0x0c, 0xec, 0x6c, 0x3c, 0x1c,
    0x78, 0x6c, 0x6c, 0x6c, 0x6c, 0x00, 0x00, 0x00,
    0x70, 0x18, 0x30, 0x60, 0x78, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x3c, 0x3c, 0x3c, 0x3c, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    */

/*
        // First part of CP437
        0x7e, 0x81, 0xa5, 0x81, 0xbd, 0x99, 0x81, 0x7e, // U+263A
            0x7e, 0xff, 0xdb, 0xff, 0xc3, 0xe7, 0xff, 0x7e,
            0x6c, 0xfe, 0xfe, 0xfe, 0x7c, 0x38, 0x10, 0x00,
            0x10, 0x38, 0x7c, 0xfe, 0x7c, 0x38, 0x10, 0x00,
            0x38, 0x7c, 0x38, 0xfe, 0xfe, 0x7c, 0x38, 0x7c,
            0x10, 0x10, 0x38, 0x7c, 0xfe, 0x7c, 0x38, 0x7c,
            0x00, 0x00, 0x18, 0x3c, 0x3c, 0x18, 0x00, 0x00,
            0xff, 0xff, 0xe7, 0xc3, 0xc3, 0xe7, 0xff, 0xff,
            0x00, 0x3c, 0x66, 0x42, 0x42, 0x66, 0x3c, 0x00,
            0xff, 0xc3, 0x99, 0xbd, 0xbd, 0x99, 0xc3, 0xff,
            0x0f, 0x07, 0x0f, 0x7d, 0xcc, 0xcc, 0xcc, 0x78,
            0x3c, 0x66, 0x66, 0x66, 0x3c, 0x18, 0x7e, 0x18,
            0x3f, 0x33, 0x3f, 0x30, 0x30, 0x70, 0xf0, 0xe0,
            0x7f, 0x63, 0x7f, 0x63, 0x63, 0x67, 0xe6, 0xc0,
            0x99, 0x5a, 0x3c, 0xe7, 0xe7, 0x3c, 0x5a, 0x99,
            0x80, 0xe0, 0xf8, 0xfe, 0xf8, 0xe0, 0x80, 0x00,
            0x02, 0x0e, 0x3e, 0xfe, 0x3e, 0x0e, 0x02, 0x00,
            0x18, 0x3c, 0x7e, 0x18, 0x18, 0x7e, 0x3c, 0x18,
            0x66, 0x66, 0x66, 0x66, 0x66, 0x00, 0x66, 0x00,
            0x7f, 0xdb, 0xdb, 0x7b, 0x1b, 0x1b, 0x1b, 0x00,
            0x3e, 0x63, 0x38, 0x6c, 0x6c, 0x38, 0xcc, 0x78,
            0x00, 0x00, 0x00, 0x00, 0x7e, 0x7e, 0x7e, 0x00,
            0x18, 0x3c, 0x7e, 0x18, 0x7e, 0x3c, 0x18, 0xff,
            0x18, 0x3c, 0x7e, 0x18, 0x18, 0x18, 0x18, 0x00,
            0x18, 0x18, 0x18, 0x18, 0x7e, 0x3c, 0x18, 0x00,
            0x00, 0x18, 0x0c, 0xfe, 0x0c, 0x18, 0x00, 0x00,
            0x00, 0x30, 0x60, 0xfe, 0x60, 0x30, 0x00, 0x00,
            0x00, 0x00, 0xc0, 0xc0, 0xc0, 0xfe, 0x00, 0x00,
            0x00, 0x24, 0x66, 0xff, 0x66, 0x24, 0x00, 0x00,
            0x00, 0x18, 0x3c, 0x7e, 0xff, 0xff, 0x00, 0x00,
            0x00, 0xff, 0xff, 0x7e, 0x3c, 0x18, 0x00, 0x00,

            */


// CCL interpreter implementation
struct CCLInterpreter
{
public:
nothrow:
@nogc:
pure:

    void initialize(VCConsole* console)
    {
        this.console = console;
    }

    void interpret(const(char)[] s)
    {
        input = s;
        inputPos = 0;

        bool finished = false;
        bool termTextWasOutput = false;
        while(!finished)
        {
            final switch (_parserState)
            {
                case ParserState.initial:

                    Token token = getNextToken();
                    final switch(token.type)
                    {
                        case TokenType.tagOpen:
                            {
                                enterTag(token.text, token.inputPos);
                                break;
                            }

                        case TokenType.tagClose:
                            {
                                exitTag(token.text, token.inputPos);
                                break;
                            }

                        case TokenType.tagOpenClose:
                            {
                                enterTag(token.text, token.inputPos);
                                exitTag(token.text, token.inputPos);
                                break;
                            }

                        case TokenType.text:
                            {
                                console.print(token.text);
                                break;
                            }

                        case TokenType.endOfInput:
                            finished = true;
                            break;

                    }
                    break;
            }
        }

        // Is there any unclosed tags? Ignore.
    }

private:

    VCConsole* console;

    void setColor(int col, bool bg) nothrow @nogc
    {
        if (bg) 
            console.bg(col);
        else 
            console.fg(col);
    }

    void setStyle(VCStyle s) pure
    {
        console.style(s);
    }

    void enterTag(const(char)[] tagName, int inputPos)
    {
        // dup top of stack, set foreground color
        console.save();

        VCStyle currentStyle = console.current.style;

        switch(tagName)
        {
            case "b":
            case "strong":
                setStyle(currentStyle | VCbold);
                break;

            case "blink":
                setStyle(currentStyle | VCblink);
                break;

            case "u":
                setStyle(currentStyle | VCunderline);
                break;

            case "shiny":
                setStyle(currentStyle | VCshiny);
                break;

            default:
                {
                    bool bg = false;
                    if ((tagName.length >= 3) && (tagName[0..3] == "on_"))
                    {
                        tagName = tagName[3..$];
                        bg = true;
                    }       

                    switch(tagName)
                    {
                        case "black":    setColor( 0, bg); break;
                        case "red":      setColor( 1, bg); break;
                        case "green":    setColor( 2, bg); break;
                        case "orange":   setColor( 3, bg); break;
                        case "blue":     setColor( 4, bg); break;
                        case "magenta":  setColor( 5, bg); break;
                        case "cyan":     setColor( 6, bg); break;
                        case "lgrey":    setColor( 7, bg); break;
                        case "grey":     setColor( 8, bg); break;
                        case "lred":     setColor( 9, bg); break;
                        case "lgreen":   setColor(10, bg); break;
                        case "yellow":   setColor(11, bg); break;
                        case "lblue":    setColor(12, bg); break;
                        case "lmagenta": setColor(13, bg); break;
                        case "lcyan":    setColor(14, bg); break;
                        case "white":    setColor(15, bg); break;
                        default:
                            break; // unknown tag
                    }
                }
        }
    }

    void exitTag(const(char)[] tagName, int inputPos)
    {
        if (tagName != "" && console.current.lastAppliedTag != tagName)
        {
            // ignore the error of mismatched name in closing tags (sorry)
        }

        // restore, but keep cursor position²
        int savedCol = console.current.ccol;
        int savedRow = console.current.crow;
        console.restore();
        console.current.ccol = savedCol;
        console.current.crow = savedRow;
    }

    // <parser>

    ParserState _parserState = ParserState.initial;
    enum ParserState
    {
        initial
    }

    // </parser>

    // <lexer>

    const(char)[] input;
    int inputPos;

    LexerState _lexerState = LexerState.initial;
    enum LexerState
    {
        initial,
        insideEntity,
        insideTag,
    }

    enum TokenType
    {
        tagOpen,      // <red>
        tagClose,     // </red>
        tagOpenClose, // <red/> 
        text,
        endOfInput
    }

    static struct Token
    {
        TokenType type;

        // name of tag, or text
        const(char)[] text = null; 

        // position in input text
        int inputPos = 0;
    }

    bool hasNextChar()
    {
        return inputPos < input.length;
    }

    char peek()
    {
        return input[inputPos];
    }

    const(char)[] lastNChars(int n)
    {
        return input[inputPos - n .. inputPos];
    }

    const(char)[] charsSincePos(int pos)
    {
        return input[pos .. inputPos];
    }

    void next()
    {
        inputPos += 1;
        assert(inputPos <= input.length);
    }

    Token getNextToken()
    {
        Token r;
        r.inputPos = inputPos;

        if (!hasNextChar())
        {
            r.type = TokenType.endOfInput;
            return r;
        }
        else if (peek() == '<')
        {
            int posOfLt = inputPos;

            // it is a tag
            bool closeTag = false;
            next;
            if (!hasNextChar())
            {
                // input terminate on "<", return end of input instead of error
                r.type = TokenType.endOfInput;
                return r;
            }

            char ch2 = peek();
            if (peek() == '/')
            {
                closeTag = true;
                next;
                if (!hasNextChar())
                {
                    // input terminate on "</", return end of input instead of error
                    r.type = TokenType.endOfInput;
                    return r;
                }
            }

            const(char)[] tagName;
            int startOfTagName = inputPos;

            while(hasNextChar())
            {
                char ch = peek();
                if (ch == '/')
                {
                    tagName = charsSincePos(startOfTagName);
                    if (closeTag)
                    {
                        // tag is malformed such as: </lol/>
                        // ignore the whole tag
                        r.type = TokenType.endOfInput;
                        return r;
                    }

                    next;
                    if (!hasNextChar())
                    {
                        // tag is malformed such as: <like-that/ 
                        // ignore the whole tag
                        r.type = TokenType.endOfInput;
                        return r;
                    }

                    if (peek() == '>')
                    {
                        next;
                        r.type = TokenType.tagOpenClose;
                        r.text = tagName;
                        return r;
                    }
                    else
                    {
                        // last > is missing, do it anyway
                        // <lol/   => <lol/>
                        r.type = TokenType.tagOpenClose;
                        r.text = tagName;
                        return r;
                    }
                }
                else if (ch == '>')
                {
                    tagName = charsSincePos(startOfTagName);
                    next;
                    r.type = closeTag ? TokenType.tagClose : TokenType.tagOpen;
                    r.text = tagName;
                    return r;
                }
                else
                {
                    // Note: ignore invalid character in tag names
                    next;
                }
            }
            if (closeTag)
            {
                // ignore unterminated tag
            }
            else
            {
                // ignore unterminated tag
            }

            // there was an error, terminate input
            {
                // input terminate on "<", return end of input instead of error
                r.type = TokenType.endOfInput;
                return r;
            }
        }
        else if (peek() == '&')
        {
            // it is an HTML entity
            next;
            if (!hasNextChar())
            {
                // no error for no entity name
            }

            int startOfEntity = inputPos;
            while(hasNextChar())
            {
                char ch = peek();
                if (ch == ';')
                {
                    const(char)[] entityName = charsSincePos(startOfEntity);
                    switch (entityName)
                    {
                        case "lt": r.text = "<"; break;
                        case "gt": r.text = ">"; break;
                        case "amp": r.text = "&"; break;
                        default: 
                            // unknown entity, ignore
                            goto nothing;
                    }
                    next;
                    r.type = TokenType.text;
                    return r;
                }
                else if ((ch >= 'a' && ch <= 'z') || (ch >= 'a' && ch <= 'z'))
                {
                    next;
                }
                else
                {
                    // illegal character in entity
                    goto nothing;
                }
            }

            nothing:

            // do nothing, ignore an unrecognized entity or empty one, but terminate input
            {
                // input terminate on "<", return end of input instead of error
                r.type = TokenType.endOfInput;
                return r;
            }
            
        }
        else 
        {
            int startOfText = inputPos;
            while(hasNextChar())
            {
                char ch = peek();

                // Note: > accepted here without escaping.
                    
                if (ch == '<') 
                    break;
                if (ch == '&') 
                    break;
                next;
            }
            assert(inputPos != startOfText);
            r.type = TokenType.text;
            r.text = charsSincePos(startOfText);
            return r;
        }
    }
}


// Make 1D separable gaussian kernel
void makeGaussianKernel(int len, 
                        float sigma, 
                        float mu, 
                        float[] outtaps)
{
    assert( (len % 2) == 1);
    assert(len <= outtaps.length);

    int taps = len/2;

    double last_int = def_int_gaussian(-taps, mu, sigma);
    double sum = 0;
    for (int x = -taps; x <= taps; ++x)
    {
        double new_int = def_int_gaussian(x + 1, mu, sigma);
        double c = new_int - last_int;

        last_int = new_int;

        outtaps[x + taps] = c;
        sum += c;
    }

    // DC-normalize
    for (int x = 0; x < len; ++x)
    {
        outtaps[x] /= sum;
    }
}

double erf(double x) pure
{
    // constants
    double a1 = 0.254829592;
    double a2 = -0.284496736;
    double a3 = 1.421413741;
    double a4 = -1.453152027;
    double a5 = 1.061405429;
    double p = 0.3275911;
    // A&S formula 7.1.26
    double t = 1.0 / (1.0 + p * abs(x));
    double y = 1.0 - (((((a5 * t + a4) * t) + a3) * t + a2) * t + a1) * t * exp(-x * x);
    return (x >= 0 ? 1 : -1) * y;
}

double def_int_gaussian(double x, double mu, double sigma) pure
{
    return 0.5 * erf((x - mu) / (1.41421356237 * sigma));
}