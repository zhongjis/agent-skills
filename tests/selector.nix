let
  lib = import ../lib;
  profiles = import ../profiles.nix;
  selectSkills = import ../lib/select-skills.nix;

  commonGeneralNames = [
    "address-comments"
    "agent-browser"
    "agent-readiness"
    "agentation"
    "agents-md"
    "ast-grep"
    "before-and-after"
    "bun"
    "caveman"
    "code-review"
    "code-review-v2"
    "codebase-design"
    "codebase-search"
    "database-schema-design"
    "diagnosing-bugs"
    "docker"
    "docx"
    "domain-modeling"
    "fd"
    "find-skills"
    "gh"
    "git-master"
    "github-actions"
    "grill-with-docs"
    "grilling"
    "handoff"
    "html-diagram"
    "huashu-design"
    "huashu-nuwa"
    "improve-codebase-architecture"
    "jq"
    "kubectl"
    "last30days"
    "mcp-builder"
    "neat-freak"
    "nix"
    "obsidian-cli"
    "pdf"
    "pnpm"
    "podman"
    "postgresql-table-design"
    "pptx"
    "prompt-engineering-patterns"
    "prototype"
    "python"
    "react-best-practices"
    "refactor-method-complexity-reduce"
    "rg"
    "setup-matt-pocock-skills"
    "setup-repo-docs"
    "shell-expert"
    "skill-maintainer"
    "sql-code-review"
    "sql-optimization-patterns"
    "tdd"
    "teach"
    "to-spec"
    "to-tickets"
    "triage"
    "typescript-best-practices"
    "use-open-design-canvas"
    "uv"
    "vitest"
    "webapp-testing"
    "writing-clearly-and-concisely"
    "writing-for-agents"
    "xlsx"
    "yq"
    "yt-dlp"
    "zoom-out"
  ];
  personalNames = builtins.sort builtins.lessThan commonGeneralNames;
  workNames = builtins.sort builtins.lessThan (
    commonGeneralNames
    ++ [
      "github-pr-management"
      "mysql-best-practices"
      "splunk"
    ]
  );
  piPersonalNames = builtins.sort builtins.lessThan (personalNames ++ ["pi-jsonl-logs"]);
  piWorkNames = builtins.sort builtins.lessThan (workNames ++ ["pi-jsonl-logs"]);
  claudePersonalNames = builtins.sort builtins.lessThan (personalNames ++ ["skill-creator"]);
  emptyHarnesses = ["codex" "factory" "omp" "opencode"];

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
  claudePersonal = lib.skillsFor {
    profile = "personal";
    harness = "claude-code";
  };
  piPersonal = lib.skillsFor {
    profile = "personal";
    harness = "pi";
  };
  piWork = lib.skillsFor {
    profile = "work";
    harness = "pi";
  };
  emptyHarnessSelections = builtins.concatLists (map (harness: [
      {
        expected = personalNames;
        skills = lib.skillsFor {
          profile = "personal";
          inherit harness;
        };
      }
      {
        expected = workNames;
        skills = lib.skillsFor {
          profile = "work";
          inherit harness;
        };
      }
    ])
    emptyHarnesses);
  emptyHarnessGroups = {
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
  };

  duplicateWithinCommonSelector = selectSkills {
    groups =
      {
        commonGeneral = {duplicate = ../.agents/skills/caveman;};
        commonPersonal = {duplicate = ../.agents/skills/git-master;};
        commonWork = {};
        claudeCodeGeneral = {};
        claudeCodePersonal = {};
        claudeCodeWork = {};
        piGeneral = {};
        piPersonal = {};
        piWork = {};
      }
      // emptyHarnessGroups;
  };
  harnessOverrideSelector = selectSkills {
    groups =
      {
        commonGeneral = {collision = ../.agents/skills/caveman;};
        commonPersonal = {};
        commonWork = {};
        claudeCodeGeneral = {collision = ../.claude/skills/skill-creator;};
        claudeCodePersonal = {};
        claudeCodeWork = {};
        piGeneral = {};
        piPersonal = {};
        piWork = {};
      }
      // emptyHarnessGroups
      // {
        codexGeneral = {codex-only = ../.agents/skills/caveman;};
        factoryGeneral = {factory-only = ../.agents/skills/caveman;};
        ompGeneral = {omp-only = ../.agents/skills/caveman;};
        opencodeGeneral = {opencode-only = ../.agents/skills/caveman;};
      };
  };
  harnessOverride = harnessOverrideSelector {
    profile = "personal";
    harness = "claude-code";
  };
  harnessRoutesAreValid = builtins.all (harness:
    builtins.hasAttr "${harness}-only" (harnessOverrideSelector {
      profile = "personal";
      inherit harness;
    }))
  emptyHarnesses;
in
  assert namesFor {profile = "personal";} == personalNames;
  assert namesFor {profile = "work";} == workNames;
  assert namesFor {
    profile = "personal";
    harness = null;
  }
  == personalNames;
  assert namesFor {
    profile = "personal";
    harness = "claude-code";
  }
  == claudePersonalNames;
  assert namesFor {
    profile = "personal";
    harness = "pi";
  }
  == piPersonalNames;
  assert namesFor {
    profile = "work";
    harness = "pi";
  }
  == piWorkNames;
  assert builtins.match ".*/.agents/skills/mcp-builder" (toString claudePersonal.mcp-builder) != null;
  assert builtins.match ".*/.claude/skills/skill-creator" (toString claudePersonal.skill-creator) != null;
  assert builtins.match ".*/.claude/skills/skill-creator" (toString harnessOverride.collision) != null;
  assert pathsAreValid commonPersonal;
  assert pathsAreValid commonWork;
  assert pathsAreValid claudePersonal;
  assert pathsAreValid piPersonal;
  assert pathsAreValid piWork;
  assert builtins.all (selection: builtins.attrNames selection.skills == selection.expected) emptyHarnessSelections;
  assert builtins.all (selection: pathsAreValid selection.skills) emptyHarnessSelections;
  assert harnessRoutesAreValid;
  # Guardrail (i): profiles.personal ∩ profiles.work == []
  assert builtins.filter (n: builtins.elem n profiles.work) profiles.personal == [];

  # Guardrail (ii): every name in profiles.personal ++ profiles.work has SKILL.md
  assert builtins.all (name:
    let skills = commonPersonal // commonWork;
    in builtins.hasAttr name skills && builtins.pathExists (skills.${name} + "/SKILL.md")
  ) (profiles.personal ++ profiles.work);

  # Guardrail (iii): personal names in commonPersonal not commonWork, vice versa; 70 general
  assert builtins.all (n: builtins.hasAttr n commonPersonal) profiles.personal;
  assert !builtins.any (n: builtins.hasAttr n commonWork) profiles.personal;
  assert builtins.all (n: builtins.hasAttr n commonWork) profiles.work;
  assert !builtins.any (n: builtins.hasAttr n commonPersonal) profiles.work;
  assert builtins.length commonGeneralNames == 70;
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
  assert fails (duplicateWithinCommonSelector {profile = "personal";}); true
