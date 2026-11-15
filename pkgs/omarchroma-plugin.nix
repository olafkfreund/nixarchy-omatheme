{
  lib,
  stdenvNoCC,
  coreutils,
  jq,
  engine,
  src,
}:

stdenvNoCC.mkDerivation {
  pname = "omarchroma-plugin";
  version = builtins.readFile "${src}/VERSION";
  inherit src;

  dontBuild = true;
  patches = [ ./patches/omarchroma-panel.patch ];

  postPatch = ''
    substituteInPlace Panel.qml \
      --replace-fail '/usr/bin/hyprchroma' '${engine}/bin/hyprchroma' \
      --replace-fail '"/usr/bin/test"' '"${coreutils}/bin/test"' \
      --replace-fail '"/usr/bin:/usr/share/omarchy/bin"' \
        '"${engine}/bin:${coreutils}/bin:/run/current-system/sw/bin"'
  '';

  installPhase = ''
    runHook preInstall
    install -Dm644 manifest.json $out/manifest.json
    install -Dm644 BarWidget.qml $out/BarWidget.qml
    install -Dm644 Panel.qml $out/Panel.qml
    install -Dm644 README.md $out/README.md
    install -Dm644 LICENSE $out/LICENSE
    runHook postInstall
  '';

  nativeBuildInputs = [
    jq
  ];

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    ${jq}/bin/jq empty manifest.json
    runHook postCheck
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    if grep -nE '/usr/bin/|/usr/share/|hyprchroma-setup|hyprchroma-uninstall|"icons"|toggleFramework\("icons"\)|target: "icons"|targetEnabled\("icons"\)|setTargetEnabled\("icons"|iconsStatusFile|nextFolderColor|installPending' \
      "$out/Panel.qml" "$out/BarWidget.qml"; then
      echo "Forbidden pattern found in installed QML files" >&2
      exit 1
    fi
    runHook postInstallCheck
  '';

  meta = {
    description = "Omarchy bar panel for the hyprchroma runtime theme engine";
    homepage = "https://github.com/NobleDoodle/omarchroma";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
