# Home Manager module: programs.hi-shell.enable = true;
self:
{ config, lib, pkgs, ... }:

let
  cfg = config.programs.hi-shell;
  shellDir = "${cfg.package}/share/hi-shell";
  hyprDir = "${config.xdg.configHome}/hypr/hi-shell";
in
{
  options.programs.hi-shell = {
    enable = lib.mkEnableOption "hi-shell, a Material 3 desktop shell for Hyprland";

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.hi-shell;
      defaultText = lib.literalExpression "hi-shell.packages.\${system}.hi-shell";
      description = "The hi-shell package.";
    };

    hyprland.installFiles = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Copy hi-shell's Hyprland files (keybinds, window and layer rules) to
        `~/.config/hypr/hi-shell/`. Copies, not links: the shell writes `overrides.lua` there and
        the files are yours to edit. Only `startup.lua` (it points at the package in the store) is
        replaced on every switch; the others are copied when missing.
        Load them from your `hyprland.lua` yourself:
        `dofile(os.getenv("HOME") .. "/.config/hypr/hi-shell/init.lua")`
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      cfg.package
      pkgs.material-symbols # the icon font (Material Symbols Rounded)
    ];
    fonts.fontconfig.enable = true;

    # `qs -c hi-shell` (the keybinds' IPC calls, Wait Mode) looks for the shell here.
    xdg.configFile."quickshell/hi-shell".source = shellDir;

    home.activation.hiShellHyprland = lib.mkIf cfg.hyprland.installFiles (
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        $DRY_RUN_CMD mkdir -p "${hyprDir}"
        for src in ${shellDir}/hypr/hi-shell/*.lua; do
          name="$(basename "$src")"
          if [ "$name" = startup.lua ] || [ ! -e "${hyprDir}/$name" ]; then
            $DRY_RUN_CMD install -m 644 "$src" "${hyprDir}/$name"
          fi
        done
      ''
    );
  };
}
