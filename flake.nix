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
          
          # Create a simple test that verifies all components are available
          buildPhase = ''
            echo "Testing Logos components compilation..."
            echo "liblogos: ${liblogos}"
            echo "package-manager: ${packageManager}"
            echo "capability-module: ${capabilityModule}"
            
            # Verify that the built components exist
            test -d "${liblogos}" || (echo "liblogos not found" && exit 1)
            test -d "${packageManager}" || (echo "package-manager not found" && exit 1)
            test -d "${capabilityModule}" || (echo "capability-module not found" && exit 1)
            
            echo "All Logos components successfully compiled and available!"
          '';
          
          installPhase = ''
            mkdir -p $out
            echo "Logos Test Example - All components compiled successfully" > $out/README.txt
            echo "liblogos: ${liblogos}" >> $out/README.txt
            echo "package-manager: ${packageManager}" >> $out/README.txt
            echo "capability-module: ${capabilityModule}" >> $out/README.txt
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
          '';
        };
      });
    };
}
