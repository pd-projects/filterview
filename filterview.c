#include <stdio.h>

#include "m_pd.h"
#include "g_canvas.h"

typedef struct filterview
{
    t_object x_ob;
    t_canvas*   x_canvas;      /* canvas this widget is currently drawn in */
    t_glist*    x_glist;       /* glist that owns this widget */

	char   canvas_id[MAXPDSTRING];  
	char   widget_id[MAXPDSTRING];        

    int         width;
    int         height;
} t_filterview;

t_class *filterview_class;
static t_widgetbehavior filterview_widgetbehavior;

static void set_tkwidgets_ids(t_filterview* x, t_canvas* canvas)
{
    x->x_canvas = canvas;
    sprintf(x->canvas_id,".x%lx.c", (long unsigned int) canvas);
    sprintf(x->widget_id,"%s.widget%lx", x->canvas_id, (long unsigned int)x);
}

static void drawme(t_filterview *x, t_glist *glist)
{
    set_tkwidgets_ids(x,glist_getcanvas(glist));
    post("drawme");
    sys_vgui("filterview_new .x%lx.c\n", x->canvas_id);
}

static void eraseme(t_filterview *x)
{
    post("eraseme");
}

static void filterview_vis(t_gobj *z, t_glist *glist, int vis)
{
    t_filterview* s = (t_filterview*)z;
    if (vis)
        drawme(s, glist);
    else
        eraseme(s);
}

void *filterview_new(void)
{
    t_filterview *x = (t_filterview *)pd_new(filterview_class);

    post("filterview_new");

    return (void *)x;
}

void filterview_setup(void)
{
    post("filterview_setup");
    filterview_class = class_new(gensym("filterview"), 
                                 (t_newmethod)filterview_new, 
                                 0,
                                 sizeof(t_filterview), 
                                 0, 0);
    sys_gui("eval [read [open /Users/hans/code/pd-projects/filterview/filterview.tcl]]\n");
    post("end filterview_setup");

/* widget behavior */
    filterview_widgetbehavior.w_getrectfn  = NULL;
    filterview_widgetbehavior.w_displacefn = NULL;
    filterview_widgetbehavior.w_selectfn   = NULL;
    filterview_widgetbehavior.w_activatefn = NULL;
    filterview_widgetbehavior.w_deletefn   = NULL;
    filterview_widgetbehavior.w_visfn      = filterview_vis;
    filterview_widgetbehavior.w_clickfn    = NULL;
    class_setwidget(filterview_class, &filterview_widgetbehavior);
//    class_setsavefn(filterview_class, &filterview_save);
}

