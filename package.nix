{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  unzip,
  vulkan-loader,
  wayland,
}:

let
  sources = lib.importJSON ./sources.json;
  source =
    sources.platforms.${stdenv.hostPlatform.system}
      or (throw "delta-dev: unsupported system ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "delta-dev";
  inherit (sources) version;

  src = fetchurl { inherit (source) url hash; };

  sourceRoot = if stdenv.hostPlatform.isDarwin then "." else "Delta";

  nativeBuildInputs =
    lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ]
    ++ lib.optionals stdenv.hostPlatform.isDarwin [ unzip ];

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [ (lib.getLib stdenv.cc.cc) ];

  # Loaded with dlopen at runtime.
  runtimeDependencies = lib.optionals stdenv.hostPlatform.isLinux [
    vulkan-loader
    wayland
  ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
  ''
  + lib.optionalString stdenv.hostPlatform.isLinux ''
    mkdir -p $out/lib/delta $out/bin
    cp -r bin lib $out/lib/delta
    ln -s $out/lib/delta/bin/delta $out/bin/delta
    cp -r share $out/share
    substituteInPlace $out/share/applications/dev.zed.Delta.desktop \
      --replace-fail "Exec=delta " "Exec=$out/bin/delta "
  ''
  + lib.optionalString stdenv.hostPlatform.isDarwin ''
    mkdir -p $out/Applications $out/bin
    cp -r Delta.app $out/Applications
    ln -s $out/Applications/Delta.app/Contents/MacOS/delta $out/bin/delta
  ''
  + ''
    runHook postInstall
  '';

  meta = {
    description = "Multiplayer environment for coding with AI agents";
    homepage = "https://delta.dev";
    license = lib.licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    maintainers = with lib.maintainers; [ kevinpita ];
    mainProgram = "delta";
    platforms = builtins.attrNames sources.platforms;
  };
}
