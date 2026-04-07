{ inputs, secrets, ... }:

let
  hostLib = import ./mkHost.nix { inherit inputs secrets; };
in
{
  inherit (hostLib) mkHost;
}
