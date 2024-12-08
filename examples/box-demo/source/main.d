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
        console.size(42, 25);
    }

    override void mouseMoved(float x, float y, float dx, float dy)
    {
    }

    int _fontSel = 0;
    int _palSel = 0;

    override void update(double dt)
    {
        console.update(dt);
        if (keyboard.isDown("escape")) exitGame();
    }

    int ntimes;
    override void draw()
    {
        ImageRef!RGBA fb = framebuffer();

        console.palette(TM_Palette.campbell);
        console.outbuf(fb.pixels, fb.w, fb.h, fb.pitch);

        with (console)
        {
            cls();

            void demo(int x, int y, TM_Color col, TM_BoxStyle s, string name)
            {
                fg(col);
                box(x, y, 20, 5, s);
                locate(x+2, y+2);
                cprint(name);
            }
            fg(TM_lcyan);
            println("        ═════ BOX STYLE DEMO ═════");

            demo( 1,  2, TM_white, TM_boxThin,      "TM_boxThin");
            demo( 1,  8, TM_lblue, TM_boxLarge,     "TM_boxLarge");
            demo( 1, 14, TM_lcyan, TM_boxLargeH,    "TM_boxLargeH");
            demo( 1, 20, TM_yellow,TM_boxLargeV,    "TM_boxLargeV");
            demo(21,  2, TM_lblue, TM_boxHeavy,     "TM_boxHeavy");
            demo(21,  8, TM_lcyan, TM_boxHeavyPlus, "TM_boxHeavyPlus");
            demo(21, 14, TM_yellow, TM_boxDouble,    "TM_boxDouble");
            demo(21, 20, TM_white, TM_boxDoubleH,   "TM_boxDoubleH");
            render();
        }
    }

    TM_Console console;
}

