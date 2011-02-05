
set framex 30
set framey 30
set framewidth 300
set frameheight 300

set filterx 150
set filtery 150
set filterwidth 100
set filterheight 150

proc startmovefilterbox {x y} {.c addtag movefilterbox closest $x $y}
proc movefilterbox {x} {
    set ::filterwidth [expr abs(($::framewidth/2) - $x)]
    puts stderr "filterwidth $::filterwidth"
    .c coords movefilterbox [expr ($::filterwidth/2)-$::filterx] $::framey \
         [expr ($::filterwidth/2)+$::filterx] [expr $::frameheight+$::framey]
}

proc startmovemey {x y} {.c addtag movemey closest $x $y}
proc movemey {y} {.c coords movemey $::framex $y [expr $::framewidth+$::framex] $y}

proc stopmoveme {} {
    .c dtag movefilterbox
    .c dtag movemey
}

wm geometry . 400x400
canvas .c
pack .c -side left -expand 1 -fill both

.c create rectangle $framex $framey [expr $framewidth+$framex] [expr $frameheight+$framey] \
    -tags filterframe -outline gray -fill "#eeeeff"

.c create rectangle $filterx $framey [expr $filterwidth+$filterx] [expr $frameheight+$framey] \
    -tags [list filterbox lines] \
    -outline red -activewidth 2

.c create line $framex $filtery [expr $::framewidth+$::framex] $filtery \
    -tags [list horizontal lines] \
    -activewidth 2

.c bind filterbox <ButtonPress-1> "startmovefilterbox %x %y"
.c bind filterbox <Motion> "movefilterbox %x"
.c bind horizontal <ButtonPress-1> "startmovemey %x %y"
.c bind horizontal <Motion> "movemey %y"
.c bind lines <ButtonRelease-1> stopmoveme


