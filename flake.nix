{
  description = "Rio | A hardware-accelerated GPU terminal emulator";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    rust-overlay.url = "github:oxalica/rust-overlay";
    systems = {
      url = "github:nix-systems/default";
      flake = false;
    };
  };

  outputs = {
    self,
    nixpkgs,
    rust-overlay,
    systems,
  }: let
    inherit (nixpkgs) lib;
    eachSystem = lib.genAttrs (import systems);
    pkgsFor = eachSystem (system:
      import nixpkgs {
        localSystem.system = system;
        overlays = [(rust-overlay.overlays.default)];
      });
    mkDevShell = pkgs: rust-toolchain: let
      runtimeDeps = self.packages.${pkgs.hostPlatform.system}.rio.runtimeDependencies;
      tools = self.packages.${pkgs.hostPlatform.system}.rio.nativeBuildInputs ++ self.packages.${pkgs.hostPlatform.system}.rio.buildInputs ++ [rust-toolchain];
    in
      pkgs.mkShell {
        LD_LIBRARY_PATH = "${pkgs.lib.makeLibraryPath runtimeDeps}";
        packages = tools ++ [rust-toolchain];
      };
  in {
    formatter = lib.mapAttrs (_: pkgs: pkgs.alejandra) pkgsFor;
    packages =
      lib.mapAttrs (system: pkgs: {
        default = self.packages.${system}.rio;
        rio = pkgs.callPackage ./pkgRio.nix {rust-toolchain = pkgs.rust-bin.stable.latest.minimal;};
      })
      pkgsFor;
    devShells =
      lib.mapAttrs (system: pkgs: {
        default = self.devShells.${system}.msrv;
        msrv = mkDevShell pkgs (pkgs.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml);
        stable = mkDevShell pkgs pkgs.rust-bin.stable.latest.default;
        nightly = mkDevShell pkgs (pkgs.rust-bin.selectLatestNightlyWith (toolchain: toolchain.default));
      })
      pkgsFor;
    apps =
      lib.mapAttrs (system: pkgs: {
        default = {
          type = "app";
          program = lib.getExe self.packages.${system}.default;
        };
      })
      pkgsFor;
  };
}
