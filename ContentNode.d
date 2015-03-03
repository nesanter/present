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
static import gtk.TreeRowReference;

import Content, Present;

enum ContentNodeType {
    ROOT,
    FRAME,
    MATH,
    MATH_INLINE,
    MATH_GROUP,
    STATIC,
    DUMMY
}

class ContentNode {
    ContentNode parent;
    ContentNode[] children;

//    int master_start_index, master_end_index;
    gsv.SourceBuffer.SourceBuffer buffer;
    gtk.TextChildAnchor.TextChildAnchor anchor;

    string custom_display_name,
           custom_inline_name;

    bool editable, inside_math;

    string latex;

    ContentNodeType type;
    ulong id;
    int cid;
    bool orphan = false;
    bool placed = false;

//    int[string] children_type_count;

//    string path;
    gtk.TreeRowReference.TreeRowReference reference;

    gtk.Label.Label inline_widget;

    enum accepted_types = [
        ContentNodeType.ROOT : [ ContentNodeType.FRAME ],
        ContentNodeType.FRAME : [ ContentNodeType.MATH, ContentNodeType.MATH_INLINE ],
        ContentNodeType.MATH : [ ContentNodeType.MATH_GROUP, ContentNodeType.STATIC ],
        ContentNodeType.MATH_GROUP : [ ContentNodeType.MATH_GROUP, ContentNodeType.STATIC ],
        ContentNodeType.STATIC : [ ],
        ContentNodeType.DUMMY : [ ]
    ];

    this(ContentNodeType type, ulong id, gtk.TextTagTable.TextTagTable tag_table, string custom_display_name = "", string custom_inline_name = "") {
        this.type = type;
        this.id = id;
        this.cid = -1;
        this.custom_display_name = custom_display_name;
        this.custom_inline_name = custom_inline_name;

        if (type == ContentNodeType.ROOT || type == ContentNodeType.STATIC) {
            editable = false;
        } else {
            editable = true;
        }

//        inline_widget = new gtk.Label.Label(inline_name, false);
//        inline_widget.setUseMarkup(1);

        /*
        start_mark = new gtk.TextMark.TextMark("s"~to!string(id), 1);
        start_mark.setVisible(1);
        end_mark = new gtk.TextMark.TextMark("e"~to!string(id), 0);
        end_mark.setVisible(1);
        s_start_mark = new gtk.TextMark.TextMark("ss"~to!string(id), 1);
        s_end_mark = new gtk.TextMark.TextMark("se"~to!string(id), 1);
        s_start_mark.setVisible(1);
        s_end_mark.setVisible(1);

        */
        /*
        auto insert_mark = buffer.getMark("insert");
        auto iter = new gtk.TextIter.TextIter();
        buffer.getIterAtMark(iter, insert_mark);
        buffer.addMark(start_mark, iter);
        buffer.getIterAtMark(iter, start_mark);
        buffer.addMark(end_mark, iter);
        */

        buffer = new gsv.SourceBuffer.SourceBuffer(tag_table);
        buffer.addOnChanged(&buffer_changed_action);
//        buffer.addOnMarkDeleted(&mark_deleted_action);
    }

    @property gtk.TreePath.TreePath path() {
        return reference.getPath();
    }

    @property ulong orphan_count() {
        ulong n = 0;
        foreach (child; children)
            if (child.orphan)
                n++;

        return n;
    }

    string latex_template(bool top) {
        if (latex.length > 0) {
            return latex;
        } else {
            final switch (type) {
                case ContentNodeType.ROOT:
                case ContentNodeType.DUMMY:
                    return "";
                case ContentNodeType.FRAME:
                    return "\\begin{frame}#0;\\end{frame}\n";
                case ContentNodeType.MATH:
                    if (top)
                        return "\\(#0;\\)";
                    else
                        return "\\[#0;\\]";
                case ContentNodeType.MATH_INLINE:
                    return "\\(#0;\\)";
                case ContentNodeType.MATH_GROUP:
                    return "#0;";
                case ContentNodeType.STATIC:
                    return "#0;";
            }
        }
    }

    @property string display_name() {
        string s;
        if (custom_display_name.length > 0) {
            s = custom_display_name;
        } else {
            final switch (type) {
                case ContentNodeType.ROOT:
                    s = "root";
                    break;
                case ContentNodeType.FRAME:
                    s = "Frame";
                    break;
                case ContentNodeType.MATH:
                    s = "Math";
                    break;
                case ContentNodeType.MATH_GROUP:
                    s = "Group";
                    break;
                case ContentNodeType.MATH_INLINE:
                    s = "Math (Inline)";
                    break;
                case ContentNodeType.STATIC:
                    s = "Static";
                    break;
                case ContentNodeType.DUMMY:
                    s = "dummy"~to!string(id);
                    break;
            }
        }

        if (orphan)
            s ~= "*";

        if (!editable) {
            s = "<i>"~s~"</i>";
        }

        return s;
    }
    
    @property string short_name() {
        string s;
        if (custom_inline_name.length > 0) {
            s = custom_inline_name;
        } else {
            final switch (type) {
                case ContentNodeType.ROOT:
                    s = "root";
                    break;
                case ContentNodeType.FRAME:
                    s = "frame";
                    break;
                case ContentNodeType.MATH:
                    s = "math";
                    break;
                case ContentNodeType.MATH_INLINE:
                    s = "math";
                    break;
                case ContentNodeType.DUMMY:
                    s = "dummy";
                    break;
                case ContentNodeType.MATH_GROUP:
                    s = "group";
                    break;
                case ContentNodeType.STATIC:
                    s = "static";
                    break;
            }
        }
        return s;
    }

    @property string inline_name() {
//        return "<span font_family=\"monospace\" color=\"gray\">"~display_name~"</span>";
        return "<"~short_name~":"~to!string(cid)~">";
    }

    @property ContentNode[] children_ordered() {
        if (children.length == 0)
            return [];
        if (children.length == 1)
            return [children[0]];

        ContentNode[] ordered = [];

        auto iter1 = new gtk.TextIter.TextIter();
        auto iter2 = new gtk.TextIter.TextIter();

        bool p = false;

        foreach (child; children) {
            buffer.getIterAtMark(iter1, buffer.getMark("s"~to!string(child.id)));
            p = false;
            foreach (i, ordered_child; ordered) {
                buffer.getIterAtMark(iter2, buffer.getMark("s"~to!string(ordered_child.id)));
                auto c = iter1.compare(iter2);
                if (c == -1) {
                    ordered = ordered[0 .. i] ~ child ~ ordered[i .. $];
                    p = true;
                    break;
                }
            }
            if (!p)
                ordered ~= child;
        }

        return ordered;
    }

    void outputBody(File f) {
        auto iter = new gtk.TextIter.TextIter();
        auto mark_iter = new gtk.TextIter.TextIter();
        buffer.getStartIter(iter);

        foreach (child; children_ordered) {
            if (child.orphan)
                continue;
            buffer.getIterAtMark(mark_iter, buffer.getMark("s"~to!string(child.id)));
            f.write(buffer.getText(iter, mark_iter, false));
            child.outputLatex(f);
            buffer.getIterAtMark(iter, buffer.getMark("e"~to!string(child.id)));
        }

        buffer.getEndIter(mark_iter);
        f.write(buffer.getText(iter, mark_iter, false));
    }

    void outputLatex(File f, bool top = false) {
        string templ = latex_template(top);

        string output;
        string sub;

        if (top && inside_math) {
            templ = "\\("~templ~"\\)";
        }

        for (int i = 0; i < templ.length; i++) {
            if (templ[i] == '#') {
                sub = "";
                for (int j = i + 1; j < templ.length; j++) {
                    if (templ[j] == ';') {
                        if (output.length > 0) {
                            f.write(output);
                            output = "";
                        }
                        i = j;
                        ulong n;
                        try {
                            n = to!ulong(sub);
                        } catch (ConvException e) {
                            writeln("error in template "~templ);
                            break;
                        }
                        if (n == 0) {
                            outputBody(f);
                        } else if ((n - 1) < children.length) {
                            children[n - 1].outputLatex(f);
                        } else {
                            writeln("error in template "~templ);
                        }
                        break;
                    }
                    sub ~= templ[j];
                }
                try {
                    ulong n = to!ulong(sub);
                } catch (ConvException ce) {

                }
            } else {
                output ~= templ[i];
            }
        }
        if (output.length > 0)
            f.write(output);
    }

    void setCID(ContentNode node) {
        int[] cids;
        foreach (child; children) {
            if (child.short_name == node.short_name)
                cids ~= child.cid;
        }
        cids.sort;

        int new_cid = 1;
        foreach (c; cids) {
            if (c == new_cid)
                new_cid++;
            else
                break;
        }

        node.cid = new_cid;
    }
    
    int addChild(ContentNode node, gtk.TextIter.TextIter iter) {
//        children_type_count[node.short_name] = children_type_count.get(node.short_name, 0) + 1;

        setCID(node);
        
        node.orphan = false;

        node.parent = this;
        if (inside_math || context == ContextType.MATH) {
            node.inside_math = true;
        }

        
        auto start_mark = new gtk.TextMark.TextMark("s"~to!string(node.id), 1);
        auto end_mark = new gtk.TextMark.TextMark("e"~to!string(node.id), 1);
//        auto child_iter = new gtk.TextIter.TextIter();

        /*
        int n = -1;

        foreach (int i, child; children) {
            auto mark = buffer.getMark("s"~to!string(child.id));
            buffer.getIterAtMark(child_iter, mark);
            if (iter.compare(child_iter) == -1) {
                children = children[0 .. i] ~ node ~ children[i .. $];
                n = i;
                break;
            }
        }

        if (n == -1) {
            n = cast(int)children.length;
            children ~= node;
        }
        */

        
        auto start_iter = new gtk.TextIter.TextIter();
        buffer.getStartIter(start_iter);
        auto match_start = new gtk.TextIter.TextIter();
        auto match_end = new gtk.TextIter.TextIter();

        if (start_iter.forwardSearch(node.inline_name, gtk.TextIter.GtkTextSearchFlags.TEXT_ONLY, match_start, match_end, null) == 1) {
            buffer.addMark(start_mark, match_start);
            buffer.addMark(end_mark, match_end);
            buffer.applyTagByName("child-tag", match_start, match_end);
        } else {

            buffer.addMark(start_mark, iter);
//        buffer.insertWithTagsByName(iter, node.inline_name, ["child-tag"]);
            buffer.insertWithTagsByName(iter, node.inline_name, ["child-tag"]);
//        node.anchor = buffer.createChildAnchor(iter);
//        writeln(node.anchor);
//        gobject.ObjectG.ObjectG.doref(cast(void*)node.anchor.getStruct());
//        node.anchor.doref();
//        view.addChildAtAnchor(node.inline_widget, anchor);
//        buffer.addMark(end_mark, iter);
            buffer.addMark(end_mark, iter);
        }
        
//        node.path = path ~ ":" ~ to!string(children.length);
        
        children ~= node;

        

        return cast(int)children.length - 1;
    }

    bool removeChild(ContentNode node) {
        if (!editable)
            return false;

        foreach (i, child; children) {
            if (child == node) {
                if ((i+1) == children.length) {
                    children = children[0 .. $-1];
                } else if (i == 0) {
                    children = children[1 .. $];
                } else {
                    children = children[0 .. i] ~ children[i+1 .. $];
                }
                auto start_mark = buffer.getMark("s"~to!string(node.id));
                auto end_mark = buffer.getMark("e"~to!string(node.id));
                if (!node.orphan) {
                    auto start = new gtk.TextIter.TextIter();
                    auto end = new gtk.TextIter.TextIter();
                    buffer.getIterAtMark(start, start_mark);
                    buffer.getIterAtMark(end, end_mark);
                    buffer.removeTagByName("child-tag", start, end);
                    buffer.delet(start, end);
                }
                buffer.deleteMark(start_mark);
                buffer.deleteMark(end_mark);
                return true;
            }
        }
        return false;
    }

    void buffer_changed_action(gtk.TextBuffer.TextBuffer buffer) {
        checkOrphans();
    }

    void checkOrphans() {
        auto search_iter = new gtk.TextIter.TextIter();
        auto match_start = new gtk.TextIter.TextIter();
        auto match_end = new gtk.TextIter.TextIter();

        buffer.getStartIter(match_start);
        buffer.getEndIter(match_end);

        buffer.removeTagByName("child-tag", match_start, match_end);

        foreach (child; children) {
            buffer.getStartIter(search_iter);
            if (search_iter.forwardSearch(child.inline_name, gtk.TextIter.GtkTextSearchFlags.TEXT_ONLY, match_start, match_end, null) == 1) {
                buffer.moveMarkByName("s"~to!string(child.id), match_start);
                buffer.moveMarkByName("e"~to!string(child.id), match_end);
                app.content.setOrphaned(child, false);
                buffer.applyTagByName("child-tag", match_start, match_end);
            } else {
                app.content.setOrphaned(child, true);
            }
        }
    }

    /+
    bool addChild(gtk.TextBuffer.TextBuffer buffer, ContentNode node, gtk.TreeStore.TreeStore model, string path) {
        auto new_iter = new gtk.TextIter.TextIter();
        auto start_iter = new gtk.TextIter.TextIter();
        auto end_iter = new gtk.TextIter.TextIter();
        buffer.getIterAtMark(new_iter, node.start_mark);

        foreach (int i, child; children) {
            buffer.getIterAtMark(start_iter, child.start_mark);
            buffer.getIterAtMark(end_iter, child.end_mark);

            if (new_iter.compare(start_iter) == -1) { //new child is before this one
                if (new_iter.compare(end_iter) <= 0) {
                    //insert before child
                    writeln("insert before");
//                    auto new_model_iter = model.createIter();
//                    model.getIterFromString(new_model_iter, position~":"~to!string(i));
//                    auto prepend_model_iter = model.prepend(new_model_iter);
//                    model.setValue(prepend_model_iter, 0, node.display_name);
                    addToModel(node, path, i+1, model);
                    if (i == 0) {
                        child.children = [node] ~ child.children;
                    } else {
                        child.children = child.children[0 .. i] ~ node ~ child.children[i..$];
                    }
                    return true;
                } else {
                    //overlapping, cannot insert
                    stderr.writeln("Cannot insert overlapping child");
                    return false;
                }
            } else if (new_iter.compare(end_iter) <= 0) { //new child is inside this one
                writeln("descend...");
                if (child.children.length == 0) {
                    writeln("direct");
//                    auto new_model_iter = model.append(model_iter);
//                    model.setValue(new_model_iter, 0, node.display_name);
                    addToModel(node, path.length == 0 ? to!string(i) : path~":"~to!string(i), 0, model);
                    child.children ~= node;
                    return true;
                } else {
//                    auto new_model_iter = model.createIter();
//                    model.iterChildren(new_model_iter, model_iter);
                    return child.addChild(buffer, node, model, path.length == 0 ? to!string(i) : path ~ ":" ~ to!string(i));
                }
            }

            writeln("next...");
        }

        //else, insert at end
        writeln("insert after");
//        auto new_model_iter = model.append(null);
//        model.setValue(new_model_iter, 0, node.display_name);
        addToModel(node, path, cast(int)children.length, model);
        children ~= node;
        return true;
    }

    void addToModel(ContentNode node, string path, int position, gtk.TreeStore.TreeStore model, bool select = true) {
        auto new_iter = new gtk.TreeIter.TreeIter();
        if (path.length > 0) {
            auto current_iter = new gtk.TreeIter.TreeIter();
            model.getIterFromString(current_iter, path);
            model.insert(new_iter, current_iter, position);
        } else {
            model.insert(new_iter, null, position);
        }

        model.setValue(new_iter, 0, node.display_name);

        if (select) {
            string p = path.length == 0 ? to!string(position) : path ~ ":" ~ to!string(position);
            auto treepath = new gtk.TreePath.TreePath(p);
            app.tree_view.expandToPath(treepath);
            app.tree_view.setCursor(treepath, app.name_column, 0);
            app.content.current_node = node;
        }
    }
    +/

    override string toString() {
        return inline_name;
    }

    // my editable region(s) are anywhere there isn't a child between start_index and end_index

    void print() {
        writeln(id, "->", children);
        foreach (child; children)
            child.print();
    }

    @property ContextType context() {
        final switch (type) {
            case ContentNodeType.ROOT:
                return ContextType.NONE;
            case ContentNodeType.FRAME:
                return ContextType.NONE;
            case ContentNodeType.DUMMY:
                return ContextType.NONE;
            case ContentNodeType.MATH:
                return ContextType.MATH;
            case ContentNodeType.MATH_INLINE:
                return ContextType.MATH;
            case ContentNodeType.MATH_GROUP:
                return ContextType.MATH;
            case ContentNodeType.STATIC:
                return ContextType.NONE;
        }
    }

    bool acceptsNode(ContentNode node) {
        foreach (accepted; accepted_types[type]) {
            if (accepted == node.type) {
                return true;
            }
        }
        return false;
    }

    /*
    void mark_deleted_action(gtk.TextMark.TextMark mark, gtk.TextBuffer.TextBuffer buffer) {
        string name = mark.getName();
        if (name == "insert")
            return;

        foreach (child; children) {
            if (name == "s"~to!string(child.id)) {
                writeln("child "~child.inline_name~" mark deleted ("~name~")");
            }
        }
    }
    */

    /+
    void load_to_buffer(gtk.TextBuffer.TextBuffer source, gtk.TextBuffer.TextBuffer dest) {
        auto start_iter = new gtk.TextIter.TextIter();
        auto end_iter = new gtk.TextIter.TextIter();
        auto new_start_iter = new gtk.TextIter.TextIter();

        auto dest_iter = new gtk.TextIter.TextIter();
        dest.getStartIter(dest_iter);

        source.getIterAtMark(start_iter, start_mark);
        source.getIterAtMark(end_iter, end_mark);
        
        foreach (child; children) {
            source.getIterAtMark(new_start_iter, child.start_mark);

            if (start_iter.compare(new_start_iter) == -1) {
                //copy from start to new_start
                dest.insertRange(dest_iter, start_iter, new_start_iter);
            }
            source.getIterAtMark(start_iter, child.end_mark);
            dest.moveMark(child.s_start_mark, dest_iter);
            dest.insert(dest_iter, "<child>");
            dest.moveMark(child.s_end_mark, dest_iter);
        }

        if (start_iter.compare(end_iter) == -1) {
            dest.insertRange(dest_iter, start_iter, end_iter);
        }
    }

    void merge_into_buffer(gtk.TextBuffer.TextBuffer source, gtk.TextBuffer.TextBuffer dest) {
        auto start_iter = new gtk.TextIter.TextIter();
        auto end_iter = new gtk.TextIter.TextIter();
        auto new_start_iter = new gtk.TextIter.TextIter();
        auto old_start_iter = new gtk.TextIter.TextIter();
        auto old_end_iter = new gtk.TextIter.TextIter();

        auto dest_iter = new gtk.TextIter.TextIter();

        dest.getIterAtMark(dest_iter, start_mark);

        source.getStartIter(start_iter);
        source.getEndIter(end_iter);

        foreach (child; children) {
            source.getIterAtMark(new_start_iter, child.s_start_mark);
            dest.getIterAtMark(old_start_iter, child.start_mark);

            if (start_iter.compare(new_start_iter) == -1) {
                writeln("deleting child "~dest.getText(dest_iter, old_start_iter, 0));
                dest.delet(dest_iter, old_start_iter);
                writeln("inserting child "~source.getText(start_iter, new_start_iter, 0));
                dest.insertRange(dest_iter, start_iter, new_start_iter);
            }
            source.getIterAtMark(start_iter, child.s_end_mark);
            dest.getIterAtMark(dest_iter, child.end_mark);
        }
        
        dest.getIterAtMark(old_end_iter, end_mark);

        if (start_iter.compare(end_iter) == -1) {
            writeln("deleting "~dest.getText(dest_iter, old_end_iter, 0));
            dest.delet(dest_iter, old_end_iter);
            writeln("inserting "~source.getText(start_iter, end_iter, 0));
            dest.insertRange(dest_iter, start_iter, end_iter);
        }

//        dest.moveMark(end_mark, dest_iter);
    }
    +/
}

