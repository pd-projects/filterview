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
	char        canvas_id[MAXPDSTRING];
    char        widget_id[MAXPDSTRING];
    
    t_outlet*   x_data_outlet;
    t_outlet*   x_status_outlet;
} t_filterview;

t_class *filterview_class;
static t_widgetbehavior filterview_widgetbehavior;

static void set_tkwidgets_ids(t_filterview* x, t_canvas* canvas)
{
    x->x_canvas = canvas;
    sprintf(x->canvas_id,".x%lx.c", (long unsigned int) canvas);
    sprintf(x->widget_id,"%s.widget%lx", x->canvas_id, (long unsigned int)x);
}


static void filterview_biquad_callback(t_filterview *x, t_symbol *s, 
                                       int argc, t_atom* argv)
{
    outlet_list(x->x_data_outlet, s, argc, argv);
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
/*        sys_vgui("%s move %s %d %d\n", 
                 x->canvas_id->s_name, x->all_tag->s_name, dx, dy);
        sys_vgui("%s move RSZ %d %d\n", x->canvas_id->s_name, dx, dy);*/
        canvas_fixlinesfor(glist_getcanvas(glist), (t_text*) x);
    }
}

static void filterview_vis(t_gobj *z, t_glist *glist, int vis)
{
    t_filterview* x = (t_filterview*)z;
    if (vis)
    {
        set_tkwidgets_ids(x, glist);
        post("drawme");
        if (x->filtertype != &s_)
            sys_vgui("filterview_setfilter %s %s\n", 
                     x->canvas_id, x->filtertype->s_name);
        sys_vgui("filterview_setrect %d %d %d %d\n",
                 text_xpix(&x->x_obj, glist), 
                 text_ypix(&x->x_obj, glist),
                 text_xpix(&x->x_obj, glist)+x->width, 
                 text_ypix(&x->x_obj, glist)+x->height);
        sys_vgui("filterview_drawme %s %s\n", x->canvas_id, 
                 x->receive_name->s_name);
    }
    else 
    {
        post("eraseme");
        sys_vgui("filterview_eraseme %s\n", x->canvas_id);
    }
}

/* set filter type ---------------------------------------------------------- */

static void filterview_allpass(t_filterview *x)
{
    x->filtertype = gensym("allpass");
    sys_vgui("filterview_setfilter %s allpass\n", x->canvas_id);
}

static void filterview_bandpass(t_filterview *x)
{
    x->filtertype = gensym("bandpass");
    sys_vgui("filterview_setfilter %s bandpass\n", x->canvas_id);
}

static void filterview_highpass(t_filterview *x)
{
    x->filtertype = gensym("highpass");
    sys_vgui("filterview_setfilter %s highpass\n", x->canvas_id);
}

static void filterview_highshelf(t_filterview *x)
{
    x->filtertype = gensym("highshelf");
    sys_vgui("filterview_setfilter %s highshelf\n", x->canvas_id);
}

static void filterview_lowpass(t_filterview *x)
{
    x->filtertype = gensym("lowpass");
    sys_vgui("filterview_setfilter %s lowpass\n", x->canvas_id);
}

static void filterview_lowshelf(t_filterview *x)
{
    x->filtertype = gensym("lowshelf");
    sys_vgui("filterview_setfilter %s lowshelf\n", x->canvas_id);
}

static void filterview_notch(t_filterview *x)
{
    x->filtertype = gensym("notch");
    sys_vgui("filterview_setfilter %s notch\n", x->canvas_id);
}

static void filterview_peaking(t_filterview *x)
{
    x->filtertype = gensym("peaking");
    sys_vgui("filterview_setfilter %s peaking\n", x->canvas_id);
}

static void filterview_resonant(t_filterview *x)
{
    x->filtertype = gensym("resonant");
    sys_vgui("filterview_setfilter %s resonant\n", x->canvas_id);
}

/* object and class creation/destruction ----------------------------------- */
static void *filterview_new(t_symbol* s)
{
    t_filterview *x = (t_filterview *)pd_new(filterview_class);
    char buf[MAXPDSTRING];

    post("filterview_new");
    x->width = 300;
    x->height = 200;
    x->filtertype = s;
    x->x_glist = canvas_getcurrent();

//    sprintf(x->receive_name, "#%lx", x);
    sprintf(buf, "#filterview");
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
    post("filterview_setup");
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
                    gensym("biquad"), A_FLOAT, A_FLOAT, A_FLOAT, A_FLOAT, A_FLOAT, 0);

/* widget behavior */
    filterview_widgetbehavior.w_getrectfn  = filterview_getrect;
    filterview_widgetbehavior.w_displacefn = filterview_displace;
    filterview_widgetbehavior.w_selectfn   = NULL;
    filterview_widgetbehavior.w_activatefn = NULL;
    filterview_widgetbehavior.w_deletefn   = NULL;
    filterview_widgetbehavior.w_visfn      = filterview_vis;
    filterview_widgetbehavior.w_clickfn    = NULL;
    class_setwidget(filterview_class, &filterview_widgetbehavior);
//    class_setsavefn(filterview_class, &filterview_save);
    sys_vgui("eval [read [open %s/filterview.tcl]]\n",
        filterview_class->c_externdir->s_name);
    post("end filterview_setup");
}

