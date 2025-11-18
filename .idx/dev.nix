{ pkgs, ... }: {
  # Which nixpkgs channel to use.
  channel = "stable-23.11"; # or "unstable"

  # Use https://search.nixos.org/packages to find packages
  packages = [
    pkgs.docker
    pkgs.docker-compose
    pkgs.kubectl
    pkgs.k3d
    pkgs.helm
    pkgs.nodejs_20
    pkgs.jq
    pkgs.gnumake
  ];

  # Sets environment variables in the workspace
  env = {
  };

  # Search for the extensions you want on https://open-vsx.org/ and use "publisher.id"
  idx.extensions = [
  ];
}