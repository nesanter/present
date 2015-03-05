import std.stdio;

static import gtk.Builder;
static import gtk.Dialog;
static import gtk.Button;
static import gtk.TreeView;
static import gtk.ListStore;
static import gtk.ComboBox;

class PresentListingDialog {
    gtk.Builder.Builder builder;
    gtk.Dialog.Dialog dialog_editor;

    gtk.ListStore.ListStore style_model;
    gtk.ListStore.ListStore properties_model;

    gtk.TreeView.TreeView properties_view;

    gtk.Entry.Entry selection_entry;
    gtk.Entry.Entry property_entry;
    gtk.TreeSelection.TreeSelection property_selection;

    ListingStyle[string] styles;
    ListingStyle active_style;

    this(gtk.Builder.Builder builder) {
        this.builder = builder;

        dialog_editor = cast(gtk.Dialog.Dialog)builder.getObject("listing-style-editor-dialog");
        style_model = cast(gtk.ListStore.ListStore)builder.getObject("listing-style-editor-style-model");
        properties_model = cast(gtk.ListStore.ListStore)builder.getObject("listing-style-editor-properties-model");
//        properties_model.addOnRowChanged(&property_changed);
        properties_view = cast(gtk.TreeView.TreeView)builder.getObject("listing-style-editor-view");

        auto value_cell = cast(gtk.CellRendererText.CellRendererText)builder.getObject("listing-style-editor-view-value-renderer");
        value_cell.addOnEdited(&property_changed);

        auto selection_box = cast(gtk.ComboBox.ComboBox)builder.getObject("listing-style-editor-style-select");
        selection_box.addOnChanged(&selection_changed_action);

        selection_entry = cast(gtk.Entry.Entry)builder.getObject("listing-style-editor-style-select-entry");
        property_entry = cast(gtk.Entry.Entry)builder.getObject("listing-style-editor-property-entry");

        property_selection = cast(gtk.TreeSelection.TreeSelection)builder.getObject("listing-style-editor-selection");

        auto add_style = cast(gtk.Button.Button)builder.getObject("listing-style-editor-add-style");
        add_style.addOnClicked(&add_style_action);
        auto remove_style = cast(gtk.Button.Button)builder.getObject("listing-style-editor-remove-style");
        remove_style.addOnClicked(&remove_style_action);
        auto add_property = cast(gtk.Button.Button)builder.getObject("listing-style-editor-add-property");
        add_property.addOnClicked(&add_property_action);
        auto remove_property = cast(gtk.Button.Button)builder.getObject("listing-style-editor-remove-property");
        remove_property.addOnClicked(&remove_property_action);

        setStyle(null);

        /* example style */

        auto demo = new ListingStyle("demo");
        styles["demo"] = demo;

        demo.properties = [
            "language" : "Java",
            "frame" : "single",
            "numbers" : "left",
            "basicstyle" : "\\footnotesize\\ttfamily",
            "keywordstyle" : "\\color{blue!50!black}",
            "commentstyle" : "\\color{green!50!black}"
        ];

        auto iter = new gtk.TreeIter.TreeIter();
        style_model.append(iter);
        style_model.setValue(iter, 0, "demo");
    }

    void runEditor() {
        dialog_editor.run();
        dialog_editor.hide();
    }

    void add_style_action(gtk.Button.Button button) {
        auto name = selection_entry.getText();

        if (name.length == 0)
            return;

        if (name in styles)
            return;

        auto style = new ListingStyle(name);

        auto iter = new gtk.TreeIter.TreeIter();
        style_model.append(iter);

        style_model.setValue(iter, 0, name);

        styles[name] = style;

        setStyle(style);
    }

    void remove_style_action(gtk.Button.Button button) {
        auto name = selection_entry.getText();

        if (name !in styles)
            return;

        styles.remove(name);

        setStyle(null);
    }

    void selection_changed_action(gtk.ComboBox.ComboBox box) {
        auto name = selection_entry.getText();

        if (name in styles)
            setStyle(styles[name]);
    }

    void setStyle(ListingStyle style) {
        active_style = style;

        properties_model.clear();

        if (style is null) {
            properties_view.setSensitive(0);
            return;
        }
        properties_view.setSensitive(1);

        auto iter = new gtk.TreeIter.TreeIter();

        foreach (key, value; style.properties) {
            properties_model.append(iter);
            properties_model.setValue(iter, 0, key);
            properties_model.setValue(iter, 1, value);
        }
    }

    /*
    void property_changed(gtk.TreePath.TreePath path, gtk.TreeIter.TreeIter iter, gtk.TreeModelIF.TreeModelIF model) {
        if (active_style is null)
            return;

        auto key = model.getValueString(iter, 0);
        auto value = model.getValueString(iter, 1);

        active_style.properties[key] = value;

        writeln(key, " = ", value);
    }
    */

    void property_changed(string path, string text, gtk.CellRendererText.CellRendererText renderer) {
        writeln(path);
        writeln(text);

        auto iter = new gtk.TreeIter.TreeIter();
        properties_model.getIterFromString(iter, path);

        auto key = properties_model.getValueString(iter, 0);
        writeln(key);
        properties_model.setValue(iter, 1, text);

        active_style.properties[key] = text;
    }

    void add_property_action(gtk.Button.Button button) {
        if (active_style is null)
            return;

        auto key = property_entry.getText();
        if (key.length == 0)
            return;

        active_style.properties[key] = "";

        auto iter = new gtk.TreeIter.TreeIter();
        properties_model.append(iter);
        properties_model.setValue(iter, 0, key);
        properties_model.setValue(iter, 1, "");
    }

    void remove_property_action(gtk.Button.Button button) {
        if (active_style is null)
            return;

        auto iter = new gtk.TreeIter.TreeIter();
        gtk.TreeModelIF.TreeModelIF model;

        if (property_selection.getSelected(model, iter) == 1) {
            auto key = properties_model.getValueString(iter, 0);
            active_style.properties.remove(key);
            properties_model.remove(iter);
        }
    }
}

class ListingStyle {
    string name;

    string[string] properties;

    this(string name) {
        this.name = name;
    }

    string output() {
        string s = "[";
        bool comma = false;
        foreach (key, value; properties) {
            if (comma)
                s ~= ",";
            comma = true;
            s ~= key~"="~value;
        }
        return s~"]";
    }
}
