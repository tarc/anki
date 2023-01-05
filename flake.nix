{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    devenv.url = "github:cachix/devenv";
    pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, devenv, ... } @ inputs:
    let
      systems = [ "x86_64-linux" "i686-linux" "x86_64-darwin" "aarch64-linux" "aarch64-darwin" ];
      forAllSystems = f: builtins.listToAttrs (map (name: { inherit name; value = f name; }) systems);
    in
    {
      packages = forAllSystems(
        system: let pkgs = import nixpkgs {
          inherit system;
        }; in {
          default = pkgs.writeScriptBin "zeca" ''
            echo bosta
          '';
      });

      devShells = forAllSystems
        (system:
          let
            pkgs = import nixpkgs {
              inherit system;
            };
          in
          {
            default = devenv.lib.mkShell {
              inherit inputs pkgs;
              modules = [
                {
                  # https://devenv.sh/reference/options/
                  packages = [
                    pkgs.git
                    pkgs.libiconv
                    pkgs.ninja
                    pkgs.openssl.dev
                    pkgs.yarn
                  ] ++ (pkgs.lib.optionals pkgs.stdenv.isDarwin [
                    pkgs.darwin.apple_sdk.frameworks.CoreFoundation
                    pkgs.darwin.apple_sdk.frameworks.Security
                  ]);

                  env.RUSTFLAGS = (builtins.map (l: ''-L ${l}/lib'') [
                    pkgs.libiconv
                    pkgs.openssl.dev
                  ]) ++ (pkgs.lib.optionals pkgs.stdenv.isDarwin
                    (with pkgs.darwin.apple_sdk; builtins.map (l: ''-L framework=${l}/Library/Frameworks'') [
                      frameworks.CoreFoundation
                      frameworks.Security
                  ]));

                  env.DISABLE_QT5_COMPAT = 1;

                  languages.rust = {
                    enable = true;
                    version = "stable";
                  };

                  languages.javascript.enable = true;
                  languages.javascript.package = pkgs.nodejs;
                  languages.python.enable = true;
                  languages.typescript.enable = true;

                  enterShell = ''
                    git --version
                  '';
                }
              ];
            };
          });
      };
}
