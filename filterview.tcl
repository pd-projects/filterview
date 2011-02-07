
catch {console show}

wm geometry . +500+40

set framex1 30
set framey1 30
set framex2 300
set framey2 300

set filterx1 120
set filterx2 180
set filterlimit1 100
set filterlimit2 200

set filtergain 150
set filterwidth [expr $::filterx2 - $::filterx1]
set filtercenter [expr $::filterx1 + ($::filterwidth/2)]
set lessthan_filtercenter 1

set previousx 0
set previousy 0

# colors
set markercolor "#bbbbcc"

proc moveband {mycanvas x} {
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
}

proc movegain {mycanvas y} {
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

#------------------------------------------------------------------------------#
# move the filter

proc start_movefilter {mycanvas x y} {
    puts stderr "start_movefilter $mycanvas $x $y"
    set ::previousx $x
    set ::previousy $y
    $mycanvas configure -cursor fleur
    $mycanvas itemconfigure filterlines -width 2
    $mycanvas bind filtergraph <Motion> "movefilter %W %x %y"
}

proc movefilter {mycanvas x y} {
    moveband $mycanvas $x
    movegain $mycanvas $y
}

#------------------------------------------------------------------------------#
# change the filter

proc start_changebandwidth {mycanvas x y} {
    puts stderr "start_changebandwidth $mycanvas $x $y"
    set ::previousx $x
    set ::previousy $y
    if {$x < $::filtercenter} {
        set ::lessthan_filtercenter 1
    } else {
        set ::lessthan_filtercenter 0
    }
    $mycanvas bind filterband <Leave> {}
    $mycanvas bind filterband <Enter> {}
    $mycanvas bind filterband <Motion> {}
    $mycanvas configure -cursor sb_h_double_arrow
    $mycanvas bind filtergraph <Motion> {changebandwidth %W %x %y}
}

proc changebandwidth {mycanvas x y} {
    puts stderr "changebandwidth $mycanvas $x $y"
    set dx [expr $x - $::previousx]
    if {$::lessthan_filtercenter} {
        if {$x < $::filterlimit1} {
            set ::filterx1 $::filterlimit1
            set ::filterx2 [expr $::filterx1 + $::filterwidth] 
        } elseif {$x > $::filtercenter} {
            set ::filterx1 $::filtercenter
            set ::filterx2 $::filtercenter
        } else {
            set ::filterx1 $x
            set ::filterx2 [expr $::filterx2 - $dx]
        }
    } else {
        if {$x > $::filterlimit2} {
            set ::filterx2 $::filterlimit2
            set ::filterx1 [expr $::filterx2 - $::filterwidth] 
        } elseif {$x < $::filtercenter} {
            set ::filterx1 $::filtercenter
            set ::filterx2 $::filtercenter
        } else {
            set ::filterx2 $x
            set ::filterx1 [expr $::filterx1 - $dx]
        }
    }
#    puts stderr "$mycanvas coords filterband $::filterx1 $::framey1 $::filterx2 $::framey2"
    $mycanvas coords filterband $::filterx1 $::framey1 $::filterx2 $::framey2
    set ::previousx $x
    set ::filterwidth [expr $::filterx2 - $::filterx1]
    set ::filtercenter [expr $::filterx1 + ($::filterwidth/2)]
    movegain $mycanvas $y
}

proc filterband_cursor {mycanvas x} {
    puts stderr "filterband_cursor $mycanvas $x"
    if {$x < $::filtercenter} {
        $mycanvas configure -cursor left_side
    } else {
        $mycanvas configure -cursor right_side
    }
}

proc enterband {mycanvas} {
    puts stderr "enterband $mycanvas"
    $mycanvas bind filtergraph <ButtonPress-1> {}
    $mycanvas bind filterband <Motion> {filterband_cursor %W %x}
    $mycanvas itemconfigure filterband -width 2
}

proc leaveband {mycanvas} {
    puts stderr "leaveband $mycanvas"
    $mycanvas bind filtergraph <ButtonPress-1> {start_movefilter %W %x %y}
    $mycanvas bind filterband <Motion> {}
    $mycanvas configure -cursor arrow
    $mycanvas itemconfigure filterband -width 1
}

#------------------------------------------------------------------------------#

proc stop_editing {mycanvas} {
    puts stderr "stop_editing $mycanvas"
    $mycanvas bind filtergraph <Motion> {}
    $mycanvas itemconfigure filterlines -width 1
    $mycanvas configure -cursor arrow
    $mycanvas bind filterband <Enter> {enterband %W}
    $mycanvas bind filterband <Leave> {leaveband %W}
}

#------------------------------------------------------------------------------#

wm geometry . 400x400
canvas .c
pack .c -side left -expand 1 -fill both

# background
.c create rectangle $framex1 $framey1 $framex2 $framey2 \
    -outline $markercolor -fill "#eeeeff" \
    -tags [list filtergraph]

# bandwidth box
.c create rectangle $filterx1 $framey1 $filterx2 $framey2 \
    -outline red -fill "#ebe8e8" \
    -tags [list filtergraph filterlines filterband]

# zero line/equator
set midpoint [expr (($::framey2 - $::framey1) / 2) + $::framey1]
.c create line $::framex1 $midpoint $::framex2 $midpoint \
    -fill $markercolor \
    -tags [list filtergraph]

# gain line
.c create line $::framex1 $::filtergain $::framex2 $::filtergain \
    -tags [list filtergraph filterlines filtergain]

# filtergraph binding is also changed by enter/leave on the band
.c bind filtergraph <ButtonPress-1> {start_movefilter %W %x %y}
.c bind filtergraph <ButtonRelease-1> {stop_editing %W}
.c bind filterband <ButtonPress-1> {start_changebandwidth %W %x %y}
.c bind filterband <ButtonRelease-1> {stop_editing %W}

# run to set things up
stop_editing .c
