{
  lib,
  moduleProfiles,
  selectedProfiles,
}:
let
  profileFor = name: moduleProfiles.${name} or (throw "Unknown module profile `${name}`");

  selected = map profileFor selectedProfiles;
  collect = kind: lib.concatMap (profile: profile.${kind} or [ ]) selected;
in
{
  system = collect "system";
  home = collect "home";
}
