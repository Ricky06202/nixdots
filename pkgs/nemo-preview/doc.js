/*
 * Vista previa de documentos de oficina (docx/xlsx/pptx/odt/ods/odp/rtf…)
 * para nemo-preview.
 *
 * nemo-preview no sabe renderizar Office, así que convertimos a PDF con
 * LibreOffice headless (perfil propio por preview: si usara el perfil del
 * usuario y LibreOffice estuviera abierto, `--convert-to` se lo mandaría a la
 * ventana en vez de convertir) y rasterizamos las páginas con pdftoppm.
 *
 * La ventana muestra: barra lateral con miniaturas de todas las páginas
 * (clicable) + la página actual. Todo es GTK dentro de un GtkClutter.Actor,
 * así que el scroll y los clics los maneja GTK.
 */

imports.gi.versions.Gtk = '3.0';

const Gtk = imports.gi.Gtk;
const Gdk = imports.gi.Gdk;
const GdkPixbuf = imports.gi.GdkPixbuf;
const GtkClutter = imports.gi.GtkClutter;
const GLib = imports.gi.GLib;
const Gio = imports.gi.Gio;

const Lang = imports.lang;

const MimeHandler = imports.ui.mimeHandler;

const SOFFICE = '@soffice@';
const PDFTOPPM = '@pdftoppm@';

const THUMB_WIDTH = 96;    /* ancho de las miniaturas de la barra lateral */
const MAX_PAGES = 60;      /* tope de páginas rasterizadas (rendimiento) */
const TIMEOUT_S = 30;      /* si LibreOffice se cuelga, degradamos */

function DocRenderer(args) {
    this._init(args);
}

DocRenderer.prototype = {
    _init : function(args) {
        this.moveOnClick = true;
        this.canFullScreen = true;
        this._proc = null;
        this._timeoutId = 0;
        this._tmpDir = null;
        this._actor = null;
        this._pages = [];
        this._pageW = 0;
        this._pageH = 0;
        this._done = false;
    },

    prepare : function(file, mainWindow, callback) {
        this._mainWindow = mainWindow;
        this._callback = callback;
        this._done = false;

        let path = file.get_path();
        if (!path) {
            this._degraded();
            return;
        }

        try {
            this._tmpDir = GLib.dir_make_tmp('nemo-preview-doc-XXXXXX');
        } catch (e) {
            logError(e, 'nemo-preview-doc: no se pudo crear el directorio temporal');
            this._degraded();
            return;
        }

        /* nombre del PDF que va a producir LibreOffice */
        let base = GLib.path_get_basename(path).replace(/\.[^.]*$/, '');
        this._pdfPath = GLib.build_filenamev([ this._tmpDir, base + '.pdf' ]);

        let argv = [ SOFFICE,
                     '--headless', '--norestore', '--invisible',
                     '-env:UserInstallation=file://' + this._tmpDir + '/profile',
                     '--convert-to', 'pdf',
                     '--outdir', this._tmpDir,
                     path ];

        this._timeoutId = GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, TIMEOUT_S,
            Lang.bind(this, function() {
                this._timeoutId = 0;
                if (!this._done && this._proc) {
                    log('nemo-preview-doc: LibreOffice tardó demasiado, se cancela');
                    try {
                        this._proc.force_exit();
                    } catch (e) {
                    }
                    this._degraded();
                }
                return false;
            }));

        this._spawn(argv, Lang.bind(this, function(ok) {
            if (!ok) {
                this._degraded();
                return;
            }
            this._rasterize();
        }));
    },

    _spawn : function(argv, callback) {
        let proc;
        try {
            proc = Gio.Subprocess.new(argv,
                Gio.SubprocessFlags.STDOUT_SILENCE |
                Gio.SubprocessFlags.STDERR_SILENCE);
        } catch (e) {
            logError(e, 'nemo-preview-doc: no se pudo lanzar ' + argv[0]);
            callback(false);
            return;
        }

        this._proc = proc;
        proc.wait_check_async(null, Lang.bind(this, function(p, res) {
            let ok = false;
            try {
                ok = p.wait_check_finish(res);
            } catch (e) {
                ok = false;
            }
            this._proc = null;
            callback(ok);
        }));
    },

    _rasterize : function() {
        if (!GLib.file_test(this._pdfPath, GLib.FileTest.EXISTS)) {
            log('nemo-preview-doc: LibreOffice no generó el PDF');
            this._degraded();
            return;
        }

        /* OJO: nemo-preview solo ofrece 800x600 como "espacio disponible" y la
         * ventana final la decide lo que devolvamos, así que el tamaño hay que
         * fijarlo aquí (rasterizando la página a un presupuesto), no recortando
         * después la textura: si recortamos, la página queda cortada. */
        /* OJO con las medidas en XWayland: Gdk.Screen devuelve la pantalla X
         * (3840x1080 con escala 2, medidas raras); el workarea del monitor sí
         * viene en píxeles lógicos (1920x1080). */
        let display = Gdk.Display.get_default();
        let monitor = display ? display.get_primary_monitor() : null;
        let geo = monitor ? monitor.get_workarea() : null;
        let sh = geo ? geo.height : 1080;
        let budgetH = Math.max(320, Math.round(sh * 0.70) - 40);

        /* OJO: -scale-to-x + -scale-to-y a la vez DEFORMA la página (estira);
         * con -scale-to-y solo se respeta el aspecto y el ancho sale solo. */
        let argv = [ PDFTOPPM, '-png',
                     '-scale-to-y', String(budgetH),
                     '-l', String(MAX_PAGES),
                     this._pdfPath,
                     GLib.build_filenamev([ this._tmpDir, 'page' ]) ];

        this._spawn(argv, Lang.bind(this, function(ok) {
            if (!ok) {
                this._degraded();
                return;
            }
            if (!this._collectPages()) {
                this._degraded();
                return;
            }
            this._buildUI();
        }));
    },

    _collectPages : function() {
        let dir;
        try {
            dir = GLib.Dir.open(this._tmpDir, 0);
        } catch (e) {
            return false;
        }

        let names = [];
        let name;
        while ((name = dir.read_name()) != null) {
            if (/^page-\d+\.png$/.test(name))
                names.push(name);
        }

        if (names.length == 0)
            return false;

        names.sort(function(a, b) {
            return parseInt(a.match(/(\d+)/)[1], 10) - parseInt(b.match(/(\d+)/)[1], 10);
        });

        this._pages = names.map(Lang.bind(this, function(n) {
            return GLib.build_filenamev([ this._tmpDir, n ]);
        }));
        return true;
    },

    _buildUI : function() {
        let info = GdkPixbuf.Pixbuf.get_file_info(this._pages[0]);
        this._pageW = info[1] || 600;
        this._pageH = info[2] || 800;

        let mainImage = new Gtk.Image({ margin: 0 });
        mainImage.set_from_file(this._pages[0]);

        let viewer = new Gtk.ScrolledWindow({
            hscrollbar_policy: Gtk.PolicyType.AUTOMATIC,
            vscrollbar_policy: Gtk.PolicyType.AUTOMATIC,
        });
        viewer.add(mainImage);

        let list = new Gtk.ListBox({ selection_mode: Gtk.SelectionMode.SINGLE });
        list.get_style_context().add_class('sidebar');

        this._pages.forEach(Lang.bind(this, function(pagePath) {
            let row = new Gtk.ListBoxRow();
            row.set_margin_top(2);
            row.set_margin_bottom(2);

            let pix = GdkPixbuf.Pixbuf.new_from_file_at_scale(pagePath,
                THUMB_WIDTH, -1, true);
            let img = new Gtk.Image({ pixbuf: pix });
            img.set_margin_start(4);
            img.set_margin_end(4);
            row.add(img);
            list.add(row);
        }));

        list.connect('row-selected', Lang.bind(this, function(lb, row) {
            if (!row)
                return;
            let idx = row.get_index();
            if (this._pages[idx])
                mainImage.set_from_file(this._pages[idx]);
        }));

        let sidebar = new Gtk.ScrolledWindow({
            hscrollbar_policy: Gtk.PolicyType.NEVER,
            vscrollbar_policy: Gtk.PolicyType.AUTOMATIC,
        });
        sidebar.add(list);
        sidebar.set_size_request(THUMB_WIDTH + 20, -1);

        let box = new Gtk.Box({
            orientation: Gtk.Orientation.HORIZONTAL,
            spacing: 6,
            border_width: 0,
        });
        box.pack_start(sidebar, false, false, 0);
        box.pack_start(viewer, true, true, 0);
        box.show_all();

        list.select_row(list.get_row_at_index(0));

        this._actor = new GtkClutter.Actor({ contents: box });
        this._actor.set_reactive(true);

        this._finish();
    },

    render : function() {
        return this._actor;
    },

    getSizeForAllocation : function(allocation) {
        /* la página ya viene rasterizada al presupuesto de pantalla, así que el
         * tamaño natural cabe: barra lateral + página */
        return [ Math.max(this._pageW + THUMB_WIDTH + 26, 200),
                 Math.max(this._pageH, 200) ];
    },

    _finish : function() {
        if (this._done)
            return;
        this._done = true;

        if (this._timeoutId) {
            GLib.source_remove(this._timeoutId);
            this._timeoutId = 0;
        }

        this._callback();
    },

    /* fallback: textura transparente 1x1 (el título sigue mostrando el nombre) */
    _degraded : function() {
        if (!this._actor) {
            let pix = GdkPixbuf.Pixbuf.new(GdkPixbuf.Colorspace.RGB, true, 8, 1, 1);
            pix.fill(0x00000000);
            let tex = new GtkClutter.Texture({ keep_aspect_ratio: true });
            tex.set_from_pixbuf(pix);
            this._actor = tex;
            this._pageW = 1;
            this._pageH = 1;
        }
        this._finish();
    },

    _cleanup : function() {
        if (this._proc) {
            try {
                this._proc.force_exit();
            } catch (e) {
            }
            this._proc = null;
        }

        if (this._tmpDir) {
            try {
                GLib.spawn_command_line_sync('rm -rf -- ' + this._tmpDir);
            } catch (e) {
            }
            this._tmpDir = null;
        }
    },

    clear : function() {
        this._cleanup();
    },

    destroy : function() {
        this._cleanup();
    },
}

let handler = new MimeHandler.MimeHandler();
let renderer = new DocRenderer();

let mimeTypes = [
    /* writer */
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/msword',
    'application/rtf',
    'application/vnd.oasis.opendocument.text',
    /* calc */
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/vnd.ms-excel',
    'application/vnd.oasis.opendocument.spreadsheet',
    /* impress / draw */
    'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'application/vnd.ms-powerpoint',
    'application/vnd.oasis.opendocument.presentation',
    'application/vnd.oasis.opendocument.graphics',
];

handler.registerMimeTypes(mimeTypes, renderer);
