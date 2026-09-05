{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    naersk = {
      url = "github:nix-community/naersk";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, naersk }:
    let
      pkgs = import nixpkgs { system = "x86_64-linux"; };
      lib = pkgs.lib;
      naerskLib = pkgs.callPackage naersk {};
      cLibs = with pkgs; [ glib ];
    in
    {
      devShells.x86_64-linux.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          cargo rustc rustfmt clippy rust-analyzer
        ] ++ cLibs;
        nativeBuildInputs = with pkgs; [ 
          pkg-config mold 
        ];
        env.RUST_SRC_PATH = "${pkgs.rust.packages.stable.rustPlatform.rustLibSrc}";
        env.RUSTFLAGS = "-C link-arg=-fuse-ld=${pkgs.mold}/bin/mold";
        shellHook = ''
          export LD_LIBRARY_PATH=${pkgs.lib.makeLibraryPath cLibs}:$LD_LIBRARY_PATH
          echo
        '';
      };

      packages.x86_64-linux.default = naerskLib.buildPackage {
        name = "my-app";
        src = ./.;
        buildInputs = [ pkgs.glib ];
        nativeBuildInputs = [ pkgs.pkg-config ];
      };

      packages.x86_64-linux.callPackage =
        pkgs.callPackage ./default.nix { };

      apps.x86_64-linux.init = {
        type = "app";
        program = "${lib.getExe (pkgs.writeShellScriptBin "cargo-init" ''
          ${lib.getExe pkgs.cargo} init "$@"
          mkdir .cargo
          cat > config.toml <<EOF
          [target.x86_64-unknown-linux-gnu]
          rustflags = ["-C", "link-arg=-fuse-ld=${pkgs.mold}/bin/mold"]
          EOF
          mv config.toml .cargo/
          git add -A
        '')}";
      };
  };
}
