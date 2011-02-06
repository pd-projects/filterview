
console show
# TODO filter out selections by tags using withtag
# TODO there is two separate modes: 
#     1) click and move filtercenter and gain (y).
#     2) click on edges of band to adjust bandwidth/Q

wm geometry . +500+40

set framex1 30
set framey1 30
set framex2 300
set framey2 300

set filterx1 100
set filterx2 200
set filtergain 150
set filtercenter 150
set filterwidth 50
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
    $mycanvas itemconfigure filterlines -width 2
    $mycanvas bind filtergraph <Motion> "movefilter %W %x %y"
}

proc movefilter {mycanvas x y} {
    puts stderr "movefilter $mycanvas $x $y"
# move bandwidth
    set dx [expr $x - $::previousx]
    set x1 [expr $::filterx1 + $dx]
    set x2 [expr $::filterx2 + $dx]
    if {$x1 < $::framex1} {
        set ::filterx1 $::framex1
        set ::filterx2 [expr $::framex1 + $::filterwidth]
    } elseif {$x2 > $::framex2} {
        set ::filterx1 [expr $::framex2 - $::filterwidth]
        set ::filterx2 $::framex2
    } else {
        set ::filterx1 $x1
        set ::filterx2 $x2
    }
    $mycanvas coords filterband $::filterx1 $::framey1 $::filterx2 $::framey2
    set ::previousx $x
# move gain
    set gainy [expr $::filtergain + $y - $::previousy]
    if {[expr $gainy < $::framey1]} {
        set ::filtergain $::framey1
    } elseif {[expr $gainy > $::framey2]} {
        set ::filtergain $::framey2
    } else {
        set ::filtergain $gainy
    }
    $mycanvas coords filtergain $::framex1 $::filtergain $::framex2 $::filtergain
    set ::previousy $y
}

proc changefilterwidth {mycanvas x y} {
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
}

proc stopmoveme {mycanvas} {
    $mycanvas bind filtergraph <Motion> {}
    $mycanvas itemconfigure filterlines -width 1
}

wm geometry . 400x400
canvas .c
pack .c -side left -expand 1 -fill both

# background
.c create rectangle $framex1 $framey1 $framex2 $framey2 \
    -outline "#bbbbcc" -fill "#eeeeff" \
    -tags [list filtergraph]
# bandwidth box
.c create rectangle $filterx1 $framey1 $filterx2 $framey2 \
    -outline red -fill "#ebe8e8" \
    -tags [list filtergraph filterlines filterband]
# gain line
.c create line $::framex1 $::filtergain $::framex2 $::filtergain \
    -tags [list filtergraph filterlines filtergain]

.c bind filtergraph <ButtonPress-1> "startmovefilter %W %x %y"
.c bind filtergraph <ButtonRelease-1> "stopmoveme %W"
