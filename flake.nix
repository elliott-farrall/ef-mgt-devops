{
  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    systems.url = "github:nix-systems/default";
  };

  outputs = inputs @ { flake-parts, nixpkgs, systems, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = builtins.attrNames systems;

      perSystem = { pkgs, ... }: {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            gcloud-sdk
            terraform
            gh
            jq
            git
            python3Packages.check-jsonschema
            python3Packages.pyyaml
            yaml-language-server
          ];

          environment.variables = {
            TF_VAR_environment = "mgt";
          };
        };

        devShells.bootstrap = pkgs.mkShell {
          packages = with pkgs; [
            gcloud-sdk
            terraform
            tfccli
            gh
            jq
            git
            gettext
            yq
          ];

          environment.variables = {
            TF_VAR_environment = "mgt";
          };
        };
      };
    };
}
