#!/usr/bin/env python3
"""Unity Appearance: schema-validated controls for the Unity desktop."""
import json
import os
from pathlib import Path
import re
import sys
import gi
gi.require_version('Gtk', '3.0')
from gi.repository import Gio, GLib, Gtk, Gdk

GROUPS = {
    'Appearance': [('GTK, icons and fonts', 'org.gnome.desktop.interface'), ('Window decorations', 'org.gnome.desktop.wm.preferences'), ('Font rendering', 'org.gnome.settings-daemon.plugins.xsettings'), ('Wallpaper', 'org.gnome.desktop.background')],
    'Launcher and Dash': [('Launcher and switcher', 'org.compiz.unityshell'), ('Launcher', 'com.canonical.Unity.Launcher'), ('Dash search', 'com.canonical.Unity.Lenses'), ('Applications', 'com.canonical.Unity.ApplicationsLens'), ('Files', 'com.canonical.Unity.FilesLens'), ('Run command', 'com.canonical.Unity.Runner'), ('HUD', 'com.canonical.indicator.appmenu.hud')],
    'Panel': [('Clock', 'com.canonical.indicator.datetime'), ('Bluetooth', 'com.canonical.indicator.bluetooth'), ('Power', 'com.canonical.indicator.power'), ('Sound', 'com.canonical.indicator.sound'), ('Session', 'com.canonical.indicator.session'), ('Notifications', 'com.canonical.notify-osd')],
    'Windows': [('General and shortcuts', 'org.compiz.core'), ('Animations', 'org.compiz.animation'), ('Rendering', 'org.compiz.opengl'), ('Window spread', 'org.compiz.scale'), ('Zoom', 'org.compiz.ezoom'), ('Moving windows', 'org.compiz.move'), ('Resizing windows', 'org.compiz.resize'), ('Window snapping', 'org.compiz.grid')],
    'Workspaces': [('Workspace overview', 'org.compiz.expo'), ('Workspace switching', 'org.compiz.wall')],
    'System': [('Desktop icons', 'org.nemo.desktop'), ('Touchpad', 'org.gnome.desktop.peripherals.touchpad'), ('Mouse', 'org.gnome.desktop.peripherals.mouse'), ('Security', 'org.gnome.desktop.lockdown'), ('Scrolling', 'com.canonical.desktop.interface')],
}
SOURCE = Gio.SettingsSchemaSource.get_default()
CATALOGUE = json.loads((Path(__file__).resolve().parent / 'settings.json').read_text())
CHOICES = json.loads((Path(__file__).resolve().parent / 'choices.json').read_text())
LIMITS = {('org.compiz.unityshell', 'icon-size'): (8, 64)}

def valid_value(schema_id, key, spec, variant):
    if not spec.range_check(variant):
        return False
    bounds = LIMITS.get((schema_id, key))
    return bounds is None or bounds[0] <= variant.unpack() <= bounds[1]


def settings_for(schema_id, profile=None):
    schema = SOURCE.lookup(schema_id, True) if SOURCE else None
    if schema is None:
        return None, None
    path = None
    if schema.get_path() is None:
        if not schema_id.startswith('org.compiz.'):
            return schema, None
        path = f'/org/compiz/profiles/{profile}/plugins/{schema_id.removeprefix("org.compiz.")}/'
    return schema, Gio.Settings.new_full(schema, None, path)


def active_profile():
    schema, settings = settings_for('org.compiz')
    profile = settings.get_string('current-profile') if schema and schema.has_key('current-profile') else None
    if not profile or '/' in profile:
        raise RuntimeError('The active Compiz profile is unavailable. Start this tool inside Unity.')
    return profile


def theme_names(kind):
    roots = [Path(GLib.get_user_data_dir())] + [Path(p) for p in GLib.get_system_data_dirs()]
    roots += [Path('/run/current-system/sw/share'), Path.home() / '.nix-profile/share', Path('/etc/profiles/per-user') / GLib.get_user_name() / 'share']
    folders = [r / ('icons' if kind in ('icon', 'cursor') else 'themes') for r in roots]
    folders.append(Path.home() / ('.icons' if kind in ('icon', 'cursor') else '.themes'))
    names = set()
    for folder in folders:
        try:
            for entry in folder.iterdir():
                match = {'gtk': entry / 'gtk-3.0', 'window': entry / 'metacity-1', 'icon': entry / 'index.theme', 'cursor': entry / 'cursors'}[kind]
                if match.exists():
                    names.add(entry.name)
        except OSError:
            continue
    return sorted(names, key=str.casefold)


class Appearance(Gtk.Window):
    def __init__(self):
        super().__init__(title='Unity Appearance')
        self.set_default_size(1000, 720)
        self.set_border_width(12)
        self.rows = []
        self.connections = []
        try:
            self.profile = active_profile()
            profile_error = None
        except RuntimeError as error:
            self.profile, profile_error = None, str(error)
        root = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        self.add(root)
        self.search = Gtk.SearchEntry(placeholder_text='Find a setting…')
        root.pack_start(self.search, False, False, 0)
        actions = Gtk.Box(spacing=8)
        apply = Gtk.Button(label='Apply')
        apply.set_tooltip_text('Save all changed settings and refresh Unity')
        apply.connect('clicked', self.apply_changes)
        reset = Gtk.Button(label='Reset visible settings')
        reset.connect('clicked', self.reset_visible)
        actions.pack_end(apply, False, False, 0)
        actions.pack_end(reset, False, False, 0)
        root.pack_start(actions, False, False, 0)
        if profile_error:
            root.pack_start(Gtk.Label(label=profile_error, wrap=True), False, False, 0)
        self.status = Gtk.Label(xalign=0, wrap=True)
        root.pack_end(self.status, False, False, 0)
        content = Gtk.Box(spacing=12)
        root.pack_start(content, True, True, 0)
        self.stack = Gtk.Stack()
        sidebar = Gtk.StackSidebar(stack=self.stack)
        content.pack_start(sidebar, False, False, 0)
        content.pack_start(self.stack, True, True, 0)
        for page, groups in GROUPS.items():
            box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=18)
            box.set_border_width(8)
            scroll = Gtk.ScrolledWindow()
            scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
            scroll.add(box)
            self.stack.add_titled(scroll, page, page)
            for title, schema_id in groups:
                heading = Gtk.Label(xalign=0)
                heading.set_markup('<b>' + GLib.markup_escape_text(title) + '</b>')
                box.pack_start(heading, False, False, 0)
                schema, settings = settings_for(schema_id, self.profile)
                if not settings or (schema.get_path() is None and not self.profile):
                    box.pack_start(Gtk.Label(label='Unavailable in this build', xalign=0), False, False, 0)
                    continue
                for key in CATALOGUE.get(schema_id, []):
                    if schema.has_key(key):
                        self.add_control(box, title, schema_id, schema, settings, key)
                    else:
                        box.pack_start(Gtk.Label(label=f'{key.replace("-", " ")}: unavailable in this build', xalign=0), False, False, 0)
        self.search.connect('search-changed', self.filter_rows)
        self.connect('destroy', Gtk.main_quit)

    def apply_changes(self, _button):
        Gio.Settings.sync()
        self.status.set_text('Settings applied. Unity components will refresh where supported.')

    def reset_visible(self, _button):
        count = 0
        for _, row in self.rows:
            if row.get_visible():
                for child in row.get_children():
                    if isinstance(child, Gtk.Button) and child.get_label() == 'Reset' and child.get_sensitive():
                        child.emit('clicked')
                        count += 1
        Gio.Settings.sync()
        self.status.set_text(f'Reset {count} visible settings.')

    def filter_rows(self, entry):
        query = entry.get_text().casefold()
        for text, row in self.rows:
            row.set_visible(query in text)

    def add_control(self, box, group, schema_id, schema, settings, key):
        spec = schema.get_key(key)
        row = Gtk.Box(spacing=10)
        row.set_valign(Gtk.Align.START)
        label = spec.get_summary() or key.replace('-', ' ').capitalize()
        labels = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=3)
        labels.set_size_request(260, -1)
        heading = Gtk.Label(label=label, xalign=0, wrap=True)
        labels.pack_start(heading, False, False, 0)
        description = spec.get_description() or ''
        row.set_tooltip_text(description or label)
        row.pack_start(labels, True, True, 0)
        self.rows.append((f'{group} {label} {description} {key}'.casefold(), row))
        error = Gtk.Label(xalign=0, wrap=True)
        labels.pack_start(error, False, False, 0)
        updating = [False]
        value = settings.get_value(key)
        signature = value.get_type_string()
        current = value.unpack()
        range_type, allowed = spec.get_range().unpack()

        def commit(value):
            if updating[0]:
                return
            try:
                variant = GLib.Variant(signature, value)
                if not valid_value(schema_id, key, spec, variant):
                    raise ValueError('Value is outside the supported range')
                if not settings.set_value(key, variant):
                    raise ValueError('This setting is locked')
                Gio.Settings.sync()
                error.set_text('')
                self.status.set_text(f'Updated {label}')
            except (ValueError, TypeError, GLib.Error, OverflowError) as exc:
                error.set_text(str(exc))

        if schema_id + ':' + key in CHOICES:
            choices = CHOICES[schema_id + ':' + key]
            if current not in [v for v, _ in choices]:
                choices = choices + [[current, str(current)]]
            widget = Gtk.ComboBoxText()
            for i, (_, title) in enumerate(choices):
                widget.append(str(i), title)
            read = lambda v: widget.set_active(next((i for i, (x, _) in enumerate(choices) if x == v), -1))
            widget.connect('changed', lambda w: commit(choices[w.get_active()][0]) if w.get_active() >= 0 else None)
        elif signature == 'b':
            widget = Gtk.Switch(valign=Gtk.Align.CENTER)
            read = widget.set_active
            widget.connect('notify::active', lambda w, _: commit(w.get_active()))
        elif range_type == 'enum':
            widget = Gtk.ComboBoxText()
            for item in allowed:
                widget.append(item, item.replace('-', ' ').capitalize())
            read = widget.set_active_id
            widget.connect('changed', lambda w: commit(w.get_active_id()))
        elif key in ('gtk-theme', 'icon-theme', 'cursor-theme') or (key == 'theme' and schema_id.endswith('wm.preferences')):
            kind = {'gtk-theme': 'gtk', 'icon-theme': 'icon', 'cursor-theme': 'cursor', 'theme': 'window'}[key]
            widget = Gtk.ComboBoxText.new_with_entry()
            for name in sorted(set(theme_names(kind) + [current])):
                widget.append_text(name)
            read = widget.get_child().set_text
            widget.connect('changed', lambda w: commit(w.get_active_text()) if w.get_active() >= 0 else None)
            widget.get_child().connect('activate', lambda w: commit(w.get_text()))
        elif signature == 's' and ('font-name' in key or key == 'titlebar-font'):
            widget = Gtk.FontButton()
            read = widget.set_font_name
            widget.connect('font-set', lambda w: commit(w.get_font_name()))
        elif signature == 's' and ('color' in key) and re.fullmatch(r'#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?', current or ''):
            widget = Gtk.ColorButton(use_alpha=True)
            def read(v):
                color = Gdk.RGBA()
                color.parse(v)
                widget.set_rgba(color)
            def color_changed(w):
                color = w.get_rgba()
                parts = [color.red, color.green, color.blue]
                if len(current) == 9:
                    parts.append(color.alpha)
                commit('#' + ''.join(f'{round(v * 255):02x}' for v in parts))
            widget.connect('color-set', color_changed)
        elif signature in ('i', 'u', 'd'):
            low, high = allowed if range_type == 'range' else ((0, 4294967295) if signature == 'u' else (-2147483648, 2147483647))
            low, high = LIMITS.get((schema_id, key), (low, high))
            widget = Gtk.SpinButton.new_with_range(low, high, 0.05 if signature == 'd' else 1)
            widget.set_digits(2 if signature == 'd' else 0)
            # Commit on Enter or focus-out so typing does not apply partial values.
            read = widget.set_value
            def save_number(w):
                w.update()
                commit(w.get_value() if signature == 'd' else int(w.get_value()))
            widget.connect('activate', save_number)
            widget.connect('focus-out-event', lambda w, _: (save_number(w), False)[1])
        else:
            editor = Gtk.Entry()
            widget = Gtk.Box(spacing=4)
            widget.pack_start(editor, True, True, 0)
            apply = Gtk.Button(label='Apply')
            widget.pack_end(apply, False, False, 0)
            if signature == 's':
                read = editor.set_text
                get = editor.get_text
            elif signature == 'as':
                read = lambda v: editor.set_text(json.dumps(v))
                get = lambda: json.loads(editor.get_text())
                editor.set_tooltip_text('List of strings, for example ["TopLeft", "BottomRight"]')
            else:
                read = lambda v: editor.set_text(GLib.Variant(signature, v).print_(True))
                get = lambda: GLib.Variant.parse(GLib.VariantType(signature), editor.get_text(), None, None).unpack()
            def save(_):
                try:
                    commit(get())
                except (ValueError, TypeError, GLib.Error) as exc:
                    error.set_text(str(exc))
            apply.connect('clicked', save)
            editor.connect('activate', save)
        widget.set_size_request(280, -1)
        widget.set_sensitive(settings.is_writable(key))
        row.pack_start(widget, False, False, 0)
        reset = Gtk.Button(label='Reset')
        reset.set_tooltip_text('Restore the default for this setting')
        reset.set_sensitive(settings.is_writable(key))
        reset.connect('clicked', lambda _: settings.reset(key))
        row.pack_end(reset, False, False, 0)
        def refresh(*_):
            updating[0] = True
            try:
                read(settings.get_value(key).unpack())
            finally:
                updating[0] = False
        refresh()
        handler = settings.connect('changed::' + key, refresh)
        self.connections.append((settings, handler))
        box.pack_start(row, False, False, 0)


if __name__ == '__main__':
    if '--self-test' in sys.argv:
        if os.environ.get('GSETTINGS_BACKEND') != 'memory':
            raise RuntimeError('Self-test requires GSETTINGS_BACKEND=memory')
        window = Appearance()
        window.show_all()
        while Gtk.events_pending():
            Gtk.main_iteration_do(False)
        schema, settings = settings_for('org.compiz.unityshell', active_profile())
        assert schema.has_key('icon-size')
        original = settings.get_int('icon-size')
        assert settings.set_int('icon-size', 40 if original != 40 else 48)
        assert settings.get_int('icon-size') != original
        settings.reset('icon-size')
        assert settings.get_int('icon-size') == original
        assert not valid_value('org.compiz.unityshell', 'icon-size', schema.get_key('icon-size'), GLib.Variant('i', -1))
        assert settings_for('org.unityonix.Missing')[0] is None
        print(f'PASS: {len(window.rows)} controls constructed; dock size write/reset and range validation')
        screenshot = os.environ.get('UNITY_APPEARANCE_SCREENSHOT')
        if screenshot:
            Gdk.pixbuf_get_from_window(window.get_window(), 0, 0, window.get_allocated_width(), window.get_allocated_height()).savev(screenshot, 'png', [], [])
    elif '--inventory' in sys.argv:
        profile = active_profile()
        report = {}
        for groups in GROUPS.values():
            for _, schema_id in groups:
                schema, _ = settings_for(schema_id, profile)
                report[schema_id] = sorted(schema.list_keys()) if schema else []
        print(json.dumps(report, indent=2))
    else:
        window = Appearance()
        window.show_all()
        Gtk.main()
