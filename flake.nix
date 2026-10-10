{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs?ref=nixos-unstable";
  };

  outputs =
    { self, nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      # community.hashi_vault runs `hvac` inside the Ansible module interpreter.
      # Ansible executes modules with its own (nix store) Python, so the package
      # has to be reachable via PYTHONPATH and not merely present on PATH.
      # The input is nixos-unstable on purpose: it gives the same Python as the
      # profile-installed Ansible, so the PYTHONPATH below matches its ABI.
      hvacEnv = pkgs.python3.withPackages (ps: [ ps.hvac ]);
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = [
          hvacEnv
        ]
        ++ (with pkgs; [
          cdrtools
          cloud-utils
        ]);

        shellHook = ''
          export PYTHONPATH="${hvacEnv}/${pkgs.python3.sitePackages}''${PYTHONPATH:+:$PYTHONPATH}"
        '';
      };
    };
}
