{
  config,
  lib,
  pkgs,
  options,
  ...
}:

let
  cfg = config.services.prometheus.exporters.smartctl;

  inherit (lib) mkOption types literalExpression;

  args = lib.escapeShellArgs (
    [
      "--web.listen-address=${cfg.listenAddress}:${toString cfg.port}"
      "--smartctl.interval=${cfg.maxInterval}"
    ]
    ++ map (device: "--smartctl.device=${device}") cfg.devices
    ++ cfg.extraFlags
  );

in
{
  port = 9633;

  extraOpts = {
    devices = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = literalExpression ''
        [ "/dev/sda", "/dev/nvme0n1" ];
      '';
      description = ''
        Paths to the disks that will be monitored. Will autodiscover
        all disks if none given.
      '';
    };

    maxInterval = mkOption {
      type = types.str;
      default = "60s";
      example = "2m";
      description = ''
        Interval that limits how often a disk can be queried.
      '';
    };
  };

  serviceOpts = {
    serviceConfig = {
      AmbientCapabilities = [
        "CAP_SYS_RAWIO"
        "CAP_SYS_ADMIN"
      ];
      CapabilityBoundingSet = [
        "CAP_SYS_RAWIO"
        "CAP_SYS_ADMIN"
      ];
      DevicePolicy = "closed";
      DeviceAllow = lib.mkOverride 50 [
        "block-blkext rw"
        "block-sd rw"
        "char-nvme rw"
      ];
      ExecStart = "${pkgs.prometheus-smartctl-exporter}/bin/smartctl_exporter ${args}";
      PrivateDevices = lib.mkForce false;
      ProtectProc = "invisible";
      ProcSubset = "pid";
      SupplementaryGroups = [
        "disk"
        "smartctl-exporter-access"
      ];
      SystemCallFilter = [
        "@system-service"
        "~@privileged"
      ];
    };
  };
}
