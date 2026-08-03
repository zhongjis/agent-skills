let
  discoverSkills = root: let
    entries = builtins.readDir root;
    directories = builtins.filter (name: entries.${name} == "directory") (builtins.attrNames entries);
    skillEntry = name: let
      directory = root + "/${name}";
    in
      if builtins.pathExists (directory + "/SKILL.md")
      then {
        inherit name;
        value = directory;
      }
      else throw "agent-skills: missing SKILL.md in ${toString directory}";
  in
    builtins.listToAttrs (map skillEntry directories);

  groups = {
    claudeCodeGeneral = discoverSkills ../skills/claude-code-general;
    claudeCodePersonal = discoverSkills ../skills/claude-code-personal;
    claudeCodeWork = discoverSkills ../skills/claude-code-work;
    codexGeneral = discoverSkills ../skills/codex-general;
    codexPersonal = discoverSkills ../skills/codex-personal;
    codexWork = discoverSkills ../skills/codex-work;
    commonGeneral = discoverSkills ../skills/common-general;
    commonPersonal = discoverSkills ../skills/common-personal;
    commonWork = discoverSkills ../skills/common-work;
    factoryGeneral = discoverSkills ../skills/factory-general;
    factoryPersonal = discoverSkills ../skills/factory-personal;
    factoryWork = discoverSkills ../skills/factory-work;
    ompGeneral = discoverSkills ../skills/omp-general;
    ompPersonal = discoverSkills ../skills/omp-personal;
    ompWork = discoverSkills ../skills/omp-work;
    opencodeGeneral = discoverSkills ../skills/opencode-general;
    opencodePersonal = discoverSkills ../skills/opencode-personal;
    opencodeWork = discoverSkills ../skills/opencode-work;
    piGeneral = discoverSkills ../skills/pi-general;
    piPersonal = discoverSkills ../skills/pi-personal;
    piWork = discoverSkills ../skills/pi-work;
  };
in {
  skillsFor = import ./select-skills.nix {inherit groups;};
}
