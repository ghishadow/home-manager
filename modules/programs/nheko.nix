{ config, lib, pkgs, ... }:

with lib;

let

  cfg = config.programs.nheko;

  iniFmt = pkgs.formats.ini { };

  configDir = if pkgs.stdenv.hostPlatform.isDarwin then
    "Library/Application Support"
  else
    config.xdg.configHome;

  camelCaseToSnakeCase =
    replaceStrings upperChars (map (s: "_${s}") lowerChars);

  inherit (generators) mkKeyValueDefault toINI;

in {
  meta.maintainers = [ maintainers.gvolpe ];

  options.programs.nheko = {
    enable = mkEnableOption "Qt desktop client for Matrix";

    package = mkPackageOption pkgs "nheko" { };

    settings = mkOption {
      type = iniFmt.type;
      default = { };
      example = literalExpression ''
        {
          general.disableCertificateValidation = false;
          auth = {
            accessToken = "SECRET";
            deviceId = "MY_DEVICE";
            homeServer = "https://matrix-client.matrix.org:443";
            userId = "@@user:matrix.org";
          };
          settings.scaleFactor = 1.0;
          sidebar.width = 416;
          user = {
            alertOnNotification = true;
            animateImagesOnHover = false;
            "sidebar\\roomListWidth" = 308;
          };
        }
      '';
      description = ''
        Attribute set of Nheko preferences (converted to an INI file).

        </para><para>

        For now, it is recommended to run nheko and sign-in before filling in
        the configuration settings in this module, as nheko writes the access
        token to <filename>$XDG_CONFIG_HOME/nheko/nheko.conf</filename> the
        first time we sign in, and we need that data into these settings for the
        correct functionality of the application.

        </para><para>

        This a temporary inconvenience, however, as nheko has plans to move the
        authentication stuff into the local database they currently use. Once
        this happens, this will no longer be an issue.
      '';
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ cfg.package ];

    home.file."${configDir}/nheko/nheko.conf" = mkIf (cfg.settings != { }) {
      text = ''
        ; Generated by Home Manager.

        ${toINI {
          mkKeyValue = k: v:
            mkKeyValueDefault { } "=" (camelCaseToSnakeCase k) v;
        } cfg.settings}
      '';
    };
  };
}

