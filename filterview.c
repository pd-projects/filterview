#include <stdio.h>

#include "m_pd.h"
#include "m_imp.h"
#include "g_canvas.h"

typedef struct filterview
{
    t_object x_obj;
    t_canvas*   x_canvas;      /* canvas this widget is currently drawn in */
    t_glist*    x_glist;       /* glist that owns this widget */

    int         width;
    int         height;
    t_symbol*   filtertype;

    /* IDs for Tk widgets */
    t_symbol*   receive_name;  /* name to bind to to receive callbacks */
    char        tkcanvas[MAXPDSTRING];
    char        tag[MAXPDSTRING];
    char        my[MAXPDSTRING];

    t_outlet*   x_data_outlet;
    t_outlet*   x_status_outlet;
} t_filterview;

t_class *filterview_class;
static t_widgetbehavior filterview_widgetbehavior;

/* time to set up! */

static void filterview_biquad_callback(t_filterview *x, t_symbol *s, int argc, t_atom* argv)
{
    outlet_list(x->x_data_outlet, &s_list, argc, argv);
}

/* widgetbehavior */

static void filterview_getrect(t_gobj *z, t_glist *glist,
                               int *xp1, int *yp1, int *xp2, int *yp2)
{
    t_filterview* x = (t_filterview*)z;

    *xp1 = text_xpix(&x->x_obj, glist);
    *yp1 = text_ypix(&x->x_obj, glist);
    *xp2 = text_xpix(&x->x_obj, glist) + x->width;
    *yp2 = text_ypix(&x->x_obj, glist) + x->height;
}

static void filterview_displace(t_gobj *z, t_glist *glist, int dx, int dy)
{
    t_filterview *x = (t_filterview *)z;
    x->x_obj.te_xpix += dx;
    x->x_obj.te_ypix += dy;
    if (glist_isvisible(glist))
    {
        sys_vgui("%s move %s %d %d\n",
                 x->tkcanvas, x->tag, dx, dy);
        sys_vgui("%s move RSZ %d %d\n", x->tkcanvas, dx, dy);
        canvas_fixlinesfor(glist_getcanvas(glist), (t_text*) x);
    }
}

static void filterview_select(t_gobj *z, t_glist *glist, int state)
{
    t_filterview *x = (t_filterview *)z;
    sys_vgui("::filterview::select %s %d\n", x->my, state);
}

void filterview_delete(t_gobj *z, t_glist *glist)
{
    canvas_deletelinesfor(glist, (t_text *)z);
}

static void filterview_vis(t_gobj *z, t_glist *glist, int vis)
{
    t_filterview* x = (t_filterview*)z;
    if (vis)
    {
        x->x_canvas = glist_getcanvas(glist);
        snprintf(x->tkcanvas, MAXPDSTRING, ".x%lx.c", (long unsigned int) x->x_canvas);
        sys_vgui("filterview::drawme %s %s %s %s %d %d %d %d %s\n",
                 x->my, x->tkcanvas, x->receive_name->s_name, x->tag,
                 text_xpix(&x->x_obj, glist),
                 text_ypix(&x->x_obj, glist),
                 text_xpix(&x->x_obj, glist)+x->width,
                 text_ypix(&x->x_obj, glist)+x->height,
                 x->filtertype->s_name);
    }
    else
    {
        sys_vgui("filterview::eraseme %s\n", x->my);
    }
    /* send the current samplerate to the GUI for calculation of biquad coeffs*/
    t_float samplerate = sys_getsr();
    if (samplerate > 0)  /* samplerate is sometimes 0, ignore that */
        sys_vgui("set ::samplerate %.0f\n", samplerate);
    /* TODO ideally, this would take into account [block~] settings or
     * the Tk code would not need the samplerate */
}

/* handle lists of biquad coeffecients -------------------------------------- */

static void filterview_list(t_filterview *x, t_symbol *s, int argc, t_atom *argv)
{
    if (argc < 5)
        pd_error(x, "[filterview] needs 5 float coefficients, ignoring list");
    else
    {
        t_float a1 = atom_getfloat(argv);
        t_float a2 = atom_getfloat(argv + 1);
        t_float b0 = atom_getfloat(argv + 2);
        t_float b1 = atom_getfloat(argv + 3);
        t_float b2 = atom_getfloat(argv + 4);
        sys_vgui("::filterview::coefficients %s %g %g %g %g %g\n",
                 x->my, a1, a2, b0, b1, b2);
        filterview_biquad_callback(x, s, argc, argv);
    }
}

/* set filter type ---------------------------------------------------------- */

static void setfiltertype(t_filterview *x, char* filtertype)
{
    x->filtertype = gensym(filtertype);
    sys_vgui("::filterview::setfiltertype %s %s\n",
             x->my, x->filtertype->s_name);
}

static void filterview_symbol(t_filterview *x, t_symbol *s)
{
    setfiltertype(x, s->s_name);
}

static void filterview_allpass(t_filterview *x)
{
    setfiltertype(x, "allpass");
}

static void filterview_bandpass(t_filterview *x)
{
    setfiltertype(x, "bandpass");
}

static void filterview_highpass(t_filterview *x)
{
    setfiltertype(x, "highpass");
}

static void filterview_highshelf(t_filterview *x)
{
    setfiltertype(x, "highshelf");
}

static void filterview_lowpass(t_filterview *x)
{
    setfiltertype(x, "lowpass");
}

static void filterview_lowshelf(t_filterview *x)
{
    setfiltertype(x, "lowshelf");
}

static void filterview_notch(t_filterview *x)
{
    setfiltertype(x, "notch");
}

static void filterview_peaking(t_filterview *x)
{
    setfiltertype(x, "peaking");
}

static void filterview_resonant(t_filterview *x)
{
    setfiltertype(x, "resonant");
}

/* object and class creation/destruction ----------------------------------- */
static void *filterview_new(t_symbol* s)
{
    t_filterview *x = (t_filterview *)pd_new(filterview_class);
    char buf[MAXPDSTRING];

    x->width = 300;
    x->height = 200;
    x->filtertype = gensym("peaking");
    x->x_glist = canvas_getcurrent();

    snprintf(x->tag, MAXPDSTRING, "T%lx", (long unsigned int)x);
    snprintf(x->my, MAXPDSTRING, "::N%lx", (long unsigned int)x);

    sprintf(buf, "#R%lx", (long unsigned int)x);
    x->receive_name = gensym(buf);
    pd_bind(&x->x_obj.ob_pd, x->receive_name);

    x->x_data_outlet = outlet_new(&x->x_obj, &s_list);
    x->x_status_outlet = outlet_new(&x->x_obj, &s_anything);

    return (void *)x;
}

static void filterview_free(t_filterview *x)
{
    pd_unbind(&x->x_obj.ob_pd, x->receive_name);
}

void filterview_setup(void)
{
    filterview_class = class_new(gensym("filterview"),
                                 (t_newmethod)filterview_new,
                                 (t_method)filterview_free,
                                 sizeof(t_filterview),
                                 0,
                                 A_DEFSYMBOL,
                                 0);

    class_addmethod(filterview_class, (t_method)filterview_allpass, gensym("allpass"), 0);
    class_addmethod(filterview_class, (t_method)filterview_bandpass, gensym("bandpass"), 0);
    class_addmethod(filterview_class, (t_method)filterview_highpass, gensym("highpass"), 0);
    class_addmethod(filterview_class, (t_method)filterview_highshelf, gensym("highshelf"), 0);
    class_addmethod(filterview_class, (t_method)filterview_lowpass, gensym("lowpass"), 0);
    class_addmethod(filterview_class, (t_method)filterview_lowshelf, gensym("lowshelf"), 0);
    class_addmethod(filterview_class, (t_method)filterview_notch, gensym("notch"), 0);
    class_addmethod(filterview_class, (t_method)filterview_peaking, gensym("peaking"), 0);
    class_addmethod(filterview_class, (t_method)filterview_resonant, gensym("resonant"), 0);
    class_addmethod(filterview_class, (t_method)filterview_biquad_callback,
                    gensym("biquad"), A_GIMME, 0);
    class_addsymbol(filterview_class, (t_method)filterview_symbol);
    class_addlist(filterview_class, (t_method)filterview_list);

    /* widget behavior */
    filterview_widgetbehavior.w_getrectfn  = filterview_getrect;
    filterview_widgetbehavior.w_displacefn = filterview_displace;
    filterview_widgetbehavior.w_selectfn   = filterview_select;
    filterview_widgetbehavior.w_activatefn = NULL;
    filterview_widgetbehavior.w_deletefn   = filterview_delete;
    filterview_widgetbehavior.w_visfn      = filterview_vis;
    filterview_widgetbehavior.w_clickfn    = NULL;
    class_setwidget(filterview_class, &filterview_widgetbehavior);
//    class_setsavefn(filterview_class, &filterview_save);
    sys_vgui("eval [read [open {%s/filterview.tcl}]]\n",
             filterview_class->c_externdir->s_name);
}

