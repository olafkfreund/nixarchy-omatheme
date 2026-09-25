{
  lib,
  stdenvNoCC,
  coreutils,
  jq,
  python3,
  src,
}:

let
  outPath = builtins.placeholder "out";
  trustedBins = "${coreutils}/bin ${jq}/bin ${python3}/bin /run/current-system/sw/bin";
  trustedPath = "${coreutils}/bin:${jq}/bin:${python3}/bin:/run/current-system/sw/bin";
in
stdenvNoCC.mkDerivation {
  pname = "hyprchroma";
  version = builtins.readFile "${src}/VERSION";
  inherit src;

  dontBuild = true;

  postPatch = ''
    for file in bin/* lib/* share/hooks/hyprchroma; do
      substituteInPlace "$file" \
        --replace '/usr/bin/stat' '${coreutils}/bin/stat' \
        --replace '/usr/bin/hyprchroma' '${outPath}/bin/hyprchroma' \
        --replace '/usr/lib/hyprchroma' '${outPath}/lib/hyprchroma'
      substituteInPlace "$file" \
        --replace 'for directory in /usr/bin /usr/share/omarchy/bin; do' \
          'for directory in ${trustedBins}; do' \
        --replace '"/usr/bin", "/usr/share/omarchy/bin"' \
          '"${coreutils}/bin", "${jq}/bin", "${python3}/bin", "/run/current-system/sw/bin"' \
        --replace '"/usr/bin:/usr/share/omarchy/bin"' \
          '"${trustedPath}"'
    done
    substituteInPlace packaging/systemd/hyprchromad.service \
      --replace-fail '/usr/bin/hyprchroma' '${outPath}/bin/hyprchroma'
  '';

  installPhase = ''
    runHook preInstall

    install -Dm755 bin/hyprchroma $out/bin/hyprchroma
    install -Dm755 bin/hyprchroma-setup $out/bin/hyprchroma-setup
    for file in hyprchroma-state hyprchroma-dark-reader hyprchroma-palette sync-gtk-theme sync-qt-kde-theme; do
      install -Dm755 "lib/$file" "$out/lib/hyprchroma/$file"
    done
    install -Dm644 share/pear-theme.css.template $out/share/hyprchroma/pear-theme.css.template
    install -Dm755 share/hooks/hyprchroma $out/share/hyprchroma/hooks/hyprchroma
    install -Dm644 packaging/systemd/hyprchromad.service $out/lib/systemd/user/hyprchromad.service
    install -Dm644 README.md $out/share/doc/hyprchroma/README.md
    install -Dm644 LICENSE $out/share/licenses/hyprchroma/LICENSE

    runHook postInstall
  '';

  meta = {
    description = "Synchronize Omarchy themes across desktop applications";
    homepage = "https://github.com/NobleDoodle/omarchroma";
    license = lib.licenses.mit;
    mainProgram = "hyprchroma";
    platforms = lib.platforms.linux;
  };
}
