using GLib;
int main () {
    var scope = new Unity.SimpleScope ();
    scope.group_name = "org.unityonix.Flatpak";
    scope.unique_name = "/org/unityonix/Flatpak";
    scope.search_hint = "Search Flatpak applications";
    scope.schema = new Unity.Schema ();
    scope.filter_set = new Unity.FilterSet ();
    scope.category_set = new Unity.CategorySet ();
    scope.category_set.add (new Unity.Category ("apps", "Flatpak applications", new ThemedIcon ("system-software-install")));
    scope.set_search_func ((search) => {
        var ctx = search.search_context;
        if (ctx.search_type == Unity.SearchType.GLOBAL) return;
        try {
            string output;
            var process = new Subprocess (SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_SILENCE,
                "@timeout@", "20", "@flatpak@", "search", "--columns=application,name,description,remotes", "--", ctx.search_query == "" ? "editor" : ctx.search_query);
            process.communicate_utf8 (null, null, out output, null);
            int count = 0;
            foreach (var line in output.split ("\n")) {
                var cols = line.split ("\t");
                if (cols.length < 4 || !cols[3].contains ("flathub")) continue;
                Unity.ScopeResult result = Unity.ScopeResult ();
                result.uri = "appstream://" + cols[0];
                result.dnd_uri = result.uri;
                result.icon_hint = "system-software-install";
                result.category = 0;
                result.result_type = Unity.ResultType.DEFAULT;
                result.mimetype = "application/x-flatpak";
                result.title = cols[1];
                result.comment = cols[2];
                result.metadata = new HashTable<string, Variant> (str_hash, str_equal);
                ctx.result_set.add_result (result);
                if (++count == 50) break;
            }
        } catch (Error e) { warning ("Flatpak search: %s", e.message); }
    });
    scope.set_activate_func ((result, metadata, action) => {
        try {
            new Subprocess (SubprocessFlags.NONE, "@software@", "--details=" + result.uri.substring (12));
            return new Unity.ActivationResponse (Unity.HandledType.HIDE_DASH);
        } catch (Error e) { warning ("Software: %s", e.message); }
        return new Unity.ActivationResponse (Unity.HandledType.SHOW_DASH);
    });
    var connector = new Unity.ScopeDBusConnector (scope);
    try { connector.export (); } catch (Error e) { stderr.printf ("%s\n", e.message); return 1; }
    Unity.ScopeDBusConnector.run ();
    return 0;
}
