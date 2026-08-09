{
  description = "Profile-aware agent skills and bootstrap packs";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          skillPacks = pkgs.writeShellApplication {
            name = "skill-packs";
            runtimeInputs = [
              pkgs.jq
              pkgs.skills
            ];
            text = ''
              export PACKS_DIR=${./packs}
              exec ${./packs.sh} "$@"
            '';
          };
        in
        {
          skill-packs = skillPacks;
          default = skillPacks;
        }
      );
    in
    {
      lib = import ./lib;
      inherit packages;
      apps = forAllSystems (
        system:
        let
          app = {
            type = "app";
            program = "${packages.${system}.skill-packs}/bin/skill-packs";
          };
        in
        {
          packs = app;
          default = app;
        }
      );
    };
}
