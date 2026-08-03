{groups}: args: let
  allowedArguments = [
    "harness"
    "profile"
  ];
  unsupportedArguments =
    builtins.filter
    (name: !(builtins.elem name allowedArguments))
    (builtins.attrNames args);
  profile =
    if args ? profile
    then args.profile
    else throw "agent-skills.skillsFor: missing required argument: profile";
  harness = args.harness or null;
  profileGroups = general: personal: work: [
    general
    (
      if profile == "personal"
      then personal
      else work
    )
  ];
  commonGroups = profileGroups groups.commonGeneral groups.commonPersonal groups.commonWork;
  harnessGroups =
    if harness == "claude-code"
    then profileGroups groups.claudeCodeGeneral groups.claudeCodePersonal groups.claudeCodeWork
    else if harness == "pi"
    then profileGroups groups.piGeneral groups.piPersonal groups.piWork
    else [];
  duplicateNamesFor = selectedGroups: let
    selectedNames = builtins.concatLists (map builtins.attrNames selectedGroups);
    uniqueNames = builtins.attrNames (builtins.listToAttrs (map (name: {
      inherit name;
      value = null;
    })
    selectedNames));
  in
    builtins.filter
    (name: builtins.length (builtins.filter (selectedName: selectedName == name) selectedNames) > 1)
    uniqueNames;
  commonDuplicateNames = duplicateNamesFor commonGroups;
  harnessDuplicateNames = duplicateNamesFor harnessGroups;
  mergeGroups = builtins.foldl' (accumulator: group: accumulator // group) {};
in
  if unsupportedArguments != []
  then throw "agent-skills.skillsFor: unsupported arguments: ${builtins.concatStringsSep ", " unsupportedArguments}"
  else if !(args ? profile)
  then throw "agent-skills.skillsFor: missing required argument: profile"
  else if profile != "personal" && profile != "work"
  then throw ''agent-skills.skillsFor: profile must be "personal" or "work"''
  else if harness != null && harness != "claude-code" && harness != "pi"
  then throw ''agent-skills.skillsFor: harness must be null, "claude-code", or "pi"''
  else if commonDuplicateNames != []
  then throw "agent-skills.skillsFor: duplicate common skill names: ${builtins.concatStringsSep ", " commonDuplicateNames}"
  else if harnessDuplicateNames != []
  then throw "agent-skills.skillsFor: duplicate ${harness} skill names: ${builtins.concatStringsSep ", " harnessDuplicateNames}"
  else mergeGroups commonGroups // mergeGroups harnessGroups
