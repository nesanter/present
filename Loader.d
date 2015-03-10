import std.stdio;
import std.exception;
import std.string;

import Present, Content, ContentNode;

class Loader {
    static bool save(Content c, string filename) {
        File f;
        try {
            f = File(filename, "w");
        } catch (ErrnoException e) {
            return false;
        }

        f.writeln("<content>");
        saveNode(f, c.root_node, 1);
        f.writeln("</content>");

        return true;
    }

    static bool load(Content c, string filename) {
        return false;
    }

    private static void saveNode(File f, ContentNode node, ulong depth) {
        writeIndent(f, depth++);
        f.writeln("<node>");
        writeProperty(f, "type", node.type, depth);
        writeProperty(f, "id", node.id, depth);
        writeProperty(f, "cid", node.cid, depth);

        if (node.latex.length > 0) {
            writeProperty(f, "latex", node.latex, depth);
        }

        final switch (node.context) {
            case ContextType.MATH:
            case ContextType.NONE:
            case ContextType.ANIM_GROUP:
                break;
            case ContextType.LIST:
                writeProperty(f, "list_type", node.list_type, depth);
                break;
            case ContextType.TABLE:
                writeProperty(f, "table_width", node.table_width, depth);
                writeProperty(f, "table_height", node.table_height, depth);
                writeProperty(f, "weight", node.weight, depth);
                writeProperty(f, "border_left", node.border.left, depth);
                writeProperty(f, "border_right", node.border.right, depth);
                writeProperty(f, "border_above", node.border.above, depth);
                writeProperty(f, "border_below", node.border.below, depth);
                break;
            case ContextType.COLUMN:
                writeProperty(f, "auto_sized", node.auto_sized, depth);
                writeProperty(f, "top_aligned", node.top_aligned, depth);
                writeProperty(f, "column_size", node.column_size, depth);
                break;
            case ContextType.LISTING:
                writeProperty(f, "listing_tyle", node.listing_style.name, depth);
                break;
            case ContextType.TIKZ:
                break;
        }

        if (node.editable) {
            string text = node.getText();
            /*
            f.writeln("<text ",text.length,">");
            f.writeln(text);
            f.writeln("</text>");
            */
            writeTextProperty(f, "text", text, depth);
        }

        foreach (child; node.children) {
            saveNode(f, child, depth);
        }

        writeIndent(f, --depth);
        f.writeln("</node>");
    }

    private static void writeIndent(File f, ulong depth) {
        foreach (n; 0 .. depth)
            f.write("  ");
    } 

    private static void writeProperty(T)(File f, string property, T value, ulong depth) {
        writeIndent(f, depth);
        f.writeln("<",property,">",value,"</",property,">");
    }

    private static void writeTextProperty(File f, string property, string text, ulong depth) {
        writeIndent(f, depth);
        f.writeln("<",property," ",text.length,">");
        auto split = splitLines(text);
        foreach (line; split) {
            writeIndent(f, depth+1);
            f.writeln("|",line);
        }
        writeIndent(f, depth);
        f.writeln("</",property,">");
    }
}
