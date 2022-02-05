{ config, lib, pkgs, ... }:

with lib;
with builtins;

let

  cfg = config.programs.astroid;

  jsonFormat = pkgs.formats.json { };

  astroidAccounts =
    filterAttrs (n: v: v.astroid.enable) config.accounts.email.accounts;

  boolOpt = b: if b then "true" else "false";

  accountAttr = account:
    with account;
    {
      email = address;
      name = realName;
      sendmail = astroid.sendMailCommand;
      additional_sent_tags = "";
      default = boolOpt primary;
      save_drafts_to = "${maildir.absPath}/${folders.drafts}/cur/";
      save_sent = "true";
      save_sent_to = "${maildir.absPath}/${folders.sent}/cur/";
      select_query = "";
    } // optionalAttrs (signature.showSignature != "none") {
      signature_attach = boolOpt (signature.showSignature == "attach");
      signature_default_on = boolOpt (signature.showSignature != "none");
      signature_file = pkgs.writeText "signature.txt" signature.text;
      signature_file_markdown = "false";
      signature_separate = "true"; # prepends '--\n' to the signature
    } // optionalAttrs (gpg != null) {
      always_gpg_sign = boolOpt gpg.signByDefault;
      gpgkey = gpg.key;
    } // astroid.extraConfig;

  # See https://github.com/astroidmail/astroid/wiki/Configuration-Reference
  finalConfig = let
    template = fromJSON (readFile ./astroid-config-template.json);
    astroidConfig = foldl' recursiveUpdate template [
      {
        astroid.notmuch_config =
          "${config.xdg.configHome}/notmuch/default/config";
        accounts = mapAttrs (n: accountAttr) astroidAccounts;
        crypto.gpg.path = "${pkgs.gnupg}/bin/gpg";
      }
      cfg.extraConfig
      cfg.externalEditor
    ];
  in astroidConfig;

in {
  options = {
    programs.astroid = {
      enable = mkEnableOption "Astroid";

      pollScript = mkOption {
        type = types.str;
        default = "";
        example = "mbsync gmail";
        description = ''
          Script to run to fetch/update mails.
        '';
      };

      externalEditor = mkOption {
        type = types.nullOr types.str;
        default = null;
        # Converts it into JSON that can be merged into the configuration.
        apply = cmd:
          optionalAttrs (cmd != null) {
            editor = {
              "external_editor" = "true";
              "cmd" = cmd;
            };
          };
        example =
          "nvim-qt -- -c 'set ft=mail' '+set fileencoding=utf-8' '+set ff=unix' '+set enc=utf-8' '+set fo+=w' %1";
        description = ''
          You can use <code>%1</code>, <code>%2</code>, and
          <code>%3</code> to refer respectively to:
          <orderedlist numeration="arabic">
            <listitem><para>file name</para></listitem>
            <listitem><para>server name</para></listitem>
            <listitem><para>socket ID</para></listitem>
          </orderedlist>
          See <link xlink:href='https://github.com/astroidmail/astroid/wiki/Customizing-editor' />.
        '';
      };

      extraConfig = mkOption {
        type = jsonFormat.type;
        default = { };
        example = literalExpression ''
          {
            poll.interval = 0;
          }
        '';
        description = ''
          JSON config that will override the default Astroid configuration.
        '';
      };
    };

    accounts.email.accounts = mkOption {
      type = with types; attrsOf (submodule (import ./astroid-accounts.nix));
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ pkgs.astroid ];

    xdg.configFile."astroid/config".source =
      jsonFormat.generate "astroid-config" finalConfig;

    xdg.configFile."astroid/poll.sh" = {
      executable = true;
      text = ''
        # Generated by Home Manager

        ${cfg.pollScript}
      '';
    };
  };
}
