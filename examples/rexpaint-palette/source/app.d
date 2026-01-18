module source.app;

import std.stdio;
import std.format;
import textmode;

// Generate palette files for REXpaint.
// Copy the output .txt files in data/palettes subdir
void main()
{


    // Create a console to access palette data
    auto console = TM_Console(80, 25);

    foreach (palIdx; 0 .. TM_PALETTE_NUM)
    {
        string paletteName = console.getPaletteName(palIdx);
        // Set the palette
        console.palette(cast(TM_Palette) palIdx);

        auto filename = format("%s.txt", paletteName);
        auto f = File(filename, "w");

        writefln("Writing %s...", filename);

        // Row 1: colors 0-7, then 8 zeros
        for (int i = 0; i < 8; i++)
        {
            ubyte r, g, b, a;
            console.getPaletteEntry(i, r, g, b, a);
            f.writef("{%3d,%3d,%3d}\t", r, g, b);
        }
        for (int i = 8; i < 16; i++)
        {
            f.writef("{  0,  0,  0}\t");
        }
        f.writeln();

        // Row 2: colors 8-15, then 8 zeros
        for (int i = 8; i < 16; i++)
        {
            ubyte r, g, b, a;
            console.getPaletteEntry(i, r, g, b, a);
            f.writef("{%3d,%3d,%3d}\t", r, g, b);
        }
        for (int i = 8; i < 16; i++)
        {
            f.writef("{  0,  0,  0}\t");
        }
        f.writeln();

        // Rows 3-12: all zeros (16 per row)
        for (int row = 2; row < 12; row++)
        {
            for (int i = 0; i < 16; i++)
            {
                f.writef("{  0,  0,  0}\t");
            }
            f.writeln();
        }

        f.close();
    }

    writeln("Done! Generated ", TM_PALETTE_NUM, " palette files.");
}
