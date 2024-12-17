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
        console.palette(TM_Palette.vga);
        setBackgroundColor(color("black"));
        console.size(80, 40);
    }

    override void mouseMoved(float x, float y, float dx, float dy)
    {
    }

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
            //printANS_CP437(import("Lxss banner.ans"));
            printANS(import("REXpaintexport.ans"));            
            render();
        }
    }

    TM_Console console;
}

