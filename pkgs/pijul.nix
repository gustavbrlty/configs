{ pkgs, lib, ... }:

let
  # Définir ici la version désirée (vérifier sur crates.io)
  pijulVersion = "1.0.0-beta.15";
in
{
  home.packages = [
    (pkgs.rustPlatform.buildRustPackage rec {
      pname = "pijul";
      version = pijulVersion;

      # Au lieu de git, on récupère la source officielle depuis Crates.io
      src = pkgs.fetchCrate {
        inherit pname version;
        # Laissez ce hash à zéro pour la première erreur (hash de la source tarball)
        sha256 = "sha256-yXjqDydoRaldGxG87W5uvUeUfEmzDxis4nGOhGBc+Rs=";
      };

      # Laissez ce hash à zéro pour la seconde erreur (hash des dépendances compilées)
      cargoHash = "sha256-Zwy7z5ZgAZTVXnbl007ngDs1gJUilVuMlluTVpDjRVs=";

      buildFeatures = [ "git" ];

      # --- Dépendances de compilation ---
      nativeBuildInputs = with pkgs; [
        pkg-config
        protobuf
        clang
        llvmPackages.libclang # Souvent requis pour bindgen
      ];

      # --- Dépendances système ---
      buildInputs = with pkgs; [
        openssl
        libsodium
        zstd
        xxhash
        dbus
      ] ++ lib.optionals pkgs.stdenv.isDarwin [
        pkgs.darwin.apple_sdk.frameworks.Security
        pkgs.darwin.apple_sdk.frameworks.SystemConfiguration
        pkgs.darwin.apple_sdk.frameworks.CoreFoundation
      ];

      # Variables d'env pour aider Rust à trouver les libs C
      PKG_CONFIG_PATH = "${pkgs.openssl.dev}/lib/pkgconfig";
      LIBCLANG_PATH = "${pkgs.llvmPackages.libclang.lib}/lib";
      
      # On désactive les tests car ils nécessitent souvent une config git/pijul locale spécifique
      doCheck = false;
    })
  ];
}
