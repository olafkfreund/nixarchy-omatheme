{
  lib,
  stdenvNoCC,
  coreutils,
  jq,
  python3,
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

        ${python3}/bin/python3 - <<'PY'
    from pathlib import Path

    panel = Path("Panel.qml")
    text = panel.read_text()
    property_marker = '  property string activeTarget: ""\n'
    property_insert = (
        '  property string activeTarget: ""\n'
        '  property var terminalStatus: ({ kitty: "unknown", foot: "unknown", ghostty: "unknown" })\n'
        '  property var electronStatus: ({ vscode: "unknown", discord: "unsupported", slack: "unsupported", obsidian: "unsupported" })\n'
        '  property var shellStatus: ({ starship: "unknown", bash: "unknown", zsh: "unknown", fish: "unknown" })\n'
        '  property var desktopStatus: ({ gtk: "unknown", qtKde: "unknown", darkReader: "unknown", pearDesktop: "unknown", flatpak: "unknown", browsers: "unknown" })\n'
        '\n'
        '  function terminalLabel(name) {\n'
        '    var value = root.terminalStatus[name] || "unknown"\n'
        '    if (value === "synchronized") return "synced"\n'
        '    if (value === "new-windows-only") return "new"\n'
        '    if (value === "restart-required") return "restart"\n'
        '    return value\n'
        '  }\n'
        '\n'
        '  function electronLabel(name) {\n'
        '    var value = root.electronStatus[name] || "unknown"\n'
        '    if (value === "restart-required") return "restart"\n'
        '    if (value === "unsupported") return "unsupported"\n'
        '    if (value === "unavailable") return "unavailable"\n'
        '    if (value === "refused") return "refused"\n'
        '    if (value === "supported") return "available"\n'
        '    return value\n'
        '  }\n'
        '\n'
        '  function shellLabel(name) {\n'
        '    var value = root.shellStatus[name] || "unknown"\n'
        '    if (value === "prompt-refresh") return "live"\n'
        '    if (value === "unavailable") return "n/a"\n'
        '    return value\n'
        '  }\n'
        '\n'
        '  function desktopLabel(name) {\n'
        '    var value = root.desktopStatus[name] || "unknown"\n'
        '    if (value === "synchronized") return "synced"\n'
        '    if (value === "not-installed") return "unavailable"\n'
        '    if (value === "restart-required") return "restart"\n'
        '    if (value === "pending") return "next launch"\n'
        '    if (value === "disabled") return "off"\n'
        '    return value\n'
        '  }\n'
        '\n'
        '  function targetShort(name) {\n'
        '    var labels = ({ starship: "S", bash: "B", zsh: "Z", fish: "F", kitty: "K", foot: "F", ghostty: "G", vscode: "VS", discord: "D", slack: "S", obsidian: "O", gtk: "G", qtKde: "Q", darkReader: "DR", pearDesktop: "P", flatpak: "F", browsers: "B" })\n'
        '    return labels[name] || name\n'
        '  }\n'
        '\n'
        '  FileView {\n'
        '    id: electronStatusFile\n'
        '    path: root.stateDir + "/electron.json"\n'
        '    printErrors: false\n'
        '    watchChanges: true\n'
        '    onLoaded: {\n'
        '      try {\n'
        '        var parsed = JSON.parse(text())\n'
        '        root.electronStatus = {\n'
        '          vscode: String(parsed.vscode || "unknown"),\n'
        '          discord: String(parsed.discord || "unsupported"),\n'
        '          slack: String(parsed.slack || "unsupported"),\n'
        '          obsidian: String(parsed.obsidian || "unsupported")\n'
        '        }\n'
        '      } catch (error) {\n'
        '        root.electronStatus = ({ vscode: "unknown", discord: "unsupported", slack: "unsupported", obsidian: "unsupported" })\n'
        '      }\n'
        '    }\n'
        '    onLoadFailed: root.electronStatus = ({ vscode: "unknown", discord: "unsupported", slack: "unsupported", obsidian: "unsupported" })\n'
        '  }\n'
        '\n'
        '  FileView {\n'
        '    id: terminalStatusFile\n'
        '    path: root.stateDir + "/terminals.json"\n'
        '    printErrors: false\n'
        '    watchChanges: true\n'
        '    onLoaded: {\n'
        '      try {\n'
        '        var parsed = JSON.parse(text())\n'
        '        root.terminalStatus = {\n'
        '          kitty: String(parsed.kitty || "unknown"),\n'
        '          foot: String(parsed.foot || "unknown"),\n'
        '          ghostty: String(parsed.ghostty || "unknown")\n'
        '        }\n'
        '      } catch (error) {\n'
        '        root.terminalStatus = ({ kitty: "unknown", foot: "unknown", ghostty: "unknown" })\n'
        '      }\n'
        '    }\n'
        '    onLoadFailed: root.terminalStatus = ({ kitty: "unknown", foot: "unknown", ghostty: "unknown" })\n'
        '  }\n'
        '\n'
        '  FileView {\n'
        '    id: shellStatusFile\n'
        '    path: root.stateDir + "/shell.json"\n'
        '    printErrors: false\n'
        '    watchChanges: true\n'
        '    onLoaded: {\n'
        '      try {\n'
        '        var parsed = JSON.parse(text())\n'
        '        root.shellStatus = {\n'
        '          starship: String(parsed.starship || "unknown"),\n'
        '          bash: String(parsed.bash || "unknown"),\n'
        '          zsh: String(parsed.zsh || "unknown"),\n'
        '          fish: String(parsed.fish || "unknown")\n'
        '        }\n'
        '      } catch (error) {\n'
        '        root.shellStatus = ({ starship: "unknown", bash: "unknown", zsh: "unknown", fish: "unknown" })\n'
        '      }\n'
        '    }\n'
        '    onLoadFailed: root.shellStatus = ({ starship: "unknown", bash: "unknown", zsh: "unknown", fish: "unknown" })\n'
        '  }\n'
        '\n'
        '  FileView {\n'
        '    id: desktopStatusFile\n'
        '    path: root.stateDir + "/status.json"\n'
        '    printErrors: false\n'
        '    watchChanges: true\n'
        '    onLoaded: {\n'
        '      try {\n'
        '        var parsed = JSON.parse(text())\n'
        '        root.desktopStatus = {\n'
        '          gtk: String(parsed.gtk || "unknown"),\n'
        '          qtKde: String(parsed.qtKde || "unknown"),\n'
        '          darkReader: String(parsed.darkReader || "unknown"),\n'
        '          pearDesktop: String(parsed.pearDesktop || "unknown"),\n'
        '          flatpak: String(parsed.flatpak || "unknown"),\n'
        '          browsers: String(parsed.browsers || "unknown")\n'
        '        }\n'
        '      } catch (error) {\n'
        '        root.desktopStatus = ({ gtk: "unknown", qtKde: "unknown", darkReader: "unknown", pearDesktop: "unknown", flatpak: "unknown", browsers: "unknown" })\n'
        '      }\n'
        '    }\n'
        '    onLoadFailed: root.desktopStatus = ({ gtk: "unknown", qtKde: "unknown", darkReader: "unknown", pearDesktop: "unknown", flatpak: "unknown", browsers: "unknown" })\n'
        '  }\n'
    )
    if property_marker not in text:
        raise SystemExit("terminal status property marker was not found")
    text = text.replace(property_marker, property_insert, 1)
    ui_marker = (
        '        Text {\n'
        '          visible: !root.guideOpen && root.ready\n'
        '          text: refreshProcess.running\n'
    )
    ui_insert = (
        '        Text {\n'
        '          visible: !root.guideOpen && root.ready\n'
        '          text: "Shell  " + root.targetShort("starship") + " " + root.shellLabel("starship")\n'
        '            + "  " + root.targetShort("bash") + " " + root.shellLabel("bash")\n'
        '            + "  " + root.targetShort("zsh") + " " + root.shellLabel("zsh")\n'
        '            + "  " + root.targetShort("fish") + " " + root.shellLabel("fish")\n'
        '          color: Color.muted\n'
        '          font.family: root.bar ? root.bar.fontFamily : Style.font.family\n'
        '          font.pixelSize: Style.font.caption\n'
        '          width: parent.width\n'
        '          maximumLineCount: 1\n'
        '          elide: Text.ElideRight\n'
        '        }\n'
        '\n'
        '        Text {\n'
        '          visible: !root.guideOpen && root.ready\n'
        '          text: "Terminals  " + root.targetShort("kitty") + " " + root.terminalLabel("kitty")\n'
        '            + "  " + root.targetShort("foot") + " " + root.terminalLabel("foot")\n'
        '            + "  " + root.targetShort("ghostty") + " " + root.terminalLabel("ghostty")\n'
        '          color: Color.muted\n'
        '          font.family: root.bar ? root.bar.fontFamily : Style.font.family\n'
        '          font.pixelSize: Style.font.caption\n'
        '          width: parent.width\n'
        '          maximumLineCount: 1\n'
        '          elide: Text.ElideRight\n'
        '        }\n'
        '\n'
        '        Text {\n'
        '          visible: !root.guideOpen && root.ready\n'
        '          text: "Electron  " + root.targetShort("vscode") + " " + root.electronLabel("vscode")\n'
        '            + "  " + root.targetShort("discord") + " " + root.electronLabel("discord")\n'
        '            + "  " + root.targetShort("slack") + " " + root.electronLabel("slack")\n'
        '            + "  " + root.targetShort("obsidian") + " " + root.electronLabel("obsidian")\n'
        '          color: Color.muted\n'
        '          font.family: root.bar ? root.bar.fontFamily : Style.font.family\n'
        '          font.pixelSize: Style.font.caption\n'
        '          width: parent.width\n'
        '          maximumLineCount: 1\n'
        '          elide: Text.ElideRight\n'
        '        }\n'
        '\n'
        '        Text {\n'
        '          visible: !root.guideOpen && root.ready\n'
        '          text: "Desktop  " + root.targetShort("gtk") + " " + root.desktopLabel("gtk")\n'
        '            + "  " + root.targetShort("qtKde") + " " + root.desktopLabel("qtKde")\n'
        '            + "  " + root.targetShort("darkReader") + " " + root.desktopLabel("darkReader")\n'
        '            + "  " + root.targetShort("pearDesktop") + " " + root.desktopLabel("pearDesktop")\n'
        '            + "  " + root.targetShort("flatpak") + " " + root.desktopLabel("flatpak")\n'
        '            + "  " + root.targetShort("browsers") + " " + root.desktopLabel("browsers")\n'
        '          color: Color.muted\n'
        '          font.family: root.bar ? root.bar.fontFamily : Style.font.family\n'
        '          font.pixelSize: Style.font.caption\n'
        '          width: parent.width\n'
        '          maximumLineCount: 1\n'
        '          elide: Text.ElideRight\n'
        '        }\n'
        '\n'
    ) + ui_marker
    if ui_marker not in text:
        raise SystemExit("terminal status UI marker was not found")
    text = text.replace(ui_marker, ui_insert, 1)
    for marker, message in (
        (
            '  property var desktopStatus: ({ gtk: "unknown", qtKde: "unknown", darkReader: "unknown", pearDesktop: "unknown", flatpak: "unknown", browsers: "unknown" })\n',
            "desktop status property marker was not inserted",
        ),
        (
            '    id: desktopStatusFile\n'
            '    path: root.stateDir + "/status.json"\n'
            '    printErrors: false\n'
            '    watchChanges: true\n',
            "desktop status watcher marker was not inserted",
        ),
        (
            '    onLoadFailed: root.desktopStatus = ({ gtk: "unknown", qtKde: "unknown", darkReader: "unknown", pearDesktop: "unknown", flatpak: "unknown", browsers: "unknown" })\n',
            "desktop status fallback marker was not inserted",
        ),
        (
            '          text: "Desktop  " + root.targetShort("gtk") + " " + root.desktopLabel("gtk")\n',
            "desktop status UI marker was not inserted",
        ),
        (
            '  function targetShort(name) {\n'
            '    var labels = ({ starship: "S", bash: "B", zsh: "Z", fish: "F", kitty: "K", foot: "F", ghostty: "G", vscode: "VS", discord: "D", slack: "S", obsidian: "O", gtk: "G", qtKde: "Q", darkReader: "DR", pearDesktop: "P", flatpak: "F", browsers: "B" })\n',
            "target abbreviation helper marker was not inserted",
        ),
        (
            '          text: "Shell  " + root.targetShort("starship") + " " + root.shellLabel("starship")\n',
            "compact shell status UI marker was not inserted",
        ),
        ('          maximumLineCount: 1\n          elide: Text.ElideRight\n', "single-line status UI marker was not inserted"),
    ):
        if marker not in text:
            raise SystemExit(message)
    panel.write_text(text)
    PY
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
    python3
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
