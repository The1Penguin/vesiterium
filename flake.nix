{
  description = "Prototype of Pisa and related thesis working files";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    systems.url = "github:nix-systems/x86_64-linux";

    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
  };

  outputs = inputs:
    let mkFlake = inputs.flake-parts.lib.mkFlake { inherit inputs; };
    in mkFlake ({ inputs, ... }: {
      systems = import inputs.systems;
      imports = [
        inputs.flake-parts.flakeModules.easyOverlay
      ];
      perSystem = { self', lib, pkgs, ... }:
        {
          packages = {
            default = self'.packages.vesiterium;
            lean-toolchain = pkgs.callPackage
              ({ lean-toolchain-name, hash, lib, runCommand, fetchurl, zstd, clangStdenv, patchelf, runtimeShell }:
              let
                inherit (clangStdenv) cc;
                parsed = lib.splitString ":" lean-toolchain-name;
                repo = lib.elemAt parsed 0;
                tc = lib.elemAt parsed 1;
                tc' = lib.removePrefix "v" tc;
                final =
                  runCommand lean-toolchain-name
                  {
                    passthru = {
                      ELAN_TOOLCHAIN = lean-toolchain-name;
                      inherit root;
                    };
                  }
                  ''
                    TC=$out/toolchains/${lib.replaceStrings ["/"] ["--"] repo}---${tc}
                    mkdir -p $(dirname $TC)
                    ln -s ${root} $TC
                  '';
                root =
                  runCommand "${lean-toolchain-name}-root"
                  {
                    src = fetchurl {
                      url = "https://github.com/${repo}/releases/download/${tc}/lean-${tc'}-linux.tar.zst"; # XXX: only x86_64-linux
                      inherit hash;
                    };
                    nativeBuildInputs = [ patchelf zstd ];
                  }
                  ''
                    mkdir -p $out
                    tar --zstd -xf $src -C $out lean-${tc'}-linux --strip 1
                    cd $out/bin
                    rm llvm-ar
                    find . -type f -exec \
                      patchelf --set-interpreter $(cat ${cc}/nix-support/dynamic-linker) {} \;
                    ln -s ${cc}/bin/ar llvm-ar

                    mv leanc{,.orig}
                    cat > leanc << EOF
                    #! ${runtimeShell}
                    dir="\$(dirname "\''${BASH_SOURCE[0]}")"
                    # use bundled libraries, but not bundled compiler that doesn't know about NIX_LDFLAGS
                    LEAN_CC="\''${LEAN_CC:-${cc}/bin/cc}" exec -a "\$0" "\$dir/leanc.orig" "\$@" -L"\$dir/../lib"
                    EOF
                    chmod 755 leanc

                    mv lake{,.orig}
                    cat > cc << EOF
                    #! ${runtimeShell}
                    dir="\$(dirname "\''${BASH_SOURCE[0]}")"
                    # use bundled libraries, but not bundled compiler that doesn't know about NIX_LDFLAGS
                    exec "${cc}/bin/cc" "\$@" -L"\$dir/../lib"
                    EOF
                    cat > lake << EOF
                    #! ${runtimeShell}
                    dir="\$(dirname "\''${BASH_SOURCE[0]}")"
                    # use custom `cc`
                    LEAN_CC="\''${LEAN_CC:-\$dir/cc}" exec -a "\$0" "\$dir/lake.orig" "\$@"
                    EOF
                    chmod 755 lake cc
                  '';
              in final) {
                lean-toolchain-name = lib.trim (lib.readFile ./lean-toolchain);
                hash = "sha256-7NAo1vZCthtFHIaHrusk3VN4n7/ct9StuPXPYOsgIro=";
              };
            vesiterium = pkgs.callPackage
              ({ lib, clangStdenv, lean-toolchain, makeWrapper, elan }:
                clangStdenv.mkDerivation (drv: {
                  name = "vesiterium";
                  src = ./.;
                  LAKE_HOME = "${lean-toolchain.passthru.root}";
                  buildPhase = "$LAKE_HOME/bin/lake build";
                  nativeBuildInputs = [ makeWrapper ];
                  installPhase = ''
                    mkdir -p $out/bin
                    install -t $out/bin .lake/build/bin/${drv.name}
                    wrapProgram $out/bin/${drv.name} \
                        --suffix PATH : ${lib.makeBinPath [ elan ]}
                  '';
                })
              ) { inherit (self'.packages) lean-toolchain; };
          };

          devShells.default = (pkgs.mkShell.override { stdenv = pkgs.clangStdenv; }) {
            packages = with self'.packages; [ lean-toolchain.passthru.root ];
            enterShell = ''
              LAKE_HOME="${self'.packages.lean-toolchain.passthru.root}";
            '';
          };
        };
    });
}
