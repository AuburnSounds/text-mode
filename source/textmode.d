module textmode;

nothrow @nogc @safe:

import core.stdc.stdlib: malloc, realloc, free;
import core.stdc.string: memset;
import core.stdc.math: sqrt, exp;

import std.utf: byDchar;

import inteli.smmintrin;
import rectlist;
import miniz;

nothrow:
@nogc:
@safe:

/// A text mode palette index.
alias TM_Color = int;

/// Helpers for text mode colors.
enum : TM_Color
{
    TM_colorBlack    = 0,  ///
    TM_colorRed      = 1,  ///
    TM_colorGreen    = 2,  ///
    TM_colorOrange   = 3,  ///
    TM_colorBlue     = 4,  ///
    TM_colorMagenta  = 5,  ///
    TM_colorCyan     = 6,  ///
    TM_colorLGrey    = 7,  ///
    TM_colorGrey     = 8,  ///
    TM_colorLRed     = 9,  ///
    TM_colorLGreen   = 10, ///
    TM_colorYellow   = 11, ///
    TM_colorLBlue    = 12, ///
    TM_colorLMagenta = 13, ///
    TM_colorLCyan    = 14, ///
    TM_colorWhite    = 15, ///

    // old names
    deprecated TM_black    = 0,
    deprecated TM_red      = 1,
    deprecated TM_green    = 2,
    deprecated TM_orange   = 3,
    deprecated TM_blue     = 4,
    deprecated TM_magenta  = 5,
    deprecated TM_cyan     = 6,
    deprecated TM_lgrey    = 7,
    deprecated TM_grey     = 8,
    deprecated TM_lred     = 9,
    deprecated TM_lgreen   = 10,
    deprecated TM_yellow   = 11,
    deprecated TM_lblue    = 12,
    deprecated TM_lmagenta = 13,
    deprecated TM_lcyan    = 14,
    deprecated TM_white    = 15
}

/**
    An individual cell of text-mode buffer.

    Either you access it or use the `print` functions.

    The first four bytes are a Unicode codepoint, conflated
    with a grapheme and font "glyph". There is one font, and
    it's 8x8. Not all codepoints exist in that font.

    Next 4-bit is foreground color in a 16 color palette.
    Next 4-bit is background color in a 16 color palette.
*/
static struct TM_CharData
{
nothrow:
@nogc:
@safe:

    /**
        Unicode codepoint to represent. This library doesn't
        compose codepoints.
    */
    dchar glyph     = 32;

    /**
        Low nibble = foreground color (0 to 15)
        High nibble = background color (0 to 15)
    */
    ubyte color     = (TM_colorBlack << 4) + TM_colorGrey;

    /**
        Style of that character, a combination of `TM_Style`
        flags.
    */
    TM_Style style  = 0;
}

/**
    Character styles.
 */
alias TM_Style = ubyte;

enum : TM_Style
{
    /// no style
    TM_styleNone  = 0,

    /// <shiny>, emissive light
    TM_styleShiny = 1,

    /// <b> or <strong>, pixels are 2x1
    TM_styleBold  = 2,

    /// <u>, lowest row is filled
    TM_styleUnder = 4,

    /// <blink> need call to console.update(dt)
    TM_styleBlink = 8,

    // old names
    deprecated TM_none      = 0,
    deprecated TM_shiny     = 1,
    deprecated TM_bold      = 2,
    deprecated TM_underline = 4,
    deprecated TM_blink     = 8,
}

/**
    A box style is composed of 8 glyphs.
*/
alias TM_BoxStyle = dchar[8];

/**
    ┌──┐
    │  │
    └──┘
*/
enum TM_BoxStyle TM_boxThin = "┌─┐││└─┘"d;

/**
    ┏━━┓
    ┃  ┃
    ┗━━┛
*/
enum TM_BoxStyle TM_boxLarge = "┏━┓┃┃┗━┛"d;

/**
    ┍━━┑
    │  │
    ┕━━┙
*/
enum TM_BoxStyle TM_boxLargeH = "┍━┑││┕━┙"d;

/**
    ┎──┒
    ┃  ┃
    ┖──┚
*/
enum TM_BoxStyle TM_boxLargeV = "┎─┒┃┃┖─┚"d;

/**
    ▛▀▀▜
    ▌  ▐
    ▙▄▄▟
*/
enum TM_BoxStyle TM_boxHeavy = "▛▀▜▌▐▙▄▟"d;

/**
    ◢██◣
    █  █
    ◥██◤
*/
enum TM_BoxStyle TM_boxHeavyPlus = "◢█◣██◥█◤"d;


/**
    ╔══╗
    ║  ║
    ╚══╝
*/
enum TM_BoxStyle TM_boxDouble = "╔═╗║║╚═╝"d;

/**
    ╒══╕
    ┃  ┃
    ╘══╛
*/
enum TM_BoxStyle TM_boxDoubleH = "╒═╕┃┃╘═╛"d;


/**
    Predefined palettes (default: vintage is loaded).
    You can either load a predefined palette, or change
    colors individually.
 */
alias TM_Palette = int;
enum : TM_Palette
{
    TM_paletteVintage,      ///
    TM_paletteCampbell,     ///
    TM_paletteOneHalfLight, ///
    TM_paletteTango,        ///
    TM_paletteVga,          ///
    TM_paletteWindows10,    ///
    TM_paletteVScode,       ///
    TM_paletteGruvbox,      ///
    TM_paletteNyx,          ///
    TM_paletteGraillon,     /// 
    TM_paletteCouture,      ///
    TM_paletteRenegate,     ///
}

/**
    Number of pre-defined palettes.
    Keep it sync with above.
*/
enum TM_PALETTE_NUM = 12;

/**
    Selected vintage font.
    There is only one font, our goal is to provide a Unicode
    8x8 font suitable for most languages. So other font
    options like 8x14 were removed, though it would be
    possible to add it back in the library.
*/
alias TM_Font = int;
enum : TM_Font
{
    /**
        A font dumped from BIOS around 2003, then extended.
        Since this library evolved to become a single font
        library, it may be fitting to evolve it contrarily
        to history and make it more "entertaining" rather
        than business-IBM-PC style.
    */
    TM_font8x8,
}

/// How to blend on output buffer?
alias TM_BlendMode = int;
enum : TM_BlendMode
{
    /// Blend console content to output, using alpha.
    TM_blendSourceOver,

    /// Copy console content to output.
    TM_blendCopy,
}

/// How to align vertically the console in output buffer.
/// Default: center.
alias TM_HorzAlign = int;
enum : TM_HorzAlign
{
    TM_horzAlignLeft,   ///
    TM_horzAlignCenter, ///
    TM_horzAlignRight   ///
}

/// How to align vertically the console in output buffer.
/// Default: middle.
alias TM_VertAlign = int;
enum : TM_VertAlign
{
    TM_vertAlignTop,    ///
    TM_vertAlignMiddle, ///
    TM_vertAlignBottom  ///
}

/// Various options to change behaviour of the library.
struct TM_Options
{
    TM_BlendMode blendMode = TM_blendSourceOver; ///
    TM_HorzAlign halign    = TM_horzAlignCenter; ///
    TM_VertAlign valign    = TM_vertAlignMiddle; ///

    /// If `true`: the output buffer is considered unchanged
    /// between calls.
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
        /// This changes the blur filter width.
        float blurScale        = 1.0f;

        /// Whether foreground color contributes to blur.
        bool blurForeground    = true;

        /// Whether background color contributes to blur.
        /// Note that this usually gives surprising results
        /// together with non-black background. Only really
        /// works if everything is shiny.
        bool blurBackground    = false;

        /// Luminance blue noise, applied to blur effect.
        bool noiseTexture      = true;

        /// Quantity of that texture (1.0f means default).
        float noiseAmount      = 1.0f;

    // </blur>


    // <tonemapping>

        /// Enable or disable tonemapping.
        bool tonemapping       = false;

        /// Channels that exceed 1.0f, bleed that much in
        /// other channels.
        float tonemappingRatio = 0.3f;

    // </tonemapping>


    // <CRT emulation>

        /// Quite basic CRT emulation.
        /// Basically work in progress.
        bool crtEmulation = false;

    // </CRT emulation>


    // <vignetting>

        /// Is vignetting enabled?
        bool vignetting = false;

        /// Location in output buffer.
        /// 0 is left, 1 is right.
        /// Default = center.
        float vignettingCenterX = 0.5f;

        /// Location in output buffer (0 to 1).
        /// 0 is top, 1 is bottom.
        /// Default = center.
        float vignettingCenterY = 0.5f;

        /// How far does it take to be completely
        /// of `vignettingColor`.
        /// Default = Twice a half-diagonal of the
        /// output buffer size.
        float vignettingDistance = 1.0f;

        /// Vignetting opacity, from 0.0 to 1.0
        float vignettingOpacity = 0.3f;

        /// sRGB 8-bit, vignetting color
        ubyte[4] vignettingColor = [0, 0, 32, 255];

    // </vignetting>
}


/**
    Main API of the text-mode library.


    3 mandatory calls:

        TM_Console console;
        console.size(columns, rows);
        console.outbuf(buf.ptr, buf.w, buf.h, buf.pitch);
        console.render();

    All calls can be mix-and-matched largely without order,
    with everything relevant being cached.

    Note: None of `TM_Console` functions are thread-safe.
          - Either call them in a single-threaded way,
          - or synchronize externally.
          - or use different `TM_Console` objects in the
            first place.
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

        See_also: `outbuf`
     */
    void size(int columns, int rows)
    {
        updateTextBufferSize(columns, rows);
        updateBackBufferSize();
        cls();

        // First draw must not rely on various caches.
        _cache[] = _text[];
        _cachedPalette = _palette;
        _lastBorderColor = _palette[0];
    }
    ///ditto
    int[2] size() pure const
    {
        return [_cols, _rows];
    }

    /**
        Given selected font and size of console screen, give
        a suggested output buffer size (in pixels).
        However, this library will manage to render in
        whatever buffer size you give, so this is completely
        optional.
    */
    int suggestedWidth()
    {
        return _cols * charWidth();
    }
    ///ditto
    int suggestedHeight()
    {
        return _rows    * charHeight();
    }

    /**
        Get number of text columns.
     */
    int columns() pure const { return _cols; }

    /**
        Get number of text rows.
     */
    int rows()    pure const { return _rows; }



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
              You MUST pair your save/restore calls, or
              endure eventual display bugs.
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
        if (_stateCount > 0)
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
        Normally you don't need this since the actual size
        in output buffer is different.
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
        assert(palette >= 0 && palette < TM_PALETTE_NUM);
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
        Get a palette preset name.
        There are 0..TM_PALETTE_NUM palette presets.
    */
    static string getPaletteName(TM_Palette palette)
    {
        // Palette names for reference
        static immutable string[] TM_PALETTE_NAMES = 
        [
            "Vintage",
            "Campbell", 
            "OneHalfLight",
            "Tango",
            "Vga",
            "Windows10",
            "VScode",
            "Gruvbox",
            "Nyx",
            "Graillon",
            "Couture",
            "Renegate"
        ];

        return TM_PALETTE_NAMES[palette];
    }

    /**
        Set/get palette entries.

        Params: entry Palette index, must be 0 to 15
                r Red value.
                g Green value.
                b Blue value.
                a Alpha value.
        All values are clamped to [0 to 255].

        Note: unlike a real text mode, colors can be
              transparent. Actually color 0 is transparent
              by default, so that it can be blit by default
              over a frame.
     */
    void setPaletteEntry(int entry,
                         int r, int g, int b, int a) pure
    {
        ubyte br = clamp0_255(r);
        ubyte bg = clamp0_255(g);
        ubyte bb = clamp0_255(b);
        ubyte ba = clamp0_255(a);
        rgba_t color = rgba_t(br, bg, bb, ba);
        if (_palette[entry] != color)
        {
            _palette[entry]  = color;
            _dirtyValidation = true;
        }
    }
    ///ditto
    void setPaletteEntry(int entry,
                         ubyte[3] rgb) pure
    {
        setPaletteEntry(entry, rgb[0], rgb[1], rgb[2], 255);
    }
    ///ditto
    void setPaletteEntry(int entry,
                         ubyte[4] rgba) pure
    {
        setPaletteEntry(entry, rgba[0], rgba[1], rgba[2],
                        rgba[3]);
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
    ///ditto
    void getPaletteEntry(int entry,
                         out int r,
                         out int g,
                         out int b,
                         out int a) pure const
    {
        r = _palette[entry].r;
        g = _palette[entry].g;
        b = _palette[entry].b;
        a = _palette[entry].a;
    }
    version(Have_colors) // If using `colors` DUB package.
    {
        import colors;
        ///ditto
        void setPaletteEntry(int entry, Color c)
        {
            RGBA8 q = c.toRGBA8();
            setPaletteEntry(entry, q.r, q.g, q.b, q.a);
        }
    }

    /**
        find best match for color `r`, `g`, `b` in palette.

        Returns: A palette index to use with `fg` or `bg`.
    */
    int findColorMatch(int r, int g, int b) pure
    {
        // Find best match in palette (sum of abs diff).
        int best = -1;
        int bestScore = int.max;
        for (int n = 0; n < 16; ++n)
        {
            rgba_t e = _palette[n];
            int diffR = abs_int32(e.r - r);
            int diffG = abs_int32(e.g - g);
            int diffB = abs_int32(e.b - b);
            int err = 3 * diffR * diffR
                    + 4 * diffG * diffG
                    + 2 * diffB * diffB;
            if (err < bestScore)
            {
                // Exact match, early exit
                if (err == 0) 
                    return n;
                best = n;
                bestScore = err;
            }
        }
        return best >= 0 ? best : 0;
    }


    /**
        Set other options.
        Those control important rendering options, and
        changing those tend to redraw the whole buffer.
     */
    void options(TM_Options options)
    {
        if (_options.blendMode != options.blendMode)
            _dirtyOut = true;

        bool blurChanged =
               _options.borderShiny != options.borderShiny
            || _options.blurAmount != options.blurAmount
            || _options.blurScale != options.blurScale
            || _options.blurForeground
            != options.blurForeground
            || _options.blurBackground
            != options.blurBackground;

        // A few of those are overreacting.
        // for example, changing blur amount or tonemapping
        // may not redo the blur convolution.
        if (_options.halign != options.halign
         || _options.valign != options.valign
         || _options.borderColor != options.borderColor
         || blurChanged
         || _options.tonemapping != options.tonemapping
         || _options.tonemappingRatio
             != options.tonemappingRatio
         || _options.noiseTexture != options.noiseTexture
         || _options.noiseAmount != options.noiseAmount
         || _options.crtEmulation != options.crtEmulation)
        {
            _dirtyPost = true;
            _dirtyOut = true;
        }
        if (_options.crtEmulation != options.crtEmulation)
        {
            //not sure if that one needed
            _dirtyPost = true;

            _dirtyFinal = true;
            _dirtyOut = true;
        }

        if (_options.vignetting != options.vignetting
         || _options.vignettingCenterX
            != options.vignettingCenterX
         || _options.vignettingCenterY
            != options.vignettingCenterY
         || _options.vignettingDistance
            != options.vignettingDistance
         || _options.vignettingOpacity
            != options.vignettingOpacity
         || _options.vignettingColor
            != options.vignettingColor)
        {
            _dirtyFinal = true;
            _dirtyOut = true;
        }

        if (blurChanged)
            invalidateBlur(true);

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
        return _text[col + row * _cols];
    }

    /**
        Access character buffer directly.
        Returns: Consecutive char data, columns x rows.
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
        // FUTURE: replace byDChar by own UTF8-decoding
        foreach(dchar ch; s.byDchar())
        {
            print(ch);
        }
    }
    ///ditto
    void print() pure
    {
    }
    ///ditto
    void print(const(wchar)[] s) pure
    {
        // FUTURE: replace byDChar by own UTF-16 decoding
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
        drawChar(current.ccol, current.crow, ch);
        current.ccol += 1;
        if (current.ccol >= _cols)
            newline();
    }
    ///ditto
    void println(const(char)[] s) pure
    {
        print(s);
        newline();
    }
    ///ditto
    void println() pure
    {
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
                for (int col = 0; col < _cols; ++col)
                {
                    charAt(col, row) = charAt(col, row + 1);
                }
            }

            for (int col = 0; col < _cols; ++col)
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
        Do nothing for each dimension separately, if
        position is out of bounds.
    */
    void locate(int x = -1, int y = -1) pure
    {
        column(x);
        row(y);
    }
    ///ditto
    void column(int x) pure
    {
        if ((x >= 0) && (x < _cols))
            current.ccol = x;
    }
    ///ditto
    void row(int y) pure
    {
        if ((y >= 0) && (y < _rows))
            current.crow = y;
    }

    /**
        Print text to console at current cursor position,
        encoded in the CCL language (much the same as in
        console-colors DUB package).
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
        Here, CCL is modified (vs console-colors) to be
        ALWAYS VALID.

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

    /**
        Print while interpreting ANSI codes.
        This is designed to print UTF-8 encoded .ans files
        directly, who support more characters.

        That .ans image is displayed in current cursor
        position as a kind of bitmap, so it's blit without
        line feeds or scrolling.

        Doesn't change cursor position.
    */
    void printANS(const(char)[] s)
    {
        ANSInterpreter interp;
        interp.initialize(&this, current.ccol,
                          current.crow);
        interp.input(s, false);
        interp.interpret(s);
    }

    /**
        Print while interpreting CP437-encoded ANSI codes.
        This is designed to print CP437 encoded .ans files
        directly, such as displayed on website:
            https://16colo.rs/

        That .ans image is displayed in current cursor
        position as a kind of bitmap, so it's blit without
        line feeds or scrolling.

        Doesn't change cursor position.
    */
    void printANS_CP437(const(char)[] s)
    {
        ANSInterpreter interp;
        interp.initialize(&this, current.ccol,
                          current.crow);
        interp.input(s, true);
        interp.interpret(s);
    }

    /**
        Print a .xp binary file from REXPaint.

        That .xp image is blit in current cursor position as
        a bitmap. Doesn't change cursor position.

        It is advantageous since .xp has up to 9 layers and
        is gzipped.

        Params:
             xpBytes   = The .xp file contents.
             layerMask = What layers to draw, -1 means all.
                         Bit 0 for layer 1
                         etc...
                         Bit 8 for layer 9.
    */
    void printXP(const(void)[] xpBytes, int layerMask = -1)
        @trusted
    {
        // Compute hash of xpBytes and current palette
        uint hash = hashPalettePlusXP(xpBytes);

        // Do we have that in cache?
        TM_Image* image;

        if (getOrCreateImage(hash, image))
        {
            // cache hit, displayed decoded image
            printImage(*image, layerMask);
            return;
        }
        assert(image !is null);

        // On heap since 8kb in size, lazy init
        if (!_infl_decompressor)
            _infl_decompressor = tinfl_decompressor_alloc();
        tinfl_init(_infl_decompressor);

        // Make TM_Image from compressed .xp
        XPInterpreter interp;
        interp.initialize(&this);
        bool success = interp.interpret(cast(const(ubyte)[]) xpBytes,
                                        &_scratch,
                                        _infl_decompressor, *image);
        if (!success)
        {
            assert(image.width == 0 && image.height == 0 && image.layers == 0);
            // Note: cache item is created anyway, but with zero size.
            // At draw time, nothing happen, but we don't waste time 
            // parsing the .xp again, which would again fail.
        }

        printImage(*image, layerMask);
    }

    /**
        Print a `TM_Image` in the console buffer.
        At cursor position.
        This is meant to mirror the behaviour of `printXP`:
          - it overwrite the style with current style
          - it changes the current color
          - it preserved cursor position
    */
    void printImage(ref const(TM_Image) image, int layerMask = -1)
        @trusted
    {
        int x = current.ccol;
        int y = current.crow;

        int w = image.width;
        int h = image.height;
        int layers = image.layers;

        for (int layer = 0; layer < layers; ++layer)
        {
            bool drawLayer = (layerMask & (1<<layer)) != 0;
            if (!drawLayer)
                continue;

            for (int row = 0; row < h; ++row)
            {
                for (int col = 0; col < w; ++col)
                {
                    // PERF: can replace by offset
                    TM_CharData src = image.charAt(layer, col, row);

                    if (src.glyph == dchar.init)
                        continue; // "transparent" glyph

                    // PERF; could be more efficient if drawChar is inline, 
                    // tricky for complete compatibility with earlier behaviour
                    TM_CharData* dst = &charAt(x + col, y + row);
                    fg(src.color & 0x0f);
                    bg((src.color >>> 4) & 0x0f);
                    drawChar(x + col, y + row, src.glyph);
                }
            }
        }
    }

    /**
        Fill a rectangle with a character, using the current
        foreground, background, and style.

        This doesn't use, nor change, cursor position.
     */
    void fillRect(int x, int y, int w, int h, dchar ch) pure
    {
        if (w < 0 || h < 0)
            return;

        for (int row = y; row < y + h; ++row)
        {
            for (int col = x; col < x + w; ++col)
            {
                drawChar(col, row, ch);
            }
        }
    }

    /**
        Draw a box with a particular box style.

        This doesn't use, nor change, cursor position.
    */
    void box(int x, int y, int w, int h, TM_BoxStyle bs)
        pure
    {
        if (w < 2 || h < 2)
            return;
        drawChar(x, y, bs[0]);
        for (int col = x + 1; col + 1 < x+w; ++col)
            drawChar(col, y, bs[1]);
        drawChar(x+w-1, y, bs[2]);
        for (int row = y + 1; row + 1 < y+h; ++row)
        {
            drawChar(x, row, bs[3]);
            drawChar(x+w-1, row, bs[4]);
        }
        drawChar(x, y+h-1, bs[5]);
        for (int col = x + 1; col + 1 < x+w; ++col)
            drawChar(col, y+h-1, bs[6]);
        drawChar(x+w-1, y+h-1, bs[7]);
    }

    /**

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

        Given buffer must be an image of sRGB 8-bit RGBA
        quadruplets.

        Params:
             pixels     = Start of output buffer.
             width      = Width of output buffer.
             height     = Height of output buffer.
             pitchBytes = Offset between output scanlines.
    */
    void outbuf(void*     pixels,
                int       width,
                int       height,
                ptrdiff_t pitchBytes)
        @system // memory-safe if pixels addressable
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

        Render console to output buffer. After this call,
        the output buffer is up-to-date with the changes in
        text buffer content.

        Depending on the options, only the rectangle in
        `getUpdateRect()` will get updated.
    */
    void render()
        @system // memory-safe if `outbuf()` memory-safe
    {
        // 1. Recompute placement of text in post buffer.
        recomputeLayout();

        // 2. Compute which palette colors effectively
        // changed. So that apps are allowed to load a
        // pre-defined palette and tweak its colors each
        // frame without redraw.
        computeChangedColors();

        // 3. Invalidate characters that need redraw in
        // `_back` buffer. After that, `_charDirty` tells if
        // a character need redraw.
        rect_t[2] textRect = invalidateChars();

        // 4. Draw chars in original size, only those who
        // changed.
        drawAllChars(textRect[0]);

        // `_text` and `_back` are up-to-date.
        // this information of recency is still in textRect
        // and _charDirty.
        _dirtyAllChars = false;
        _cache[] = _text[];

        // 5. Apply scale, character margins, etc.
        // Take characters in _back and put them in _post,
        // into the final resolution.
        // This only needs done for _charDirty chars.
        // Borders are drawn if _dirtyPost is true.
        // _dirtyPost get cleared after that.
        // Return rectangle that changed
        rect_t[2] postRect = backToPost(textRect);

        // Changed palette color may affect out and post
        // buffers redraw because of borders.
        _cachedPalette = _palette;

        // 6. Blur go here.
        applyBlur(postRect[1]); // PERF: give list of rect

        // 7. Other effects. Screen simulation, etc.
        applyEffects(postRect[0]);

        // 8. Blend into out buffer.
        postToOut(textRect[0]);
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

        This answer is only valid until the next `render()`.
        Also invalidated if you print, change style,
        palette, options, etc.
     */
    bool hasPendingUpdate()
    {
        return ! rectIsEmpty(getUpdateRect());
    }

    /**
        Returns the outbuf rectangle which is going to be
        updated when `render()` is called.

        This is expressed in output buffer coordinates.

        This answer is only valid until the next `render()`
        call. Also invalidated if you print, change style,
        palette, or options, etc.

        Note: In case of nothing to redraw, it's width and
              height will be zero.
    */
    rect_t getUpdateRect()
    {
        if (_dirtyOut || (!_options.allowOutCaching) )
        {
            return rectWithCoords(0, 0, _outW, _outH);
        }

        recomputeLayout();

        rect_t[2] textRect = invalidateChars();

        if (textRect[0].isEmpty)
            return rectWithCoords(0, 0, 0, 0);


        rect_t r = transformRectToOutputCoord(textRect[0]);
        if (r.isEmpty)
            return r;

        // extend it to account for blur
        return extendByFilterWidth(r);
    }


    /**
        Convert pixel position to character position.
        Which character location is at pixel x,y ?

        Returns: `true` if a character is pointed at, else
                 `false`.
                 If no hit, `*col` and `*row` are left
                 unchanged.
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
        dy = dy / ch;
        assert(dx >= 0 && dy >= 0);
        if (dx < 0 || dy < 0 || dx >= _cols || dy >= _rows)
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
        tinfl_decompressor_free(_infl_decompressor);
        sb_free(_scratch);

        // clear cached .xp image
        int cached = sb_count(_xpCache);
        for (int c = 0; c < cached; ++c)
        {
            _xpCache[c].cachedImage.release();
            free(_xpCache[c].cachedImage);
        }
        sb_free(_xpCache);
    }

private:

    // By default, EGA text mode, correspond to a 320x200.
    TM_Font _font = TM_font8x8;
    int _cols     = -1;
    int _rows     = -1;

    TM_Options _options = TM_Options.init;

    TM_CharData[] _text  = null; // text buffer
    TM_CharData[] _cache = null; // same but cached
    bool[] _charDirty = null; // true if char need redraw

    double _elapsedTime = 0; // Time elapsed, for blink
    bool _blinkOn; // Is <blink> text visible at this time
    bool _cachedBlinkOn;

    // Palette
    rgba_t[16] _palette =
    [
        rgba_t(  0,  0,  0,  0), rgba_t(128,  0,  0,255),
        rgba_t(  0,128,  0,255), rgba_t(128,128,  0,255),
        rgba_t(  0,  0,128,255), rgba_t(128,  0,128,255),
        rgba_t(  0,128,128,255), rgba_t(192,192,192,255),
        rgba_t(128,128,128,255), rgba_t(255,  0,  0,255),
        rgba_t(  0,255,  0,255), rgba_t(255,255,  0,255),
        rgba_t(  0,  0,255,255), rgba_t(255,  0,255,255),
        rgba_t(  0,255,255,255), rgba_t(255,255,255,255),
    ];

    bool _dirtyAllChars   = true; // all chars need redraw
    bool _dirtyValidation = true; // _charDirty need compute
    bool _dirtyPost       = true;
    bool _dirtyOut        = true;

    rgba_t[16] _cachedPalette; // Last used color color.
    bool[16] _paletteChanged; // Palette changed
    rgba_t _lastBorderColor; // Last used border color.

    rect_t[2]  _lastBounds;  // last computed dirty rects

    // Size of bitmap backing buffer.
    // In _back and _backFlags buffer, every character is
    // rendered next to each other without gaps.
    int _backWidth  = -1;
    int _backHeight = -1;
    rgba_t[] _back  = null;
    ubyte[] _backFlags = null;
    enum : ubyte
    {
        BACK_IS_FG = 1, // fg when present, bg else
    }

    // A buffer for effects, same size as outbuf (including
    // borders) In _post/_blur/_emit/_emitH/_final buffers,
    // scale is applied and also borders.
    int _postWidth  = -1;
    int _postHeight = -1;
    rgba_t[] _post  = null;


    // a buffer that is a copy of _post,
    // with only blur applied
    rgba32f_t[] _blur = null;

    // a buffer that composites _post and _blur
    rgba_t[] _final  = null;

    // A buffer that contains _post but converted in YCbCr
    // (such as with BT.601 for example).
    YCbCrA_t[] _yuv;

    // A buffer of a single scan line, utilized for compositing effect.
    rgba32f_t[] _fxbuf = null;

    // A buffer of a single scan line, utilized for compositin effect in YUV.
    YCbCrA_t[] _yuvbuf = null;

    // Blur is invalidated by filling it with black,
    // to avoid too much recompute.
    bool _blurIsCompletelyBlack = false;

    // The blur must be recomputed, since it's done 
    // differently in the first place (like kernel change).
    bool _dirtyBlur = false;

    // if true, whole final buffer must be redone
    bool _dirtyFinal = false;

    // filter width of gaussian blur, in pixels
    int _filterWidth;
    float[MAX_FILTER_WIDTH] _blurKernel;

    // presumably this is slow beyond that
    enum MAX_FILTER_WIDTH = 63;

    //those two buffers are fake-linear, premul alpha, u16

    // emissive color
    rgba16_t[] _emit  = null;

    // same, but horz-blurred, transposed
    rgba16_t[] _emitH = null;

    // General purpose _scratch buffer.
    // Used for .xp decompression.
    ubyte* _scratch;

    tinfl_decompressor* _infl_decompressor;

    static struct State
    {
        ubyte bg       = 0;
        ubyte fg       = 8;
        int ccol       = 0; // cursor col  (X position)
        int crow       = 0; // cursor row (Y position)
        TM_Style style = 0;

        // for the CCL interpreter
        int inputPos   = 0; // pos of opening tag

        // Color byte if both fg and bg are applied.
        ubyte colorByte() pure const nothrow @nogc
        {
            return (fg & 0x0f) | ((bg & 0x0f) << 4);
        }
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
        return (cast(uint)col < _cols)
            && (cast(uint)row < _rows);
    }
    bool validColumn(int col) pure const
    {
        return (cast(uint)col < _cols);
    }
    bool validRow(int row) pure const
    {
        return (cast(uint)row < _rows);
    }

    // safe drawing, help function
    void drawChar(int col, int row, dchar ch) pure @trusted
    {
        if ( ! validPosition(col, row) )
            return;
        TM_CharData* cd = &charAt(col, row);
        cd.glyph = ch;
        cd.style = current.style;
        cd.color = current.colorByte;
        _dirtyValidation = true;
    }

    // Output buffer description
    void* _outPixels;
    int _outW;
    int _outH;
    ptrdiff_t _outPitch;

    // out and post scale and margins.
    // if any changes, then post and outbuf must be redrawn
    int _outScaleX     = -1;
    int _outScaleY     = -1;
    int _outMarginLeft = -1;
    int _outMarginTop  = -1;
    int _charMarginX   = -1;
    int _charMarginY   = -1;

    // depending on font, console size and outbuf size,
    // compute the scaling and margins it needs.
    // Invalidate out and post buffer if that changed.
    void recomputeLayout()
    {
        int charW = charWidth();
        int charH = charHeight();

        // Find scale to multiply size of character by whole
        // amount.
        // eg: scale == 2 => each font pixel becomes 2x2
        //     pixel block.
        int scaleX = _outW / (_cols * charW);
        if (scaleX < 1)
            scaleX = 1;
        int scaleY = _outH / (_rows * charH);
        if (scaleY < 1)
            scaleY = 1;
        int scale = (scaleX < scaleY) ? scaleX : scaleY;

        // Compute remainder pixels in outbuf
        int remX = _outW - (_cols * charW) * scale;
        int remY = _outH - (_rows * charH) * scale;
        assert(remX <= _outW && remY <= _outH);
        if (remX < 0)
            remX = 0;
        if (remY < 0)
            remY = 0;

        int marginLeft;
        int marginTop;
        final switch(_options.halign)
        {
            case TM_horzAlignLeft:   marginLeft = 0;
                break;
            case TM_horzAlignCenter: marginLeft = remX/2;
                break;
            case TM_horzAlignRight:  marginLeft = remX;
                break;
        }

        final switch(_options.valign)
        {
            case TM_vertAlignTop:    marginTop  = 0;
                break;
            case TM_vertAlignMiddle: marginTop  = remY/2;
                break;
            case TM_vertAlignBottom: marginTop  = remY;
                break;
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
            updateFilterSize(cast(int)(0.5f + filterSize));
        }
    }

    // r is in text console coordinates
    // transform it in pixel coordinates
    rect_t transformRectToOutputCoord(rect_t r)
    {
        if (rectIsEmpty(r))
            return r;
        int cw = charWidth();
        int ch = charHeight();
        r.left   *= cw * _outScaleX;
        r.right  *= cw * _outScaleX;
        r.top    *= ch * _outScaleY;
        r.bottom *= ch * _outScaleY;
        r = rectTranslate(r, _outMarginLeft, _outMarginTop);
        return rectIntersection(r, rectOutput());
    }

    rect_t rectOutput()
    {
        return rect_t(0, 0, _outW, _outH);
    }

    // extend rect in output coordinates, by filter radius
    rect_t extendByFilterWidth(rect_t r)
    {
        r = rectGrow(r, _filterWidth / 2);
        r = rectIntersection(r, rectOutput());
        return r;
    }

    // since post and output have same coordinates
    alias transformRectToPostCoord
        = transformRectToOutputCoord;

    void updateTextBufferSize(int columns, int rows)
        @trusted
    {
        // PERF: could be one allocation
        if (_cols != columns || _rows != rows)
        {
            int n = columns * rows;
            size_t bytes = n * TM_CharData.sizeof;
            void* alloc = realloc_c17(_text.ptr, bytes * 2);
            _text  = (cast(TM_CharData*)alloc)[0..  n];
            _cache = (cast(TM_CharData*)alloc)[n..2*n];
            TM_CharData[] text = _text;
            TM_CharData[] cache = _cache;

            bytes = n * bool.sizeof;
            alloc = realloc_c17(_charDirty.ptr, bytes);
            _charDirty = (cast(bool*)alloc)[0..n];
            _cols = columns;
            _rows = rows;
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
            size_t npix = width * height;
            void* p = realloc_c17(_back.ptr, npix * 5);
            _back      = (cast(rgba_t*)p)[0..npix];
            _backFlags = (cast(ubyte*) p)[npix*4..npix*5];
            _backHeight = height;
            _backWidth = width;
        }
    }

    void updatePostBuffersSize(int width, int height)
        @trusted
    {
        if (width != _postWidth || height != _postHeight)
        {
            ubyte* p = null;
            size_t needed = layout(p, width, height);
            p = cast(ubyte*) realloc_c17(_post.ptr, needed);
            layout(p, width, height);
            _postWidth = width;
            _postHeight = height;
            _dirtyPost = true;
            invalidateBlur(false);
        }
    }

    size_t layout(ubyte* p, int width, int height) @trusted
    {
        ubyte* pold = p;
        size_t n = width * height;

        // YUV buffer has 2 more lines for sampling 2x2
        size_t n2 = width * (height + 2); 

        // scanline sized buffer
        size_t n3 = width;

        static void align16(ref ubyte* pt)
        {
            size_t asInt = cast(size_t)pt;
            size_t remainder = asInt & 15;
            size_t offset = (16 - remainder) & 15;
            pt += offset;
        }

        _post  = (cast(rgba_t*   )p)[0..n]; p += n * 4;
        _final = (cast(rgba_t*   )p)[0..n]; p += n * 4;
        _yuv   = (cast(YCbCrA_t* )p)[0..n2]; p += n2 * 4;
        _emit  = (cast(rgba16_t* )p)[0..n]; p += n * 8;
        _emitH = (cast(rgba16_t* )p)[0..n]; p += n * 8;
        align16(p);
        _yuvbuf = (cast(YCbCrA_t*)p)[0..n3]; p += n3 * 4;
        align16(p);
        _fxbuf = (cast(rgba32f_t*)p)[0..n3]; p += n3 * 16;
        align16(p);
        _blur  = (cast(rgba32f_t*)p)[0..n]; p += n * 16;
        return p - pold;
    }

    // called when blur needs to be wholly evaluated,
    // however it's so expensive we make it black and mark
    // it as such, since this saves computations.
    // See Issue #11.
    void invalidateBlur(bool blurPropertiesChanged) @trusted
    {
        size_t bytes = rgba32f_t.sizeof * _blur.length;
        memset(_blur.ptr, 0, bytes);

        // so that next invalidateChars can take that into
        // account.
        _blurIsCompletelyBlack = true;

        // Did the blur shape/lighting changed itself?
        // or was just a resize.
        _dirtyBlur = blurPropertiesChanged;

        // Must revalidate, since blur was cleared.
        _dirtyValidation = true;
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
            makeGaussianKernel(filterSize, sigma, mu,
                               _blurKernel[]);
            invalidateBlur(true);
            _dirtyFinal = true;
        }
    }

    void computeChangedColors()
    {
        for (int c = 0; c < 16; ++c)
        {
            bool differ = _palette[c] != _cachedPalette[c];
            _paletteChanged[c] = differ;
        }

        // Did the border color change?
        rgba_t borderColor = _palette[_options.borderColor];
        if (borderColor != _lastBorderColor)
            _dirtyPost = true;
        _lastBorderColor = borderColor;
    }

    // Reasons to redraw:
    //  - their fg or bg color changed
    //  - their fg or bg color PALETTE changed
    //  - glyph displayed changed
    //  - character is <blink> and time passed
    //  - font changed
    //  - size changed
    //
    // Returns: The rectangle of all text that needs to
    //          redrawn, in text coordinates.
    //          And rectangle of all text whose blur layer
    //          needs to be redrawn, in text coordinates.
    rect_t[2] invalidateChars()
    {
        // validation results might not need recompute
        if (!_dirtyValidation)
            return _lastBounds;

        _dirtyValidation = false;

        rect_t bounds,  // regular layer changes
               bBounds; // blur layer changes

        for (int row = 0; row < _rows; ++row)
        {
            for (int col = 0; col < _cols; ++col)
            {
                int icell = col + row * _cols;
                TM_CharData text  =  _text[icell];
                TM_CharData cache =  _cache[icell];

                TM_Style style  = text.style;
                TM_Style cstyle = cache.style;

                bool blink = (style & TM_styleBlink) != 0;
                bool shiny = (style & TM_styleShiny) != 0;
                bool cShiny = (cstyle & TM_styleShiny) != 0;
                bool blinkTick = _cachedBlinkOn != _blinkOn;

                // Dis this char graphics change?
                bool redraw = false;
                if (_dirtyAllChars)
                    redraw = true;
                else if (!equalCharData(text, cache))
                    redraw = true; // chardata changed
                else if (_paletteChanged[text.color & 0x0f])
                    redraw = true; // fg color changed
                else if (_paletteChanged[text.color >>> 4])
                    redraw = true; // bg color changed
                else if (blink && blinkTick)
                    redraw = true; // text blinked on or off

                if (redraw)
                    bounds = rectMergeWithPoint(bounds, col,
                                                row);

                // Did this char _blur_ layer change?
                // PERF: some palette change do not trigger
                //       blur changes, rare.

                // Reasons to recompute blur:
                // 1. A char changed its non-blur display,
                //    or the blur shape has changed,
                //    and the character is shiny.
                bool doBlur = (redraw || _dirtyBlur
                        || _blurIsCompletelyBlack) && shiny;
                // 2. A char lost its shininess, and the
                //    blur buffer isn't all black.
                if (!shiny
                    && cShiny
                    && !_blurIsCompletelyBlack)
                    doBlur = true;

                if (doBlur)
                    bBounds = rectMergeWithPoint(bBounds,
                                                 col, row);

                _charDirty[icell] = redraw;
            }
        }

        _blurIsCompletelyBlack = false;
        _dirtyBlur = false;

        _lastBounds[0] = bounds;
        _lastBounds[1] = bBounds;
        _cachedBlinkOn = _blinkOn;
        return _lastBounds;
    }

    // Draw all chars from _text to _back, no caching yet
    void drawAllChars(rect_t r)
    {
        for (int row = r.top; row < r.bottom; ++row)
        {
            for (int col = r.left; col < r.right; ++col)
            {
                if (_charDirty[col + _cols * row])
                    drawCharToBack(col, row);
            }
        }
    }

    // Draw from _back/_backFlags to _post/_emit
    // Returns changed rect, in pixels. One for out and one
    // for blur.
    rect_t[2] backToPost(rect_t[2] rect) @trusted
    {
        bool drawBorder = false;

        rect_t postRect = transformRectToPostCoord(rect[0]);
        rect_t blurRect = transformRectToPostCoord(rect[1]);

        if (_dirtyPost)
        {
            drawBorder = true;
        }


        if (drawBorder)
        {
            rgba_t border = _palette[_options.borderColor];

            // PERF: only draw the border areas
            size_t pl = _post.length;
            for (size_t p = 0; p < pl; ++p)
                _post[p] = border;

            // now also fill _emit, and since border is
            // never <shiny> (huh???)
            if (_options.borderShiny)
            {
                _emit[] = linearU16Premul(border);
                blurRect = rectWithCoords(0, 0,
                            _postWidth, _postHeight);
            }
            else
                _emit[] = rgba16_t(0, 0, 0, 0);

            postRect = rectWithCoords(0, 0,
                           _postWidth, _postHeight);
            rect[0] = rectWithCoords(0, 0, _cols, _rows);
            rect[1] = rect[0];
        }

        rect_t r = rect[0];

        // Which chars to copy, scale and margins applied?
        for (int row = r.top; row < r.bottom; ++row)
        {
            for (int col = r.left; col < r.right; ++col)
            {
                int charIndex = col + _cols * row;
                if (!(_charDirty[charIndex] || _dirtyPost))
                    continue; // char didn't change

                TM_Style style = _text[charIndex].style;
                bool shiny = (style & TM_styleShiny) != 0;
                copyCharBackToPost(col, row, shiny);
            }
        }
        _dirtyPost = false;
        return [postRect, blurRect];
    }

    void copyCharBackToPost(int col, int row, bool shiny)
        @trusted
    {
        int cw = charWidth();
        int ch = charHeight();

        int backPitch = _cols * cw;

        for (int y = row*ch; y < (row+1)*ch; ++y)
        {
            const(rgba_t)* backScan = &_back[backPitch * y];
            const(ubyte)* backFlags;
            backFlags = &_backFlags[backPitch * y];

            for (int x = col*cw; x < (col+1)*cw; ++x)
            {
                rgba_t fg   = backScan[x];
                ubyte flags = backFlags[x];
                bool isFg = (flags & BACK_IS_FG) != 0;
                bool fgCanEmit = _options.blurForeground;
                bool bgCanEmit = _options.blurBackground;
                bool thisCanEmit = ( isFg && fgCanEmit)
                                || (!isFg && bgCanEmit);

                bool emitLight = shiny && thisCanEmit;
                rgba16_t emit = rgba16_t(0, 0, 0, 0);
                if (emitLight)
                {
                    emit = linearU16Premul(fg);
                }

                int baseX = x * _outScaleX + _outMarginLeft;

                for (int yy = 0; yy < _outScaleY; ++yy)
                {
                    int posY = y * _outScaleY
                             + yy + _outMarginTop;
                    if (posY >= _outH)
                        continue;

                    int start = posY * _outW;
                    rgba_t*   postScan = &_post[start];
                    rgba16_t* emitScan = &_emit[start];

                    int minX = baseX;
                    int maxX = baseX + _outScaleX;
                    if (maxX > _outW) maxX = _outW;
                    int count = maxX - minX;

                    for (int xx = minX; xx < maxX; ++xx)
                    {
                        // copy pixel from _back to _post
                        postScan[xx] = fg;

                        // but also write its emissiveness
                        emitScan[xx] = emit;
                    }
                }
            }
        }
    }

    // Draw from _post to _out
    void postToOut(rect_t textRect) @trusted
    {
        rect_t r; // changed rectangle
        r = transformRectToOutputCoord(textRect);

        // Extend rect to account for blur
        r = extendByFilterWidth(r);

        if ( (!_options.allowOutCaching) || _dirtyOut)
        {
            // No cache, redraw everything from _post.
            // The buffer content wasn't preserved, so we do
            // it again.
            r = rectWithCoords(0, 0, _outW, _outH);
        }

        for (int y = r.top; y < r.bottom; ++y)
        {
            const(rgba_t)* postScan = &_final[_postWidth*y];
            rgba_t* outScan = cast(rgba_t*)(_outPixels
                                            + _outPitch*y);

            // Read one pixel, make potentially
            // several in output with nearest
            // resampling
            final switch (_options.blendMode)
            {
                case TM_blendCopy:
                    for (int x = r.left; x < r.right; ++x)
                        outScan[x] = postScan[x];
                    break;

                case TM_blendSourceOver:
                    for (int x = r.left; x < r.right; ++x)
                    {
                        rgba_t fg = postScan[x];
                        rgba_t bg = outScan[x];
                        rgba_t c = blendColor(fg, bg, fg.a);
                        outScan[x] = c;
                    }
                    break;
            }
        }

        _dirtyOut = false;
    }

    void drawCharToBack(int col, int row) @trusted
    {
        TM_CharData cdata = charAt(col, row);
        int cw = charWidth();
        int ch = charHeight();
        ubyte fgi = cdata.color & 15;
        ubyte bgi = cdata.color >>> 4;
        rgba_t fgCol = _palette[ cdata.color &  15 ];
        rgba_t bgCol = _palette[ cdata.color >>> 4 ];
        const(ubyte)[] glyphData = getGlyphData(_font,
                                               cdata.glyph);
        assert(glyphData.length == 8);
        bool bold  = (cdata.style & TM_styleBold ) != 0;
        bool under = (cdata.style & TM_styleUnder) != 0;
        bool blink = (cdata.style & TM_styleBlink) != 0;
        for (int y = 0; y < ch; ++y)
        {
            const int yback = row * ch + y;
            int bits  = glyphData[y];

            if ( (y == ch - 1) && under)
                bits = 0xff;

            if (bold)
                bits |= (bits >> 1);

            if (blink && !_blinkOn)
                bits = 0;

            int idx = (_cols * cw) * yback + (col * cw);
            rgba_t* pixels = &_back[idx];
            ubyte*  flags  = &_backFlags[idx];
            if (bits == 0) // speed-up empty lines
            {
                flags[0..cw]  = 0;     // all bg
                pixels[0..cw] = bgCol;
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

    // copy _post to _final (same space)
    // _final is _post + filtered _emissive
    void applyBlur(rect_t updateRect) @trusted
    {
        rect_t wholeOut = rectWithCoords(0, 0,
                                         _postWidth,
                                         _postHeight);


        if (updateRect.isEmpty)
            return;

        int filter_2 = _filterWidth / 2;

        rect_t rH = rectGrowXY(updateRect, filter_2,0);
        rect_t rV = rectGrow(updateRect, filter_2);
        rH = rectIntersection(rH, wholeOut);
        rV = rectIntersection(rV, wholeOut);

        // blur emissive horizontally, from _emit to _emitH
        // the updated area is updateRect, enlarged
        // horizontally.
        for (int y = rH.top; y < rH.bottom; ++y)
        {
            rgba16_t* emitScan  = &_emit[_postWidth * y];

            for (int x = rH.left; x < rH.right; ++x)
            {
                int postWidth = _postWidth;
                if (x < 0 || x >= _postWidth)
                    assert(false);
                __m128 mmC = _mm_setzero_ps();

                float[] kernel = _blurKernel;
                for (int n = -filter_2; n <= filter_2; ++n)
                {
                    int xe = x + n;
                    if (xe < 0 || xe >= _postWidth)
                        continue;
                    rgba16_t e = emitScan[xe];
                    __m128i mmE;
                    mmE = _mm_setr_epi32(e.r,e.g,e.b,e.a);
                    float w = _blurKernel[filter_2 + n];
                    __m128 ew = _mm_cvtepi32_ps(mmE)
                              * _mm_set1_ps(w);
                    mmC = mmC + ew;
                }

                // store result transposed in _emitH
                // for faster convolution in Y afterwards
                rgba16_t* emitH = &_emitH[_postHeight*x+y];
                __m128i mmRes = _mm_cvttps_epi32(mmC);
                mmRes = _mm_packus_epi32(mmRes, mmRes);
                _mm_storeu_si64(emitH, mmRes);
            }
        }

        // blur vertically
        for (int y = rV.top; y < rV.bottom; ++y)
        {
            if (y < 0 || y >= _postHeight)
                assert(false);

            rgba32f_t* blurScan = &_blur[_postWidth * y];

            for (int x = rV.left; x < rV.right; ++x)
            {
                __m128 mmC = _mm_setzero_ps();

                if (x < 0) assert(false);
                if (x >= _postWidth) assert(false);

                const(rgba16_t)* emitHScan;
                emitHScan = &_emitH[_postHeight * x];

                for (int n = -filter_2; n <= filter_2; ++n)
                {
                    int ye = y + n;
                    if (ye < 0) continue;
                    if (ye >= _postHeight) continue;
                    rgba16_t e = emitHScan[ye];
                    float w = _blurKernel[filter_2 + n];
                    __m128i mmE;
                    mmE = _mm_setr_epi32(e.r,e.g,e.b,e.a);
                    __m128 ew = _mm_cvtepi32_ps(mmE)
                              * _mm_set1_ps(w);
                    mmC = mmC + ew;
                }
                mmC = _mm_sqrt_ps(mmC);
                if (_options.noiseTexture)
                {
                    // so that the user has easier tuning
                    enum float NSCALE = 0.0006f;
                    float noiseAmount= _options.noiseAmount;
                    noiseAmount *= NSCALE;

                    float noise = NOISE_16x16[(x & 15)*16
                                + (y & 15)];

                    noise = (noise - 127.5f) * noiseAmount;
                    mmC = mmC * (1.0f + noise);
                }
                _mm_storeu_ps(cast(float*)&blurScan[x],mmC);
            }
        }
    }

    void applyEffects(rect_t r) @trusted
    {
        int W = _postWidth;
        int H = _postHeight;

        rect_t whole = rectWithCoords(0, 0, _outW, _outH);
        if (_dirtyFinal)
        {
            r = whole;
            _dirtyFinal = false;
        }

        if (r.isEmpty)
            return;

        r = rectGrow(r, _filterWidth / 2);
        r = rectIntersection(r, whole);

        // Compute YCbCr buffer for CRT emulation
        // else computing 4:2:0 is too expensive
        if (_options.crtEmulation)
        {
            assert(_yuv.length == (_outH+2) * _outW);
            for (int y = r.top; y < r.bottom; ++y)
            {
                const(rgba_t)*    postS;
                YCbCrA_t*         yuvS;
                postS = &_post[_postWidth * y];
                yuvS  = &_yuv[_postWidth * y];

                int count = r.right - r.left;
                convertRGBA8ToBT601(&yuvS[r.left], &postS[r.left], count);
            }

            YCbCrA_t[] yuv = _yuv;

            // if last line is touched, replicate on last
            // two lines of _yuv buffer (only first pixel
            // of last lines need to be replicated though)
            if (r.bottom >= _postHeight)
            {
                yuv[W*H .. W*(H+1)] = yuv[W*(H-1) .. W*H];
                yuv[W*(H+1)] = yuv[W*H];
            }
        }

        float vCx = _options.vignettingCenterX * (W-1);
        float vCy = _options.vignettingCenterY * (H-1);
        float outBufDiagonal = sqrt( cast(float)(W*W)+(H*H) );
        float maxDistVignetting = _options.vignettingDistance *
                                  outBufDiagonal / 2;

        // vignetting color in 4xfloat form
        __m128 vigColor = _mm_setr_ps(_options.vignettingColor[0],
                                      _options.vignettingColor[1],
                                      _options.vignettingColor[2],
                                      _options.vignettingColor[3]);

        const(YCbCrA_t)* pYUV = _yuv.ptr;

        for (int y = r.top; y < r.bottom; ++y)
        {
            const(rgba_t)*    postS;
            const(rgba32f_t)* blurS;
            rgba_t*           finalScan;
            rgba32f_t*        fxbufS;
            YCbCrA_t*         yuvbufS;
            rgba_t*           yuvbufS2;

            postS     = &_post[_postWidth * y];
            blurS     = &_blur[_postWidth * y];
            finalScan = &_final[_postWidth * y];
            fxbufS    = &_fxbuf[0];
            yuvbufS   = &_yuvbuf[0];
            yuvbufS2  = cast(rgba_t*)yuvbufS;

            bool chromaNoise = ((y / _outScaleY) & 3) != 0;

            int N = r.right - r.left;

            if ( ! _options.crtEmulation)
            {
                // just convert u8 to float from post buffer to fxbuf
                __m128i zero = _mm_setzero_si128();
                for (int x = r.left; x < r.right; ++x)
                {
                    __m128i post = _mm_loadu_si32(&postS[x]);                    
                    post = _mm_unpacklo_epi8(post, zero);
                    post = _mm_unpacklo_epi16(post, zero);
                    __m128 postF = _mm_cvtepi32_ps(post);
                    _mm_store_ps(cast(float*)&fxbufS[x], postF);
                }
            }
            else
            {
                // 3 effects here:
                // - chroma downsampling
                // - chroma quantization
                // - chroma noise

                for (int x = r.left; x < r.right; ++x)
                {
                    // PERF: downsampling could be done in _yuv
                    // buffer instead.
                    
                    // Find 4 pixels in the 2x2 patch,
                    // and the one we are in too `P`.
                    // _yuv is extended for that being
                    // possible, but top-right pixel is from
                    // next-line.
                    //
                    // A B   one of them being P
                    // C D
                    //
                    int x_2 = x & ~1;
                    int y_2 = y & ~1;
                    int i0 = W * y_2   + x_2;
                    int scaleX = _outScaleX;
                    int scaleY = _outScaleY;
                    YCbCrA_t P_YCbCr = pYUV[W * y + x];

                    // PERF: merge reads there
                    YCbCrA_t A = pYUV[i0];
                    YCbCrA_t B = pYUV[i0 + 1];
                    YCbCrA_t C = pYUV[i0 + W];
                    YCbCrA_t D = pYUV[i0 + W + 1];

                    // chroma is subsampled 4:2:0
                    // This is a bit blurry but give that nosltagic feel,
                    // even though it's not so much CRT rather than "old video"
                    // PERF: user _mm_avg intrin
                    P_YCbCr.Cb = (A.Cb + C.Cb
                                + B.Cb + D.Cb + 2) / 4;
                    P_YCbCr.Cr = (A.Cr + C.Cr
                                + B.Cr + D.Cr + 2) / 4;

                    // FUTURE: could be a noise more CRT-ish
                    // this one can be pretty obvious
                    // this really looks like JPEG
                    if (chromaNoise)
                    {
                        // Quantize chroma + randomize last bits
                        int Cb_noise = (x/scaleX)       & 0xff;
                        int Cr_noise = ((x+128)/scaleX) & 0xff;
                        P_YCbCr.Cb = (P_YCbCr.Cb & 0xfc)
                                   + (NOISE_16x16[Cb_noise]>>>6);
                        P_YCbCr.Cr = (P_YCbCr.Cr & 0xfc)
                                   + (NOISE_16x16[Cr_noise]>>>6);
                    }
                    yuvbufS[x] = P_YCbCr;
                }

                //  Convert back in RGB (in-place actually)
                convertBT601ToRGBInPlace(&yuvbufS[r.left], &yuvbufS2[r.left], N);

                for (int x = r.left; x < r.right; ++x)
                {
                    rgba_t subsmp = yuvbufS2[x];

                    // Blend additional RGB matrix to
                    // simulate a screen.
                    // PERF: grossly unoptimized
                    ubyte offset = (y % 3) != 0 ? 8 : 0;
                    switch((x) % 3)
                    {
                        case 0:
                            if (subsmp.r+offset>255)
                                subsmp.r = 255;
                            else
                                subsmp.r += offset;
                            break;
                        case 1:
                            if (subsmp.g +offset > 255)
                                subsmp.g = 255;
                            else
                                subsmp.g += offset;
                            break;
                        case 2:
                            if (subsmp.b+offset > 255)
                                subsmp.b = 255;
                            else
                                subsmp.b += offset;
                            break;
                        default: break;
                    }
                    __m128i post = _mm_loadu_si32(&subsmp);

                    __m128i zero = _mm_setzero_si128();
                    post = _mm_unpacklo_epi8(post, zero);
                    post = _mm_unpacklo_epi16(post, zero);
                    __m128 postF = _mm_cvtepi32_ps(post);
                    _mm_store_ps(cast(float*)&fxbufS[x], postF);
                }
            }

            // Add blur
            for (int x = r.left; x < r.right; ++x)
            {
                __m128 postF = _mm_load_ps(cast(const(float)*) &fxbufS[x]);

                __m128 blurAmt;
                blurAmt = _options.blurAmount;
                __m128 blur;
                blur = _mm_loadu_ps(cast(float*)&blurS[x]); // PERF align this load

                // Add blur
                __m128 RGB = postF + blur * blurAmt;

                _mm_store_ps(cast(float*) &fxbufS[x], RGB);
            }


            if (_options.vignetting)
            {
                for (int x = r.left; x < r.right; ++x)
                {
                    __m128 RGB = _mm_load_ps(cast(const(float)*) &fxbufS[x]);


                    float dist2 = (vCx-x)*(vCx-x)+(vCy-y)*(vCy-y);
                    float amt = sqrt(dist2) / maxDistVignetting;
                    assert(amt >= 0);
                    if (amt > 1)
                        amt = 1;
                    amt *= _options.vignettingOpacity;

                    // Note: clamped by subsequent code
                    RGB = RGB + (vigColor - RGB) * amt;

                    _mm_store_ps(cast(float*) &fxbufS[x], RGB);
                }
            }

            if (_options.tonemapping)
            {
                for (int x = r.left; x < r.right; ++x)
                {
                    __m128 RGB = _mm_load_ps(cast(const(float)*) &fxbufS[x]);

                    // PERF: SIMD
                    // Similar tonemapping as Dplug.
                    float tmThre  = 255.0f;
                    float tmRat = _options.tonemappingRatio;
                    float eR = RGB.array[0] - tmThre;
                    float eG = RGB.array[1] - tmThre;
                    float eB = RGB.array[2] - tmThre;
                    eR = TM_max32f(0.0f, eR);
                    eG = TM_max32f(0.0f, eG);
                    eB = TM_max32f(0.0f, eB);
                    float exceedLuma = 0.3333f * eR
                                     + 0.3333f * eG
                                     + 0.3333f * eB;

                    // Add excess energy in all channels
                    RGB.ptr[0] += exceedLuma * tmRat;
                    RGB.ptr[1] += exceedLuma * tmRat;
                    RGB.ptr[2] += exceedLuma * tmRat;

                    _mm_store_ps(cast(float*) &fxbufS[x], RGB);
                }
            }

            // back to u8
            for (int x = r.left; x < r.right; ++x)
            {
                __m128 RGB = _mm_load_ps(cast(const(float)*) &fxbufS[x]);
                __m128i zero = _mm_setzero_si128();
                __m128i finalCol = _mm_cvttps_epi32(RGB);
                finalCol = _mm_packs_epi32(finalCol, zero);
                finalCol = _mm_packus_epi16(finalCol, zero);
                _mm_storeu_si32(&finalScan[x], finalCol);
            }
        }
    }

    uint hashPalettePlusXP(const(void)[] xpBytes)
    {
        // hash _palette, since the decoded XP is only 
        // valid for a particular palette.
        uint hash = hashFNV1A32(xpBytes);
        hash = hashFNV1A32(_palette, hash);
        return hash;
    }

    static struct XPCacheItem
    {
        uint hash;
        TM_Image* cachedImage; // itself allocated on heap
    }        

    XPCacheItem* _xpCache;

    // return true if was in cache, false if just created
    // it's a stupid linear cache since we don't have yet 
    // a usecase with many .xp, and in a B-tree the item count 
    // would be likely > 30 in a single node, so...
    bool getOrCreateImage(uint hash, out TM_Image* result)
        @trusted
    {
        int cached = sb_count(_xpCache);
        for (int c = 0; c < cached; ++c)
        {
            if (hash == _xpCache[c].hash)
            {
                result = _xpCache[c].cachedImage;
                return true; // hit
            }
        }
        // create a new TM_Image storage
        // fortunately it needs no ctor

        XPCacheItem item;
        item.hash = hash;
        item.cachedImage = cast(TM_Image*) malloc(TM_Image.sizeof);
        item.cachedImage.initialize();
        sb_push!XPCacheItem(_xpCache, item);
        result = _xpCache[cached].cachedImage; // borrow
        return false;
    }
}


/**
    An image composed of TM_CharData cells with a specific 
    width and height. This is an intermediate format for 
    decoded .xp buffers.
*/
struct TM_Image
{
nothrow:
@nogc:
@safe:

    /// Width of the image in characters.
    int width = 0;

    /// Height of the image in characters.
    int height = 0;

    /// Layers in this image, all have same width and height
    int layers = 0;

    /// The character data array (width * height * layers elements).
    /// If a layer is null, no data there.
    TM_CharData[] data;

    // Important, if we assign an uninitialized TM_Image
    // with TM_Image.init, then it may crash! probably calling dtor (!)
    // TODO: report upstream
    void initialize()
    {
        width = 0;
        height = 0;
        layers = 0;
        data = null;
    }

    @disable this(this); // create issues in containers

    ref inout(TM_CharData) charAt(int layer, int col, int row) pure inout return
    {
        return data[layer * width * height + row * width + col];
    }

    void resize(int numLayers, int newWidth, int newHeight) @trusted
    {
        // need allocate
        int newSize     = newWidth * newHeight * numLayers;
        int currentSize = width    * height    * layers;
        
        if (newSize > currentSize)
        {
            size_t bytes = newSize * TM_CharData.sizeof;
            void* alloc = realloc_c17(data.ptr, bytes);

            data = (cast(TM_CharData*)alloc)[0..newSize];

            // fill with non-character (special value for transparent)
            for (int s = 0; s < newSize; ++s)
                data[s].glyph = dchar.init;

            width = newWidth;
            height = newHeight;
            layers = numLayers;
        }
    }

    void release() @trusted
    {
        free(data.ptr);
        data = null;
    }

    ~this()
    {
        release();
    }
}


// *********************************************************
// *********************** PRIVATE *************************
// *********************************************************
private:
// *********************************************************
// ***********************  BELOW  *************************
// *********************************************************

struct rgba_t
{
    ubyte r, g, b, a;
}
static assert(rgba_t.sizeof == 4);

struct rgba16_t
{
    ushort r, g, b, a;
}
static assert(rgba16_t.sizeof == 8);

struct rgba32f_t
{
    float r, g, b, a;
}
static assert(rgba32f_t.sizeof == 16);

struct YCbCrA_t
{
    ubyte Y, Cb, Cr, a;    
}
static assert(YCbCrA_t.sizeof == 4);


YCbCrA_t RGBToBT601(rgba_t c)
{
    ubyte Y  = (cast(ushort)( 66 * c.r + 129 * c.g +  25 * c.b + 4096)) >>> 8;
    ubyte Cb = (cast(ushort)(-38 * c.r -  74 * c.g + 112 * c.b + 32768)) >>> 8;
    ubyte Cr = (cast(ushort)(127 * c.r - 106 * c.g -  21 * c.b + 32768)) >>> 8;

   // On Microsoft website:
   // ubyte Cr = (cast(ushort)(112 * c.r - 94 * c.g -  18 * c.b + 32768)) >>> 8;


    YCbCrA_t r;
    r.Y  = Y;
    r.Cb = Cb;
    r.Cr = Cr;
    r.a = c.a;
    return r;
}

// TODO: move that to intel-intrinsics
__m128i _mm_movelh_epi32 (__m128i a, __m128i b) pure @trusted
{    
    a.ptr[2] = b.array[0];
    a.ptr[3] = b.array[1];
    return a;
}

__m128i _mm_movehl_epi32 (__m128i a, __m128i b) pure @trusted
{
    a.ptr[0] = b.array[2];
    a.ptr[1] = b.array[3];
    return a;
}

void _MM_TRANSPOSE4_EPI32 (ref __m128i row0, ref __m128i row1, ref __m128i row2, ref __m128i row3) pure @safe
{
    __m128i tmp3, tmp2, tmp1, tmp0;
    tmp0 = _mm_unpacklo_epi32(row0, row1);
    tmp2 = _mm_unpacklo_epi32(row2, row3);
    tmp1 = _mm_unpackhi_epi32(row0, row1);
    tmp3 = _mm_unpackhi_epi32(row2, row3);
    row0 = _mm_movelh_epi32(tmp0, tmp2);
    row1 = _mm_movehl_epi32(tmp2, tmp0);
    row2 = _mm_movelh_epi32(tmp1, tmp3);
    row3 = _mm_movehl_epi32(tmp3, tmp1);
}

// FUTURE: could be more precise actually. See convertBT601ToRGBInPlace which used 19.13 fixed point
void convertRGBA8ToBT601(YCbCrA_t* yuv, const(rgba_t)* rgba, int count) @system
{
    __m128i zero = _mm_setzero_si128();
    int n = 0;
    for (; n + 3 < count; n += 4)
    {
        // PERF: not optimal for A
        // Read 4 pixels
        __m128i input    = _mm_loadu_si128(cast(const(__m128i)*) &rgba[n]); // R0 G0 B0 A0 R1 G1 B1 A1 R2 G2 B2 A2 R3 G3 B3 A3
        __m128i pixels01 = _mm_unpacklo_epi8(input, zero); // R0 G0 B0 A0 R1 G1 B1 A1
        __m128i pixels23 = _mm_unpackhi_epi8(input, zero); // R2 G2 B2 A2 R3 G3 B3 A3

        const __m128i mulY  = _mm_setr_epi16( 66,  129,  25, 0,  66,  128,  25, 0);
        const __m128i mulCb = _mm_setr_epi16(-38,  -74, 112, 0, -38,  -74, 112, 0);
        const __m128i mulCr = _mm_setr_epi16(127, -106, -21, 0, 127, -106, -21, 0);
        const __m128i mulA  = _mm_setr_epi16(  0,    0,   0, 256, 0,    0,   0, 256);

        __m128i pixels01_Y = _mm_madd_epi16(pixels01, mulY);
        __m128i pixels23_Y = _mm_madd_epi16(pixels23, mulY);
        __m128i A = _mm_hadd_epi32(pixels01_Y, pixels23_Y); // Y0 Y1 Y2 Y3

        __m128i pixels01_Cb = _mm_madd_epi16(pixels01, mulCb);
        __m128i pixels23_Cb = _mm_madd_epi16(pixels23, mulCb);
        __m128i B = _mm_hadd_epi32(pixels01_Cb, pixels23_Cb); // Cb0 Cb1 Cb2 Cb3

        __m128i pixels01_Cr = _mm_madd_epi16(pixels01, mulCr);
        __m128i pixels23_Cr = _mm_madd_epi16(pixels23, mulCr);
        __m128i C = _mm_hadd_epi32(pixels01_Cr, pixels23_Cr); // Cr0 Cr1 Cr2 Cr3

        __m128i pixels01_A = _mm_madd_epi16(pixels01, mulA);
        __m128i pixels23_A = _mm_madd_epi16(pixels23, mulA);
        __m128i D = _mm_hadd_epi32(pixels01_A, pixels23_A); // A0 A1 A2 A3

        _MM_TRANSPOSE4_EPI32(A, B, C, D);

        __m128i rounding = _mm_setr_epi32(4096, 32768, 32768, 128);

        A = _mm_srli_epi32( _mm_add_epi32(A, rounding), 8); // Y0 Cb0 Cr0 A0
        B = _mm_srli_epi32( _mm_add_epi32(B, rounding), 8); // Y1 Cb1 Cr1 A1
        C = _mm_srli_epi32( _mm_add_epi32(C, rounding), 8); // Y2 Cb2 Cr2 A2
        D = _mm_srli_epi32( _mm_add_epi32(D, rounding), 8); // Y3 Cb3 Cr3 A3

        __m128i output01 = _mm_packs_epi32(A, B);
        __m128i output23 = _mm_packs_epi32(C, D);
        __m128i output0123 = _mm_packus_epi16(output01, output23);
        _mm_storeu_si128(cast(__m128i*) &yuv[n], output0123);
    }

    for (; n < count; ++n)
    {
        yuv[n] = RGBToBT601(rgba[n]);
    }
}

// FUTURE: interesting "broken" effect if you only convert 1 out of 4 pixels...
//         try 1 out of 2 also!
// in and out can be the same pointer
void convertBT601ToRGBInPlace(YCbCrA_t* inBuf, rgba_t* outBuf, int N) @trusted
{
    // 13-bit fixed point coefficients
    // Bitness was reduced until it all fits in a short
    enum short YSCALE = 9539;  // 1.16438356164 
    enum short CR_R   = 13075; // 1.59602678571
    enum short CB_G   = 3209;  // 0.39176229009
    enum short CR_G   = 6660;  // 0.81296764723
    enum short CB_B   = 16525; // 2.01723214286
    enum short ONE    = 8192;  // 1.0

    int n = 0;

    for ( ; n + 3 < N; n += 4)
    {
        __m128i Z = _mm_setzero_si128();
        __m128i pixels0123 = _mm_loadu_si128( cast(const(__m128i)*) &inBuf[n] );
        __m128i pixels01 = _mm_unpacklo_epi8(pixels0123, Z); // R0 G0 B0 A0 R1 G1 B1 A1
        __m128i pixels23 = _mm_unpackhi_epi8(pixels0123, Z); // R2 G2 B2 A2 R3 G3 B3 A3
         const __m128i mulR = _mm_setr_epi16(YSCALE, 0, CR_R, 0, YSCALE, 0, CR_R, 0); // to compute reds
         const __m128i mulG = _mm_setr_epi16(YSCALE, -CB_G, -CR_G, 0, YSCALE, -CB_G, -CR_G, 0); // to compute green
         const __m128i mulB = _mm_setr_epi16(YSCALE, CB_B, 0, 0, YSCALE, CB_B, 0, 0); // to compute blue
         const __m128i mulA = _mm_setr_epi16(0, 0, 0, ONE, 0, 0, 0, ONE); // to compute alpha

        __m128i offset = _mm_setr_epi16(-16, -128, -128, 0, -16, -128, -128, 0);
        pixels01 = _mm_add_epi16(pixels01, offset);
        pixels23 = _mm_add_epi16(pixels23, offset);

        __m128i pixels01_R = _mm_madd_epi16(pixels01, mulR);
        __m128i pixels23_R = _mm_madd_epi16(pixels23, mulR);
        __m128i A = _mm_hadd_epi32(pixels01_R, pixels23_R); // R0 R1 R2 R3

        __m128i pixels01_G = _mm_madd_epi16(pixels01, mulG);
        __m128i pixels23_G = _mm_madd_epi16(pixels23, mulG);
        __m128i B = _mm_hadd_epi32(pixels01_G, pixels23_G); 

        __m128i pixels01_B = _mm_madd_epi16(pixels01, mulB);
        __m128i pixels23_B = _mm_madd_epi16(pixels23, mulB);
        __m128i C = _mm_hadd_epi32(pixels01_B, pixels23_B);

        __m128i pixels01_A = _mm_madd_epi16(pixels01, mulA);
        __m128i pixels23_A = _mm_madd_epi16(pixels23, mulA);
        __m128i D = _mm_hadd_epi32(pixels01_A, pixels23_A);

        _MM_TRANSPOSE4_EPI32(A, B, C, D);

        A = _mm_srai_epi32( A, 13); // R0 G0 B0 A0
        B = _mm_srai_epi32( B, 13); // R1 G1 B1 A1
        C = _mm_srai_epi32( C, 13); // R2 G2 B2 A2
        D = _mm_srai_epi32( D, 13); // R3 G3 B3 A3
        __m128i output01 = _mm_packs_epi32(A, B);
        __m128i output23 = _mm_packs_epi32(C, D);
        __m128i output0123 = _mm_packus_epi16(output01, output23);
        _mm_storeu_si128(cast(__m128i*) &outBuf[n], output0123);
    }

    for ( ; n < N; ++n)
    {
        YCbCrA_t c = inBuf[n];

        int Y  = c.Y - 16;
        int Cb = c.Cb - 128;
        int Cr = c.Cr - 128;    

        // Fixed-point calculation
        int R = (YSCALE * Y               + CR_R * Cr) >> 13;
        int G = (YSCALE * Y - CB_G * Cb   - CR_G * Cr) >> 13;
        int B = (YSCALE * Y + CB_B * Cb              ) >> 13;

        rgba_t col;
        col.r = clamp0_255(R);
        col.g = clamp0_255(G);
        col.b = clamp0_255(B);
        col.a = c.a;
        outBuf[n] = col;
    }
}

// FUTURE: our BT601 conversion doesn't get back to the same value
// which isn't so dire, as it's used as an effect...

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

rgba_t blendColor(rgba_t fg, rgba_t bg, ubyte alpha) 
    pure @trusted
{
    ubyte invAlpha = cast(ubyte)(~cast(int)alpha);
     // [ alpha invAlpha... (4x)]
    __m128i alphaMask;
    alphaMask = _mm_set1_epi32((invAlpha << 16)|alpha);
    __m128i mmfg = _mm_cvtsi32_si128( *cast(int*)(&fg) );
    __m128i mmbg = _mm_cvtsi32_si128( *cast(int*)(&bg) );
    __m128i zero = _mm_setzero_si128();
    // [fg.r bg.r fg.g bg.g fg.b bg.b fg.a bg.a 0 (8x) ]
    __m128i colorMask = _mm_unpacklo_epi8(mmfg, mmbg);
    // [fg.r bg.r fg.g bg.g fg.b bg.b fg.a bg.a ]
    colorMask = _mm_unpacklo_epi8(colorMask, zero);
     // [ fg[i]*alpha+bg[i]*invAlpha (4x) ]
    __m128i product = _mm_madd_epi16(colorMask, alphaMask);

    // To divide a ushort by 255, LLVM suggests to
    // * sign multiply by 32897
    // * right-shift logically by 23
    // Thanks https://godbolt.org/
    version(LDC)
        product *= _mm_set1_epi32(32897);
    else
    {
        product[0] *= 32897;
        product[1] *= 32897;
        product[2] *= 32897;
        product[3] *= 32897;
    }
    product = _mm_srli_epi32(product, 23);
    __m128i c = _mm_packs_epi32(product, zero);
    c = _mm_packus_epi16(c, zero);
    rgba_t result = void;
    *cast(int*)(&result) = c[0];
    return result;
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


// IMPORTANT: all palette here have first color alpha at 0
// in order to make the console transparent by default.
// But, actual palettes didn't have that color 0 as 
// transparent.

static immutable uint[16][TM_PALETTE_NUM] PALETTE_DATA =
[
    // Vintage (also: Windows XP console)
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

    // VGA/CGA/EGA
    [ 0x00000000, 0xAA0000ff, 0x00AA00ff, 0xAA5500ff,
      0x0000AAff, 0xAA00AAff, 0x00AAAAff, 0xAAAAAAff,
      0x555555ff, 0xff5555ff, 0x55ff55ff, 0xffff55ff,
      0x5555ffff, 0xff55ffff, 0x55ffffff, 0xffffffff ],

    // Windows 10 console
    [ 0x0c0c0c00, 0xC50F1Fff, 0x13A10Eff, 0xC19C00ff,
      0x0037DAff, 0x881798ff, 0x3A96DDff, 0xCCCCCCff,
      0x767676ff, 0xE74856ff, 0x16C60Cff, 0xF9F1A5ff,
      0x3B78FFff, 0xB4009Eff, 0x61D6D6ff, 0xF2F2F2ff ],

    // VSCode
    [ 0x00000000, 0xCD3131ff, 0x0DBC79ff, 0xE5E510ff,
      0x2472C8ff, 0xBC3FBCff, 0x11A8CDff, 0xE5E5E5ff,
      0x666666ff, 0xF14C4Cff, 0x23D18Bff, 0xF5F543ff,
      0x3B8EEAff, 0xD670D6ff, 0x29B8DBff, 0xE5E5E5ff ],

    // Gruvbox dark mode
    // https://github.com/morhetz/gruvbox
    [ 0x28282800, 0xCC241Dff, 0x98971Aff, 0xD79921ff,
      0x458588ff, 0xB16286ff, 0x689D6Aff, 0xA89984ff,
      0x928374ff, 0xFB4934ff, 0xB8BB26ff, 0xFABD2Fff,
      0x83A598ff, 0xD3869Bff, 0x8EC07Cff, 0xEBDBB2ff ],

    // Nyx, inspired from Hades I Nyx character
    // https://www.supergiantgames.com/
    [ 0x0a071800, 0x91114cff, 0x2a2e33ff, 0x5f5240ff,
      0x23263eff, 0x7329a2ff, 0xbdbbeeff, 0x9aa2a9ff,
      0x565b69ff, 0xfd116cff, 0x859480ff, 0xe6cd6bff,
      0x3a3a85ff, 0x9d2be9ff, 0x60c6f1ff, 0xefeef1ff ],

    // Graillon, inspired by Graillon interface
    // https://www.auburnsounds.com/
    [ 0x0b070f00, 0x4a3441ff, 0x7e9e8fff, 0x593d20ff,
      0x2e3084ff, 0x8b326fff, 0x7c93b3ff, 0x917f83ff,
      0x3d2d37ff, 0xe96979ff, 0xa9efadff, 0xff9f74ff,
      0x5f74ffff, 0xe652b7ff, 0x97ebebff, 0xe7dcdeff ],

    // Couture-inspired palette: grey, white, black, red
    // Clearly lacks mauve, blue, green, cyan
    [ 0x1b1d2800, 0x832539ff, 0xb2b3bdff, 0x832539ff,
      0xb1b3bcff, 0x832539ff, 0xb1b3bcff, 0xb1b2bcff,
      0x3b3e47ff, 0xd43e49ff, 0xe5e7e2ff, 0xd43e49ff,
      0xe5e7e2ff, 0xd43e49ff, 0xe5e7e2ff, 0xe5e7e2ff ],

    // Renegate-inspired palette
    // has inverted orange/yellow and red
    [ 0x03121200, 0xb38769ff, 0x72897aff, 0x6f4e4dff,
      0x0ca9bbff, 0x7a5b6aff, 0x0ca9bbff, 0x6d7977ff,
      0x4a4a48ff, 0xffce96ff, 0x88ab7aff, 0xfdb0b0ff,
      0x96f8f8ff, 0x9b7486ff, 0x96f8f8ff, 0xfff8f8ff ],
];

alias TM_RangeFlags = int;
enum : TM_RangeFlags
{
    // the whole range has the same glyph
    TM_singleGlyph = 1
}

struct TM_UniRange
{
    dchar start, stop;
    const(ubyte)[] glyphData;
    TM_RangeFlags flags = 0;
}

struct TM_FontDesc
{
    int[2] charSize;
    TM_UniRange[] fontData;
}

int[2] fontCharSize(TM_Font font) pure
{
    return BUILTIN_FONTS[font].charSize;
}

const(ubyte)[] getGlyphData(TM_Font font, dchar glyph) pure
{
    assert(font == TM_font8x8);
    const(TM_UniRange)[] fd = BUILTIN_FONTS[font].fontData;

    int ch = 8;
    for (size_t r = 0; r < fd.length; ++r)
    {
        if (glyph >= fd[r].start && glyph < fd[r].stop)
        {
            TM_RangeFlags flags = fd[r].flags;

            if ( (flags & TM_singleGlyph) != 0)
                return fd[r].glyphData[0..ch];

            uint index = glyph - fd[r].start;
            return fd[r].glyphData[index*ch..index*ch+ch];
        }
    }

    // Return notdef glyph
    return NOT_DEF[0..8];
}


static immutable TM_FontDesc[1] BUILTIN_FONTS =
[
    // TODO:
    // U+FF11 U+FF12 U+FF18 U+3000 U+FF2B U+FF22


    TM_FontDesc([8, 8],
    [
        TM_UniRange(0x0000, 0x0020, EMPTY, TM_singleGlyph),
        TM_UniRange(0x0020, 0x0080, BASIC_LATIN),
        TM_UniRange(0x0080, 0x00A0, EMPTY, TM_singleGlyph),
        TM_UniRange(0x00A0, 0x0100, LATIN1_SUPP),
        TM_UniRange(0x0390, 0x03D0, GREEK_AND_COPTIC),
        TM_UniRange(0x2020, 0x2030, GENERAL_PUNCTUATION),
        TM_UniRange(0x2122, 0x2123, LETTERLIKE_SYMBOLS),
        TM_UniRange(0x2190, 0x219A, ARROWS),
        TM_UniRange(0x2200, 0x2270, MATH_OPERATORS),
        TM_UniRange(0x2300, 0x2322, MISC_TECHNICAL),
        TM_UniRange(0x23CE, 0x23D0, MISC_TECHNICAL2),
        TM_UniRange(0x2500, 0x2580, BOX_DRAWING),
        TM_UniRange(0x2580, 0x25A0, BLOCK_ELEMENTS),
        TM_UniRange(0x25A0, 0x2600, GEOMETRIC_SHAPES),
        TM_UniRange(0x2630, 0x2640, MISC_SYMBOLS_2630),
        TM_UniRange(0x2660, 0x2670, MISC_SYMBOLS_2660),
        TM_UniRange(0x3000, 0x3001, BASIC_LATIN[0..8]),

        // U+FF00 to U+FF5E is fullwidth of U+0020 to U+007E
        // => reuse the table since we do not "fullwidth"
        TM_UniRange(0xFF00, 0xFF5F, BASIC_LATIN[0..0x5F*8]),
    ])
];


static immutable ubyte[8] EMPTY =
[
    // All control chars have that same empty glyph
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
];

static immutable ubyte[8] NOT_DEF =
[
    0x78,0xcc,0x0c,0x18,0x30,0x00,0x30,0x00, // ?
];

static immutable ubyte[96 * 8] BASIC_LATIN =
[
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+0020 Space
    0x30,0x78,0x78,0x30,0x30,0x00,0x30,0x00, // U+0021 !
    0x6c,0x6c,0x6c,0x00,0x00,0x00,0x00,0x00, // U+0022 "
    0x6c,0x6c,0xfe,0x6c,0xfe,0x6c,0x6c,0x00, // U+0023 #
    0x30,0x7c,0xc0,0x78,0x0c,0xf8,0x30,0x00, // U+0024 $
    0x00,0xc6,0xcc,0x18,0x30,0x66,0xc6,0x00, // U+0025 %
    0x38,0x6c,0x38,0x76,0xdc,0xcc,0x76,0x00, // U+0026 &
    0x60,0x60,0xc0,0x00,0x00,0x00,0x00,0x00, // U+0027 '
    0x18,0x30,0x60,0x60,0x60,0x30,0x18,0x00, // U+0028 (
    0x60,0x30,0x18,0x18,0x18,0x30,0x60,0x00, // U+0029 )
    0x00,0x66,0x3c,0xff,0x3c,0x66,0x00,0x00, // U+002A *
    0x00,0x30,0x30,0xfc,0x30,0x30,0x00,0x00, // U+002B +
    0x00,0x00,0x00,0x00,0x00,0x30,0x30,0x60, // U+002C ,
    0x00,0x00,0x00,0xfc,0x00,0x00,0x00,0x00, // U+002D -
    0x00,0x00,0x00,0x00,0x00,0x30,0x30,0x00, // U+002E .
    0x06,0x0c,0x18,0x30,0x60,0xc0,0x80,0x00, // U+002F /

    0x7c,0xc6,0xce,0xde,0xf6,0xe6,0x7c,0x00, // U+0030 0
    0x30,0x70,0x30,0x30,0x30,0x30,0xfc,0x00, // U+0031 1
    0x78,0xcc,0x0c,0x38,0x60,0xcc,0xfc,0x00, // U+0032 2
    0x78,0xcc,0x0c,0x38,0x0c,0xcc,0x78,0x00, // U+0033 3
    0x1c,0x3c,0x6c,0xcc,0xfe,0x0c,0x1e,0x00, // U+0034 4
    0xfc,0xc0,0xf8,0x0c,0x0c,0xcc,0x78,0x00, // U+0035 5
    0x38,0x60,0xc0,0xf8,0xcc,0xcc,0x78,0x00, // U+0036 6
    0xfc,0xcc,0x0c,0x18,0x30,0x30,0x30,0x00, // U+0037 7
    0x78,0xcc,0xcc,0x78,0xcc,0xcc,0x78,0x00, // U+0038 8
    0x78,0xcc,0xcc,0x7c,0x0c,0x18,0x70,0x00, // U+0039 9
    0x00,0x30,0x30,0x00,0x00,0x30,0x30,0x00, // U+003A :
    0x00,0x30,0x30,0x00,0x00,0x30,0x30,0x60, // U+003B ;
    0x18,0x30,0x60,0xc0,0x60,0x30,0x18,0x00, // U+003C <
    0x00,0x00,0xfc,0x00,0x00,0xfc,0x00,0x00, // U+003D =
    0x60,0x30,0x18,0x0c,0x18,0x30,0x60,0x00, // U+003E >
    0x78,0xcc,0x0c,0x18,0x30,0x00,0x30,0x00, // U+003F ?

    0x7c,0xc6,0xde,0xde,0xde,0xc0,0x78,0x00, // U+0040 @
    0x30,0x78,0xcc,0xcc,0xfc,0xcc,0xcc,0x00, // U+0041 A
    0xfc,0x66,0x66,0x7c,0x66,0x66,0xfc,0x00, // U+0042 B
    0x3c,0x66,0xc0,0xc0,0xc0,0x66,0x3c,0x00, // U+0043 C
    0xf8,0x6c,0x66,0x66,0x66,0x6c,0xf8,0x00, // U+0044 D
    0xfe,0x62,0x68,0x78,0x68,0x62,0xfe,0x00, // U+0045 E
    0xfe,0x62,0x68,0x78,0x68,0x60,0xf0,0x00, // U+0046 F
    0x3c,0x66,0xc0,0xc0,0xce,0x66,0x3e,0x00, // U+0047 G
    0xcc,0xcc,0xcc,0xfc,0xcc,0xcc,0xcc,0x00, // U+0048 H
    0x78,0x30,0x30,0x30,0x30,0x30,0x78,0x00, // U+0049 I
    0x1e,0x0c,0x0c,0x0c,0xcc,0xcc,0x78,0x00, // U+004A J
    0xe6,0x66,0x6c,0x78,0x6c,0x66,0xe6,0x00, // U+004B K
    0xf0,0x60,0x60,0x60,0x62,0x66,0xfe,0x00, // U+004C L
    0xc6,0xee,0xfe,0xfe,0xd6,0xc6,0xc6,0x00, // U+004D M
    0xc6,0xe6,0xf6,0xde,0xce,0xc6,0xc6,0x00, // U+004E N
    0x38,0x6c,0xc6,0xc6,0xc6,0x6c,0x38,0x00, // U+004F O

    0xfc,0x66,0x66,0x7c,0x60,0x60,0xf0,0x00, // U+0050 P
    0x78,0xcc,0xcc,0xcc,0xdc,0x78,0x1c,0x00, // U+0051 Q
    0xfc,0x66,0x66,0x7c,0x6c,0x66,0xe6,0x00, // U+0052 R
    0x78,0xcc,0xc0,0x78,0x0c,0xcc,0x78,0x00, // U+0053 S
    0xfc,0xb4,0x30,0x30,0x30,0x30,0x78,0x00, // U+0054 T
    0xcc,0xcc,0xcc,0xcc,0xcc,0xcc,0xfc,0x00, // U+0055 U
    0xcc,0xcc,0xcc,0xcc,0xcc,0x78,0x30,0x00, // U+0056 V
    0xc6,0xc6,0xc6,0xd6,0xfe,0xee,0xc6,0x00, // U+0057 W
    0xc6,0xc6,0x6c,0x38,0x38,0x6c,0xc6,0x00, // U+0058 X
    0xcc,0xcc,0xcc,0x78,0x30,0x30,0x78,0x00, // U+0059 Y
    0xfe,0xc6,0x8c,0x18,0x32,0x66,0xfe,0x00, // U+005A Z
    0x78,0x60,0x60,0x60,0x60,0x60,0x78,0x00, // U+005B [
    0xc0,0x60,0x30,0x18,0x0c,0x06,0x02,0x00, // U+005C \
    0x78,0x18,0x18,0x18,0x18,0x18,0x78,0x00, // U+005D ]
    0x10,0x38,0x6c,0xc6,0x00,0x00,0x00,0x00, // U+005E ^
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0xff, // U+005F _

    0x30,0x30,0x18,0x00,0x00,0x00,0x00,0x00, // U+0060 `
    0x00,0x00,0x78,0x0c,0x7c,0xcc,0x76,0x00, // U+0061 a
    0xe0,0x60,0x60,0x7c,0x66,0x66,0xdc,0x00, // U+0062 b
    0x00,0x00,0x78,0xcc,0xc0,0xcc,0x78,0x00, // U+0063 c
    0x1c,0x0c,0x0c,0x7c,0xcc,0xcc,0x76,0x00, // U+0064 d
    0x00,0x00,0x78,0xcc,0xfc,0xc0,0x78,0x00, // U+0065 e
    0x38,0x6c,0x60,0xf0,0x60,0x60,0xf0,0x00, // U+0066 f
    0x00,0x00,0x76,0xcc,0xcc,0x7c,0x0c,0xf8, // U+0067 g
    0xe0,0x60,0x6c,0x76,0x66,0x66,0xe6,0x00, // U+0068 h
    0x30,0x00,0x70,0x30,0x30,0x30,0x78,0x00, // U+0069 i
    0x0c,0x00,0x0c,0x0c,0x0c,0xcc,0xcc,0x78, // U+006A j
    0xe0,0x60,0x66,0x6c,0x78,0x6c,0xe6,0x00, // U+006B k
    0x70,0x30,0x30,0x30,0x30,0x30,0x78,0x00, // U+006C l
    0x00,0x00,0xcc,0xfe,0xfe,0xd6,0xc6,0x00, // U+006D m
    0x00,0x00,0xf8,0xcc,0xcc,0xcc,0xcc,0x00, // U+006E n
    0x00,0x00,0x78,0xcc,0xcc,0xcc,0x78,0x00, // U+006F o

    0x00,0x00,0xdc,0x66,0x66,0x7c,0x60,0xf0, // U+0070 p
    0x00,0x00,0x76,0xcc,0xcc,0x7c,0x0c,0x1e, // U+0071 q
    0x00,0x00,0xdc,0x76,0x66,0x60,0xf0,0x00, // U+0072 r
    0x00,0x00,0x7c,0xc0,0x78,0x0c,0xf8,0x00, // U+0073 s
    0x10,0x30,0x7c,0x30,0x30,0x34,0x18,0x00, // U+0074 t
    0x00,0x00,0xcc,0xcc,0xcc,0xcc,0x76,0x00, // U+0075 u
    0x00,0x00,0xcc,0xcc,0xcc,0x78,0x30,0x00, // U+0076 v
    0x00,0x00,0xc6,0xd6,0xfe,0xfe,0x6c,0x00, // U+0077 w
    0x00,0x00,0xc6,0x6c,0x38,0x6c,0xc6,0x00, // U+0078 x
    0x00,0x00,0xcc,0xcc,0xcc,0x7c,0x0c,0xf8, // U+0079 y
    0x00,0x00,0xfc,0x98,0x30,0x64,0xfc,0x00, // U+007A z
    0x1c,0x30,0x30,0xe0,0x30,0x30,0x1c,0x00, // U+007B {
    0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x00, // U+007C |
    0xe0,0x30,0x30,0x1c,0x30,0x30,0xe0,0x00, // U+007D }
    0x76,0xdc,0x00,0x00,0x00,0x00,0x00,0x00, // U+007E ~
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+007F Del
];

static immutable ubyte[96 * 8] LATIN1_SUPP =
[
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+00A0 ' '
    0x18,0x18,0x00,0x18,0x18,0x18,0x18,0x00, // U+00A1 ¡
    0x18,0x18,0x7e,0xc0,0xc0,0x7e,0x18,0x18, // U+00A2 ¢
    0x38,0x6c,0x64,0xf0,0x60,0xe6,0xfc,0x00, // U+00A3 £
    0x00,0x84,0x78,0xcc,0xcc,0x78,0x84,0x00, // U+00A4 ¤
    0xcc,0xcc,0x78,0xfc,0x30,0xfc,0x30,0x30, // U+00A5 ¥
    0x18,0x18,0x18,0x00,0x18,0x18,0x18,0x00, // U+00A6 |
    0x3c,0x60,0x78,0x6c,0x6c,0x3c,0x0c,0x78, // U+00A7 §
    0xcc,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+00A8 ¨
    0x7e,0x81,0x9d,0xa1,0xa1,0x9d,0x81,0x7e, // U+00A9 ©
    0x3c,0x6c,0x6c,0x3e,0x00,0x7e,0x00,0x00, // U+00AA ª
    0x00,0x33,0x66,0xcc,0x66,0x33,0x00,0x00, // U+00AB «
    0x00,0x00,0x00,0xfc,0x0c,0x0c,0x00,0x00, // U+00AC ¬
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+00AD SHY
    0x7e,0x81,0xb9,0xa5,0xb9,0xa5,0x81,0x7e, // U+00AE ®
    0xff,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+00AF ¯

    0x38,0x6c,0x6c,0x38,0x00,0x00,0x00,0x00, // U+00B0 °
    0x30,0x30,0xfc,0x30,0x30,0x00,0xfc,0x00, // U+00B1 +-
    0x70,0x18,0x30,0x60,0x78,0x00,0x00,0x00, // U+00B2 ²
    0x70,0x18,0x30,0x18,0x70,0x00,0x00,0x00, // U+00B3 ³
    0x0C,0x18,0x30,0x00,0x00,0x00,0x00,0x00, // U+00B4 ´
    0x00,0x66,0x66,0x66,0x66,0x7c,0x60,0xc0, // U+00B5 µ
    0x7f,0xdb,0xdb,0x7b,0x1b,0x1b,0x1b,0x00, // U+00B6 ¶
    0x00,0x00,0x00,0x00,0x18,0x00,0x00,0x00, // U+00B7 ·
    0x00,0x00,0x00,0x00,0x00,0x18,0x0c,0x38, // U+00B8 ¸
    0x30,0x70,0x30,0x30,0x78,0x00,0x00,0x00, // U+00B9 ¹
    0x38,0x6c,0x6c,0x38,0x00,0x7c,0x00,0x00, // U+00BA º
    0x00,0xcc,0x66,0x33,0x66,0xcc,0x00,0x00, // U+00BB »
    0xc3,0xc6,0xcc,0xdb,0x37,0x6f,0xcf,0x03, // U+00BC ¼
    0xc3,0xc6,0xcc,0xde,0x33,0x66,0xcc,0x0f, // U+00BD ½
    0xe3,0x36,0x6c,0x3b,0xf7,0x6f,0xcf,0x03, // U+00BE ¾
    0x30,0x00,0x30,0x60,0xc0,0xcc,0x78,0x00, // U+00BF ¿

    0xc0,0x38,0x6c,0xc6,0xfe,0xc6,0xc6,0x00, // U+00C0 À
    0x03,0x38,0x6c,0xc6,0xfe,0xc6,0xc6,0x00, // U+00C1 Á
    0x7e,0xc3,0x38,0x6c,0xc6,0xfe,0xc6,0x00, // U+00C2 Â
    0x76,0xdc,0x38,0x6c,0xc6,0xfe,0xc6,0x00, // U+00C3 Ã
    0xc6,0x38,0x6c,0xc6,0xfe,0xc6,0xc6,0x00, // U+00C4 Ä
    0x30,0x30,0x00,0x78,0xcc,0xfc,0xcc,0x00, // U+00C5 Å
    0x3e,0x6c,0xcc,0xfe,0xcc,0xcc,0xce,0x00, // U+00C6 Æ
    0x78,0xcc,0xc0,0xcc,0x78,0x18,0x0c,0x78, // U+00C7 Ç
    0xe0,0x00,0xfc,0x60,0x78,0x60,0xfc,0x00, // U+00C8 È
    0x1c,0x00,0xfc,0x60,0x78,0x60,0xfc,0x00, // U+00C9 É
    0x78,0xcc,0xfc,0x60,0x78,0x60,0xfc,0x00, // U+00CA Ê
    0xcc,0x00,0xfc,0x60,0x78,0x60,0xfc,0x00, // U+00CB Ë
    0xe0,0x00,0x78,0x30,0x30,0x30,0x78,0x00, // U+00CC Ì
    0x1c,0x00,0x78,0x30,0x30,0x30,0x78,0x00, // U+00CD Í
    0x7e,0xc3,0x78,0x30,0x30,0x30,0x78,0x00, // U+00CE Î
    0xcc,0x00,0x78,0x30,0x30,0x30,0x78,0x00, // U+00CF Ï

    0xf1,0x6c,0x66,0xf6,0x66,0x6c,0xf1,0x00, // U+00D0 Ð
    0xfc,0x00,0xcc,0xec,0xfc,0xdc,0xcc,0x00, // U+00D1 Ñ
    0xc0,0x38,0x6c,0xc6,0xc6,0x6c,0x38,0x00, // U+00D2 Ò
    0x06,0x38,0x6c,0xc6,0xc6,0x6c,0x38,0x00, // U+00D3 Ó
    0x7c,0xc6,0x38,0x66,0x66,0x3c,0x18,0x00, // U+00D4 Ô
    0x76,0xdc,0x38,0x66,0x66,0x3c,0x18,0x00, // U+00D5 Õ
    0xc3,0x18,0x3c,0x66,0x66,0x3c,0x18,0x00, // U+00D6 Ö
    0x00,0xc6,0x6c,0x38,0x6c,0xc6,0x00,0x00, // U+00D7 ×
    0x3a,0x6c,0xce,0xd6,0xe6,0x6c,0xb8,0x00, // U+00D8 Ø
    0xe0,0x00,0xcc,0xcc,0xcc,0xcc,0x78,0x00, // U+00D9 Ù
    0x1c,0x00,0xcc,0xcc,0xcc,0xcc,0x78,0x00, // U+00DA Ú
    0x7c,0xc6,0x00,0xc6,0xc6,0xc6,0x7c,0x00, // U+00DB Û
    0xcc,0x00,0xcc,0xcc,0xcc,0xcc,0x78,0x00, // U+00DC Ü
    0x1c,0x00,0xcc,0xcc,0x78,0x30,0x78,0x00, // U+00DD Ý
    0xf0,0x60,0x7c,0x66,0x7c,0x60,0xf0,0x00, // U+00DE Þ
    0x00,0x78,0xcc,0xf8,0xcc,0xf8,0xc0,0xc0, // U+00DF ß

    0xe0,0x00,0x78,0x0c,0x7c,0xcc,0x7e,0x00, // U+00E0 à
    0x1c,0x00,0x78,0x0c,0x7c,0xcc,0x7e,0x00, // U+00E1 á
    0x7e,0xc3,0x3c,0x06,0x3e,0x66,0x3f,0x00, // U+00E2 â
    0x76,0xdc,0x78,0x0c,0x7c,0xcc,0x7e,0x00, // U+00E3 ã
    0xcc,0x00,0x78,0x0c,0x7c,0xcc,0x7e,0x00, // U+00E4 ä
    0x30,0x30,0x78,0x0c,0x7c,0xcc,0x7e,0x00, // U+00E5 å
    0x00,0x00,0x7f,0x0c,0x7f,0xcc,0x7f,0x00, // U+00E6 æ
    0x00,0x00,0x78,0xc0,0xc0,0x78,0x0c,0x38, // U+00E7 ç
    0xe0,0x00,0x78,0xcc,0xfc,0xc0,0x78,0x00, // U+00E8 è
    0x1c,0x00,0x78,0xcc,0xfc,0xc0,0x78,0x00, // U+00E9 é
    0x7e,0xc3,0x3c,0x66,0x7e,0x60,0x3c,0x00, // U+00EA ê
    0xcc,0x00,0x78,0xcc,0xfc,0xc0,0x78,0x00, // U+00EB ë
    0xe0,0x00,0x70,0x30,0x30,0x30,0x78,0x00, // U+00EC ì
    0x38,0x00,0x70,0x30,0x30,0x30,0x78,0x00, // U+00ED í
    0x7c,0xc6,0x38,0x18,0x18,0x18,0x3c,0x00, // U+00EE î
    0xcc,0x00,0x70,0x30,0x30,0x30,0x78,0x00, // U+00EF ï

    0x30,0x7e,0x0c,0x7c,0xcc,0xcc,0x78,0x00, // U+00F0 ð
    0x00,0xf8,0x00,0xf8,0xcc,0xcc,0xcc,0x00, // U+00F1 ñ
    0x00,0xe0,0x00,0x78,0xcc,0xcc,0x78,0x00, // U+00F2 ò
    0x00,0x1c,0x00,0x78,0xcc,0xcc,0x78,0x00, // U+00F3 ó
    0x78,0xcc,0x00,0x78,0xcc,0xcc,0x78,0x00, // U+00F4 ô
    0x76,0xdc,0x00,0x78,0xcc,0xcc,0x78,0x00, // U+00F5 õ
    0x00,0xcc,0x00,0x78,0xcc,0xcc,0x78,0x00, // U+00F6 ö
    0x03,0x03,0x00,0xfc,0x00,0x03,0x03,0x00, // U+00F7 ÷
    0x78,0xcc,0x00,0xcc,0xcc,0xcc,0x7e,0x00, // U+00F8 û
    0x00,0xe0,0x00,0xcc,0xcc,0xcc,0x7e,0x00, // U+00F9 ù
    0x00,0x1c,0x00,0xcc,0xcc,0xcc,0x7e,0x00, // U+00FA ú
    0x78,0xcc,0x00,0xcc,0xcc,0xcc,0x7e,0x00, // U+00FB û
    0x00,0xcc,0x00,0xcc,0xcc,0xcc,0x7e,0x00, // U+00FC ü
    0x00,0x1c,0x00,0xcc,0xcc,0x7c,0x0c,0x78, // U+00FD ý
    0x70,0x60,0x7c,0x66,0x66,0x7c,0x60,0xf0, // U+00FE þ
    0x00,0xcc,0x00,0xcc,0xcc,0x7c,0x0c,0xf8, // U+00FF ÿ
];

static immutable ubyte[64 * 8] GREEK_AND_COPTIC =
[
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+0390
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+0391
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+0392
    0x00,0xfc,0xcc,0xc0,0xc0,0xc0,0xc0,0x00, // U+0393 Γ
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+0394
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+0395
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+0396
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+0397
    0x38,0x6c,0xc6,0xfe,0xc6,0x6c,0x38,0x00, // U+0398 Θ
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+0399
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+039A
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+039B
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+039C
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+039D
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+039E
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+039F

    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+03A0
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+03A1
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+03A2
    0xfc,0xcc,0x60,0x30,0x60,0xcc,0xfc,0x00, // U+03A3 Σ
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+03A4
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+03A5
    0xfc,0x30,0x78,0xcc,0xcc,0x78,0x30,0xfc, // U+03A6 Φ
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+03A7
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+03A8
    0x38,0x6c,0xc6,0xc6,0x6c,0x6c,0xee,0x00, // U+03A9 Ω
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+03AA
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+03AB
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+03AC
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+03AD
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+03AE
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+03AF

    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+03B0
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+03B1
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+03B2
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+03B3
    0x1c,0x30,0x18,0x7c,0xcc,0xcc,0x78,0x00, // U+03B4 δ
    0x38,0x60,0xc0,0xf8,0xc0,0x60,0x38,0x00, // U+03B5 ε
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+03B6
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+03B7
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+03B8
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+03B9
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+03BA
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+03BB
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+03BC
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+03BD
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+03BE
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+03BF

    0x00,0xfe,0x6c,0x6c,0x6c,0x6c,0x6c,0x00, // U+03C0 π
    0x00,0x00,0x76,0xdc,0xc8,0xdc,0x76,0x00, // U+03C1 ρ
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+03C2
    0x00,0x00,0x7e,0xd8,0xd8,0xd8,0x70,0x00, // U+03C3 σ
    0x00,0x76,0xdc,0x18,0x18,0x18,0x18,0x00, // U+03C4 τ
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+03C5
    0x06,0x0c,0x7e,0xdb,0xdb,0x7e,0x60,0xc0, // U+03C6 φ
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+03C7
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+03C8
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+03C9
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+03CA
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+03CB
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+03CC
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+03CD
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+03CE
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+03CF
];

static immutable ubyte[16 * 8] GENERAL_PUNCTUATION =
[
    0x30,0x30,0xfc,0x30,0x30,0x30,0x30,0x30, // U+2020 †
    0x30,0x30,0xfc,0x30,0x30,0xfc,0x30,0x30, // U+2021 ‡
    0x00,0x00,0x18,0x3c,0x3c,0x18,0x00,0x00, // U+2022 •
    0x00,0x30,0x38,0x3c,0x38,0x30,0x00,0x00, // U+2023 ‣
    0x00,0x00,0x00,0x00,0x00,0x18,0x18,0x00, // U+2024 ․
    0x00,0x00,0x00,0x00,0x00,0x6c,0x6c,0x00, // U+2025 ‥
    0x00,0x00,0x00,0x00,0x00,0xdb,0xdb,0x00, // U+2026 …
    0x00,0x00,0x00,0x18,0x18,0x00,0x00,0x00, // U+2027 ‧
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+2028
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+2029
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+202A
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+202B
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+202C
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+202D
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+202E
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+202F
];

static immutable ubyte[1 * 8] LETTERLIKE_SYMBOLS =
[
    0x00,0xee,0x4e,0x4a,0x00,0x00,0x00,0x00, // U+2122 ™
];

static immutable ubyte[16 * 8] ARROWS =
[
    // Note: only a few of the Unicode arrows
    // TODO: ↖   ↗   ↘   ↙   ↚   ↛   ↜   ↝   ↞   ↟
    0x00,0x30,0x60,0xfe,0x60,0x30,0x00,0x00, // U+2190 ←
    0x18,0x3c,0x7e,0x18,0x18,0x18,0x18,0x00, // U+2191 ↑
    0x00,0x18,0x0c,0xfe,0x0c,0x18,0x00,0x00, // U+2192 →
    0x18,0x18,0x18,0x18,0x7e,0x3c,0x18,0x00, // U+2193 ↓
    0x00,0x24,0x66,0xff,0x66,0x24,0x00,0x00, // U+2194 ↔
    0x18,0x3c,0x7e,0x18,0x18,0x7e,0x3c,0x18, // U+2195 ↕
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+2196
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+2197
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+2198
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+2199
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+219A
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+219B
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+219C
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+219D
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+219E
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+219F
];

static immutable ubyte[112 * 8] MATH_OPERATORS =
[
    0x00,0xc3,0x7e,0x7e,0x24,0x3c,0x18,0x00, // U+2200 ∀
    0x18,0x24,0x20,0x20,0x20,0x20,0x24,0x18, // U+2201 ∁
    0x38,0x6c,0x0c,0x7c,0xcc,0xcc,0x78,0x00, // U+2202 ∂
    0x7e,0x06,0x06,0x1e,0x06,0x06,0x7e,0x00, // U+2203 ∃
    0x10,0x7e,0x16,0x16,0x3e,0x16,0x7e,0x10, // U+2204 ∄
    0x00,0x02,0x7c,0xce,0xd6,0xe6,0x7c,0x80, // U+2205 ∅
    0x18,0x18,0x24,0x24,0x42,0x42,0x81,0xff, // U+2206 ∆
    0xff,0x81,0x42,0x42,0x24,0x24,0x18,0x18, // U+2207 ∇
    0x00,0x3c,0x60,0x7c,0x60,0x3c,0x00,0x00, // U+2208 ∈
    0x08,0x3c,0x68,0x7c,0x68,0x3c,0x08,0x00, // U+2209 ∉
    0x00,0x3c,0x60,0x7c,0x60,0x3c,0x00,0x00, // U+220A ∊
    0x00,0x78,0x0c,0x7c,0x0c,0x78,0x00,0x00, // U+220B ∋
    0x20,0x78,0x2c,0x7c,0x2c,0x78,0x20,0x00, // U+220C ∌
    0x00,0x78,0x0c,0x7c,0x0c,0x78,0x00,0x00, // U+220D ∍
    0x00,0x7e,0x7e,0x7e,0x7e,0x7e,0x7e,0x00, // U+220E ∎
    0xff,0x66,0x66,0x66,0x66,0x66,0x66,0x66, // U+220F ∏

    0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x7e, // U+2210 ∐
    0xfc,0xcc,0x60,0x30,0x60,0xcc,0xfc,0x00, // U+2211 ∑
    0x00,0x00,0x00,0xfc,0x00,0x00,0x00,0x00, // U+2212 −
    0xfc,0x00,0x30,0x30,0xfc,0x30,0x30,0x00, // U+2213 ∓
    0x30,0x00,0x30,0x30,0xfc,0x30,0x30,0x00, // U+2214 ∔
    0x06,0x0c,0x18,0x30,0x60,0xc0,0x80,0x00, // U+2215 ∕
    0xc0,0x60,0x30,0x18,0x0c,0x06,0x02,0x00, // U+2216 ∖
    0x00,0x66,0x3c,0xff,0x3c,0x66,0x00,0x00, // U+2217 ∗
    0x00,0x3c,0x66,0x42,0x42,0x66,0x3c,0x00, // U+2218 ∘
    0x00,0x00,0x00,0x18,0x18,0x00,0x00,0x00, // U+2219 ∙
    0x0f,0x0c,0x0c,0x0c,0xec,0x6c,0x3c,0x1c, // U+221A √
    0xef,0x6c,0xec,0x0c,0xec,0x6c,0x3c,0x1c, // U+221B ∛
    0xaf,0xec,0x2c,0x0c,0xec,0x6c,0x3c,0x1c, // U+221C ∜
    0x00,0x00,0x7e,0xd8,0xd8,0x7e,0x00,0x00, // U+221D ∝
    0x00,0x00,0x7e,0xdb,0xdb,0x7e,0x00,0x00, // U+221E ∞
    0xc0,0xc0,0xc0,0xc0,0xc0,0xfe,0xfe,0x00, // U+221F ∟

    0x06,0x0c,0x18,0x30,0x60,0xc0,0xfe,0x00, // U+2220 ∠
    0x06,0x0c,0xd8,0x30,0x68,0xc8,0xfe,0x08, // U+2221 ∡
    0x13,0x0e,0x38,0xe4,0xe4,0x38,0x0e,0x13, // U+2222 ∢
    0x10,0x10,0x10,0x10,0x10,0x10,0x10,0x10, // U+2223 ∣
    0x10,0x14,0x18,0x10,0x30,0x50,0x10,0x10, // U+2224 ∤
    0x28,0x28,0x28,0x28,0x28,0x28,0x28,0x28, // U+2225 ∥
    0x28,0x28,0xe8,0x38,0x2e,0x28,0x28,0x28, // U+2226 ∦
    0x00,0x10,0x38,0x6c,0xc6,0x82,0x00,0x00, // U+2227 ∧
    0x00,0x82,0xc6,0x6c,0x38,0x10,0x00,0x00, // U+2228 ∨
    0x78,0xcc,0xcc,0xcc,0xcc,0xcc,0xcc,0x00, // U+2229 ∩
    0xcc,0xcc,0xcc,0xcc,0xcc,0xcc,0x78,0x00, // U+222A ∪
    0x0e,0x1b,0x1b,0x18,0x18,0xd8,0xd8,0x70, // U+222B ∫
    0x1e,0x2b,0x2b,0x28,0x28,0xe8,0xe8,0x70, // U+222C ∬
    0x3e,0x57,0x57,0x54,0x2a,0xea,0xea,0x7c, // U+222D ∭
    0x0e,0x1b,0x1b,0x28,0x14,0xd8,0xd8,0x70, // U+222E ∮
    0x1e,0x2b,0x3b,0x44,0x38,0xa8,0xe8,0x70, // U+222F ∯

    // Note: no room to display contour integrals (t)
    0x3e,0x57,0x5f,0x64,0x3e,0xea,0xea,0x7c, // U+2230 ∰
    0x0e,0x1b,0x1b,0x28,0x14,0xd8,0xd8,0x70, // U+2231 ∱ (t)
    0x0e,0x1b,0x1b,0x28,0x14,0xd8,0xd8,0x70, // U+2232 ∲ (t)
    0x0e,0x1b,0x1b,0x28,0x14,0xd8,0xd8,0x70, // U+2233 ∳ (t)
    0x00,0x18,0x18,0x00,0x00,0x66,0x66,0x00, // U+2234 ∴
    0x00,0x66,0x66,0x00,0x00,0x18,0x18,0x00, // U+2235 ∵
    0x00,0x18,0x18,0x00,0x00,0x18,0x18,0x00, // U+2236 ∶
    0x00,0x66,0x66,0x00,0x00,0x66,0x66,0x00, // U+2237 ∷
    0x30,0x30,0x00,0xfc,0x00,0x00,0x00,0x00, // U+2238 ∸
    0x00,0x03,0x03,0xf8,0x03,0x03,0x00,0x00, // U+2239 ∹
    0xc6,0xc6,0x00,0xfe,0x00,0xc6,0xc6,0x00, // U+223A ∺
    0x18,0x18,0x00,0x32,0x4c,0x00,0x18,0x18, // U+223B ∻
    0x00,0x00,0x00,0x76,0xdc,0x00,0x00,0x00, // U+223C ∼
    0x00,0x00,0x00,0xdc,0x76,0x00,0x00,0x00, // U+223D ∽
    0x00,0x00,0x64,0x92,0x92,0x4c,0x00,0x00, // U+223E ∾
    0x00,0x00,0x60,0x92,0x92,0x0c,0x00,0x00, // U+223F ∿

    // Note: U+224C has a reverse tilde, some fonts are wrong
    0x10,0x18,0x08,0x18,0x10,0x18,0x08,0x00, // U+2240 ≀
    0x10,0x10,0x10,0x76,0xdc,0x10,0x10,0x10, // U+2241 ≁
    0x00,0x00,0xfe,0x00,0x76,0xdc,0x00,0x00, // U+2242 ≂
    0x00,0x00,0x76,0xdc,0x00,0xfe,0x00,0x00, // U+2243 ≃
    0x10,0x10,0x76,0xdc,0x10,0xfe,0x10,0x10, // U+2244 ≄
    0x00,0x76,0xdc,0x00,0xfe,0x00,0xfe,0x00, // U+2245 ≅
    0x76,0xdc,0x00,0x08,0xfe,0x10,0xfe,0x20, // U+2246 ≆
    0x10,0x76,0xdc,0x10,0xfe,0x10,0xfe,0x10, // U+2247 ≇
    0x00,0x76,0xdc,0x00,0x76,0xdc,0x00,0x00, // U+2248 ≈
    0x10,0x76,0xdc,0x10,0x76,0xdc,0x10,0x10, // U+2249 ≉
    0x76,0xdc,0x00,0x76,0xdc,0x00,0xfe,0x00, // U+224A ≊
    0x76,0xdc,0x00,0x76,0xdc,0x00,0x76,0xdc, // U+224B ≋
    0x00,0xdc,0x76,0x00,0xfe,0x00,0xfe,0x00, // U+224C ≌
    0x82,0x44,0x38,0x00,0x38,0x44,0x82,0x00, // U+224D ≍
    0x18,0x24,0xe7,0x00,0xe7,0x24,0x18,0x00, // U+224E ≎
    0x00,0x18,0x24,0xe7,0x00,0xff,0x00,0x00, // U+224F ≏

    0x30,0x00,0xfc,0x00,0x00,0xfc,0x00,0x00, // U+2250 ≐
    0x30,0x00,0xfc,0x00,0x00,0xfc,0x00,0x30, // U+2251 ≑
    0xc0,0x00,0xfc,0x00,0x00,0xfc,0x00,0x0c, // U+2252 ≒
    0x0c,0x00,0xfc,0x00,0x00,0xfc,0x00,0xc0, // U+2253 ≓
    0x00,0x00,0xbf,0x00,0x00,0xbf,0x00,0x00, // U+2254 ≔
    0x00,0x00,0xfd,0x00,0x00,0xfd,0x00,0x00, // U+2255 ≕
    0x00,0xfc,0x30,0x48,0x30,0xfc,0x00,0x00, // U+2256 ≖
    0x30,0x48,0x48,0x30,0xfc,0x00,0xfc,0x00, // U+2257 ≗
    0x30,0xcc,0x00,0xfc,0x00,0xfc,0x00,0x00, // U+2258 ≘
    0x30,0x48,0x00,0xfc,0x00,0xfc,0x00,0x00, // U+2259 ≙
    0x48,0x30,0x00,0xfc,0x00,0xfc,0x00,0x00, // U+225A ≚
    0x54,0x38,0x54,0x00,0xfe,0x00,0xfe,0x00, // U+225B ≛
    0x10,0x28,0x7c,0x00,0xfe,0x00,0xfe,0x00, // U+225C ≜
    0x5b,0xda,0xd3,0xda,0x00,0xfe,0x00,0xfe, // U+225D ≝
    0x7c,0x54,0x54,0x00,0xfc,0x00,0xfc,0x00, // U+225E ≞
    0x30,0x10,0x20,0x00,0x20,0xfc,0x00,0xfc, // U+225F ≟
    // TODO
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+2260
    0x00,0xfc,0x00,0xfc,0x00,0xfc,0x00,0x00, // U+2261 ≡
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+2262
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+2263
    0x18,0x30,0x60,0x30,0x18,0x00,0xfc,0x00, // U+2264 ≤
    0x60,0x30,0x18,0x30,0x60,0x00,0xfc,0x00, // U+2265 ≥
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+2266
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+2267
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+2268
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+2269
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+226A
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+226B
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+226C
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+226D
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+226E
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+226F
];

static immutable ubyte[34 * 8] MISC_TECHNICAL =
[
    0x01,0x1a,0x24,0x4a,0x52,0x24,0x58,0x80, // U+2300 ⌀
    0x00,0x90,0x58,0x34,0x12,0x00,0x00,0x00, // U+2301 ⌁
    0x00,0x10,0x38,0x6c,0xc6,0xc6,0xfe,0x00, // U+2302 ⌂
    0x00,0x10,0x38,0x6c,0xc6,0x00,0x00,0x00, // U+2303 ⌃
    0x00,0x00,0xc6,0x6c,0x38,0x10,0x00,0x00, // U+2304 ⌄
    0x00,0xfe,0x10,0x38,0x6c,0xc6,0x00,0x00, // U+2305 ⌅
    0xfe,0x00,0xfe,0x10,0x38,0x6c,0xc6,0x00, // U+2306 ⌆
    0x00,0x10,0x08,0x10,0x08,0x10,0x08,0x00, // U+2307 ⌇
    0x00,0x1e,0x18,0x18,0x18,0x18,0x18,0x18, // U+2308 ⌈
    0x00,0x78,0x18,0x18,0x18,0x18,0x18,0x18, // U+2309 ⌉
    0x18,0x18,0x18,0x18,0x18,0x18,0x1e,0x00, // U+230A ⌊
    0x18,0x18,0x18,0x18,0x18,0x18,0x78,0x00, // U+230B ⌋
    0x00,0x00,0x00,0x07,0x07,0x18,0x18,0x18, // U+230C ⌌
    0x00,0x00,0x00,0xe0,0xe0,0x18,0x18,0x18, // U+230D ⌍
    0x18,0x18,0x18,0x07,0x07,0x00,0x00,0x00, // U+230E ⌎
    0x18,0x18,0x18,0xe0,0xe0,0x00,0x00,0x00, // U+230F ⌏

    0x00,0x00,0x00,0x3f,0x30,0x30,0x00,0x00, // U+2310 ⌐
    0x00,0x7e,0x42,0x24,0x24,0x42,0x7e,0x00, // U+2311 ⌑
    0x00,0x3c,0x42,0x81,0x81,0x81,0x00,0x00, // U+2312 ⌒ 
    0x00,0x3c,0x42,0x81,0x81,0xff,0x00,0x00, // U+2313 ⌓
    0x00,0x38,0x44,0x82,0x44,0x28,0x10,0x00, // U+2314 ⌔
    0x0e,0x11,0x11,0x11,0x3e,0x70,0xe0,0xc0, // U+2315 ⌕
    0x10,0x10,0x38,0xfe,0x38,0x10,0x10,0x00, // U+2316 ⌖
    0x24,0x24,0xff,0x24,0x24,0xff,0x24,0x24, // U+2317 ⌗
    0xe7,0xa5,0xff,0x24,0x24,0xff,0xa5,0xe7, // U+2318 ⌘
    0x00,0x00,0x00,0x30,0x30,0x3f,0x00,0x00, // U+2319 ⌙
    0x3c,0x54,0x92,0x9b,0xa2,0x44,0x3c,0x3c, // U+231A ⌚
    0xfe,0xfe,0x44,0x28,0x44,0x82,0xfe,0x00, // U+231B ⌛
    0xf0,0xf0,0xc0,0xc0,0x00,0x00,0x00,0x00, // U+231C ⌜
    0x0f,0x0f,0x03,0x03,0x00,0x00,0x00,0x00, // U+231D ⌝
    0x00,0x00,0x00,0x00,0xc0,0xc0,0xf0,0xf0, // U+231E ⌞ 
    0x00,0x00,0x00,0x00,0x03,0x03,0x0f,0x0f, // U+231F ⌟

    0x0e,0x1b,0x1b,0x18,0x18,0x18,0x18,0x18, // U+2320 ⌠
    0x18,0x18,0x18,0x18,0x18,0xd8,0xd8,0x70, // U+2321 ⌡
];

static immutable ubyte[2 * 8] MISC_TECHNICAL2 =
[
    0x06,0x06,0x36,0x66,0xfe,0x60,0x30,0x00, // U+23CE ⏎
    0xff,0x81,0x99,0xbd,0x81,0xbd,0x81,0xff, // U+23CF ⏏
];

static immutable ubyte[128 * 8] BOX_DRAWING =
[
    0x00,0x00,0x00,0x00,0xff,0x00,0x00,0x00, // U+2500 ─
    0x00,0x00,0x00,0xff,0xff,0x00,0x00,0x00, // U+2501 ━
    0x10,0x10,0x10,0x10,0x10,0x10,0x10,0x10, // U+2502 │
    0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18, // U+2503 ┃
    0x00,0x00,0x00,0x00,0xdb,0x00,0x00,0x00, // U+2504 ┄
    0x00,0x00,0x00,0xdb,0xdb,0x00,0x00,0x00, // U+2505 ┅
    0x10,0x10,0x00,0x10,0x10,0x00,0x10,0x10, // U+2506 ┆
    0x18,0x18,0x00,0x18,0x18,0x00,0x18,0x18, // U+2507 ┇
    0x00,0x00,0x00,0x00,0xaa,0x00,0x00,0x00, // U+2508 ┈
    0x00,0x00,0x00,0xaa,0xaa,0x00,0x00,0x00, // U+2509 ┉
    0x10,0x00,0x10,0x00,0x10,0x00,0x10,0x00, // U+250A ┊
    0x18,0x00,0x18,0x00,0x18,0x00,0x18,0x00, // U+250B ┋
    0x00,0x00,0x00,0x00,0x1f,0x10,0x10,0x10, // U+250C ┌
    0x00,0x00,0x00,0x1f,0x1f,0x10,0x10,0x10, // U+250D ┍
    0x00,0x00,0x00,0x00,0x1f,0x18,0x18,0x18, // U+250E ┎
    0x00,0x00,0x00,0x1f,0x1f,0x18,0x18,0x18, // U+250F ┏

    0x00,0x00,0x00,0x00,0xf0,0x10,0x10,0x10, // U+2510 ┐
    0x00,0x00,0x00,0xf0,0xf0,0x10,0x10,0x10, // U+2511 ┑
    0x00,0x00,0x00,0x00,0xf8,0x18,0x18,0x18, // U+2512 ┒
    0x00,0x00,0x00,0xf8,0xf8,0x18,0x18,0x18, // U+2513 ┓
    0x10,0x10,0x10,0x10,0x1f,0x00,0x00,0x00, // U+2514 └
    0x10,0x10,0x10,0x1f,0x1f,0x00,0x00,0x00, // U+2515 ┕
    0x18,0x18,0x18,0x18,0x1f,0x00,0x00,0x00, // U+2516 ┖
    0x18,0x18,0x18,0x1f,0x1f,0x00,0x00,0x00, // U+2517 ┗
    0x10,0x10,0x10,0x10,0xf0,0x00,0x00,0x00, // U+2518 ┘
    0x10,0x10,0x10,0xf0,0xf0,0x00,0x00,0x00, // U+2519 ┙
    0x18,0x18,0x18,0x18,0xf8,0x00,0x00,0x00, // U+251A ┚
    0x18,0x18,0x18,0xf8,0xf8,0x00,0x00,0x00, // U+251B ┛
    0x10,0x10,0x10,0x10,0x1f,0x10,0x10,0x10, // U+251C ├
    0x10,0x10,0x10,0x1f,0x1f,0x10,0x10,0x10, // U+251D ┝
    0x18,0x18,0x18,0x18,0x1f,0x10,0x10,0x10, // U+251E ┞
    0x10,0x10,0x10,0x10,0x1f,0x18,0x18,0x18, // U+251F ┟

    0x18,0x18,0x18,0x18,0x1f,0x18,0x18,0x18, // U+2520 ┠
    0x18,0x18,0x18,0x1f,0x1f,0x10,0x10,0x10, // U+2521 ┡
    0x10,0x10,0x10,0x1f,0x1f,0x18,0x18,0x18, // U+2522 ┢
    0x18,0x18,0x18,0x1f,0x1f,0x18,0x18,0x18, // U+2523 ┣
    0x10,0x10,0x10,0x10,0xf0,0x10,0x10,0x10, // U+2524 ┤
    0x10,0x10,0x10,0xf0,0xf0,0x10,0x10,0x10, // U+2525 ┥
    0x18,0x18,0x18,0x18,0xf8,0x10,0x10,0x10, // U+2526 ┦
    0x10,0x10,0x10,0x10,0xf8,0x18,0x18,0x18, // U+2527 ┧
    0x18,0x18,0x18,0x18,0xf8,0x18,0x18,0x18, // U+2528 ┨
    0x18,0x18,0x18,0xf8,0xf8,0x10,0x10,0x10, // U+2529 ┩
    0x10,0x10,0x10,0xf8,0xf8,0x18,0x18,0x18, // U+252A ┪
    0x18,0x18,0x18,0xf8,0xf8,0x18,0x18,0x18, // U+252B ┫
    0x00,0x00,0x00,0x00,0xff,0x10,0x10,0x10, // U+252C ┬
    0x00,0x00,0x00,0xf0,0xff,0x10,0x10,0x10, // U+252D ┭
    0x00,0x00,0x00,0x1f,0xff,0x10,0x10,0x10, // U+252E ┮
    0x00,0x00,0x00,0xff,0xff,0x10,0x10,0x10, // U+252F ┯

    0x00,0x00,0x00,0x00,0xff,0x18,0x18,0x18, // U+2530 ┰
    0x00,0x00,0x00,0xf8,0xff,0x18,0x18,0x18, // U+2531 ┱
    0x00,0x00,0x00,0x1f,0xff,0x18,0x18,0x18, // U+2532 ┲
    0x00,0x00,0x00,0xff,0xff,0x18,0x18,0x18, // U+2533 ┳
    0x10,0x10,0x10,0x10,0xff,0x00,0x00,0x00, // U+2534 ┴
    0x10,0x10,0x10,0xf0,0xff,0x00,0x00,0x00, // U+2535 ┵
    0x10,0x10,0x10,0x1f,0xff,0x00,0x00,0x00, // U+2536 ┶
    0x10,0x10,0x10,0xff,0xff,0x00,0x00,0x00, // U+2537 ┷
    0x18,0x18,0x18,0x18,0xff,0x00,0x00,0x00, // U+2538 ┸
    0x18,0x18,0x18,0xf8,0xff,0x00,0x00,0x00, // U+2539 ┹
    0x18,0x18,0x18,0x1f,0xff,0x00,0x00,0x00, // U+253A ┺
    0x18,0x18,0x18,0xff,0xff,0x00,0x00,0x00, // U+253B ┻
    0x10,0x10,0x10,0x10,0xff,0x10,0x10,0x10, // U+253C ┼
    0x10,0x10,0x10,0xf0,0xff,0x10,0x10,0x10, // U+253D ┽
    0x10,0x10,0x10,0x1f,0xff,0x10,0x10,0x10, // U+253E ┾
    0x10,0x10,0x10,0xff,0xff,0x10,0x10,0x10, // U+253F ┿

    0x18,0x18,0x18,0x18,0xff,0x10,0x10,0x10, // U+2540 ╀
    0x10,0x10,0x10,0x10,0xff,0x18,0x18,0x18, // U+2541 ╁
    0x18,0x18,0x18,0x18,0xff,0x18,0x18,0x18, // U+2542 ╂
    0x18,0x18,0x18,0xf8,0xff,0x10,0x10,0x10, // U+2543 ╃
    0x18,0x18,0x18,0x1f,0xff,0x10,0x10,0x10, // U+2544 ╄
    0x10,0x10,0x10,0xf8,0xff,0x18,0x18,0x18, // U+2545 ╅
    0x10,0x10,0x10,0x1f,0xff,0x18,0x18,0x18, // U+2546 ╆
    0x18,0x18,0x18,0xff,0xff,0x10,0x10,0x10, // U+2547 ╇
    0x10,0x10,0x10,0xff,0xff,0x18,0x18,0x18, // U+2548 ╈
    0x18,0x18,0x18,0xf8,0xff,0x18,0x18,0x18, // U+2549 ╉
    0x18,0x18,0x18,0x1f,0xff,0x18,0x18,0x18, // U+254A ╊
    0x18,0x18,0x18,0xff,0xff,0x18,0x18,0x18, // U+254B ╋
    0x00,0x00,0x00,0x00,0xee,0x00,0x00,0x00, // U+254C ╌
    0x00,0x00,0x00,0xee,0xee,0x00,0x00,0x00, // U+254D ╍
    0x10,0x10,0x10,0x00,0x10,0x10,0x10,0x00, // U+254E ╎
    0x18,0x18,0x18,0x00,0x18,0x18,0x18,0x00, // U+254F ╏

    0x00,0x00,0xff,0x00,0xff,0x00,0x00,0x00, // U+2550 ═
    0x36,0x36,0x36,0x36,0x36,0x36,0x36,0x36, // U+2551 ║
    0x00,0x00,0x1f,0x18,0x1f,0x18,0x18,0x18, // U+2552 ╒
    0x00,0x00,0x00,0x00,0x3f,0x36,0x36,0x36, // U+2553 ╓
    0x00,0x00,0x3f,0x30,0x37,0x36,0x36,0x36, // U+2554 ╔
    0x00,0x00,0xf8,0x18,0xf8,0x18,0x18,0x18, // U+2555 ╕
    0x00,0x00,0x00,0x00,0xfe,0x36,0x36,0x36, // U+2556 ╖
    0x00,0x00,0xfe,0x06,0xf6,0x36,0x36,0x36, // U+2557 ╗
    0x18,0x18,0x1f,0x18,0x1f,0x00,0x00,0x00, // U+2558 ╘
    0x36,0x36,0x36,0x36,0x3f,0x00,0x00,0x00, // U+2559 ╙
    0x36,0x36,0x37,0x30,0x3f,0x00,0x00,0x00, // U+255A ╚
    0x18,0x18,0xf8,0x18,0xf8,0x00,0x00,0x00, // U+255B ╛
    0x36,0x36,0x36,0x36,0xfe,0x00,0x00,0x00, // U+255C ╜
    0x36,0x36,0xf6,0x06,0xfe,0x00,0x00,0x00, // U+255D ╝
    0x18,0x18,0x1f,0x18,0x1f,0x18,0x18,0x18, // U+255E ╞
    0x36,0x36,0x36,0x36,0x37,0x36,0x36,0x36, // U+255F ╟

    0x36,0x36,0x37,0x30,0x37,0x36,0x36,0x36, // U+2560 ╠
    0x18,0x18,0xf8,0x18,0xf8,0x18,0x18,0x18, // U+2561 ╡
    0x36,0x36,0x36,0x36,0xf6,0x36,0x36,0x36, // U+2562 ╢
    0x36,0x36,0xf6,0x06,0xf6,0x36,0x36,0x36, // U+2563 ╣
    0x00,0x00,0xff,0x00,0xff,0x18,0x18,0x18, // U+2564 ╤
    0x00,0x00,0x00,0x00,0xff,0x36,0x36,0x36, // U+2565 ╥
    0x00,0x00,0xff,0x00,0xf7,0x36,0x36,0x36, // U+2566 ╦
    0x18,0x18,0xff,0x00,0xff,0x00,0x00,0x00, // U+2567 ╧
    0x36,0x36,0x36,0x36,0xff,0x00,0x00,0x00, // U+2568 ╨
    0x36,0x36,0xf7,0x00,0xff,0x00,0x00,0x00, // U+2569 ╩
    0x18,0x18,0xff,0x18,0xff,0x18,0x18,0x18, // U+256A ╪
    0x36,0x36,0x36,0x36,0xff,0x36,0x36,0x36, // U+256B ╫
    0x36,0x36,0xf7,0x00,0xf7,0x36,0x36,0x36, // U+256C ╬
    0x00,0x00,0x00,0x00,0x07,0x08,0x10,0x10, // U+256D ╭
    0x00,0x00,0x00,0x00,0xc0,0x20,0x10,0x10, // U+256E ╮
    0x10,0x10,0x10,0x20,0xc0,0x00,0x00,0x00, // U+256F ╯

    0x10,0x10,0x10,0x08,0x07,0x00,0x00,0x00, // U+2570 ╰
    0x01,0x02,0x04,0x08,0x10,0x20,0x40,0x80, // U+2571 ╱
    0x80,0x40,0x20,0x10,0x08,0x04,0x02,0x01, // U+2572 ╲
    0x81,0x42,0x24,0x18,0x18,0x24,0x42,0x81, // U+2573 ╳
    0x00,0x00,0x00,0x00,0xf0,0x00,0x00,0x00, // U+2574 ╴
    0x10,0x10,0x10,0x10,0x10,0x00,0x00,0x00, // U+2575 ╵
    0x00,0x00,0x00,0x00,0x1f,0x00,0x00,0x00, // U+2576 ╶
    0x00,0x00,0x00,0x00,0x10,0x10,0x10,0x10, // U+2577 ╷
    0x00,0x00,0x00,0xf0,0xf0,0x00,0x00,0x00, // U+2578 ╸
    0x18,0x18,0x18,0x18,0x18,0x00,0x00,0x00, // U+2579 ╹
    0x00,0x00,0x00,0x1f,0x1f,0x00,0x00,0x00, // U+257A ╺
    0x00,0x00,0x00,0x18,0x18,0x18,0x18,0x18, // U+257B ╻
    0x00,0x00,0x00,0x1f,0xff,0x00,0x00,0x00, // U+257C ╼
    0x10,0x10,0x10,0x10,0x18,0x18,0x18,0x18, // U+257D ╽
    0x00,0x00,0x00,0xf0,0xff,0x00,0x00,0x00, // U+257E ╾
    0x18,0x18,0x18,0x18,0x10,0x10,0x10,0x10, // U+257F ╿
];

static immutable ubyte[32 * 8] BLOCK_ELEMENTS =
[
    0xff,0xff,0xff,0xff,0x00,0x00,0x00,0x00, // U+2580 ▀
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0xff, // U+2581 ▁
    0x00,0x00,0x00,0x00,0x00,0x00,0xff,0xff, // U+2582 ▂
    0x00,0x00,0x00,0x00,0x00,0xff,0xff,0xff, // U+2583 ▃
    0x00,0x00,0x00,0x00,0xff,0xff,0xff,0xff, // U+2584 ▄
    0x00,0x00,0x00,0xff,0xff,0xff,0xff,0xff, // U+2585 ▅
    0x00,0x00,0xff,0xff,0xff,0xff,0xff,0xff, // U+2586 ▆
    0x00,0xff,0xff,0xff,0xff,0xff,0xff,0xff, // U+2587 ▇
    0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff, // U+2588 █
    0xfe,0xfe,0xfe,0xfe,0xfe,0xfe,0xfe,0xfe, // U+2589 ▉
    0xfc,0xfc,0xfc,0xfc,0xfc,0xfc,0xfc,0xfc, // U+258A ▊
    0xf8,0xf8,0xf8,0xf8,0xf8,0xf8,0xf8,0xf8, // U+258B ▋
    0xf0,0xf0,0xf0,0xf0,0xf0,0xf0,0xf0,0xf0, // U+258C ▌
    0xe0,0xe0,0xe0,0xe0,0xe0,0xe0,0xe0,0xe0, // U+258D ▍
    0xc0,0xc0,0xc0,0xc0,0xc0,0xc0,0xc0,0xc0, // U+258E ▎
    0x80,0x80,0x80,0x80,0x80,0x80,0x80,0x80, // U+258F ▏

    0x0f,0x0f,0x0f,0x0f,0x0f,0x0f,0x0f,0x0f, // U+2590 ▐
    0x22,0x88,0x22,0x88,0x22,0x88,0x22,0x88, // U+2591 ░
    0x55,0xaa,0x55,0xaa,0x55,0xaa,0x55,0xaa, // U+2592 ▒
    0xdb,0x77,0xdb,0xee,0xdb,0x77,0xdb,0xee, // U+2593 ▓
    0xff,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+2594 ▔
    0x01,0x01,0x01,0x01,0x01,0x01,0x01,0x01, // U+2595 ▕
    0x00,0x00,0x00,0x00,0xf0,0xf0,0xf0,0xf0, // U+2596 ▖
    0x00,0x00,0x00,0x00,0x0f,0x0f,0x0f,0x0f, // U+2597 ▗
    0xf0,0xf0,0xf0,0xf0,0x00,0x00,0x00,0x00, // U+2598 ▘
    0xf0,0xf0,0xf0,0xf0,0xff,0xff,0xff,0xff, // U+2599 ▙
    0xf0,0xf0,0xf0,0xf0,0x0f,0x0f,0x0f,0x0f, // U+259A ▚
    0xff,0xff,0xff,0xff,0xf0,0xf0,0xf0,0xf0, // U+259B ▛
    0xff,0xff,0xff,0xff,0x0f,0x0f,0x0f,0x0f, // U+259C ▜
    0x0f,0x0f,0x0f,0x0f,0x00,0x00,0x00,0x00, // U+259D ▝
    0x0f,0x0f,0x0f,0x0f,0xf0,0xf0,0xf0,0xf0, // U+259E ▞
    0x0f,0x0f,0x0f,0x0f,0xff,0xff,0xff,0xff, // U+259F ▟
];

static immutable ubyte[96 * 8] GEOMETRIC_SHAPES =
[
    0x00,0x00,0x3c,0x3c,0x3c,0x3c,0x00,0x00, // U+25A0 ■
    0x00,0x00,0x3c,0x24,0x24,0x3c,0x00,0x00, // U+25A1 □
    0x00,0x3c,0x42,0x42,0x42,0x42,0x3c,0x00, // U+25A2 ▢
    0x00,0x7e,0x42,0x5a,0x5a,0x42,0x7e,0x00, // U+25A3 ▣
    0xfe,0x82,0xfe,0x82,0xfe,0x82,0xfe,0x00, // U+25A4 ▤
    0xfe,0xaa,0xaa,0xaa,0xaa,0xaa,0xfe,0x00, // U+25A5 ▥
    0xfe,0xaa,0xfe,0xaa,0xfe,0xaa,0xfe,0x00, // U+25A6 ▦
    0xfe,0xa6,0x92,0xca,0xa6,0x92,0xfe,0x00, // U+25A7 ▧
    0xfe,0xca,0x92,0xa6,0xca,0x92,0xfe,0x00, // U+25A8 ▨
    0xfe,0xc6,0xaa,0x92,0xaa,0xc6,0xfe,0x00, // U+25A9 ▩
    0x00,0x00,0x00,0x18,0x18,0x00,0x00,0x00, // U+25AA ▪
    0x00,0x00,0x00,0x38,0x28,0x38,0x00,0x00, // U+25AB ▫
    0x00,0x00,0xff,0xff,0xff,0xff,0x00,0x00, // U+25AC ▬
    0x00,0x00,0xff,0x81,0x81,0xff,0x00,0x00, // U+25AD ▭
    0x3c,0x3c,0x3c,0x3c,0x3c,0x3c,0x3c,0x3c, // U+25AE ▮
    0x3c,0x24,0x24,0x24,0x24,0x24,0x24,0x3c, // U+25AF ▯

    0x00,0x00,0x3f,0x7f,0xfe,0xfc,0x00,0x00, // U+25B0 ▰
    0x00,0x00,0x3f,0x41,0x82,0xfc,0x00,0x00, // U+25B1 ▱
    0x18,0x18,0x3c,0x3c,0x7e,0x7e,0xff,0xff, // U+25B2 ▲
    0x18,0x18,0x24,0x24,0x42,0x42,0x81,0xff, // U+25B3 △
    0x00,0x00,0x10,0x38,0x7c,0xfe,0x00,0x00, // U+25B4 ▴
    0x00,0x00,0x10,0x28,0x44,0xfe,0x00,0x00, // U+25B5 ▵
    0xc0,0xf0,0xfc,0xff,0xff,0xfc,0xf0,0xc0, // U+25B6 ▶
    0xc0,0xb0,0x8c,0x83,0x83,0x8c,0xb0,0xc0, // U+25B7 ▷
    0x20,0x30,0x38,0x3c,0x38,0x30,0x20,0x00, // U+25B8 ▸
    0x20,0x30,0x28,0x24,0x28,0x30,0x20,0x00, // U+25B9 ▹
    0xc0,0xf0,0xfc,0xff,0xfc,0xf0,0xc0,0x00, // U+25BA ►
    0xc0,0xb0,0x8c,0x83,0x8c,0xb0,0xc0,0x00, // U+25BB ▻
    0xff,0xff,0x7e,0x7e,0x3c,0x3c,0x18,0x18, // U+25BC ▼
    0xff,0x81,0x42,0x42,0x24,0x24,0x18,0x18, // U+25BD ▽
    0x00,0x00,0xfe,0x7c,0x38,0x10,0x00,0x00, // U+25BE ▾
    0x00,0x00,0xfe,0x44,0x28,0x10,0x00,0x00, // U+25BF ▿

    0x03,0x0f,0x3f,0xff,0xff,0x3f,0x0f,0x03, // U+25C0 ◀
    0x03,0x0d,0x31,0xc1,0xc1,0x31,0x0d,0x03, // U+25C1 ◁
    0x04,0x0c,0x1c,0x3c,0x1c,0x0c,0x04,0x00, // U+25C2 ◂
    0x04,0x0c,0x14,0x24,0x14,0x0c,0x04,0x00, // U+25C3 ◃
    0x03,0x0f,0x3f,0xff,0x3f,0x0f,0x03,0x00, // U+25C4 ◄
    0x03,0x0d,0x31,0xc1,0x31,0x0d,0x03,0x00, // U+25C5 ◅
    0x18,0x3c,0x7e,0xff,0x7e,0x3c,0x18,0x00, // U+25C6 ◆
    0x18,0x3c,0x66,0xc3,0x66,0x3c,0x18,0x00, // U+25C7 ◇
    0x10,0x28,0x44,0x92,0x44,0x28,0x10,0x00, // U+25C8 ◈
    0x3c,0x42,0x99,0xbd,0xbd,0x99,0x42,0x3c, // U+25C9 ◉
    0x10,0x38,0x28,0x44,0x44,0x28,0x38,0x10, // U+25CA ◊
    0x00,0x3c,0x66,0x42,0x42,0x66,0x3c,0x00, // U+25CB ○
    0x24,0x00,0x81,0x00,0x00,0x81,0x00,0x24, // U+25CC ◌
    0x3c,0x6a,0xd5,0xab,0xd5,0xab,0x56,0x3c, // U+25CD ◍
    0x3c,0x42,0x99,0xa5,0xa5,0x99,0x42,0x3c, // U+25CE ◎
    0x00,0x18,0x3c,0x7e,0x7e,0x3c,0x18,0x00, // U+25CF ●

    0x3c,0x72,0xf1,0xf1,0xf1,0xf1,0x72,0x3c, // U+25D0 ◐
    0x3c,0x4e,0x8f,0x8f,0x8f,0x8f,0x4e,0x3c, // U+25D1 ◑
    0x3c,0x42,0x81,0x81,0xff,0xff,0x7e,0x3c, // U+25D2 ◒
    0x3c,0x7e,0xff,0xff,0x81,0x81,0x42,0x3c, // U+25D3 ◓
    0x3c,0x4e,0x8f,0x8f,0x81,0x81,0x42,0x3c, // U+25D4 ◔
    0x3c,0x4e,0x8f,0x8f,0xff,0xff,0x7e,0x3c, // U+25D5 ◕
    0x30,0x70,0xf0,0xf0,0xf0,0xf0,0x70,0x30, // U+25D6 ◖
    0x0c,0x0e,0x0f,0x0f,0x0f,0x0f,0x0e,0x0c, // U+25D7 ◗
    0xff,0xff,0xe7,0xc3,0xc3,0xe7,0xff,0xff, // U+25D8 ◘
    0xff,0x81,0x99,0xbd,0xbd,0x99,0x81,0xff, // U+25D9 ◙
    0xff,0x81,0x99,0xbd,0x00,0x00,0x00,0x00, // U+25DA ◚
    0x00,0x00,0x00,0x00,0xbd,0x99,0x81,0xff, // U+25DB ◛
    0x30,0x40,0x80,0x80,0x00,0x00,0x00,0x00, // U+25DC ◜
    0x0c,0x02,0x01,0x01,0x00,0x00,0x00,0x00, // U+25DD ◝
    0x00,0x00,0x00,0x00,0x01,0x01,0x02,0x0c, // U+25DE ◞
    0x00,0x00,0x00,0x00,0x80,0x80,0x40,0x30, // U+25DF ◟

    0x3c,0x42,0x81,0x81,0x00,0x00,0x00,0x00, // U+25E0 ◠
    0x00,0x00,0x00,0x00,0x81,0x81,0x42,0x3c, // U+25E1 ◡
    0x01,0x03,0x07,0x0f,0x1f,0x3f,0x7f,0xff, // U+25E2 ◢
    0x80,0xc0,0xe0,0xf0,0xf8,0xfc,0xfe,0xff, // U+25E3 ◣
    0xff,0xfe,0xfc,0xf8,0xf0,0xe0,0xc0,0x80, // U+25E4 ◤
    0xff,0x7f,0x3f,0x1f,0x0f,0x07,0x03,0x01, // U+25E5 ◥
    0x00,0x00,0x18,0x24,0x24,0x18,0x00,0x00, // U+25E6 ◦
    0xff,0xf1,0xf1,0xf1,0xf1,0xf1,0xf1,0xff, // U+25E7 ◧
    0xff,0x8f,0x8f,0x8f,0x8f,0x8f,0x8f,0xff, // U+25E8 ◨
    0xff,0xff,0xfd,0xf9,0xf1,0xe1,0xc1,0xff, // U+25E9 ◩
    0xff,0x83,0x87,0x8f,0x9f,0xbf,0xff,0xff, // U+25EA ◪
    0xfe,0x92,0x92,0x92,0x92,0x92,0xfe,0x00, // U+25EB ◫
    0x00,0x18,0x24,0x4a,0x81,0xff,0x00,0x00, // U+25EC ◬
    0x00,0x18,0x34,0x72,0xf1,0xff,0x00,0x00, // U+25ED ◭
    0x00,0x18,0x2c,0x4e,0x8f,0xff,0x00,0x00, // U+25EE ◮
    0x3c,0x42,0x81,0x81,0x81,0x81,0x42,0x3c, // U+25EF ◯

    0xfe,0x92,0x92,0xf2,0x82,0x82,0xfe,0x00, // U+25F0 ◰
    0xfe,0x82,0x82,0xf2,0x92,0x92,0xfe,0x00, // U+25F1 ◱
    0xfe,0x82,0x82,0x9e,0x92,0x92,0xfe,0x00, // U+25F2 ◲
    0xfe,0x92,0x92,0x9e,0x82,0x82,0xfe,0x00, // U+25F3 ◳
    0x38,0x54,0x92,0xf2,0x82,0x44,0x38,0x00, // U+25F4 ◴
    0x38,0x44,0x82,0xf2,0x92,0x54,0x38,0x00, // U+25F5 ◵
    0x38,0x44,0x82,0x9e,0x92,0x54,0x38,0x00, // U+25F6 ◶
    0x38,0x54,0x92,0x9e,0x82,0x44,0x38,0x00, // U+25F7 ◷
    0xff,0x82,0x84,0x88,0x90,0xa0,0xc0,0x80, // U+25F8 ◸
    0xff,0x41,0x21,0x11,0x09,0x05,0x03,0x01, // U+25F9 ◹
    0x80,0xc0,0xa0,0x90,0x88,0x84,0x82,0xff, // U+25FA ◺
    0x00,0x7e,0x42,0x42,0x42,0x42,0x7e,0x00, // U+25FB ◻
    0x00,0x7e,0x7e,0x7e,0x7e,0x7e,0x7e,0x00, // U+25FC ◼
    0x00,0x00,0x3c,0x24,0x24,0x3c,0x00,0x00, // U+25FD ◽
    0x00,0x00,0x3c,0x3c,0x3c,0x3c,0x00,0x00, // U+25FE ◾
    0x01,0x03,0x05,0x09,0x11,0x21,0x41,0xff, // U+25FF ◿
];

static immutable ubyte[16 * 8] MISC_SYMBOLS_2630 =
[
    // TODO
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+2630 TODO
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+2631 TODO
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+2632 TODO
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+2633 TODO
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+2634 TODO
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+2635 TODO
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+2636 TODO
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+2637 TODO
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+2638 TODO
    0x7e,0x81,0xa5,0x81,0x99,0xa5,0x81,0x7e, // U+2639 ☹
    0x7e,0x81,0xa5,0x81,0xbd,0x99,0x81,0x7e, // U+263A ☺
    0x7e,0xff,0xdb,0xff,0xc3,0xe7,0xff,0x7e, // U+263B ☻
    0x99,0x5a,0x3c,0xe7,0xe7,0x3c,0x5a,0x99, // U+263C ☼
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+263D TODO
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+263E TODO
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // U+263F TODO
];

static immutable ubyte[16 * 8] MISC_SYMBOLS_2660 =
[
    // Note: could not draw card colors without filling
    0x10,0x10,0x38,0x7c,0xfe,0x7c,0x38,0x7c, // U+2660 ♠
    0x6c,0xfe,0xfe,0xfe,0x7c,0x38,0x10,0x00, // U+2661 ♡
    0x10,0x38,0x7c,0xfe,0x7c,0x38,0x10,0x00, // U+2662 ♢
    0x38,0x7c,0x38,0xfe,0xfe,0x7c,0x38,0x7c, // U+2663 ♣
    0x10,0x10,0x38,0x7c,0xfe,0x7c,0x38,0x7c, // U+2664 ♤
    0x6c,0xfe,0xfe,0xfe,0x7c,0x38,0x10,0x00, // U+2665 ♥
    0x10,0x38,0x7c,0xfe,0x7c,0x38,0x10,0x00, // U+2666 ♦
    0x38,0x7c,0x38,0xfe,0xfe,0x7c,0x38,0x7c, // U+2667 ♧
    0x49,0x92,0x92,0x49,0x49,0xff,0x81,0x7e, // U+2668 ♨
    0x30,0x30,0x30,0x30,0x30,0x70,0xf0,0xe0, // U+2669 ♩
    0x3f,0x33,0x3f,0x30,0x30,0x70,0xf0,0xe0, // U+266A ♪
    0x7f,0x63,0x7f,0x63,0x63,0x67,0xe6,0xc0, // U+266B ♫
    0x7f,0x63,0x7f,0x63,0x63,0xe3,0xc7,0x06, // U+266C ♬
    0x20,0x20,0x20,0x20,0x30,0x28,0x30,0x00, // U+266D ♭
    0x20,0x20,0x3c,0x24,0x3c,0x04,0x04,0x00, // U+266E ♮
    0x0c,0x6e,0x7c,0xee,0x7c,0xec,0x60,0x00, // U+266F ♯
];



/* CP437 upper range

    0xf8,0xcc,0xcc,0xfa,0xc6,0xcf,0xc6,0xc7, // U+20A7 ₧
    0x78,0x6c,0x6c,0x6c,0x6c,0x00,0x00,0x00, // U+207F
    0x0e,0x1b,0x18,0x3c,0x18,0x18,0xd8,0x70, // U+0192 ƒ


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

        while(!finished)
        {

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
        }

        // Is there any unclosed tags? Ignore.
    }

private:

    TM_Console* console;

    void setCol(int col, bool bg)
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
                setStyle(currentStyle | TM_styleBold);
                break;

            case "blink":
                setStyle(currentStyle | TM_styleBlink);
                break;

            case "u":
                setStyle(currentStyle | TM_styleUnder);
                break;

            case "shiny":
                setStyle(currentStyle | TM_styleShiny);
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
                    case "black":   setCol( 0, bg); break;
                    case "red":     setCol( 1, bg); break;
                    case "green":   setCol( 2, bg); break;
                    case "orange":  setCol( 3, bg); break;
                    case "blue":    setCol( 4, bg); break;
                    case "magenta": setCol( 5, bg); break;
                    case "cyan":    setCol( 6, bg); break;
                    case "lgrey":   setCol( 7, bg); break;
                    case "grey":    setCol( 8, bg); break;
                    case "lred":    setCol( 9, bg); break;
                    case "lgreen":  setCol(10, bg); break;
                    case "yellow":  setCol(11, bg); break;
                    case "lblue":   setCol(12, bg); break;
                    case "lmagenta":setCol(13, bg); break;
                    case "lcyan":   setCol(14, bg); break;
                    case "white":   setCol(15, bg); break;
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
                // input terminate on "<", return EOI
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
                    // input terminate on "</", return EOI
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
                        // tag is malformed such as:
                        //     <like-that/
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
                    // Note: ignore invalid character in tag
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
                // input terminate on "<", return EOI
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
                    const(char)[] entName =
                        charsSincePos(entStart);
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
                      || (ch >= 'A' && ch <= 'Z'))
                    // Accept both lowercase and uppercase
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

            // do nothing, ignore an unrecognized entity or
            // empty one, but terminate input
            {
                // input terminate on "<", return end of
                // input instead of error
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

// .ans interpreter implementation
struct ANSInterpreter
{
public:
nothrow:
@nogc:
pure:

    void initialize(TM_Console* console, int baseX,
                    int baseY)
    {
        this.console = console;
        this.baseX   = baseX;
        this.baseY   = baseY;
    }

    ~this()
    {
        console.current.ccol = baseX;
        console.current.crow = baseY;
    }

    void input(const(char)[] s, bool isCP437)
    {
        this.s        = s;
        this.inputPos = 0;
        this.line     = 0;
        this.isCP437  = isCP437;
    }

    // Output BOTH original char in the input
    // and the glyph. This is because .ans uses
    // 0x1b escape codes, however this is still
    // a glyph in CP437 and no escaping is done.
    //
    // Returns:
    //     Number of character popped.
    //     ch = original byte in the stream
    //          If and only if that byte was 0..128, else 0.
    //  glyph = Unicode BMP glyph.
    int peek(out char ch, out dchar glyph)
    {
        if (inputPos >= s.length)
        {
            decode_error:
            ch = '\0';
            glyph = '\0'; // end marker
            return 0;
        }

        ch = s[inputPos];

        if (isCP437)
        {
            glyph = cast(dchar) CP437_TO_UNICODE[ch];
            if (ch > 127) ch = '\0';
            return 1;
        }


        // UTF-8 decoding.
        // This looks verbose compared to how it's
        // supposed to be decoded
        if (ch <= 127)
        {
            glyph = ch;
            return 1;
        }
        else if (ch <= 223)
        {
            // two-byte codepoint
            if (inputPos + 1 >= s.length)
                goto decode_error;
            char ch2 = s[inputPos+1];
            if (ch2 > 191)
                goto decode_error;
            glyph = ((ch & 0x1f) << 6)
                   | (ch2 & 0x3f);
            return 2;
        }
        else if (ch <= 239)
        {
            // three-byte codepoint
            if (inputPos + 2 >= s.length)
                goto decode_error;
             char ch2 = s[inputPos+1];
             char ch3 = s[inputPos+2];
             if (ch2 > 191 || ch3 > 191)
                 goto decode_error;
             glyph = ((ch  & 0x0f) << 12)
                   | ((ch2 & 0x3f) << 6)
                   |  (ch3 & 0x3f);
             return 3;
        }
        else if (ch >= 247)
        {
            // four-byte codepoint
            if (inputPos + 3 >= s.length)
                goto decode_error;
            char ch2 = s[inputPos+1];
            char ch3 = s[inputPos+2];
            char ch4 = s[inputPos+3];
            if (ch2 > 191 || ch3 > 191 || ch4 > 191)
                goto decode_error;
            glyph = ((ch  & 0x07) << 18)
                  | ((ch2 & 0x3f) << 12)
                  | ((ch3 & 0x3f) << 6)
                  |  (ch4 & 0x3f);
            return 4;
        }
        else
            goto decode_error;
    }

    void next()
    {
        char ch;
        dchar glyph;
        int ofs = peek(ch, glyph);
        inputPos += ofs;
    }

    bool isNumber()
    {
        char ch;
        dchar glyph;
        peek(ch, glyph);
        return ch >= '0' && ch <= '9';
    }

    // never fails since called on '0' .. '9' input
    int parseNumber()
    {
        int r = 0;
        char ch;
        dchar glyph;
        while(true)
        {
            peek(ch, glyph);
            if (ch >= '0' && ch <= '9')
            {
                next;
                r = r * 10 + (ch - '0');
            }
            else
                break;
        }
        return r;
    }

    // this string may be CP437 or UTF-8.
    // Much like Markdown, a VT-100 emulation cannot fail.
    void interpret(const(char)[] s)
    {
        int line = 0;
        LW:
        while(true)
        {
            char ch;
            dchar glyph;
            int npos = peek(ch, glyph);
            if (glyph == '\0')
                break; // end of input

            switch(ch)
            {
            case '\n': // CR
            {
                next;
                line++;
                console.locate(baseX, baseY+line);
                break;
            }
            case '\r':
            {
                next;
                console.column(baseX);
                break;
            }
            case '\x1A':
            {
                // beyond that is the "sub" in ANSI lore
                break LW;
            }
            case '\x1B':
            {
                dchar escGlyph = glyph;
                next;
                peek(ch, glyph);
                if (ch == '[')
                {
                    next;
                    bool equal = false;
                    peek(ch, glyph);
                    if (ch == '=')
                    {
                        equal = true;
                        next;
                    }

                    int nArg = 0;
                    enum MAX_ARGS = 8;
                    int[MAX_ARGS] args;
                    while(true)
                    {
                        if (isNumber())
                        {
                            int n = parseNumber();
                            if (nArg + 1 < MAX_ARGS)
                                args[nArg++] = n;
                            peek(ch, glyph);

                            // ; or exit
                            if (ch == ';')
                                next;
                            else
                                break;
                        }
                        else
                            break;
                    }

                    peek(ch, glyph);
                    char command = ch;
                    next;
                    if (command == 'm')
                    {
                        displayAttr(args);
                    }
                    else if (command == 'C' && nArg >= 1)
                    {
                        int curcol = console.current.ccol;
                        console.column(curcol + args[0]);
                    }
                    else
                    {
                        // ignore whole sequence
                    }
                    break;
                }
                else if (ch ==  ']')
                {
                    next;
                    while(true)
                    {
                        peek(ch, glyph);
                        next;
                        if (ch == 7)
                            break;
                    }
                    // escape sequence failed
                }
                else
                {
                    next;
                    // unknown escape sequence
                }
                break;
            }
            default:
            {
                next;
                console.print(glyph);
                break;
            }
            }
        }
    }

    // See https://en.wikipedia.org/wiki/ANSI_escape_code
    void displayAttr(int[] args)
    {
        if (args.length == 0)
        {
            console.style(TM_styleNone);
            return;
        }


        for (size_t i = 0; i < args.length; ++i)
        with (console)
        {
            int n = args[i];
            TM_Style curStyle = current.style;

            switch(n)
            {
            // All attributes become turned off
            case 0: style(TM_styleNone);
                break;
            case 1: style(curStyle | TM_styleBold);
                break;
            case 2: break; // not sure what to do
            case 3:
            case 5:
            case 6:
                style(curStyle | TM_styleBlink); break;
            case 4: style(curStyle | TM_styleUnder);
                break;
            case 21: style(curStyle & ~cast(int)TM_styleBold);
                break;
            case 24: style(curStyle & ~cast(int)TM_styleUnder);
                break;
            case 25: style(curStyle & ~cast(int)TM_styleBlink);
                break;
            case 30: .. case 37:   fg(n - 30); break;
            case 40: .. case 47:   bg(n - 40); break;
            case 90: .. case 97:   fg(n - 82); break;
            case 100: .. case 107: bg(n - 92); break;

            case 38: // eg: \e[48;5;236;38;5;247m
            case 48:
            {
                if (i + 1 >= args.length)
                    return;
                int subcmd = args[++i];
                int icol;
                if (subcmd == 5)
                {
                    if (i + 1 >= args.length)
                        return;
                    icol = extendedPaletteMatch(args[++i]);
                }
                else if (subcmd == 2)
                {
                    if (i + 3 >= args.length)
                        return;
                    int r = cast(ubyte)args[++i];
                    int g = cast(ubyte)args[++i];
                    int b = cast(ubyte)args[++i];
                    icol = findColorMatch(r, g, b);
                }
                else
                    return;

                if (n == 38)
                    fg(icol);
                else
                    bg(icol);
                break;
            }

            case 39: fg(TM_colorGrey); break;
            case 49: bg(TM_colorBlack); break;
            default: break; // ignore
            }
        }
    }

    int extendedPaletteMatch(int c)
    {
        if (c < 0 || c > 255)
            return 0; // black, invalid color

        if (c < 16)
            return c; // base 16 colors

        // Else match into the palette of 16 colors, since
        // we don't want to display more than 16 colors
        // anyway (well... for now)

        int r, g, b;
        if (c >= 232)
        {
            c -= 232; // 0 to 23
            r = g = b = ((255 * c) + 12) / 23;
        }
        else
        {
            // 16 to 231
            // 6 × 6 × 6 cube (216 colors)
            // c = 36 × r + 6 × g + b (0 <= r, g, b <= 5)
            c -= 16;
            b = c % 6;
            c /= 6;
            g = c % 6;
            c /= 6;
            r = c;
            r = ((255 * r) + 3) / 5;
            g = ((255 * g) + 3) / 5;
            b = ((255 * b) + 3) / 5;
        }
        return console.findColorMatch(r, g, b);
    }


private:
    const(char)[] s;
    int inputPos;
    int line;
    bool isCP437;
    int baseX, baseY;
    TM_Console* console;
}

static immutable ushort[256] CP437_TO_UNICODE =
[
    0x0000,0x263A,0x263B,0x2665,0x2666,0x2663,0x2660,0x2022,
    0x25D8,0x25CB,0x25D9,0x2642,0x2640,0x266A,0x266B,0x263C,
    0x25BA,0x25C4,0x2195,0x203C,0x00B6,0x00A7,0x25AC,0x21A8,
    0x2191,0x2193,0x2192,0x2190,0x221F,0x2194,0x25B2,0x25BC,
    0x0020,0x0021,0x0022,0x0023,0x0024,0x0025,0x0026,0x0027,
    0x0028,0x0029,0x002A,0x002B,0x002C,0x002D,0x002E,0x002F,
    0x0030,0x0031,0x0032,0x0033,0x0034,0x0035,0x0036,0x0037,
    0x0038,0x0039,0x003A,0x003B,0x003C,0x003D,0x003E,0x003F,
    0x0040,0x0041,0x0042,0x0043,0x0044,0x0045,0x0046,0x0047,
    0x0048,0x0049,0x004A,0x004B,0x004C,0x004D,0x004E,0x004F,
    0x0050,0x0051,0x0052,0x0053,0x0054,0x0055,0x0056,0x0057,
    0x0058,0x0059,0x005A,0x005B,0x005C,0x005D,0x005E,0x005F,
    0x0060,0x0061,0x0062,0x0063,0x0064,0x0065,0x0066,0x0067,
    0x0068,0x0069,0x006A,0x006B,0x006C,0x006D,0x006E,0x006F,
    0x0070,0x0071,0x0072,0x0073,0x0074,0x0075,0x0076,0x0077,
    0x0078,0x0079,0x007A,0x007B,0x007C,0x007D,0x007E,0x2302,
    0x00C7,0x00FC,0x00E9,0x00E2,0x00E4,0x00E0,0x00E5,0x00E7,
    0x00EA,0x00EB,0x00E8,0x00EF,0x00EE,0x00EC,0x00C4,0x00C5,
    0x00C9,0x00E6,0x00C6,0x00F4,0x00F6,0x00F2,0x00FB,0x00F9,
    0x00FF,0x00D6,0x00DC,0x00A2,0x00A3,0x00A5,0x20A7,0x0192,
    0x00E1,0x00ED,0x00F3,0x00FA,0x00F1,0x00D1,0x00AA,0x00BA,
    0x00BF,0x2310,0x00AC,0x00BD,0x00BC,0x00A1,0x00AB,0x00BB,
    0x2591,0x2592,0x2593,0x2502,0x2524,0x2561,0x2562,0x2556,
    0x2555,0x2563,0x2551,0x2557,0x255D,0x255C,0x255B,0x2510,
    0x2514,0x2534,0x252C,0x251C,0x2500,0x253C,0x255E,0x255F,
    0x255A,0x2554,0x2569,0x2566,0x2560,0x2550,0x256C,0x2567,
    0x2568,0x2564,0x2565,0x2559,0x2558,0x2552,0x2553,0x256B,
    0x256A,0x2518,0x250C,0x2588,0x2584,0x258C,0x2590,0x2580,
    0x03B1,0x00DF,0x0393,0x03C0,0x03A3,0x03C3,0x00B5,0x03C4,
    0x03A6,0x0398,0x03A9,0x03B4,0x221E,0x03C6,0x03B5,0x2229,
    0x2261,0x00B1,0x2265,0x2264,0x2320,0x2321,0x00F7,0x2248,
    0x00B0,0x2219,0x00B7,0x221A,0x207F,0x00B2,0x25A0,0x00A0,
];

// limitation of .xp format
enum TM_MAX_IMAGE_LAYERS = 9;

struct XPInterpreter
{
public:
nothrow:
@nogc:

    void initialize(TM_Console* console)
    {
        this.console = console;
    }

    // Reference: Appendix B: .xp Format Specification
    //            in REXPaint manual.txt
    bool interpret(const(ubyte)[] input,

                   // *scratch is a stretchy buffer
                   // for amortized ungzip
                   ubyte** scratch,

                   tinfl_decompressor* infl_decomp,

                   ref TM_Image outImage) // output image
        @trusted
    {
        if (input.length < 18)
            return false; // can't be a .gz file

        // check Gzip header
        const(ubyte)* bodyPtr;
        size_t bodyLen;
        {
            int ofs = 0;
            _input = input;
            if (popByte() != 0x1f)
                return false;
            if (popByte() != 0x8b)
                return false;
            if (popByte() != 0x08)
                return false; // not DEFLATE
            ubyte flags = popByte();

            // REXpaint seems to be 0 here
            assert(flags == 0);

            read_s32_LE(); // skip timestamp
            ubyte xflags = popByte();

            // REXpaint seems to be 0 here
            assert(xflags == 0);
            popByte(); // ignore OS

            // other stuff is optional, DEFLATE data here
            bodyPtr = _input.ptr;
        }

        // check Gzip footer to get size of DEFLATE data
        {
            _input = input[$-8..$];
            read_s32_LE(); // skip CRC
            bodyLen = cast(uint) read_s32_LE();
            if (bodyLen > int.max)
                return false;
        }

        // deflate uncompress stuff
        {
            sb_set_capacity(*scratch, cast(int)bodyLen);

            // inflate
            size_t outlen = bodyLen;
            int hdr_sz = 10;
            int ftr_sz = 8;
            size_t inlen = input.length - hdr_sz - ftr_sz;
            ubyte* output_start = *scratch;
            ubyte* output_next = *scratch;
            int flags =
                TINFL_FLAG_USING_NON_WRAPPING_OUTPUT_BUF;
            tinfl_status st = tinfl_decompress(infl_decomp,
                                               bodyPtr,
                                               &inlen,
                                               output_start,
                                               output_next,
                                               &outlen,
                                               flags);
            if (st != TINFL_STATUS_DONE)
                return false;
            // MAYDO: use decompressed length
            input = (*scratch)[0..outlen];
        }

        _input = input;
        int ver = read_s32_LE();
        int numLayers = read_s32_LE();
        if (numLayers < 1 || numLayers > TM_MAX_IMAGE_LAYERS)
            return false;

        int maxLayerWidth = 0;
        int maxLayerHeight = 0;

        // Read max width and height of layers
        // with this first scan
        {
            const(ubyte)[] tmp = _input;
            for (int layer = 0; layer < numLayers; layer++)
            {
                int width = read_s32_LE();
                int height = read_s32_LE();
                if (maxLayerWidth < width) maxLayerWidth = width;
                if (maxLayerHeight < height) maxLayerHeight = height;

                for (int x = 0; x < width; ++x)
                {
                    for (int y = 0; y < height; ++y)
                    {
                        read_s32_LE();
                        ubyte fgr = popByte();
                        ubyte fgg = popByte();
                        ubyte fgb = popByte();
                        ubyte bgr = popByte();
                        ubyte bgg = popByte();
                        ubyte bgb = popByte();

                        // transparent color
                        if (bgr==255 && bgg==0 && bgb==255)
                            continue; // glyph already set to 0xffff
                    }
                }
            }
            _input = tmp;
        }

        // At this point, parsing cannot crash anymore.
        // outImage is given a non-zero size, which means "drawable".

        outImage.resize(numLayers, maxLayerWidth, maxLayerHeight);

        for (int layer = 0; layer < numLayers; layer++)
        {
            int width = read_s32_LE();
            int height = read_s32_LE();

            for (int x = 0; x < width; ++x)
            {
                for (int y = 0; y < height; ++y)
                {
                    uint asci = read_s32_LE() & 255;
                    dchar ch;
                    ch = cast(dchar) CP437_TO_UNICODE[asci];
                    ubyte fgr = popByte();
                    ubyte fgg = popByte();
                    ubyte fgb = popByte();
                    ubyte bgr = popByte();
                    ubyte bgg = popByte();
                    ubyte bgb = popByte();

                    // transparent color
                    if (bgr==255 && bgg==0 && bgb==255)
                        continue; // glyph already set to 0xffff

                    // PERF: LRU cache for matching colors
                    int fgM, bgM;
                    fgM = console.findColorMatch(fgr, fgg, fgb);
                    bgM = console.findColorMatch(bgr, bgg, bgb);

                    TM_CharData* p = &outImage.charAt(layer, x, y);
                    p.color = cast(ubyte)(fgM | (bgM << 4));
                    p.glyph = ch;
                }
            }
        }
        return true;
    }

    int read_s32_LE()
    {
        uint r = popByte();
        r |= (popByte << 8);
        r |= (popByte << 16);
        r |= (popByte << 24);
        return r;
    }

    ubyte popByte()
    {
        if (_input.length == 0)
            return 0;
        else
        {
            ubyte r = _input[0];
            _input = _input[1..$];
            return r;
        }
    }

    void skipBytes(size_t b)
    {
        if (_input.length < b)
            _input = _input[$..$];
        else
            _input = _input[b..$];
    }

    const(ubyte)[] _input;

private:
    TM_Console* console;
    int baseX, baseY;
}

// Make 1D separable gaussian kernel
void makeGaussianKernel(int len,
                        float sigma,
                        float mu,
                        float[] outtaps)
{
    static double gaussian(double x,
                           double mu,
                           double sigma)
    {
        enum SQRT2 = 1.41421356237;
        return 0.5 * erf((x - mu) / (SQRT2 * sigma));
    }
    assert( (len % 2) == 1);
    assert(len <= outtaps.length);

    int taps = len/2;

    double last_int = gaussian(-taps, mu, sigma);
    double sum = 0;
    for (int x = -taps; x <= taps; ++x)
    {
        double new_int = gaussian(x + 1, mu, sigma);
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

double erf(double x)
{
    // constants
    double a1 = 0.254829592;
    double a2 = -0.284496736;
    double a3 = 1.421413741;
    double a4 = -1.453152027;
    double a5 = 1.061405429;
    double p  = 0.3275911;
    // A&S formula 7.1.26
    double t = 1.0 / (1.0 + p * abs_double(x));
    double y = 1.0 - (((((a5 * t + a4) * t) + a3) * t + a2)
             * t + a1) * t * exp(-x * x);
    return (x >= 0 ? 1 : -1) * y;
}

double abs_double(double x) pure
{
    return x >= 0 ? x : -x;
}

int abs_int32(int x) pure
{
    return x >= 0 ? x : -x;
}

int TM_minint(int a, int b) pure
{
    return a < b ? a : b;
}

float TM_max32f(float a, float b) pure
{
    return a > b ? a : b;
}

ubyte clamp16_235(ubyte x) pure
{
    if (x < 16) x = 16;
    if (x > 235) x = 235;
    return cast(ubyte)x;
}

ubyte clamp16_240(ubyte x) pure
{
    if (x < 16) x = 16;
    if (x > 240) x = 240;
    return cast(ubyte)x;
}

ubyte clamp0_255(int x) pure
{
    if (x < 0) x = 0;
    if (x > 255) x = 255;
    return cast(ubyte)x;
}

// If == is used on TM_CharData, then filling bytes could
// lead to incorrect invalidation!
bool equalCharData(TM_CharData a, TM_CharData b) pure
{
    return a.glyph == b.glyph
        && a.color == b.color
        && a.style == b.style;
}


// https://gist.github.com/ctmatthews/c1cbd1b2e68c29a88b236475a0b26cd0
uint hashFNV1A32(const(void)[] data, uint seed = 0x811c9dc5)
{
    uint result = seed;

    const(ubyte)[] bytes = cast(const(ubyte)[])data;
    foreach(ubyte b; bytes)
    {
        result ^= b;
        result *= 0x01000193;
    }
    return result;
}
