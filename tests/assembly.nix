let
  assembleSkills = import ../lib/assemble-skills.nix;
  supportedHarnesses = [
    "claude-code"
    "codex"
    "factory"
    "omp"
    "opencode"
    "pi"
  ];
  physicalHarnessSkills = builtins.listToAttrs (map (name: {
      inherit name;
      value = {};
    }) supportedHarnesses);
  assembleFixture = args: assembleSkills ({
      rootSkills = {};
      vendoredCommonSkills = {};
      inherit physicalHarnessSkills supportedHarnesses;
      skillHarnesses = {};
    } // args);
  sameLayerCollision = assembleFixture {
    rootSkills = {collision = ../.;};
    vendoredCommonSkills = {collision = ./.;};
  };
  routedPhysicalCollision = assembleFixture {
    rootSkills = {collision = ../.;};
    physicalHarnessSkills = physicalHarnessSkills // {
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
  fails = value: !(builtins.tryEval (builtins.deepSeq value true)).success;
in
  assert fails sameLayerCollision;
  assert fails routedPhysicalCollision;
  assert fails staleRoute;
  assert fails unsupportedRoute;
  true
