
set framex1 30
set framey1 30
set framex2 300
set framey2 300

set filterx 150
set filtery 150
set filterwidth 100
set filterheight 150

proc startmovefilterbox {x y} {.c addtag movefilterbox closest $x $y}
proc movefilterbox {x} {
    set ::filterwidth [expr abs(($::framex2/2) - $x)]
    puts stderr "filterwidth $::filterwidth"
    .c coords movefilterbox [expr ($::filterwidth/2)-$::filterx] $::framey1 \
         [expr ($::filterwidth/2)+$::filterx] [expr $::framey2+$::framey1]
}

proc startmovemey {x y} {.c addtag movemey closest $x $y}
proc movemey {y} {
    if {[expr $y < $::framey1]} {
        set ::filterheight $::framey1
    } elseif {[expr $y > $::framey2]} {
        set ::filterheight $::framey2
    } else {
        set ::filterheight $y
    }
    .c coords movemey $::framex1 $::filterheight $::framex2 $::filterheight
}

proc stopmoveme {} {
    .c dtag movefilterbox
    .c dtag movemey
}

wm geometry . 400x400
canvas .c
pack .c -side left -expand 1 -fill both

.c create rectangle $framex1 $framey1 $framex2 $framey2 \
    -tags filterframe -outline gray -fill "#eeeeff"

.c create rectangle $filterx $framey1 [expr $filterwidth+$filterx] $framey2 \
    -tags [list filterbox lines] \
    -outline red -activewidth 2

.c create line $framex1 $filterheight $::framex2 $filterheight \
    -tags [list horizontal lines] \
    -activewidth 2

.c bind filterbox <ButtonPress-1> "startmovefilterbox %x %y"
.c bind filterbox <Motion> "movefilterbox %x"
.c bind horizontal <ButtonPress-1> "startmovemey %x %y"
.c bind horizontal <Motion> "movemey %y"
.c bind lines <ButtonRelease-1> stopmoveme


