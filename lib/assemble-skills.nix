{
  rootSkills,
  vendoredCommonSkills,
  physicalHarnessSkills,
  skillHarnesses,
  supportedHarnesses,
}: let
  rootNames = builtins.attrNames rootSkills;
  routeNames = builtins.attrNames skillHarnesses;
  staleRoutes = builtins.filter (name: !(builtins.hasAttr name rootSkills)) routeNames;
  unsupportedRoutes = builtins.filter
    (name: !(builtins.elem skillHarnesses.${name} supportedHarnesses))
    routeNames;

  attrsForNames = attrs: names:
    builtins.listToAttrs (map (name: {
        inherit name;
        value = attrs.${name};
      }) names);
  rootCommonSkills = attrsForNames rootSkills (
    builtins.filter (name: !(builtins.hasAttr name skillHarnesses)) rootNames
  );
  routedSkillsFor = harness: attrsForNames rootSkills (
    builtins.filter
    (name: skillHarnesses.${name} or null == harness)
    rootNames
  );
  mergeDisjoint = label: left: right: let
    collisions = builtins.filter (name: builtins.hasAttr name right) (builtins.attrNames left);
  in
    if collisions == []
    then left // right
    else throw "agent-skills: ${label} collision: ${builtins.concatStringsSep ", " collisions}";

  validated =
    if staleRoutes != []
    then throw "agent-skills: stale skill harness routes: ${builtins.concatStringsSep ", " staleRoutes}"
    else if unsupportedRoutes != []
    then throw "agent-skills: unsupported skill harness routes: ${builtins.concatStringsSep ", " unsupportedRoutes}"
    else true;
in
  builtins.seq validated {
    commonSkills = mergeDisjoint "root common vs vendored common" rootCommonSkills vendoredCommonSkills;
    harnessSkills = builtins.mapAttrs
      (harness: physicalSkills:
        mergeDisjoint
        "routed root vs physical ${harness}"
        (routedSkillsFor harness)
        physicalSkills)
      physicalHarnessSkills;
  }
