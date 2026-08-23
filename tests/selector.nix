let
  lib = import ../lib;
  profiles = import ../profiles.nix;
  selectSkills = import ../lib/select-skills.nix;
  assembleSkills = import ../lib/assemble-skills.nix;

  supportedHarnessRoots = {
    "claude-code" = ../.claude/skills;
    codex = ../.codex/skills;
    factory = ../.factory/skills;
    omp = ../.omp/skills;
    opencode = ../.opencode/skills;
    pi = ../.pi/skills;
  };

  discoverNames = root:
    if builtins.pathExists root
    then
      let
        entries = builtins.readDir root;
      in
        builtins.filter
        (name:
          entries.${name}
          == "directory"
          && builtins.pathExists (root + "/${name}/SKILL.md"))
        (builtins.attrNames entries)
    else [];
  movedRootNames = [
    "address-comments"
    "ast-grep"
    "code-review"
    "code-review-v2"
    "codebase-search"
    "fd"
    "find-skills"
    "flue-framework"
    "gh"
    "github-pr-management"
    "pi-jsonl-logs"
    "programming"
    "rg"
    "setup-repo-docs"
    "skill-maintainer"
    "splunk"
    "use-open-design-canvas"
    "zoom-out"
  ];
  routedRootNames = ["pi-jsonl-logs"];
  rootNames = discoverNames ../skills;
  vendoredCommonNames = discoverNames ../.agents/skills;
  commonNames = vendoredCommonNames ++ builtins.filter
    (name: !(builtins.elem name routedRootNames))
    rootNames;
  harnessNames = builtins.mapAttrs
    (harness: root:
      discoverNames root
      ++ builtins.filter (name: (import ../skill-harnesses.nix).${name} or null == harness) rootNames)
    supportedHarnessRoots;
  allCatalogNames = builtins.attrNames (
    builtins.listToAttrs (map (name: {
        inherit name;
        value = true;
      }) (rootNames ++ vendoredCommonNames ++ builtins.concatLists (builtins.attrValues harnessNames)))
  );

  namesForProfile = names: profile:
    builtins.filter
    (name:
      !(builtins.elem name profiles.personal)
      && !(builtins.elem name profiles.work)
      || builtins.elem name profiles.${profile})
    names;
  namesToAttrs = names:
    builtins.listToAttrs (map (name: {
        inherit name;
        value = true;
      }) names);
  expectedNames = profile: harness:
    builtins.attrNames (
      namesToAttrs (namesForProfile commonNames profile)
      // (
        if harness == null
        then {}
        else namesToAttrs (namesForProfile harnessNames.${harness} profile)
      )
    );
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
  harnessSelections = builtins.concatLists (map (harness: [
      {
        expected = expectedNames "personal" harness;
        skills = lib.skillsFor {
          profile = "personal";
          inherit harness;
        };
      }
      {
        expected = expectedNames "work" harness;
        skills = lib.skillsFor {
          profile = "work";
          inherit harness;
        };
      }
    ]) (builtins.attrNames supportedHarnessRoots));
  emptyHarnesses =
    builtins.filter
    (harness: harnessNames.${harness} == [])
    (builtins.attrNames supportedHarnessRoots);

  emptyGroups = {
    commonGeneral = {};
    commonPersonal = {};
    commonWork = {};
    claudeCodeGeneral = {};
    claudeCodePersonal = {};
    claudeCodeWork = {};
    codexGeneral = {};
    codexPersonal = {};
    codexWork = {};
    factoryGeneral = {};
    factoryPersonal = {};
    factoryWork = {};
    ompGeneral = {};
    ompPersonal = {};
    ompWork = {};
    opencodeGeneral = {};
    opencodePersonal = {};
    opencodeWork = {};
    piGeneral = {};
    piPersonal = {};
    piWork = {};
  };
  fixtureSelector = selectSkills {
    groups = emptyGroups // {
      commonGeneral = {
        common = ../.;
        collision = ../.;
      };
      commonPersonal = {personal = ./.;};
      commonWork = {work = ./.;};
      claudeCodeGeneral = {
        collision = ./.;
        harness = ./.;
      };
    };
  };
  fixturePersonal = fixtureSelector {profile = "personal";};
  fixtureWork = fixtureSelector {profile = "work";};
  fixtureHarness = fixtureSelector {
    profile = "personal";
    harness = "claude-code";
  };
  duplicateWithinCommonSelector = selectSkills {
    groups = emptyGroups // {
      commonGeneral = {duplicate = ../.;};
      commonPersonal = {duplicate = ./.;};
    };
  };
  duplicateWithinHarnessSelector = selectSkills {
    groups = emptyGroups // {
      piGeneral = {duplicate = ../.;};
      piPersonal = {duplicate = ./.;};
    };
  };
  fixturePhysicalHarnesses = builtins.mapAttrs (_: _: {}) supportedHarnessRoots;
  assembleFixture = args: assembleSkills ({
      rootSkills = {};
      vendoredCommonSkills = {};
      physicalHarnessSkills = fixturePhysicalHarnesses;
      skillHarnesses = {};
      supportedHarnesses = builtins.attrNames supportedHarnessRoots;
    } // args);
  sameLayerCollision = assembleFixture {
    rootSkills = {collision = ../.;};
    vendoredCommonSkills = {collision = ./.;};
  };
  routedPhysicalCollision = assembleFixture {
    rootSkills = {collision = ../.;};
    physicalHarnessSkills = fixturePhysicalHarnesses // {
      pi = {collision = ./.;};
    };
    skillHarnesses = {collision = "pi";};
  };
  staleRoute = assembleFixture {
    skillHarnesses = {missing = "pi";};
  };
  unsupportedRoute = assembleFixture {
    rootSkills = {routed = ../.;};
    skillHarnesses = {routed = "unsupported";};
  };
in
  assert rootNames == movedRootNames;
  assert !(builtins.elem "pi-jsonl-logs" commonNames);
  assert builtins.elem "pi-jsonl-logs" harnessNames.pi;
  assert builtins.all
    (harness: harness == "pi" || !(builtins.elem "pi-jsonl-logs" harnessNames.${harness}))
    (builtins.attrNames supportedHarnessRoots);
  assert namesFor {profile = "personal";} == expectedNames "personal" null;
  assert namesFor {profile = "work";} == expectedNames "work" null;
  assert namesFor {
    profile = "personal";
    harness = null;
  } == expectedNames "personal" null;
  assert builtins.all
  (selection:
    builtins.attrNames selection.skills
    == selection.expected
    && pathsAreValid selection.skills)
  harnessSelections;
  assert builtins.all
  (harness:
    namesFor {
      profile = "personal";
      inherit harness;
    } == namesFor {profile = "personal";})
  emptyHarnesses;
  assert pathsAreValid commonPersonal;
  assert pathsAreValid commonWork;

  assert builtins.hasAttr "common" fixturePersonal;
  assert builtins.hasAttr "personal" fixturePersonal;
  assert !builtins.hasAttr "work" fixturePersonal;
  assert builtins.hasAttr "common" fixtureWork;
  assert builtins.hasAttr "work" fixtureWork;
  assert !builtins.hasAttr "personal" fixtureWork;
  assert builtins.hasAttr "harness" fixtureHarness;
  assert toString fixtureHarness.collision == toString ./.;

  assert builtins.filter (name: builtins.elem name profiles.work) profiles.personal == [];
  assert builtins.all
  (name: builtins.elem name allCatalogNames)
  (profiles.personal ++ profiles.work);

  assert fails (lib.skillsFor {profile = "general";});
  assert fails (lib.skillsFor {
    profile = "personal";
    harness = "unknown";
  });
  assert fails (lib.skillsFor {});
  assert fails (lib.skillsFor {
    profile = "personal";
    profiles = [];
  });
  assert fails (duplicateWithinCommonSelector {profile = "personal";});
  assert fails (duplicateWithinHarnessSelector {
    profile = "personal";
    harness = "pi";
  });
  assert fails sameLayerCollision;
  assert fails routedPhysicalCollision;
  assert fails staleRoute;
  assert fails unsupportedRoute;
  true
