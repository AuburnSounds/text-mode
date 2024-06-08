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
    }

    override void draw()
    {
        ImageRef!RGBA fb = framebuffer();

        with (console)
        {
            cls;
            outputBuffer(fb.pixels, fb.w, fb.h, fb.pitch);
            println("hello!");
            println("hello!");
            println("hello!");
            locate(10, 10);
            println("hello!");
            render();
        }
    } 

    VintageConsole console;
}

