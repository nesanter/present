import std.stdio;
import std.exception;
import std.string;
import std.conv;
import std.path;

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
//        saveNode(f, c.root_node, 1);
        foreach (child; c.root_node.children)
            saveNode(f, child, 1);
        f.writeln("</content>");

        return true;
    }

    static bool load(Content c, string filename) {
        File f;
        try {
            f = File(filename, "r");
        } catch (ErrnoException e) {
            return false;
        }

        while (!f.eof) {
            auto line = clean(f.readln());
            if (line == "<content>") {
                if (!loadContent(f, c))
                    return false;
            }
        }

        c.current_filename = filename;
        c.current_basename = baseName(filename);

        return true;
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

        if (node.custom_display_name.length > 0) {
            writeProperty(f, "custom_display_name", node.custom_display_name, depth);
        }

        if (node.custom_inline_name.length > 0) {
            writeProperty(f, "custom_inline_name", node.custom_inline_name, depth);
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
            case ContextType.MATH_TABLE:
                if (node.math_environment != "")
                    writeProperty(f, "math_environment", node.math_environment, depth);
                break;
        }

        string text = node.getText();
        /*
           f.writeln("<text ",text.length,">");
           f.writeln(text);
           f.writeln("</text>");
         */
        writeTextProperty(f, "text", text, depth);

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
        f.writeln(property,"=",value);
    }

    private static void writeTextProperty(File f, string property, string text, ulong depth) {
        writeIndent(f, depth);
        auto split = splitLines(text);
        f.writeln(property,"{");
        foreach (line; split) {
            writeIndent(f, depth+1);
            f.writeln("|",line);
        }
        writeIndent(f, depth);
        f.writeln("}");
    }

    private static bool loadContent(File f, Content c) {
        while (!f.eof) {
            auto line = clean(f.readln());
            if (line == "<node>") {
                auto node = loadNode(f, c);
                if (node is null)
                    return false;
                auto n = c.root_node.addLoadedChild(node);
                c.addToModel(node, null, n, false);
                c.updateModel(node);
                node.initBuffers();
            } else if (line == "</content>") {
                return true;
            }
        }

        return false;
    }

    private static ContentNode loadNode(File f, Content c) {
        bool not;
        string key, value;

        ContentNode node = new ContentNode(c.tag_table);

        while (!f.eof) {
            key = readProperty(f, value, not);
            if (not) {
                if (key == "</node>") {
                    writeln("loaded ", node);
                    return node;
                } else if (key == "<node>") {
                    auto child = loadNode(f, c);
                    if (child is null)
                        return null;
                    writeln("added child ",node);
                    auto n = node.addLoadedChild(child);
//                    c.addToModel(child, node, n, false);
                }
            } else {
                try {
                    switch (key) {
                        case "type":
                            node.type = to!ContentNodeType(value);
                            break;
                        case "cid":
                            node.cid = to!int(value);
                            break;
                        case "id":
                            node.id = to!ulong(value);
                            c.node_by_id[node.id] = node;
                            break;
                        case "latex":
                            node.latex = value;
                            break;
                        case "custom_display_name":
                            node.custom_display_name = value;
                            break;
                        case "custom_inline_name":
                            node.custom_inline_name = value;
                            break;
                        case "list_type":
                            node.list_type = value;
                            break;
                        case "table_width":
                            node.table_width = to!int(value);
                            break;
                        case "table_height":
                            node.table_height = to!int(value);
                            break;
                        case "weight":
                            node.weight = to!(int[2])(value);
                            break;
                        case "border_left":
                            node.border.left = to!bool(value);
                            break;
                        case "border_right":
                            node.border.right = to!bool(value);
                            break;
                        case "border_above":
                            node.border.above = to!bool(value);
                            break;
                        case "border_below":
                            node.border.below = to!bool(value);
                            break;
                        case "auto_sized":
                            node.auto_sized = to!bool(value);
                            break;
                        case "top_aligned":
                            node.top_aligned = to!bool(value);
                            break;
                        case "column_size":
                            node.column_size = to!ulong(value);
                            break;
                        case "listing_style":
                            //ignore for the moment
                            //node.listing_style = value;
                            break;
                        case "text":
                            node.buffer.setText(value);
                            break;
                        default:
                            writeln("Unknown key "~key);
                            break;
                    }
                } catch (ConvException ce) {
                    writeln("Bad value "~value~" for key "~key);
                }
            }
        }

        return null;
    }

    private static string readProperty(File f, out string value, out bool not_property) {
        auto line = clean(f.readln());
        auto ind = indexOf(line, "=");
        if (ind == -1) {
            ind = indexOf(line, "{");
            if (ind == -1) {
                not_property = true;
                return line;
            } else {
                value = readTextProperty(f);
                return line[0 .. ind];
            }
        }

        auto key = line[0 .. ind];

        if (line.length == ind+1) {
            value = "";
            return key;
        }

        value = line[ind+1 .. $];
        return key;
    }

    private static string readTextProperty(File f) {
        string s;
        while (!f.eof) {
            auto line = stripLeft(f.readln());
            if (line.length == 0)
                continue;
            if (line[0] == '|') {
                s ~= line[1 .. $];
            } else if (line[0] == '}') {
                break;
            }
        }
        return s;
    }

    private static string clean(string input) {
        return chomp(stripLeft(input));
    }
}
