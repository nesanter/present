import std.stdio;
import std.exception;

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
        saveNode(f, c.root_node);
        f.writeln("</content>");

        return true;
    }

    static bool load(Content c, string filename) {
        return false;
    }

    private static void saveNode(File f, ContentNode node) {
        f.writeln("<node>");
        writeProperty(f, "type", node.type);
        writeProperty(f, "id", node.id);
        writeProperty(f, "cid", node.cid);

        if (node.latex.length > 0) {
            writeProperty(f, "latex", node.latex);
        }

        final switch (node.context) {
            case ContextType.MATH:
            case ContextType.NONE:
            case ContextType.ANIM_GROUP:
                break;
            case ContextType.LIST:
                writeProperty(f, "list_type", node.list_type);
                break;
            case ContextType.TABLE:
                writeProperty(f, "table_width", node.table_width);
                writeProperty(f, "table_height", node.table_height);
                writeProperty(f, "weight", node.weight);
                writeProperty(f, "border_left", node.border.left);
                writeProperty(f, "border_right", node.border.right);
                writeProperty(f, "border_above", node.border.above);
                writeProperty(f, "border_below", node.border.below);
                break;
            case ContextType.COLUMN:
                writeProperty(f, "auto_sized", node.auto_sized);
                writeProperty(f, "top_aligned", node.top_aligned);
                writeProperty(f, "column_size", node.column_size);
                break;
            case ContextType.LISTING:
                writeProperty(f, "listing_tyle", node.listing_style.name);
                break;
            case ContextType.TIKZ:
                writeProperty(f, "tikz_properties", node.tikz_properties);
                break;
        }

        if (node.editable) {
            string text = node.getText();
            f.writeln("<text ",text.length,">");
            f.writeln(text);
            f.writeln("</text>");
        }

        foreach (child; node.children) {
            saveNode(f, child);
        }

        f.writeln("</node>");
    }

    private static void writeProperty(T)(File f, string property, T value) {
        f.writeln("<",property,">",value,"</",property,">");
    }
}
