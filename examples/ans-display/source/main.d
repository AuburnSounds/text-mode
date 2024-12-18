import std.file;
import std.string;
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
        console.size(80, 50);
        loadANS();
    }

    override void mouseMoved(float x, float y, float dx, float dy)
    {
    }

    override void update(double dt)
    {
        console.update(dt);
        if (keyboard.isDownOnce("escape")) exitGame();

        int numImg = cast(int) ANSI_IMAGES.length;
        if (keyboard.isDownOnce("left"))
        {
            imgIndex = (imgIndex - 1 + numImg) % numImg;
            loadANS();
        }
        if (keyboard.isDownOnce("right"))
        {
            imgIndex = (imgIndex + 1) % numImg;
            loadANS();
        }
    }

    int imgIndex = 0;
    enum string[] ANSI_IMAGES =
    [
        "resources/Pac-Man (UTF-8).txt",
        "resources/IBM PCjr startup screen (80x25 UTF-8 double-width text).txt",
        "resources/MiniColorsWheel.ans",
    ];

    const(char)[] ansBytes;
    bool isCP437;

    void loadANS()
    {
        const(char)[] path = ANSI_IMAGES[imgIndex];
        ansBytes = cast(char[]) std.file.read(path);

        // considered CP437 if no "UTF-8" in path
        isCP437 = path.indexOf("UTF-8") == -1;
    }

    override void draw()
    {
        ImageRef!RGBA fb = framebuffer();

        console.palette(TM_Palette.campbell);
        console.outbuf(fb.pixels, fb.w, fb.h, fb.pitch);

        with (console)
        {
            cls;
            println("Press ← and → to cycle .ans images");
            println;
            if (isCP437)
                printANS_CP437(ansBytes);
            else
                printANS(ansBytes);
            render;
        }
    }

    TM_Console console;
}

