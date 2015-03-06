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

import ContentNode, Present;

class Content {
    ulong mark_id;

    gtk.TreeStore.TreeStore model;
    gtk.TextTagTable.TextTagTable tag_table;

    ContentNode root_node;
    ContentNode current_node;

    ContentNode[ulong] node_by_id;

    this(gtk.Builder.Builder builder) {
//        this.view = view;
        model = new gtk.TreeStore.TreeStore([gtkc.gobjecttypes.GType.STRING, gtkc.gobjecttypes.GType.INT]);
        tag_table = cast(gtk.TextTagTable.TextTagTable)builder.getObject("editor-tag-table");
        writeln(tag_table.lookup("child-tag"));
        writeln(tag_table.lookup("onslide-highlight-tag"));

//        root_node = insertNodeAtCursor(ContentNodeType.ROOT);
        root_node = new ContentNode(ContentNodeType.ROOT, mark_id++, tag_table);
        current_node = root_node;

//        selection_buffer.addOnInsertText(&selection_insert_action);
    }

    /+
    ContentNode insertNodeAtCursor(ContentNodeType type) {
        auto node = new ContentNode(type, mark_id++);
        /*
        if (current_node !is null) {
            auto current_start_iter = master_buffer.getIterAtMark(current_node.start_mark);
            auto selection_insert_iter = selection_b
        }
        */
        auto selection_insert_iter = new gtk.TextIter.TextIter();
        auto mark = selection_buffer.getMark("insert");
        selection_buffer.getIterAtMark(selection_insert_iter, mark);
        auto start_iter = new gtk.TextIter.TextIter();

        if (current_node is null) {
            master_buffer.getStartIter(start_iter);
        } else {
            master_buffer.getIterAtMark(start_iter, current_node.start_mark);
        }

        start_iter.forwardChars(selection_insert_iter.getOffset());

        master_buffer.addMark(node.start_mark, start_iter);
        master_buffer.addMark(node.end_mark, start_iter);

        selection_buffer.addMark(node.s_start_mark, selection_insert_iter);
        selection_buffer.addMark(node.s_end_mark, selection_insert_iter);

        if (root_node is null) {
            root_node = node;
        } else {
            root_node.addChild(master_buffer, node, model, "");
        }
        return node;
    }
    +/
    /+
    void merge_current() {
        if (current_node !is null) {
            current_node.merge_into_buffer(selection_buffer, master_buffer);
        }
    }
    +/

    auto createNode(ContentNodeType type) {
        auto node = new ContentNode(type, mark_id++, tag_table);
        node_by_id[node.id] = node;
        return node;
    }

    void insertTextAtCursor(string text) {
        if (current_node is null || current_node.type == ContentNodeType.ROOT) {
            writeln("oops!");
        } else {
            auto iter = new gtk.TextIter.TextIter();
            current_node.buffer.getIterAtMark(iter, current_node.buffer.getInsert());
            current_node.buffer.insert(iter, text);
        }
    }

    ContentNode insertNodeAtCursor(ContentNodeType type, bool select, string custom_display_name = "", string custom_inline_name = "") {

        if (!current_node.acceptsNodeType(type))
            return null;

        auto node = new ContentNode(type, mark_id++, tag_table, custom_display_name, custom_inline_name);
        node_by_id[node.id] = node;

        auto old_node = current_node;

        int n;

        if (current_node is null) {
            //this shouldn't happen
            writeln("oops!");
            /*
            root_node.children ~= node;
            current_node = node;
            node.path = "0";
            n = 0;
            */
        } else {
            auto iter = new gtk.TextIter.TextIter();
            current_node.buffer.getIterAtMark(iter, current_node.buffer.getInsert());
            n = current_node.addChild(node, iter);
        }

        addToModel(node, old_node, n, select);

        return node;
    }

    ContentNode insertNodeAtCursor(ContentNode parent, ContentNodeType type, string custom_display_name = "", string custom_inline_name = "") {
        if (!parent.acceptsNodeType(type))
            return null;

        auto node = new ContentNode(type, mark_id++, tag_table, custom_display_name, custom_inline_name);
        node_by_id[node.id] = node;

        auto iter = new gtk.TextIter.TextIter();
        parent.buffer.getIterAtMark(iter, parent.buffer.getInsert());
        int n = parent.addChild(node, iter);

        addToModel(node, parent, n, false);

        return node;
    }

    ContentNode insertNodeAtToplevel(ContentNodeType type, bool select) {
        auto node = new ContentNode(type, mark_id++, tag_table);
        node_by_id[node.id] = node;

//        node.path = to!string(root_node.children.length);

//        root_node.children_type_count[node.inline_name] = root_node.children_type_count.get(node.inline_name, 0) + 1;
//        node.cid = root_node.children_type_count[node.inline_name];
        root_node.setCID(node);

        addToModel(node, null, cast(int)root_node.children.length, select);
        
        root_node.children ~= node;

        return node;
    }

    bool moveNodeByID(ulong id, int[] path, int position) {
        auto source = node_by_id[id];
        writeln("source = ", source);

        auto dest = root_node;
        foreach (ind; path) {
            dest = dest.children[ind];
        }

        writeln("dest = ", dest);

        if (dest == source) {
            writeln("cannot move because dest == source");
            return false;
        }

        if (!dest.acceptsNodeType(source.type)) {
            writeln("dest does not accept source");
            return false;
        }

        //remove
        ContentNode parent;
        auto source_path = source.path;

        if (source_path.getDepth() > 1) {
            auto dest_path = dest.path;
            if (source_path.isAncestor(dest_path)) {
                writeln("dest cannot be child of source");
                return false;
            }

            source_path.up();
            parent = getNodeFromPath(source_path);
            writeln("parent = ",parent);
            auto removed = parent.removeChild(source);

            if (!removed) {
                writeln("source cannot be removed from parent");
                return false;
            }

            auto iter = new gtk.TextIter.TextIter();
            dest.buffer.getEndIter(iter);
            dest.addChild(source, iter);
            
            removeFromModel(source);

            addToModel(source, dest, position, false);
            restoreChildren(source);

            /*
            auto new_iter = new gtk.TreeIter.TreeIter();
            model.getIter(source_iter, source_path);
            auto dest_iter = new gtk.TreeIter.TreeIter();
            auto dest_path = dest.path;
            auto parent_iter = new gtk.TreeIter.TreeIter();
            model.getIter(parent_iter, parent.path);

            if (dest.children.length == 0) {

            } else {
                if (position == -1 || position >= dest.children.length) {
                    //after last child
                    dest_path.appendIndex(dest.children.length - 1);
                    model.getIter(dest_iter, dest_path);
                    model.insertAfter(source_iter, parent_iter, dest_iter);
                } else {
                    //before position
                    dest_path.appendIndex(position);
                    model.getIter(dest_iter, dest_path);
                    model.moveBefore(source_iter, parent_iter, dest_iter);
                }
            }
            */
            current_node = dest;
        } else {
            parent = root_node;
            removeFromModel(source);
            addToModel(source, null, position, false);
            restoreChildren(source);

            foreach (i, child; parent.children) {
                if (child == source) {
                    if ((i+1) == parent.children.length) {
                        parent.children = parent.children[0 .. $-1];
                    } else {
                        parent.children = parent.children[0 .. i] ~ parent.children[i+1 .. $];
                    }
                    break;
                }
            }
            if (position == -1 || position >= dest.children.length) {
                dest.children ~= source;
            } else {
                dest.children = dest.children[0 .. position] ~ source ~ dest.children[position .. $];
            }
            current_node = source;
        }

        
        return true;
    }

    void restoreChildren(ContentNode node) {
        foreach (int i, child; node.children) {
            addToModel(child, node, i, false);
            restoreChildren(child);
        }
    }

    void activate(gtk.TreePath.TreePath path) {
        current_node = getNodeFromPath(path);
    }

    ContentNode getNodeFromPath(gtk.TreePath.TreePath path) {
        auto indices = path.getIndices();

        auto node = root_node;

        foreach (ind; indices) {
            node = node.children[ind];
        }

        return node;
    }

    void addToModel(ContentNode node, ContentNode parent, int position, bool select) {
        auto new_iter = new gtk.TreeIter.TreeIter();
        if (parent is null) {
            model.insert(new_iter, null, position);
        } else {
            auto current_iter = new gtk.TreeIter.TreeIter();
            model.getIter(current_iter, parent.path);
            model.insert(new_iter, current_iter, position);
        }

        model.setValue(new_iter, 0, node.display_name);
        model.setValue(new_iter, 1, node.cid);

        node.reference = new gtk.TreeRowReference.TreeRowReference(model, model.getPath(new_iter));

        if (select) {
//            string p = path.length == 0 ? to!string(position) : path ~ ":" ~ to!string(position);
            auto treepath = node.path;
            app.tree_view.expandToPath(treepath);
            app.tree_view.setCursor(treepath, app.name_column, 0);
//            app.content.current_node = node;
            current_node = node;
//            app.context_window.setContext(current_node.context);
        }
    }

    void removeFromModel(ContentNode node) {
        auto iter = new gtk.TreeIter.TreeIter();
        model.getIter(iter, node.path);
        model.remove(iter);
    }

    void selectInModel(ContentNode node) {
        auto treepath = node.path;
        app.tree_view.expandToPath(treepath);
        app.tree_view.setCursor(treepath, app.name_column, 0);
    }

    void updateModel(ContentNode node, bool clear = true) {
        //remove all children
        if (clear) {
            auto iter = new gtk.TreeIter.TreeIter();
            auto child_iter = new gtk.TreeIter.TreeIter();
            model.getIter(iter, node.path);

            while (model.iterChildren(child_iter, iter) == 1) {
                model.remove(child_iter);
            }
        }

        foreach (int i, child; node.children) {
            addToModel(child, node, i, false);
            updateModel(child, false);
        }

        updateDisplayName(node);
    }

    void updateView(gsv.SourceView.SourceView view) {
        view.setBuffer(current_node.buffer);
        /*
        foreach (child; current_node.children) {
            if (child.orphan)
                continue;
            writeln("placing "~to!string(child.id));
            child.placed = true;
            view.addChildAtAnchor(child.inline_widget, child.anchor);
            child.inline_widget.show();
        }
        */
    }

    void checkOrphans() {
        /*
        foreach (child; current_node.children) {
            if (!child.placed || child.orphan)
                continue;
            if (child.anchor.getDeleted() == 1) {
                child.orphan = true;
                auto iter = new gtk.TreeIter.TreeIter();
                model.getIterFromString(iter, child.path);
                model.setValue(iter, 0, child.display_name);
            }
        }
        */
    }

    void setOrphaned(ContentNode node, bool orphaned) {
        if (node.orphan == orphaned)
            return;

        node.orphan = orphaned;

        updateDisplayName(node);
    }

    void updateDisplayName(ContentNode node, bool recursive = false) {
        auto iter = new gtk.TreeIter.TreeIter();
        model.getIter(iter, node.path);
        model.setValue(iter, 0, node.display_name);
        if (recursive) {
            foreach (child; node.children) {
                updateDisplayName(child, true);
            }
        }
    }

    void restoreOrphan(gsv.SourceView.SourceView view) {
        /*
        foreach (child; current_node.children) {
            if (child.orphan) {
                child.orphan = false;
                child.placed = true;
                auto iter = new gtk.TextIter.TextIter();
//                current_node.buffer.getIterAtMark(iter, current_node.buffer.getMark("s"~to!string(child.id)));
                auto mark = current_node.buffer.getInsert();
                current_node.buffer.getIterAtMark(iter, mark);

                child.anchor.unref();
                child.anchor = current_node.buffer.createChildAnchor(iter);
                view.addChildAtAnchor(child.inline_widget, child.anchor);
                child.inline_widget.show();
                auto tree_iter = new gtk.TreeIter.TreeIter();
                model.getIterFromString(tree_iter, child.path);
                model.setValue(tree_iter, 0, child.display_name);
                return;
            }
        }
        */
    }


    /+
    void row_activated_action(gtk.TreePath.TreePath path, gtk.TreeViewColumn.TreeViewColumn column, gtk.TreeView.TreeView view) {
        //get the child
        int[] indices = path.getIndices();
//        writeln(indices);

        auto node = root_node;

        foreach (ind; indices) {
//            writeln(node.children);
            node = node.children[ind];
        }

//        writeln(node.id);

        /*
        auto start_iter = new gtk.TextIter.TextIter();
        auto end_iter = new gtk.TextIter.TextIter();
        auto master_start_iter = new gtk.TextIter.TextIter();
        auto master_end_iter = new gtk.TextIter.TextIter();

        master_buffer.getIterAtMark(master_start_iter, node.start_mark);
        master_buffer.getIterAtMark(master_end_iter, node.end_mark);

        selection_buffer.getStartIter(start_iter);
        selection_buffer.getEndIter(end_iter);

        selection_buffer.delet(start_iter, end_iter);
        
        node.load_to_buffer(master_buffer, selection_buffer);

        */

        
        current_node = node;
    }
    +/
/*
    void selection_insert_action(gtk.TextIter.TextIter iter, string text, int len, gtk.TextBuffer.TextBuffer buffer) {
        if (ignore_insert)
            return;
        auto master_iter = new gtk.TextIter.TextIter();
        master_buffer.getIterAtMark(master_iter, current_node.start_mark);
        master_iter.forwardChars(iter.getOffset());
        master_buffer.insert(master_iter, text);
        writeln("inserted "~text);
    }
*/
    void print_tree() {
        root_node.print();
    }

    bool descend() {
        auto insert_iter = new gtk.TextIter.TextIter();
        auto mark_iter = new gtk.TextIter.TextIter();
        current_node.buffer.getIterAtMark(insert_iter, current_node.buffer.getInsert());

        foreach (child; current_node.children) {
            if (child.orphan)
                continue;

            current_node.buffer.getIterAtMark(mark_iter, current_node.buffer.getMark("s"~to!string(child.id)));
            if (mark_iter.compare(insert_iter) <= 0) {
                current_node.buffer.getIterAtMark(mark_iter, current_node.buffer.getMark("e"~to!string(child.id)));
                if (mark_iter.compare(insert_iter) >= 0) {
                    current_node = child;
                    selectInModel(child);
                    app.editor.setBuffer(child.buffer);
//                    app.context_window.setContext(current_node.context);
                    return true;
                }
            }
        }
        return false;
    }

    bool ascend() {
        if (current_node.parent is null)
            return false;

        current_node = current_node.parent;
        selectInModel(current_node);
        app.editor.setBuffer(current_node.buffer);
//        app.context_window.setContext(current_node.context);

        return true;
    }

    void insertCompletion(string completion) {
        string[] split;

        long ind;
        while ((ind = indexOf(completion, ',')) != -1) {
            split ~= completion[0 .. ind];
            completion = completion[ind + 1 .. $];
        }
        split ~= completion;
        writeln(split);

        try {
            for (int i = 0; i < split.length; ) {
                if (split[i] == "g") {
                    auto node = insertNodeAtCursor(ContentNodeType.MATH_GROUP, true, split[i+1], split[i+2]);
                    node.latex = split[i+3];
                    i += 4;
                } else if (split[i] == "g*") {
                    auto node = insertNodeAtCursor(ContentNodeType.MATH_GROUP, false, split[i+1], split[i+2]);
                    node.latex = split[i+3];
                    i += 4;
                } else if (split[i] == "f") {
                    auto node = insertNodeAtCursor(ContentNodeType.STATIC, true, split[i+1], split[i+2]);
                    node.latex = split[i+3];
                    i += 4;
                } else if (split[i] == "f*") {
                    auto node = insertNodeAtCursor(ContentNodeType.STATIC, false, split[i+1], split[i+2]);
                    node.latex = split[i+3];
                    i += 4;
                } else if (split[i] == "t") {
                    insertTextAtCursor(split[i+1]);
                    i += 2;
                } else {
                    writeln("warning: unknown completion function ",split[i]);
                    i++;
                }
            }
        } catch (RangeError e) {
             writeln("error inserting completion "~completion);
        }
    }

    void outputPreamble(File f) {
        f.writeln("\\documentclass[t]{beamer}");
        f.writeln("\\usefonttheme[onlymath]{serif}");
        f.writeln("\\setbeamertemplate{navigation symbols}{}");
        f.writeln("\\usepackage[at]{easylist}");
        f.writeln("\\usepackage{multirow}");
        f.writeln("\\usepackage{graphicx}");
        f.writeln("\\usepackage{listings}");
    }

    void outputPreviewPreamble(File f) {
        outputPreamble(f);
        f.writeln("\\usepackage[pdftex,active,tightpage]{preview}");
    }

    void exportLatex(File f, ContentNode root) {
        if (root is null) {
            outputPreamble(f);
            f.writeln("\\begin{document}");
            foreach (child; root_node.children) {
                child.outputLatex(f, true);
            }
            f.writeln("\\end{document}");
        } else if (root.type == ContentNodeType.FRAME) {
            outputPreamble(f);
            f.writeln("\\begin{document}");
            root.outputLatex(f, true);
            f.writeln("\\end{document}");
        } else {
            outputPreviewPreamble(f);
            f.writeln("\\begin{document}");
            f.writeln("\\begin{preview}");
            root.outputLatex(f, true);
            f.writeln("\\end{preview}");
            f.writeln("\\end{document}");
        }
    }
}

