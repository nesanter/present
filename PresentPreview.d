import std.stdio;
import std.conv;
import std.string;
import std.exception;
import std.process;

static import gtk.Builder;
static import gtk.Main;
static import gtk.Window;
static import gtk.MenuItem;
static import gtk.CheckMenuItem;
static import pango.PgFontDescription;
static import gtk.TextView;
static import gtk.TextChildAnchor;
static import gtk.TreeView;
static import gtk.TreeStore;
static import gtk.TreePath;
static import gtk.CellRendererText;
static import gtkc.gobjecttypes;
static import gtk.TextTagTable;
static import gtk.Label;
static import gobject.ObjectG;
static import gsv.SourceView;
static import gsv.SourceBuffer;
static import gsv.SourceMark;
static import gtk.ToolPalette;
static import gtk.SearchEntry;
static import gtk.ToolItemGroup;
static import gtk.ToolButton;
static import gtk.MenuToolButton;
static import gtkc.gtk;
static import gdk.Event;
static import gdk.Rectangle;
static import gobject.CClosure;
static import gtk.DrawingArea;
static import cairo.Context;
static import gtkc.cairotypes;
static import poppler_glib.poppler;
static import poppler_glib.document;
static import poppler_glib.page;

import Content, Present;

enum ScaleMode {
    AUTO,
    HSCALE,
    WSCALE
}

class PresentPreview {
    gtk.Builder.Builder builder;
    gtk.Window.Window window;
    gtk.DrawingArea.DrawingArea drawing_area;

    int current_page, n_pages;
    double page_height, page_width;
    double hscale = 1, wscale = 1;

    ScaleMode scale_mode = ScaleMode.AUTO;

    poppler_glib.document.PopplerDocument* current_preview;
    poppler_glib.page.PopplerPage* current_preview_page;

    this(gtk.Builder.Builder builder) {
        this.builder = builder;
        window = cast(gtk.Window.Window)builder.getObject("preview-window");

        window.addOnDelete(&delete_action);

        drawing_area = cast(gtk.DrawingArea.DrawingArea)builder.getObject("preview-area");
        drawing_area.addOnDraw(&preview_draw_action);
        drawing_area.addOnSizeAllocate(&preview_size_allocate_action);

        auto refresh_button = cast(gtk.ToolButton.ToolButton)builder.getObject("preview-refresh");
        refresh_button.addOnClicked(&preview_refresh_action);

        auto next_button = cast(gtk.ToolButton.ToolButton)builder.getObject("preview-next");
        next_button.addOnClicked(&preview_next_action);

        auto prev_button = cast(gtk.ToolButton.ToolButton)builder.getObject("preview-prev");
        prev_button.addOnClicked(&preview_prev_action);
    }

    void show() {
        window.showAll();
    }

    void hide() {
        window.hide();
    }

    void updatePreview(string filename, bool reset_page) {
        if (reset_page)
            current_page = 0;

        current_preview = poppler_glib.document.poppler_document_new_from_file(toStringz(filename), null, null);
        if (current_preview is null) {
            writeln("null");
            return;
        }

        n_pages = poppler_glib.document.poppler_document_get_n_pages(current_preview);

        if (n_pages == 0)
            return;

        if (current_page >= n_pages || current_page < 0)
            current_page = 0;

        current_preview_page = poppler_glib.document.poppler_document_get_page(current_preview, current_page);

        poppler_glib.page.poppler_page_get_size(current_preview_page, &page_width, &page_height);

        int area_height = drawing_area.getAllocatedHeight();
        int area_width = drawing_area.getAllocatedWidth();

        hscale = to!double(area_height) / page_height;
        wscale = to!double(area_width) / page_width;

        drawing_area.queueDrawArea(0, 0, area_width, area_height);
    }

    void updatePreviewPage() {
        if (current_preview is null)
            return;


        if (n_pages == 0)
            return;

        if (current_page >= n_pages)
            current_page = n_pages - 1;

        if (current_page < 0)
            current_page = 0;

        current_preview_page = poppler_glib.document.poppler_document_get_page(current_preview, current_page);

        poppler_glib.page.poppler_page_get_size(current_preview_page, &page_width, &page_height);

        int area_height = drawing_area.getAllocatedHeight();
        int area_width = drawing_area.getAllocatedWidth();

        hscale = to!double(area_height) / page_height;
        wscale = to!double(area_width) / page_width;

        drawing_area.queueDrawArea(0, 0, area_width, area_height);
    }

    void preview_refresh_action(gtk.ToolButton.ToolButton button) {
        if (!app.generatePreview()) {
            return;
        }
        updatePreview(app.preview_filename, false);
    }

    bool delete_action(gdk.Event.Event event, gtk.Widget.Widget widget) {
        auto toggle_item = cast(gtk.CheckMenuItem.CheckMenuItem)builder.getObject("file-toggle-preview");
        toggle_item.setActive(0);
        return (widget.hideOnDelete() == 1);
    }

    bool preview_draw_action(cairo.Context.Context context, gtk.Widget.Widget widget) {
        if (current_preview_page !is null) {


            final switch (scale_mode) {
                case ScaleMode.AUTO:
                    if (hscale < wscale)
                        context.scale(hscale, hscale);
                    else
                        context.scale(wscale, wscale);
                    break;
                case ScaleMode.HSCALE:
                    context.scale(hscale, hscale);
                    break;
                case ScaleMode.WSCALE:
                    context.scale(wscale, wscale);
                    break;
            }

            poppler_glib.page.poppler_page_render(current_preview_page, cast(gtkc.cairotypes.cairo_t*)context.getStruct());
        }
        return false;
    }

    void preview_size_allocate_action(gdk.Rectangle.Rectangle* rect, gtk.Widget.Widget widget) {
        int area_height = drawing_area.getAllocatedHeight();
        int area_width = drawing_area.getAllocatedWidth();

        hscale = to!double(area_height) / page_height;
        wscale = to!double(area_width) / page_width;
    }

    void preview_next_action(gtk.ToolButton.ToolButton button) {
        current_page++;
        updatePreviewPage();
    }

    void preview_prev_action(gtk.ToolButton.ToolButton button) {
        current_page--;
        updatePreviewPage();
    }
}

