{
  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    make-shell.url = "github:nicknovitski/make-shell";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    systems.url = "github:nix-systems/default";
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ inputs.make-shell.flakeModules.default ];

      systems = import inputs.systems;

      perSystem = { pkgs, system, ... }: let
        tfccli = pkgs.stdenv.mkDerivation rec {
          pname = "tfccli";
          version = "0.11.0";

          src = pkgs.fetchurl {
            url = "https://github.com/richclement/tfccli/releases/download/v${version}/tfccli_${version}_linux_amd64.tar.gz";
            sha256 = "sha256-QEjiQMJ1zK+oPaKeqoTDuRbRgaK68J5ptSmcdcUMDzE=";
          };

          nativeBuildInputs = [ pkgs.unzip ];

          unpackPhase = ''
            tar xzf $src
          '';

          installPhase = ''
            mkdir -p $out/bin
            cp tfccli $out/bin/
          '';
        };
      in {
        _module.args.pkgs = import inputs.nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };

        make-shells = rec {
          default = ci;
          
          ci.packages = with pkgs; [
            google-cloud-sdk
            terraform
            gh
            jq
            git
            shellcheck
            check-jsonschema
            yamllint
            nodePackages.commitlint
            python3Packages.pyyaml
            yq
            gettext
          ];

          bootstrap.packages = with pkgs; [
            google-cloud-sdk
            terraform
            gh
            jq
            git
            shellcheck
            check-jsonschema
            yamllint
            nodePackages.commitlint
            python3Packages.pyyaml
            yq
            gettext
            tfccli
          ];
        };
      };
    };
}
