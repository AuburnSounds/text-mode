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

    int _fontSel = 0;
    int _palSel = 0;

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
                println("");
            }

        if (keyboard.isDown("left"))
        {
            if (++_fontSel > VCFont.max) 
                _fontSel = VCFont.min;
            console.font( cast(VCFont) _fontSel );
        }
        if (keyboard.isDown("right"))
        {
            if (--_fontSel < VCFont.min) 
                _fontSel = VCFont.max;
            console.font( cast(VCFont) _fontSel );
        }
        if (keyboard.isDown("up"))
        {
            if (++_palSel > VCPalette.max) 
                _palSel = VCPalette.min;
            console.palette( cast(VCPalette) _palSel );
        }
        if (keyboard.isDown("down"))
        {
            if (--_palSel < VCPalette.min) 
                _palSel = VCPalette.max;
            console.palette( cast(VCPalette) _palSel );
        }
    }

    int ntimes;
    override void draw()
    {
        ImageRef!RGBA fb = framebuffer();

        with (console)
        {
        //    cls;
          //  println("Hello world!");
            //println("Enter prompt: $ABCDEFGH+=");

            console.outbuf(fb.pixels, fb.w, fb.h, fb.pitch);
            render();
        }
    } 

    VCConsole console;
}

