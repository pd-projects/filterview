
set framex1 30
set framey1 30
set framex2 300
set framey2 300

set filterx1 100
set filtery1 150
set filterx2 200
set filtery2 150
set filtercenter 150
set filtersideflag 1

proc startmovefilterbox {x y} {
    .c addtag movefilterbox closest $x $y
    if {$x < $::filtercenter} {
        set ::filtersideflag 1
    } else {
        set ::filtersideflag 2
    }
}
proc movefilterbox {x w} {
    puts stderr "movefilterbox $w"
    if {$::filtersideflag == 1} {
        if {$x < $::framex1} {
            set ::filterx1 $::framey1
        } elseif {$x < [expr $::filtercenter]} {
            set ::filterx1 $x
        } elseif {$x < $::framey2} {
            set ::filterx2 $x
        } else {
            set ::filterx2 $::framey2
        }
    } else {
    }
    .c coords movefilterbox $::filterx1 $::framey1 \
         $::filterx2 $::framey2
}

# TODO filter out selections by tags using withtag
# TODO there is two separate modes: 
#     1) click and move filtercenter and gain (y).
#     2) click on edges of band to adjust bandwidth/Q
proc startmovemey {x y} {.c addtag movemey closest $x $y}
proc movemey {y} {
    if {[expr $y < $::framey1]} {
        set ::filtery2 $::framey1
    } elseif {[expr $y > $::framey2]} {
        set ::filtery2 $::framey2
    } else {
        set ::filtery2 $y
    }
    .c coords movemey $::framex1 $::filtery2 $::framex2 $::filtery2
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

.c create rectangle $filterx1 $framey1 $filterx2 $framey2 \
    -tags [list filterbox lines] \
    -outline red -activewidth 2

.c create line $framex1 $filtery2 $::framex2 $filtery2 \
    -tags [list horizontal lines] \
    -activewidth 2

.c bind filterbox <ButtonPress-1> "startmovefilterbox %x %y"
.c bind filterbox <Motion> "movefilterbox %x %W"
.c bind horizontal <ButtonPress-1> "startmovemey %x %y"
.c bind horizontal <Motion> "movemey %y"
.c bind lines <ButtonRelease-1> stopmoveme


