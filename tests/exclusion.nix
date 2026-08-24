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
  ];
  assert builtins.attrNames filteredRootFixture == ["keep"];
  assert fails staleRootExclusion;
  assert builtins.all
    (name: builtins.pathExists (../skills + "/${name}/SKILL.md"))
    excludedRootNames;
  assert builtins.all
    (name: projectSkillEntries.${name} or null == "symlink")
    excludedRootNames;
  assert builtins.all
    (skills: builtins.all (name: !(builtins.hasAttr name skills)) excludedRootNames)
    selectedSkillSets;
  true
