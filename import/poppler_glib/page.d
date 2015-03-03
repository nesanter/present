module poppler_glib.page;

import gtkc.gobjecttypes;
import gtkc.gobject;
import gtkc.cairotypes;
import gtkc.cairo;

import poppler_glib.poppler;

extern (C) {
    GType      	       poppler_page_get_type             () ;

    void                   poppler_page_render               (PopplerPage        *page,
            cairo_t            *cairo);
    void                   poppler_page_render_for_printing  (PopplerPage        *page,
            cairo_t            *cairo);
    void       poppler_page_render_for_printing_with_options (PopplerPage        *page,
            cairo_t            *cairo,
            PopplerPrintFlags   options);
    cairo_surface_t       *poppler_page_get_thumbnail        (PopplerPage        *page);
    void                   poppler_page_render_selection     (PopplerPage        *page,
            cairo_t            *cairo,
            PopplerRectangle   *selection,
            PopplerRectangle   *old_selection,
            PopplerSelectionStyle style,
            PopplerColor       *glyph_color,
            PopplerColor       *background_color);

    void                   poppler_page_get_size             (PopplerPage        *page,
            double             *width,
            double             *height);
    int                    poppler_page_get_index            (PopplerPage        *page);
    gchar                 *poppler_page_get_label            (PopplerPage        *page);
    double                 poppler_page_get_duration         (PopplerPage        *page);
    PopplerPageTransition *poppler_page_get_transition       (PopplerPage        *page);
    gboolean               poppler_page_get_thumbnail_size   (PopplerPage        *page,
            int                *width,
            int                *height);
    GList             *poppler_page_find_text_with_options   (PopplerPage        *page,
            const  char        *text,
            PopplerFindFlags    options);
    GList     	      *poppler_page_find_text            (PopplerPage        *page,
            const  char        *text);
    void                   poppler_page_render_to_ps         (PopplerPage        *page,
            PopplerPSFile      *ps_file);
    char                  *poppler_page_get_text             (PopplerPage        *page);
    char                  *poppler_page_get_text_for_area    (PopplerPage        *page,
            PopplerRectangle   *area);
    char                  *poppler_page_get_selected_text    (PopplerPage        *page,
            PopplerSelectionStyle style,
            PopplerRectangle   *selection);
    cairo_region_t        *poppler_page_get_selected_region  (PopplerPage        *page,
            gdouble             scale,
            PopplerSelectionStyle  style,
            PopplerRectangle   *selection);
    GList                 *poppler_page_get_selection_region (PopplerPage        *page,
            gdouble             scale,
            PopplerSelectionStyle style,
            PopplerRectangle   *selection);
    void                   poppler_page_selection_region_free(GList              *region);
    GList                 *poppler_page_get_link_mapping     (PopplerPage        *page);
    void                   poppler_page_free_link_mapping    (GList              *list);
    GList                 *poppler_page_get_image_mapping    (PopplerPage        *page);
    void                   poppler_page_free_image_mapping   (GList              *list);
    cairo_surface_t       *poppler_page_get_image            (PopplerPage        *page,
            gint                image_id);
    GList              *poppler_page_get_form_field_mapping  (PopplerPage        *page);
    void                poppler_page_free_form_field_mapping (GList              *list);
    GList                 *poppler_page_get_annot_mapping    (PopplerPage        *page);
    void                   poppler_page_free_annot_mapping   (GList              *list);
    void                   poppler_page_add_annot            (PopplerPage        *page,
            PopplerAnnot       *annot);
    void                   poppler_page_remove_annot         (PopplerPage        *page,
            PopplerAnnot       *annot);
    void 		      poppler_page_get_crop_box 	 (PopplerPage        *page,
            PopplerRectangle   *rect);
    gboolean               poppler_page_get_text_layout      (PopplerPage        *page,
            PopplerRectangle  **rectangles,
            guint              *n_rectangles);
    gboolean           poppler_page_get_text_layout_for_area (PopplerPage        *page,
            PopplerRectangle   *area,
            PopplerRectangle  **rectangles,
            guint              *n_rectangles);
    GList                 *poppler_page_get_text_attributes  (PopplerPage        *page);
    void                   poppler_page_free_text_attributes (GList              *list);
    GList *        poppler_page_get_text_attributes_for_area (PopplerPage        *page,
            PopplerRectangle   *area);

    /* A rectangle on a page, with coordinates in PDF points. */
    /**
     * PopplerRectangle:
     * @x1: x coordinate of lower left corner
     * @y1: y coordinate of lower left corner
     * @x2: x coordinate of upper right corner
     * @y2: y coordinate of upper right corner
     *
     * A #PopplerRectangle is used to describe
     * locations on a page and bounding boxes
     */
    struct PopplerRectangle
    {
        gdouble x1;
        gdouble y1;
        gdouble x2;
        gdouble y2;
    }

    GType             poppler_rectangle_get_type () ;
    PopplerRectangle *poppler_rectangle_new      ();
    PopplerRectangle *poppler_rectangle_copy     (PopplerRectangle *rectangle);
    void              poppler_rectangle_free     (PopplerRectangle *rectangle);

    /* A point on a page, with coordinates in PDF points. */
    /**
     * PopplerPoint:
     * @x: x coordinate
     * @y: y coordinate
     *
     * A #PopplerPoint is used to describe a location point on a page
     */
    struct PopplerPoint
    {
        gdouble x;
        gdouble y;
    }

    GType             poppler_point_get_type () ;
    PopplerPoint     *poppler_point_new      ();
    PopplerPoint     *poppler_point_copy     (PopplerPoint *point);
    void              poppler_point_free     (PopplerPoint *point);

    /* PopplerQuadrilateral */

    /* A quadrilateral encompasses a word or group of contiguous words in the
     * text underlying the annotation. The coordinates for each quadrilateral are
     * given in the order x1 y1 x2 y2 x3 y3 x4 y4 specifying the quadrilateral’s four
     *  vertices in counterclockwise order */

    /**
     *  PopplerQuadrilateral:
     *  @p1: a #PopplerPoint with the first vertex coordinates
     *  @p2: a #PopplerPoint with the second vertex coordinates
     *  @p3: a #PopplerPoint with the third vertex coordinates
     *  @p4: a #PopplerPoint with the fourth vertex coordinates
     *
     *  A #PopplerQuadrilateral is used to describe rectangle-like polygon
     *  with arbitrary inclination on a page.
     *
     *  Since: 0.26
     **/
    struct PopplerQuadrilateral
    {
        PopplerPoint p1;
        PopplerPoint p2;
        PopplerPoint p3;
        PopplerPoint p4;
    }

    GType                 poppler_quadrilateral_get_type () ;
    PopplerQuadrilateral *poppler_quadrilateral_new      ();
    PopplerQuadrilateral *poppler_quadrilateral_copy     (PopplerQuadrilateral *quad);
    void                 poppler_quadrilateral_free     (PopplerQuadrilateral *quad);

    /* A color in RGB */

    /**
     * PopplerColor:
     * @red: the red componment of color
     * @green: the green component of color
     * @blue: the blue component of color
     *
     * A #PopplerColor describes a RGB color. Color components
     * are values between 0 and 65535
     */
    struct PopplerColor
    {
        guint16 red;
        guint16 green;
        guint16 blue;
    }

    GType             poppler_color_get_type      () ;
    PopplerColor     *poppler_color_new           ();
    PopplerColor     *poppler_color_copy          (PopplerColor *color);
    void              poppler_color_free          (PopplerColor *color);

    /* Text attributes. */
    /**
     * PopplerTextAttributes:
     * @font_name: font name
     * @font_size: font size
     * @is_underlined: if text is underlined
     * @color: a #PopplerColor, the foreground color
     * @start_index: start position this text attributes apply
     * @end_index: end position this text text attributes apply
     *
     * A #PopplerTextAttributes is used to describe text attributes of a range of text
     *
     * Since: 0.18
     */
    struct PopplerTextAttributes
    {
        gchar *font_name;
        gdouble font_size;
        gboolean is_underlined;
        PopplerColor color;

        gint start_index;
        gint end_index;
    }

    GType                  poppler_text_attributes_get_type () ;
    PopplerTextAttributes *poppler_text_attributes_new      ();
    PopplerTextAttributes *poppler_text_attributes_copy     (PopplerTextAttributes *text_attrs);
    void                   poppler_text_attributes_free     (PopplerTextAttributes *text_attrs);

    /* Mapping between areas on the current page and PopplerActions */

    /**
     * PopplerLinkMapping:
     * @area: a #PopplerRectangle representing an area of the page
     * @action: a #PopplerAction
     *
     * A #PopplerLinkMapping structure represents the location
     * of @action on the page
     */
    struct  PopplerLinkMapping
    {
        PopplerRectangle area;
        PopplerAction *action;
    }

    GType               poppler_link_mapping_get_type () ;
    PopplerLinkMapping *poppler_link_mapping_new      ();
    PopplerLinkMapping *poppler_link_mapping_copy     (PopplerLinkMapping *mapping);
    void                poppler_link_mapping_free     (PopplerLinkMapping *mapping);

    /* Page Transition */

    /**
     * PopplerPageTransition:
     * @type: the type of transtition
     * @alignment: the dimension in which the transition effect shall occur.
     * Only for #POPPLER_PAGE_TRANSITION_SPLIT and #POPPLER_PAGE_TRANSITION_BLINDS transition types
     * @direction: the direccion of motion for the transition effect.
     * Only for #POPPLER_PAGE_TRANSITION_SPLIT, #POPPLER_PAGE_TRANSITION_BOX and #POPPLER_PAGE_TRANSITION_FLY
     * transition types
     * @duration: the duration of the transition effect
     * @angle: the direction in which the specified transition effect shall moves,
     * expressed in degrees counterclockwise starting from a left-to-right direction.
     * Only for #POPPLER_PAGE_TRANSITION_WIPE, #POPPLER_PAGE_TRANSITION_GLITTER, #POPPLER_PAGE_TRANSITION_FLY,
     * #POPPLER_PAGE_TRANSITION_COVER, #POPPLER_PAGE_TRANSITION_UNCOVER and #POPPLER_PAGE_TRANSITION_PUSH
     * transition types
     * @scale: the starting or ending scale at which the changes shall be drawn.
     * Only for #POPPLER_PAGE_TRANSITION_FLY transition type
     * @rectangular: whether the area that will be flown is rectangular and opaque.
     * Only for #POPPLER_PAGE_TRANSITION_FLY transition type
     *
     * A #PopplerPageTransition structures describes a visual transition
     * to use when moving between pages during a presentation
     */
    struct PopplerPageTransition
    {
        PopplerPageTransitionType type;
        PopplerPageTransitionAlignment alignment;
        PopplerPageTransitionDirection direction;
        gint duration;
        gint angle;
        gdouble scale;
        gboolean rectangular;
    }

    GType                  poppler_page_transition_get_type () ;
    PopplerPageTransition *poppler_page_transition_new      ();
    PopplerPageTransition *poppler_page_transition_copy     (PopplerPageTransition *transition);
    void                   poppler_page_transition_free     (PopplerPageTransition *transition);

    /* Mapping between areas on the current page and images */

    /**
     * PopplerImageMapping:
     * @area: a #PopplerRectangle representing an area of the page
     * @image_id: an image identifier
     *
     * A #PopplerImageMapping structure represents the location
     * of an image on the page
     */
    struct  PopplerImageMapping
    {
        PopplerRectangle area;
        gint image_id;	
    }

    GType                  poppler_image_mapping_get_type () ;
    PopplerImageMapping   *poppler_image_mapping_new      ();
    PopplerImageMapping   *poppler_image_mapping_copy     (PopplerImageMapping *mapping);
    void                   poppler_image_mapping_free     (PopplerImageMapping *mapping);

    /* Mapping between areas on the current page and form fields */

    /**
     * PopplerFormFieldMapping:
     * @area: a #PopplerRectangle representing an area of the page
     * @field: a #PopplerFormField
     *
     * A #PopplerFormFieldMapping structure represents the location
     * of @field on the page
     */
    struct PopplerFormFieldMapping
    {
        PopplerRectangle area;
        PopplerFormField *field;
    }

    GType                    poppler_form_field_mapping_get_type () ;
    PopplerFormFieldMapping *poppler_form_field_mapping_new      ();
    PopplerFormFieldMapping *poppler_form_field_mapping_copy     (PopplerFormFieldMapping *mapping);
    void                     poppler_form_field_mapping_free     (PopplerFormFieldMapping *mapping);

    /* Mapping between areas on the current page and annots */

    /**
     * PopplerAnnotMapping:
     * @area: a #PopplerRectangle representing an area of the page
     * @annot: a #PopplerAnnot
     *
     * A #PopplerAnnotMapping structure represents the location
     * of @annot on the page
     */
    struct PopplerAnnotMapping
    {
        PopplerRectangle area;
        PopplerAnnot *annot;
    }

    GType                poppler_annot_mapping_get_type () ;
    PopplerAnnotMapping *poppler_annot_mapping_new      ();
    PopplerAnnotMapping *poppler_annot_mapping_copy     (PopplerAnnotMapping *mapping);
    void                 poppler_annot_mapping_free     (PopplerAnnotMapping *mapping);

}
