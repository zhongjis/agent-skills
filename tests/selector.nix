let
  lib = import ../lib;
  selectSkills = import ../lib/select-skills.nix;

  commonGeneralNames = [
    "address-comments"
    "agent-browser"
    "agent-readiness"
    "agentation"
    "agents-md"
    "ast-grep"
    "before-and-after"
    "biome-js"
    "bun"
    "canvas-design"
    "caveman"
    "code-review"
    "code-review-v2"
    "codebase-design"
    "codebase-search"
    "complexity"
    "database-migration"
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
    "jujutsu"
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
    "prompt-engineering"
    "prototype"
    "python"
    "react-best-practices"
    "rg"
    "setup-matt-pocock-skills"
    "setup-repo-docs"
    "shell-expert"
    "skill-maintainer"
    "sql-code-review"
    "sql-optimization-patterns"
    "svg-logo-designer"
    "tdd"
    "teach"
    "to-spec"
    "to-tickets"
    "triage"
    "typescript-best-practices"
    "use-open-design-canvas"
    "uv"
    "vite"
    "vitepress"
    "vitest"
    "webapp-testing"
    "writing-clearly-and-concisely"
    "writing-great-skills"
    "xlsx"
    "yq"
    "yt-dlp"
    "zoom-out"
  ];
  personalNames = builtins.sort builtins.lessThan (
    commonGeneralNames
    ++ [
      "recharts-patterns"
      "supabase-postgres-best-practices"
      "svelte"
      "sveltekit"
    ]
  );
  workNames = builtins.sort builtins.lessThan (
    commonGeneralNames
    ++ [
      "enterprise-scala"
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
        commonGeneral = {duplicate = ../skills/common-general/caveman;};
        commonPersonal = {duplicate = ../skills/common-personal/svelte;};
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
        commonGeneral = {collision = ../skills/common-general/caveman;};
        commonPersonal = {};
        commonWork = {};
        claudeCodeGeneral = {collision = ../skills/claude-code-general/skill-creator;};
        claudeCodePersonal = {};
        claudeCodeWork = {};
        piGeneral = {};
        piPersonal = {};
        piWork = {};
      }
      // emptyHarnessGroups
      // {
        codexGeneral = {codex-only = ../skills/common-general/caveman;};
        factoryGeneral = {factory-only = ../skills/common-general/caveman;};
        ompGeneral = {omp-only = ../skills/common-general/caveman;};
        opencodeGeneral = {opencode-only = ../skills/common-general/caveman;};
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
  assert builtins.match ".*/skills/common-general/mcp-builder" (toString claudePersonal.mcp-builder) != null;
  assert builtins.match ".*/skills/claude-code-general/skill-creator" (toString claudePersonal.skill-creator) != null;
  assert builtins.match ".*/skills/claude-code-general/skill-creator" (toString harnessOverride.collision) != null;
  assert pathsAreValid commonPersonal;
  assert pathsAreValid commonWork;
  assert pathsAreValid claudePersonal;
  assert pathsAreValid piPersonal;
  assert pathsAreValid piWork;
  assert builtins.all (selection: builtins.attrNames selection.skills == selection.expected) emptyHarnessSelections;
  assert builtins.all (selection: pathsAreValid selection.skills) emptyHarnessSelections;
  assert harnessRoutesAreValid;
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
