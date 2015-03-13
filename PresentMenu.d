import std.stdio;

static import gtk.Builder;
static import gtk.MenuItem;

import ContentNode, Present;

interface MainMenuItem {
    void update(ContentNode current_node);
}

class TypeDependentItem : MainMenuItem {
    ContentNodeType type;
    gtk.MenuItem.MenuItem item;

    this(gtk.Builder.Builder builder, string name, ContentNodeType type) {
        this.type = type;
        item = cast(gtk.MenuItem.MenuItem)builder.getObject(name);
        item.addOnActivate(&action);
    }

    void update(ContentNode current_node) {
        if (current_node.editable && current_node.acceptsNodeType(type)) {
            item.setSensitive(1);
        } else {
            item.setSensitive(0);
        }
    }

    void action(gtk.MenuItem.MenuItem action) {
        //do nothing
    }
}

class ContextDependentItem : MainMenuItem {
    ContextType type;
    gtk.MenuItem.MenuItem item;

    this(gtk.Builder.Builder builder, string name, ContextType type) {
        this.type = type;
        item = cast(gtk.MenuItem.MenuItem)builder.getObject(name);
    }

    void update(ContentNode current_node) {
        if (current_node.context == type) {
            item.setVisible(1);
        } else {
            item.setVisible(0);
        }
    }
}

class GenericMenuItem : MainMenuItem {
    gtk.MenuItem.MenuItem item;

    this(gtk.Builder.Builder builder, string name) {
        item = cast(gtk.MenuItem.MenuItem)builder.getObject(name);
        item.addOnActivate(&action);
    }

    void update(ContentNode current_node) {
        //do nothing
    }

    void action(gtk.MenuItem.MenuItem action) {
        //do nothing
    }
}

class GenericCheckMenuItem : MainMenuItem {
    gtk.CheckMenuItem.CheckMenuItem item;

    this(gtk.Builder.Builder builder, string name) {
        item = cast(gtk.CheckMenuItem.CheckMenuItem)builder.getObject(name);
        item.addOnToggled(&action);
    }

    void update(ContentNode current_node) {
        //do nothing
    }

    void action(gtk.CheckMenuItem.CheckMenuItem item) {
        //do nothing
    }
}

class GenericRadioMenuItem(T) : MainMenuItem {
    T[gtk.RadioMenuItem.RadioMenuItem] items;

    this(gtk.Builder.Builder builder, T[string] names) {
        foreach (name, value; names) {
            auto item = cast(gtk.RadioMenuItem.RadioMenuItem)builder.getObject(name);
            items[item] = value;
            item.addOnActivate(&action);
        }
    }

    void update(ContentNode current_node) {
        //do nothing
    }

    void action(gtk.MenuItem.MenuItem item) {
        //do nothing
    }
}


// Content Menu

class ContentMenuItem : GenericMenuItem {
    this(gtk.Builder.Builder builder, string name) {
        super(builder, name);
    }

    override void update(ContentNode current_node) {
        if (current_node.type == ContentNodeType.ROOT)
            item.setSensitive(0);
        else
            item.setSensitive(1);
    }
}

class InsertMathItem : GenericMenuItem {
    this(gtk.Builder.Builder builder, string name) {
        super(builder, name);
    }

    override void update(ContentNode current_node) {
        if (current_node.acceptsNodeType(ContentNodeType.MATH)) {
            item.setSensitive(1);
            item.setLabel("_Math");
        } else if (current_node.acceptsNodeType(ContentNodeType.MATH_INLINE)) {
            item.setSensitive(1);
            item.setLabel("_Math (Inline Only)");
        } else {
            item.setSensitive(0);
        }
    }

    override void action(gtk.MenuItem.MenuItem item) {
        auto node = app.content.insertNodeAtCursor(ContentNodeType.MATH, app.auto_select);
        if (node is null) {
            node = app.content.insertNodeAtCursor(ContentNodeType.MATH_INLINE, app.auto_select);
        }
        if (app.auto_select) {
            app.updateContext();
        }
    }
}

class InsertListItem : TypeDependentItem {
    this(gtk.Builder.Builder builder, string name) {
        super(builder, name, ContentNodeType.LIST);
    }

    override void action(gtk.MenuItem.MenuItem item) {
        auto node = app.content.insertNodeAtCursor(ContentNodeType.LIST, app.auto_select);
        if (app.auto_select) {
            app.updateContext();
        }
    }
}

class InsertTableItem : TypeDependentItem {
    this(gtk.Builder.Builder builder, string name) {
        super(builder, name, ContentNodeType.TABLE);
    }

    override void action(gtk.MenuItem.MenuItem item) {
        if (app.table_dialog.runSize()) {
            auto node = app.content.insertNodeAtCursor(ContentNodeType.TABLE, app.auto_select);
//            node.table_width = table_dialog.getWidth();
//            node.table_height = table_dialog.getHeight();
            node.populateTable(app.table_dialog.getWidth(), app.table_dialog.getHeight());
            app.content.updateModel(node, false);
            if (app.auto_select) {
                app.updateContext();
            }
        }
    }
}

class InsertColumnsItem : TypeDependentItem {
    this(gtk.Builder.Builder builder, string name) {
        super(builder, name, ContentNodeType.COLUMN_GROUP);
    }

    override void action(gtk.MenuItem.MenuItem item) {
        auto node = app.content.insertNodeAtCursor(ContentNodeType.COLUMN_GROUP, app.auto_select);
        if (node is null)
            return;

        foreach (i; 0 .. 2) {
            auto col = app.content.insertNodeAtCursor(node, ContentNodeType.COLUMN);
            col.column_size = 50;
            app.content.updateDisplayName(col);
        }

        if (app.auto_select) {
            app.updateContext();
        }
    }
}

class InsertGraphicItem : TypeDependentItem {
    this(gtk.Builder.Builder builder, string name) {
        super(builder, name, ContentNodeType.GRAPHIC);
    }

    override void action(gtk.MenuItem.MenuItem item) {
        auto node = app.content.insertNodeAtCursor(ContentNodeType.GRAPHIC, app.auto_select);
        if (node is null)
            return;

        auto width = app.content.insertNodeAtCursor(node, ContentNodeType.PROPERTY, "Width", "width");
        app.content.insertTextAtCursor(width, "\\textwidth");

        auto path = app.content.insertNodeAtCursor(node, ContentNodeType.PROPERTY, "File", "file");

        if (app.auto_select) {
            app.viewCurrent(); // ???
            app.updateContext();
        }
    }
}

class InsertListingItem : TypeDependentItem {
    this(gtk.Builder.Builder builder, string name) {
        super(builder, name, ContentNodeType.LISTING);
    }

    override void action(gtk.MenuItem.MenuItem item) {
        auto node = app.content.insertNodeAtCursor(ContentNodeType.LISTING, app.auto_select);

        if (app.auto_select) {
            app.editor.setBuffer(app.content.current_node.buffer);
            app.updateContext();
        }
    }
}

class InsertTikzItem : TypeDependentItem {
    this(gtk.Builder.Builder builder, string name) {
        super(builder, name, ContentNodeType.TIKZ_PICTURE);
    }

    override void action(gtk.MenuItem.MenuItem item) {
        auto node = app.content.insertNodeAtCursor(ContentNodeType.TIKZ_PICTURE, app.auto_select);
        if (node is null)
            return;

        app.content.insertTextAtCursor(node, "[x=1.0cm,y=1.0cm]");

        if (app.auto_select) {
            app.viewCurrent();
            app.updateContext();
        }
    }
}

class InsertAlignedItem : TypeDependentItem {
    this(gtk.Builder.Builder builder, string name) {
        super(builder, name, ContentNodeType.MATH_TABLE);
    }

    override void action(gtk.MenuItem.MenuItem item) {
        if (app.table_dialog.runSize()) {
            auto node = app.content.insertNodeAtCursor(ContentNodeType.MATH_TABLE, app.auto_select, "Aligned Math", "aligned");
            if (node is null)
                return;

            node.math_environment = "align*";
            node.populateTableGroup(app.table_dialog.getWidth(), app.table_dialog.getHeight(),
                                    ContentNodeType.MATH_TABLE_ROW, ContentNodeType.MATH_TABLE_CELL);
            app.content.updateModel(node, false);
            if (app.auto_select) {
                app.updateContext();
            }
        }
    }
}

class AnimateOverprintItem : TypeDependentItem {
    this(gtk.Builder.Builder builder, string name) {
        super(builder, name, ContentNodeType.OVERPRINT);
    }

    override void action(gtk.MenuItem.MenuItem item) {
        auto node = app.content.insertNodeAtCursor(ContentNodeType.OVERPRINT, app.auto_select);

        if (node is null)
            return;

        foreach (i; 0 .. 2) {
            auto view = app.content.insertNodeAtCursor(node, ContentNodeType.ONSLIDE);
        }

        if (app.auto_select) {
            app.viewCurrent(); // ???
            app.updateContext();
        }
    }
}

// Properties

class PropertiesMathInlineItem : GenericCheckMenuItem {
    this(gtk.Builder.Builder builder, string name) {
        super(builder, name);
    }

    override void update(ContentNode current_node) {
        if (current_node.context != ContextType.MATH)
            return;
        
        if (current_node.type == ContentNodeType.MATH_INLINE) {
            item.setActive(1);
            if (current_node.parent.acceptsNodeType(ContentNodeType.MATH))
                item.setSensitive(1);
            else
                item.setSensitive(0);
        } else {
            item.setActive(0);
            if (current_node.parent.acceptsNodeType(ContentNodeType.MATH_INLINE))
                item.setSensitive(1);
            else
                item.setSensitive(0);
        }
    }

    override void action(gtk.CheckMenuItem.CheckMenuItem item) {
        if (app.content.current_node.type == ContentNodeType.MATH) {
            if (item.getActive() == 1) {
                if (app.content.current_node.parent.acceptsNodeType(ContentNodeType.MATH_INLINE)) {
                    app.content.current_node.type = ContentNodeType.MATH_INLINE;
                    app.content.updateDisplayName(app.content.current_node);
                } else {
                    item.setActive(0);
                }
            }
        } else {
            if (item.getActive() == 0) {
                if (app.content.current_node.parent.acceptsNodeType(ContentNodeType.MATH)) {
                    app.content.current_node.type = ContentNodeType.MATH;
                    app.content.updateDisplayName(app.content.current_node);
                } else {
                    item.setActive(1);
                }
            }
        }
    }
}

class PropertiesListTypeItem : GenericRadioMenuItem!string {
    this(gtk.Builder.Builder builder, string[string] names) {
        super(builder, names);
    }

    override void update(ContentNode current_node) {
        if (current_node.context != ContextType.LIST)
            return;

        foreach (item, type; items) {
            if (current_node.list_type == type) {
                item.setActive(1);
                return;
            }
        }
    }

    override void action(gtk.MenuItem.MenuItem item) {
        if (app.content.current_node.context != ContextType.LIST)
            return;
        
        app.content.current_node.list_type = items[cast(gtk.RadioMenuItem.RadioMenuItem)item];
    }
}

class PropertiesTableSizeItem : GenericMenuItem {
    this(gtk.Builder.Builder builder, string name) {
        super(builder, name);
    }

    override void update(ContentNode current_node) {
        if (current_node.context != ContextType.TABLE)
            return;

        if (current_node.type == ContentNodeType.TABLE ||
            current_node.type == ContentNodeType.TABLE_GROUP) {
            item.setSensitive(1);
        } else {
            item.setSensitive(0);
        }
    }

    override void action(gtk.MenuItem.MenuItem item) {
        if (app.content.current_node.context != ContextType.TABLE)
            return;

        if (app.table_dialog.runSize()) {
            if (app.content.current_node.type == ContentNodeType.TABLE) {
                app.content.current_node.resizeTable(app.table_dialog.getWidth(), app.table_dialog.getHeight());
                app.content.updateDisplayName(app.content.current_node);
            } else if (app.content.current_node.type == ContentNodeType.TABLE_GROUP) {
                app.content.current_node.resizeTableGroup(app.table_dialog.getWidth(), app.table_dialog.getHeight(),
                                                          ContentNodeType.TABLE_ROW, ContentNodeType.TABLE_CELL);
                app.content.updateModel(app.content.current_node);
            }
            app.updateContext();
        }
    }
}

class PropertiesTableGroupItem : GenericCheckMenuItem {
    this(gtk.Builder.Builder builder, string name) {
        super(builder, name);
    }

    override void update(ContentNode current_node) {
        if (current_node.context != ContextType.TABLE)
            return;

        if (current_node.type == ContentNodeType.TABLE_GROUP) {
            item.setActive(1);
            item.setSensitive(1);
        } else if (current_node.type == ContentNodeType.TABLE_CELL) {
            item.setActive(0);
            item.setSensitive(1);
        } else {
            item.setActive(0);
            item.setSensitive(0);
        }
    }

    override void action(gtk.CheckMenuItem.CheckMenuItem item) {
        if (item.getActive()) {
            //group
            if (app.content.current_node.type != ContentNodeType.TABLE_CELL)
                return;

            if (app.table_dialog.runSize()) {
                app.content.current_node.type = ContentNodeType.TABLE_GROUP;
                app.content.current_node.children = [];
                app.content.current_node.clearBuffer();
                app.content.current_node.populateTableGroup(app.table_dialog.getWidth(), app.table_dialog.getHeight(),
                                                            ContentNodeType.TABLE_ROW, ContentNodeType.TABLE_CELL);

                app.content.updateModel(app.content.current_node);
            }
        } else {
            //cell
            if (app.content.current_node.type != ContentNodeType.TABLE_GROUP)
                return;

            app.content.current_node.type = ContentNodeType.TABLE_CELL;
            app.content.current_node.children = [];
            app.content.current_node.clearBuffer();

            app.content.updateModel(app.content.current_node);
        }
        app.updateContext();
    }
}

class PropertiesTableBorderItem : GenericMenuItem {
    this(gtk.Builder.Builder builder, string name) {
        super(builder, name);
    }

    override void action(gtk.MenuItem.MenuItem item) {
        if (app.content.current_node.context != ContextType.TABLE)
            return;

        auto table = app.content.current_node.findParent(ContentNodeType.TABLE);

        if (table.invalid)
            return;

        app.table_dialog.table = table.flattenTable();

        app.table_dialog.runBorder();
    }
}

class PropertiesColumnSizeItem : GenericMenuItem {
    this(gtk.Builder.Builder builder, string name) {
        super(builder, name);
    }

    override void action(gtk.MenuItem.MenuItem item) {
        if (app.content.current_node.context != ContextType.COLUMN)
            return;

        auto column_group = app.content.current_node.findParent(ContentNodeType.COLUMN_GROUP);

        app.column_dialog.runSize(column_group);
    }
}

class PropertiesColumnAddItem : GenericMenuItem {
    this(gtk.Builder.Builder builder, string name) {
        super(builder, name);
    }

    override void action(gtk.MenuItem.MenuItem item) {
        if (app.content.current_node.context != ContextType.COLUMN)
            return;

        auto column_group = app.content.current_node.findParent(ContentNodeType.COLUMN_GROUP);

        auto col = app.content.insertNodeAtCursor(column_group, ContentNodeType.COLUMN);

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
                app.content.updateDisplayName(child);
            }
        }

        if (app.auto_select) {
            app.content.current_node = col;
            app.updateContext();
        }
    }
}

class PropertiesColumnRemoveItem : GenericMenuItem {
    this(gtk.Builder.Builder builder, string name) {
        super(builder, name);
    }

    override void update(ContentNode current_node) {
        if (current_node.context != ContextType.COLUMN)
            return;

        auto column_group = current_node.findParent(ContentNodeType.COLUMN_GROUP);

        if (column_group.children.length > 1) {
            item.setSensitive(1);
        } else {
            item.setSensitive(0);
        }
    }

    override void action(gtk.MenuItem.MenuItem item) {
        if (app.content.current_node.context != ContextType.COLUMN)
            return;

        auto column_group = app.content.current_node.findParent(ContentNodeType.COLUMN_GROUP);

        if (column_group.children.length > 1) {
            if (app.content.current_node.type == ContentNodeType.COLUMN) {
                column_group.removeChild(app.content.current_node);
            } else {
                column_group.removeChild(column_group.children[$-1]);
            }
            app.content.updateModel(column_group);
        }
    }
}

class PropertiesColumnAlignItem : GenericCheckMenuItem {
    this(gtk.Builder.Builder builder, string name) {
        super(builder, name);
    }

    override void update(ContentNode current_node) {
        if (current_node.context != ContextType.COLUMN)
            return;

        item.setActive(current_node.top_aligned ? 1 : 0);
    }

    override void action(gtk.CheckMenuItem.CheckMenuItem item) {
        if (app.content.current_node.context != ContextType.COLUMN)
            return;

        app.content.current_node.top_aligned = item.getActive() == 1;
    }
}

class PropertiesListingStyleItem : GenericMenuItem {
    this(gtk.Builder.Builder builder, string name) {
        super(builder, name);
    }

    override void action(gtk.MenuItem.MenuItem item) {
        if (app.content.current_node.context != ContextType.LISTING)
            return;

        app.listing_dialog.runEditor();

        app.content.current_node.listing_style = app.listing_dialog.active_style;
        app.content.updateDisplayName(app.content.current_node);
    }
}

class PropertiesTikzAddElement : GenericMenuItem {
    this(gtk.Builder.Builder builder, string name) {
        super(builder, name);
    }

    override void action(gtk.MenuItem.MenuItem item) {
        if (app.content.current_node.context != ContextType.TIKZ)
            return;

        auto tikz = app.content.current_node.findParent(ContentNodeType.TIKZ_PICTURE);

        auto element = app.content.insertNodeAtCursor(tikz, ContentNodeType.TIKZ_ELEMENT);

        if (app.auto_select) {
            app.content.current_node = element;
            app.viewCurrent();
            app.updateContext();
        }
    }
}


