/**
    A library for integer coord rectangles, and list of those.
    In UI and rendering, useful for caching computation.
    Also port of stb's stretchy buffers.
*/
module rectlist;

import core.stdc.stdlib: malloc, realloc, free;

nothrow @nogc @safe:


/*
 _____ _____ _____ _____ _____ _____ _____ __    _____
| __  |   __|     |_   _|  _  |   | |   __|  |  |   __|
|    -|   __|   --| | | |     | | | |  |  |  |__|   __|
|__|__|_____|_____| |_| |__|__|_|___|_____|_____|_____|

*/

/**
    2D rectangle, int coordinates.
*/
struct rect_t {
nothrow @nogc @safe:
    int left;
    int top;
    int right;
    int bottom;

    bool isEmpty() { return rectIsEmpty(this); }
}


/**
    Build rectangles with coordinates.
*/
rect_t rectWithCoords(int left, int top, int right, int bottom) {
    return rect_t(left, top, right, bottom);
}


/**
    Build rectangles with one point + dimensions.
*/
rect_t rectWithSize(int left, int top, int width, int height) {
    return rect_t(left, top, left + width, top + height);
}


/**
    Width of rectangle.
*/
int rectWidth(const(rect_t) r) {
    return r.right - r.left;
}


/**
    Height of rectangle.
*/
int rectHeight(const(rect_t) r) {
    return r.bottom - r.top;
}


/**
    Returns: `true` if empty (one or both dimension is zero).
*/
bool rectIsEmpty(const(rect_t) r) {
    if (r.left == r.right) return true;
    if (r.top == r.bottom) return true;
    return false;
}


/**
    Returns: `true` if rectangle has >=0 width and height.
*/
bool rectIsSorted(const(rect_t) r) {
    return r.right >= r.left && r.bottom >= r.top;
}


/**
    Returns: `true` if it contains a 2D point.
*/
bool rectContainsPoint(const(rect_t) r, int pointX, int pointY) {
    assert(rectIsSorted(r));
    return pointX >= r.left && pointX < r.right
        && pointY >= r.top  && pointY < r.bottom;
}


/**
    Returns: `true` if rectangle `r` contains another `o`.
*/
bool rectContainsRect(const(rect_t) r, const(rect_t) o) {
    assert(rectIsSorted(r));
    assert(rectIsSorted(o));
    if ( (o.left < r.left) || (o.right > r.right) ) return false;
    if ( (o.left < r.left) || (o.right > r.right) ) return false;
    return true;
}


/**
    Returns: Intersection of two rectangles.
    Note: check with `rectIsEmpty`.
*/
rect_t rectIntersection(const(rect_t) a, const(rect_t) b) {
    assert(rectIsSorted(a));
    assert(rectIsSorted(b));

    // Return empty rect if one of the rect is empty
    if (rectIsEmpty(a)) return a;
    if (rectIsEmpty(b)) return b;

    int maxLeft   = (a.left   > b.left  ) ? a.left   : b.left;
    int minRight  = (a.right  < b.right ) ? a.right  : b.right;
    int maxTop    = (a.top    > b.top   ) ? a.top    : b.top;
    int minBottom = (a.bottom < b.bottom) ? a.bottom : b.bottom;

    rect_t r;
    r.left   = maxLeft;
    r.right  = minRight >= maxLeft ? minRight : maxLeft;
    r.top    = maxTop;
    r.bottom = minBottom >= maxTop ? minBottom : maxTop;
    assert(rectIsSorted(r));
    return r;
}
   

/**
    Returns: `true` if two rectangles intersect.
*/
bool rectCheckIntersects(const(rect_t) a, const(rect_t) b) {
    return !rectIsEmpty(rectIntersection(a, b));
}


/**
    Returns a rectangle that encloses both `a` and `b`.
*/
rect_t rectMerge(const(rect_t) a, const(rect_t) b) {
    assert(rectIsSorted(a));
    assert(rectIsSorted(b));

    if (rectIsEmpty(a)) return b;
    if (rectIsEmpty(b)) return a;

    int minLeft   = (a.left   < b.left  ) ? a.left   : b.left;
    int maxRight  = (a.right  > b.right ) ? a.right  : b.right;
    int minTop    = (a.top    < b.top   ) ? a.top    : b.top;
    int maxBottom = (a.bottom > b.bottom) ? a.bottom : b.bottom;

    rect_t r;
    r.left   = minLeft;
    r.right  = maxRight;
    r.top    = minTop;
    r.bottom = maxBottom;
    assert(rectIsSorted(r));
    return r;
}

/**
    Returns: Rectangle that encloses both `a` and point `x`,`y`.
*/
rect_t rectMergeWithPoint(const(rect_t) a, int x, int y) {
    assert(rectIsSorted(a));
    if (rectIsEmpty(a)) {
        return rect_t(x, y, x+1, y+1);
    }
    else {
        rect_t r = a;
        if (r.left    > x  ) r.left   = x;
        if (r.top     > y  ) r.top    = y;
        if (r.right   < x+1) r.right  = x+1;
        if (r.bottom  < y+1) r.bottom = y+1;
        return r;
    }
}

/**
    Returns: `true` if none of the rectangles overlap with each
    other. VERY INEFFICIENT, keep it for debug purpose.
*/
bool rectHaveNoOverlap(const(rect_t)[] rects) {
    foreach(i; 0..rects.length) {
        assert(rectIsSorted(rects[i]));
        foreach (j; i+1..rects.length)
            if (rectCheckIntersects(rects[i], rects[j]))
                return false;
    }
    return true;
}


/**
    Returns: A translated rectangle by dx, dy.
*/
rect_t rectTranslate(rect_t r, int dx, int dy) {
    r.right   += dx;
    r.left    += dx;
    r.top     += dy;
    r.bottom  += dy;
    return r;
}


/**
    Returns: This rectangle, extended on all sides by the given
    amount.
*/
rect_t rectGrow(rect_t r, int amount) {
    r.left   -= amount;
    r.right  += amount;
    r.top    -= amount;
    r.bottom += amount;
    return r;
}


/**
    Returns: This rectangle, extended by different amounts
    horizontally and vertically.
*/
rect_t rectGrowXY(rect_t r, int amtX, int amtY) {
    r.left   -= amtX;
    r.right  += amtX;
    r.top    -= amtY;
    r.bottom += amtY;
    return r;
}


/*
 _____ _____ _____ _____ __    _  _____ _____
| __  |   __|     |_   _|  |  | ||   __|_   _|
|    -|   __|   --| | | |  |__| ||__   | | |
|__|__|_____|_____| |_| |_____|_||_____| |_|

*/


/**
    2D rectangle list, int coordinates.
*/
struct rectlist_t {
    rect_t* rects = null;
}

/**
    Returns: `true` if rectlist has no rectangle.
*/
bool rectlistIsEmpty(ref rectlist_t rl) @trusted {
    return sb_length(rl.rects) == 0;
}

/**
    Push back one rectangle at the end of the list.
*/
void rectlistPush(ref rectlist_t rl, rect_t r) @trusted {
    sb_push(rl.rects, r);
}

/**
    Push back one rectangle if not empty.
*/
void rectlistPushIfNotEmpty(ref rectlist_t rl, rect_t r) @trusted {
    if (!rectIsEmpty(r)) sb_push(rl.rects, r);
}


/**
    Clear rectangles, and release the allocation.
    List is now an empty list.
*/
void rectlistFree(ref rectlist_t rl) @trusted {
    sb_free(rl.rects);
}

/**
     Returns: number of rectangle in list.
*/
int rectlistCount(ref const(rectlist_t) rl) @trusted {
    return sb_length(rl.rects);
}

/**
    Return nth items of list.
*/
ref inout(rect_t) rectlistNth(ref inout(rectlist_t) rl, int nth)
    @trusted {
    return rl.rects[nth];
}

/**
    Clear list of rectangles to 0 items, but keep the allocation.
*/
void rectlistClear(ref rectlist_t rl) @trusted {
    sb_clear(rl.rects);
}

/**
    Returns: rectangles in the list as a slice.
*/
inout(rect_t)[] rectlistRectangles(ref inout(rectlist_t) rl)
@trusted {
    int count = rectlistCount(rl);
    if (count == 0) return [];
    return rl.rects[0..count];
}

/**
    Returns: A single rectangle that contains other rectangles in the
    list, as a bounding box.
*/
rect_t rectlistBounds(ref const(rectlist_t) rl) @trusted {
    rect_t res;
    assert(rectIsEmpty(res));
    foreach(i; 0..rectlistCount(rl)) {
        res = rectMerge(res, rl.rects[i]);
    }
    return res;
}

/**
    Returns: `true` if none of the rectangles overlap with each
    other. VERY INEFFICIENT, keep it for debug purpose.
*/
bool rectlistHasNoOverlap(ref const(rectlist_t) rl) {
    return rectHaveNoOverlap(rectlistRectangles(rl));
}
unittest {
    rectlist_t rl;
    rectlistPush(rl, rect_t(0, 0, 1, 1));
    rectlistPush(rl, rect_t(1, 1, 2, 2));
    assert(rectlistHasNoOverlap(rl));
    rectlistClear(rl);
    assert(rectlistCount(rl) == 0);

    rectlistPush(rl, rect_t( 0, 0, 1, 1));
    rectlistPush(rl, rect_t( 0, 0, 2, 1));
    assert( ! rectlistHasNoOverlap(rl));
}

/**
    Take rectangles in input, make it non-overlapping and push the
    result in output rectlist.
    Warning: Input is destroyed!
    Note: this is not very efficient, O(n^2) complexity.
*/
void rectlistRemoveOverlapping(ref rectlist_t input,
                               ref rectlist_t output) @trusted {
    for (int i = 0; i < rectlistCount(input); ++i) {

        rect_t A = rectlistNth(input, i);
        assert(rectIsSorted(A));

        // empty boxes aren't kept
        if (rectIsEmpty(A))
            continue;

        bool foundIntersection = false;

        // Test A against other rectangles. If pass, it is pushed.
        for(int j = i + 1; j < rectlistCount(input); ++j) {
            rect_t B = rectlistNth(input, j);
            rect_t C = rectIntersection(A, B);
            if ( ! rectIsEmpty(C)) {
                // Case 1: A contains B
                // => B is removed from input
                if (rectContainsRect(A, B)) {
                    // Remove that box since it has been dealt with
                    sb_delete_nth_replace_by_last(input.rects, j);
                    j = j - 1; // no need to tweak i since i < j
                    continue;
                }
                foundIntersection = true; // A not pushed as is

                if (rectContainsRect(B, A)) {
                    // Keep the larger rectangle, drop A
                    break;
                }
                else {
                    // computes A without (A inter B)

                    enum FORMER_SPLIT_ALGO = false;
                    static if (FORMER_SPLIT_ALGO) {
                        rect_t D, E, F, G;
                        rectSubtractionH(A, C, D, E, F, G);
                        rectlistPushIfNotEmpty(input, D);
                        rectlistPushIfNotEmpty(input, E);
                        rectlistPushIfNotEmpty(input, F);
                        rectlistPushIfNotEmpty(input, G);
                    }
                    else {
                        // newer algo splits in 2 ways and keeps best
                        rect_t D, E, F, G;
                        rect_t H, I, J, K;
                        rectSubtractionH(A, C, D, E, F, G);
                        rectSubtractionV(A, C, H, I, J, K);

                        static int minOfWidthHeight(rect_t r) {
                            int w = rectWidth(r);
                            int h = rectHeight(r);
                            return w < h ? w : h;
                        }

                        static int evalSplit(rect_t r0, rect_t r1,
                                             rect_t r2, rect_t r3) {
                            int s0 = minOfWidthHeight(r0);
                            int s1 = minOfWidthHeight(r1);
                            int s2 = minOfWidthHeight(r2);
                            int s3 = minOfWidthHeight(r3);
                            s0 = s0 > s1 ? s0 : s1;
                            s2 = s2 > s3 ? s2 : s3;
                            return s0 > s2 ? s0 : s2;
                        }

                        int scoreH = evalSplit(D, E, F, G);
                        int scoreV = evalSplit(H, I, J, K);
                        if (scoreH > scoreV) {
                            rectlistPushIfNotEmpty(input, D);
                            rectlistPushIfNotEmpty(input, E);
                            rectlistPushIfNotEmpty(input, F);
                            rectlistPushIfNotEmpty(input, G);
                        }
                        else {
                            rectlistPushIfNotEmpty(input, H);
                            rectlistPushIfNotEmpty(input, I);
                            rectlistPushIfNotEmpty(input, J);
                            rectlistPushIfNotEmpty(input, K);
                        }
                    }
                    break;
                }
            }
        }
        if (!foundIntersection)
            rectlistPush(output, A);
    }
}

unittest {
    rectlist_t rl;
    rectlistPush(rl, rect_t(0, 0, 4, 4));
    rectlistPush(rl, rect_t(2, 2, 6, 6));
    rectlistPush(rl, rect_t(1, 1, 2, 2));
    assert(rectlistBounds(rl) == rect_t(0, 0, 6, 6));
    rectlist_t ab;
    rectlistRemoveOverlapping(rl, ab);

    assert(rectlistRectangles(ab) ==
           [ rect_t(2, 2, 6, 6),
             rect_t(0, 0, 4, 2),
             rect_t(0, 2, 2, 4) ]
          ||
          rectlistRectangles(ab) ==
           [ rect_t(2, 2, 6, 6),
             rect_t(0, 0, 2, 4),
             rect_t(2, 0, 4, 2) ]);
    assert(rectlistBounds(ab) == rect_t(0, 0, 6, 6));
}


/**
    Make 4 boxes that are A without C (C is contained in A)
    Some may be empty though since C touch at least one edge of A.

  General case: at least one of D, E, F or G is empty.
    +---------+               +---------+
    |    A    |               |    D    |
    |  +---+  |   After split +--+---+--+
    |  | C |  |        =>     | E|   |F |
    |  +---+  |               +--+---+--+
    |         |               |    G    |
    +---------+               +---------+
*/
void rectSubtractionH(rect_t A, rect_t C, 
                      out rect_t D, out rect_t E, 
                      out rect_t F, out rect_t G)
{
    D = rectWithCoords(A.left, A.top, A.right, C.top);
    E = rectWithCoords(A.left, C.top, C.left, C.bottom);
    F = rectWithCoords(C.right, C.top, A.right, C.bottom);
    G = rectWithCoords(A.left, C.bottom, A.right, A.bottom);
}


/**
+---------+               +---------+
|    A    |               |  | E |  |
|  +---+  |   After split +  +---+  +
|  | C |  |        =>     | D|   |G |
|  +---+  |               +  +---+  +
|         |               |  | F |  |
+---------+               +---------+
*/
void rectSubtractionV(rect_t A, rect_t C,
                      out rect_t D, out rect_t E,
                      out rect_t F, out rect_t G)
{
    D = rectWithCoords(A.left, A.top, C.left, A.bottom);
    E = rectWithCoords(C.left, A.top, C.right, C.top);
    F = rectWithCoords(C.left, C.bottom, C.right, A.bottom);
    G = rectWithCoords(C.right, C.top, A.right, A.bottom);
}


/*
 _____ _____ _____ _____ _____ _____ _____
| __  |  |  |   __|   __|   __| __  |   __|
| __ -|  |  |   __|   __|   __|    -|__   |
|_____|_____|__|  |__|  |_____|__|__|_____|

Basically the stretchy buffer in stb.

*/
public @system
{
    /**
        Number of items currently in stretchy buffer.
    */
    int sb_count(T)(scope T* a) { return a ? sb_n(a) : 0; }
    alias sb_length = sb_count; /// ditto
    alias sb_size   = sb_count; /// ditto

    /**
        Capacity of the stretchy buffer.
    */
    int sb_capacity(T)(scope T* a) { return a ? sb_m(a) : 0; }

    /**
        Push back one item in stretchy buffer.
    */
    void sb_push(T)(scope ref T* a, T v) {
        sb_maybegrow(a,1); a[sb_n(a)++] = v;
    }

    /**
        Free the stretchy buffer. It becomes `null`.
    */
    void sb_free(T)(scope ref T* a) {
        if (a) free(sb_raw(a));
        a = null;
    }

    /**
        First item in stretchy buffer.
    */
    T sb_first(T)(scope T* a) { return a[0]; }

    /**
        Last item in stretchy buffer.
    */
    T sb_last(T)(scope T* a) { return a[sb_n(a) - 1]; }

    /**
        Clear existing items.
    */
    void sb_clear(T)(scope T* a) { if (a) sb_n(a) = 0; }

    /**
        Delete one item, replace by last item in the buffer.
    */
    void sb_delete_nth_replace_by_last(T)(scope T* a, int index) {
        int n = sb_n(a);
        assert(index >= 0 && index < n);
        a[index] = a[n-1];
        sb_n(a) -= 1;
    }
}
private @system
{
    int* sb_raw(T)(scope T* a) {
        return (cast(int *) cast(void *)a - 2);
    }
    ref int sb_m(T)(scope T* a) { return sb_raw(a)[0]; }
    ref int sb_n(T)(scope T* a) { return sb_raw(a)[1]; }
    bool sb_needgrow(T)(scope T* a, int n) {
        return (a == null) || (sb_n(a) + n >= sb_m(a));
    }
    void* sb_maybegrow(T)(scope ref T* a, int n) {
        return sb_needgrow(a, n) ? sb_grow(a, n) : null;
    }
    void* sb_grow(T)(scope ref T* a, int n) {
        alias increment = n;
        int itemsize = cast(int)T.sizeof;
        void** arr = cast(void **)&a;
        int m = *arr ? 2*sb_m(*arr)+increment : increment+1;
        void* r = *arr ? sb_raw(*arr) : null;
        void *p = realloc(r, itemsize * m + int.sizeof*2);
        assert(p);
        if (p) {
            if (!*arr) (cast(int *) p)[1] = 0;
            *arr = cast(void *) (cast(int *) p + 2);
            sb_m(*arr) = m;
        }
        return *arr;
    }
}

@trusted unittest
{
    int i;
    int *arr;
    for (i=0; i < 1000000; ++i)
        sb_push(arr, i);
    assert(sb_count(arr) == 1000000);
    for (i=0; i < 1000000; ++i)
        assert(arr[i] == i);
    sb_free(arr);
}