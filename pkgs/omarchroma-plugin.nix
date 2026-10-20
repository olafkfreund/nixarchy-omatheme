{
  lib,
  stdenvNoCC,
  coreutils,
  jq,
  perl,
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
    # shortcut: omarchroma before 3.2.3 reads Color unqualified, which Qt 6.12's
    # QtQuick Color singleton shadows; drop once the omarchroma input is >= 3.2.3.
    perl -pi -e 's/(^|[^.A-Za-z_])Color\.(?=[a-z])/$1Commons.Color./g' Panel.qml
    grep -q '^import qs.Commons as Commons$' Panel.qml || sed -i 's/^import qs.Commons$/&\nimport qs.Commons as Commons/' Panel.qml
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

  nativeBuildInputs = [
    jq
    perl
  ];

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
