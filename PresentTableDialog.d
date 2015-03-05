import std.conv;
import std.stdio;

static import gtk.Builder;
static import gtk.Dialog;
static import gtk.Grid;
static import gtk.Menu;
static import gtk.MenuButton;
static import gtk.CheckMenuItem;

import ContentNode;

class PresentTableDialog {
    gtk.Builder.Builder builder;
    gtk.Dialog.Dialog size_dialog;
    gtk.Dialog.Dialog border_dialog;

    gtk.Adjustment.Adjustment width_adj, height_adj;

    gtk.Grid.Grid border_grid;
    gtk.Menu.Menu border_menu;
    gtk.CheckMenuItem.CheckMenuItem border_left, border_right,
                                    border_above, border_below;

    ContentNode[][] table;

    BorderButton current;

    BorderButton[] buttons;

    ulong width, height;

    this(gtk.Builder.Builder builder) {
        this.builder = builder;

        size_dialog = cast(gtk.Dialog.Dialog)builder.getObject("table-size-dialog");
        width_adj = cast(gtk.Adjustment.Adjustment)builder.getObject("table-size-width-adjustment");
        height_adj = cast(gtk.Adjustment.Adjustment)builder.getObject("table-size-height-adjustment");

        border_dialog = cast(gtk.Dialog.Dialog)builder.getObject("table-border-dialog");
        border_grid = cast(gtk.Grid.Grid)builder.getObject("table-border-grid");
        border_menu = cast(gtk.Menu.Menu)builder.getObject("table-border-menu");

        border_left = cast(gtk.CheckMenuItem.CheckMenuItem)builder.getObject("table-border-left");
        border_left.addOnToggled(&border_left_toggled);
        border_right = cast(gtk.CheckMenuItem.CheckMenuItem)builder.getObject("table-border-right");
        border_right.addOnToggled(&border_right_toggled);
        border_above = cast(gtk.CheckMenuItem.CheckMenuItem)builder.getObject("table-border-above");
        border_above.addOnToggled(&border_above_toggled);
        border_below = cast(gtk.CheckMenuItem.CheckMenuItem)builder.getObject("table-border-below");
        border_below.addOnToggled(&border_below_toggled);
    }

    bool runSize() {
        auto result = size_dialog.run();

        size_dialog.hide();

        return (result == 0);
    }

    bool runBorder() {

        buildGrid();

        auto result = border_dialog.run();

        border_dialog.hide();

        return (result == 0);
    }

    int getWidth() {
        return to!int(width_adj.getValue());
    }

    int getHeight() {
        return to!int(height_adj.getValue());
    }

    void buildGrid() {

        while (height > 0) {
            border_grid.removeRow(0);
            height--;
        }

        buttons = [];

        foreach (n; 0 .. table.length) {
            border_grid.insertRow(0);
        }

        height = table.length;
        width = table[0].length;

        foreach (int r; 0 .. cast(int)table.length) {
            foreach (int c; 0 .. cast(int)table[r].length) {
                if (table[r][c] !is null) {
                    buttons ~= new BorderButton(this, border_menu, table[r][c]);
                    border_grid.attach(buttons[$-1].button, c, r, table[r][c].weight[0], table[r][c].weight[1]);
                }
            }
        }

        border_grid.showAll();
    }

    void border_left_toggled(gtk.CheckMenuItem.CheckMenuItem item) {
        if (current is null)
            return;

        current.node.border.left = item.getActive() == 1;
        current.update();
    }

    void border_right_toggled(gtk.CheckMenuItem.CheckMenuItem item) {
        if (current is null)
            return;

        current.node.border.right = item.getActive() == 1;
        current.update();
    }

    void border_above_toggled(gtk.CheckMenuItem.CheckMenuItem item) {
        if (current is null)
            return;

        current.node.border.above = item.getActive() == 1;
        current.update();
    }

    void border_below_toggled(gtk.CheckMenuItem.CheckMenuItem item) {
        if (current is null)
            return;

        current.node.border.below = item.getActive() == 1;
        current.update();
    }
}

class BorderButton {
    gtk.MenuButton.MenuButton button;
    gtk.Label.Label label;
    ContentNode node;

    PresentTableDialog parent;

    this(PresentTableDialog parent, gtk.Menu.Menu menu, ContentNode node) {
        this.node = node;
        this.parent = parent;

        button = new gtk.MenuButton.MenuButton();
        button.setPopup(menu);
        button.addOnToggled(&button_toggle_action);

        label = new gtk.Label.Label("");
        button.add(label);

        update();
    }
    
    void button_toggle_action(gtk.ToggleButton.ToggleButton button) {
        if (button.getActive()) {
            parent.current = this;
            parent.border_left.setActive(node.border.left);
            parent.border_right.setActive(node.border.right);
            parent.border_above.setActive(node.border.above);
            parent.border_below.setActive(node.border.below);
        }
    }

    void update() {
        string s;
        if (node.border.left)
            s ~= "L";
        if (node.border.right)
            s ~= "R";
        if (node.border.above)
            s ~= "A";
        if (node.border.below)
            s ~= "B";

        label.setText(s);
    }
}

