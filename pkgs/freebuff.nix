{ pkgs, lib, ... }:

let
  # Vérifier la dernière version sur https://registry.npmjs.org/freebuff/latest
  freebuffVersion = "0.0.171";
in
{
  home.packages = [
    (pkgs.stdenv.mkDerivation {
      pname = "freebuff";
      version = freebuffVersion;

      src = pkgs.fetchurl {
        url = "https://codebuff.com/api/releases/download/${freebuffVersion}/freebuff-linux-x64.tar.gz";
        # Laissez ce hash à zéro pour la première erreur (le bon hash sera affiché)
        sha256 = "sha256-1awl+z2EgtEEOiWDxXNsUBjEWqCqNELSuuhNn+hN3Zc=";
      };

      sourceRoot = ".";

      # Le binaire est un exécutable Bun auto-suffisant : patchelf/autoPatchelf
      # et le strip cassent son en-tête ELF. Il s'appuie sur nix-ld
      # (programs.nix-ld.enable = true dans OS.nix) pour trouver ld-linux.
      dontStrip = true;
      dontPatchELF = true;
      dontAutoPatchelf = true;

      installPhase = ''
        runHook preInstall
        mkdir -p $out/bin
        cp freebuff tree-sitter.wasm $out/bin/
        chmod +x $out/bin/freebuff
        runHook postInstall
      '';

      meta = with lib; {
        description = "The free coding agent for your terminal";
        homepage = "https://freebuff.com/cli";
        license = licenses.mit;
        platforms = [ "x86_64-linux" ];
        mainProgram = "freebuff";
      };
    })
  ];
}
