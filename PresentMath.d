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

import Present;

enum string completions_file = "completions.txt";

class PresentMath {
    gtk.Builder.Builder builder;
    gtk.Window.Window window;
    gtk.ToolPalette.ToolPalette palette;
    gtk.SearchEntry.SearchEntry entry;
    gtk.TreeStore.TreeStore entry_model;
    string[string] completions;
    gtk.ToolItemGroup.ToolItemGroup[string] tool_groups;
    string[gtk.ToolButton.ToolButton] tool_item_completions;

    this(gtk.Builder.Builder builder) {
        this.builder = builder;
        window = cast(gtk.Window.Window)builder.getObject("math-window");
        palette = cast(gtk.ToolPalette.ToolPalette)builder.getObject("tools-palette");

        entry = cast(gtk.SearchEntry.SearchEntry)builder.getObject("math-entry");
        entry_model = cast(gtk.TreeStore.TreeStore)builder.getObject("math-entry-model");
        
        try {
            File f = File(completions_file, "r");

            foreach (line; f.byLine) {
                line = strip(line);
                if (line.length == 0 || line[0] == ';')
                    continue;

                if (line[0] == '*') {
                    if (line.length < 2) {
                        writeln("cannot parse completion "~line);
                        continue;
                    }
                    if (line[1] == 'g') {
                        if (line[1 .. $] in tool_groups) {
                            writeln("ignoring duplicate tool group "~line[2 .. $]);
                        } else {
                            auto group = new gtk.ToolItemGroup.ToolItemGroup(to!string(line[2 .. $]));
                            tool_groups[to!string(line[2 .. $])] = group;
                            palette.add(group);
                        }
                        continue;
                    }
                    auto ind = lastIndexOf(line, ':');
                    if (ind == -1 || ((ind + 1) >= line.length)) {
                        writeln("cannot parse completion "~line);
                        continue;
                    }

                    auto ind2 = lastIndexOf(line, ',');

                    string c, n;
                    if (ind2 == -1 || ((ind + 1) >= line.length)) {
                        c = to!string(line[ind + 1 .. $]);
                        n = to!string(line[ind + 1 .. $]);
                    } else {
                        c = to!string(line[ind + 1 .. ind2]);
                        n = to!string(line[ind2 + 1 .. $]);
                    }

                    gtk.ToolButton.ToolButton item;

                    if (line[1] == 'b') {
                        item = new gtk.ToolButton.ToolButton(null, n);
                    } else if (line[1] == 'm') {
                        item = new gtk.MenuToolButton.MenuToolButton(null, n);
                    } else {
                        writeln("cannot parse completion "~line);
                        continue;
                    }

                    item.addOnClicked(&tool_completion_action);
                    tool_item_completions[item] = c;

                    if (line[2 .. ind] in tool_groups) {
                        tool_groups[to!string(line[2 .. ind])].insert(item, -1);
                    } else {
                        writeln("no such tool group "~line[2 .. ind]);
                        continue;
                    }
                    continue;
                }

                auto ind = indexOf(line, ':');
                if (ind == -1 || ((ind + 1) >= line.length)) {
                    writeln("cannot parse completion "~line);
                    continue;
                }

                string name = to!string(line[0..ind]);
                string latex = to!string(line[ind+1..$]);

                completions[name] = latex;

                auto iter = entry_model.append(null);
                entry_model.setValue(iter, 0, name);
                entry_model.setValue(iter, 1, latex);
            }
        } catch (ErrnoException e) {
            writeln("Unable to open completions.txt");
        }

        entry.addOnActivate(&entry_activate_action);

        window.addOnDelete(&delete_action);

        disable();
    }

    void show() {
        window.showAll();
    }

    void hide() {
        window.hide();
    }

    void entry_activate_action(gtk.Entry.Entry entry) {
        auto s = entry.getText();

        if (s in completions) {
            app.content.insertCompletion(completions[s]);

            app.editor.setBuffer(app.content.current_node.buffer);
            app.updateContext();
        }
    }

    void enable() {
        palette.setSensitive(1);
        entry.setSensitive(1);
//        palette.showAll();

        if (window.getVisible() == 1) {
//            window.present();
            entry.grabFocus();
        }
    }
    
    void disable() {
        palette.setSensitive(0);
        entry.setSensitive(0);
    }

    bool delete_action(gdk.Event.Event event, gtk.Widget.Widget widget) {
        auto toggle_item = cast(gtk.CheckMenuItem.CheckMenuItem)builder.getObject("file-toggle-math");
        toggle_item.setActive(0);
        return (widget.hideOnDelete() == 1);
    }

    void tool_completion_action(gtk.ToolButton.ToolButton button) {
        auto s = tool_item_completions[button];

        if (s in completions) {
            app.content.insertCompletion(completions[s]);

            app.editor.setBuffer(app.content.current_node.buffer);
            app.updateContext();
            app.main_window.present();
        }
    }
}


