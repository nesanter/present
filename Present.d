import std.stdio;
import std.conv;
import std.string;
import std.exception;
import std.process;
import std.file;

static import gtk.Builder;
static import gtk.Main;
static import gtk.Window;
static import gtk.MenuItem;
static import gtk.CheckMenuItem;
static import gtk.RadioMenuItem;
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
static import gtkc.gtktypes;
static import gtkc.gdktypes;
static import gdk.Event;
static import gdk.Rectangle;
static import gobject.CClosure;
static import gtk.DrawingArea;
static import cairo.Context;
static import gtkc.cairotypes;
static import poppler_glib.poppler;
static import poppler_glib.document;
static import poppler_glib.page;
static import gtk.DragAndDrop;
static import gdk.Atoms;

import Content, ContentNode, PresentMath, PresentPreview, PresentTableDialog, PresentColumnDialog, PresentListingDialog, Loader;

Present app;

void main(string[] args) {

//    auto doc = poppler_glib.document.poppler_document_new_from_file("file:/home/noah/programming/present/output.pdf", null, null);
//    writeln(doc);
//    writeln(poppler_glib.document.poppler_document_get_n_pages(doc));
//    auto page = poppler_glib.document.poppler_document_get_page(doc, 0);

    gtk.Main.Main.init(args);

    app = new Present();

    app.run();

    gtk.Main.Main.run();
}

enum ContextType {
    NONE,
    MATH,
    LIST,
    TABLE,
    COLUMN,
    LISTING,
    ANIM_GROUP,
    TIKZ
}

extern (C) void main_window_present_cb() {
    app.main_window.present();
}

extern (C) void sub_window_present_cb() {
    if (app.content.current_node.context == ContextType.MATH) {
        if (app.math_window.window.getVisible() == 1) {
            app.math_window.window.present();
        }
    }
}

extern (C) void refresh_preview_cb() {
    auto item = cast(gtk.CheckMenuItem.CheckMenuItem)app.builder.getObject("file-toggle-preview");
    item.setActive(1);
    app.preview_window.show();
    app.preview_window.window.present();
    if (!app.generatePreview())
        return;
    app.preview_window.updatePreview(app.preview_filename, false);
}

class Present {
    gtk.Builder.Builder builder;
    Content content;
    gtk.Window.Window main_window;
    gsv.SourceView.SourceView editor;
    gtk.TreeViewColumn.TreeViewColumn name_column;
//    gtk.CellRendererText.CellRendererText name_column_renderer;
    gtk.TreeView.TreeView tree_view;
//    gtk.MenuItem.MenuItem insert_orphaned_item;

//    PresentContext context_window;
    PresentPreview preview_window;
    PresentMath math_window;
    PresentTableDialog table_dialog;
    PresentColumnDialog column_dialog;
    PresentListingDialog listing_dialog;

    gtk.MenuItem.MenuItem properties_math_item;
    gtk.MenuItem.MenuItem properties_list_item;
    gtk.MenuItem.MenuItem properties_table_item;
    gtk.MenuItem.MenuItem properties_column_item;
    gtk.MenuItem.MenuItem properties_listing_item;
    gtk.MenuItem.MenuItem properties_tikz_item;

    gtk.CheckMenuItem.CheckMenuItem properties_math_inline;

    gtk.RadioMenuItem.RadioMenuItem[] properties_list_type_items;

    gtk.MenuItem.MenuItem properties_table_size;
    gtk.CheckMenuItem.CheckMenuItem properties_table_group;

    gtk.CheckMenuItem.CheckMenuItem properties_column_align;

    gtk.CheckMenuItem.CheckMenuItem frame_shrink_contents;

    gtk.MenuItem.MenuItem content_insert_math;
    gtk.MenuItem.MenuItem[ContentNodeType] insert_items;

    bool auto_select;

    string target_name = "tree";

//    string preview_filename = "file:/home/noah/programming/present/out/preview.pdf";
    string preview_filename;
    bool preview_ready = true;

    void run() {
        builder = new gtk.Builder.Builder();
        builder.addFromFile("interface.glade");

        main_window = cast(gtk.Window.Window)(builder.getObject("main-window"));
        main_window.addOnDestroy(&main_window_quit_action);

        init_accels();
        init_menu_bar();
        init_tree();
        init_editor();
        init_preview_window();
        init_math_window();
        init_table_dialog();
        init_column_dialog();
        init_listing_dialog();

        preview_filename = tempDir() ~ "/preview";

        ContentNode.ContentNode.init_list_types();

        updateContext();

        main_window.showAll();
    }

    void init_accels() {
        auto main_accel_group = cast(gtk.AccelGroup.AccelGroup)builder.getObject("main-window-accels");
        auto sub_accel_group = cast(gtk.AccelGroup.AccelGroup)builder.getObject("sub-window-accels");
        uint key;
        gtkc.gdktypes.GdkModifierType mods;

        auto closure = gobject.CClosure.CClosure.newObject(&sub_window_present_cb, main_window);
        gtk.AccelGroup.AccelGroup.acceleratorParse("Escape", key, mods);
        main_accel_group.connect(key, mods, cast(gtk.AccelGroup.GtkAccelFlags)0, closure);

        closure = gobject.CClosure.CClosure.newObject(&main_window_present_cb, main_window);
        gtk.AccelGroup.AccelGroup.acceleratorParse("Escape", key, mods);
        sub_accel_group.connect(key, mods, cast(gtk.AccelGroup.GtkAccelFlags)0, closure);

        closure = gobject.CClosure.CClosure.newObject(&refresh_preview_cb, main_window);
        gtk.AccelGroup.AccelGroup.acceleratorParse("<Control>r", key, mods);
        main_accel_group.connect(key, mods, cast(gtk.AccelGroup.GtkAccelFlags)0, closure);
    }

    void init_menu_bar() {
        auto file_quit = cast(gtk.MenuItem.MenuItem)builder.getObject("file-quit");
        file_quit.addOnActivate(&file_quit_action);

        auto file_export = cast(gtk.MenuItem.MenuItem)builder.getObject("file-export");
        file_export.addOnActivate(&file_export_action);

        auto file_open = cast(gtk.MenuItem.MenuItem)builder.getObject("file-open");
        file_open.addOnActivate(&file_open_action);

        auto file_save = cast(gtk.MenuItem.MenuItem)builder.getObject("file-save");
        file_save.addOnActivate(&file_save_action);


//        auto content_insert = cast(gtk.MenuItem.MenuItem)builder.getObject("content-insert-item");
//        content_insert.addOnActivate(&popup_insert_action);

//        auto content_animate = cast(gtk.MenuItem.MenuItem)builder.getObject("content-animate-item");
//        content_animate.addOnActivate(&popup_animate_action);

        auto frame_new = cast(gtk.MenuItem.MenuItem)builder.getObject("frame-new");
        frame_new.addOnActivate(&new_frame_action);

        auto frame_remove = cast(gtk.MenuItem.MenuItem)builder.getObject("frame-remove");
        frame_remove.addOnActivate(&remove_frame_action);

        auto frame_add_title = cast(gtk.MenuItem.MenuItem)builder.getObject("frame-add-title");
        frame_add_title.addOnActivate(&frame_add_title_action);
        insert_items[ContentNodeType.FRAME_TITLE] = frame_add_title;

        frame_shrink_contents = cast(gtk.CheckMenuItem.CheckMenuItem)builder.getObject("frame-shrink");
        frame_shrink_contents.addOnToggled(&frame_shrink_contents_action);

        auto frame_previous = cast(gtk.MenuItem.MenuItem)builder.getObject("frame-previous");
        auto frame_next = cast(gtk.MenuItem.MenuItem)builder.getObject("frame-next");

        frame_previous.addOnActivate(&frame_previous_action);
        frame_next.addOnActivate(&frame_next_action);

//        auto content_merge = cast(gtk.MenuItem.MenuItem)builder.getObject("content-merge");
//        content_merge.addOnActivate(&merge_action);

        content_insert_math = cast(gtk.MenuItem.MenuItem)builder.getObject("content-insert-math");
        content_insert_math.addOnActivate(&insert_math_action);
//        insert_items[ContentNodeType.MATH] = content_insert_math;
//        insert_items[ContentNodeType.MATH_INLINE] = content_insert_math;

        auto content_insert_list = cast(gtk.MenuItem.MenuItem)builder.getObject("content-insert-list");
        content_insert_list.addOnActivate(&insert_list_action);
        insert_items[ContentNodeType.LIST] = content_insert_list;

        auto content_insert_table = cast(gtk.MenuItem.MenuItem)builder.getObject("content-insert-table");
        content_insert_table.addOnActivate(&insert_table_action);
        insert_items[ContentNodeType.TABLE] = content_insert_table;

        auto content_insert_columns = cast(gtk.MenuItem.MenuItem)builder.getObject("content-insert-columns");
        content_insert_columns.addOnActivate(&insert_columns_action);
        insert_items[ContentNodeType.COLUMN_GROUP] = content_insert_columns;

        auto content_insert_listing = cast(gtk.MenuItem.MenuItem)builder.getObject("content-insert-listing");
        content_insert_listing.addOnActivate(&insert_listing_action);
        insert_items[ContentNodeType.LISTING] = content_insert_listing;

        auto content_insert_graphic = cast(gtk.MenuItem.MenuItem)builder.getObject("content-insert-figure-graphic");
        content_insert_graphic.addOnActivate(&insert_graphic_action);
        insert_items[ContentNodeType.GRAPHIC] = content_insert_graphic;

        auto content_insert_tikz = cast(gtk.MenuItem.MenuItem)builder.getObject("content-insert-figure-tikz");
        content_insert_tikz.addOnActivate(&insert_tikz_action);
        insert_items[ContentNodeType.TIKZ_PICTURE] = content_insert_tikz;

        auto content_animate_overprint = cast(gtk.MenuItem.MenuItem)builder.getObject("content-animate-overprint");
        content_animate_overprint.addOnActivate(&insert_overprint_action);
        insert_items[ContentNodeType.OVERPRINT] = content_animate_overprint;

        auto content_remove = cast(gtk.MenuItem.MenuItem)builder.getObject("content-remove");
        content_remove.addOnActivate(&content_remove_action);

        auto content_duplicate = cast (gtk.MenuItem.MenuItem)builder.getObject("content-duplicate");
        content_duplicate.addOnActivate(&content_duplicate_action);

//        auto content_show_master = cast(gtk.CheckMenuItem.CheckMenuItem)builder.getObject("content-show-master");
//        content_show_master.addOnToggled(&show_master_action);
        auto content_auto_select = cast(gtk.CheckMenuItem.CheckMenuItem)builder.getObject("content-auto-select");
        content_auto_select.addOnToggled(&auto_select_action);
        auto_select = content_auto_select.getActive() == 1;

//        insert_orphaned_item = cast(gtk.MenuItem.MenuItem)builder.getObject("content-insert-orphaned");
//        insert_orphaned_item.addOnActivate(&insert_orphaned_action);
        auto content_descend = cast(gtk.MenuItem.MenuItem)builder.getObject("content-descend");
        content_descend.addOnActivate(&content_descend_action);
        auto content_ascend = cast(gtk.MenuItem.MenuItem)builder.getObject("content-ascend");
        content_ascend.addOnActivate(&content_ascend_action);

        auto preview_window_toggle = cast(gtk.CheckMenuItem.CheckMenuItem)builder.getObject("file-toggle-preview");
        preview_window_toggle.addOnToggled(&preview_window_toggle_action);
        auto math_window_toggle = cast(gtk.CheckMenuItem.CheckMenuItem)builder.getObject("file-toggle-math");
        math_window_toggle.addOnToggled(&math_window_toggle_action);

        properties_math_item = cast(gtk.MenuItem.MenuItem)builder.getObject("properties-math-item");

        properties_math_inline = cast(gtk.CheckMenuItem.CheckMenuItem)builder.getObject("properties-math-inline");
        properties_math_inline.addOnToggled(&properties_math_inline_toggle_action);

        properties_list_item = cast(gtk.MenuItem.MenuItem)builder.getObject("properties-list-item");
        
        auto properties_list_itemize = cast(gtk.RadioMenuItem.RadioMenuItem)builder.getObject("properties-list-itemize");
        auto properties_list_enumerate = cast(gtk.RadioMenuItem.RadioMenuItem)builder.getObject("properties-list-enumerate");
        auto properties_list_alpha = cast(gtk.RadioMenuItem.RadioMenuItem)builder.getObject("properties-list-alpha");
        properties_list_itemize.addOnActivate(&properties_list_type_change_action);
        properties_list_enumerate.addOnActivate(&properties_list_type_change_action);
        properties_list_alpha.addOnActivate(&properties_list_type_change_action);

        properties_list_type_items = [
            properties_list_itemize,
            properties_list_enumerate,
            properties_list_alpha
        ];

        properties_table_item = cast(gtk.MenuItem.MenuItem)builder.getObject("properties-table-item");

        properties_table_size = cast(gtk.MenuItem.MenuItem)builder.getObject("properties-table-size");
        properties_table_size.addOnActivate(&properties_table_size_action);

        properties_table_group = cast(gtk.CheckMenuItem.CheckMenuItem)builder.getObject("properties-table-group");
        properties_table_group.addOnToggled(&properties_table_group_toggle);

        auto properties_table_border = cast(gtk.MenuItem.MenuItem)builder.getObject("properties-table-border");
        properties_table_border.addOnActivate(&properties_table_border_action);

        properties_column_item = cast(gtk.MenuItem.MenuItem)builder.getObject("properties-column-item");
        
        auto properties_column_size = cast(gtk.MenuItem.MenuItem)builder.getObject("properties-column-size");
        properties_column_size.addOnActivate(&properties_column_size_action);

        auto properties_column_add = cast(gtk.MenuItem.MenuItem)builder.getObject("properties-column-add");
        properties_column_add.addOnActivate(&properties_column_add_action);

        properties_column_align = cast(gtk.CheckMenuItem.CheckMenuItem)builder.getObject("properties-column-align");
        properties_column_align.addOnToggled(&properties_column_align_action);

        properties_listing_item = cast(gtk.MenuItem.MenuItem)builder.getObject("properties-listing-item");
        
        auto properties_listing_style = cast(gtk.MenuItem.MenuItem)builder.getObject("properties-listing-style");
        properties_listing_style.addOnActivate(&properties_listing_style_action);

        properties_tikz_item = cast(gtk.MenuItem.MenuItem)builder.getObject("properties-tikz-item");

        auto properties_tikz_add_element = cast(gtk.MenuItem.MenuItem)builder.getObject("properties-tikz-add-element");
        properties_tikz_add_element.addOnActivate(&properties_tikz_add_element_action);
    }

    void init_editor() {
        editor = cast(gsv.SourceView.SourceView)builder.getObject("frame-editor");
        
        auto font = new pango.PgFontDescription.PgFontDescription();
        font.setFamily("monospace");
        editor.modifyFont(font);

//        editor.setBuffer(content.selection_buffer);
//        editor.setBuffer(content.current_node.buffer);
//        editor.setEditable(0);

        editor.addOnUndo(&undo_redo_action);
        editor.addOnRedo(&undo_redo_action);
    }

    void init_tree() {
        tree_view = cast(gtk.TreeView.TreeView)builder.getObject("frame-tree");
        
        content = new Content(builder);

        name_column = cast(gtk.TreeViewColumn.TreeViewColumn)builder.getObject("tree-column-content");
//        name_column_renderer = new gtk.CellRendererText.CellRendererText();
//        name_column = new gtk.TreeViewColumn.TreeViewColumn("Content", name_column_renderer, "text", 0);

//        cid_column_renderer = new gtk.CellRendererText.CellRendererText();
//        cid_column = new gtk.TreeViewColumn.TreeViewColumn("

//        tree_view.appendColumn();

//        auto iter = content.model.append(null);
//        content.model.setValue(iter, 0, "test");

        tree_view.setModel(content.model);

        tree_view.addOnRowActivated(&row_activated_action);

        gtkc.gtktypes.GtkTargetEntry[1] dnd_target_list = [gtkc.gtktypes.GtkTargetEntry(cast(char*)target_name, gtkc.gtktypes.GtkTargetFlags.SAME_WIDGET, 0)];

        tree_view.enableModelDragDest(dnd_target_list, gtkc.gdktypes.GdkDragAction.ACTION_MOVE);
        tree_view.enableModelDragSource(gtkc.gdktypes.GdkModifierType.BUTTON1_MASK, dnd_target_list, gtkc.gdktypes.GdkDragAction.ACTION_MOVE);

        tree_view.addOnDragDataGet(&tree_drag_data_get_action);
        tree_view.addOnDragDataReceived(&tree_drag_data_received_action);
        
//        gtk.DragAndDrop.DragAndDrop.destSet(tree_view, gtkc.gtktypes.GtkDestDefaults.HIGHLIGHT | gtkc.gtktypes.GtkDestDefaults.MOTION, dnd_target_list, gtkc.gdktypes.GdkDragAction.ACTION_MOVE);
//        gtk.DragAndDrop.DragAndDrop.sourceSet(tree_view, gtkc.gdktypes.GdkModifierType.BUTTON1_MASK, dnd_target_list, gtkc.gdktypes.GdkDragAction.ACTION_MOVE);

        /*
        tree_view.addOnDragDataRecieved(&tree_drag_data_recieved_action);
        tree_view.addOnDragLeave(&tree_drag_leave_action);
        tree_view.addOnDragMotion(&tree_drag_motion_action);
        tree_view.addOnDragDrop(&tree_drag_drop_action);
        */


    }

    void init_preview_window() {
        preview_window = new PresentPreview(builder);
//        context_window = new PresentContext(builder);
//        context_window.setContext(ContextType.NONE);
    }

    void init_math_window() {
        math_window = new PresentMath(builder);
    }

    void init_table_dialog() {
        table_dialog = new PresentTableDialog(builder);
    }

    void init_column_dialog() {
        column_dialog = new PresentColumnDialog(builder);
    }

    void init_listing_dialog() {
        listing_dialog = new PresentListingDialog(builder);
    }

    void main_window_quit_action(gtk.Widget.Widget widget) {
        gtk.Main.Main.quit();
    }

    void updateContext() {

        main_window.setTitle("Present - "~content.current_node.buildTitle());

        if (content.current_node.editable) {
            editor.setEditable(1);
        } else {
            editor.setEditable(0);
        }

        foreach (key, value; insert_items) {
            if (content.current_node.acceptsNodeType(key))
                value.setSensitive(1);
            else
                value.setSensitive(0);
        }

        if (content.current_node.acceptsNodeType(ContentNodeType.MATH)) {
            content_insert_math.setSensitive(1);
            content_insert_math.setLabel("_Math");
        } else if (content.current_node.acceptsNodeType(ContentNodeType.MATH_INLINE)) {
            content_insert_math.setSensitive(1);
            content_insert_math.setLabel("_Math (inline)");
        } else {
            content_insert_math.setSensitive(0);
        }

        if (content.current_node.type == ContentNodeType.FRAME) {
            frame_shrink_contents.setSensitive(1);
            frame_shrink_contents.setActive(content.current_node.shrink_contents ? 1 : 0);
        } else {
            frame_shrink_contents.setSensitive(0);
        }

        auto content_menu = cast(gtk.MenuItem.MenuItem)builder.getObject("content-menu-item");
        if (content.current_node.type == ContentNodeType.ROOT) {
            content_menu.setSensitive(0);
        } else {
            content_menu.setSensitive(1);
        }

        if (content.current_node.context == ContextType.MATH) {
            math_window.enable();
            properties_math_item.setVisible(1);
            if (content.current_node.type == ContentNodeType.MATH) {
                properties_math_inline.setActive(0);
            } else if (content.current_node.type == ContentNodeType.MATH_INLINE) {
                properties_math_inline.setActive(1);
            }
        } else {
            math_window.disable();
            main_window.present();
            editor.grabFocus();
            properties_math_item.setVisible(0);
        }

        if (content.current_node.context == ContextType.LIST) {
            foreach (item; properties_list_type_items) {
                if (item.getName() == "properties.list.type."~content.current_node.list_type) {
                    item.setActive(1);
                    break;
                }
            }
            properties_list_item.setVisible(1);
        } else {
            properties_list_item.setVisible(0);
        }

        if (content.current_node.context == ContextType.TABLE) {
            auto table = content.current_node.findParent(ContentNodeType.TABLE);
            table.calculateTableWeights();
            auto valid = table.tableValid();
            content.updateDisplayName(table, true);
//            if (valid)
//                writeln(table.flattenTable());
//            auto size = table.tableSize();
//            writeln("Size = ",size);
//            if (size == (table.table_width * table.table_height))
//                writeln(table.flattenTable());
//            if (table.table_width == table.weight[0] && table.table_height == table.weight[1])
//                writeln(table.flattenTable());
            properties_table_item.setVisible(1);
            if (content.current_node.type == ContentNodeType.TABLE_GROUP) {
                properties_table_group.setActive(1);
                properties_table_group.setSensitive(1);
            } else if (content.current_node.type == ContentNodeType.TABLE_CELL) {
                properties_table_group.setActive(0);
                properties_table_group.setSensitive(1);
            } else {
                properties_table_group.setActive(0);
                properties_table_group.setSensitive(1);
            }

            if (content.current_node.type == ContentNodeType.TABLE ||
                content.current_node.type == ContentNodeType.TABLE_GROUP) {
                properties_table_size.setSensitive(1);
            } else {
                properties_table_size.setSensitive(0);
            }
        } else {
            properties_table_item.setVisible(0);
        }

        if (content.current_node.context == ContextType.COLUMN) {
            properties_column_item.setVisible(1);
            properties_column_align.setActive((content.current_node.top_aligned ? 1 : 0));
        } else {
            properties_column_item.setVisible(0);
        }

        if (content.current_node.context == ContextType.LISTING) {
            properties_listing_item.setVisible(1);
        } else {
            properties_listing_item.setVisible(0);
        }

        if (content.current_node.context == ContextType.TIKZ) {
            properties_tikz_item.setVisible(1);
        } else {
            properties_tikz_item.setVisible(0);
        }
    }

    bool runLatex() {
        auto pid = spawnProcess(["pdflatex", "-halt-on-error", "-output-directory="~tempDir(), "preview.tex"]);
        if (wait(pid) == 0) {
            return true;
        } else {
            return false;
        }
    }

    bool generatePreview() {
        File previewfile = File(preview_filename~".tex", "w");
        content.exportLatex(previewfile, content.current_node);
        previewfile.close();
        return runLatex();
    }

    void file_quit_action(gtk.MenuItem.MenuItem item) {
        gtk.Main.Main.quit();
    }

    void file_export_action(gtk.MenuItem.MenuItem item) {
        File f = File("output.tex", "w");
        content.exportLatex(f, null);
        f.close();
    }

    void file_open_action(gtk.MenuItem.MenuItem item) {
        content.clear();
        if (Loader.Loader.load(content, tempDir()~"/test_save")) {
//            viewCurrent();
            editor.setBuffer(content.root_node.buffer);
            updateContext();
        } else {
            writeln("loading failed");
        }
    }

    void file_save_action(gtk.MenuItem.MenuItem item) {
        Loader.Loader.save(content, tempDir()~"/test_save");
    }

    void popup_insert_action(gtk.MenuItem.MenuItem item) {
        auto content_insert_menu = cast(gtk.Menu.Menu)(builder.getObject("content-insert"));
        content_insert_menu.popup(null, null, null, null, 0, gtk.Main.Main.getCurrentEventTime());
    }

    void popup_animate_action(gtk.MenuItem.MenuItem item) {
        auto content_animate_menu = cast(gtk.Menu.Menu)(builder.getObject("content-animate"));
        content_animate_menu.popup(null, null, null, null, 0, gtk.Main.Main.getCurrentEventTime());
    }

    void new_frame_action(gtk.MenuItem.MenuItem item) {
        auto node = content.insertNodeAtToplevel(ContentNodeType.FRAME, auto_select);
        if (auto_select) {
            viewCurrent();
//            editor.setEditable(1);
            updateContext();
        } else {
            content.updateView(editor);
        }
    }

    void remove_frame_action(gtk.MenuItem.MenuItem item) {
        /*
        auto path = content.current_node.path;
        while (path.getDepth() > 1) {
            path.up();
        }
        auto frame = content.getNodeFromPath(path);
        */

        auto frame = content.current_node.findParent(ContentNodeType.FRAME);
        if (frame is null)
            return;

        content.removeFromModel(frame);

        foreach (i, child; content.root_node.children) {
            if (child == frame) {
                if ((i+1) == content.root_node.children.length) {
                    content.root_node.children = content.root_node.children[0 .. $-1];
                } else {
                    content.root_node.children = content.root_node.children[0 .. i] ~ content.root_node.children[i+1 .. $];
                }
                break;
            }
        }

        content.current_node = content.root_node;
        editor.setBuffer(content.current_node.buffer);
        updateContext();
    }

    void frame_add_title_action(gtk.MenuItem.MenuItem item) {
        auto node = content.insertNodeAtCursor(ContentNodeType.FRAME_TITLE, auto_select);
        if (node is null)
            return;

        if (auto_select) {
            editor.setBuffer(content.current_node.buffer);
            updateContext();
        } else {
            content.updateView(editor);
        }
    }

    void frame_shrink_contents_action(gtk.CheckMenuItem.CheckMenuItem item) {
        if (content.current_node.type != ContentNodeType.FRAME)
            return;

        content.current_node.shrink_contents = item.getActive() == 1;
    }

    void frame_previous_action(gtk.MenuItem.MenuItem item) {
        auto frame = content.current_node.findParent(ContentNodeType.FRAME);
        if (frame is null)
            return;

        auto indices = frame.path.getIndices();

        if (indices[0] > 0) {
            content.current_node = content.root_node.children[indices[0]-1];
            viewCurrent();
            updateContext();
        }
    }

    void frame_next_action(gtk.MenuItem.MenuItem item) {
        auto frame = content.current_node.findParent(ContentNodeType.FRAME);
        if (frame is null)
            return;

        auto indices = frame.path.getIndices();

        if (indices[0]+1 < content.root_node.children.length) {
            content.current_node = content.root_node.children[indices[0]+1];
            viewCurrent();
            updateContext();
        }
    }

    void insert_math_action(gtk.MenuItem.MenuItem item) {
        auto node = content.insertNodeAtCursor(ContentNodeType.MATH, auto_select);
        if (node is null) {
            node = content.insertNodeAtCursor(ContentNodeType.MATH_INLINE, auto_select);
        }
        if (auto_select) {
            editor.setBuffer(content.current_node.buffer);
            updateContext();
        } else {
            content.updateView(editor);
        }
    }

    void insert_list_action(gtk.MenuItem.MenuItem item) {
        auto node = content.insertNodeAtCursor(ContentNodeType.LIST, auto_select);
        if (auto_select) {
            editor.setBuffer(content.current_node.buffer);
            updateContext();
        } else {
            content.updateView(editor);
        }
    }

    void insert_table_action(gtk.MenuItem.MenuItem item) {
        if (table_dialog.runSize()) {
            auto node = content.insertNodeAtCursor(ContentNodeType.TABLE, auto_select);
//            node.table_width = table_dialog.getWidth();
//            node.table_height = table_dialog.getHeight();
            node.populateTable(table_dialog.getWidth(), table_dialog.getHeight());
            content.updateModel(node, false);
            if (auto_select) {
                editor.setBuffer(content.current_node.buffer);
                updateContext();
            } else {
                content.updateView(editor);
            }
        }
    }

    void insert_columns_action(gtk.MenuItem.MenuItem item) {
        auto node = content.insertNodeAtCursor(ContentNodeType.COLUMN_GROUP, auto_select);
        if (node is null)
            return;

        foreach (i; 0 .. 2) {
            auto col = content.insertNodeAtCursor(node, ContentNodeType.COLUMN);
            col.column_size = 50;
            content.updateDisplayName(col);
        }

        if (auto_select) {
            editor.setBuffer(content.current_node.buffer);
            updateContext();
        }
    }

    void insert_listing_action(gtk.MenuItem.MenuItem item) {
        auto node = content.insertNodeAtCursor(ContentNodeType.LISTING, auto_select);

        if (auto_select) {
            editor.setBuffer(content.current_node.buffer);
            updateContext();
        }
    }

    void insert_overprint_action(gtk.MenuItem.MenuItem item) {
        auto node = content.insertNodeAtCursor(ContentNodeType.OVERPRINT, auto_select);

        if (node is null)
            return;

        foreach (i; 0 .. 2) {
            auto view = content.insertNodeAtCursor(node, ContentNodeType.ONSLIDE);
        }

        if (auto_select) {
            viewCurrent();
            updateContext();
        }
    }

    void insert_graphic_action(gtk.MenuItem.MenuItem item) {
        auto node = content.insertNodeAtCursor(ContentNodeType.GRAPHIC, auto_select);
        if (node is null)
            return;

        auto width = content.insertNodeAtCursor(node, ContentNodeType.PROPERTY, "Width", "width");
        content.insertTextAtCursor(width, "\\textwidth");

        auto path = content.insertNodeAtCursor(node, ContentNodeType.PROPERTY, "File", "file");

        if (auto_select) {
            viewCurrent();
            updateContext();
        }
    }

    void insert_tikz_action(gtk.MenuItem.MenuItem item) {
        auto node = content.insertNodeAtCursor(ContentNodeType.TIKZ_PICTURE, auto_select);
        if (node is null)
            return;

        content.insertTextAtCursor(node, "[x=1.0cm,y=1.0cm]");

        if (auto_select) {
            viewCurrent();
            updateContext();
        }
    }
    
    void merge_action(gtk.MenuItem.MenuItem item) {
//        content.merge_current();
    }

    void row_activated_action(gtk.TreePath.TreePath path, gtk.TreeViewColumn.TreeViewColumn column, gtk.TreeView.TreeView view) {
        content.checkOrphans();



        content.activate(path);
//        auto editor = cast(gtk.TextView.TextView)builder.getObject("frame-editor");
//        editor.setBuffer(content.current_node.buffer);
        content.updateView(editor);
        updateContext();
        /*
        if (content.current_node.orphan_count > 0) {
            insert_orphaned_item.setSensitive(1);
        } else {
            insert_orphaned_item.setSensitive(0);
        }
        */
//        context_window.setContext(content.current_node.context);
    }

    void undo_redo_action(gsv.SourceView.SourceView view) {
//        content.updateView(view);
    }

    /*
    void insert_orphaned_action(gtk.MenuItem.MenuItem item) {
        content.restoreOrphan(editor);

        if (content.current_node.orphan_count > 0) {
            insert_orphaned_item.setSensitive(1);
        } else {
            insert_orphaned_item.setSensitive(0);
        }
    }
    */

    void auto_select_action(gtk.CheckMenuItem.CheckMenuItem item) {
        auto_select = item.getActive() == 1;
    }
    /*
    void show_master_action(gtk.CheckMenuItem.CheckMenuItem item) {
        auto editor = cast(gtk.TextView.TextView)builder.getObject("frame-editor");
        if (item.getActive()) {
            editor.setBuffer(content.master_buffer);
            editor.setEditable(0);
        } else {
            editor.setBuffer(content.selection_buffer);
            editor.setEditable(1);
        }
    }
    */

    void content_duplicate_action(gtk.MenuItem.MenuItem item) {
        auto parent = content.current_node.parent;

        ContentNode copy;

        if (content.current_node.type == ContentNodeType.FRAME) {
            copy = content.duplicate(content.current_node, true);
            content.insertNodeAtToplevel(copy, auto_select);
        } else if (parent !is null && parent.editable) {
            copy = content.duplicate(content.current_node, true);
            content.insertNodeAtCursor(parent, copy);
        } else {
            return;
        }

        content.updateModel(copy);

        if (auto_select) {
            content.current_node = copy;
            viewCurrent();
            updateContext();
        }
    }

    void content_descend_action(gtk.MenuItem.MenuItem item) {
        content.descend();
        updateContext();
    }
    void content_ascend_action(gtk.MenuItem.MenuItem item) {
        content.ascend();
        updateContext();
    }

    void content_remove_action(gtk.MenuItem.MenuItem item) {
        if (content.current_node.type != ContentNodeType.FRAME) {
            auto path = content.current_node.path;
            path.up();
            auto node = content.getNodeFromPath(path);
            if (!node.editable)
                return;
            node.removeChild(content.current_node);
            content.removeFromModel(content.current_node);
            content.current_node = node;
            viewCurrent();
            updateContext();
        }
    }

    void math_window_toggle_action(gtk.CheckMenuItem.CheckMenuItem item) {
        if (item.getActive()) {
            math_window.show();
            math_window.window.present();
            math_window.entry.grabFocus();
        } else {
            math_window.hide();
        }
    }
    
    void preview_window_toggle_action(gtk.CheckMenuItem.CheckMenuItem item) {
        if (item.getActive()) {
            preview_window.show();
            preview_window.window.present();
        } else {
            preview_window.hide();
        }
    }

    void properties_math_inline_toggle_action(gtk.CheckMenuItem.CheckMenuItem item) {
        if (content.current_node.type == ContentNodeType.MATH) {
            if (item.getActive()) {
                if (content.current_node.parent.acceptsNodeType(ContentNodeType.MATH_INLINE)) {
                    content.current_node.type = ContentNodeType.MATH_INLINE;
                    content.updateDisplayName(content.current_node);
                } else {
                    item.setActive(0);
                }
            }
        } else if (content.current_node.type == ContentNodeType.MATH_INLINE) {
            if (!item.getActive()) {
                if (content.current_node.parent.acceptsNodeType(ContentNodeType.MATH)) {
                    content.current_node.type = ContentNodeType.MATH;
                    content.updateDisplayName(content.current_node);
                } else {
                    item.setActive(1);
                }
            }
        }
    }

    void properties_list_type_change_action(gtk.MenuItem.MenuItem item) {
        if (content.current_node.context != ContextType.LIST)
            return;

        string name = item.getName();

//        writeln(name);

        long index = lastIndexOf(name, ".");

        if (index == -1)
            return;

        content.current_node.list_type = name[index+1 .. $];
        content.updateDisplayName(content.current_node);
    }

    void properties_table_size_action(gtk.MenuItem.MenuItem item) {
        if (content.current_node.context != ContextType.TABLE)
            return;

        if (table_dialog.runSize()) {
            if (content.current_node.type == ContentNodeType.TABLE) {
                content.current_node.resizeTable(table_dialog.getWidth(), table_dialog.getHeight());
                content.updateDisplayName(content.current_node);
            } else if (content.current_node.type == ContentNodeType.TABLE_GROUP) {
                content.current_node.resizeTableGroup(table_dialog.getWidth(), table_dialog.getHeight());
                content.updateModel(content.current_node);
            }
            updateContext();
        }
    }

    void properties_table_border_action(gtk.MenuItem.MenuItem item) {
        if (content.current_node.context != ContextType.TABLE)
            return;

        auto table = content.current_node.findParent(ContentNodeType.TABLE);

        if (table.invalid)
            return;

        table_dialog.table = table.flattenTable();

        table_dialog.runBorder();
    }

    void properties_table_group_toggle(gtk.CheckMenuItem.CheckMenuItem item) {
        if (item.getActive()) {
            //group
            if (content.current_node.type != ContentNodeType.TABLE_CELL)
                return;

            if (table_dialog.runSize()) {
                content.current_node.type = ContentNodeType.TABLE_GROUP;
                content.current_node.children = [];
                content.current_node.clearBuffer();
                content.current_node.populateTableGroup(table_dialog.getWidth(), table_dialog.getHeight());

                content.updateModel(content.current_node);
            }
        } else {
            //cell
            if (content.current_node.type != ContentNodeType.TABLE_GROUP)
                return;

            content.current_node.type = ContentNodeType.TABLE_CELL;
            content.current_node.children = [];
            content.current_node.clearBuffer();

            content.updateModel(content.current_node);
        }
        updateContext();
    }

    void properties_column_size_action(gtk.MenuItem.MenuItem item) {
        if (content.current_node.context != ContextType.COLUMN)
            return;

        auto column_group = content.current_node.findParent(ContentNodeType.COLUMN_GROUP);

        column_dialog.runSize(column_group);
    }

    void properties_column_add_action(gtk.MenuItem.MenuItem item) {
        if (content.current_node.context != ContextType.COLUMN)
            return;

        auto column_group = content.current_node.findParent(ContentNodeType.COLUMN_GROUP);

        auto col = content.insertNodeAtCursor(column_group, ContentNodeType.COLUMN);

        ulong n_auto;
        ulong taken;

        foreach (child; column_group.children) {
            if (child.auto_sized)
                n_auto++;
            else
                taken += child.column_size;
        }

        ulong split;
        if (taken < 100)
            split = (100 - taken) / n_auto;

        foreach (child; column_group.children) {
            if (child.auto_sized) {
                child.column_size = split;
                content.updateDisplayName(child);
            }
        }
    }

    void properties_column_align_action(gtk.CheckMenuItem.CheckMenuItem item) {
        if (content.current_node.context != ContextType.COLUMN)
            return;

        content.current_node.top_aligned = item.getActive() == 1;
    }

    void properties_listing_style_action(gtk.MenuItem.MenuItem item) {
        if (content.current_node.context != ContextType.LISTING)
            return;

        listing_dialog.runEditor();

        content.current_node.listing_style = listing_dialog.active_style;
        content.updateDisplayName(content.current_node);
    }

    void properties_tikz_add_element_action(gtk.MenuItem.MenuItem item) {
        if (content.current_node.context != ContextType.TIKZ)
            return;

        auto tikz = content.current_node.findParent(ContentNodeType.TIKZ_PICTURE);

        auto element = content.insertNodeAtCursor(tikz, ContentNodeType.TIKZ_ELEMENT);

        if (auto_select) {
            content.current_node = element;
            viewCurrent();
            updateContext();
        }
    }

    void tree_drag_data_get_action(gdk.DragContext.DragContext context, gtk.SelectionData.SelectionData selection, uint info, uint time, gtk.Widget.Widget widget) {
        auto s = tree_view.getSelection();
        auto iter = s.getSelected();
        auto path = iter.getTreePath();
        auto node = content.getNodeFromPath(path);
//        writeln(node);
//        selection.dataSetText(to!string(node.id));
        selection.dataSet(gdk.Atoms.atomIntern("string", 0), 8, cast(char[])to!string(node.id));
    }

    void tree_drag_data_received_action(gdk.DragContext.DragContext context, int x, int y, gtk.SelectionData.SelectionData selection, uint info, uint time, gtk.Widget.Widget widget) {
        auto data = text(selection.dataGetData());
        gtk.TreePath.TreePath path;
        gtkc.gtktypes.GtkTreeViewDropPosition pos;
        auto result = tree_view.getDestRowAtPos(x, y, path, pos);
//        writeln(path);
//        writeln("result = ",result);
//        writeln(pos);
//        writeln("data = ",data);


        bool moved;

        if (result == 1) {
            auto indices = path.getIndices();
//            writeln(indices);
//            writeln(indices[0 .. $-1], indices[$-1]);

            final switch (pos) {
                case gtkc.gtktypes.GtkTreeViewDropPosition.BEFORE:
                    moved = content.moveNodeByID(to!ulong(data), indices[0 .. $-1], indices[$-1]);
                    break;
                case gtkc.gtktypes.GtkTreeViewDropPosition.AFTER:
                    moved = content.moveNodeByID(to!ulong(data), indices[0 .. $-1], indices[$-1]+1);
                    break;
                case gtkc.gtktypes.GtkTreeViewDropPosition.INTO_OR_BEFORE:
                case gtkc.gtktypes.GtkTreeViewDropPosition.INTO_OR_AFTER:
                    moved = content.moveNodeByID(to!ulong(data), indices, -1);
                    break;
            }
        } else {
            moved = content.moveNodeByID(to!ulong(data), [], -1);
        }

        if (moved) {
            viewCurrent();
            context.dropFinish(1, time);
        } else {
            context.dropFinish(0, time);
        }
    }

    void viewCurrent() {
        tree_view.expandToPath(content.current_node.path);
        tree_view.setCursor(content.current_node.path, name_column, 0);
        editor.setBuffer(content.current_node.buffer);
    }
}


