{
  lib,
  stdenvNoCC,
  bash,
  coreutils,
  jq,
  python3,
  src,
  electronRenderer ? ./hyprchroma-electron,
  shellRenderer ? ./hyprchroma-shell,
  terminalRenderer ? ./hyprchroma-terminals,
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

  nativeBuildInputs = [ bash ];

  checkPhase = ''
    for file in bin/* lib/* share/hooks/hyprchroma; do
      bash -n "$file"
    done
  '';

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
    ${python3}/bin/python3 - <<'PY'
    from pathlib import Path

    path = Path("bin/hyprchroma")
    text = path.read_text()
    text = text.replace(
        'case "$' + '{1:-}" in\n  daemon)',
        'case "$' + '{1:-}" in\n'
        '  terminals)\n'
        '    shift\n'
        '    "$HYPRCHROMA_LIB/hyprchroma-terminals" "$' + '{1:-all}"\n'
        '    exit $?\n'
        '    ;;\n'
        '  shell)\n'
        '    "$HYPRCHROMA_LIB/hyprchroma-shell"\n'
        '    exit $?\n'
        '    ;;\n'
        '  daemon)',
        1,
    )
    text = text.replace(
        '       hyprchroma daemon           watch for changes and keep everything in step\n',
        '       hyprchroma terminals [name]  render Kitty, Foot, and Ghostty files\n'
        '       hyprchroma shell             render Starship and shell colors\n'
        '       hyprchroma daemon           watch for changes and keep everything in step\n',
        1,
    )
    marker = '\npython3 - "$HYPRCHROMA_LIB/hyprchroma-state" "$STATUS_FILE"'
    if marker not in text:
        raise SystemExit("hyprchroma status update marker was not found")
    text = text.replace(
        marker,
        '\n"$HYPRCHROMA_LIB/hyprchroma-terminals" all || fail "terminal synchronization failed"'
        '\n"$HYPRCHROMA_LIB/hyprchroma-shell" || fail "shell synchronization failed"'
        + marker,
        1,
    )
    path.write_text(text)
    PY
  '';

  installPhase = ''
    runHook preInstall

    install -Dm755 bin/hyprchroma $out/bin/hyprchroma
    install -Dm755 bin/hyprchroma-setup $out/bin/hyprchroma-setup
    for file in hyprchroma-state hyprchroma-dark-reader hyprchroma-palette sync-gtk-theme sync-qt-kde-theme; do
      install -Dm755 "lib/$file" "$out/lib/hyprchroma/$file"
    done
    install -Dm755 "${terminalRenderer}" "$out/lib/hyprchroma/hyprchroma-terminals"
    install -Dm755 "${shellRenderer}" "$out/lib/hyprchroma/hyprchroma-shell"
    install -Dm755 "${electronRenderer}" "$out/lib/hyprchroma/hyprchroma-electron"
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
