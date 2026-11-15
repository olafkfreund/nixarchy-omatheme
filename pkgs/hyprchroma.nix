{
  lib,
  stdenvNoCC,
  bash,
  coreutils,
  util-linux,
  gawk,
  glib,
  jq,
  python3,
  python3Packages,
  src,
  electronRenderer ? ./hyprchroma-electron,
  shellRenderer ? ./hyprchroma-shell,
  terminalRenderer ? ./hyprchroma-terminals,
  editorRenderer ? ./hyprchroma-editors,
  editorBridges ? ./editors,
}:

let
  pythonRuntime = python3.withPackages (_: [ python3Packages.plyvel ]);
  outPath = builtins.placeholder "out";
  trustedBins = "${coreutils}/bin ${util-linux}/bin ${gawk}/bin ${glib}/bin ${jq}/bin ${pythonRuntime}/bin /run/current-system/sw/bin";
  trustedPath = "${coreutils}/bin:${util-linux}/bin:${gawk}/bin:${glib}/bin:${jq}/bin:${pythonRuntime}/bin:/run/current-system/sw/bin";
  dataDirs = "/etc/profiles/per-user/\${USER:-}/share:$HOME/.nix-profile/share:/run/current-system/sw/share";
in
stdenvNoCC.mkDerivation {
  pname = "hyprchroma";
  version = builtins.readFile "${src}/VERSION";
  inherit src;

  dontBuild = true;
  doCheck = true;
  doInstallCheck = true;

  passthru.pythonRuntime = pythonRuntime;

  nativeBuildInputs = [ bash ];

  checkPhase = ''
    runHook preCheck
    ${pythonRuntime}/bin/python3 -c 'import plyvel'
    for file in bin/hyprchroma lib/sync-* share/hooks/hyprchroma; do
      bash -n "$file"
    done
    for file in lib/hyprchroma-state lib/hyprchroma-dark-reader lib/hyprchroma-palette; do
      ${pythonRuntime}/bin/python3 -m py_compile "$file"
    done
    runHook postCheck
  '';

  postPatch = ''
    rm bin/hyprchroma-setup bin/hyprchroma-uninstall lib/hyprchroma-icons
    for file in bin/* lib/* share/hooks/hyprchroma; do
      substituteInPlace "$file" \
        --replace-quiet '/usr/bin/stat' '${coreutils}/bin/stat' \
        --replace-quiet '/usr/bin/python3' '${pythonRuntime}/bin/python3' \
        --replace-quiet '/usr/bin/hyprchroma' '${outPath}/bin/hyprchroma' \
        --replace-quiet '/usr/lib/hyprchroma' '${outPath}/lib/hyprchroma'
      substituteInPlace "$file" \
        --replace-quiet 'for directory in /usr/bin /usr/share/omarchy/bin; do' \
          'for directory in ${trustedBins}; do' \
        --replace-quiet '"/usr/bin", "/usr/share/omarchy/bin"' \
          '"${coreutils}/bin", "${util-linux}/bin", "${gawk}/bin", "${glib}/bin", "${jq}/bin", "${pythonRuntime}/bin", "/run/current-system/sw/bin"' \
        --replace-quiet '"/usr/bin:/usr/share/omarchy/bin"' \
          '"${trustedPath}"' \
        --replace-quiet '"''${trusted:-/usr/bin:/usr/share/omarchy/bin}"' \
          '"${trustedPath}"'
    done
    substituteInPlace bin/hyprchroma \
      --replace-fail '"''${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"' '"''${XDG_DATA_DIRS:-${dataDirs}}"'
    substituteInPlace lib/hyprchroma-state \
      --replace-fail 'Path("/usr/share/omarchy/bin")' 'Path("/run/current-system/sw/share/omarchy/bin")' \
      --replace-fail 'or "/usr/share:/usr/local/share"' 'or f"/etc/profiles/per-user/{os.environ.get("USER", "")}/share:{Path.home()}/.nix-profile/share:/run/current-system/sw/share"' \
      --replace-fail 'or "/usr/share"' 'or f"/etc/profiles/per-user/{os.environ.get("USER", "")}/share:{Path.home()}/.nix-profile/share:/run/current-system/sw/share"'
    substituteInPlace lib/sync-gtk-theme \
      --replace-fail '"/usr/share/icons/$value"' '"/etc/profiles/per-user/''${USER:-}/share/icons/$value" || -d "$HOME/.nix-profile/share/icons/$value" || -d "/run/current-system/sw/share/icons/$value"' \
      --replace-fail '/usr/share/themes /usr/local/share/themes' '/etc/profiles/per-user/''${USER:-}/share/themes "$HOME/.nix-profile/share/themes" /run/current-system/sw/share/themes'
    substituteInPlace lib/sync-qt-kde-theme \
      --replace-fail '"/usr/share/icons/$value"' '"/etc/profiles/per-user/''${USER:-}/share/icons/$value" || -d "$HOME/.nix-profile/share/icons/$value" || -d "/run/current-system/sw/share/icons/$value"' \
      --replace-fail '"/usr/share/icons/$dark"' '"/etc/profiles/per-user/''${USER:-}/share/icons/$dark" || -d "$HOME/.nix-profile/share/icons/$dark" || -d "/run/current-system/sw/share/icons/$dark"' \
      --replace-fail '"/usr/share/icons/$breeze"' '"/etc/profiles/per-user/''${USER:-}/share/icons/$breeze" || -d "$HOME/.nix-profile/share/icons/$breeze" || -d "/run/current-system/sw/share/icons/$breeze"'
    substituteInPlace packaging/systemd/hyprchromad.service \
      --replace-fail '/usr/bin/hyprchroma' '${outPath}/bin/hyprchroma'
    ${pythonRuntime}/bin/python3 - <<'PY'
    from pathlib import Path

    path = Path("bin/hyprchroma")
    text = path.read_text()
    old = 'case "$' + '{1:-}" in\n  daemon)'
    assert old in text, "hyprchroma dispatch was not found"
    text = text.replace(
        old,
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
        '  electron)\n'
        '    shift\n'
        '    "$HYPRCHROMA_LIB/hyprchroma-electron" "$' + '{1:-status}"\n'
        '    exit $?\n'
        '    ;;\n'
        '  editors)\n'
        '    "$HYPRCHROMA_LIB/hyprchroma-editors"\n'
        '    exit $?\n'
        '    ;;\n'
        '  daemon)',
        1,
    )
    old = '       hyprchroma daemon           watch for changes and keep everything in step\n'
    assert old in text, "hyprchroma help line was not found"
    text = text.replace(
        old,
        '       hyprchroma terminals [name]  render Kitty, Foot, and Ghostty files\n'
        '       hyprchroma shell             render Starship and shell colors\n'
        '       hyprchroma electron [app]    synchronize Electron registry status\n'
        '       hyprchroma editors            render Vim and Neovim colors\n'
        '       hyprchroma daemon           watch for changes and keep everything in step\n',
        1,
    )
    marker = '\n${pythonRuntime}/bin/python3 -I - "$HYPRCHROMA_LIB/hyprchroma-state" "$STATUS_FILE"'
    assert marker in text, "hyprchroma status update marker was not found"
    text = text.replace(
        marker,
        '\n"$HYPRCHROMA_LIB/hyprchroma-terminals" all || fail "terminal synchronization failed"'
        '\n"$HYPRCHROMA_LIB/hyprchroma-shell" || fail "shell synchronization failed"'
        '\n"$HYPRCHROMA_LIB/hyprchroma-editors" || fail "editor synchronization failed"'
        + marker,
        1,
    )
    old = '  settings_key=$(target_key "$target") || fail "unknown target: $target"\n'
    assert old in text, "hyprchroma set-enabled block was not found"
    text = text.replace(
        old,
        old
        + '  if (( ! force )); then\n'
        + '    recorded=$(jq -r --arg key "$settings_key" \'.frameworks[$key] | if . == null then "" else tostring end\' "$SETTINGS_FILE" 2>/dev/null || true)\n'
        + '    if [[ $recorded == "$set_enabled" ]]; then\n'
        + '      status_key=$settings_key\n'
        + '      [[ $status_key == pear ]] && status_key=pearDesktop\n'
        + '      if [[ $set_enabled == true ]]; then\n'
        + '        jq -e --arg key "$status_key" \'.[$key] != null\' "$STATUS_FILE" >/dev/null 2>&1 && exit 0\n'
        + '      elif [[ $target != dark-reader && $target != qt-kde && $target != browsers && $target != thunderbird ]]; then\n'
        + '        exit 0\n'
        + '      fi\n'
        + '    fi\n'
        + '  fi\n',
        1,
    )
    old = '"$HYPRCHROMA_SELF" --target="$name" --set-enabled=false --quiet || true'
    assert old in text, "hyprchroma framework remove call was not found"
    text = text.replace(old, '"$HYPRCHROMA_SELF" --target="$name" --set-enabled=false --quiet --force || true', 1)
    old = '"$HYPRCHROMA_SELF" --target="$name" --set-enabled=true --quiet || true'
    assert old in text, "hyprchroma framework restore call was not found"
    text = text.replace(old, '"$HYPRCHROMA_SELF" --target="$name" --set-enabled=true --quiet --force || true', 1)
    for target in ("thunderbird", "pear"):
        for enabled in ("true", "false"):
            old = f'"$HYPRCHROMA_SELF" --target={target} --set-enabled={enabled} --quiet || true'
            assert old in text, f"hyprchroma framework_apps {target} {enabled} call was not found"
            text = text.replace(old, old.replace(' --quiet ||', ' --quiet --force ||'), 1)
    old = '  key=$(target_key "$1") || return 1\n'
    assert old in text, "hyprchroma target_enabled key was not found"
    text = text.replace(old, old + '  [[ $key == icons ]] && return 1\n', 1)
    old = '  # theme. Only a recorded true turns any of these on.\n'
    assert old in text, "hyprchroma target_enabled comment was not found"
    text = text.replace(old, '  # theme. Icons stays off in this package even if a prior install recorded true.\n', 1)
    path.write_text(text)

    path = Path("lib/hyprchroma-state")
    text = path.read_text()
    old = '            names.add(os.path.basename(os.readlink(entry / "exe")))'
    assert old in text, "running_executables basename was not found"
    text = text.replace(old,
        '            name = os.path.basename(os.readlink(entry / "exe")).removesuffix(" (deleted)")\n'
        '            wrapped = re.fullmatch(r"\\.(.+)-wrapped", name)\n'
        '            names.add(wrapped.group(1) if wrapped else name)', 1)
    old = '        return os.path.basename(os.readlink(f"/proc/{pid}/exe"))'
    assert old in text, "window_executable basename was not found"
    text = text.replace(old,
        '        name = os.path.basename(os.readlink(f"/proc/{pid}/exe")).removesuffix(" (deleted)")\n'
        '        wrapped = re.fullmatch(r"\\.(.+)-wrapped", name)\n'
        '        return wrapped.group(1) if wrapped else name', 1)
    old = '        if not binary or running_binary(pid) != os.path.realpath(binary):\n'
    assert old in text, "idle GTK portal binary comparison was not found"
    text = text.replace(old,
        '        if not binary:\n'
        '            continue\n'
        '        binary = os.path.realpath(binary)\n'
        '        wrapped = os.path.join(os.path.dirname(binary), f".{os.path.basename(binary)}-wrapped")\n'
        '        if running_binary(pid) not in (binary, wrapped):\n', 1)
    path.write_text(text)

    path = Path("lib/hyprchroma-dark-reader")
    text = path.read_text()
    old = '    return executable.removesuffix(" (deleted)")'
    assert old in text, "dark-reader running_executable return was not found"
    text = text.replace(old,
        '    executable = executable.removesuffix(" (deleted)")\n'
        '    wrapped = re.fullmatch(r"\\.(.+)-wrapped", executable)\n'
        '    return wrapped.group(1) if wrapped else executable', 1)
    path.write_text(text)
    PY
  '';

  installPhase = ''
    runHook preInstall

    install -Dm755 bin/hyprchroma $out/bin/hyprchroma
    for file in hyprchroma-state hyprchroma-dark-reader hyprchroma-palette sync-gtk-theme sync-qt-kde-theme; do
      install -Dm755 "lib/$file" "$out/lib/hyprchroma/$file"
    done
    install -Dm755 ${./hyprchroma-icons-stub} "$out/lib/hyprchroma/hyprchroma-icons"
    install -Dm755 "${terminalRenderer}" "$out/lib/hyprchroma/hyprchroma-terminals"
    install -Dm755 "${shellRenderer}" "$out/lib/hyprchroma/hyprchroma-shell"
    install -Dm755 "${electronRenderer}" "$out/lib/hyprchroma/hyprchroma-electron"
    install -Dm755 "${editorRenderer}" "$out/lib/hyprchroma/hyprchroma-editors"
    for file in nixarchy-theme.lua omarchy.lua nixarchy-theme.vim omarchy.vim; do
      install -Dm644 "${editorBridges}/$file" "$out/share/hyprchroma/editors/$file"
    done
    install -Dm644 share/pear-theme.css.template $out/share/hyprchroma/pear-theme.css.template
    install -Dm755 share/hooks/hyprchroma $out/share/hyprchroma/hooks/hyprchroma
    install -Dm644 packaging/systemd/hyprchromad.service $out/lib/systemd/user/hyprchromad.service
    install -Dm644 README.md $out/share/doc/hyprchroma/README.md
    install -Dm644 LICENSE $out/share/licenses/hyprchroma/LICENSE

    runHook postInstall
  '';

  installCheckPhase = ''
    runHook preInstallCheck
    bash -n "$out/lib/hyprchroma/hyprchroma-icons"
    # env shebangs are handled by patchShebangs.
    # Comment-only lines cannot execute a /usr path.
    bad=$(grep -RIn '/usr/' "$out/bin" "$out/lib/hyprchroma" "$out/share/hyprchroma" "$out/share/systemd/user/hyprchromad.service" | grep -Ev ':[0-9]+:[[:space:]]*(#!/usr/bin/env([[:space:]]|$)|#([^!]|$))' || true)
    if [[ -n $bad ]]; then
      printf 'forbidden /usr path in installed file: %s\n' "$bad" >&2
      exit 1
    fi
    runHook postInstallCheck
  '';

  meta = {
    description = "Synchronize Omarchy themes across desktop applications";
    homepage = "https://github.com/NobleDoodle/omarchroma";
    license = lib.licenses.mit;
    mainProgram = "hyprchroma";
    platforms = lib.platforms.linux;
  };
}
