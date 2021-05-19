let
  sources = import ./nix/sources.nix;
  # Disable tests for these packages
  dontCheckPackages = [
  ];

  # Jailbreak these packages
  doJailbreakPackages = [
  ];

  # Disable haddocks for these packages
  dontHaddockPackages = [
  ];

  docker-entrypoint = pkgs.writeScript "entrypoint.sh" ''
    #!${pkgs.stdenv.shell}
    ${pkgs.dockerTools.shadowSetup}

    # Normally we don't have to do this but since we're using 'scratch'.... ¯\_(ツ)_/¯
    mkdir /home

    # Add local user
    # Either use the LOCAL_USER_ID if passed in at runtime or
    # fallback
    USER_ID=''${LOCAL_USER_ID:-9001}
    APP_DIR=''${APP_DIR:-/opt/app}
    # For some reason useradd doesn't add the group for us as it should
    # so we create it manually
    groupadd -g $USER_ID -o user

    echo "Starting with UID : $USER_ID"
    useradd --shell /bin/bash -u $USER_ID -g user -c "The User" --create-home user
    export HOME=/home/user

    # set correct permissions on APP_DIR and subfolders
    chown -R user. $APP_DIR

    cp ${./fallback-error-page.html} /fallback-error-page.html

    exec pid1 -u user -g user "$@"
  '';

  config = {
    packageOverrides = pkgs: rec {

      app-docker-image = pkgs.dockerTools.buildLayeredImage {
        name = "denibertovic/ingress-fail-page";
        tag = "latest";
        # tag = "${haskellPackages.ingress-fail-page.version}";
        # We can remove some of these packages if we don't end up needing them
        # But I like having some utilities installed
        contents = [ pkgs.bash
                     pkgs.coreutils
                     pkgs.which
                     (pkgs.haskell.lib.justStaticExecutables haskellPackages.ingress-fail-page)
                     (pkgs.haskell.lib.justStaticExecutables haskellPackages.pid1)
                   ];
        config = {
           Entrypoint = [ docker-entrypoint ];
           Cmd = [ "${pkgs.haskell.lib.justStaticExecutables haskellPackages.ingress-fail-page}/bin/ingress-fail-page" "3000" "/www" ];
           # TODO: bake in keys and configs as well
           WorkingDir = "/opt/app";
         };
       };
      haskellPackages =
        let
          generatedOverrides = haskellPackagesNew: haskellPackagesOld:
            let
              toPackage = file: _: {
                name  = builtins.replaceStrings [ ".nix" ] [ "" ] file;

                value = haskellPackagesNew.callPackage (./. + "/nix/${file}") { };
              };

            in
              pkgs.lib.mapAttrs' toPackage (builtins.readDir ./nix);

          makeOverrides =
            function: names: haskellPackagesNew: haskellPackagesOld:
              let
                toPackage = name: {
                  inherit name;

                  value = function haskellPackagesOld.${name};
                };

            in
              builtins.listToAttrs (map toPackage names);

          composeExtensionsList =
            pkgs.lib.fold pkgs.lib.composeExtensions (_: _: {});

          # More exotic overrides go here
          manualOverrides = haskellPackagesNew: haskellPackagesOld: {
          };
        in
          pkgs.haskellPackages.override {
            overrides = composeExtensionsList [
              generatedOverrides
              (makeOverrides pkgs.haskell.lib.dontCheck   dontCheckPackages  )
              (makeOverrides pkgs.haskell.lib.doJailbreak doJailbreakPackages)
              (makeOverrides pkgs.haskell.lib.dontHaddock dontHaddockPackages)
              manualOverrides
            ];
          };
    };
  };
  # This is VERY important as we PIN nixpkgs so we're not dependant on what the
  # global nix-channel is set to on your host system
  pkgs = import sources.nixpkgs { inherit config; };

in
  { app = pkgs.haskellPackages.ingress-fail-page;
    app-docker-image = pkgs.app-docker-image;
  }
