module textmode;

nothrow @nogc @safe:

import core.memory;
import core.stdc.stdlib: realloc, free;

import std.utf: byDchar;
import std.math: abs, exp, sqrt;

import inteli.smmintrin;

nothrow:
@nogc:
@safe:

/// A text mode palette index.
alias TM_Color = int;

/// Helpers for text mode colors.
enum : TM_Color
{
    TM_black    = 0, ///
    TM_red      = 1, ///
    TM_green    = 2, ///
    TM_orange   = 3, ///
    TM_blue     = 4, ///
    TM_magenta  = 5, ///
    TM_cyan     = 6, ///
    TM_lgrey    = 7, ///
    TM_grey     = 8, ///
    TM_lred     = 9, ///
    TM_lgreen   = 10, ///
    TM_yellow   = 11, ///
    TM_lblue    = 12, ///
    TM_lmagenta = 13, ///
    TM_lcyan    = 14, ///
    TM_white    = 15 ///
}

/** 
    An individual cell of text-mode buffer.

    Either you access it or use the `print` functions.

    The first four bytes are a Unicode codepoint, conflated with a 
    grapheme and font "glyph". There is only one font, and it's 8x8. 
    Not all codepoints exist in that font.

    The next 4-bit are foreground color in a 16 color palette.
    The next 4-bit are background color in a 16 color palette.
    Each glyph is rendered fully opaque, in those two colors.
*/
static struct TM_CharData
{
nothrow:
@nogc:
@safe:

    /// Unicode codepoint to represent. This library doesn't 
    /// compose codepoints.
    dchar glyph     = 32;

    /// Low nibble = foreground color (0 to 15)
    /// High nibble = background color (0 to 15)
    ubyte color     = (TM_black << 4) + TM_grey;  

    /// Style of that character, a combination of TM_Style flags.
    TM_Style style; 
}

/** 
    Character styles.
 */
alias TM_Style = ubyte;

enum : TM_Style
{
    TM_none      = 0, /// no style
    TM_shiny     = 1, /// <shiny>, emissive light
    TM_bold      = 2, /// <b> or <strong>, pixels are 2x1
    TM_underline = 4, /// <u>, lowest row is filled
    TM_blink     = 8, /// <blink>, need to call console.update(dt)
}

/**
    Predefined palettes (default: vintage is loaded).
    You can either load a predefined palette, or change colors 
    individually.
 */
enum TM_Palette
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
struct TM_Rect
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
/// There is only one font, our goal it provide a Unicode 8x8 
/// font suitable for most languages, so others were removed. 
/// A text mode with `dchar` as input.
enum TM_Font
{
    // 8x8 fonts
    pcega, /// A font dumped from BIOS around 2003, then extended.
}

/// How to blend on output buffer?
enum TM_BlendMode
{
    /// Blend console content to output, using alpha.
    sourceOver,

    /// Copy console content to output.
    copy,
}

/// How to align vertically the console in output buffer.
/// Default: center.
enum TM_HorzAlign
{
    left,   ///
    center, ///
    right   ///
}

/// How to align vertically the console in output buffer.
/// Default: middle.
enum TM_VertAlign
{
    top,    ///
    middle, ///
    bottom  ///
}

/// Various options to change behaviour of the library.
struct TM_Options
{
    TM_BlendMode blendMode = TM_BlendMode.sourceOver; ///
    TM_HorzAlign halign    = TM_HorzAlign.center; ///
    TM_VertAlign valign    = TM_VertAlign.middle; ///

    /// The output buffer is considered unchanged between calls.
    /// It is considered our changes are still there and not erased,
    /// unless the size of the buffer has changed, or its location.
    /// In this case we can draw less.
    bool allowOutCaching   = false;

    /// Palette color of the borderColor;
    ubyte borderColor      = 0;

    /// Is the border color itself <shiny>?
    bool borderShiny       = false;

    /// The <blink> time in milliseconds.
    double blinkTime = 1200;


    // <blur>

    /// Quantity of blur added by TM_shiny / <shiny>
    /// (1.0f means default).
    float blurAmount       = 1.0f;

    /// Kernel size in multiple of default value.
    /// This changes the blur filter width (1.0f means default).
    float blurScale        = 1.0f;

    /// Whether foreground/background color contributes to blur.    
    bool blurForeground    = true;
    bool blurBackground    = true; ///ditto

    /// Luminance blue noise texture, applied to blur effect.
    bool noiseTexture      = true;

    /// Quantity of that texture (1.0f means default).
    float noiseAmount      = 1.0f;

    // </blur>


    // <tonemapping>

    /// Enable or disable tonemapping.
    bool tonemapping       = false;

    /// Channels that exceed 1.0f, bleed that much in other channels.
    float tonemappingRatio = 0.3f;

    // </tonemapping>
}


/** 
    Main API of the text-mode library.


    3 mandatory calls:

        TM_Console console;
        console.size(columns, rows);
        console.outbuf(buf.ptr, buf.w, buf.h, buf.pitchBytes);
        console.render();

    All calls can be mixed and match without any ordering, except
    that a call to 
     the sequence:
        getUpdateRect
        TM_Rect dirty = console.

    Note: None of the `TM_Console` functions are thread-safe. Either
          call them single-threaded, or synchronize externally.
          None of them can be called concurrently, unless it's 
          different `TM_Console` objects.
*/
struct TM_Console
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
        (MANDATORY)
        Set/get size of text buffer.
        Warning: this clears the screen like calling `cls`.

        See_also: outbuf
     */
    void size(int columns, int rows)
    {
        updateTextBufferSize(columns, rows);
        updateBackBufferSize();
        cls();
    }
    ///ditto
    int[2] size() pure const
    {
        return [_columns, _rows];
    }

    /**
        Given selected font and size of console screen, give a 
        suggested output buffer size (in pixels).
        However, this library will manage to render in whatever 
        buffer size you give, so this is completely optional.
    */
    int suggestedWidth()
    {
        return _columns * charWidth();
    }
    ///ditto
    int suggestedHeight()
    {
        return _rows    * charHeight();
    }

    /**
        Get number of text columns.
     */
    int columns() pure const { return _columns; }

    /**
        Get number of text rows.
     */
    int rows()    pure const { return _columns; }



    // ███████╗████████╗██╗   ██╗██╗     ███████╗
    // ██╔════╝╚══██╔══╝╚██╗ ██╔╝██║     ██╔════╝
    // ███████╗   ██║    ╚████╔╝ ██║     █████╗
    // ╚════██║   ██║     ╚██╔╝  ██║     ██╔══╝
    // ███████║   ██║      ██║   ███████╗███████╗

    /**
        Set current foreground color.
     */
    void fg(TM_Color fg) pure
    {
        assert(fg >= 0 && fg < 16);
        current.fg = cast(ubyte)fg;
    }

    /**
        Set current background color.
     */
    void bg(TM_Color bg) pure
    {
        assert(bg >= 0 && bg < 16);
        current.bg = cast(ubyte)bg;
    }

    /**
        Set current character attributes aka style.
     */
    void style(TM_Style s) pure
    {
        current.style = s;
    }

    /** 
        Save/restore state, that includes:
        - foreground color
        - background color
        - cursor position
        - character style

        Note: This won't report stack errors.
              You MUST pair your save/restore calls, or endure 
              eventual display bugs.
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
    void font(TM_Font font)
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
    TM_Font font() pure const
    { 
        return _font; 
    }

    /**
        Get width/height of a character in selected font.
        Normally you don't need this since the actual size in output
        buffer is different.
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
    void palette(TM_Palette palette)
    {
        for (int entry = 0; entry < 16; ++entry)
        {
            uint col = PALETTE_DATA[palette][entry];
            ubyte r = 0xff & (col >>> 24);
            ubyte g = 0xff & (col >>> 16);
            ubyte b = 0xff & (col >>> 8);
            ubyte a = 0xff & col;
            setPaletteEntry(entry, r, g, b, a);
        }
    }

    /**
        Set/get palette entries.

        Params: entry Palette index, must be 0 <= entry <= 15
                r Red value, 0 to 255
                g Green value, 0 to 255
                b Blue value, 0 to 255
                a Alpha value, 0 to 255. 

        When used as background color, alpha is considered 255.
     */
    void setPaletteEntry(int entry, 
                         ubyte r, ubyte g, ubyte b, ubyte a) pure
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
        r = _palette[entry].r;
        g = _palette[entry].g;
        b = _palette[entry].b;
        a = _palette[entry].a;
    }


    /** 
        Set other options.
        Those control important rendering options, and changing those
        tend to redraw the whole buffer.
     */
    void options(TM_Options options)
    {
        if (_options.blendMode != options.blendMode)
            _dirtyOut = true;

        // A few of those are overreacting.
        // for example, changing blur amount or tonemapping
        // may not redo the blur convolution.
        if (_options.halign != options.halign
         || _options.valign != options.valign
         || _options.borderColor != options.borderColor
         || _options.borderShiny != options.borderShiny
         || _options.blurAmount != options.blurAmount
         || _options.blurScale != options.blurScale
         || _options.blurForeground != options.blurForeground
         || _options.blurBackground != options.blurBackground
         || _options.tonemapping != options.tonemapping
         || _options.tonemappingRatio != options.tonemappingRatio
         || _options.noiseTexture != options.noiseTexture
         || _options.noiseAmount != options.noiseAmount)
        {
            _dirtyPost = true;
            _dirtyOut = true;
        }
        _options = options;
    }


    /// ████████╗███████╗██╗  ██╗████████╗
    /// ╚══██╔══╝██╔════╝╚██╗██╔╝╚══██╔══╝
    ///    ██║   █████╗   ╚███╔╝    ██║   
    ///    ██║   ██╔══╝   ██╔██╗    ██║   
    ///    ██║   ███████╗██╔╝ ██╗   ██║   
    ///    ╚═╝   ╚══════╝╚═╝  ╚═╝   ╚═╝


    /**
        Access character buffer directly.
        Returns: One single character data.
     */
    ref TM_CharData charAt(int col, int row) pure return
    {
        return _text[col + row * _columns];
    }

    /**
        Access character buffer directly.
        Returns: Consecutive character data, columns x rows items.
                 Characters are stored in row-major order.
     */
    TM_CharData[] characters() pure return
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
            TM_CharData* cdata = &_text[col + row * _columns];
            cdata.glyph = ch;
            cdata.color = ( current.fg & 0x0f      ) 
                        | ((current.bg & 0x0f) << 4);
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
                charAt(col, _rows-1) = TM_CharData.init;
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
        _text[] = TM_CharData.init;
        current = State.init;
        _dirtyValidation = true;
    }
    ///ditto
    alias clearScreen = cls;

    /** 
        Change text cursor position. -1 indicate "keep".
        Do nothing for each dimension separately, if position is out
        of bounds.
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
        Print text to console at current cursor position, encoded in
        the CCL language (same as in console-colors DUB package).
        Text input MUST be UTF-8.

        Accepted tags:
        - <COLORNAME> such as:
          <black> <red>      <green>   <orange>
          <blue>  <magenta>  <cyan>    <lgrey> 
          <grey>  <lred>     <lgreen>  <yellow>
          <lblue> <lmagenta> <lcyan>   <white>

        each corresponding to color 0 to 15 in the palette.

        Unknown tags have no effect and are removed.
        Tags CAN'T have attributes.
        Here, CCL is modified (vs console-colors) to be ALWAYS VALID.

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

    // ██████╗ ███████╗███╗   ██╗██████╗ ███████╗██████╗
    // ██╔══██╗██╔════╝████╗  ██║██╔══██╗██╔════╝██╔══██╗
    // ██████╔╝█████╗  ██╔██╗ ██║██║  ██║█████╗  ██████╔╝
    // ██╔══██╗██╔══╝  ██║╚██╗██║██║  ██║██╔══╝  ██╔══██╗
    // ██║  ██║███████╗██║ ╚████║██████╔╝███████╗██║  ██║
    // ╚═╝  ╚═╝╚══════╝╚═╝  ╚═══╝╚═════╝ ╚══════╝╚═╝  ╚═╝

    /**
        (MANDATORY)

        Setup output buffer.
        Mandatory call, before being able to call `render`.

        Given buffer must be an image of sRGB 8-bit RGBA quadruplets.

        Params:
             pixels    Start of output buffer.
    */
    void outbuf(void*     pixels, 
                int       width, 
                int       height, 
                ptrdiff_t pitchBytes)
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
            updatePostBuffersSize(width, height);
        }
    }

    /**
        (MANDATORY, well if you want some output)

        Render console to output buffer. After this call, the output
        buffer is up-to-date with the changes in text buffer content.

        Depending on the options, only the rectangle in 
        `getUpdateRect()` will get updated.
    */
    void render() 
        @system // memory-safe if `outbuf()` called and memory-safe
    {
        // 0. Invalidate characters that need redraw in _back buffer.
        // After that, _charDirty tells if a character need redraw.
        TM_Rect textRect = invalidateChars();

        // 1. Draw chars in original size, only those who changed.
        drawAllChars(textRect);

        // from now on, consider _text and _back is up-to-date.
        // this information of recency is still in textRect and 
        // _charDirty.
        _dirtyAllChars = false;
        _cache[] = _text[];

        // Recompute placement of text in post buffer.
        recomputeLayout();

        // 2. Apply scale, character margins, etc.
        // Take characters in _back and put them in _post, into the 
        // final resolution.
        // This only needs done for _charDirty chars.
        // Borders are drawn if _dirtyPost is true.
        // _dirtyPost get cleared after that.
        // Return rectangle that changed
        TM_Rect postRect = backToPost(textRect);

        // Dirty border color can affect out and post buffers redraw
        _paletteDirty[] = false;

        // 3. Effect go here. Blur, screen simulation, etc.
        //    So, effect are applied in final resolution size.
        applyEffects(postRect);

        // 4. Blend into out buffer.
        postToOut(textRect);
    }

    /**
        Make time progress, so that <blink> does blink.
        Give it your frame's delta time, in seconds.
    */
    void update(double deltaTimeSeconds)
    {
        double blinkTimeSecs = _options.blinkTime * 0.001;

        // prevent large pause making screen updates
        // since it means we already struggle
        if (deltaTimeSeconds > blinkTimeSecs)
            deltaTimeSeconds = blinkTimeSecs;

        double time = _elapsedTime;
        time += deltaTimeSeconds;
        _blinkOn = time < blinkTimeSecs * 0.5;
        if (_cachedBlinkOn != _blinkOn)
            _dirtyValidation = true;
        time = time % blinkTimeSecs;
        if (time < 0) 
            time = 0;
        _elapsedTime = time;
    }
 
    // <dirty rectangles> 

    /**
        Return if there is pending updates to draw.
        
        This answer is only valid until the next `render()` call.
        Also invalidated if you print, change style, palette, or
        options, etc.
     */
    bool hasPendingUpdate()
    {
        TM_Rect r = getUpdateRect();
        return (r.x2 - r.x1) != 0 && (r.y2 - r.y1) != 0;
    }

    /**
        Returns the outbuf rectangle which is going to be updated
        when `render()` is called.

        This is expressed in output buffer coordinates.

        This answer is only valid until the next `render()` call.
        Also invalidated if you print, change style, palette, or
        options, etc.

        Note: In case of nothing to redraw, it's width and height 
              will be zero. Better use `hasPendingUpdate()`.
    */
    TM_Rect getUpdateRect()
    {
        if (_dirtyOut || (!_options.allowOutCaching) )
        {
            return TM_Rect(0, 0, _outW, _outH);
        }

        TM_Rect textRect = invalidateChars();

        if (textRect.isEmpty)
            return TM_Rect(0, 0, 0, 0);

        recomputeLayout();

        TM_Rect r = transformRectToOutputCoord(textRect);
        if (r.isEmpty)
            return r;

        // extend it to account for blur
        return extendByFilterWidth(r);
    }


    /** 
        Convert pixel position to character position.
        Which character location is at pixel x,y ?

        Returns: `true` if a character is pointed at, else `false`.
                 If no hit, `*col` and `*row` are left unchanged.
    */
    bool hit(int x, int y, int* column, int* row)
    {
        // No layout yet
        if (_outScaleX == -1 || _outScaleY == -1)
            return false;

        int dx = (x - _outMarginLeft);
        int dy = (y - _outMarginTop);
        if (dx < 0 || dy < 0)
            return false;
        int cw = charWidth() * _outScaleX;
        int ch = charHeight() * _outScaleY;
        assert(_outScaleX > 0);
        assert(_outScaleY > 0);
        assert(cw >= 0);
        assert(ch >= 0);
        dx = dx / cw;
        dy = (dy + ch - 1) / ch;
        assert(dx >= 0 && dy >= 0);
        if (dx < 0 || dy < 0 || dx >= _columns || dy >= rows)
            return false;
        *column = dx;
        *row    = dy;
        return true;
    }
    ///ditto
    bool hit(double x, double y, int* column, int* row)
    {
        return hit(cast(int)x, cast(int)y, column, row);
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
    TM_Font _font = TM_Font.pcega;
    int _columns  = -1;
    int _rows     = -1;

    TM_Options _options = TM_Options.init;

    TM_CharData[] _text  = null; // text buffer
    TM_CharData[] _cache = null; // same but cached
    bool[] _charDirty = null; // true if char need redraw in _back

    double _elapsedTime = 0; // Time elapsed, to compute blink
    bool _blinkOn; // Is <blink> text visible at this point in time?
    bool _cachedBlinkOn;

    // Palette
    rgba_t[16] _palette = 
    [
        rgba_t(  0,   0,   0,   0), rgba_t(128,   0,   0, 255),
        rgba_t(  0, 128,   0, 255), rgba_t(128, 128,   0, 255),
        rgba_t(  0,   0, 128, 255), rgba_t(128,   0, 128, 255),
        rgba_t(  0, 128, 128, 255), rgba_t(192, 192, 192, 255),
        rgba_t(128, 128, 128, 255), rgba_t(255,   0,   0, 255),
        rgba_t(  0, 255,   0, 255), rgba_t(255, 255,   0, 255),
        rgba_t(  0,   0, 255, 255), rgba_t(255,   0, 255, 255),
        rgba_t(  0, 255, 255, 255), rgba_t(255, 255, 255, 255),
    ];

    bool _dirtyAllChars   = true; // all chars need redraw
    bool _dirtyValidation = true; // if _charDirty already computed
    bool _dirtyPost       = true;
    bool _dirtyOut        = true;

    bool[16] _paletteDirty; // true if this color changed
    TM_Rect  _lastBounds;   // last computed dirty rectangle

    // Size of bitmap backing buffer.
    // In _back and _backFlags buffer, every character is rendered 
    // next to each other without gaps.
    int _backWidth  = -1;
    int _backHeight = -1;
    rgba_t[] _back  = null;
    ubyte[] _backFlags = null;
    enum : ubyte
    {
        BACK_IS_FG = 1, // fg when present, bg else
    }

    // A buffer for effects, same size as outbuf (including borders)
    // In _post/_blur/_emit/_emitH buffers, scale is applied and also 
    // borders.
    int _postWidth  = -1;
    int _postHeight = -1;
    rgba_t[] _post  = null; 

    rgba_t[] _blur  = null; // a buffer that is a copy of _post, with 
                            // blur applied

    // if true, whole blur must be redone
    bool _dirtyBlur = false;
    int _filterWidth; // filter width of gaussian blur, in pixels
    float[MAX_FILTER_WIDTH] _blurKernel;
    enum MAX_FILTER_WIDTH = 63; // presumably this is slow beyond that

    // Note: those two buffers are fake-linear, premul alpha, u16
    rgba16_t[] _emit  = null; // emissive color
    rgba16_t[] _emitH = null; // same, but horz-blurred, transposed

    static struct State
    {
        ubyte bg       = 0;
        ubyte fg       = 8;
        int ccol       = 0; // cursor col  (X position)
        int crow       = 0; // cursor row (Y position)
        TM_Style style = 0;

        // for the CCL interpreter
        int inputPos   = 0; // pos of opening tag in input chars
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
        int charW = charWidth();
        int charH = charHeight();

        // Find scale to multiply size of character by whole amount.
        // eg: scale == 2 => each font pixel becomes 2x2 pixel block.
        int scaleX = _outW / (_columns * charW);
        if (scaleX < 1) 
            scaleX = 1;
        int scaleY = _outH / (_rows    * charH);
        if (scaleY < 1) 
            scaleY = 1;
        int scale = (scaleX < scaleY) ? scaleX : scaleY;

        // Compute remainder pixels in outbuf
        int remX = _outW - (_columns * charW) * scale;
        int remY = _outH - (_rows    * charH) * scale;
        assert(remX <= _outW && remY <= _outH);
        if (remX < 0) 
            remX = 0;
        if (remY < 0) 
            remY = 0;

        int marginLeft;
        int marginTop;
        final switch(_options.halign) with (TM_HorzAlign)
        {
            case left:    marginLeft = 0;      break;
            case center:  marginLeft = remX/2; break;
            case right:   marginLeft = remX;   break;
        }

        final switch(_options.valign) with (TM_VertAlign)
        {
            case top:     marginTop  = 0;      break;
            case middle:  marginTop  = remY/2; break;
            case bottom:  marginTop  = remY;   break;
        }

        int charMarginX = 0; // not implemented
        int charMarginY = 0; // not implemented

        if (   _outMarginLeft != marginLeft
            || _outMarginTop  != marginTop
            || _charMarginX   != charMarginX
            || _charMarginY   != charMarginY 
            || _outScaleX     != scale
            || _outScaleY     != scale)
        {
            _dirtyOut      = true;
            _dirtyPost     = true;
            _outMarginLeft = marginLeft;
            _outMarginTop  = marginTop;
            _charMarginX   = charMarginX;
            _charMarginY   = charMarginY;
            _outScaleX     = scale;
            _outScaleY     = scale;

            float filterSize = charW * scale 
                            * _options.blurScale * 2.5f;
            updateFilterSize( cast(int)(0.5f + filterSize) ); 
        }
    }

    // r is in text console coordinates
    // transform it in pixel coordinates
    TM_Rect transformRectToOutputCoord(TM_Rect r)
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

        // Need to clamp, coords may be out of buffer if said buffer is small
        if (r.x1 > _outW) r.x1 = _outW;
        if (r.x2 > _outW) r.x2 = _outW;
        if (r.y1 > _outH) r.y1 = _outH;
        if (r.y2 > _outH) r.y2 = _outH;
        return r;
    }

    // extend rect in output coordinates, by filter radius

    TM_Rect extendByFilterWidth(TM_Rect r)
    {
        int filter_2 = _filterWidth / 2;
        r.x1 -= filter_2;
        r.x2 += filter_2;
        r.y1 -= filter_2;
        r.y2 += filter_2;
        if (r.x1 <     0) r.x1 = 0;
        if (r.y1 <     0) r.y1 = 0;
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
            size_t bytes = cells * TM_CharData.sizeof;
            void* alloc = realloc_c17(_text.ptr, bytes * 2);
            _text  = (cast(TM_CharData*)alloc)[    0..  cells];
            _cache = (cast(TM_CharData*)alloc)[cells..2*cells];

            alloc = realloc_c17(_charDirty.ptr, cells * bool.sizeof);
            _charDirty = (cast(bool*)alloc)[0..cells];            
            _columns = columns;
            _rows    = rows;
            _dirtyAllChars = true;
        }
    }

    void updateBackBufferSize() @trusted
    {
        int width  = columns * charWidth();
        int height = rows    * charHeight();
        if (width != _backWidth || height != _backHeight)
        {
            _dirtyAllChars = true;
            size_t pixels = width * height;
            void* p = realloc_c17(_back.ptr, pixels * 5);
            _back      = (cast(rgba_t*)p)[0..pixels];
            _backFlags = (cast(ubyte*) p)[pixels*4..pixels*5];
            _backHeight = height;
            _backWidth = width;
        }
    }

    void updatePostBuffersSize(int width, int height) @trusted
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
            double sigma = (filterSize - 1) / 8.0;
            double mu = 0.0;
            makeGaussianKernel(filterSize, sigma, mu, _blurKernel[]);
            _dirtyBlur = true;
        }
    }

    // Reasons to redraw: 
    //  - their fg or bg color changed
    //  - their fg or bg color PALETTE changed
    //  - glyph displayed changed
    //  - character is <blink> and time passed
    //  - font changed
    //  - size changed
    //
    // Returns: A rectangle that needs to change, in text coordinates.
    TM_Rect invalidateChars()
    {
        // validation results might not need to be recomputed
        if (!_dirtyValidation)
            return _lastBounds;

        _dirtyValidation = false;

        TM_Rect bounds;
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
                    TM_CharData text  =  _text[icell];
                    TM_CharData cache =  _cache[icell];
                    bool blink = (text.style & TM_shiny) != 0;
                    bool redraw = false;
                    if (text != cache)
                        redraw = true; // chardata changed
                    else if (_paletteDirty[text.color & 0x0f])
                        redraw = true; // fg color changed
                    else if (_paletteDirty[text.color >>> 4])
                        redraw = true; // bg color changed
                    else if (blink && (_cachedBlinkOn != _blinkOn))
                        redraw = true; // text blinked on or off
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
                bounds = TM_Rect(0, 0, 0, 0);
            }
        }
        _lastBounds = bounds;
        _cachedBlinkOn = _blinkOn;
        return bounds;
    }

    // Draw all chars from _text to _back, no caching yet
    void drawAllChars(TM_Rect textRect)
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

    // Draw from _back/_backFlags to _post/_emit
    // Returns changed rect, in pixels
    TM_Rect backToPost(TM_Rect textRect) @trusted
    {
        bool drawBorder = false;

        TM_Rect postRect = transformRectToPostCoord(textRect);

        if (_dirtyPost)
        {
            drawBorder = true;
        }
        if (_paletteDirty[_options.borderColor])
            drawBorder = true;

        if (drawBorder)
        {
            rgba_t border = _palette[_options.borderColor];

            // PERF: only draw the border areas
            _post[] = border;

            // now also fill _emit, and since border is never <shiny>
            if (_options.borderShiny)
                _emit[] = linearU16Premul(border);
            else
                _emit[] = rgba16_t(0, 0, 0, 0);

            postRect = TM_Rect(0, 0, _postWidth, _postHeight);
            textRect = TM_Rect(0, 0, _columns, _rows);
        }

        // Which chars to copy, with scale and margins applied?
        for (int row = textRect.y1; row < textRect.y2; ++row)
        {
            for (int col = textRect.x1; col < textRect.x2; ++col)
            {
                int charIndex = col + _columns * row;
                if ( ! ( _charDirty[charIndex] || _dirtyPost) )
                    continue; // char didn't change

                bool shiny = (_text[charIndex].style & TM_shiny) != 0;
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
            const(ubyte)* backFlags = &_backFlags[backPitch * y]; 

            for (int x = col*cw; x < (col+1)*cw; ++x)
            {
                rgba_t fg   = backScan[x];
                ubyte flags = backFlags[x];
                bool isFg = (flags & BACK_IS_FG) != 0;
                bool emitLight =
                    shiny && ( ( isFg && _options.blurForeground)
                            || (!isFg && _options.blurBackground) );

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
                        int outX = x * _outScaleX 
                                 + xx + _outMarginLeft;
                        if (outX >= _outW)
                            continue;

                        // copy pixel from _back buffer to _post
                        postScan[outX] = fg;

                        // but also write its emissiveness
                        emitScan[outX] = rgba16_t(0, 0, 0, 0);
                        if (emitLight)
                        {
                            emitScan[outX] = linearU16Premul(fg);

                        }
                    }
                }
            }
        }
    }

    // Draw from _post to _out
    void postToOut(TM_Rect textRect) @trusted
    {
        TM_Rect changeRect = transformRectToOutputCoord(textRect);

        // Extend it to account for blur
        changeRect = extendByFilterWidth(changeRect);

        if ( (!_options.allowOutCaching) || _dirtyOut)
        {
            // No caching-case, redraw everything we now from _post.
            // The buffer content wasn't preserved, so we do it again.
            changeRect = TM_Rect(0, 0, _outW, _outH); 
        }

        for (int y = changeRect.y1; y < changeRect.y2; ++y)
        {
            const(rgba_t)* postScan = &_blur[_postWidth * y];
            rgba_t*         outScan = cast(rgba_t*)(_outPixels 
                                                     + _outPitch * y);

            for (int x = changeRect.x1; x < changeRect.x2; ++x)
            {
                // Read one pixel, make potentially several in output
                // with nearest resampling
                rgba_t fg = postScan[x];
                final switch (_options.blendMode) with (TM_BlendMode)
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
        TM_CharData cdata = charAt(col, row);
        int cw = charWidth();
        int ch = charHeight();
        ubyte fgi = cdata.color & 15;
        ubyte bgi = cdata.color >>> 4;
        rgba_t fgCol = _palette[ cdata.color &  15 ];
        rgba_t bgCol = _palette[ cdata.color >>> 4 ];
        const(ubyte)[] glyphData = getGlyphData(_font, cdata.glyph);
        assert(glyphData.length == 8);
        bool bold      = (cdata.style & TM_bold     ) != 0;
        bool underline = (cdata.style & TM_underline) != 0;
        bool blink     = (cdata.style & TM_blink    ) != 0;
        for (int y = 0; y < ch; ++y)
        {
            const int yback = row * ch + y;
            int bits  = glyphData[y];

            if ( (y == ch - 1) && underline)
                bits = 0xff;

            if (bold)
                bits |= (bits >> 1);

            if (blink && !_blinkOn)
                bits = 0;

            int idx = (_columns * cw) * yback + (col * cw);
            rgba_t* pixels = &_back[idx];
            ubyte*  flags  = &_backFlags[idx];
            if (bits == 0)
            {
                flags[0..cw]  = 0;     // all bg
                pixels[0..cw] = bgCol; // speed-up empty lines
            }
            else
            {   
                for (int x = 0; x < cw; ++x)
                {
                    bool on = (bits >> (cw - 1 - x)) & 1;
                    flags[x]  = on ? BACK_IS_FG : 0;
                    pixels[x] = on ? fgCol : bgCol;
                }
            }
        }
    }

    // copy _post to _blur (same space)
    // _blur is _post + filtered _emissive
    void applyEffects(TM_Rect updateRect) @trusted
    {
        if (_dirtyBlur)
        {
            updateRect = TM_Rect(0, 0, _outW, _outH);
            _dirtyBlur = false;
        }

        if (updateRect.isEmpty)
            return;

        int filter_2 = _filterWidth / 2;

        // blur emissive horizontally, from _emit to _emitH
        // the updated area is updateRect enlarged horizontally.
        for (int y = updateRect.y1; y < updateRect.y2; ++y)
        {
            rgba16_t* emitScan  = &_emit[_postWidth * y]; 
            
            for (int x = updateRect.x1 - filter_2; 
                     x < updateRect.x2 + filter_2; ++x)
            {  
                int postWidth = _postWidth;
                if (x < 0 || x >= _postWidth) 
                    continue;
                __m128 mmRGBA = _mm_setzero_ps();

                float[] kernel = _blurKernel;
                for (int n = -filter_2; n <= filter_2; ++n)
                {
                    int xe = x + n;
                    if (xe < 0 || xe >= _postWidth) 
                        continue;
                    rgba16_t emit = emitScan[xe];
                    __m128i mmEmit = _mm_setr_epi32(emit.r, emit.g, emit.b, emit.a);
                    float factor = _blurKernel[filter_2 + n];
                    mmRGBA = mmRGBA + _mm_cvtepi32_ps(mmEmit) * _mm_set1_ps(factor);
                }

                // store result transposed in _emitH
                // for faster convolution in Y afterwards
                rgba16_t* emitH = &_emitH[_postHeight * x + y];
                __m128i mmRes = _mm_cvttps_epi32(mmRGBA);
                
                mmRes = _mm_packus_epi32(mmRes, mmRes);
                _mm_storeu_si64(emitH, mmRes);
            }
        }

        for (int y = updateRect.y1 - filter_2; 
                 y < updateRect.y2 + filter_2; ++y)
        {
            if (y < 0 || y >= _postHeight) 
                continue;
 
            const(rgba_t)*   postScan = &_post[_postWidth * y];
            rgba_t*          blurScan = &_blur[_postWidth * y];
            
            for (int x = updateRect.x1 - filter_2; 
                     x < updateRect.x2 + filter_2; ++x)
            {
                // blur vertically
                __m128 mmBlur = _mm_setzero_ps();

                if (x < 0) continue;
                if (x >= _postWidth) continue;

                const(rgba16_t)* emitHScan = &_emitH[_postHeight * x];

                for (int n = -filter_2; n <= filter_2; ++n)
                {
                    int ye = y + n;
                    if (ye < 0) continue;
                    if (ye >= _postHeight) continue;
                    rgba16_t emitH = emitHScan[ye];
                    float factor = _blurKernel[filter_2 + n];
                    __m128i mmEmit = _mm_setr_epi32(emitH.r, emitH.g, emitH.b, emitH.a);
                    mmBlur = mmBlur + _mm_cvtepi32_ps(mmEmit) * _mm_set1_ps(factor);
                }

                static ubyte clamp_0_255(float t) pure
                {
                    int u = cast(int)t;
                    if (u > 255) u = 255;
                    if (u < 0) u = 0;
                    return cast(ubyte)u;
                }

                static TM_max32f(float a, float b) pure
                {
                    return a < b ? a : b;
                }

                mmBlur = _mm_sqrt_ps(mmBlur);

                if (_options.noiseTexture)
                {
                    // so that the user has easier tuning values
                    enum float NSCALE = 0.0006f;
                    float noiseAmount = _options.noiseAmount * NSCALE;
                    float noise = NOISE_16x16[(x & 15)*16 + (y & 15)];
                    noise = (noise - 127.5f) * noiseAmount;
                    mmBlur = mmBlur * (1.0f + noise);
                }

                // PERF: could be improved with SIMD below

                float BLUR_AMOUNT = _options.blurAmount;

                // Add blur
                rgba_t post = postScan[x];
                float R = post.r + mmBlur.array[0] * BLUR_AMOUNT;
                float G = post.g + mmBlur.array[1] * BLUR_AMOUNT;
                float B = post.b + mmBlur.array[2] * BLUR_AMOUNT;

                if (_options.tonemapping)
                {
                    // Similar tonemapping as Dplug.
                    float tmThre  = 255.0f;
                    float tmRatio = _options.tonemappingRatio; 
                    float excessR = TM_max32f(0.0f, R - tmThre);
                    float excessG = TM_max32f(0.0f, G - tmThre);
                    float excessB = TM_max32f(0.0f, B - tmThre);
                    float exceedLuma = 0.3333f * excessR 
                                     + 0.3333f * excessG
                                     + 0.3333f * excessB;

                    // Add excess energy in all channels
                    R += exceedLuma * tmRatio;
                    G += exceedLuma * tmRatio;
                    B += exceedLuma * tmRatio;
                }

                post.r = clamp_0_255(R);
                post.g = clamp_0_255(G);
                post.b = clamp_0_255(B);
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

// 16x16 patch of 8-bit blue noise, tileable. 
// This is used over the whole buffer.
private static immutable ubyte[256] NOISE_16x16 =
[
    127, 194, 167,  79,  64, 173,  22,  83, 
    167, 105, 119, 250, 201,  34, 214, 145, 
    233,  56,  13, 251, 203, 124, 243,  42, 
    216,  34,  73, 175, 133,  64, 185,  73, 
     93, 156, 109, 144,  34,  98, 153, 138, 
    187, 238, 155,  46,  13, 102, 247,   0,
     28, 180,  46, 218, 183,  13, 212,  69,  
     13,  92, 126, 228, 211, 161, 117, 197, 
    134, 240, 121,  75, 234,  88,  53, 170, 
    109, 204,  59,  22,  86, 141,  38, 222,
     81, 205,  13,  59, 160, 198, 129, 252,  
      0, 147, 176, 193, 244,  71, 173,  56,
     22, 168, 104, 139,  22, 114,  38, 220, 
    101, 231,  77,  34, 113,  13, 189,  96, 
    253, 148, 227, 190, 246, 174,  66, 155,  
     28,  50, 164, 131, 217, 151, 232, 128, 
    115,  69,  34,  50,  93,  13, 209,  85,
    192, 120, 248,  64,  90,  28, 208,  42,
      0, 200, 215,  79, 125, 148, 239, 136, 
    181,  22, 206,  13, 185, 108,  59, 179,
     90, 130, 159, 182, 235,  42, 106,   0,  
     56,  99, 226, 140, 157, 237,  77, 165, 
    249,  28, 105,  13,  61, 170, 224,  75, 
    202, 163, 114,  81,  46,  22, 137, 223, 
    189,  53, 219, 142, 196,  28, 122, 154, 
    254,  42,  28, 242, 196, 210, 119,  38, 
    149,  86, 118, 245,  71,  96, 213,  13,  
     88, 178,  66, 129, 171,   0,  99,  69, 
    178,  13, 207,  38, 159, 187,  50, 132, 
    236, 146, 191,  95,  53, 229, 163, 241,
     46, 225, 102, 135,   0, 230, 110, 199,  
     61,   0, 221,  22, 150,  83, 112, 22
];

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
    rgba_t c;
    c.r = cast(ubyte) ( ( fg.r * alpha + bg.r * invAlpha ) / 255 );
    c.g = cast(ubyte) ( ( fg.g * alpha + bg.g * invAlpha ) / 255 );
    c.b = cast(ubyte) ( ( fg.b * alpha + bg.b * invAlpha ) / 255 );
    c.a = cast(ubyte) ( ( fg.a * alpha + bg.a * invAlpha ) / 255 );
    return c;
}

rgba16_t linearU16Premul(rgba_t c)
{
    rgba16_t res;
    res.r = (c.r * c.r * c.a) >> 8;
    res.g = (c.g * c.g * c.a) >> 8;
    res.b = (c.b * c.b * c.a) >> 8;
    res.a = (c.a * c.a * c.a) >> 8;
    return res;
}


static immutable uint[16][TM_Palette.max+1] PALETTE_DATA =
[
    // Vintaage
    [ 0x00000000, 0x800000ff, 0x008000ff, 0x808000ff,
      0x000080ff, 0x800080ff, 0x008080ff, 0xc0c0c0ff,
      0x808080ff, 0xff0000ff, 0x00ff00ff, 0xffff00ff,
      0x0000ffff, 0xff00ffff, 0x00ffffff, 0xffffffff ],

    // Campbell
    [ 0x0c0c0c00, 0xc50f1fff, 0x13a10eff, 0xc19c00ff,
      0x0037daff, 0x881798ff, 0x3a96ddff, 0xccccccff,
      0x767676ff, 0xe74856ff, 0x16c60cff, 0xf9f1a5ff,
      0x3b78ffff, 0xb4009eff, 0x61d6d6ff, 0xf2f2f2ff ],

    // OneHalfLight
    [ 0x383a4200, 0xe45649ff, 0x50a14fff, 0xc18301ff,
      0x0184bcff, 0xa626a4ff, 0x0997b3ff, 0xfafafaff,
      0x4f525dff, 0xdf6c75ff, 0x98c379ff, 0xe4c07aff,
      0x61afefff, 0xc577ddff, 0x56b5c1ff, 0xffffffff ],

    // Tango
    [ 0x00000000, 0xcc0000ff, 0x4e9a06ff, 0xc4a000ff,
      0x3465a4ff, 0x75507bff, 0x06989aff, 0xd3d7cfff,
      0x555753ff, 0xef2929ff, 0x8ae234ff, 0xfce94fff,
      0x729fcfff, 0xad7fa8ff, 0x34e2e2ff, 0xeeeeecff ],
];

alias TM_RangeFlags = int;
enum : TM_RangeFlags
{
    // the whole range has the same glyph
    TM_singleGlyph = 1
}

struct TM_UnicodeRange
{
    dchar start, stop;
    const(ubyte)[] glyphData;
    TM_RangeFlags flags = 0;
}

struct TM_FontDesc
{
    int[2] charSize;
    TM_UnicodeRange[] fontData;
}

int[2] fontCharSize(TM_Font font) pure
{
    return BUILTIN_FONTS[font].charSize;
}

const(ubyte)[] getGlyphData(TM_Font font, dchar glyph) pure
{
    assert(font == TM_Font.pcega);
    const(TM_UnicodeRange)[] fontData = BUILTIN_FONTS[font].fontData;

    int ch = 8;
    for (size_t r = 0; r < fontData.length; ++r)
    {
        if (glyph >= fontData[r].start && glyph < fontData[r].stop)
        {
            TM_RangeFlags flags = fontData[r].flags;
            
            if ( (flags & TM_singleGlyph) != 0)
                return fontData[r].glyphData[0..ch];

            uint index = glyph - fontData[r].start;
            return fontData[r].glyphData[index*ch..index*ch+ch];
        }
    }

    // Return notdef glyph
    return NOT_DEF[0..8];
}


static immutable TM_FontDesc[TM_Font.max + 1] BUILTIN_FONTS =
[
    TM_FontDesc([8, 8], 
    [
        TM_UnicodeRange(0x0000, 0x0020, EMPTY, TM_singleGlyph),
        TM_UnicodeRange(0x0020, 0x0080, BASIC_LATIN),
        TM_UnicodeRange(0x0080, 0x00A0, NOT_DEF, TM_singleGlyph),
        TM_UnicodeRange(0x00A0, 0x0100, LATIN1_SUPP),
        // TODO, more characters
    ])
];


static immutable ubyte[8] EMPTY =
[
    // All control chars have that same empty glyph
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
];
    
static immutable ubyte[8] NOT_DEF =
[
    0x78, 0xcc, 0x0c, 0x18, 0x30, 0x00, 0x30, 0x00, // ?
];

static immutable ubyte[96 * 8] BASIC_LATIN =
[    
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // U+0020 Space
    0x30, 0x78, 0x78, 0x30, 0x30, 0x00, 0x30, 0x00, // U+0021 !
    0x6c, 0x6c, 0x6c, 0x00, 0x00, 0x00, 0x00, 0x00, // U+0022 "
    0x6c, 0x6c, 0xfe, 0x6c, 0xfe, 0x6c, 0x6c, 0x00, // U+0023 #
    0x30, 0x7c, 0xc0, 0x78, 0x0c, 0xf8, 0x30, 0x00, // U+0024 $
    0x00, 0xc6, 0xcc, 0x18, 0x30, 0x66, 0xc6, 0x00, // U+0025 %
    0x38, 0x6c, 0x38, 0x76, 0xdc, 0xcc, 0x76, 0x00, // U+0026 &
    0x60, 0x60, 0xc0, 0x00, 0x00, 0x00, 0x00, 0x00, // U+0027 '
    0x18, 0x30, 0x60, 0x60, 0x60, 0x30, 0x18, 0x00, // U+0028 (
    0x60, 0x30, 0x18, 0x18, 0x18, 0x30, 0x60, 0x00, // U+0029 )
    0x00, 0x66, 0x3c, 0xff, 0x3c, 0x66, 0x00, 0x00, // U+002A *
    0x00, 0x30, 0x30, 0xfc, 0x30, 0x30, 0x00, 0x00, // U+002B +
    0x00, 0x00, 0x00, 0x00, 0x00, 0x30, 0x30, 0x60, // U+002C ,
    0x00, 0x00, 0x00, 0xfc, 0x00, 0x00, 0x00, 0x00, // U+002D -
    0x00, 0x00, 0x00, 0x00, 0x00, 0x30, 0x30, 0x00, // U+002E .
    0x06, 0x0c, 0x18, 0x30, 0x60, 0xc0, 0x80, 0x00, // U+002F /
    0x7c, 0xc6, 0xce, 0xde, 0xf6, 0xe6, 0x7c, 0x00, // U+0030 0
    0x30, 0x70, 0x30, 0x30, 0x30, 0x30, 0xfc, 0x00, // U+0031 1
    0x78, 0xcc, 0x0c, 0x38, 0x60, 0xcc, 0xfc, 0x00, // U+0032 2 
    0x78, 0xcc, 0x0c, 0x38, 0x0c, 0xcc, 0x78, 0x00, // U+0033 3
    0x1c, 0x3c, 0x6c, 0xcc, 0xfe, 0x0c, 0x1e, 0x00, // U+0034 4
    0xfc, 0xc0, 0xf8, 0x0c, 0x0c, 0xcc, 0x78, 0x00, // U+0035 5
    0x38, 0x60, 0xc0, 0xf8, 0xcc, 0xcc, 0x78, 0x00, // U+0036 6
    0xfc, 0xcc, 0x0c, 0x18, 0x30, 0x30, 0x30, 0x00, // U+0037 7
    0x78, 0xcc, 0xcc, 0x78, 0xcc, 0xcc, 0x78, 0x00, // U+0038 8
    0x78, 0xcc, 0xcc, 0x7c, 0x0c, 0x18, 0x70, 0x00, // U+0039 9
    0x00, 0x30, 0x30, 0x00, 0x00, 0x30, 0x30, 0x00, // U+003A :
    0x00, 0x30, 0x30, 0x00, 0x00, 0x30, 0x30, 0x60, // U+003B ;
    0x18, 0x30, 0x60, 0xc0, 0x60, 0x30, 0x18, 0x00, // U+003C <
    0x00, 0x00, 0xfc, 0x00, 0x00, 0xfc, 0x00, 0x00, // U+003D =
    0x60, 0x30, 0x18, 0x0c, 0x18, 0x30, 0x60, 0x00, // U+003E >
    0x78, 0xcc, 0x0c, 0x18, 0x30, 0x00, 0x30, 0x00, // U+003F ?
    0x7c, 0xc6, 0xde, 0xde, 0xde, 0xc0, 0x78, 0x00, // U+0040 @
    0x30, 0x78, 0xcc, 0xcc, 0xfc, 0xcc, 0xcc, 0x00, // U+0041 A
    0xfc, 0x66, 0x66, 0x7c, 0x66, 0x66, 0xfc, 0x00, // U+0042 B
    0x3c, 0x66, 0xc0, 0xc0, 0xc0, 0x66, 0x3c, 0x00, // U+0043 C
    0xf8, 0x6c, 0x66, 0x66, 0x66, 0x6c, 0xf8, 0x00, // U+0044 D
    0xfe, 0x62, 0x68, 0x78, 0x68, 0x62, 0xfe, 0x00, // U+0045 E
    0xfe, 0x62, 0x68, 0x78, 0x68, 0x60, 0xf0, 0x00, // U+0046 F
    0x3c, 0x66, 0xc0, 0xc0, 0xce, 0x66, 0x3e, 0x00, // U+0047 G
    0xcc, 0xcc, 0xcc, 0xfc, 0xcc, 0xcc, 0xcc, 0x00, // U+0048 H
    0x78, 0x30, 0x30, 0x30, 0x30, 0x30, 0x78, 0x00, // U+0049 I
    0x1e, 0x0c, 0x0c, 0x0c, 0xcc, 0xcc, 0x78, 0x00, // U+004A J
    0xe6, 0x66, 0x6c, 0x78, 0x6c, 0x66, 0xe6, 0x00, // U+004B K
    0xf0, 0x60, 0x60, 0x60, 0x62, 0x66, 0xfe, 0x00, // U+004C L
    0xc6, 0xee, 0xfe, 0xfe, 0xd6, 0xc6, 0xc6, 0x00, // U+004D M
    0xc6, 0xe6, 0xf6, 0xde, 0xce, 0xc6, 0xc6, 0x00, // U+004E N
    0x38, 0x6c, 0xc6, 0xc6, 0xc6, 0x6c, 0x38, 0x00, // U+004F O
    0xfc, 0x66, 0x66, 0x7c, 0x60, 0x60, 0xf0, 0x00, // U+0050 P
    0x78, 0xcc, 0xcc, 0xcc, 0xdc, 0x78, 0x1c, 0x00, // U+0051 Q
    0xfc, 0x66, 0x66, 0x7c, 0x6c, 0x66, 0xe6, 0x00, // U+0052 R
    0x78, 0xcc, 0xe0, 0x70, 0x1c, 0xcc, 0x78, 0x00, // U+0053 S
    0xfc, 0xb4, 0x30, 0x30, 0x30, 0x30, 0x78, 0x00, // U+0054 T
    0xcc, 0xcc, 0xcc, 0xcc, 0xcc, 0xcc, 0xfc, 0x00, // U+0055 U
    0xcc, 0xcc, 0xcc, 0xcc, 0xcc, 0x78, 0x30, 0x00, // U+0056 V
    0xc6, 0xc6, 0xc6, 0xd6, 0xfe, 0xee, 0xc6, 0x00, // U+0057 W
    0xc6, 0xc6, 0x6c, 0x38, 0x38, 0x6c, 0xc6, 0x00, // U+0058 X
    0xcc, 0xcc, 0xcc, 0x78, 0x30, 0x30, 0x78, 0x00, // U+0059 Y
    0xfe, 0xc6, 0x8c, 0x18, 0x32, 0x66, 0xfe, 0x00, // U+005A Z
    0x78, 0x60, 0x60, 0x60, 0x60, 0x60, 0x78, 0x00, // U+005B [
    0xc0, 0x60, 0x30, 0x18, 0x0c, 0x06, 0x02, 0x00, // U+005C \
    0x78, 0x18, 0x18, 0x18, 0x18, 0x18, 0x78, 0x00, // U+005D ]
    0x10, 0x38, 0x6c, 0xc6, 0x00, 0x00, 0x00, 0x00, // U+005E ^
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xff, // U+005F _
    0x30, 0x30, 0x18, 0x00, 0x00, 0x00, 0x00, 0x00, // U+0060 `
    0x00, 0x00, 0x78, 0x0c, 0x7c, 0xcc, 0x76, 0x00, // U+0061 a
    0xe0, 0x60, 0x60, 0x7c, 0x66, 0x66, 0xdc, 0x00, // U+0062 b
    0x00, 0x00, 0x78, 0xcc, 0xc0, 0xcc, 0x78, 0x00, // U+0063 c
    0x1c, 0x0c, 0x0c, 0x7c, 0xcc, 0xcc, 0x76, 0x00, // U+0064 d
    0x00, 0x00, 0x78, 0xcc, 0xfc, 0xc0, 0x78, 0x00, // U+0065 e
    0x38, 0x6c, 0x60, 0xf0, 0x60, 0x60, 0xf0, 0x00, // U+0066 f
    0x00, 0x00, 0x76, 0xcc, 0xcc, 0x7c, 0x0c, 0xf8, // U+0067 g
    0xe0, 0x60, 0x6c, 0x76, 0x66, 0x66, 0xe6, 0x00, // U+0068 h
    0x30, 0x00, 0x70, 0x30, 0x30, 0x30, 0x78, 0x00, // U+0069 i
    0x0c, 0x00, 0x0c, 0x0c, 0x0c, 0xcc, 0xcc, 0x78, // U+006A j
    0xe0, 0x60, 0x66, 0x6c, 0x78, 0x6c, 0xe6, 0x00, // U+006B k
    0x70, 0x30, 0x30, 0x30, 0x30, 0x30, 0x78, 0x00, // U+006C l
    0x00, 0x00, 0xcc, 0xfe, 0xfe, 0xd6, 0xc6, 0x00, // U+006D m
    0x00, 0x00, 0xf8, 0xcc, 0xcc, 0xcc, 0xcc, 0x00, // U+006E n
    0x00, 0x00, 0x78, 0xcc, 0xcc, 0xcc, 0x78, 0x00, // U+006F o
    0x00, 0x00, 0xdc, 0x66, 0x66, 0x7c, 0x60, 0xf0, // U+0070 p
    0x00, 0x00, 0x76, 0xcc, 0xcc, 0x7c, 0x0c, 0x1e, // U+0071 q
    0x00, 0x00, 0xdc, 0x76, 0x66, 0x60, 0xf0, 0x00, // U+0072 r
    0x00, 0x00, 0x7c, 0xc0, 0x78, 0x0c, 0xf8, 0x00, // U+0073 s
    0x10, 0x30, 0x7c, 0x30, 0x30, 0x34, 0x18, 0x00, // U+0074 t
    0x00, 0x00, 0xcc, 0xcc, 0xcc, 0xcc, 0x76, 0x00, // U+0075 u
    0x00, 0x00, 0xcc, 0xcc, 0xcc, 0x78, 0x30, 0x00, // U+0076 v
    0x00, 0x00, 0xc6, 0xd6, 0xfe, 0xfe, 0x6c, 0x00, // U+0077 w
    0x00, 0x00, 0xc6, 0x6c, 0x38, 0x6c, 0xc6, 0x00, // U+0078 x
    0x00, 0x00, 0xcc, 0xcc, 0xcc, 0x7c, 0x0c, 0xf8, // U+0079 y
    0x00, 0x00, 0xfc, 0x98, 0x30, 0x64, 0xfc, 0x00, // U+007A z
    0x1c, 0x30, 0x30, 0xe0, 0x30, 0x30, 0x1c, 0x00, // U+007B {
    0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x00, // U+007C | Vert line
    0xe0, 0x30, 0x30, 0x1c, 0x30, 0x30, 0xe0, 0x00, // U+007D }
    0x76, 0xdc, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // U+007E ~
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // U+007F Delete
];

static immutable ubyte[96 * 8] LATIN1_SUPP =
[
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // U+00A0 NBSP
    0x18, 0x18, 0x00, 0x18, 0x18, 0x18, 0x18, 0x00, // U+00A1 ¡
    0x18, 0x18, 0x7e, 0xc0, 0xc0, 0x7e, 0x18, 0x18, // U+00A2 ¢
    0x38, 0x6c, 0x64, 0xf0, 0x60, 0xe6, 0xfc, 0x00, // U+00A3 £
    0x00, 0x84, 0x78, 0xcc, 0xcc, 0x78, 0x84, 0x00, // U+00A4 ¤
    0x30, 0x30, 0x00, 0x78, 0xcc, 0xfc, 0xcc, 0x00, // U+00A5 Å
    0x18, 0x18, 0x18, 0x00, 0x18, 0x18, 0x18, 0x00, // U+00A6 | broken bar
    0x3c, 0x60, 0x78, 0x6c, 0x6c, 0x3c, 0x0c, 0x78, // U+00A7 §
    0xcc, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // U+00A8 ¨ diaeresis
    0x7e, 0x81, 0x9d, 0xa1, 0xa1, 0x9d, 0x81, 0x7e, // U+00A9 (c) copyright 
];

/* CP437 upper range
    0x00, 0x10, 0x38, 0x6c, 0xc6, 0xc6, 0xfe, 0x00, // U+2302 ⌂
    0x78, 0xcc, 0xc0, 0xcc, 0x78, 0x18, 0x0c, 0x78, // U+00C7 Ç
    0x00, 0xcc, 0x00, 0xcc, 0xcc, 0xcc, 0x7e, 0x00, // U+00FC ü
    0x1c, 0x00, 0x78, 0xcc, 0xfc, 0xc0, 0x78, 0x00, // U+00E9 é
    0x7e, 0xc3, 0x3c, 0x06, 0x3e, 0x66, 0x3f, 0x00, // U+00E2 â
    0xcc, 0x00, 0x78, 0x0c, 0x7c, 0xcc, 0x7e, 0x00, // U+00E4 ä
    0xe0, 0x00, 0x78, 0x0c, 0x7c, 0xcc, 0x7e, 0x00, // U+00E0 à
    0x30, 0x30, 0x78, 0x0c, 0x7c, 0xcc, 0x7e, 0x00, // U+00E5 å
    0x00, 0x00, 0x78, 0xc0, 0xc0, 0x78, 0x0c, 0x38, // U+00E7 ç
    0x7e, 0xc3, 0x3c, 0x66, 0x7e, 0x60, 0x3c, 0x00, // U+00EA ê
    0xcc, 0x00, 0x78, 0xcc, 0xfc, 0xc0, 0x78, 0x00, // U+00EB ë
    0xe0, 0x00, 0x78, 0xcc, 0xfc, 0xc0, 0x78, 0x00, // U+00E8 è
    0xcc, 0x00, 0x70, 0x30, 0x30, 0x30, 0x78, 0x00, // U+00EF ï
    0x7c, 0xc6, 0x38, 0x18, 0x18, 0x18, 0x3c, 0x00, // U+00EE î
    0xe0, 0x00, 0x70, 0x30, 0x30, 0x30, 0x78, 0x00, // U+00EC ì
    0xc6, 0x38, 0x6c, 0xc6, 0xfe, 0xc6, 0xc6, 0x00, // U+00C4 Ä
    
    0x1c, 0x00, 0xfc, 0x60, 0x78, 0x60, 0xfc, 0x00, // U+00C9 É
    0x00, 0x00, 0x7f, 0x0c, 0x7f, 0xcc, 0x7f, 0x00, // U+00E6 æ
    0x3e, 0x6c, 0xcc, 0xfe, 0xcc, 0xcc, 0xce, 0x00, // U+00C6 Æ
    0x78, 0xcc, 0x00, 0x78, 0xcc, 0xcc, 0x78, 0x00, // U+00F4 ô
    0x00, 0xcc, 0x00, 0x78, 0xcc, 0xcc, 0x78, 0x00, // U+00F6 ö
    0x00, 0xe0, 0x00, 0x78, 0xcc, 0xcc, 0x78, 0x00, // U+00F2 ò
    0x78, 0xcc, 0x00, 0xcc, 0xcc, 0xcc, 0x7e, 0x00, // U+00F8 û
    0x00, 0xe0, 0x00, 0xcc, 0xcc, 0xcc, 0x7e, 0x00, // U+00F9 ù
    0x00, 0xcc, 0x00, 0xcc, 0xcc, 0x7c, 0x0c, 0xf8, // U+00FF ÿ
    0xc3, 0x18, 0x3c, 0x66, 0x66, 0x3c, 0x18, 0x00, // U+00D6 Ö
    0xcc, 0x00, 0xcc, 0xcc, 0xcc, 0xcc, 0x78, 0x00, // U+00DC Ü
    
    0xcc, 0xcc, 0x78, 0xfc, 0x30, 0xfc, 0x30, 0x30, // U+00A5 ¥
    0xf8, 0xcc, 0xcc, 0xfa, 0xc6, 0xcf, 0xc6, 0xc7, // U+20A7 ₧
    0x0e, 0x1b, 0x18, 0x3c, 0x18, 0x18, 0xd8, 0x70, // U+0192 ƒ
    0x1c, 0x00, 0x78, 0x0c, 0x7c, 0xcc, 0x7e, 0x00, // U+00E1 á
    0x38, 0x00, 0x70, 0x30, 0x30, 0x30, 0x78, 0x00, // U+00ED í
    0x00, 0x1c, 0x00, 0x78, 0xcc, 0xcc, 0x78, 0x00, // U+00F3 ó
    0x00, 0x1c, 0x00, 0xcc, 0xcc, 0xcc, 0x7e, 0x00, // U+00DA ú
    0x00, 0xf8, 0x00, 0xf8, 0xcc, 0xcc, 0xcc, 0x00, // U+00F1 ñ
    0xfc, 0x00, 0xcc, 0xec, 0xfc, 0xdc, 0xcc, 0x00, // U+00D1 Ñ
    0x3c, 0x6c, 0x6c, 0x3e, 0x00, 0x7e, 0x00, 0x00, // U+00AA ª
    0x38, 0x6c, 0x6c, 0x38, 0x00, 0x7c, 0x00, 0x00, // U+00BA º
    0x30, 0x00, 0x30, 0x60, 0xc0, 0xcc, 0x78, 0x00, // U+00BF ¿
    0x00, 0x00, 0x00, 0xfc, 0xc0, 0xc0, 0x00, 0x00, // U+2310 ⌐
    0x00, 0x00, 0x00, 0xfc, 0x0c, 0x0c, 0x00, 0x00, // U+00AC ¬
    0xc3, 0xc6, 0xcc, 0xde, 0x33, 0x66, 0xcc, 0x0f, // U+00BD ½
    0xc3, 0xc6, 0xcc, 0xdb, 0x37, 0x6f, 0xcf, 0x03, // U+00BC ¼
    
    0x00, 0x33, 0x66, 0xcc, 0x66, 0x33, 0x00, 0x00, // U+00AB «
    0x00, 0xcc, 0x66, 0x33, 0x66, 0xcc, 0x00, 0x00, // U+00BB »
    0x22, 0x88, 0x22, 0x88, 0x22, 0x88, 0x22, 0x88, // U+2591 ░
    0x55, 0xaa, 0x55, 0xaa, 0x55, 0xaa, 0x55, 0xaa, // U+2592 ▒
    0xdb, 0x77, 0xdb, 0xee, 0xdb, 0x77, 0xdb, 0xee, // U+2593 ▓
    0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, // U+2502 │
    0x18, 0x18, 0x18, 0x18, 0xf8, 0x18, 0x18, 0x18, // U+2524 ┤
    0x18, 0x18, 0xf8, 0x18, 0xf8, 0x18, 0x18, 0x18, // U+2561 ╡
    0x36, 0x36, 0x36, 0x36, 0xf6, 0x36, 0x36, 0x36, // U+2562 ╢
    0x00, 0x00, 0x00, 0x00, 0xfe, 0x36, 0x36, 0x36, // U+2556 ╖
    0x00, 0x00, 0xf8, 0x18, 0xf8, 0x18, 0x18, 0x18, // U+2555 ╕
    0x36, 0x36, 0xf6, 0x06, 0xf6, 0x36, 0x36, 0x36, // U+2563 ╣
    0x36, 0x36, 0x36, 0x36, 0x36, 0x36, 0x36, 0x36, // U+2551 ║
    0x00, 0x00, 0xfe, 0x06, 0xf6, 0x36, 0x36, 0x36, // U+2557 ╗
    0x36, 0x36, 0xf6, 0x06, 0xfe, 0x00, 0x00, 0x00, // U+255D ╝
    0x36, 0x36, 0x36, 0x36, 0xfe, 0x00, 0x00, 0x00, // U+255C
    0x18, 0x18, 0xf8, 0x18, 0xf8, 0x00, 0x00, 0x00, // U+255B
    0x00, 0x00, 0x00, 0x00, 0xf8, 0x18, 0x18, 0x18, // U+2510
    0x18, 0x18, 0x18, 0x18, 0x1f, 0x00, 0x00, 0x00, // U+2514
    0x18, 0x18, 0x18, 0x18, 0xff, 0x00, 0x00, 0x00, // U+2534
    0x00, 0x00, 0x00, 0x00, 0xff, 0x18, 0x18, 0x18, // U+25C2
    0x18, 0x18, 0x18, 0x18, 0x1f, 0x18, 0x18, 0x18, // U+251C
    0x00, 0x00, 0x00, 0x00, 0xff, 0x00, 0x00, 0x00, // U+2500
    0x18, 0x18, 0x18, 0x18, 0xff, 0x18, 0x18, 0x18, // U+253C
    0x18, 0x18, 0x1f, 0x18, 0x1f, 0x18, 0x18, 0x18, // U+255E
    0x36, 0x36, 0x36, 0x36, 0x37, 0x36, 0x36, 0x36, // U+255F
    0x36, 0x36, 0x37, 0x30, 0x3f, 0x00, 0x00, 0x00, // U+255A
    0x00, 0x00, 0x3f, 0x30, 0x37, 0x36, 0x36, 0x36, // U+2554
    0x36, 0x36, 0xf7, 0x00, 0xff, 0x00, 0x00, 0x00, // U+2569
    0x00, 0x00, 0xff, 0x00, 0xf7, 0x36, 0x36, 0x36, // U+2566
    0x36, 0x36, 0x37, 0x30, 0x37, 0x36, 0x36, 0x36, // U+2560
    0x00, 0x00, 0xff, 0x00, 0xff, 0x00, 0x00, 0x00, // U+2550
    0x36, 0x36, 0xf7, 0x00, 0xf7, 0x36, 0x36, 0x36, // U+256C
    0x18, 0x18, 0xff, 0x00, 0xff, 0x00, 0x00, 0x00, // U+2567
    0x36, 0x36, 0x36, 0x36, 0xff, 0x00, 0x00, 0x00, // U+2568
    0x00, 0x00, 0xff, 0x00, 0xff, 0x18, 0x18, 0x18, // U+2564
    0x00, 0x00, 0x00, 0x00, 0xff, 0x36, 0x36, 0x36, // U+2565
    0x36, 0x36, 0x36, 0x36, 0x3f, 0x00, 0x00, 0x00, // U+2559
    0x18, 0x18, 0x1f, 0x18, 0x1f, 0x00, 0x00, 0x00, // U+2558
    0x00, 0x00, 0x1f, 0x18, 0x1f, 0x18, 0x18, 0x18, // U+2552
    0x00, 0x00, 0x00, 0x00, 0x3f, 0x36, 0x36, 0x36, // U+2553
    0x36, 0x36, 0x36, 0x36, 0xff, 0x36, 0x36, 0x36, // U+256B
    0x18, 0x18, 0xff, 0x18, 0xff, 0x18, 0x18, 0x18, // U+256A
    0x18, 0x18, 0x18, 0x18, 0xf8, 0x00, 0x00, 0x00, // U+2518
    0x00, 0x00, 0x00, 0x00, 0x1f, 0x18, 0x18, 0x18, // U+250C
    0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, // U+2588
    0x00, 0x00, 0x00, 0x00, 0xff, 0xff, 0xff, 0xff, // U+2584
    0xf0, 0xf0, 0xf0, 0xf0, 0xf0, 0xf0, 0xf0, 0xf0, // U+258C
    0x0f, 0x0f, 0x0f, 0x0f, 0x0f, 0x0f, 0x0f, 0x0f, // U+2590
    0xff, 0xff, 0xff, 0xff, 0x00, 0x00, 0x00, 0x00, // U+2580
    0x00, 0x00, 0x76, 0xdc, 0xc8, 0xdc, 0x76, 0x00, // U+03C1
    0x00, 0x78, 0xcc, 0xf8, 0xcc, 0xf8, 0xc0, 0xc0, // U+00DF
    0x00, 0xfc, 0xcc, 0xc0, 0xc0, 0xc0, 0xc0, 0x00, // U+0393
    0x00, 0xfe, 0x6c, 0x6c, 0x6c, 0x6c, 0x6c, 0x00, // U+03C0
    0xfc, 0xcc, 0x60, 0x30, 0x60, 0xcc, 0xfc, 0x00, // U+03A3
    0x00, 0x00, 0x7e, 0xd8, 0xd8, 0xd8, 0x70, 0x00, // U+03C3
    0x00, 0x66, 0x66, 0x66, 0x66, 0x7c, 0x60, 0xc0, // U+00B5 µ
    0x00, 0x76, 0xdc, 0x18, 0x18, 0x18, 0x18, 0x00, // U+03C4
    0xfc, 0x30, 0x78, 0xcc, 0xcc, 0x78, 0x30, 0xfc, // U+03A6
    0x38, 0x6c, 0xc6, 0xfe, 0xc6, 0x6c, 0x38, 0x00, // U+0398
    0x38, 0x6c, 0xc6, 0xc6, 0x6c, 0x6c, 0xee, 0x00, // U+03A9
    0x1c, 0x30, 0x18, 0x7c, 0xcc, 0xcc, 0x78, 0x00, // U+03B4
    0x00, 0x00, 0x7e, 0xdb, 0xdb, 0x7e, 0x00, 0x00, // U+221E
    0x06, 0x0c, 0x7e, 0xdb, 0xdb, 0x7e, 0x60, 0xc0, // U+03C6
    0x38, 0x60, 0xc0, 0xf8, 0xc0, 0x60, 0x38, 0x00, // U+03B5
    0x78, 0xcc, 0xcc, 0xcc, 0xcc, 0xcc, 0xcc, 0x00, // U+2229
    0x00, 0xfc, 0x00, 0xfc, 0x00, 0xfc, 0x00, 0x00, // U+2261
    0x30, 0x30, 0xfc, 0x30, 0x30, 0x00, 0xfc, 0x00, // U+00B1 +-
    0x60, 0x30, 0x18, 0x30, 0x60, 0x00, 0xfc, 0x00, // U+2265 >=
    0x18, 0x30, 0x60, 0x30, 0x18, 0x00, 0xfc, 0x00, // U+2264 <=
    0x0e, 0x1b, 0x1b, 0x18, 0x18, 0x18, 0x18, 0x18, // U+2320
    0x18, 0x18, 0x18, 0x18, 0x18, 0xd8, 0xd8, 0x70, // U+2321
    0x30, 0x30, 0x00, 0xfc, 0x00, 0x30, 0x30, 0x00, // U+00F7
    0x00, 0x76, 0xdc, 0x00, 0x76, 0xdc, 0x00, 0x00, // U+2248
    0x38, 0x6c, 0x6c, 0x38, 0x00, 0x00, 0x00, 0x00, // U+00B0
    0x00, 0x00, 0x00, 0x18, 0x18, 0x00, 0x00, 0x00, // U+2219
    0x00, 0x00, 0x00, 0x00, 0x18, 0x00, 0x00, 0x00, // U+00B7
    0x0f, 0x0c, 0x0c, 0x0c, 0xec, 0x6c, 0x3c, 0x1c, // U+221A
    0x78, 0x6c, 0x6c, 0x6c, 0x6c, 0x00, 0x00, 0x00, // U+207F
    0x70, 0x18, 0x30, 0x60, 0x78, 0x00, 0x00, 0x00, // U+00B2 ²
    0x00, 0x00, 0x3c, 0x3c, 0x3c, 0x3c, 0x00, 0x00, // U+25A0
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00  // U+00A0
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

    void initialize(TM_Console* console)
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

    TM_Console* console;

    void setColor(int col, bool bg) nothrow @nogc
    {
        if (bg) 
            console.bg(col);
        else 
            console.fg(col);
    }

    void setStyle(TM_Style s) pure
    {
        console.style(s);
    }

    void enterTag(const(char)[] tagName, int inputPos)
    {
        // dup top of stack, set foreground color
        console.save();

        TM_Style currentStyle = console.current.style;

        switch(tagName)
        {
            case "b":
            case "strong":
                setStyle(currentStyle | TM_bold);
                break;

            case "blink":
                setStyle(currentStyle | TM_blink);
                break;

            case "u":
                setStyle(currentStyle | TM_underline);
                break;

            case "shiny":
                setStyle(currentStyle | TM_shiny);
                break;

            default:
                {
                    bool bg = false;
                    if ((tagName.length >= 3) 
                        && (tagName[0..3] == "on_"))
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
        // restore, but keep cursor position
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
                // input terminate on "<", return end of input 
                // instead of error
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
                    // input terminate on "</", return end of input 
                    // instead of error
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
                    r.type = closeTag ? TokenType.tagClose
                                      : TokenType.tagOpen;
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
                // input terminate on "<", return end of input instead
                // of error
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

            int entStart = inputPos;
            while(hasNextChar())
            {
                char ch = peek();
                if (ch == ';')
                {
                    const(char)[] entName = charsSincePos(entStart);
                    switch (entName)
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
                else if ((ch >= 'a' && ch <= 'z') 
                      || (ch >= 'a' && ch <= 'z')) // TODO suspicious
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

            // do nothing, ignore an unrecognized entity or empty one, 
            // but terminate input
            {
                // input terminate on "<", return end of input instead
                // of error
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
                        float[] outtaps) pure
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
    double p  = 0.3275911;
    // A&S formula 7.1.26
    double t = 1.0 / (1.0 + p * abs(x));
    double y = 1.0 - (((((a5 * t + a4) * t) + a3) * t + a2) * t + a1)
                     * t * exp(-x * x);
    return (x >= 0 ? 1 : -1) * y;
}

double def_int_gaussian(double x, double mu, double sigma) pure
{
    return 0.5 * erf((x - mu) / (1.41421356237 * sigma));
}