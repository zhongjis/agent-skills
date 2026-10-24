include "session";
if any(.[]; type != "object" or (.type | type) != "string") then error("each JSONL entry must be an object with a type") else . end |
# Compile user regexes even for empty sessions; never evaluate them as jq code.
def validate_regex($p): ("" | test($p; "i")) | null;
def endpoint_regex($mode; $p):
  if $mode == "-tool-arg" then
    if $p | contains(":") then $p | index(":") as $i | validate_regex(.[:$i]), validate_regex(.[($i+1):])
    else error("tool-arg endpoint requires NAME:PATTERN") end
  else validate_regex($p) end;
([if $cli == "toolcalls" then validate_regex($tool)
 elif $cli == "custom" then validate_regex($type)
 elif $cli == "timing" then endpoint_regex($fm; $from), endpoint_regex($tm; $to)
 else null end]) as $validation |
if $cli == "overview" then
  "=== Full-session overview (all branches; not active model context) ===",
  (.[] | select(.type == "session") | "cwd: \(.cwd // "unknown") version: \(.version) started: \(.timestamp)"),
  ([.[] | select(.type == "session_info") | .name // empty] | last // empty | "name: \(.)"),
  "--- Entry Types ---", (group_by(.type)[] | "  \(length) \(.[0].type)"),
  "--- Message Roles ---", ([.[] | select(.type == "message")] | group_by(.message.role)[] | "  \(length) \(.[0].message.role)"),
  "--- Tool Usage (top-level + recorded nested) ---",
  ([calls] | (group_by(.name)[] | "  \(length) \(.[0].name)"),
    "  \(map(.name) | unique | length) unique tools, \(length) total recorded calls"),
  ([usage] | "  cost:        $\(map(.cost.total // 0) | add // 0)",
    "  tokens:      \(map(.totalTokens // 0) | add // 0)",
    "  input:       \(map(.input // 0) | add // 0)", "  output:      \(map(.output // 0) | add // 0)",
    "  reasoning:   \(map(.reasoning // 0) | add // 0) (subset of output)",
    "  cache_read:  \(map(.cacheRead // 0) | add // 0)", "  cache_write: \(map(.cacheWrite // 0) | add // 0)"),
  "  assistant messages: \([.[] | select(.type == "message" and .message.role == "assistant")] | length)",
  "--- Model selection changes (requested) ---", (.[] | select(.type == "model_change") | "\(.provider)/\(.modelId)"),
  "--- Assistant request / provider response model ---",
  ([.[] | select(.type == "message" and .message.role == "assistant") | .message |
    {requested:(.model // "unknown"),response:(.responseModel // .model // "unknown")}] |
    group_by([.requested,.response])[] | "  \(length) requested=\(.[0].requested) response=\(.[0].response)"),
  "--- Thinking ---",
  ([.[] | select(.type == "message" and .message.role == "assistant") | .message.content[]? | select(.type == "thinking")] |
    "thinking blocks: \(length)", "thinking chars: \(map(.thinking // "" | length) | add // 0)"),
  ([.[] | .timestamp // empty | epoch] | if length > 1 then "duration: \(max - min)s (timestamp span)" else "duration: 0s" end),
  warnings
elif $cli == "toolcalls" then
  resultmap as $rm |
  (calls | select(.name | test($tool; "i")) | . as $c |
    (if $field != "" then (.arguments[$field] | tostring)
     else (.arguments | tojson) end) as $value |
    (if $compact and $field != "" then $value
     else "[\(.ts)] \(.name) \(callmeta)" + (if $compact then " | " else "\n  " end) +
       (if $field != "" then $field + "=" else "args: " end) + $value end),
    (if $compact and $field != "" and (.nested or .arguments == null) then "  metadata: \(callmeta)" else empty end),
    (if $results and (.nested | not) then
       if $rm[$c.id] != null then $rm[$c.id] | "  result id=\($c.id) error=\(.isError // false): \(.content | text | one | .[:300])"
       else "  result id=\($c.id): unavailable" end
     else empty end)),
  warnings
elif $cli == "subagents" then
  resultmap as $rm |
  [calls | select(.name == "agent") | select($type == "" or .arguments.subagent_type == $type)] as $cs |
  ($cs[] | "[\(.ts)] \(.arguments.subagent_type // "agent graph/unspecified (not an individual agent)") | \(.arguments.description // "no desc") | bg=\(.arguments.run_in_background // false) inherit_context=\(.arguments.inherit_context // false) | \(callmeta)" +
    (if (.nested | not) and $rm[.id] != null then " resultError=\($rm[.id].isError // false) result=\($rm[.id].content | text | one | .[:300])" else "" end) +
    (if $prompt == 0 then "" else "\n  prompt: " + ((.arguments.prompt // "") | if $prompt == -1 then . else .[:$prompt] end) end)),
  "--- Summary ---", ($cs | group_by(.arguments.subagent_type)[] | "  \(length) \(.[0].arguments.subagent_type // "agent graph/unspecified")"), warnings
elif $cli == "tasks" then
  resultmap as $rm |
  [calls | select(.name == "Task")] as $cs |
  ($cs[] | . as $call | .arguments as $a |
    "[\(.ts)] Task op=\($a.op // "unknown") \(callmeta)",
    (($a.tasks // []) | to_entries[] | .key as $i | .value |
      # Current Task create is all-or-nothing and returns ordered explicit taskIds.
      (if .taskId != null then .taskId
       elif $a.op == "create" and $rm[$call.id].isError != true and
            ($rm[$call.id].details.taskIds | type) == "array" and
            ($rm[$call.id].details.taskIds | length) == ($a.tasks | length) then
         $rm[$call.id].details.taskIds[$i]
       else null end) as $id |
      "  task#\($id // "unassigned/unknown") \(.subject // "") status=\(.status // "unspecified") addBlocks=\(.addBlocks // [] | tojson) addBlockedBy=\(.addBlockedBy // [] | tojson)" +
      (if .description != null then "\n    desc: \(.description | one | .[:150])" else "" end)),
    (if $a.taskId != null then "  taskId=\($a.taskId)" else empty end)),
  "--- Summary (calls by op; records by lifecycle) ---",
  ($cs | group_by(.arguments.op)[] | "  \(.[0].arguments.op // "unknown"): \(length) calls, \([.[].arguments.tasks[]?] | length) task records"), warnings
elif $cli == "files" then
  [calls | select(.name | IN("read", "write", "edit", "grep", "find", "ls")) |
    select($op == "" or .name == $op)] as $cs |
  (if $unique then [$cs[].arguments.path // empty] | unique[]
   else $cs | group_by(.name)[] | "=== \(.[0].name) ===",
     ([.[].arguments.path // empty] | unique | (.[] | "  " + .), "  (\(length) unique files)") end),
  ($cs[] | select(.arguments == null) | "WARNING: path unavailable; \(.name) \(callmeta)"), warnings
elif $cli == "custom" then
  [.[] | select(.type == "custom" or .type == "custom_message" or (.type == "message" and .message.role == "custom")) |
    if .type == "message" then . + {customType:.message.customType,content:.message.content,display:.message.display} else . end |
    select((.customType // "unknown") | test($type; "i"))] as $cs |
  ($cs[] | "[\(.timestamp)] \(.type): \(.customType // "unknown") | " +
    (if .type == "custom" then
       if $data then "data: " + (.data | tojson)
       elif .data | type == "object" then "keys: " + (.data | keys | join(","))
       else "data type: " + (.data | type) end
     else "display=\(if .display == null then "unknown" else .display end) | " +
       (.content | text | if $data then . else .[:150] end) end) |
    if $compact then one else . end),
  "--- Summary ---", ($cs | group_by(.customType)[] | "  \(length) \(.[0].customType // "unknown")"), "  total: \($cs | length)"
elif $cli == "thread" then
  (if $leaf == "" then . else path($leaf) end) |
  "=== Raw audit history (\(if $leaf == "" then "all branches, append order" else "parentId path to " + $leaf end)); not model-visible context ===",
  ([.[] |
    if .type == "message" then
      .message as $m |
      if $m.role == "toolResult" and ($tools | not) then empty
      else
        (if $m.role == "bashExecution" then "\($m.command // "") exit=\($m.exitCode // "unknown")"
         elif $m.role == "system" then ($m.content | text) + " sections=" + (($m.sections // {}) | tojson) + " toolsAdded=" + (($m.toolsAdded // []) | map(.name) | tojson) + " toolsRemoved=" + (($m.toolsRemoved // []) | map(.name) | tojson)
         elif $m.role == "assistant" then
           ([$m.content[]? | if .type == "text" then .text elif .type == "toolCall" then "[TOOL:\(.name)]" else empty end] | join(" "))
         else ($m.content | text) + ($m.summary // "") end) as $body |
        select(($noempty and $m.role == "assistant" and ($body | test("^\\s*$"))) | not) |
        "\(.timestamp) | \(.id) | \($m.role)\(if $m.role == "toolResult" then ":\($m.toolName) error=\($m.isError)" else "" end) | \($body | one | .[:$max])"
      end
    elif .type == "custom_message" then "\(.timestamp) | \(.id) | custom_message:\(.customType) | \(.content | text | one | .[:$max])"
    elif .type == "compaction" or .type == "branch_summary" then
      "\(.timestamp) | \(.id) | \(.type) firstKeptEntryId=\(.firstKeptEntryId // "n/a") | \(.summary | one | .[:$max])"
    elif .type == "context_edit" then
      "\(.timestamp) | \(.id) | context_edit target=\(.targetId) omission=\(.replacement == null) replacement=\(.replacement | text | one | .[:$max]) (raw target unchanged)"
    elif .type == "model_change" or .type == "thinking_level_change" then "\(.timestamp) | \(.id) | \(.type) \(.modelId // .thinkingLevel)"
    else empty end] |
    if $head >= 0 then .[:$head][] elif $tail == 0 then empty elif $tail > 0 then .[-$tail:][] else .[] end)
elif $cli == "timing" then
  def matches($mode; $pattern):
    if $mode == "text" then
      [.[] | select(.type == "message" or .type == "custom_message") |
        (if .type == "message" then .message.content else .content end | text) as $body |
        select($body | test($pattern; "i")) | {ts:.timestamp}]
    else
      (if $mode == "-tool-arg" then
        if $pattern | contains(":") then $pattern | index(":") as $i | {name:.[:$i],arg:.[($i+1):]}
        else error("tool-arg endpoint requires NAME:PATTERN") end
       else {name:$pattern} end) as $p |
      [calls | select(.name | test($p.name; "i")) |
        select($p.arg == null or (.arguments | tojson | test($p.arg; "i")))]
    end;
  matches($fm; $from) as $fs | matches($tm; $to) as $ts |
  ($fs[0].ts // error("no from event matched")) as $start |
  ($start | epoch) as $t0 |
  ([$ts[] | select((.ts | epoch) >= $t0)][0].ts // error("no to event matched at/after from")) as $end |
  "from: \($start)", "to:   \($end)", "duration: \(((($end | epoch) - $t0) * 1000 | round) / 1000)s"
elif $cli == "errors" then
  [(.[] | select(.type == "message") | . as $e | .message as $m |
    if $m.role == "assistant" and ($m.stopReason == "error" or $m.stopReason == "aborted") then
      {ts:.timestamp,kind:"assistant " + $m.stopReason,body:($m.errorMessage // "") + " diagnostics=" + ($m.diagnostics // [] | tojson)}
    elif $m.role == "toolResult" and $m.isError == true then
      {ts:.timestamp,kind:"tool error " + $m.toolName,body:($m.content | text)}
    elif $m.role == "bashExecution" and (($m.exitCode != null and $m.exitCode != 0) or $m.cancelled == true) then
      {ts:.timestamp,kind:"bash execution exit=" + ($m.exitCode | tostring) + " cancelled=" + ($m.cancelled // false | tostring),body:($m.command // "") + " " + ($m.output // "")}
    elif $m.role == "toolResult" and $m.toolName == "bash" and ($m.content | text | test("(Command exited with code [1-9]|exit(ed with)? (code |status )[1-9])"; "i")) then
      {ts:.timestamp,kind:"bash output-text failure hint (not structured exit status)",body:($m.content | text)}
    else empty end),
    (calls | select(.nested and .status == "error") | {ts,kind:"nested tool error " + .name,body:callmeta})] as $es |
  ($es[] | "[\(.ts)] \(.kind) | " + (.body | if $compact then one | .[:200] else . end)),
  "--- Summary (disjoint records; text hints not structured failures) ---",
  ($es | group_by(.kind)[] | "  \(length) \(.[0].kind)"), "  total records: \($es | length)", warnings
else error("unknown report: " + $cli) end
