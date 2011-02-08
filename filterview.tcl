#!/bin/sh
# This line continues for Tcl, but is a single line for 'sh' \
    exec /usr/bin/wish "$0" -- ${1+"$@"}

#catch {console show}

package require Tk

set tcl_precision 6  ;# http://wiki.tcl.tk/8401

set framex1 30.0
set framey1 30.0
set framex2 300.0
set framey2 300.0
set midpoint [expr (($::framey2 - $::framey1) / 2) + $::framey1]
set hzperpixel [expr 20000.0 / ($::framex2 - $::framex1)]
set magnatudeperpixel [expr 0.5 / ($::framey2 - $::framey1)]

set filterx1 120.0
set filterx2 180.0
set filterlimit1 100.0
set filterlimit2 200.0

set filtergain 150
set filterwidth [expr $::filterx2 - $::filterx1]
set filtercenter [expr $::filterx1 + ($::filterwidth/2)]
set lessthan_filtercenter 1

set previousx 0
set previousy 0

set pi [expr acos(-1)]
set 2pi [expr 2.0*$pi]
set LN2 0.69314718
set samplerate 44100

# coefficients for [biquad~]
set a0 0
set a1 0
set a2 1
set b1 0
set b2 0

# colors
set markercolor "#bbbbcc"

#------------------------------------------------------------------------------#
proc generate_plotpoints {} {
    set framewidth [expr int($::framex2 - $::framex1)]
    puts stderr "generate_plotpoints $framewidth"
    for {set x [expr int($::framex1)]} {$x <= $::framex2} {incr x [expr $framewidth/10]} {
        lappend plotpoints $x
        lappend plotpoints [calc_magnatude [expr ($x - $::framex1) * $::hzperpixel]]
    }
#    puts stderr "plotpoints $plotpoints"
    return $plotpoints
}

proc drawgraph {mycanvas} {
    set plotpoints [generate_plotpoints]
    puts stderr "$mycanvas coords response $plotpoints"
    $mycanvas coords responseline $plotpoints
    $mycanvas coords responsefill [concat $plotpoints $::framex2 $::framey2 $::framex1 $::framey2]
}

#------------------------------------------------------------------------------#
# calculate magnatude and phase of a given frequency for a set of
# biquad coefficients.  f is input freq in radians
proc calc_magnatude {f} {
    set x1 [expr cos($f)]
    set x2 [expr cos(2*$f)]
    set y1 [expr sin($f)]
    set y2 [expr sin(2*$f)]

    set A [expr $::a0 + $::a1*$x1 + $::a2*$x2]
    set B [expr $::a1*$y1 + $::a2*$y2]
    set C [expr 1 + $::b1*$x1 + $::b2*$x2]
    set D [expr $::b1*$y1 + $::b2*$y2]
    set ccdd [expr $C*$C + $D*$D]

    set r [expr ($A*$C + $B*$D) / ($ccdd)]
    set i [expr ($A*$D - $B*$C) / ($ccdd)]
    
    set magnatude [expr sqrt($r*$r + $i*$i)]
#    set phase [expr atan2($i, $r)]

#    return [list $magnatude $phase]
    puts stderr "MAGNATUDE $magnatude"
    return [expr ($magnatude - 0.75) / $::magnatudeperpixel + $::framey1]
}

#------------------------------------------------------------------------------#
# calculate coefficients

proc e_omega {f r} {
    return [expr $::2pi*$f/$r]
}

proc e_alpha {bw omega} {
    return [expr sin($omega)*sinh($::LN2/2.0 * $bw * $omega/sin($omega))]
}

# lowpass
#    f0 = frequency in Hz
#    bw = bandwidth where 1 is an octave
proc lowpass {f0pix bwpix} {
    set f [expr ($f0pix - $::framex1) * $::hzperpixel]
    set bw [expr $bwpix / 100.0]
    puts stderr "lowpass: $f $bw $::filtercenter $::filterwidth"
    set omega [e_omega $f $::samplerate]
#    set alpha [e_alpha [expr $bw] $omega]
    set alpha [expr sin($omega)/(2.0*$bw)]
    set b1 [expr 1.0 - cos($omega)]
    set b0 [expr $b1/2.0]
    set b2 $b0
    set a0 [expr 1.0 + $alpha]
    set a1 [expr -2.0*cos($omega)]
    set a2 [expr 1.0 - $alpha]

# get this from ggee/filters
#    if {!check_stability(-a1/a0,-a2/a0,b0/a0,b1/a0,b2/a0)} {
#       post("lowpass: filter unstable -> resetting")]
#        set a0 1; set a1 0; set a2 0
#        set b0 1; set b1 0; set b2 0
#    }

    set ::a0 [expr -$a1/$a0]
    set ::a1 [expr -$a2/$a0]
    set ::a2 [expr $b0/$a0]
    set ::b1 [expr $b1/$a0]
    set ::b2 [expr $b2/$a0]
#    puts stderr "\t\tBIQUAD lowpass $::a0 $::a1 $::a2 $::b1 $::b2"
}


#------------------------------------------------------------------------------#

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
    set ::filterwidth [expr $::filterx2 - $::filterx1]
    set ::filtercenter [expr $::filterx1 + ($::filterwidth/2)]
    $mycanvas coords filterbandleft $::filterx1 $::framey1  $::filterx1 $::framey2
    $mycanvas coords filterbandcenter $::filtercenter $::framey1  $::filtercenter $::framey2
    $mycanvas coords filterbandright $::filterx2 $::framey1  $::filterx2 $::framey2
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
    lowpass $::filtercenter $::filterwidth
    drawgraph $mycanvas
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
    $mycanvas bind bandedges <Leave> {}
    $mycanvas bind bandedges <Enter> {}
    $mycanvas bind bandedges <Motion> {}
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
        } elseif {$x < $::framex1} {
            set ::filterx1 $::framex1
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
        } elseif {$x > $::framex2} {
            set ::filterx2 $::framex2
            set ::filterx1 [expr $::filterx2 - $::filterwidth] 
        } elseif {$x < $::filtercenter} {
            set ::filterx1 $::filtercenter
            set ::filterx2 $::filtercenter
        } else {
            set ::filterx2 $x
            set ::filterx1 [expr $::filterx1 - $dx]
        }
    }
    set ::filterwidth [expr $::filterx2 - $::filterx1]
    set ::filtercenter [expr $::filterx1 + ($::filterwidth/2)]
    $mycanvas coords filterbandleft $::filterx1 $::framey1  $::filterx1 $::framey2
    $mycanvas coords filterbandcenter $::filtercenter $::framey1  $::filtercenter $::framey2
    $mycanvas coords filterbandright $::filterx2 $::framey1  $::filterx2 $::framey2
    set ::previousx $x

    movegain $mycanvas $y
    lowpass $::filtercenter $::filterwidth
    drawgraph $mycanvas
}

proc filterband_cursor {mycanvas x} {
    if {$x < $::filtercenter} {
        $mycanvas configure -cursor left_side
    } else {
        $mycanvas configure -cursor right_side
    }
}

proc enterband {mycanvas} {
    puts stderr "enterband $mycanvas"
    $mycanvas bind filtergraph <ButtonPress-1> {}
    $mycanvas bind bandedges <Motion> {filterband_cursor %W %x}
    $mycanvas itemconfigure filterband -width 2
}

proc leaveband {mycanvas} {
    puts stderr "leaveband $mycanvas"
    $mycanvas bind filtergraph <ButtonPress-1> {start_movefilter %W %x %y}
    $mycanvas bind bandedges <Motion> {}
    $mycanvas configure -cursor arrow
    $mycanvas itemconfigure filterband -width 1
}

#------------------------------------------------------------------------------#

proc stop_editing {mycanvas} {
    puts stderr "stop_editing $mycanvas"
    $mycanvas bind filtergraph <Motion> {}
    $mycanvas itemconfigure filterlines -width 1
    $mycanvas configure -cursor arrow
    $mycanvas bind bandedges <Enter> {enterband %W}
    $mycanvas bind bandedges <Leave> {leaveband %W}
}

#------------------------------------------------------------------------------#

proc filterview_new {tkcanvas} {
    puts stderr "filterview_new $tkcanvas"
    # background
    $tkcanvas create rectangle $::framex1 $::framey1 $::framex2 $::framey2 \
        -outline $::markercolor -fill "#eeeeff" \
        -tags [list filtergraph]

    # magnatude response graph fill
    $tkcanvas create polygon $::framex1 $::midpoint $::framex2 $::midpoint \
        $::framex2 $::framey2 $::framex1 $::framey2 \
        -fill "#e7f6d8" \
        -tags [list filtergraph response responsefill]

    # magnatude response graph line
    $tkcanvas create line $::framex1 $::midpoint $::framex2 $::midpoint \
        -fill "#B7C6A8" -width 3 \
        -tags [list filtergraph response responseline]

    # zero line/equator
    $tkcanvas create line $::framex1 $::midpoint $::framex2 $::midpoint \
        -fill $::markercolor \
        -tags [list filtergraph]

    # bandwidth box left side
    $tkcanvas create line $::filterx1 $::framey1 $::filterx1 $::framey2 \
        -fill red \
        -tags [list filtergraph filterlines filterband filterbandleft bandedges]
    # bandwidth box center
    $tkcanvas create line $::filtercenter $::framey1 $::filtercenter $::framey2 \
        -fill "#ffbbbb" \
        -tags [list filtergraph filterlines filterband filterbandcenter]
    # bandwidth box right side
    $tkcanvas create line $::filterx2 $::framey1 $::filterx2 $::framey2 \
        -fill red \
        -tags [list filtergraph filterlines filterband filterbandright bandedges]

    # gain line
    $tkcanvas create line $::framex1 $::filtergain $::framex2 $::filtergain \
        -fill red \
        -tags [list filtergraph filterlines filtergain]

    # filtergraph binding is also changed by enter/leave on the band
    $tkcanvas bind filtergraph <ButtonPress-1> {start_movefilter %W %x %y}
    $tkcanvas bind filtergraph <ButtonRelease-1> {stop_editing %W}
    $tkcanvas bind bandedges <ButtonPress-1> {start_changebandwidth %W %x %y}
    $tkcanvas bind bandedges <ButtonRelease-1> {stop_editing %W}

    # run to set things up
    stop_editing $tkcanvas
}

wm geometry . 400x400+500+40
canvas .c
pack .c -side left -expand 1 -fill both
filterview_new .c
