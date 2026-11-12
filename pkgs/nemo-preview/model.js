/*
 * Vista previa de modelos 3D para nemo-preview.
 *
 * No hay render 3D interactivo dentro del preview (la ventana de nemo-preview
 * solo pinta texturas), así que lanzamos f3d (VTK) en modo offscreen para
 * generar un PNG y lo mostramos como textura. Formatos: todo lo que f3d
 * soporta con los plugins assimp + native + occt + usd (stl, obj, ply, 3mf,
 * fbx, dae, gltf/glb, step/iges/brep, fcstd, usd/usdz, vtk...).
 */

imports.gi.versions.Gtk = '3.0';

const Gtk = imports.gi.Gtk;
const GdkPixbuf = imports.gi.GdkPixbuf;
const GtkClutter = imports.gi.GtkClutter;
const GLib = imports.gi.GLib;
const Gio = imports.gi.Gio;

const Lang = imports.lang;

const MimeHandler = imports.ui.mimeHandler;
const Utils = imports.ui.utils;

const F3D = '@f3d@';
const RESOLUTION = 900;

function ModelRenderer(args) {
    this._init(args);
}

ModelRenderer.prototype = {
    _init : function(args) {
        this.moveOnClick = true;
        this.canFullScreen = true;
        this._proc = null;
        this._outPath = null;
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

        this._outPath = GLib.build_filenamev([ GLib.get_tmp_dir(),
            'nemo-preview-3d-' + GLib.get_monotonic_time() + '.png' ]);

        let argv = [ F3D,
                     '--config=thumbnail',
                     '--load-plugins=assimp,native,occt,usd',
                     '--verbose=quiet',
                     '--resolution=' + RESOLUTION + ',' + RESOLUTION,
                     '--output=' + this._outPath,
                     path ];

        try {
            this._proc = Gio.Subprocess.new(argv,
                Gio.SubprocessFlags.STDOUT_SILENCE |
                Gio.SubprocessFlags.STDERR_SILENCE);
        } catch (e) {
            logError(e, 'nemo-preview-3d: no se pudo lanzar f3d');
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
        try {
            let pix = GdkPixbuf.Pixbuf.new_from_file(this._outPath);
            this._texture = new GtkClutter.Texture({ keep_aspect_ratio: true });
            this._texture.set_from_pixbuf(pix);
        } catch (e) {
            logError(e, 'nemo-preview-3d: no se pudo leer el render de f3d');
            this._degraded();
            return;
        }

        this._callback();
    },

    /* f3d falló (o el archivo no tiene geometría): textura vacía, el título
     * del preview sigue mostrando el nombre del archivo. */
    _degraded : function() {
        if (!this._texture) {
            let pix = GdkPixbuf.Pixbuf.new(GdkPixbuf.Colorspace.RGB, true, 8, 1, 1);
            pix.fill(0x00000000);
            this._texture = new GtkClutter.Texture({ keep_aspect_ratio: true });
            this._texture.set_from_pixbuf(pix);
        }

        this._callback();
    },

    render : function() {
        return this._texture;
    },

    getSizeForAllocation : function(allocation, fullScreen) {
        let baseSize = this._texture ? this._texture.get_base_size()
                                     : [ RESOLUTION, RESOLUTION ];
        return Utils.getScaledSize(baseSize, allocation, fullScreen);
    },

    _cleanup : function() {
        if (this._proc) {
            try {
                this._proc.force_exit();
            } catch (e) {
            }
            this._proc = null;
        }

        if (this._outPath) {
            try {
                Gio.File.new_for_path(this._outPath).delete(null);
            } catch (e) {
            }
            this._outPath = null;
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
let renderer = new ModelRenderer();

let mimeTypes = [
    /* plugin native */
    'model/stl', 'model/obj', 'model/gltf+json', 'model/gltf-binary',
    'application/vnd.ply', 'application/vnd.3ds', 'application/gml+xml',
    'application/dicom', 'application/vnd.mhd', 'application/vnd.nrrd',
    'application/vnd.pts', 'image/x-tga', 'image/vnd.radiance',
    'model/vrml', 'model/vnd.vrml', 'application/vnd.vtk',
    'application/vnd.vtu', 'application/vnd.vtp', 'application/vnd.vti',
    'application/vnd.vtr', 'application/vnd.vts', 'application/vnd.vtm',
    'application/vnd.mdl', 'application/vnd.spz', 'application/vnd.splat',
    /* plugin assimp */
    'application/vnd.fbx', 'application/vnd.dae', 'image/vnd.dxf',
    'application/vnd.off', 'application/vnd.x', 'model/3mf', 'application/x-amf',
    /* plugin occt */
    'model/iges', 'application/vnd.step', 'model/step',
    'application/vnd.brep', 'application/vnd.xbf',
    'application/x-extension-fcstd',
    /* plugin usd */
    'application/vnd.usd', 'application/vnd.usdc', 'model/vnd.usda',
    'model/vnd.usdz+zip',
];

handler.registerMimeTypes(mimeTypes, renderer);
