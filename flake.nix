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
      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
          };
        in
        {
          default = pkgs.writeScriptBin "build" ''
            cargo build -p runner
            zsh -c 'RELEASE=1 exec /Users/silvia/projects/anki/out/rust/debug/runner build wheels'
            zsh -c 'RELEASE=1 exec /Users/silvia/projects/anki/out/rust/debug/runner build pylib/anki qt/aqt'
          '';
        }
      );

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
                    pkgs.openssl
                    pkgs.yarn
                  ] ++ (pkgs.lib.optionals pkgs.stdenv.isDarwin [
                    pkgs.darwin.apple_sdk.frameworks.CoreFoundation
                    pkgs.darwin.apple_sdk.frameworks.Security
                  ]);

                  enterShell = ''
                    [ -d ".vscode" ] && echo "Creating .vscode" || mkdir ".vscode"
                    pushd ".vscode"
                    [ -f extensions.json ] && echo "Linking extensions.json" || ln -sf ../.vscode.dist/extensions.json .
                    [ -f settings.json ] && echo "Linking settings.json" || ln -sf ../.vscode.dist/settings.json .
                    popd
                  '';

                  env.RUSTFLAGS = (builtins.map (l: ''-L ${l}/lib'') [
                    pkgs.libiconv
                    pkgs.openssl
                  ]) ++ (pkgs.lib.optionals pkgs.stdenv.isDarwin
                    (with pkgs.darwin.apple_sdk; builtins.map (l: ''-L framework=${l}/Library/Frameworks'') [
                      frameworks.CoreFoundation
                      frameworks.Security
                    ]));

                  env.DISABLE_QT5_COMPAT = 1;
                  env.RELEASE = 1;
                  env.PYTHONWARNINGS = "default";
                  env.PYTHONPYCACHEPREFIX = "out/pycache";
                  env.out = (builtins.getEnv "PWD") + "/out";
                  env.CARGO_TARGET_DIR = (builtins.getEnv "PWD") + "/out/rust";
                  env.RECONFIGURE_KEY = ";";

                  languages.rust = {
                    enable = true;
                    version = "stable";
                  };

                  languages.javascript.enable = true;
                  languages.javascript.package = pkgs.nodejs;
                  languages.python.enable = true;
                  languages.typescript.enable = true;
                }
              ];
            };
          });
    };
}
