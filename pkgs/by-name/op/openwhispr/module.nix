{ config, lib, pkgs, ... }:

let
  cfg = config.programs.openwhispr;
in
{
  options.programs.openwhispr = {
    enable = lib.mkEnableOption "OpenWhispr, a voice-to-text dictation app";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.openwhispr ];

    # Allow access to /dev/uinput (required by ydotoold for keyboard simulation)
    hardware.uinput.enable = true;

    # ydotoold daemon: runs per-user, provides the socket that ydotool connects to
    systemd.user.services.ydotoold = {
      description = "ydotool daemon";
      wantedBy = [ "default.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.ydotool}/bin/ydotoold";
        Restart = "on-failure";
      };
    };
  };
}
