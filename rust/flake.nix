{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    naersk = {
      url = "github:nix-community/naersk";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    use-mold.url = "github:campbellcole/use-mold";
  };

  # mold setup currently doesn't work

  outputs = { self, nixpkgs, naersk, use-mold }:
    let
      pkgs = import nixpkgs { system = "x86_64-linux"; };
      lib = pkgs.lib;
      naerskLib = pkgs.callPackage naersk {};
      cLibs = with pkgs; [ glib ];
      buildpkgs = with pkgs; [ 
        cargo
        cargo
        glib
        rustc 
        rustfmt 
        clippy 
        rust-analyzer 
        clang 
      ];
      nativebuildpkgs = with pkgs; [ pkg-config clang ];
      moldHook = use-mold.useMoldHook {
        # all attributes are optional and their default values are shown here
        cargoConfigDir = "$PWD/.cargo";
        
        # the `linker` attribute is the full path to the mold binary
        configTemplate = ({ linker }: ''
          [target.x86_64-unknown-linux-gnu]
          linker = "clang"
          rustflags = ["-C", "link-arg=-fuse-ld=${linker}"]
        '');

        # extra shell hook code to include after the mold hook
        extraShellHook = "";
        
        # setting this to false will cause the config to become invalid when mold updates!
        # it is recommended to leave this as true
        force = true;

        # usually, calling useMoldHook with an empty attrset suffices:
        # moldHook = use-mold.useMoldHook {};
      };
    in
    {
      devShells.x86_64-linux.default = pkgs.mkShell {
        buildInputs = buildpkgs ++ cLibs;
        nativeBuildInputs = nativebuildpkgs;
        env.RUST_SRC_PATH = "${pkgs.rust.packages.stable.rustPlatform.rustLibSrc}";

        LD_LIBRARY_PATH = lib.makeLibraryPath (buildpkgs ++ cLibs);
        shellHook = moldHook pkgs.mold;
      };

      # Build options
      packages.x86_64-linux.default = naerskLib.buildPackage {
        name = "build";
        src = ./.;
        nativeBuildInputs = nativebuildpkgs ++ [ pkgs.mold ];
        RUSTFLAGS = "-C link-arg=-fuse-ld=${pkgs.mold}/bin/mold -C linker=clang";
      };
      packages.x86_64-linux.callPackage =
        pkgs.callPackage ./default.nix { };
      

      # Cargo tools
      apps.x86_64-linux.test = {
        type = "app";
        program = "${lib.getExe (pkgs.writeShellScriptBin "cargo-test" ''
          exec nix develop "${self}#default" --command cargo test "$@"
        '')}";
      };

      apps.x86_64-linux.run = {
        type = "app";
        program = "${lib.getExe (pkgs.writeShellScriptBin "cargo-run" ''
          exec nix develop "${self}#default" --command cargo run "$@"
        '')}";
      };

      apps.x86_64-linux.init = {
        type = "app";
        program = "${lib.getExe (pkgs.writeShellScriptBin "cargo-init" ''
          ${lib.getExe pkgs.cargo} init "$@"
          ${lib.getExe pkgs.cargo} generate-lockfile
          git add -A
        '')}";
      };
  };
}
