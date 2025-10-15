{
  description = "Logos Test Example - Pulls and compiles logos-liblogos, logos-package-manager, and logos-capability-module";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    logos-liblogos.url = "git+ssh://git@github.com/logos-co/logos-liblogos.git";
    logos-package-manager.url = "git+ssh://git@github.com/logos-co/logos-package-manager.git";
    logos-capability-module.url = "git+ssh://git@github.com/logos-co/logos-capability-module.git";
  };

  outputs = { self, nixpkgs, logos-liblogos, logos-package-manager, logos-capability-module }:
    let
      systems = [ "aarch64-darwin" "x86_64-darwin" "aarch64-linux" "x86_64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f {
        pkgs = import nixpkgs { inherit system; };
        liblogos = logos-liblogos.packages.${system}.default;
        packageManager = logos-package-manager.packages.${system}.default;
        capabilityModule = logos-capability-module.packages.${system}.default;
      });
    in
    {
      packages = forAllSystems ({ pkgs, liblogos, packageManager, capabilityModule }: {
        default = pkgs.stdenv.mkDerivation rec {
          pname = "logos-test-example";
          version = "1.0.0";
          
          src = ./.;

          # This is an aggregate runtime layout; avoid stripping to prevent hook errors
          dontStrip = true;
          dontWrapQtApps = true;
          
          nativeBuildInputs = [ 
            pkgs.cmake 
            pkgs.ninja 
            pkgs.pkg-config
            pkgs.qt6.wrapQtAppsNoGuiHook
          ];
          
          buildInputs = [ 
            pkgs.qt6.qtbase
            liblogos
          ];
          
          # Configure and build phase
          configurePhase = ''
            runHook preConfigure
            
            echo "Configuring logos-test-example..."
            echo "liblogos: ${liblogos}"
            echo "package-manager: ${packageManager}"
            echo "capability-module: ${capabilityModule}"
            
            # Verify that the built components exist
            test -d "${liblogos}" || (echo "liblogos not found" && exit 1)
            test -d "${packageManager}" || (echo "package-manager not found" && exit 1)
            test -d "${capabilityModule}" || (echo "capability-module not found" && exit 1)
            
            cmake -S . -B build \
              -GNinja \
              -DCMAKE_BUILD_TYPE=Release \
              -DLOGOS_LIBLOGOS_ROOT=${liblogos}
            
            runHook postConfigure
          '';
          
          buildPhase = ''
            runHook preBuild
            
            cmake --build build
            echo "logos-test-example built successfully!"
            
            runHook postBuild
          '';
          
          installPhase = ''
            set -euo pipefail
            mkdir -p $out
            echo "Logos Test Example - All components compiled successfully" > $out/README.txt
            echo "liblogos: ${liblogos}" >> $out/README.txt
            echo "package-manager: ${packageManager}" >> $out/README.txt
            echo "capability-module: ${capabilityModule}" >> $out/README.txt

            # Prepare runtime layout
            mkdir -p "$out/bin" "$out/lib" "$out/bin/modules" "$out/modules"
            
            # Install our custom binary
            if [ -f "build/bin/logos-test-example" ]; then
              cp build/bin/logos-test-example "$out/bin/"
              echo "Installed logos-test-example binary"
            fi
            
            # Also copy the original binaries from liblogos for reference
            if [ -f "${liblogos}/bin/logoscore" ]; then
              cp -L "${liblogos}/bin/logoscore" "$out/bin/logoscore"
            fi
            if [ -f "${liblogos}/bin/logos_host" ]; then
              cp -L "${liblogos}/bin/logos_host" "$out/bin/logos_host"
            fi

            # Copy core shared library to lib for RPATH resolution
            if ls "${liblogos}/lib/"liblogos_core.* >/dev/null 2>&1; then
              cp -L "${liblogos}/lib/"liblogos_core.* "$out/lib/" || true
            fi

            # Determine platform-specific plugin extension
            OS_EXT="so"
            case "$(uname -s)" in
              Darwin)
                OS_EXT="dylib";;
              Linux)
                OS_EXT="so";;
              MINGW*|MSYS*|CYGWIN*)
                OS_EXT="dll";;
            esac

            # Symlink plugins into both expected locations
            ln -s "${packageManager}/lib/logos/modules/package_manager_plugin.$OS_EXT" "$out/bin/modules/package_manager_plugin.$OS_EXT" || true
            ln -s "${capabilityModule}/lib/logos/modules/capability_module_plugin.$OS_EXT" "$out/bin/modules/capability_module_plugin.$OS_EXT" || true
            ln -s "${packageManager}/lib/logos/modules/package_manager_plugin.$OS_EXT" "$out/modules/package_manager_plugin.$OS_EXT" || true
            ln -s "${capabilityModule}/lib/logos/modules/capability_module_plugin.$OS_EXT" "$out/modules/capability_module_plugin.$OS_EXT" || true

            # Helpful message
            echo "Installed runtime to $out"
            echo " - binaries in $out/bin"
            echo " - core lib in $out/lib"
            echo " - plugins in $out/bin/modules and $out/modules"
          '';
          
          meta = with pkgs.lib; {
            description = "Logos Test Example - Pulls and compiles logos-liblogos, logos-package-manager, and logos-capability-module";
            platforms = platforms.unix;
          };
        };
        
        # Individual packages for direct access
        liblogos = liblogos;
        package-manager = packageManager;
        capability-module = capabilityModule;
      });

      devShells = forAllSystems ({ pkgs, liblogos, packageManager, capabilityModule }: {
        default = pkgs.mkShell {
          nativeBuildInputs = [
            pkgs.cmake
            pkgs.ninja
            pkgs.pkg-config
          ];
          buildInputs = [
            pkgs.qt6.qtbase
            pkgs.qt6.qtremoteobjects
            liblogos
            packageManager
            capabilityModule
          ];
          
          shellHook = ''
            export LOGOS_LIBLOGOS_ROOT="${liblogos}"
            export LOGOS_PACKAGE_MANAGER_ROOT="${packageManager}"
            export LOGOS_CAPABILITY_MODULE_ROOT="${capabilityModule}"
            echo "Logos Test Example development environment"
            echo "LOGOS_LIBLOGOS_ROOT: $LOGOS_LIBLOGOS_ROOT"
            echo "LOGOS_PACKAGE_MANAGER_ROOT: $LOGOS_PACKAGE_MANAGER_ROOT"
            echo "LOGOS_CAPABILITY_MODULE_ROOT: $LOGOS_CAPABILITY_MODULE_ROOT"

            # Prepare module directories for runtime discovery
            mkdir -p "$PWD/bin/modules" "$PWD/modules"

            # Determine platform-specific library extension
            OS_EXT="so"
            case "$(uname -s)" in
              Darwin)
                OS_EXT="dylib";;
              Linux)
                OS_EXT="so";;
              MINGW*|MSYS*|CYGWIN*)
                OS_EXT="dll";;
            esac

            # Symlink the two plugins into expected locations
            for targetDir in "$PWD/bin/modules" "$PWD/modules"; do
              mkdir -p "$targetDir"
              ln -sf "$LOGOS_PACKAGE_MANAGER_ROOT/lib/logos/modules/package_manager_plugin.$OS_EXT" "$targetDir/package_manager_plugin.$OS_EXT" 2>/dev/null || true
              ln -sf "$LOGOS_CAPABILITY_MODULE_ROOT/lib/logos/modules/capability_module_plugin.$OS_EXT" "$targetDir/capability_module_plugin.$OS_EXT" 2>/dev/null || true
            done

            echo "Symlinked plugins into ./bin/modules and ./modules"
          '';
        };
      });
    };
}
