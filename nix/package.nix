# hi-shell and everything it runs: the shell's files go to $out/share/hi-shell, and
# $out/bin/hi-shell starts them with the helper programs on PATH and the QML modules in place.
# Not on PATH (they need the system's setuid wrappers or services): pkexec, systemd.
{
  lib,
  stdenvNoCC,
  makeWrapper,
  quickshell,
  qt6,
  python3,
  matugen,
  wireplumber,
  networkmanager,
  bluez,
  upower,
  brightnessctl,
  ddcutil,
  libnotify,
  hyprsunset,
  hyprlock,
  hyprpicker,
  cliphist,
  translate-shell,
  grim,
  slurp,
  wl-clipboard,
  wf-recorder,
  wtype,
  cava,
  imagemagick,
  curl,
  libqalculate,
  tesseract,
  ffmpeg,
  playerctl,
  procps,
  git,
}:

let
  # Stdlib only, plus fontTools for the small icon font (services/icon_font.py).
  python = python3.withPackages (ps: [ ps.fonttools ]);
  tesseractLangs = tesseract.override { enableLanguages = [ "eng" "rus" ]; };

  runtimeDeps = [
    quickshell
    python
    matugen
    wireplumber
    networkmanager
    bluez
    upower
    brightnessctl
    ddcutil
    libnotify
    hyprsunset
    hyprlock
    hyprpicker
    cliphist
    translate-shell
    grim
    slurp
    wl-clipboard
    wf-recorder
    wtype
    cava
    imagemagick
    curl
    libqalculate
    tesseractLangs
    ffmpeg
    playerctl
    procps
    git
  ];
in
stdenvNoCC.mkDerivation {
  pname = "hi-shell";
  version = "unstable";

  src = lib.fileset.toSource {
    root = ../.;
    fileset = lib.fileset.unions [
      ../common
      ../modules
      ../services
      ../translations
      ../wait-mode
      ../hypr
      ../dots
      ../shell.qml
      ../run.sh
      ../LICENSE
    ];
  };

  nativeBuildInputs = [ makeWrapper ];
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/hi-shell $out/bin
    cp -a . $out/share/hi-shell/
    chmod -R u+w $out/share/hi-shell

    # Hyprland starts the wrapper (the helper programs on PATH), not run.sh from ~/.config.
    substituteInPlace $out/share/hi-shell/hypr/hi-shell/startup.lua \
      --replace-fail 'os.getenv("HOME") .. "/.config/quickshell/hi-shell/run.sh"' '"'$out'/bin/hi-shell"'

    patchShebangs $out/share/hi-shell

    # qs -c hi-shell finds the shell through ~/.config/quickshell/hi-shell (see the Home Manager module).
    makeWrapper $out/share/hi-shell/run.sh $out/bin/hi-shell \
      --prefix PATH : ${lib.makeBinPath runtimeDeps} \
      --prefix QML2_IMPORT_PATH : ${qt6.qtmultimedia}/${qt6.qtbase.qtQmlPrefix} \
      --prefix QT_PLUGIN_PATH : ${qt6.qtmultimedia}/${qt6.qtbase.qtPluginPrefix} \
      --set PYTHONDONTWRITEBYTECODE 1
    runHook postInstall
  '';

  meta = {
    description = "Material 3 Expressive desktop shell for Hyprland with AI built in, on Quickshell";
    homepage = "https://github.com/imu-useful/hi-shell";
    license = lib.licenses.gpl2Only;
    platforms = lib.platforms.linux;
    mainProgram = "hi-shell";
  };
}
