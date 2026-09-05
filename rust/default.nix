{
  rustPlatform,
  glib,
  pkg-config,
}:

rustPlatform.buildRustPackage {
  name = "example";
  src = ./.;
  cargoHash = "";
  buildInputs = [ 
    glib 
  ];
  nativeBuildInputs = [ pkg-config ];
}
