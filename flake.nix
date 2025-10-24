{
  description = "Logos Test Example - Pulls and compiles logos-liblogos, logos-package-manager, and logos-capability-module";

  inputs = {
    # Follow the same nixpkgs as logos-liblogos to ensure compatibility
    nixpkgs.follows = "logos-liblogos/nixpkgs";
    logos-cpp-sdk.url = "github:logos-co/logos-cpp-sdk";
    logos-liblogos.url = "github:logos-co/logos-liblogos";
    logos-package-manager.url = "github:logos-co/logos-package-manager";
    logos-capability-module.url = "github:logos-co/logos-capability-module";
    logos-waku-module.url = "github:logos-co/logos-waku-module";
  };

  outputs = { self, nixpkgs, logos-liblogos, logos-cpp-sdk, logos-package-manager, logos-capability-module, logos-waku-module }:
    let
      systems = [ "aarch64-darwin" "x86_64-darwin" "aarch64-linux" "x86_64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f {
        pkgs = import nixpkgs { inherit system; };
        liblogos = logos-liblogos.packages.${system}.default;
        cppSdk = logos-cpp-sdk.packages.${system}.default;
        packageManager = logos-package-manager.packages.${system}.default;
        capabilityModule = logos-capability-module.packages.${system}.default;
        wakuModule = logos-waku-module.packages.${system}.default;
      });
    in
    {
      packages = forAllSystems ({ pkgs, liblogos, cppSdk, packageManager, capabilityModule, wakuModule }: {
        default = pkgs.stdenv.mkDerivation rec {
          pname = "logos-test-example";
          version = "1.0.0";
          
          src = ./.;

          # This is an aggregate runtime layout; avoid stripping to prevent hook errors
          dontStrip = true;
          
          # This is a CLI application, disable Qt wrapping
          dontWrapQtApps = true;
          
          nativeBuildInputs = [ 
            pkgs.cmake 
            pkgs.ninja 
            pkgs.pkg-config
          ];
          
          buildInputs = [ 
            pkgs.qt6.qtbase
            pkgs.qt6.qtremoteobjects
            pkgs.zstd
            pkgs.krb5
            liblogos
            cppSdk
            packageManager
            capabilityModule
            wakuModule
          ];
          
          # Configure and build phase
          configurePhase = ''
            runHook preConfigure
            
            echo "Configuring logos-test-example..."
            echo "liblogos: ${liblogos}"
            echo "cpp-sdk: ${cppSdk}"
            echo "package-manager: ${packageManager}"
            echo "capability-module: ${capabilityModule}"
            echo "waku-module: ${wakuModule}"
            
            # Verify that the built components exist
            test -d "${liblogos}" || (echo "liblogos not found" && exit 1)
            test -d "${cppSdk}" || (echo "cpp-sdk not found" && exit 1)
            test -d "${packageManager}" || (echo "package-manager not found" && exit 1)
            test -d "${capabilityModule}" || (echo "capability-module not found" && exit 1)
            test -d "${wakuModule}" || (echo "waku-module not found" && exit 1)
            
            cmake -S . -B build \
              -GNinja \
              -DCMAKE_BUILD_TYPE=Release \
              -DLOGOS_LIBLOGOS_ROOT=${liblogos} \
              -DLOGOS_CPP_SDK_ROOT=${cppSdk}
            
            runHook postConfigure
          '';
          
          buildPhase = ''
            runHook preBuild
            
            cmake --build build
            echo "logos-test-example built successfully!"
            
            runHook postBuild
          '';
          
          installPhase = ''
            runHook preInstall
            
            # Create output directories
            mkdir -p $out/bin $out/lib $out/modules
            
            # Install our test example binary
            if [ -f "build/bin/logos-test-example" ]; then
              cp build/bin/logos-test-example "$out/bin/"
              echo "Installed logos-test-example binary"
            fi
            
            # Copy the core binaries from liblogos
            if [ -f "${liblogos}/bin/logoscore" ]; then
              cp -L "${liblogos}/bin/logoscore" "$out/bin/"
              echo "Installed logoscore binary"
            fi
            if [ -f "${liblogos}/bin/logos_host" ]; then
              cp -L "${liblogos}/bin/logos_host" "$out/bin/"
              echo "Installed logos_host binary"
            fi
            
            # Copy required shared libraries from liblogos
            if ls "${liblogos}/lib/"liblogos_core.* >/dev/null 2>&1; then
              cp -L "${liblogos}/lib/"liblogos_core.* "$out/lib/" || true
            fi
            
            # Copy SDK library if it exists
            if ls "${cppSdk}/lib/"liblogos_sdk.* >/dev/null 2>&1; then
              cp -L "${cppSdk}/lib/"liblogos_sdk.* "$out/lib/" || true
            fi

            # Determine platform-specific plugin extension
            OS_EXT="so"
            case "$(uname -s)" in
              Darwin) OS_EXT="dylib";;
              Linux) OS_EXT="so";;
              MINGW*|MSYS*|CYGWIN*) OS_EXT="dll";;
            esac

            # Copy module plugins into the modules directory
            if [ -f "${packageManager}/lib/package_manager_plugin.$OS_EXT" ]; then
              cp -L "${packageManager}/lib/package_manager_plugin.$OS_EXT" "$out/modules/"
            fi
            if [ -f "${capabilityModule}/lib/capability_module_plugin.$OS_EXT" ]; then
              cp -L "${capabilityModule}/lib/capability_module_plugin.$OS_EXT" "$out/modules/"
            fi
            if [ -f "${wakuModule}/lib/waku_module_plugin.$OS_EXT" ]; then
              cp -L "${wakuModule}/lib/waku_module_plugin.$OS_EXT" "$out/modules/"
            fi
            
            # Copy libwaku library to modules directory (needed by waku_module_plugin)
            if [ -f "${wakuModule}/lib/libwaku.$OS_EXT" ]; then
              cp -L "${wakuModule}/lib/libwaku.$OS_EXT" "$out/modules/"
            fi

            # Create a README for reference
            cat > $out/README.txt <<EOF
Logos Test Example - Build Information
======================================
liblogos: ${liblogos}
cpp-sdk: ${cppSdk}
package-manager: ${packageManager}
capability-module: ${capabilityModule}
waku-module: ${wakuModule}

Runtime Layout:
- Binaries: $out/bin
- Libraries: $out/lib
- Modules: $out/modules

Usage:
  $out/bin/logos-test-example --module-path $out/modules
EOF
            
            runHook postInstall
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
        waku-module = wakuModule;
      });

      devShells = forAllSystems ({ pkgs, liblogos, cppSdk, packageManager, capabilityModule, wakuModule }: {
        default = pkgs.mkShell {
          nativeBuildInputs = [
            pkgs.cmake
            pkgs.ninja
            pkgs.pkg-config
          ];
          buildInputs = [
            pkgs.qt6.qtbase
            pkgs.qt6.qtremoteobjects
            pkgs.zstd
            liblogos
            cppSdk
            packageManager
            capabilityModule
            wakuModule
          ];
          
          shellHook = ''
            export LOGOS_LIBLOGOS_ROOT="${liblogos}"
            export LOGOS_CPP_SDK_ROOT="${cppSdk}"
            export LOGOS_PACKAGE_MANAGER_ROOT="${packageManager}"
            export LOGOS_CAPABILITY_MODULE_ROOT="${capabilityModule}"
            export LOGOS_WAKU_MODULE_ROOT="${wakuModule}"
            
            echo "Logos Test Example development environment"
            echo "======================================"
            echo "LOGOS_LIBLOGOS_ROOT: $LOGOS_LIBLOGOS_ROOT"
            echo "LOGOS_CPP_SDK_ROOT: $LOGOS_CPP_SDK_ROOT"
            echo "LOGOS_PACKAGE_MANAGER_ROOT: $LOGOS_PACKAGE_MANAGER_ROOT"
            echo "LOGOS_CAPABILITY_MODULE_ROOT: $LOGOS_CAPABILITY_MODULE_ROOT"
            echo "LOGOS_WAKU_MODULE_ROOT: $LOGOS_WAKU_MODULE_ROOT"

            # Prepare modules directory for runtime discovery
            mkdir -p "$PWD/modules"

            # Determine platform-specific library extension
            OS_EXT="so"
            case "$(uname -s)" in
              Darwin) OS_EXT="dylib";;
              Linux) OS_EXT="so";;
              MINGW*|MSYS*|CYGWIN*) OS_EXT="dll";;
            esac

            # Symlink the plugins and libwaku into the modules directory
            if [ -f "$LOGOS_PACKAGE_MANAGER_ROOT/lib/package_manager_plugin.$OS_EXT" ]; then
              ln -sf "$LOGOS_PACKAGE_MANAGER_ROOT/lib/package_manager_plugin.$OS_EXT" "$PWD/modules/"
            fi
            if [ -f "$LOGOS_CAPABILITY_MODULE_ROOT/lib/capability_module_plugin.$OS_EXT" ]; then
              ln -sf "$LOGOS_CAPABILITY_MODULE_ROOT/lib/capability_module_plugin.$OS_EXT" "$PWD/modules/"
            fi
            if [ -f "$LOGOS_WAKU_MODULE_ROOT/lib/waku_module_plugin.$OS_EXT" ]; then
              ln -sf "$LOGOS_WAKU_MODULE_ROOT/lib/waku_module_plugin.$OS_EXT" "$PWD/modules/"
            fi
            
            # Also symlink libwaku library to modules directory
            if [ -f "$LOGOS_WAKU_MODULE_ROOT/lib/libwaku.$OS_EXT" ]; then
              ln -sf "$LOGOS_WAKU_MODULE_ROOT/lib/libwaku.$OS_EXT" "$PWD/modules/"
            fi

            echo "Symlinked plugins into ./modules"
            echo ""
            echo "To build: cmake -S . -B build -DLOGOS_LIBLOGOS_ROOT=\$LOGOS_LIBLOGOS_ROOT -DLOGOS_CPP_SDK_ROOT=\$LOGOS_CPP_SDK_ROOT && cmake --build build"
          '';
        };
      });
    };
}
