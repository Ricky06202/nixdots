/*
 * Vista previa de SVG para nemo-preview.
 *
 * El viewer de imágenes normal (image.js) ya pinta SVG vía el loader de
 * gdk-pixbuf, pero lo hace con el tamaño intrínseco del archivo: un logo de
 * 115x48 se ve diminuto (no se escala) y al ampliar se ve borroso. Aquí lo
 * rasterizamos con rsvg-convert a 1400 px de ancho (vector → nítido, sin
 * importar el tamaño original), lo componemos sobre un tablero gris para que
 * se vea la transparencia y el arte blanco/negro se lea, y lo mostramos con
 * botón de pantalla completa.
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
const Utils = imports.ui.utils;

const RSVG = '@rsvg@';
const RENDER_WIDTH = 1400;   /* ancho de rasterizado (nítido al ampliar) */
const CHECKER_CELL = 12;

function SvgRenderer(args) {
    this._init(args);
}

SvgRenderer.prototype = {
    _init : function(args) {
        this.moveOnClick = true;
        this.canFullScreen = true;
        this._proc = null;
        this._tmpPath = null;
        this._texture = null;
    },

    prepare : function(file, mainWindow, callback) {
        this._mainWindow = mainWindow;
        this._callback = callback;
        this._texture = null;

        let path = file.get_path();
        if (!path) {
            this._degraded();
            return;
        }

        this._tmpPath = GLib.build_filenamev([ GLib.get_tmp_dir(),
            'nemo-preview-svg-' + GLib.get_monotonic_time() + '.png' ]);

        let argv = [ RSVG, '-w', String(RENDER_WIDTH), '-o', this._tmpPath, path ];

        try {
            this._proc = Gio.Subprocess.new(argv,
                Gio.SubprocessFlags.STDOUT_SILENCE |
                Gio.SubprocessFlags.STDERR_SILENCE);
        } catch (e) {
            logError(e, 'nemo-preview-svg: no se pudo lanzar rsvg-convert');
            this._degraded();
            return;
        }

        this._proc.wait_check_async (null, Lang.bind(this,
            function(proc, res) {
                let ok = false;
                try {
                    ok = proc.wait_check_finish(res);
                } catch (e) {
                    ok = false;
                }
                this._proc = null;

                if (ok)
                    this._load();
                else
                    this._degraded();
            }));
    },

    _load : function() {
        let pix;
        try {
            let svg = GdkPixbuf.Pixbuf.new_from_file(this._tmpPath);
            pix = this._withCheckerboard(svg);
        } catch (e) {
            logError(e, 'nemo-preview-svg: no se pudo componer el render');
            this._degraded();
            return;
        }

        this._texture = new GtkClutter.Texture({ keep_aspect_ratio: true });
        this._texture.set_from_pixbuf(pix);
        this._callback();
    },

    /* Tablero de transparencia: fondo claro y cuadros suaves. Se compone con
     * cairo (mucho más rápido que pintar píxel a píxel desde JS). */
    _withCheckerboard : function(svg) {
        let cairo = imports.cairo;
        let w = svg.get_width();
        let h = svg.get_height();

        let surface = new cairo.ImageSurface(cairo.Format.ARGB32, w, h);
        let cr = new cairo.Context(surface);

        cr.setSourceRGB(0.93, 0.93, 0.93);
        cr.paint();

        cr.setSourceRGB(0.82, 0.82, 0.85);
        let row = 0;
        for (let y = 0; y < h; y += CHECKER_CELL, row++) {
            let x = (row % 2) * CHECKER_CELL;
            for (; x < w; x += 2 * CHECKER_CELL)
                cr.rectangle(x, y, CHECKER_CELL, CHECKER_CELL);
        }
        cr.fill();

        Gdk.cairo_set_source_pixbuf(cr, svg, 0, 0);
        cr.paint();

        return Gdk.pixbuf_get_from_surface(surface, 0, 0, w, h);
    },

    render : function() {
        return this._texture;
    },

    getSizeForAllocation : function(allocation, fullScreen) {
        let baseSize = this._texture ? this._texture.get_base_size() : [ 400, 300 ];
        /* upscale = true: como rasterizamos a 1400 px, ampliar sigue viéndose
         * nítido y así los SVG chicos (iconos, logos) no salen enanos. */
        return Utils.getScaledSize(baseSize, allocation, true);
    },

    createToolbar : function() {
        let toolbar = new Gtk.Toolbar({ icon_size: Gtk.IconSize.MENU });
        toolbar.get_style_context().add_class('osd');
        toolbar.set_show_arrow(false);
        toolbar.show();

        let zoom = Utils.createFullScreenButton(this._mainWindow);
        toolbar.insert(zoom, 0);

        return new GtkClutter.Actor({ contents: toolbar });
    },

    _degraded : function() {
        if (!this._texture) {
            let pix = GdkPixbuf.Pixbuf.new(GdkPixbuf.Colorspace.RGB, true, 8, 1, 1);
            pix.fill(0x00000000);
            this._texture = new GtkClutter.Texture({ keep_aspect_ratio: true });
            this._texture.set_from_pixbuf(pix);
        }
        this._callback();
    },

    _cleanup : function() {
        if (this._proc) {
            try {
                this._proc.force_exit();
            } catch (e) {
            }
            this._proc = null;
        }

        if (this._tmpPath) {
            try {
                Gio.File.new_for_path(this._tmpPath).delete(null);
            } catch (e) {
            }
            this._tmpPath = null;
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
let renderer = new SvgRenderer();

handler.registerMimeTypes([ 'image/svg+xml',
                            'image/svg+xml-compressed',
                            'image/svg' ], renderer);
