import std.stdio;

static import gtk.Dialog;
static import gtk.Adjustment;
static import gtk.SpinButton;
static import gtk.CheckButton;
static import gtk.Grid;

import Present, ContentNode;

class PresentColumnDialog {
    gtk.Builder.Builder builder;
    gtk.Dialog.Dialog dialog_size;
    gtk.Grid.Grid dialog_size_grid;

    ColumnSizeButtons[] buttons;

    ContentNode column_group;

    this(gtk.Builder.Builder builder) {
        this.builder = builder;

        dialog_size = cast(gtk.Dialog.Dialog)builder.getObject("column-size-dialog");
        dialog_size_grid = cast(gtk.Grid.Grid)builder.getObject("column-size-dialog-grid");
    }

    void runSize(ContentNode column_group) {
        this.column_group = column_group;

        if (column_group.type != ContentNodeType.COLUMN_GROUP)
            return;

        foreach (i, child; column_group.children) {
            if (i < buttons.length) {
                buttons[i].column = child;
                buttons[i].auto_button.setActive(child.auto_sized ? 1 : 0);
            } else {
                buttons ~= new ColumnSizeButtons(child, this);
                dialog_size_grid.attach(buttons[i].spin_button, 0, cast(int)i, 1, 1);
                dialog_size_grid.attach(buttons[i].auto_button, 1, cast(int)i, 1, 1);
            }
        }

        updateSizes();

        dialog_size_grid.showAll();

        dialog_size.run();

        dialog_size.hide();

        foreach (child; column_group.children)
            app.content.updateDisplayName(child);
    }

    void updateSizes() {
        ulong n_auto;
        ulong taken;
        foreach (child; column_group.children) {
            if (child.auto_sized)
                n_auto++;
            else
                taken += child.column_size;
        }

        ulong split;
        if (taken < 100) {
            split = (100 - taken) / n_auto;
        }

        foreach (i, child; column_group.children) {
            if (child.auto_sized) {
                child.column_size = split;
                buttons[i].update();
            }
        }
    }
}

class ColumnSizeButtons {
    gtk.SpinButton.SpinButton spin_button;
    gtk.Adjustment.Adjustment adjustment;
    gtk.CheckButton.CheckButton auto_button;

    ContentNode column;

    PresentColumnDialog parent;

    this(ContentNode column, PresentColumnDialog parent) {
        this.column = column;
        this.parent = parent;

        adjustment = new gtk.Adjustment.Adjustment(column.column_size, 0, 100, 1, 10, 10);
        spin_button = new gtk.SpinButton.SpinButton(adjustment, 0, 0);
        spin_button.setNumeric(1);
        spin_button.setUpdatePolicy(gtkc.gtktypes.GtkSpinButtonUpdatePolicy.UPDATE_IF_VALID);
        spin_button.setSnapToTicks(1);

        adjustment.addOnValueChanged(&size_changed_action);

        auto_button = new gtk.CheckButton.CheckButton("Auto");
        auto_button.addOnToggled(&auto_toggled_action);

        if (column.auto_sized) {
            spin_button.setSensitive(0);
            auto_button.setActive(1);
        } else {
            spin_button.setSensitive(1);
            auto_button.setActive(0);
        }

        update();
    }

    void auto_toggled_action(gtk.ToggleButton.ToggleButton button) {
        if (button.getActive() == 0) {
            spin_button.setSensitive(1);
            if (column.auto_sized) {
                column.auto_sized = false;
            }
        } else {
            spin_button.setSensitive(0);
            if (!column.auto_sized) {
                column.auto_sized = true;
                parent.updateSizes();
                update();
            }
        }
    }

    void size_changed_action(gtk.Adjustment.Adjustment adjustment) {
        column.column_size = cast(ulong)adjustment.getValue();

        parent.updateSizes();
    }

    void update() {
        adjustment.setValue(column.column_size);
    }
}
