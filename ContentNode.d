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

import Content, Present, PresentListingDialog;

enum ContentNodeType {
    ROOT,
    FRAME,
    FRAME_TITLE,
    MATH,
    MATH_INLINE,
    MATH_GROUP,
    STATIC,
    /*
    LIST_ITEM,
    LIST_ENUM,
    LIST_ALPHA,
    */
    LIST,
    TABLE,
    TABLE_GROUP,
    TABLE_ROW,
    TABLE_CELL,
    COLUMN_GROUP,
    COLUMN,
    LISTING,
    OVERPRINT,
    ONSLIDE,
//    ANIMATION,
    DUMMY
}

struct Borders {
    bool left, right, above, below;
}

class ContentNode {
    ContentNode parent;
    ContentNode[] children;

//    int master_start_index, master_end_index;
    gsv.SourceBuffer.SourceBuffer buffer;
//    gtk.TextChildAnchor.TextChildAnchor anchor;

    string custom_display_name,
           custom_inline_name;

    bool shrink_contents;

    bool /*editable,*/ inside_math, supress_animations;
    bool invalid;

    string latex;

    ContentNodeType type;
    ulong id;
    int cid;

    int table_width, table_height;
    int[2] weight;
    Borders border = Borders(false, true, false, true);

    bool auto_sized = true;
    bool top_aligned = true;
    ulong column_size;

    ListingStyle listing_style;

    bool orphan = false;
//    bool placed = false;

    SlideMarker[] slide_marks;
    ulong slide_mark_count;

    string list_type;

//    int[string] children_type_count;

//    string path;
    gtk.TreeRowReference.TreeRowReference reference;

//    gtk.Label.Label inline_widget;

    enum accepted_types = [
        ContentNodeType.ROOT : [ ContentNodeType.FRAME ],
        ContentNodeType.FRAME : [ ContentNodeType.MATH, ContentNodeType.MATH_INLINE,
                                  ContentNodeType.LIST,
                                  ContentNodeType.TABLE, ContentNodeType.COLUMN_GROUP,
                                  ContentNodeType.LISTING, ContentNodeType.FRAME_TITLE,
                                  ContentNodeType.OVERPRINT ],
        ContentNodeType.FRAME_TITLE : [ ],
        ContentNodeType.MATH : [ ContentNodeType.MATH_GROUP, ContentNodeType.STATIC,
                                 ContentNodeType.OVERPRINT ],
        ContentNodeType.MATH_INLINE : [ ContentNodeType.MATH_GROUP, ContentNodeType.STATIC,
                                        ContentNodeType.OVERPRINT ],
        ContentNodeType.MATH_GROUP : [ ContentNodeType.MATH_GROUP, ContentNodeType.STATIC,
                                       ContentNodeType.OVERPRINT ],
        ContentNodeType.STATIC : [ ContentNodeType.MATH_GROUP, ContentNodeType.STATIC ],
        /*
        ContentNodeType.LIST_ITEM : [ ContentNodeType.MATH, ContentNodeType.MATH_INLINE,
                                      ContentNodeType.TABLE ],
        ContentNodeType.LIST_ENUM : [ ContentNodeType.MATH, ContentNodeType.MATH_INLINE,
                                      ContentNodeType.TABLE ],
        ContentNodeType.LIST_ALPHA : [ ContentNodeType.MATH, ContentNodeType.MATH_INLINE,
                                       ContentNodeType.TABLE, ContentNodeType.LISTING ],
        */
        ContentNodeType.LIST : [ ContentNodeType.MATH, ContentNodeType.MATH_INLINE,
                                 ContentNodeType.TABLE, ContentNodeType.OVERPRINT ],
        ContentNodeType.TABLE : [ ],
        ContentNodeType.TABLE_GROUP : [ ],
        ContentNodeType.TABLE_ROW : [ ],
        ContentNodeType.TABLE_CELL : [ ContentNodeType.MATH_INLINE, ContentNodeType.OVERPRINT ],
        ContentNodeType.COLUMN_GROUP : [ ContentNodeType.COLUMN ],
        ContentNodeType.COLUMN : [ ContentNodeType.MATH, ContentNodeType.MATH_INLINE,
                                   ContentNodeType.LIST,
                                   ContentNodeType.TABLE, ContentNodeType.COLUMN_GROUP,
                                   ContentNodeType.LISTING, ContentNodeType.OVERPRINT ],
        ContentNodeType.LISTING : [ ],
        ContentNodeType.OVERPRINT : [ ContentNodeType.ONSLIDE ],
        ContentNodeType.ONSLIDE : [ ContentNodeType.MATH, ContentNodeType.MATH_INLINE,
                                    ContentNodeType.TABLE, ContentNodeType.COLUMN_GROUP ],
        ContentNodeType.DUMMY : [ ]
    ];

    static string default_list_type = "Lettered";

    static ListProperties[string] list_properties;

    static void init_list_types() {
        list_properties = [
            "Itemized" : ItemizedList,
            "Enumerated" : EnumeratedList,
            "Lettered" : AlphaList
        ];
    }

    this(ContentNodeType type, ulong id, gtk.TextTagTable.TextTagTable tag_table, string custom_display_name = "", string custom_inline_name = "") {
        this.type = type;
        this.id = id;
        this.cid = -1;
        this.custom_display_name = custom_display_name;
        this.custom_inline_name = custom_inline_name;

        if (type == ContentNodeType.LIST) {
            list_type = default_list_type;
        }

        /*
        if (type == ContentNodeType.ROOT || type == ContentNodeType.STATIC) {
            editable = false;
        } else {
            editable = true;
        }
        */

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
                    return "\\begin{frame}[fragile"~(shrink_contents ? ",shrink" : "")~"]\n#0;\n\\end{frame}\n";
                case ContentNodeType.FRAME_TITLE:
                    if (top)
                        return "#0;";
                    else
                        return "\\frametitle{#0;}\n";
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
                    /*
                case ContentNodeType.LIST_ITEM:
                    if (top)
                        return "\\begin{frame}[fragile]\n\\begin{easylist}[itemize]\n#0;\n\\end{easylist}\n\\end{frame}\n";
                    else
                        return "\\begin{easylist}[itemize]\n#0;\n\\end{easylist}\n";
                case ContentNodeType.LIST_ENUM:
                    if (top)
                        return "\\begin{frame}[fragile]\n\\begin{easylist}[enumerate]\n#0;\n\\end{easylist}\n\\end{frame}\n";
                    else
                        return "\\begin{easylist}[enumerate]\n#0;\n\\end{easylist}\n";
                case ContentNodeType.LIST_ALPHA:
                    if (top)
                        return "\\begin{frame}[fragile]\n\\ListProperties(Numbers1=l,Mark=,FinalMark={)},Progressive=0.5cm,Hide2=1)\n\\begin{easylist}\n#0;\n\\end{easylist}\n\\end{frame}\n";
                    else
                        return "\\ListProperties(Numbers1=l,Mark=,FinalMark={)},Progressive=0.5cm,Hide2=2)\n\\begin{easylist}\n#0;\n\\end{easylist}\n";
                    */
                case ContentNodeType.LIST:
                    if (top)
                        return "\\begin{frame}[fragile]\n"~list_properties[list_type].output~"\n\\begin{easylist}\n#0;\n\\end{easylist}\n\\end{frame}\n";
                    else
                        return "\n"~list_properties[list_type].output~"\n\\begin{easylist}\n#0;\n\\end{easylist}\n";
                case ContentNodeType.TABLE:
                case ContentNodeType.TABLE_GROUP:
                case ContentNodeType.TABLE_ROW:
                case ContentNodeType.TABLE_CELL:
                    return "";
                case ContentNodeType.COLUMN_GROUP:
                    if (top)
                        return "\\begin{frame}[fragile]\n\\begin{columns}["~(top_aligned ? "T" : "c")~"]\n#0;\n\\end{columns}\n\\end{frame}\n";
                    else
                        return "\\begin{columns}["~(top_aligned ? "T" : "c")~"]\n#0;\n\\end{columns}\n\\hfill\n";
                case ContentNodeType.COLUMN:
                    if (top)
                        return "#0;";
                    else
                        return "\\begin{column}["~(top_aligned ? "T" : "c")~"]{."~to!string(column_size)~"\\textwidth}\n#0;\n\\end{column}\n";
                case ContentNodeType.LISTING:
                    if (listing_style is null)
                        return "\\begin{lstlisting}\n#0;\n\\end{lstlisting}";
                    else
                        return "\\begin{lstlisting}"~listing_style.output~"\n#0;\n\\end{lstlisting}";
                case ContentNodeType.OVERPRINT:
                    return "\\begin{overprint}[\\textwidth]\n#0;\n\\end{overprint}\n";
                case ContentNodeType.ONSLIDE:
                    return "\\onslide<+>\n#0;\n";
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
                case ContentNodeType.FRAME_TITLE:
                    s = "Title";
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
                    /*
                case ContentNodeType.LIST_ITEM:
                    s = "Itemized";
                    break;
                case ContentNodeType.LIST_ENUM:
                    s = "Numbered";
                    break;
                case ContentNodeType.LIST_ALPHA:
                    s = "Lettered";
                    break;
                    */
                case ContentNodeType.LIST:
                    s = list_type;
                    break;
                case ContentNodeType.TABLE:
                    s = "Table ["~to!string(table_width)~"x"~to!string(table_height)~"] ("~to!string(weight[0])~"x"~to!string(weight[1])~")";
                    break;
                case ContentNodeType.TABLE_GROUP:
                    s = "Group ["~to!string(table_width)~"x"~to!string(table_height)~"] ("~to!string(weight[0])~"x"~to!string(weight[1])~")";
                    break;
                case ContentNodeType.TABLE_ROW:
                    s = "Row ("~to!string(weight[0])~"x"~to!string(weight[1])~")";
                    break;
                case ContentNodeType.TABLE_CELL:
                    s = "Cell ("~to!string(weight[0])~"x"~to!string(weight[1])~")";
                    break;
                case ContentNodeType.COLUMN_GROUP:
                    s = "Columns";
                    break;
                case ContentNodeType.COLUMN:
                    s = "Column ("~to!string(column_size)~"%)";
                    break;
                case ContentNodeType.LISTING:
                    if (listing_style is null)
                        s = "Code Listing";
                    else
                        s = "Code Listing ("~listing_style.name~")";
                    break;
                case ContentNodeType.OVERPRINT:
                    s = "Overprint";
                    break;
                case ContentNodeType.ONSLIDE:
                    s = "View";
                    break;
            }
        }

        if (orphan)
            s ~= "*";

        if (!editable) {
            s = "<i>"~s~"</i>";
        }
        
        if (invalid) {
            s = "<span color=\"red\">" ~ s ~ "</span>";
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
                case ContentNodeType.FRAME_TITLE:
                    s = "title";
                    break;
                case ContentNodeType.MATH:
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
                    /*
                case ContentNodeType.LIST_ITEM:
                case ContentNodeType.LIST_ENUM:
                case ContentNodeType.LIST_ALPHA:
                    */
                case ContentNodeType.LIST:
                    s = "list";
                    break;
                case ContentNodeType.TABLE:
                    return "table";
                case ContentNodeType.TABLE_GROUP:
                    return "group";
                case ContentNodeType.TABLE_ROW:
                    return "row";
                case ContentNodeType.TABLE_CELL:
                    return "cell";
                case ContentNodeType.COLUMN_GROUP:
                    return "columns";
                case ContentNodeType.COLUMN:
                    return "column";
                case ContentNodeType.LISTING:
                    return "listing";
                case ContentNodeType.OVERPRINT:
                    return "overprint";
                case ContentNodeType.ONSLIDE:
                    return "view";
            }
        }
        return s;
    }

    @property bool editable() {
        final switch (type) {
            case ContentNodeType.ROOT:
            case ContentNodeType.STATIC:
            case ContentNodeType.TABLE:
            case ContentNodeType.TABLE_GROUP:
            case ContentNodeType.TABLE_ROW:
            case ContentNodeType.COLUMN_GROUP:
            case ContentNodeType.OVERPRINT:
                return false;
            case ContentNodeType.FRAME:
            case ContentNodeType.FRAME_TITLE:
            case ContentNodeType.MATH:
            case ContentNodeType.MATH_INLINE:
            case ContentNodeType.MATH_GROUP:
            /*
            case ContentNodeType.LIST_ITEM:
            case ContentNodeType.LIST_ENUM:
            case ContentNodeType.LIST_ALPHA:
            */
            case ContentNodeType.LIST:
            case ContentNodeType.TABLE_CELL:
            case ContentNodeType.DUMMY:
            case ContentNodeType.COLUMN:
            case ContentNodeType.LISTING:
            case ContentNodeType.ONSLIDE:
                return true;
        }
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

        ulong i = 0;
        bool start = true;
        auto slide_mark_iter = new gtk.TextIter.TextIter();

        if (i < slide_mark_count)
            buffer.getIterAtMark(slide_mark_iter, slide_marks[0].start1_mark);

        foreach (child; children_ordered) {
            if (child.orphan)
                continue;
            
            buffer.getIterAtMark(mark_iter, buffer.getMark("s"~to!string(child.id)));

            while (i < slide_mark_count && slide_mark_iter.compare(mark_iter) <= 0) {
                f.write(buffer.getText(iter, slide_mark_iter, false));
                if (start) {
                    if (type == ContentNodeType.FRAME) {
                        f.write("\\begin{"~slide_marks[i].env_keyword~"}<"~slide_marks[i].range~">");
                    } else {
                        f.write("\\"~slide_marks[i].keyword~"<"~slide_marks[i].range~">{");
                    }
                    start = false;
                    buffer.getIterAtMark(slide_mark_iter, slide_marks[i].start2_mark);
                    buffer.getIterAtMark(iter, slide_marks[i].end1_mark);
                } else {
                    if (type == ContentNodeType.FRAME) {
                        f.write("\\end{"~slide_marks[i].env_keyword~"}");
                    } else {
                        f.write("}");
                    }
                    start = true;
                    buffer.getIterAtMark(iter, slide_marks[i].end2_mark);
                    i++;
                    if (i < slide_marks.length)
                        buffer.getIterAtMark(slide_mark_iter, slide_marks[i].start1_mark);
                }
            }

            f.write(buffer.getText(iter, mark_iter, false));
            child.outputLatex(f);
            buffer.getIterAtMark(iter, buffer.getMark("e"~to!string(child.id)));
        }

        buffer.getEndIter(mark_iter);

        while (i < slide_mark_count && slide_mark_iter.compare(mark_iter) <= 0) {
            f.write(buffer.getText(iter, slide_mark_iter, false));
            if (start) {
                if (type == ContentNodeType.FRAME) {
                    f.write("\\begin{"~slide_marks[i].env_keyword~"}<"~slide_marks[i].range~">");
                } else {
                    f.write("\\"~slide_marks[i].keyword~"<"~slide_marks[i].range~">{");
                }
                start = false;
                buffer.getIterAtMark(slide_mark_iter, slide_marks[i].start2_mark);
                buffer.getIterAtMark(iter, slide_marks[i].end1_mark);
            } else {
                if (type == ContentNodeType.FRAME) {
                    f.write("\\end{"~slide_marks[i].env_keyword~"}");
                } else {
                    f.write("}");
                }
                start = true;
                buffer.getIterAtMark(iter, slide_marks[i].end2_mark);
                i++;
                if (i < slide_marks.length)
                    buffer.getIterAtMark(slide_mark_iter, slide_marks[i].start1_mark);
            }
        }

        f.write(buffer.getText(iter, mark_iter, false));
    }

    void outputLatex(File f, bool top = false) {
        string templ = latex_template(top);

        string output;
        string sub;

        if (type == ContentNodeType.TABLE) {
            //special table processing
            outputTable(f);
            return;
        }

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

    void outputTable(File f) {
        if (invalid) {
            f.write("(invalid table)");
        } else {
            f.write("\\begin{tabular}{");
            foreach (c; 0 .. weight[0]) {
                f.write("c");
            }
            f.write("}\n");

            auto flat = flattenTable();

            auto table_borders = getBorders(flat);

            if (border.above)
                f.write("\\hline\n");

            for (ulong rn = 0; rn < flat.length; rn++) {
                for (ulong cn = 0; cn < flat[rn].length; ) {
                    ulong s = 0;
                    while ((cn+s) < flat[rn].length && table_borders[rn][cn+s].above)
                        s++;
                    if (s == 0) {
                        cn++;
                    } else {
                        f.write("\\cline{",cn+1,"-",cn+s,"} ");
                        cn += s;
                    }
                }
                f.write("\n");

                for (ulong cn = 0; cn < flat[rn].length; ) {
                    auto cell = flat[rn][cn];
                    if (cell !is null) {
                        f.write("\\multicolumn{",cell.weight[0],"}{");
                        if (cn == 0 && border.left)
                            f.write("|");
                        if (table_borders[rn][cn].left)
                            f.write("|");
                        f.write("c");
                        if (table_borders[rn][cn+cell.weight[0]-1].right)
                            f.write("|");
                        if ((cn+1) == flat[rn].length && border.right)
                            f.write("|");
                        f.write("}{");

                        if (cell.weight[1] > 1) {
                            f.write("\\multirow{",cell.weight[1],"}{*}{");
                        }

                        cell.outputBody(f);

                        if (cell.weight[1] > 1) {
                            f.write("}");
                        
                        }

                        f.write("}");
                        cn += cell.weight[0];
                    } else {
                        f.write("\\multicolumn{1}{");
                        if (cn == 0 && border.left)
                            f.write("|");
                        if (table_borders[rn][cn].left)
                            f.write("|");
                        f.write("c");
                        if (table_borders[rn][cn].right)
                            f.write("|");
                        if ((cn+1) == flat[rn].length && border.right)
                            f.write("|");
                        f.write("}{}");
                        cn++;
                    }
                    if (cn == flat[rn].length)
                        f.write(" \\\\\n");
                    else
                        f.write(" & ");
                }

                for (ulong cn = 0; cn < flat[rn].length; ) {
                    ulong s = 0;
                    while ((cn+s) < flat[rn].length && table_borders[rn][cn+s].below)
                        s++;
                    if (s == 0) {
                        cn++;
                    } else {
                        f.write("\\cline{",cn+1,"-",cn+s,"} ");
                        cn += s;
                    }
                }
                f.write("\n");
            }
            f.write("\\end{tabular}\n");
        }
    }

    /*
    void outputTableGroup(File f) {
        foreach (row; children) {
            f.writeln("\\hline\n");
            row.outputTableRow(f);
        }
        f.writeln("\\hline\n");
    }

    void outputTableRow(File f) {
        foreach (col; children) {
            if (
        }
    }
    */

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

        if (supress_animations || context == ContextType.ANIM_GROUP) {
            node.supress_animations = true;
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
        if (context == ContextType.LISTING)
            return;
        checkSlideMarks();
        if (!supress_animations)
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

    void checkSlideMarks() {
        auto match1_start = new gtk.TextIter.TextIter();
        auto match1_end = new gtk.TextIter.TextIter();
        auto match2_start = new gtk.TextIter.TextIter();
        auto match2_end = new gtk.TextIter.TextIter();
        auto match3_start = new gtk.TextIter.TextIter();
        auto match3_end = new gtk.TextIter.TextIter();

        buffer.getStartIter(match1_start);
        buffer.getEndIter(match1_end);

        buffer.removeTagByName("onslide-range-tag", match1_start, match1_end);
//        buffer.removeTagByName("onslide-highlight-tag", match1_start, match1_end);

        buffer.getStartIter(match3_end);
        
        ulong i = 0;

        while (match3_end.forwardSearch("<<", gtk.TextIter.GtkTextSearchFlags.TEXT_ONLY, match1_start, match1_end, null) == 1) {
            if (match1_end.forwardSearch(">(", gtk.TextIter.GtkTextSearchFlags.TEXT_ONLY, match2_start, match2_end, null) == 1) {
                if (match2_end.forwardSearch(")>", gtk.TextIter.GtkTextSearchFlags.TEXT_ONLY, match3_start, match3_end, null) == 1) {
                    auto range = buffer.getText(match2_end, match3_start, 0);
//                    buffer.applyTagByName("onslide-highlight-tag", match1_end, match2_start);
                    buffer.applyTagByName("onslide-range-tag", match2_end, match3_start);
                    if (i < slide_marks.length) {
                        slide_marks[i].active = true;
                        buffer.moveMark(slide_marks[i].start1_mark, match1_start);
                        buffer.moveMark(slide_marks[i].start2_mark, match2_start);
                        buffer.moveMark(slide_marks[i].end1_mark, match1_end);
                        buffer.moveMark(slide_marks[i].end2_mark, match3_end);
                        slide_marks[i].setRange(range);
                    } else {
                        auto mark = new SlideMarker;
                        mark.active = true;
                        mark.setRange(range);
                        mark.start1_mark = buffer.createMark(null, match1_start, 0);
                        mark.start2_mark = buffer.createMark(null, match2_start, 0);
                        mark.end1_mark = buffer.createMark(null, match1_end, 0);
                        mark.end2_mark = buffer.createMark(null, match3_end, 0);
                        slide_marks ~= mark;
                    }
                    i++;
                } else {
                    break;
                }
            } else {
                break;
            }
        }
        
        slide_mark_count = i;

        while (i < slide_marks.length) {
            slide_marks[i].active = false;
            i++;
        }
    }

    void clearBuffer() {
        auto start_iter = new gtk.TextIter.TextIter();
        auto end_iter = new gtk.TextIter.TextIter();

        buffer.getStartIter(start_iter);
        buffer.getEndIter(end_iter);

        buffer.delet(start_iter, end_iter);
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
            case ContentNodeType.FRAME:
            case ContentNodeType.FRAME_TITLE:
            case ContentNodeType.DUMMY:
            case ContentNodeType.STATIC:
            case ContentNodeType.ONSLIDE:
                return ContextType.NONE;
            case ContentNodeType.MATH:
            case ContentNodeType.MATH_INLINE:
            case ContentNodeType.MATH_GROUP:
                return ContextType.MATH;
            /*
            case ContentNodeType.LIST_ITEM:
            case ContentNodeType.LIST_ENUM:
            case ContentNodeType.LIST_ALPHA:
            */
            case ContentNodeType.LIST:
                return ContextType.LIST;
            case ContentNodeType.TABLE:
            case ContentNodeType.TABLE_GROUP:
            case ContentNodeType.TABLE_ROW:
            case ContentNodeType.TABLE_CELL:
                return ContextType.TABLE;
            case ContentNodeType.COLUMN_GROUP:
            case ContentNodeType.COLUMN:
                return ContextType.COLUMN;
            case ContentNodeType.LISTING:
                return ContextType.LISTING;
            case ContentNodeType.OVERPRINT:
                return ContextType.ANIM_GROUP;
        }
    }

    bool acceptsNodeType(ContentNodeType child_type) {
//        writeln(accepted_types[type]);
        foreach (accepted; accepted_types[type]) {
            if (accepted == child_type) {
                return true;
            }
        }
        return false;
    }

    void populateTable(int width, int height) {
        auto iter = new gtk.TextIter.TextIter();
        buffer.getStartIter(iter);

        table_width = width;
        table_height = height;

        border.left = true;
        border.right = false;
        border.above = true;
        border.below = false;

        auto group = app.content.createNode(ContentNodeType.TABLE_GROUP);

        addChild(group, iter);

        group.populateTableGroup(width, height);
    }

    void populateTableGroup(int width, int height) {
        table_width = width;
        table_height = height;

        auto rowiter = new gtk.TextIter.TextIter();
        auto coliter = new gtk.TextIter.TextIter();
        buffer.getStartIter(rowiter);

        foreach (row; 0 .. table_height) {
            auto node = app.content.createNode(ContentNodeType.TABLE_ROW);
            addChild(node, rowiter);

            node.buffer.getStartIter(coliter);
            foreach (col; 0 .. table_width) {
                auto cell = app.content.createNode(ContentNodeType.TABLE_CELL);
                node.addChild(cell, coliter);
            }
        }
    }

    void resizeTable(int width, int height) {
        table_width = width;
        table_height = height;
    }

    void resizeTableGroup(int width, int height) {
        if (height < table_height) {
            foreach (row; height .. table_height) {
                removeChild(children[row]);
            }
            children = children[0 .. height];
        } else if (height > table_height) {
            auto rowiter = new gtk.TextIter.TextIter();
            buffer.getEndIter(rowiter);
            foreach (row; table_height .. height) {
                auto node = app.content.createNode(ContentNodeType.TABLE_ROW);
                addChild(node, rowiter);
            }
        }

        if (width < table_width) {
            foreach (row; 0 .. height) {
                foreach (col; width .. table_width) {
                    children[row].removeChild(children[row].children[col]);
                }
                children[row].children = children[row].children[0 .. width];
            }
        } else {
            auto coliter = new gtk.TextIter.TextIter();
            foreach (row; 0 .. height) {
                children[row].buffer.getEndIter(coliter);
                while(children[row].children.length < width) {
                    auto node = app.content.createNode(ContentNodeType.TABLE_CELL);
                    children[row].addChild(node, coliter);
                }
            }
        }

        table_width = width;
        table_height = height;
    }

    int[2] calculateTableWeights() {
        if (type == ContentNodeType.TABLE_CELL) {
            weight = [1, 1];
        } else if (type == ContentNodeType.TABLE_ROW) {
            int wsum = 0, hmax = 0;
            foreach (child; children) {
                auto weights = child.calculateTableWeights();
                wsum += weights[0];
                if (weights[1] > hmax)
                    hmax = weights[1];
            }
            foreach (child; children) {
                if (child.weight[1] < hmax) {
                    //rebalance
                    child.balanceTableHeight(hmax);
                }
            }
            weight = [wsum, hmax];
        } else if (type == ContentNodeType.TABLE_GROUP) {
            int wmax = 0, hsum = 0;
            foreach (child; children) {
                auto weights = child.calculateTableWeights();
                if (weights[0] > wmax)
                    wmax = weights[0];
                hsum += weights[1];
            }
            foreach (child; children) {
                if (child.weight[0] < wmax) {
                    //rebalance
                    child.balanceTableWidth(wmax);
                }
            }
            weight = [wmax, hsum];
        } else if (type == ContentNodeType.TABLE) {
            weight = children[0].calculateTableWeights();
        } else {
            //do nothing
        }
        return weight;
    }

    /*
    void balanceTable(int width, int height) {
        if (type == ContentNodeType.TABLE_CELL) {
            if (width > 0)
                weight[0] = width;
            if (height > 0)
                weight[1] = height;
        } else if (type == ContentNodeType.TABLE_ROW) {
            if (width > 0)
                weight[0] = width;
            if (height > 0)
                weight[1] = height;

            foreach (child; children) {
                child.balanceTable(width, height);
            }
        } else if (type == ContentNodeType.TABLE_GROUP) {
        } else if (type == ContentNodeType.TABLE) {
            //not sure
        } else {
            //do nothing
        }
    }
    */

    void balanceTableWidth(int width) {
        if (width > weight[0]) {
            weight[0] = width;
            foreach (child; children) {
                child.balanceTableWidth(width);
            }
        }
    }

    void balanceTableHeight(int height) {
        if (height > weight[1]) {
            weight[1] = height;
            foreach (child; children) {
                 child.balanceTableHeight(height);
            }
        }
    }

    bool tableValid() {
        if (type == ContentNodeType.TABLE_CELL) {
            invalid = false;
            return true;
        } else if (type == ContentNodeType.TABLE_ROW) {
            foreach (child; children) {
                if (!child.tableValid()) {
                    invalid = true;
                    return false;
                }
            }
            invalid = false;
            return true;
        } else if (type == ContentNodeType.TABLE_GROUP) {
            ulong sum;
            foreach (child; children) {
                if (!child.tableValid()) {
                    invalid = true;
                    return false;
                }
                sum += child.weight[0] * child.weight[1];
            }
            if (sum != weight[0] * weight[1])
                invalid = true;
            else
                invalid = false;

            return !invalid;
        } else if (type == ContentNodeType.TABLE) {
            if (children[0].tableValid()) {
                invalid = false;
            } else {
                invalid = true;
            }
            return !invalid;
        } else {
            return false;
        }
    }

    ContentNode findParent(ContentNodeType parent_type) {
        if (type == parent_type)
            return this;
        else if (parent is null)
            return null;
        else
            return parent.findParent(parent_type);
    }

    /*
    ContentNode[][] flattenTable() {
        if (type == ContentNodeType.TABLE) {
            return children[0].flattenTable();
        }

        ContentNode[][] table = new ContentNode[][](weight[0], weight[1]);
        writeln(display_name, " -> ", table);
        if (type == ContentNodeType.TABLE_CELL) {
            table[0][0] = this;
        } else if (type == ContentNodeType.TABLE_ROW) {
            ulong i;
            foreach (child; children) {
                auto subtable = child.flattenTable();
                writeln("sub = ",subtable);
                foreach (x; 0 .. subtable.length) {
                    foreach (y; 0 .. subtable[x].length) {
                        table[i+x][y] = subtable[x][y];
                    }
                }
                i += subtable.length;
            }
        } else if (type == ContentNodeType.TABLE_GROUP) {
            ulong i;
            foreach (child; children) {
                auto subtable = child.flattenTable();
                writeln("sub = ",subtable);
                foreach (x; 0 .. subtable.length) {
                    foreach (y; 0 .. subtable[x].length) {
                        table[x][i+y] = subtable[x][y];
                    }
                }
                i += subtable[0].length;
            }
        }
        return table;
    }
    */

    ContentNode[][] flattenTableGroup() {
        ContentNode[][] table = new ContentNode[][](weight[1], weight[0]);

        ulong x, y;

        writeln(weight);

        foreach (rn, row; children) {
            foreach (cn, col; row.children) {
                if (col.type == ContentNodeType.TABLE_CELL) {
                    table[y][x] = col;
                } else if (col.type == ContentNodeType.TABLE_GROUP) {
                    auto subtable = col.flattenTableGroup();
                    foreach (i; 0 .. col.weight[0]) {
                        foreach (j; 0 .. col.weight[1]) {
                            table[y+j][x+i] = subtable[j][i];
                        }
                    }
                }
                x += col.weight[0];
            }
            x = 0;
            y += row.weight[1];
        }

        return table;
    }

    ContentNode[][] flattenTable() {
        if (type != ContentNodeType.TABLE)
            return null;

        return children[0].flattenTableGroup();
    }

    Borders[][] getBorders(ContentNode[][] flat) {
        Borders[][] table_borders = new Borders[][](weight[1], weight[0]);

        for (ulong rn = 0; rn < flat.length; rn++) {
            for (ulong cn = 0; cn < flat[rn].length; cn++) {
                auto cell = flat[rn][cn];
                if (cell !is null) {
                    foreach (i; 0 .. cell.weight[0]) {
                        if (cell.border.above) {
                            table_borders[rn][cn+i].above = true;
                        }
                        if (cell.border.below) {
                            table_borders[rn+cell.weight[1]-1][cn+i].below = true;
                        }
                    }
                    foreach (i; 0 .. cell.weight[1]) {
                        if (cell.border.left) {
                            table_borders[rn+i][cn].left = true;
                        }
                        if (cell.border.right) {
                            table_borders[rn+i][cn+cell.weight[0]-1].right = true;
                        }
                    }
                }
            }
        }

        return table_borders;
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

    string buildTitle() {
        string title = short_name;
        ContentNode node = parent;
        while (node !is null) {
            title = node.short_name ~ "/" ~ title;
            node = node.parent;
        }
        return title;
    }

    string getText() {
        auto start = new gtk.TextIter.TextIter();
        auto end = new gtk.TextIter.TextIter();

        buffer.getStartIter(start);
        buffer.getEndIter(end);

        return buffer.getText(start, end, 1);
    }
}


class SlideMarker {
    string range, keyword, env_keyword;
    bool active;
    gtk.TextMark.TextMark start1_mark, end1_mark,
                          start2_mark, end2_mark;

    this() {
        //do nothing
    }

    void setRange(string s) {
        if (s.length == 0) {
            range = "+-";
            keyword = "visible";
            env_keyword = "visibleenv";
        } else if (s.length == 1 && s[0] == '*') {
            range = "+-";
            keyword = "only";
            env_keyword = "onlyenv";
        } else if (s[0] == '*') {
            range = s[1..$];
            keyword = "only";
            env_keyword = "onlyenv";
        } else {
            range = s;
            keyword = "visible";
            env_keyword = "visibleenv";
        }
    }
}

enum AlphaList = ListProperties([
        "Numbers1" : "l",
        "Numbers2" : "a",
        "FinalMark1" : "{)}",
        "FinalMark2" : ".",
        "Mark" : "",
        "Progressive" : "0.5cm",
        "Hide2" : "1"
]);

enum EnumeratedList = ListProperties([
        "Numbers1" : "a",
        "Numbers2" : "l",
        "FinalMark1" : ".",
        "FinalMark2" : "{)}",
        "Mark" : "",
        "Progressive" : "0.5cm",
        "Hide2" : "1"
]);

enum ItemizedList = ListProperties([
        "Style1*" : "\\textbullet\\hskip .5em",
        "Style2*" : "--\\hskip .5em",
        "Mark" : "",
        "Progressive" : "0.5cm",
        "Hang" : "true",
        "Hide" : "1000"
]);


struct ListProperties {
    string[string] properties;
    
    this(string[string] properties) {
        this.properties = properties;
    }

    @properties string output() {
        string s = "\\ListProperties(";
        bool comma = false;
        foreach (key, value; properties) {
            if (comma)
                s ~= ",";
            else
                comma = true;
            s ~= key ~ "=" ~ value;
        }
        writeln(s);
        return s ~ ")";
    }
}

