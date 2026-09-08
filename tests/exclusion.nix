let
  lib = import ../lib;
  excludeRootSkills = import ../lib/exclude-skills.nix;
  excludedRootNames = (import ../skill-selection.nix).exclude;
  harnesses = [
    "claude-code"
    "codex"
    "factory"
    "omp"
    "opencode"
    "pi"
  ];
  selectedSkillSets = builtins.concatLists (map (profile:
    [
      (lib.skillsFor {inherit profile;})
    ] ++ map (harness: lib.skillsFor {
        inherit profile harness;
      }) harnesses) [
    "personal"
    "work"
  ]);
  projectSkillEntries = builtins.readDir ../.agents/skills;
  # Excluded skills are preserved as real leaves; resolve name under any category.
  leafExists = root: name:
    builtins.pathExists (root + "/${name}/SKILL.md")
    || (let
      entries = builtins.readDir root;
      dirs = builtins.filter (n: entries.${n} == "directory") (builtins.attrNames entries);
    in
      builtins.any (n: leafExists (root + "/${n}") name) dirs);
  filteredRootFixture = excludeRootSkills {
    rootSkills = {
      keep = ../.;
      omit = ./.;
    };
    exclude = ["omit"];
  };
  staleRootExclusion = excludeRootSkills {
    rootSkills = {present = ../.;};
    exclude = ["missing"];
  };
  fails = value: !(builtins.tryEval (builtins.deepSeq value true)).success;
in
  assert excludedRootNames == [
    "find-skills"
    "skill-maintainer"
    "flue-framework"
  ];
  assert builtins.attrNames filteredRootFixture == ["keep"];
  assert fails staleRootExclusion;
  assert builtins.all
    (name: leafExists ../skills name)
    excludedRootNames;
  assert builtins.all
    (name: projectSkillEntries.${name} or null == "symlink")
    (builtins.filter (name: builtins.hasAttr name projectSkillEntries) excludedRootNames);
  assert builtins.all
    (skills: builtins.all (name: !(builtins.hasAttr name skills)) excludedRootNames)
    selectedSkillSets;
  true
