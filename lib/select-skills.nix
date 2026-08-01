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
  selectedGroups =
    [
      groups.commonGeneral
      (
        if profile == "personal"
        then groups.commonPersonal
        else groups.commonWork
      )
    ]
    ++ (
      if harness == "pi"
      then [
        groups.piGeneral
        (
          if profile == "personal"
          then groups.piPersonal
          else groups.piWork
        )
      ]
      else []
    );
  selectedNames = builtins.concatLists (map builtins.attrNames selectedGroups);
  uniqueNames = builtins.attrNames (builtins.listToAttrs (map (name: {
      inherit name;
      value = null;
    })
    selectedNames));
  duplicateNames =
    builtins.filter
    (name: builtins.length (builtins.filter (selectedName: selectedName == name) selectedNames) > 1)
    uniqueNames;
in
  if unsupportedArguments != []
  then throw "agent-skills.skillsFor: unsupported arguments: ${builtins.concatStringsSep ", " unsupportedArguments}"
  else if !(args ? profile)
  then throw "agent-skills.skillsFor: missing required argument: profile"
  else if profile != "personal" && profile != "work"
  then throw ''agent-skills.skillsFor: profile must be "personal" or "work"''
  else if harness != null && harness != "pi"
  then throw ''agent-skills.skillsFor: harness must be null or "pi"''
  else if duplicateNames != []
  then throw "agent-skills.skillsFor: duplicate skill names: ${builtins.concatStringsSep ", " duplicateNames}"
  else builtins.foldl' (accumulator: group: accumulator // group) {} selectedGroups
