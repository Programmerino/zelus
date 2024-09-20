{
  description = "Nix Template";

  nixConfig = {
    extra-substituters = [
      "https://programmerino.cachix.org"
    ];
    extra-trusted-public-keys = [
      "programmerino.cachix.org-1:v8UWI2QVhEnoU71CDRNS/K1CcW3yzrQxJc604UiijjA="
    ];
  };

  inputs = {
    nixpkgs.url = "/home/davis/Downloads/nixpkgs";
    flake-root.url = "github:srid/flake-root";
  };

  outputs = inputs @ {flake-parts, ...}:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = ["x86_64-linux"];
      imports = [
        inputs.flake-root.flakeModule
      ];
      perSystem = {
        config,
        self',
        inputs',
        pkgs,
        system,
        lib,
        ...
      }: let
        pkgs = import inputs.nixpkgs {
          inherit system;
          overlays = [
            (self: super: {
              ocaml-ng =
                super.ocaml-ng
                // {
                  ocamlPackages_4_14 = super.ocaml-ng.ocamlPackages_4_14.overrideScope (
                    oself: osuper: {
                      zelus-muf = osuper.zelus-muf.overrideAttrs (_: {
                        src = ./.;
                      });
                    }
                  );
                };
            })
          ];
          config.allowUnfree = true;
        };
        myOcaml = pkgs.ocaml-ng.ocamlPackages_4_14;
        myZlax = pkgs.python311.pkgs.zlax.overridePythonAttrs (oldAttrs: {
          src = ./lib/zlax;
          sourceRoot = "./zlax";
        });
        myPython = pkgs.python311.withPackages (ps:
          with ps; [
          ] ++ myZlax.dependencies);
        zelusWithPackages = zelus: ps:
          pkgs.writeShellApplication {
            name = "zeluc";

            # Add -I {path} for each package in the list
            text = ''
              exec ${zelus}/bin/zeluc ${pkgs.lib.concatStringsSep " " (map (path: "-I " + "${path}/share/${path.pname}") ps)} "$@"
            '';
          };
          envVars = ''
            export PATH="$PATH:$FLAKE_ROOT/_build/install/default/bin"
            export OCAMLPATH="$OCAMLPATH:$FLAKE_ROOT/_build/install/default/lib"
            export PYTHONPATH="$PYTHONPATH:$FLAKE_ROOT/lib"
          '';
      in {
        packages.default = myOcaml.zelus-muf;
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            nil
            myPython
            alejandra
            git
            myOcaml.ocaml-lsp
            myOcaml.ocamlformat
            myOcaml.alcotest
            poetry
            (pkgs.writeShellApplication {
              name = "build_zeluc";
              text = ''
                ${envVars}
                (cd "$FLAKE_ROOT" && exec dune build "$@")
              '';
            })
            (pkgs.writeShellApplication {
              name = "zluciole";
              text = ''
                ${envVars}
                exec python3 -m zlax.zluciole "$@"
              '';
            })
            (pkgs.writeShellApplication {
              name = "zeluc";
              text = ''
                ${envVars}
                exec "$FLAKE_ROOT/compiler/zeluc.exe" "$@"
              '';
            })
          ];
          inputsFrom = [myOcaml.zelus-muf myOcaml.zlax config.flake-root.devShell];
          shellHook = ''
            ${envVars}
          '';
        };
        formatter = pkgs.alejandra;
      };
    };
}
