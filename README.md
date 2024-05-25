# cp437


A library to render CP437 characters in an image, in a low CPU way. To be used in a virtual console.


# Usage



```
enum CP437Font
{

}


struct CP437
{
	/// Set size of internal buffer.
	void setConsoleSize(int rows, int columns);

	/// Change selected font.
	void setFont(CP437Font font);

	/// Clear console screen.
	void cls();
}


