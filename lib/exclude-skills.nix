{
  rootSkills,
  exclude,
}: let
  staleExclusions = builtins.filter
    (name: !(builtins.hasAttr name rootSkills))
    exclude;
in
  if staleExclusions != []
  then throw "agent-skills: stale root skill exclusions: ${builtins.concatStringsSep ", " staleExclusions}"
  else removeAttrs rootSkills exclude
