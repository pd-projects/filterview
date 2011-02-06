
console show

wm geometry . +500+40

set framex1 30
set framey1 30
set framex2 300
set framey2 300

set filterx1 100
set filterx2 200
set filtergain 150
set filtercenter 150
set filterbandwidth 50
set filtersideflag 1

set previousx 0
set previousy 0

proc startmovefilter {mycanvas x y} {
    puts stderr "startmovefilter $mycanvas $x $y"
    set ::previousx $x
    set ::previousy $y
    if {$x < $::filtercenter} {
        set ::filtersideflag 1
    } else {
        set ::filtersideflag 2
    }
    $mycanvas itemconfigure filtergraph -width 2
    $mycanvas bind filtergraph <Motion> "movefilter %W %x %y"
}

proc movefilter {mycanvas x y} {
    puts stderr "movefilter $mycanvas $x $y"
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
    $mycanvas coords movefilter $::filterx1 $::framey1 $::filterx2 $::framey2
    movegain $mycanvas $y
}

# TODO filter out selections by tags using withtag
# TODO there is two separate modes: 
#     1) click and move filtercenter and gain (y).
#     2) click on edges of band to adjust bandwidth/Q
proc movegain {mycanvas y} {
    puts stderr "movegain $mycanvas $y"
    set dy [expr $y - $::previousy]
    set gainy [expr $::filtergain + $dy]
    if {[expr $gainy < $::framey1]} {
        set ::filtergain $::framey1
    } elseif {[expr $gainy > $::framey2]} {
        set ::filtergain $::framey2
    } else {
        set ::filtergain $gainy
    }
    $mycanvas coords filtergain $::framex1 $::filtergain $::framex2 $::filtergain
    puts stderr "$mycanvas coords filtergain $::framex1 $::filtergain $::framex2 $::filtergain"
    set ::previousy $y
}

proc stopmoveme {mycanvas} {
    $mycanvas bind filtergraph <Motion> {}
    $mycanvas itemconfigure filtergraph -width 1
}

wm geometry . 400x400
canvas .c
pack .c -side left -expand 1 -fill both

# background
.c create rectangle $framex1 $framey1 $framex2 $framey2 \
    -outline "#eeeeee" -fill "#eeeeff" \
    -tags [list filtergraph]
# bandwidth box
.c create rectangle $filterx1 $framey1 $filterx2 $framey2 \
    -tags [list filtergraph filterbandwidth] \
    -outline red -activewidth 2
# gain line
.c create line $::framex1 $::filtergain $::framex2 $::filtergain \
    -tags [list filtergraph filtergain]

.c bind filtergraph <ButtonPress-1> "startmovefilter %W %x %y"
.c bind filtergraph <ButtonRelease-1> "stopmoveme %W"

