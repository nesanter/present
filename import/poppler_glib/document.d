module poppler_glib.document;

import gtkc.gobjecttypes;
import gtkc.gobject;
import gtkc.giotypes;
import gtkc.gio;
import poppler_glib.poppler;

enum PopplerPageLayout
{
  POPPLER_PAGE_LAYOUT_UNSET,
  POPPLER_PAGE_LAYOUT_SINGLE_PAGE,
  POPPLER_PAGE_LAYOUT_ONE_COLUMN,
  POPPLER_PAGE_LAYOUT_TWO_COLUMN_LEFT,
  POPPLER_PAGE_LAYOUT_TWO_COLUMN_RIGHT,
  POPPLER_PAGE_LAYOUT_TWO_PAGE_LEFT,
  POPPLER_PAGE_LAYOUT_TWO_PAGE_RIGHT
} 

enum PopplerPageMode
{
  POPPLER_PAGE_MODE_UNSET,
  POPPLER_PAGE_MODE_NONE,
  POPPLER_PAGE_MODE_USE_OUTLINES,
  POPPLER_PAGE_MODE_USE_THUMBS,
  POPPLER_PAGE_MODE_FULL_SCREEN,
  POPPLER_PAGE_MODE_USE_OC,
  POPPLER_PAGE_MODE_USE_ATTACHMENTS
} 

enum PopplerFontType
{
  POPPLER_FONT_TYPE_UNKNOWN,
  POPPLER_FONT_TYPE_TYPE1,
  POPPLER_FONT_TYPE_TYPE1C,
  POPPLER_FONT_TYPE_TYPE1COT,
  POPPLER_FONT_TYPE_TYPE3,
  POPPLER_FONT_TYPE_TRUETYPE,
  POPPLER_FONT_TYPE_TRUETYPEOT,
  POPPLER_FONT_TYPE_CID_TYPE0,
  POPPLER_FONT_TYPE_CID_TYPE0C,
  POPPLER_FONT_TYPE_CID_TYPE0COT,
  POPPLER_FONT_TYPE_CID_TYPE2,
  POPPLER_FONT_TYPE_CID_TYPE2OT
}

enum PopplerViewPreferences /*< flags >*/
{
  POPPLER_VIEWER_PREFERENCES_UNSET = 0,
  POPPLER_VIEWER_PREFERENCES_HIDE_TOOLBAR = 1 << 0,
  POPPLER_VIEWER_PREFERENCES_HIDE_MENUBAR = 1 << 1,
  POPPLER_VIEWER_PREFERENCES_HIDE_WINDOWUI = 1 << 2,
  POPPLER_VIEWER_PREFERENCES_FIT_WINDOW = 1 << 3,
  POPPLER_VIEWER_PREFERENCES_CENTER_WINDOW = 1 << 4,
  POPPLER_VIEWER_PREFERENCES_DISPLAY_DOC_TITLE = 1 << 5,
  POPPLER_VIEWER_PREFERENCES_DIRECTION_RTL = 1 << 6
}

enum PopplerPermissions /*< flags >*/
{
  POPPLER_PERMISSIONS_OK_TO_PRINT = 1 << 0,
  POPPLER_PERMISSIONS_OK_TO_MODIFY = 1 << 1,
  POPPLER_PERMISSIONS_OK_TO_COPY = 1 << 2,
  POPPLER_PERMISSIONS_OK_TO_ADD_NOTES = 1 << 3,
  POPPLER_PERMISSIONS_OK_TO_FILL_FORM = 1 << 4,
  POPPLER_PERMISSIONS_OK_TO_EXTRACT_CONTENTS = 1 << 5,
  POPPLER_PERMISSIONS_OK_TO_ASSEMBLE = 1 << 6,
  POPPLER_PERMISSIONS_OK_TO_PRINT_HIGH_RESOLUTION = 1 << 7,
  POPPLER_PERMISSIONS_FULL = (POPPLER_PERMISSIONS_OK_TO_PRINT | POPPLER_PERMISSIONS_OK_TO_MODIFY | POPPLER_PERMISSIONS_OK_TO_COPY | POPPLER_PERMISSIONS_OK_TO_ADD_NOTES | POPPLER_PERMISSIONS_OK_TO_FILL_FORM | POPPLER_PERMISSIONS_OK_TO_EXTRACT_CONTENTS | POPPLER_PERMISSIONS_OK_TO_ASSEMBLE | POPPLER_PERMISSIONS_OK_TO_PRINT_HIGH_RESOLUTION)

}

extern (C) {
    GType              poppler_document_get_type               ();
    PopplerDocument   *poppler_document_new_from_file          (const char      *uri,
            const char      *password,
            GError         **error);
    PopplerDocument   *poppler_document_new_from_data          (char            *data,
            int              length,
            const char      *password,
            GError         **error);
    PopplerDocument   *poppler_document_new_from_stream        (GInputStream    *stream,
            goffset          length,
            const char      *password,
            GCancellable    *cancellable,
            GError         **error);
    PopplerDocument   *poppler_document_new_from_gfile         (GFile           *file,
            const char      *password,
            GCancellable    *cancellable,
            GError         **error);
    gboolean           poppler_document_save                   (PopplerDocument *document,
            const char      *uri,
            GError         **error);
    gboolean           poppler_document_save_a_copy            (PopplerDocument *document,
            const char      *uri,
            GError         **error);
    gboolean           poppler_document_get_id                 (PopplerDocument *document,
            gchar          **permanent_id,
            gchar          **update_id);
    int                poppler_document_get_n_pages            (PopplerDocument *document);
    PopplerPage       *poppler_document_get_page               (PopplerDocument *document,
            int              index);
    PopplerPage       *poppler_document_get_page_by_label      (PopplerDocument *document,
            const char      *label);
    gchar             *poppler_document_get_pdf_version_string (PopplerDocument *document);
    void               poppler_document_get_pdf_version        (PopplerDocument *document,
            guint           *major_version,
            guint           *minor_version);
    gchar             *poppler_document_get_title              (PopplerDocument *document);
    gchar             *poppler_document_get_author             (PopplerDocument *document);
    gchar             *poppler_document_get_subject            (PopplerDocument *document);
    gchar             *poppler_document_get_keywords           (PopplerDocument *document);
    gchar             *poppler_document_get_creator            (PopplerDocument *document);
    gchar             *poppler_document_get_producer           (PopplerDocument *document);
    time_t             poppler_document_get_creation_date      (PopplerDocument *document);
    time_t             poppler_document_get_modification_date  (PopplerDocument *document);
    gboolean           poppler_document_is_linearized          (PopplerDocument *document);
    PopplerPageLayout  poppler_document_get_page_layout        (PopplerDocument *document);
    PopplerPageMode    poppler_document_get_page_mode          (PopplerDocument *document);
    PopplerPermissions poppler_document_get_permissions        (PopplerDocument *document);
    gchar             *poppler_document_get_metadata           (PopplerDocument *document);

    /* Attachments */
    guint              poppler_document_get_n_attachments      (PopplerDocument  *document);
    gboolean           poppler_document_has_attachments        (PopplerDocument  *document);
    GList             *poppler_document_get_attachments        (PopplerDocument  *document);

    /* Links */
    PopplerDest       *poppler_document_find_dest              (PopplerDocument  *document,
            const gchar      *link_name);

    /* Form */
    PopplerFormField  *poppler_document_get_form_field         (PopplerDocument  *document,
            gint              id);

    /* Interface for getting the Index of a poppler_document */
    GType             poppler_index_iter_get_type   ();
    PopplerIndexIter *poppler_index_iter_new        (PopplerDocument   *document);
    PopplerIndexIter *poppler_index_iter_copy       (PopplerIndexIter  *iter);
    void              poppler_index_iter_free       (PopplerIndexIter  *iter);

    PopplerIndexIter *poppler_index_iter_get_child  (PopplerIndexIter  *parent);
    gboolean	  poppler_index_iter_is_open    (PopplerIndexIter  *iter);
    PopplerAction    *poppler_index_iter_get_action (PopplerIndexIter  *iter);
    gboolean          poppler_index_iter_next       (PopplerIndexIter  *iter);

    /* Interface for getting the Fonts of a poppler_document */
    GType             poppler_font_info_get_type       ();
    PopplerFontInfo  *poppler_font_info_new            (PopplerDocument   *document);
    gboolean          poppler_font_info_scan           (PopplerFontInfo   *font_info,
            int                n_pages,
            PopplerFontsIter **iter);
    void             poppler_font_info_free            (PopplerFontInfo   *font_info);

    GType             poppler_fonts_iter_get_type      ();
    PopplerFontsIter *poppler_fonts_iter_copy          (PopplerFontsIter  *iter);
    void              poppler_fonts_iter_free          (PopplerFontsIter  *iter);
    const(char*)       poppler_fonts_iter_get_name      (PopplerFontsIter  *iter);
    const(char*)       poppler_fonts_iter_get_full_name (PopplerFontsIter  *iter);
    const(char*)       poppler_fonts_iter_get_substitute_name (PopplerFontsIter *iter);
    const(char*)       poppler_fonts_iter_get_file_name (PopplerFontsIter  *iter);
    PopplerFontType   poppler_fonts_iter_get_font_type (PopplerFontsIter  *iter);
    const(char*)       poppler_fonts_iter_get_encoding  (PopplerFontsIter *iter);
    gboolean	  poppler_fonts_iter_is_embedded   (PopplerFontsIter  *iter);
    gboolean	  poppler_fonts_iter_is_subset     (PopplerFontsIter  *iter);
    gboolean          poppler_fonts_iter_next          (PopplerFontsIter  *iter);

    /* Interface for getting the Layers of a poppler_document */
    GType              poppler_layers_iter_get_type    ();
    PopplerLayersIter *poppler_layers_iter_new         (PopplerDocument   *document);
    PopplerLayersIter *poppler_layers_iter_copy        (PopplerLayersIter *iter);
    void               poppler_layers_iter_free        (PopplerLayersIter *iter);

    PopplerLayersIter *poppler_layers_iter_get_child   (PopplerLayersIter *parent);
    gchar             *poppler_layers_iter_get_title   (PopplerLayersIter *iter);
    PopplerLayer      *poppler_layers_iter_get_layer   (PopplerLayersIter *iter);
    gboolean           poppler_layers_iter_next        (PopplerLayersIter *iter);

    /* Export to ps */
    GType          poppler_ps_file_get_type       ();
    PopplerPSFile *poppler_ps_file_new            (PopplerDocument *document,
            const char      *filename,
            int              first_page,
            int              n_pages);
    void           poppler_ps_file_set_paper_size (PopplerPSFile   *ps_file,
            double           width,
            double           height);
    void           poppler_ps_file_set_duplex     (PopplerPSFile   *ps_file,
            gboolean         duplex);
    void           poppler_ps_file_free           (PopplerPSFile   *ps_file);
}


