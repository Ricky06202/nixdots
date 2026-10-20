{ lib, fetchurl, buildNpmPackage, nodejs_22, bun, python3, gnumake, pkg-config, makeWrapper }:

buildNpmPackage rec {
  pname = "letta-code";
  version = "0.34.19";

  src = fetchurl {
    url = "https://registry.npmjs.org/@letta-ai/letta-code/-/letta-code-${version}.tgz";
    hash = "sha256-MxSbyOeTJ2ubSV0JfgPP5hiEL91Z+DFkiO0NqreriGU=";
  };

  # Lockfile completo generado desde package.json (el shrinkwrap publicado
  # está incompleto y npm ci lo rechaza). Incluye prod deps + peer resuelto.
  npmDepsHash = "sha256-MmpYXekmS2yn26zJ+0waSAwA6CjLutV9Y4FBuoRbiO8=";
  npmDepsFetcherVersion = 2;
  nodejs = nodejs_22;

  # El tarball ya trae letta.js/dist compilados: no correr el build de fuente
  # (requiere bun + TypeScript).
  dontNpmBuild = true;

  postPatch = ''
    # El paquete publicado lista devDependencies que no están en el lock y
    # react 18.2.0, que choca con el peer de @pierre/diffs (>=18.3.1).
    # Ajustamos package.json para que coincida con el lock generado.
    ${python3}/bin/python3 - <<'PY'
    import json
    p = "package.json"
    d = json.load(open(p))
    d.pop("devDependencies", None)
    d.setdefault("dependencies", {})["react"] = "18.3.1"
    open(p, "w").write(json.dumps(d, indent=2, ensure_ascii=False) + "\n")
    PY

    cp ${./package-lock.json} package-lock.json
    rm -f npm-shrinkwrap.json
  '';

  makeCacheWritable = true;
  npmInstallFlags = [ "--omit=dev" "--legacy-peer-deps" ];
  npmRebuildFlags = [ "--ignore-scripts" ];
  npmPackFlags = [ "--ignore-scripts" ];
  npmPruneFlags = [ "--omit=dev" "--ignore-scripts" ];
  dontNpmPrune = true;

  nativeBuildInputs = [ python3 gnumake pkg-config makeWrapper bun ];

  postInstall = ''
    cd $out/lib/node_modules/@letta-ai/letta-code

    export HOME=$TMPDIR
    export npm_config_cache=$TMPDIR/npm-cache
    mkdir -p "$npm_config_cache"

    # Parches de vendor que el paquete espera en su postinstall.
    node scripts/postinstall-patches.js

    # node-pty es nativo; compilarlo contra el Node de Nix.
    npm rebuild node-pty --foreground-scripts --build-from-source

    cd -

    # El binario es un polyglot sh que busca bun o node en PATH.
    wrapProgram $out/bin/letta \
      --prefix PATH : ${lib.makeBinPath [ nodejs_22 bun ]}
  '';

  meta = with lib; {
    description = "Letta Code CLI (agentes con memoria persistente)";
    homepage = "https://github.com/letta-ai/letta-code";
    license = licenses.asl20;
    mainProgram = "letta";
    platforms = platforms.linux;
  };
}
