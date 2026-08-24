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

  discoverSkillsIf = folder:
    if builtins.pathExists folder
    then discoverSkills folder
    else {};

  profiles = import ../profiles.nix;
  personalNames = profiles.personal;
  workNames = profiles.work;
  selection = import ../skill-selection.nix;

  splitByProfile = skillAttrs: let
    isPersonal = name: builtins.elem name personalNames;
    isWork = name: builtins.elem name workNames;
  in {
    general = builtins.listToAttrs (
      builtins.filter (e: !(isPersonal e.name) && !(isWork e.name))
      (map (name: {
        name = name;
        value = skillAttrs.${name};
      }) (builtins.attrNames skillAttrs))
    );
    personal = builtins.listToAttrs (
      builtins.filter (e: isPersonal e.name)
      (map (name: {
        name = name;
        value = skillAttrs.${name};
      }) (builtins.attrNames skillAttrs))
    );
    work = builtins.listToAttrs (
      builtins.filter (e: isWork e.name)
      (map (name: {
        name = name;
        value = skillAttrs.${name};
      }) (builtins.attrNames skillAttrs))
    );
  };

  agentFolders = {
    claude-code = ../.claude/skills;
    codex = ../.codex/skills;
    opencode = ../.opencode/skills;
    factory = ../.factory/skills;
    omp = ../.omp/skills;
    pi = ../.pi/skills;
  };

  physicalHarnessSkills = builtins.mapAttrs (_: discoverSkillsIf) agentFolders;
  rootSkills = import ./exclude-skills.nix {
    rootSkills = discoverSkillsIf ../skills;
    exclude = selection.exclude;
  };
  assembled = import ./assemble-skills.nix {
    inherit rootSkills;
    vendoredCommonSkills = discoverSkillsIf ../.agents/skills;
    inherit physicalHarnessSkills;
    skillHarnesses = import ../skill-harnesses.nix;
    supportedHarnesses = builtins.attrNames agentFolders;
  };
  commonSkills = assembled.commonSkills;
  claudeCodeSkills = assembled.harnessSkills.claude-code;
  codexSkills = assembled.harnessSkills.codex;
  opencodeSkills = assembled.harnessSkills.opencode;
  factorySkills = assembled.harnessSkills.factory;
  ompSkills = assembled.harnessSkills.omp;
  piSkills = assembled.harnessSkills.pi;

  commonSplit = splitByProfile commonSkills;
  claudeCodeSplit = splitByProfile claudeCodeSkills;
  codexSplit = splitByProfile codexSkills;
  opencodeSplit = splitByProfile opencodeSkills;
  factorySplit = splitByProfile factorySkills;
  ompSplit = splitByProfile ompSkills;
  piSplit = splitByProfile piSkills;

  groups = {
    commonGeneral = commonSplit.general;
    commonPersonal = commonSplit.personal;
    commonWork = commonSplit.work;
    claudeCodeGeneral = claudeCodeSplit.general;
    claudeCodePersonal = claudeCodeSplit.personal;
    claudeCodeWork = claudeCodeSplit.work;
    codexGeneral = codexSplit.general;
    codexPersonal = codexSplit.personal;
    codexWork = codexSplit.work;
    opencodeGeneral = opencodeSplit.general;
    opencodePersonal = opencodeSplit.personal;
    opencodeWork = opencodeSplit.work;
    factoryGeneral = factorySplit.general;
    factoryPersonal = factorySplit.personal;
    factoryWork = factorySplit.work;
    ompGeneral = ompSplit.general;
    ompPersonal = ompSplit.personal;
    ompWork = ompSplit.work;
    piGeneral = piSplit.general;
    piPersonal = piSplit.personal;
    piWork = piSplit.work;
  };
in {
  skillsFor = import ./select-skills.nix {inherit groups;};
}
