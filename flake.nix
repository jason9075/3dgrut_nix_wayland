{
  description = "3dgrut dev environment (Nix)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            just

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
            echo "- For the full CUDA/PyTorch + native extensions env, use conda:"
            echo "    ./install_env.sh 3dgrut [WITH_GCC11]"
          '';
        };
      });
}
