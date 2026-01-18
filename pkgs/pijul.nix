{ pkgs, lib, ... }:

let
  # Définir ici la version désirée (vérifier sur crates.io)
  pijulVersion = "1.0.0-beta.11";
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
        sha256 = "sha256-+rMMqo2LBYlCFQJv8WFCSEJgDUbMi8DnVDKXIWm3tIk=";
      };

      # Laissez ce hash à zéro pour la seconde erreur (hash des dépendances compilées)
      cargoHash = "sha256-IhArTiReUdj49bA+XseQpOiszK801xX5LdLj8vXD8rs=";

      buildFeatures = [ "git" ];

      postPatch = ''
        # 1. FIX IMPORT : On ajoute l'import manquant tout en haut du fichier (Ligne 1)
        #    On utilise 'as _' pour éviter les conflits de noms.
        sed -i '1i use ::sanakirja::RootPageMut as _;' src/commands/git.rs

        # 2. FIX RAND 0.9 : On remplace l'ancien module 'distributions' par 'distr'
        #    C'est un changement de rupture de la librairie 'rand' v0.9 utilisée par ce projet.
        sed -i 's/rand::distributions::Alphanumeric/rand::distr::Alphanumeric/g' src/commands/git.rs
      '';

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
        xxHash
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
