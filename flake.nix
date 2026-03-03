{
  description = "3dgrut dev environment (Nix)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        # Default shell stays "free" to avoid unfree CUDA eval errors.
        pkgs = import nixpkgs { inherit system; };

        # CUDA shells are opt-in, and explicitly allow unfree.
        pkgsCuda12_8 = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };

        # Pin CUDA toolkit to 12.6 by overriding `cudaPackages`.
        pkgsCuda12_6 = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
          overlays = [
            (final: prev: {
              cudaPackages = prev.cudaPackages_12_6;
            })
          ];
        };
      in
      {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            just
            colmap

            # Python + formatting tools
            python311
            black
            isort

            # Common build utilities (useful when running install_env.sh)
            git
            curl
            cmake
            ninja
            pkg-config
            gcc

            # Common runtime deps seen in CI / rich logging
            glib

            # X11 helper (useful for Docker GUI on Wayland/XWayland)
            xhost
          ];

          shellHook = ''
            echo "Entered 3dgrut dev shell (Nix)."
            echo "- Run 'just' to see common tasks."
            echo "- CUDA-enabled COLMAP (12.6): nix develop .#cuda"
            echo "- CUDA-enabled COLMAP (12.8): nix develop .#cuda12_8"
            echo "- For full CUDA/PyTorch + native extensions env, use conda:"
            echo "    ./install_env.sh 3dgrut [WITH_GCC11]"
          '';
        };

        devShells.cuda = pkgsCuda12_6.mkShell {
          packages = with pkgsCuda12_6; [
            just
            colmapWithCuda

            python311
            black
            isort

            git
            curl
            cmake
            ninja
            pkg-config
            gcc

            glib
            xhost
          ];

          shellHook = ''
            echo "Entered 3dgrut CUDA dev shell (Nix)."
            echo "- Run 'just' to see common tasks."
            echo "- CUDA toolkit: ${pkgsCuda12_6.cudaPackages.cudatoolkit.version}"
            echo "- This shell enables unfree CUDA packages for colmapWithCuda."
            echo "- For full CUDA/PyTorch + native extensions env, use conda:"
            echo "    ./install_env.sh 3dgrut [WITH_GCC11]"
          '';
        };

        devShells.cuda12_8 = pkgsCuda12_8.mkShell {
          packages = with pkgsCuda12_8; [
            just
            colmapWithCuda

            python311
            black
            isort

            git
            curl
            cmake
            ninja
            pkg-config
            gcc

            glib
            xhost
          ];

          shellHook = ''
            echo "Entered 3dgrut CUDA 12.8 dev shell (Nix)."
            echo "- Run 'just' to see common tasks."
            echo "- CUDA toolkit: ${pkgsCuda12_8.cudaPackages.cudatoolkit.version}"
            echo "- This shell enables unfree CUDA packages for colmapWithCuda."
            echo "- For full CUDA/PyTorch + native extensions env, use conda:"
            echo "    ./install_env.sh 3dgrut [WITH_GCC11]"
          '';
        };
      });
}
