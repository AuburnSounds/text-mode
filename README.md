# text-mode

The goal of the `text-mode` DUB package is to be a virtual text-mode, like in older DOS machines, except with Unicode support instead of a single 8-bit code page. There is however a 16 color palette like in ancient text modes.

A secundary goal is to be efficient (everything is cached) and provide vintage looks.


## 0. Basic example

See `examples/` to run a basic example (you will need [SDL](https://www.libsdl.org/) installed).


### 1. Setup a `TM_Console`


The following `TM_Console` methods are necessary in order to use `text-mode`:
   - `size(int columns, int rows)`
   - `outbuf(void* p, int width, int height, int pitchBytes)`
   - `render()`


**Example:**
```d
TM_Console console;

void setup(MyImage image)
{
    // Set number of columns and rows.
    int columns = 40;
    int rows = 20;
 
    // .size clear the text buffer content and eventually resize it
    console.size(columns, rows);
 
    // set where to draw output, can be called every frame
    console.outbuf(image.ptr, image.width, image.height, image.pitchBytes);
 
    /* ...printing functions goes here... */
 
    // display changes since the last .render, in output buffer
     console.render();
}
```

> _**Key concept**: No font resampling is done. Pixels are scaled NxN depending to the room in output buffer, and letterboxed with "border" pixels._

 ### 2. Print some text

 **Example:**
```d
console.size(40, 22);

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
``` 

**Result**
![text-mode first example](example-1.png)



> _**Key-concept**: if text must be printed in a line below the screen, the whole screen scrolls._



TO DOCUMENT
- raw char data access
- print some CCL text
- tweak options

