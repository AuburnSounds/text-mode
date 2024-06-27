import turtle;
import textmode;

int main(string[] args)
{
    runGame(new TermExample());
    return 0;
}

class TermExample : TurtleGame
{
    this()
    {

    }

    override void load()
    {
        setBackgroundColor(color("rgba(0, 0, 0, 0%)"));
        console.size(40, 22);
    }

    override void mouseMoved(float x, float y, float dx, float dy)
    {
    }

    int _fontSel = 0;
    int _palSel = 0;

    override void update(double dt)
    {
        if (keyboard.isDown("escape")) exitGame();
    }

    int ntimes;
    override void draw()
    {
        ImageRef!RGBA fb = framebuffer();

        
        TM_Options options;
        options.allowOutCaching = true; // doable because background color is set to transparent
        console.options(options);

        console.palette(TM_Palette.campbell);
        console.outbuf(fb.pixels, fb.w, fb.h, fb.pitch);

        with (console)
        {
            cls();

            print("Hello world! ");
            println("Same, with line feed");

            // Save state (colors, style, cursor position)
            save();

            // Change foreground color (0 to 15)
            fg(TM_red);
            print("This is red text ");
            bg(TM_blue);
            println("on blue background");

            // Restore state. Warning: this restore cursor position!
            restore();

            // Set text cursor position (where text is drawn next)
            locate(7, 5);

            // There are 3 implemented styles:
            //   - bold
            //   - shiny (sort of bloom)
            //   - underline
            style(TM_bold);
            println("This is bold");

            style(TM_shiny);
            print("This is ");
            fg(14);
            println("shiny");

            style(TM_underline);
             fg(TM_lgreen);
            println("This is underline");

            render();
        }
    } 

    TM_Console console;
}

