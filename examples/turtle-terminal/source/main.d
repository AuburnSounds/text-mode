import turtle;
import vintageconsole;

int main(string[] args)
{
    runGame(new TermExample());
    return 0;
}

class TermExample : TurtleGame
{
    this()
    {
        console.size(80, 25);
        console.font(VCFont.pcvga);
    }

    override void load()
    {
    }

    override void mouseMoved(float x, float y, float dx, float dy)
    {
    }

    override void update(double dt)
    {
        if (keyboard.isDown("escape")) exitGame;

        if (keyboard.isDown("space"))
            with(console)
        {
            for (int i = 0; i < 256; ++i)
            {
                fg(i & 15);
                bg(cast(ubyte)(i >>> 4));
                string s;
                s ~= cast(char)i;
                print(s);
            }
        }
    }

    int ntimes;
    override void draw()
    {
        ImageRef!RGBA fb = framebuffer();

        with (console)
        {
            outputBuffer(fb.pixels, fb.w, fb.h, fb.pitch);

            render();
        }
    } 

    VCConsole console;
}

