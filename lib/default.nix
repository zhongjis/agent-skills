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
    commonGeneral = discoverSkills ../skills/common-general;
    commonPersonal = discoverSkills ../skills/common-personal;
    commonWork = discoverSkills ../skills/common-work;
    piGeneral = discoverSkills ../skills/pi-general;
    piPersonal = discoverSkills ../skills/pi-personal;
    piWork = discoverSkills ../skills/pi-work;
  };
in {
  skillsFor = import ./select-skills.nix {inherit groups;};
}
