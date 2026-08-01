let
  lib = import ../lib;
  selectSkills = import ../lib/select-skills.nix;

  namesFor = args: builtins.attrNames (lib.skillsFor args);
  pathsAreValid = skills:
    builtins.all
    (path:
      builtins.typeOf path
      == "path"
      && (builtins.tryEval (builtins.readDir path)).success
      && builtins.pathExists (path + "/SKILL.md"))
    (builtins.attrValues skills);
  fails = value: !(builtins.tryEval (builtins.deepSeq value true)).success;

  commonPersonal = lib.skillsFor {profile = "personal";};
  commonWork = lib.skillsFor {profile = "work";};
  piPersonal = lib.skillsFor {
    profile = "personal";
    harness = "pi";
  };
  piWork = lib.skillsFor {
    profile = "work";
    harness = "pi";
  };

  duplicateSelector = selectSkills {
    groups = {
      commonGeneral = {duplicate = ../skills/common-general/poc-common-general;};
      commonPersonal = {duplicate = ../skills/common-personal/poc-common-personal;};
      commonWork = {};
      piGeneral = {};
      piPersonal = {};
      piWork = {};
    };
  };
in
  assert namesFor {profile = "personal";}
  == [
    "poc-common-general"
    "poc-common-personal"
  ];
  assert namesFor {profile = "work";}
  == [
    "poc-common-general"
    "poc-common-work"
  ];
  assert namesFor {
    profile = "personal";
    harness = null;
  }
  == [
    "poc-common-general"
    "poc-common-personal"
  ];
  assert namesFor {
    profile = "personal";
    harness = "pi";
  }
  == [
    "poc-common-general"
    "poc-common-personal"
    "poc-pi-general"
    "poc-pi-personal"
  ];
  assert namesFor {
    profile = "work";
    harness = "pi";
  }
  == [
    "poc-common-general"
    "poc-common-work"
    "poc-pi-general"
    "poc-pi-work"
  ];
  assert pathsAreValid commonPersonal;
  assert pathsAreValid commonWork;
  assert pathsAreValid piPersonal;
  assert pathsAreValid piWork;
  assert fails (lib.skillsFor {profile = "general";});
  assert fails (lib.skillsFor {
    profile = "personal";
    harness = "claude-code";
  });
  assert fails (lib.skillsFor {});
  assert fails (lib.skillsFor {
    profile = "personal";
    profiles = [];
  });
  assert fails (duplicateSelector {profile = "personal";}); true
