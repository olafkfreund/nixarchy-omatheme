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

  postPatch = ''
    substituteInPlace Panel.qml \
      --replace '/usr/bin/hyprchroma' '${engine}/bin/hyprchroma' \
      --replace '/usr/bin/hyprchroma-setup' '${engine}/bin/hyprchroma-setup' \
      --replace '"/usr/bin/test"' '"${coreutils}/bin/test"' \
      --replace '"/usr/bin:/usr/share/omarchy/bin"' \
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

  nativeBuildInputs = [ jq ];

  checkPhase = ''
    ${jq}/bin/jq empty manifest.json
  '';

  meta = {
    description = "Omarchy bar panel for the hyprchroma runtime theme engine";
    homepage = "https://github.com/NobleDoodle/omarchroma";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
