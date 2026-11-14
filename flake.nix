{
  description = "EF Cloud Infrastructure Framework — management plane";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs @ { flake-parts, nixpkgs, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];

      perSystem = { config, self', inputs', pkgs, system, ... }: {
        devShells.default = pkgs.mkShell {
          name = "ef-dev";

          packages = with pkgs; [
            # Bootstrap & CI tooling
            gcloud-sdk
            terraform
            tfccli
            gh
            jq
            curl
            git

            # Schema validation (CI)
            python3Packages.check-jsonschema
            python3Packages.pyyaml
            yaml-language-server
          ];

          shellHook = ''
            export TF_VAR_environment=mgt
            echo "EF devshell ready."
            echo "Run: scripts/bootstrap.sh"
          '';
        };
      };
    };
}
