{

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
  };
  outputs = { self, nixpkgs, ... }:
    let

      version = builtins.replaceStrings [ "\n" ] [ "" ]
        (builtins.readFile ./.version + versionSuffix);
      versionSuffix = if officialRelease then
        ""
      else
        "pre${
          nixpkgs.lib.substring 0 8 (self.lastModifiedDate or self.lastModified)
        }_${self.shortRev or "dirty"}";

      officialRelease = false;

      systems = [ "x86_64-linux" "i686-linux" "aarch64-linux" "x86_64-darwin" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system);

      # Memoize nixpkgs for different platforms for efficiency.
      nixpkgsFor = forAllSystems (system:
        import nixpkgs {
          inherit system;
          overlays = [ self.overlay ];
        });
    in {
      overlay = final: prev: {
        ifconfigio = with final;
          with pkgs;
          (buildGoModule {
            name = "ifconfig.io-${version}";

            src = self;
            vendorSha256 = "sha256-5hk58EGsTuV0pLEELFcJNM/hbCjLj0wrA7RC1+3m1UU=";

            tags = [ "jsoniter" ];

            postInstall = ''
              mkdir -p $out/usr/lib/ifconfig.io/
              cp -r ./templates $out/usr/lib/ifconfig.io
            '';

          });

        ifconfigio-docker = with final;
          with pkgs;
          (dockerTools.buildLayeredImage {
            name = "ifconfig.io";
            tag = version;
            created = "now";
            contents = [ ifconfigio busybox ];
            config = {
              Cmd = "/bin/ifconfig.io";
              WorkingDir = "/usr/lib/ifconfig.io";
              ExposedPorts = { "8080" = { }; };
              Env = [ "HOSTNAME=ifconfig.io" "TLS=0" "TLSCERT=" "TLSKEY=" ];
            };
          });
      };
      packages = forAllSystems (system: {
        inherit (nixpkgsFor.${system}) ifconfigio ifconfigio-docker;
      });
      defaultPackage =
        forAllSystems (system: self.packages.${system}.ifconfigio);

      nixosModules.ifconfigio = { pkgs, ... }: {
        nixpkgs.overlays = [ self.overlay ];
        systemd.packages = [ pkgs.ifconfigio ];
        users.users.ifconfigio = {
          description = "ifconfig.io daemon user";
          group = "ifconfigio";
          isSystemUser = true;
        };
        users.groups.ifconfigio = { };
      };

    };
}
