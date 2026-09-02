#!/bin/bash
# Runs after every Edit/Write tool call.
# Fails immediately if an Android import is found in commonMain — before Claude proceeds further.

INPUT=$(cat)
FILE=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('tool_input', {}).get('file_path', ''))
except:
    print('')
" 2>/dev/null)

# Only check .kt files inside commonMain
if [[ "$FILE" != *"shared/src/commonMain"* ]] || [[ "$FILE" != *.kt ]]; then
  exit 0
fi

if [ ! -f "$FILE" ]; then
  exit 0
fi

VIOLATIONS=$(grep -n "^import android\." "$FILE" 2>/dev/null)
if [ -n "$VIOLATIONS" ]; then
  echo "HOOK VIOLATION — Android import in commonMain: $FILE"
  echo "$VIOLATIONS"
  echo "android.* imports break iOS compilation. Use org.jetbrains.androidx.* equivalents."
  exit 1
fi

exit 0
