# Claude Code session reports over slurped JSONL entries.
# Never print thinking text, signatures, or image data.
def one: gsub("\\s+"; " ");
def cut($n): one | if $n == 0 or length <= $n then . else .[:$n] + "…" end;
def text:
  if type == "string" then .
  elif type == "array" then [.[] | select(.type == "text") | .text // ""] | join("\n")
  else "" end;
def images: if type == "array" then [.[] | select(.type == "image")] | length else 0 end;
def ctag: (capture("^\\s*<(?<t>[A-Za-z_-]+)>") | .t) // null;

# User entries carry human prompts, slash/bash commands, interrupts, harness-injected
# text, skill bodies (isMeta), compaction summaries, and tool results.
def ukind:
  if .isCompactSummary then "summary"
  elif .isMeta then "meta"
  elif (.message.content | text | startswith("[Request interrupted by user")) then "interrupt"
  else .message.content as $c |
    if ($c | type) == "array" then
      (if any($c[]; .type == "tool_result") then "result" else "prompt" end)
    else ($c | ctag) as $t |
      if $t == null then "prompt"
      elif $t == "command-message" or $t == "command-name" or $t == "bash-input" then "command"
      else "injected" end
    end
  end;
def utext:
  .message.content as $c |
  if ($c | type) != "string" then
    ($c | text) + (if ($c | images) > 0 then " [\($c | images) image(s)]" else "" end)
  elif ($c | test("<command-name>")) then
    ($c | capture("<command-name>(?<n>[^<]*)</command-name>").n)
    + ((($c | capture("<command-args>(?<a>[\\s\\S]*?)</command-args>").a) // "") | if . == "" then "" else " " + . end)
  elif ($c | test("^\\s*<bash-input>")) then
    "! " + (($c | capture("<bash-input>(?<b>[\\s\\S]*?)</bash-input>").b) // "")
  else $c end;

def apierr: .type == "assistant" and (.isApiErrorMessage // false);
def calls:
  .[] | select(.type == "assistant") | . as $e | .message.content[]? | select(.type == "tool_use") |
  {timestamp: ($e.timestamp // "-"), id, name, input: (.input // {}), side: ($e.isSidechain // false)};
def results:
  reduce (.[] | select(.type == "user") | . as $e | .message.content | arrays | .[] | select(.type == "tool_result") |
    {id: .tool_use_id, timestamp: ($e.timestamp // "-"), error: (.is_error // false),
     body: ((.content | text) + (if (.content | images) > 0 then " [image]" else "" end)),
     extra: $e.toolUseResult}) as $r ({}; .[$r.id] = $r);
def key:
  .input as $i |
  ($i.command // $i.file_path // $i.notebook_path // $i.pattern // $i.url // $i.query
   // $i.skill // $i.description // $i.prompt // ($i | tojson)) | tostring;
# One API response is split into one line per content block, each repeating
# the same usage; count each message.id once.
def usages:
  [.[] | select(.type == "assistant" and (apierr | not) and .message.usage != null and .message.model != "<synthetic>") |
    {k: (.message.id // .requestId // .uuid), u: .message.usage, m: .message.model}] | group_by(.k) | map(last);
def window: select(($since == "" or (.timestamp // "") >= $since) and ($until == "" or (.timestamp // "") < $until));
def epoch: capture("^(?<b>[0-9-]+T[0-9:]+)(?<f>\\.[0-9]+)?Z$") | (.b + "Z" | fromdateiso8601) + (("0" + (.f // "")) | tonumber);
def limit: if $head >= 0 then .[:$head] elif $tail == 0 then [] elif $tail > 0 then .[-$tail:] else . end;
def counts: group_by(.) | map({key: (.[0] | tostring), value: length}) | sort_by(-.value) | map("\(.key)=\(.value)") | join(" ");
def sum($f): map(.u[$f] // 0) | add // 0;

def overview:
  ([.[] | select(.cwd != null)][0] // {}) as $h |
  ([.[] | .timestamp // empty] | sort) as $ts |
  ([.[] | select(.type == "user") | ukind] | group_by(.) | map({key: .[0], value: length}) | from_entries) as $k |
  ([.[] | select(.type == "cost-state")][-1]) as $cost |
  usages as $u | [calls] as $calls |
  "session:   \($h.sessionId // "-")  agent: \($h.agentId // "main")",
  "title:     \([.[] | select(.type == "ai-title") | .aiTitle][-1] // "-")",
  "cwd:       \($h.cwd // "-")  branch: \($h.gitBranch // "-")  version: \($h.version // "-")",
  (if ($ts | length) > 0
   then "span:      \($ts[0]) to \($ts[-1]) (\(try ((($ts[-1] | epoch) - ($ts[0] | epoch)) | floor | tostring) catch "?")s)"
   else "span:      -" end),
  "entries:   \(length) lines: \(map(.type) | counts)",
  "user:      prompts=\($k.prompt // 0) commands=\($k.command // 0) injected=\($k.injected // 0) meta=\($k.meta // 0) tool-results=\($k.result // 0) interrupts=\($k.interrupt // 0) compact-summaries=\($k.summary // 0)",
  "assistant: messages=\([.[] | select(.type == "assistant" and (apierr | not)) | .message.id // .uuid] | unique | length) api-errors=\([.[] | select(apierr)] | length)",
  "tools:     \($calls | map(.name) | counts)",
  "tokens:    input=\($u | sum("input_tokens")) output=\($u | sum("output_tokens")) cache-read=\($u | sum("cache_read_input_tokens")) cache-write=\($u | sum("cache_creation_input_tokens")) (once per message.id)",
  "models:    \($u | map(.m) | counts)",
  "cost:      \(if $cost then "$\(($cost.totalCostUSD // 0) * 10000 | round / 10000) (last cost-state snapshot)" else "not recorded" end)",
  "compactions: \([.[] | select(.type == "system" and .subtype == "compact_boundary") | .compactMetadata.trigger // "?"] | counts | if . == "" then "0" else . end)",
  "subagents: agent-calls=\($calls | map(select(.name == "Agent")) | length) transcripts=\($metas | length)";

def prompts:
  [.[] | select(.type == "user") | window | ukind as $k |
    select($k == "prompt" or $k == "command" or ($all and ($k == "injected" or $k == "meta" or $k == "summary" or $k == "interrupt"))) |
    "\(.timestamp // "-") \($k | ascii_upcase): \(utext | cut($max))"] | limit | .[];

def thread:
  ([calls] | map({key: .id, value: .name}) | from_entries) as $names |
  [.[] | window | (.timestamp // "-") as $t |
    if .type == "user" then ukind as $k |
      if $k == "prompt" or $k == "command" or $k == "summary" or $k == "injected" or $k == "interrupt" or ($k == "meta" and $all) then
        "\($t) \($k | ascii_upcase): \(utext | cut($max))"
      elif $k == "result" and $tools then
        .message.content[] | select(.type == "tool_result") |
        "\($t)     RESULT\(if .is_error then " ERROR" else "" end) \($names[.tool_use_id] // "?"): \(.content | text | cut($max))"
      else empty end
    elif apierr then "\($t) API-ERROR \(.error // "-"): \(.message.content | text | cut($max))"
    elif .type == "assistant" then
      .message.content[]? |
      if .type == "text" then select(.text | test("\\S")) | "\($t) ASSISTANT: \(.text | cut($max))"
      elif .type == "tool_use" then "\($t)   TOOL \(.name): \(key | cut($max))"
      else empty end
    elif .type == "system" and .subtype == "compact_boundary" then
      "\($t) COMPACT \(.compactMetadata.trigger // "?"): \(.compactMetadata.preTokens // "?") to \(.compactMetadata.postTokens // "?") tokens"
    else empty end] | limit | .[];

def toolcalls:
  results as $res |
  calls | window |
  select($tool == "" or (.name | test($tool; "i"))) |
  select($match == "" or (.input | tojson | test($match; "i"))) |
  (if $field == "" then key else (.input[$field] // empty | if type == "string" then . else tojson end) end) as $v |
  $res[.id] as $r |
  (if $compact then "\(.timestamp) \(.name): \($v | cut($max))"
   else "\(.timestamp) \(.name) id=\(.id)\(if .side then " sidechain" else "" end)\n  \(if $field == "" then (.input | tojson) else $v end | cut($max))" end) +
  (if $results | not then ""
   elif $r == null then "\n  RESULT: none recorded"
   else "\n  RESULT\(if $r.error then " ERROR" else "" end): \($r.body | cut($max))" end);

def errors:
  results as $res | ([calls] | map({key: .id, value: .}) | from_entries) as $c |
  [(.[] | select(apierr) | window | "\(.timestamp // "-") API-ERROR \(.error // "-"): \(.message.content | text | cut($max))"),
   ($res[] | window | . as $r | (($r.extra | type) == "object" and $r.extra.interrupted == true) as $int |
     select($r.error or $int) | ($c[$r.id] // {name: "?", input: {}}) as $call |
     "\($r.timestamp) TOOL-ERROR \($call.name)\(if $int then " interrupted" else "" end): \($call | key | cut(160)) => \($r.body | cut($max))")
  ] | sort | .[];

def fileops: {Read: "read", Write: "write", Edit: "edit", MultiEdit: "edit", NotebookEdit: "edit", Grep: "grep", Glob: "glob"};
def files:
  [calls | window | fileops[.name] as $o | select($o != null and ($opf == "" or $o == $opf)) |
    {timestamp, op: $o, path: (.input.file_path // .input.notebook_path // .input.path // empty)}] |
  if $unique then group_by(.path) | .[] | "\(length)x \(map(.op) | unique | join(",")) \(.[0].path)"
  else .[] | "\(.timestamp) \(.op) \(.path)" end;

def subagents:
  results as $res |
  ($metas | map({key: (.toolUseId // ""), value: .}) | from_entries) as $m |
  calls | window | select(.name == "Agent" or (.name == "Task" and .input.subagent_type != null)) |
  select($type == "" or ((.input.subagent_type // "general-purpose") | test($type; "i"))) |
  $res[.id] as $r | $m[.id] as $meta |
  ($r.extra | if type == "object" then . else {} end) as $x |
  ($x.agentId // $meta.agentId) as $aid |
  "\(.timestamp) \(.input.subagent_type // "general-purpose"): \(.input.description // "-")\(if .input.run_in_background then " [background]" else "" end)\(if .input.model then " model=\(.input.model)" else "" end)",
  "  status: \($x.status // (if $r == null then "no result recorded" elif $r.error then "error" else "completed" end))\(if $meta then " finished=\($meta.finished // "?")" else "" end)",
  (if $aid then "  transcript: \($meta.file // ($subdir + "/agent-" + $aid + ".jsonl"))" else empty end),
  (if $prompt == 0 then empty else "  prompt: \(.input.prompt // "" | if $prompt < 0 then one else cut($prompt) end)" end);

def skills:
  [(calls | window | select(.name == "Skill") | {timestamp, kind: "tool", name: (.input.skill // "?"), args: (.input.args // "")}),
   (.[] | select(.type == "user") | window | select(ukind == "command") | utext as $t | select($t | startswith("/")) |
     {timestamp, kind: "slash", name: ($t | capture("^/(?<n>\\S+)").n), args: ($t | sub("^/\\S+\\s*"; ""))})] |
  sort_by(.timestamp) |
  (.[] | "\(.timestamp) \(.kind) \(.name)\(if .args != "" then ": " + (.args | cut($max)) else "" end)"),
  "totals: \(map(.name) | counts)";

if $cli == "overview" then overview
elif $cli == "prompts" then prompts
elif $cli == "thread" then thread
elif $cli == "toolcalls" then toolcalls
elif $cli == "errors" then errors
elif $cli == "files" then files
elif $cli == "subagents" then subagents
elif $cli == "skills" then skills
else error("unknown report: " + $cli) end
