
set ::current "2"

proc doodle {w {color black}} {
    bind $w <1>         [list doodle'start %W %x %y $color]
    bind $w <B1-Motion> {doodle'move %W %x %y}
}

proc startmovemex {x y} {.c addtag movemex closest $x $y}
proc movemex {x} {.c coords movemex $x 20 $x 300}

proc startmovemey {x y} {.c addtag movemey closest $x $y}
proc movemey {y} {.c coords movemey 0 $y 300 $y}

proc stopmoveme {} {
    .c dtag movemex
    .c dtag movemey
}

wm geometry . 400x400
canvas .c
pack .c -side left -expand 1 -fill both

.c create rectangle 20 20 300 300 -tags frame

.c create line 30 20 30 300 -tags [list vert1 vertical lines] \
    -activewidth 2
.c create line 270 20 270 300 -tags [list vert2 vertical lines] \
    -activewidth 2
.c create line 0 50 300 50 -tags [list horizontal lines] \
    -activewidth 2

.c bind vertical <ButtonPress-1> "startmovemex %x %y"
.c bind vertical <Motion> "movemex %x"
.c bind horizontal <ButtonPress-1> "startmovemey %x %y"
.c bind horizontal <Motion> "movemey %y"
.c bind lines <ButtonRelease-1> stopmoveme


