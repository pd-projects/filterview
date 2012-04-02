#!/bin/sh
# This line continues for Tcl, but is a single line for 'sh' \
    exec /usr/bin/wish "$0" -- ${1+"$@"}

# TODO accept biquad lists on the inlet
# TODO handle changes in samplerate
# TODO make Tcl side aware of edit mode so that the object can be selected and moved.  It should not update the graph in editmode
# TODO make Tk tags local to each instance...

#------------- .mmb edits ----------------
#
# lines 43-47: changed names of coefficient variables (they were
#		incorrect and led to confusion). I updated this
#		throughout (I think).
#
# line 54: added proc mtof for intuitive log frequency scaling.
#
# lines 64-65: converts x axis to midi notes, then frequencies, then
#		radians. Before, the conversion to radians was not
#		done, which is why the response was so jagged proc
#		calc_magnatude_phase: I reworked the math here a pretty good
#		amount. It now gives the correct magnitudes as well as
#		phases. The magnitudes are also converted to dB.
#
# line 134: I added a proc e_alphaq. I just did this to see the
#		response without resonance (q = .7071) to be sure it
#		wasn't what was causing problems. Might be useful
#		later.
#
# lines 146-147: Frequency input for calculating coefficients is a
#                 again log-scaled with mtof.
#
#-----------------------------------------
package require Tk

# global things that are generally useful
set pi [expr acos(-1)]
set 2pi [expr 2.0*$pi]
set LN2 0.69314718
set samplerate 44100

namespace eval filterview:: {
    #------------------------------
    # global variables for all instances
    
    # colors
    variable markercolor "#bbbbcc"
    variable mutedline_color "#ffbbbb"
    variable selectedline_color "#ff0000"

    # allpass, bandpass, highpass, highshelf, lowpass, lowshelf, notch, peaking, resonant
    variable filters_with_gain [list "highshelf" "lowshelf" "peaking"]

    #------------------------------
    # per-instance variables
    variable currentfiltertype "peaking"
    variable receive_name

    variable previousx 0
    variable previousy 0

    variable framex1 0
    variable framey1 0
    variable framex2 0
    variable framey2 0
    
    variable midpoint 0
    variable hzperpixel 0
    variable magnatudeperpixel 0
    
    variable filterx1 0
    variable filterx2 0

    variable filtergain 0
    variable filterwidth 0
    variable filtercenter 0
    variable lessthan_filtercenter 1

    # coefficients for [biquad~]
    variable a1 0
    variable a2 0
    variable b0 1
    variable b1 0
    variable b2 0
}

#------------------------------------------------------------------------------#
proc filterview::mtof {nn} {
    return [expr pow(2.0, ($nn-45)/12.0)*110.0]
}

proc filterview::drawgraph {tkcanvas} {
    variable framex1
    variable framey1
    variable framex2
    variable framey2
    variable a1
    variable a2
    variable b0
    variable b1
    variable b2

    set framewidth [expr int($framex2 - $framex1)]
    for {set x [expr int($framex1)]} {$x <= $framex2} {incr x [expr $framewidth/40]} {
        lappend magnatudepoints $x
        lappend phasepoints $x
        set nn [expr ($x - $framex1)/$framewidth*120+16.766]
        set result [calc_magnatude_phase \
                        [expr $::2pi * [mtof $nn] / $::samplerate] $a1 $a2 $b0 $b1 $b2 \
                       $framey1 $framey2]
        lappend magnatudepoints [lindex $result 0]
        lappend phasepoints [lindex $result 1]
    }
    $tkcanvas coords responseline $magnatudepoints
    $tkcanvas coords responsefill \
        [concat $magnatudepoints $framex2 $framey2 $framex1 $framey2]
    $tkcanvas coords phaseline $phasepoints
}

proc filterview::update_coefficients {tkcanvas} {
    variable receive_name
    variable currentfiltertype
    variable filtercenter
    variable filterwidth
    variable a1
    variable a2
    variable b0
    variable b1
    variable b2

    # run the calc for a given filter type first
    $currentfiltertype $filtercenter $filterwidth
    # send the result to pd
    pdsend "$receive_name biquad $a1 $a2 $b0 $b1 $b2"
    # update the graph
    drawgraph $tkcanvas
}

#------------------------------------------------------------------------------#
# calculate magnatude and phase of a given frequency for a set of
# biquad coefficients.  f is input freq in radians
proc filterview::calc_magnatude_phase {f a1 a2 b0 b1 b2 framey1 framey2} {
    set x1 [expr cos(-1.0*$f)]
    set x2 [expr cos(-2.0*$f)]
    set y1 [expr sin(-1.0*$f)]
    set y2 [expr sin(-2.0*$f)]

    set A [expr $b0 + $b1*$x1 + $b2*$x2]
    set B [expr $b1*$y1 + $b2*$y2]
    set C [expr 1 - $a1*$x1 - $a2*$x2]
    set D [expr 0 - $a1*$y1 - $a2*$y2]
    set numermag [expr sqrt($A*$A + $B*$B)]
    set numerarg [expr atan2($B, $A)]
    set denommag [expr sqrt($C*$C + $D*$D)]
    set denomarg [expr atan2($D, $C)]

    set magnatude [expr $numermag/$denommag]
    set phase [expr $numerarg-$denomarg]
    
    set fHz [expr $f * $::samplerate / $::2pi]

    # convert magnitude to dB scale
    set logmagnitude [expr 20.0*log($magnatude)/log(10)]
#    puts stderr "MAGNATUDE at $fHz Hz ($f radians): $magnatude dB: $logmagnitude"
    # clip
    if {$logmagnitude > 25.0} {
        set logmagnitude 25.0
    } elseif {$logmagnitude < -25.0} {
        set logmagnitude -25.0
    }
    # scale to pixel range
    set halfframeheight [expr ($framey2 - $framey1)/2.0]
    set logmagnitude [expr $logmagnitude/25.0 * $halfframeheight]
    # invert and offset
    set logmagnitude [expr -1.0 * $logmagnitude + $halfframeheight + $framey1]

    #	puts stderr "PHASE at $fHz Hz ($f radians): $phase"
    # wrap phase
    if {$phase > $::pi} {
        set phase [expr $phase - $::2pi]
    } elseif {$phase < [expr -$::pi]} {
        set phase [expr $phase + $::2pi]
    }
    # scale phase values to pixels
    set scaledphase [expr $halfframeheight*(-$phase/($::pi)) + $halfframeheight + $framey1]
    
    return [list $logmagnitude $scaledphase]
}

#------------------------------------------------------------------------------#
# calculate coefficients

proc filterview::e_omega {f r} {
    return [expr $::2pi*$f/$r]
}

proc filterview::e_alpha {bw omega} {
    return [expr sin($omega)*sinh($::LN2/2.0 * $bw * $omega/sin($omega))]
}

# just for testing
proc filterview::e_alphaq {q omega} {
    return [expr sin($omega)/(2*$q)]
}

# lowpass
#    f0 = frequency in Hz
#    bw = bandwidth where 1 is an octave
proc filterview::lowpass {f0pix bwpix} {
    variable framex1
    variable framex2

    set nn [expr ($f0pix - $framex1)/($framex2-$framex1)*120+16.766]
    set nn2 [expr ($bwpix+$f0pix - $framex1)/($framex2-$framex1)*120+16.766] 
    set f [mtof $nn]
    set bwf [mtof $nn2]
    set bw [expr ($bwf/$f)-1]
#    puts stderr "lowpass: $f $bw $filtercenter $filterwidth"
    set omega [e_omega $f $::samplerate]
    set alpha [e_alpha $bw $omega]
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

    set filterview::a1 [expr -$a1/$a0]
    set filterview::a2 [expr -$a2/$a0]
    set filterview::b0 [expr $b0/$a0]
    set filterview::b1 [expr $b1/$a0]
    set filterview::b2 [expr $b2/$a0]
}

# highpass
proc filterview::highpass {f0pix bwpix} {
    variable framex1
    variable framex2

    set nn [expr ($f0pix - $framex1)/($framex2-$framex1)*120+16.766]
    set nn2 [expr ($bwpix+$f0pix - $framex1)/($framex2-$framex1)*120+16.766] 
    set f [mtof $nn]
    set bwf [mtof $nn2]
    set bw [expr ($bwf/$f)-1]
    set omega [e_omega $f $::samplerate]
    set alpha [e_alpha $bw $omega]
    set b1 [expr -1*(1.0 + cos($omega))]
    set b0 [expr -$b1/2.0]
    set b2 $b0
    set a0 [expr 1.0 + $alpha]
    set a1 [expr -2.0*cos($omega)]
    set a2 [expr 1.0 - $alpha]
    
    set ::filterview::a1 [expr -$a1/$a0]
    set ::filterview::a2 [expr -$a2/$a0]
    set ::filterview::b0 [expr $b0/$a0]
    set ::filterview::b1 [expr $b1/$a0]
    set ::filterview::b2 [expr $b2/$a0]
}

#bandpass
proc filterview::bandpass {f0pix bwpix} {
    variable framex1
    variable framex2

    set nn [expr ($f0pix - $framex1)/($framex2-$framex1)*120+16.766]
    set nn2 [expr ($bwpix+$f0pix - $framex1)/($framex2-$framex1)*120+16.766] 
    set f [mtof $nn]
    set bwf [mtof $nn2]
    set bw [expr ($bwf/$f)-1]
    set omega [e_omega $f $::samplerate]
    set alpha [e_alpha $bw $omega]
    set b1 0
    set b0 $alpha
    set b2 [expr -$b0]
    set a0 [expr 1.0 + $alpha]
    set a1 [expr -2.0*cos($omega)]
    set a2 [expr 1.0 - $alpha]
    
    set ::filterview::a1 [expr -$a1/$a0]
    set ::filterview::a2 [expr -$a2/$a0]
    set ::filterview::b0 [expr $b0/$a0]
    set ::filterview::b1 [expr $b1/$a0]
    set ::filterview::b2 [expr $b2/$a0]
}

#resonant
proc filterview::resonant {f0pix bwpix} {
    variable framex1
    variable framex2

    set nn [expr ($f0pix - $framex1)/($framex2-$framex1)*120+16.766]
    set nn2 [expr ($bwpix+$f0pix - $framex1)/($framex2-$framex1)*120+16.766] 
    set f [mtof $nn]
    set bwf [mtof $nn2]
    set bw [expr ($bwf/$f)-1]
    set omega [e_omega $f $::samplerate]
    set alpha [e_alpha $bw $omega]
    set b1 0
    set b0 [expr sin($omega)/2]
    set b2 [expr -$b0]
    set a0 [expr 1.0 + $alpha]
    set a1 [expr -2.0*cos($omega)]
    set a2 [expr 1.0 - $alpha]
    
    set ::filterview::a1 [expr -$a1/$a0]
    set ::filterview::a2 [expr -$a2/$a0]
    set ::filterview::b0 [expr $b0/$a0]
    set ::filterview::b1 [expr $b1/$a0]
    set ::filterview::b2 [expr $b2/$a0]
}

#notch
proc filterview::notch {f0pix bwpix} {
    variable framex1
    variable framex2

    set nn [expr ($f0pix - $framex1)/($framex2-$framex1)*120+16.766]
    set nn2 [expr ($bwpix+$f0pix - $framex1)/($framex2-$framex1)*120+16.766] 
    set f [mtof $nn]
    set bwf [mtof $nn2]
    set bw [expr ($bwf/$f)-1]
    set omega [e_omega $f $::samplerate]
    set alpha [e_alpha $bw $omega]
    set b1 [expr -2.0*cos($omega)]
    set b0 1
    set b2 1
    set a0 [expr 1.0 + $alpha]
    set a1 $b1
    set a2 [expr 1.0 - $alpha]
    
    set ::filterview::a1 [expr -$a1/$a0]
    set ::filterview::a2 [expr -$a2/$a0]
    set ::filterview::b0 [expr $b0/$a0]
    set ::filterview::b1 [expr $b1/$a0]
    set ::filterview::b2 [expr $b2/$a0]
}

#peaking
proc filterview::peaking {f0pix bwpix} {
    variable framex1
    variable framey1
    variable framex2
    variable framey2
    variable filtergain

    set nn [expr ($f0pix - $framex1)/($framex2-$framex1)*120+16.766]
    set nn2 [expr ($bwpix+$f0pix - $framex1)/($framex2-$framex1)*120+16.766] 
    set f [mtof $nn]
    set bwf [mtof $nn2]
    set bw [expr ($bwf/$f)-1]
    set omega [e_omega $f $::samplerate]
    set alpha [e_alpha $bw $omega]
    set amp [expr pow(10.0, (-1.0*(($filtergain-$framey1)/($framey2-$framey1)*50.0-25.0))/40.0)]
    set alphamulamp [expr $alpha*$amp]
    set alphadivamp [expr $alpha/$amp]
    set b1 [expr -2.0*cos($omega)]
    set b0 [expr 1.0 + $alphamulamp]
    set b2 [expr 1.0 - $alphamulamp]
    set a0 [expr 1.0 + $alphadivamp]
    set a1 $b1
    set a2 [expr 1.0 - $alphadivamp]
    
    set ::filterview::a1 [expr -$a1/$a0]
    set ::filterview::a2 [expr -$a2/$a0]
    set ::filterview::b0 [expr $b0/$a0]
    set ::filterview::b1 [expr $b1/$a0]
    set ::filterview::b2 [expr $b2/$a0]
}

#lowshelf
proc filterview::lowshelf {f0pix bwpix} {
    variable framex1
    variable framey1
    variable framex2
    variable framey2
    variable filtergain

    set nn [expr ($f0pix - $framex1)/($framex2-$framex1)*120+16.766]
    set f [mtof $nn]
    set bw [expr $bwpix / 100.0]
    set amp [expr pow(10.0, (-1.0*(($filtergain-$framey1)/($framey2-$framey1)*50.0-25.0))/40.0)]
    set omega [e_omega $f $::samplerate]
    set alpha [e_alpha $bw $omega]
    
    set alphamod [expr 2.0*sqrt($amp)*$alpha]
    set cosomega [expr cos($omega)]
    set ampplus [expr $amp+1.0]
    set ampmin [expr $amp-1.0]
    
    
    set b0 [expr $amp*($ampplus - $ampmin*$cosomega + $alphamod)]
    set b1 [expr 2.0*$amp*($ampmin - $ampplus*$cosomega)]
    set b2 [expr $amp*($ampplus - $ampmin*$cosomega - $alphamod)]
    set a0 [expr $ampplus + $ampmin*$cosomega + $alphamod]
    set a1 [expr -2.0*($ampmin + $ampplus*$cosomega)]
    set a2 [expr $ampplus + $ampmin*$cosomega - $alphamod]
    
    set ::filterview::a1 [expr -$a1/$a0]
    set ::filterview::a2 [expr -$a2/$a0]
    set ::filterview::b0 [expr $b0/$a0]
    set ::filterview::b1 [expr $b1/$a0]
    set ::filterview::b2 [expr $b2/$a0]
}

#highshelf
proc filterview::highshelf {f0pix bwpix} {
    variable framex1
    variable framey1
    variable framex2
    variable framey2
    variable filtergain

    set nn [expr ($f0pix - $framex1)/($framex2-$framex1)*120+16.766]
    set nn2 [expr ($bwpix+$f0pix - $framex1)/($framex2-$framex1)*120+16.766] 
    set f [mtof $nn]
    set bwf [mtof $nn2]
    set bw [expr ($bwf/$f)-1]
    set amp [expr pow(10.0, (-1.0*(($filtergain-$framey1)/($framey2-$framey1)*50.0-25.0))/40.0)]
    set omega [e_omega $f $::samplerate]
    set alpha [e_alpha $bw $omega]
    
    set alphamod [expr 2.0*sqrt($amp)*$alpha]
    set cosomega [expr cos($omega)]
    set ampplus [expr $amp+1.0]
    set ampmin [expr $amp-1.0]
    
    set b0 [expr $amp*($ampplus + $ampmin*$cosomega + $alphamod)]
    set b1 [expr -2.0*$amp*($ampmin + $ampplus*$cosomega)]
    set b2 [expr $amp*($ampplus + $ampmin*$cosomega - $alphamod)]
    set a0 [expr $ampplus - $ampmin*$cosomega + $alphamod]
    set a1 [expr 2.0*($ampmin - $ampplus*$cosomega)]
    set a2 [expr $ampplus - $ampmin*$cosomega - $alphamod]
    
    set ::filterview::a1 [expr -$a1/$a0]
    set ::filterview::a2 [expr -$a2/$a0]
    set ::filterview::b0 [expr $b0/$a0]
    set ::filterview::b1 [expr $b1/$a0]
    set ::filterview::b2 [expr $b2/$a0]
}

#allpass
proc filterview::allpass {f0pix bwpix} {
    variable framex1
    variable framex2

    set nn [expr ($f0pix - $framex1)/($framex2-$framex1)*120+16.766]
    set nn2 [expr ($bwpix+$f0pix - $framex1)/($framex2-$framex1)*120+16.766] 
    set f [mtof $nn]
    set bwf [mtof $nn2]
    set bw [expr ($bwf/$f)-1]
    set omega [e_omega $f $::samplerate]
    set alpha [e_alpha $bw $omega]
    
    set b0 [expr 1.0 - $alpha]
    set b1 [expr -2.0*cos($omega)]
    set b2 [expr 1.0 + $alpha]
    set a0 $b2
    set a1 $b1
    set a2 $b0
    
    set ::filterview::a1 [expr -$a1/$a0]
    set ::filterview::a2 [expr -$a2/$a0]
    set ::filterview::b0 [expr $b0/$a0]
    set ::filterview::b1 [expr $b1/$a0]
    set ::filterview::b2 [expr $b2/$a0]
}

#------------------------------------------------------------------------------#
# move filter control lines

proc filterview::moveband {tkcanvas x} {
    variable previousx
    variable framex1
    variable framey1
    variable framex2
    variable framey2
    variable filterx1
    variable filterx2
    variable filterwidth
    variable filtercenter

    set dx [expr $x - $previousx]
    set x1 [expr $filterx1 + $dx]
    set x2 [expr $filterx2 + $dx]
    if {$x1 < $framex1} {
        set filterx1 $framex1
        set filterx2 [expr $framex1 + $filterwidth]
    } elseif {$x2 > $framex2} {
        set filterx1 [expr $framex2 - $filterwidth]
        set filterx2 $framex2
    } else {
        set filterx1 $x1
        set filterx2 $x2
    }
    set filterwidth [expr $filterx2 - $filterx1]
    set filtercenter [expr $filterx1 + ($filterwidth/2)]
    $tkcanvas coords filterbandleft $filterx1 $framey1  $filterx1 $framey2
    $tkcanvas coords filterbandcenter $filtercenter $framey1  $filtercenter $framey2
    $tkcanvas coords filterbandright $filterx2 $framey1  $filterx2 $framey2
    set previousx $x
}

proc filterview::movegain {tkcanvas y} {
    variable previousy
    variable framex1
    variable framey1
    variable framex2
    variable framey2
    variable filtergain

    set gainy [expr $filtergain + $y - $previousy]
    if {[expr $gainy < $framey1]} {
        set filtergain $framey1
    } elseif {[expr $gainy > $framey2]} {
        set filtergain $framey2
    } else {
        set filtergain $gainy
    }
    $tkcanvas coords filtergain $framex1 $filtergain $framex2 $filtergain
    set previousy $y
}

#------------------------------------------------------------------------------#
# move the filter

proc filterview::start_move {tkcanvas x y} {
#    puts stderr "start_move $tkcanvas $x $y"
    variable selectedline_color
    variable previousx $x
    variable previousy $y
    variable framey1
    variable framey2
    variable filtercenter

    $tkcanvas configure -cursor fleur
    $tkcanvas itemconfigure filterlines -width 2 -fill $selectedline_color
    $tkcanvas bind filtergraph <Motion> "filterview::move %W %x %y"
    create_centerline $tkcanvas $framey1 $framey2 $filtercenter
}

proc filterview::move {tkcanvas x y} {
    moveband $tkcanvas $x
    movegain $tkcanvas $y
    update_coefficients $tkcanvas
}

#------------------------------------------------------------------------------#
# change the filter

proc filterview::start_changebandwidth {tkcanvas x y} {
#    puts stderr "start_changebandwidth $tkcanvas $x $y"
    variable previousx $x
    variable previousy $y
    variable framey1
    variable framey2
    variable filtercenter
    variable lessthan_filtercenter

    if {$x < $filtercenter} {
        set lessthan_filtercenter 1
    } else {
        set lessthan_filtercenter 0
    }
    $tkcanvas bind bandedges <Leave> {}
    $tkcanvas bind bandedges <Enter> {}
    $tkcanvas bind bandedges <Motion> {}
    $tkcanvas configure -cursor sb_h_double_arrow
    $tkcanvas bind filtergraph <Motion> {filterview::changebandwidth %W %x %y}
    create_centerline $tkcanvas $framey1 $framey2 $filtercenter
}

proc filterview::changebandwidth {tkcanvas x y} {
    variable previousx
    variable framex1
    variable framey1
    variable framex2
    variable framey2
    variable filterx1
    variable filterx2
    variable filterwidth
    variable filtercenter
    variable lessthan_filtercenter

    set dx [expr $x - $previousx]
    if {$lessthan_filtercenter} {
        if {$x < $framex1} {
            set filterx1 $framex1
            set filterx2 [expr $filterx1 + $filterwidth] 
        } elseif {$x < [expr $filtercenter - 75]} {
            set filterx1 [expr $filtercenter - 75]
            set filterx2 [expr $filtercenter + 75]
        } elseif {$x > $filtercenter} {
            set filterx1 $filtercenter
            set filterx2 $filtercenter
        } else {
            set filterx1 $x
            set filterx2 [expr $filterx2 - $dx]
        }
    } else {
        if {$x > $framex2} {
            set filterx2 $framex2
            set filterx1 [expr $filterx2 - $filterwidth] 
        } elseif {$x > [expr $filtercenter + 75]} {
            set filterx1 [expr $filtercenter - 75]
            set filterx2 [expr $filtercenter + 75]
        } elseif {$x < $filtercenter} {
            set filterx1 $filtercenter
            set filterx2 $filtercenter
        } else {
            set filterx2 $x
            set filterx1 [expr $filterx1 - $dx]
        }
    }
    set filterwidth [expr $filterx2 - $filterx1]
    set filtercenter [expr $filterx1 + ($filterwidth/2)]
    $tkcanvas coords filterbandleft $filterx1 $framey1  $filterx1 $framey2
    $tkcanvas coords filterbandcenter $filtercenter $framey1  $filtercenter $framey2
    $tkcanvas coords filterbandright $filterx2 $framey1  $filterx2 $framey2
    set previousx $x

    movegain $tkcanvas $y
    update_coefficients $tkcanvas
}

proc filterview::band_cursor {tkcanvas x} {
    variable filtercenter
    if {$x < $filtercenter} {
        $tkcanvas configure -cursor left_side
    } else {
        $tkcanvas configure -cursor right_side
    }
}

proc filterview::enterband {tkcanvas} {
    variable selectedline_color
    $tkcanvas bind filtergraph <ButtonPress-1> {}
    $tkcanvas bind bandedges <Motion> {filterview::band_cursor %W %x}
    $tkcanvas itemconfigure filterband -width 2 -fill $selectedline_color
}

proc filterview::leaveband {tkcanvas} {
    variable mutedline_color
    $tkcanvas bind filtergraph <ButtonPress-1> {filterview::start_move %W %x %y}
    $tkcanvas bind bandedges <Motion> {}
    $tkcanvas configure -cursor arrow
    $tkcanvas itemconfigure filterband -width 1 -fill $mutedline_color
}

#------------------------------------------------------------------------------#

proc filterview::create_centerline {tkcanvas y1 y2 centery} {
    variable mutedline_color
    # bandwidth box center
    $tkcanvas create line $centery $y1 $centery $y2 \
        -fill $mutedline_color \
        -tags [list filtergraph filterlines filterband filterbandcenter]
}

proc filterview::delete_centerline {tkcanvas} {
    $tkcanvas delete filterbandcenter
}

#------------------------------------------------------------------------------#

proc filterview::stop_editing {tkcanvas} {
    variable mutedline_color
    $tkcanvas bind filtergraph <Motion> {}
    $tkcanvas itemconfigure filterlines -width 1 -fill $mutedline_color
    $tkcanvas configure -cursor arrow
    $tkcanvas bind bandedges <Enter> {filterview::enterband %W}
    $tkcanvas bind bandedges <Leave> {filterview::leaveband %W}
    delete_centerline $tkcanvas
}

proc filterview::set_for_editmode {mytoplevel} {
    if {$::editmode($mytoplevel) == 1} {
    } else {
    }
}

#------------------------------------------------------------------------------#
proc filterview::set_samplerate {sr} {
    set ::samplerate $sr
}

proc filterview::setrect {x1 y1 x2 y2} {
    # convert these all to floats so the math works properly
    variable framex1 [expr $x1 * 1.0]
    variable framey1 [expr $y1 * 1.0]
    variable framex2 [expr $x2 * 1.0]
    variable framey2 [expr $y2 * 1.0]
    
    variable midpoint [expr (($framey2 - $framey1) / 2) + $framey1]
    variable hzperpixel [expr 20000.0 / ($framex2 - $framex1)]
    variable magnatudeperpixel [expr 0.5 / ($framey2 - $framey1)]
    
    # TODO make these set by something else, saved state?
    variable filterx1 120.0
    variable filterx2 180.0

    variable filtergain $midpoint
    variable filterwidth [expr $filterx2 - $filterx1]
    variable filtercenter [expr $filterx1 + ($filterwidth/2)]
}

proc filterview::eraseme {tkcanvas} {
    $tkcanvas delete filtergraph
}

proc filterview::setfilter {tkcanvas filter} {
    variable currentfiltertype $filter
    variable framex1
    variable framex2
    variable filtergain
    variable filters_with_gain
    variable mutedline_color

    if {[lsearch -exact $filters_with_gain $filter] > -1} {
        $tkcanvas create line $framex1 $filtergain $framex2 $filtergain \
            -fill $mutedline_color \
            -tags [list filtergraph filterlines filtergain]
    } else {
        $tkcanvas delete filtergain
    }
    update_coefficients $tkcanvas
}

proc filterview::drawme {tkcanvas name} {
    variable receive_name $name
    variable currentfiltertype
    variable markercolor
    variable mutedline_color
    variable framex1
    variable framey1
    variable framex2
    variable framey2
    variable filterx1
    variable filterx2
    variable midpoint

    # background
    $tkcanvas create rectangle $framex1 $framey1 $framex2 $framey2 \
        -outline $markercolor -fill "#f8feff" \
        -tags [list filtergraph]

    # magnatude response graph fill
    $tkcanvas create polygon $framex1 $midpoint $framex2 $midpoint \
        $framex2 $framey2 $framex1 $framey2 \
        -fill "#e7f6d8" \
        -tags [list filtergraph response responsefill]

    # magnatude response graph line
    $tkcanvas create line $framex1 $midpoint $framex2 $midpoint \
        -fill "#B7C6A8" -width 3 \
        -tags [list filtergraph response responseline]

    # zero line/equator
    $tkcanvas create line $framex1 $midpoint $framex2 $midpoint \
        -fill $markercolor \
        -tags [list filtergraph]

    # phase response graph line
    $tkcanvas create line $framex1 $midpoint $framex2 $midpoint \
        -fill "#ccf" -width 1 \
        -tags [list filtergraph response phaseline]

    # bandwidth box left side
    $tkcanvas create line $filterx1 $framey1 $filterx1 $framey2 \
        -fill $mutedline_color \
        -tags [list filtergraph filterlines filterband filterbandleft bandedges]
    # bandwidth box right side
    $tkcanvas create line $filterx2 $framey1 $filterx2 $framey2 \
        -fill $mutedline_color \
        -tags [list filtergraph filterlines filterband filterbandright bandedges]

    setfilter $tkcanvas $currentfiltertype

    # filtergraph binding is also changed by enter/leave on the band
    $tkcanvas bind filtergraph <ButtonPress-1> {filterview::start_move %W %x %y}
    $tkcanvas bind filtergraph <ButtonRelease-1> {filterview::stop_editing %W}
    $tkcanvas bind bandedges <ButtonPress-1> {filterview::start_changebandwidth %W %x %y}
    $tkcanvas bind bandedges <ButtonRelease-1> {filterview::stop_editing %W}

    # run to set things up
    stop_editing $tkcanvas
}

# sets up an instance of the class
proc filterview::new {} { 
}

# sets up the class
proc filterview::setup {} {
    bind PatchWindow <<EditMode>> {+filterview::set_for_editmode %W}    
    # check if we are Pd < 0.43, which has no 'pdsend', but a 'pd' coded in C
    if {[info procs "pdsend"] ne "pdsend"} {
        proc pdsend {args} {pd "[join $args { }] ;"}
    }

    # if not loading within Pd, then create a window and canvas to work with
    if {[llength [info procs ::pdtk_post]] == 0} {
        catch {console show}
        puts stderr "setting up as standalone dev mode!"
       # this stuff creates a dev skeleton
        proc ::pdtk_post {args} {puts stderr "pdtk_post $args"}
        proc ::pdsend {args} {puts stderr "pdsend $args"}
        filterview::setrect 30.0 30.0 330.0 230.0
        wm geometry . 400x400+500+40
        canvas .c
        pack .c -side left -expand 1 -fill both
        filterview::drawme .c #filterview
    }
}

filterview::setup
