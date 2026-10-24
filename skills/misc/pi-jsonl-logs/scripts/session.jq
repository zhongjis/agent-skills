# Current Pi v3 report primitives. Never emit image data or replay signatures.
def text:
  if type == "string" then .
  elif type == "array" then [ .[] | select(.type == "text") | .text // "" ] | join("\n")
  else "" end;
def one: gsub("[\r\n]"; " ");
def arguments:
  if . == null then null
  elif type == "object" then .
  elif type == "string" then fromjson | if type == "object" then . else error("tool arguments must be an object") end
  else error("tool arguments must be an object") end;
def calls:
  .[] | select(.type == "message") | .timestamp as $ts | .message |
  if .role == "assistant" then
    .content[]? | select(.type == "toolCall") |
    . + {ts:$ts, nested:false, arguments:(.arguments | arguments)}
  elif .role == "toolResult" then
    .toolCallId as $parent | .nestedCalls.calls[]? |
    . + {ts:$ts, nested:true, parentCallId:$parent, arguments:(.arguments | arguments)}
  else empty end;
def warnings:
  .[] | select(.type == "message" and .message.nestedCalls.complete == false) |
  "WARNING: nestedCalls complete=false at \(.id): bounded metadata, not a complete tool trace.";
def callmeta:
  "id=\(.id)" + (if .namespace then " namespace=\(.namespace)" else "" end) +
  (if .nested then " nested parent=\(.parentCallId) status=\(.status) durationMs=\(.durationMs // "unknown") error=\(.error // "none") (metadata only; result body unavailable)" else "" end) +
  (if .arguments == null then " [arguments unavailable]" else "" end);
def resultmap:
  reduce (.[] | select(.type == "message" and .message.role == "toolResult") | .message) as $m
    ({}; .[$m.toolCallId] = $m);
def usage:
  .[] | if .type == "message" and (.message.role == "assistant" or .message.role == "toolResult") then .message.usage
  elif .type == "usage" or .type == "compaction" or .type == "branch_summary" then .usage
  else null end | select(. != null);
def epoch:
  capture("^(?<base>[0-9-]+T[0-9:]+)(?<frac>\\.[0-9]+)?Z$") |
  (.base + "Z" | fromdateiso8601) + (("0" + (.frac // "")) | tonumber);
def path($leaf):
  [.[] | select(.type != "session" and .id != null)] as $entries |
  (reduce $entries[] as $e ({}; if has($e.id) then error("duplicate entry id: " + $e.id) else .[$e.id]=$e end)) as $index |
  def walk($id; $seen):
    if $id == null then []
    elif $seen | index($id) then error("cyclic parentId at " + $id)
    elif $index[$id] == null then error("missing branch entry: " + $id)
    else $index[$id] as $e | walk($e.parentId; $seen + [$id]) + [$e] end;
  walk($leaf; []);
