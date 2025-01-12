import turtle;
import textmode;

int main(string[] args)
{
    runGame(new TermExample());
    return 0;
}

// Note: the "turtle" game engine now has a builtin text-mode console,
// this is an example of how it could be integrated manually;
class TermExample : TurtleGame
{
    this()
    {

    }

    override void load()
    {
        setBackgroundColor(color("#222"));
        console.size(40, 22);
    }

    override void mouseMoved(float x, float y, float dx, float dy)
    {
    }

    int _fontSel = 0;
    int _palSel = 0;

    override void update(double dt)
    {
        console.update(dt);
        if (keyboard.isDownOnce("escape")) exitGame();
        if (keyboard.isDownOnce("space")) crt = !crt;
    }

    int ntimes;
    bool crt = false;
    override void draw()
    {
        ImageRef!RGBA fb = framebuffer();

        console.palette(TM_paletteCampbell);
        console.outbuf(fb.pixels, fb.w, fb.h, fb.pitch);

        TM_Options opt;
        opt.crtEmulation = crt;
        console.options(opt);

        with (console)
        {
            cls();

            print("Hello world! ");
            println("Same, with line feed");

            // Save state (colors, style, cursor position)
            save();

            // Change foreground color (0 to 15)
            fg(TM_colorWhite);

            bg(TM_colorBlue);
            println("on blue background");

            // Restore state. Warning: this restore cursor position!
            restore();

            // Set text cursor position (where text is drawn next)
            locate(7, 5);

            // There are 3 implemented styles:
            //   - bold
            //   - shiny (sort of bloom)
            //   - underline
            style(TM_styleBold);
            println("This is bold");

            style(TM_styleShiny);
            print("This is ");
            fg(14);
            print("shiny");

            style(TM_styleShiny | TM_styleBlink);
            println(" and blinking");

            style(TM_styleNone);
            cprintln("<lblue><on_red>Press SPACE to enable CRT simulation</></>");

            style(TM_styleUnder);
             fg(TM_colorLGreen);
            println("This is underline");

            render();
        }
    }

    TM_Console console;
}

