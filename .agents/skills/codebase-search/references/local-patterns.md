# Local Search Patterns Reference

Detailed grep, glob, and file-type patterns for local codebase search.

## Table of Contents

- [Find function definitions](#find-function-definitions)
- [Find class definitions](#find-class-definitions)
- [Find usage / callsites](#find-usage--callsites)
- [Find imports / requires](#find-imports--requires)
- [Find configuration](#find-configuration)
- [Find TODOs and error handling](#find-todos-and-error-handling)
- [Search workflow examples](#search-workflow-examples)
- [Search optimization](#search-optimization)
- [Common scenarios](#common-scenarios)

---

## Find function definitions

```bash
# Python
grep -n "def function_name" --type py

# JavaScript
grep -n "function functionName" --type js
grep -n "const functionName = " --type js

# TypeScript
grep -n "function functionName" --type ts
grep -n "export const functionName" --type ts

# Go
grep -n "func functionName" --type go

# Java
grep -n "public.*functionName" --type java
```

## Find class definitions

```bash
# Python
grep -n "class ClassName" --type py

# JavaScript/TypeScript
grep -n "class ClassName" --type js,ts

# Java
grep -n "public class ClassName" --type java

# C++
grep -n "class ClassName" --type cpp
```

## Find usage / callsites

```bash
# Python
grep -n "ClassName(" --type py
grep -n "function_name(" --type py

# JavaScript
grep -n "new ClassName" --type js
grep -n "functionName(" --type js
```

## Find imports / requires

```bash
# Python
grep -n "from.*import.*ModuleName" --type py
grep -n "import.*ModuleName" --type py

# JavaScript
grep -n "import.*from.*module-name" --type js
grep -n "require.*module-name" --type js

# Go
grep -n "import.*package-name" --type go
```

## Find configuration

```bash
# Config files
glob "**/*config*.{json,yaml,yml,toml,ini}"

# Environment variables
grep -n "process\\.env\\." --type js
grep -n "os\\.environ" --type py

# Constants
grep -n "^[A-Z_]+\\s*=" --type py
grep -n "const [A-Z_]+" --type js
```

## Find TODOs and error handling

```bash
# TODOs
grep -n "TODO|FIXME|HACK|XXX" -i

# Python error handling
grep -n "try:|except|raise" --type py

# JavaScript error handling
grep -n "try|catch|throw" --type js

# Go error handling
grep -n "if err != nil" --type go
```

---

## Search workflow examples

### Start broad, then narrow

```
Step 1: Semantic search "How does authentication work?"
Result: Points to auth/ directory

Step 2: Grep in auth/ for specific function
Pattern: "def verify_token"
Result: Found in auth/jwt.py

Step 3: Read the file
File: auth/jwt.py
Result: Understand implementation
```

### Use directory targeting

```
# Start without target (search everywhere)
Query: "Where is user login implemented?"
Target: []

# Refine with specific directory
Query: "Where is login validated?"
Target: ["backend/auth/"]
```

### Combine searches

```
# Find where feature is implemented
Semantic: "user registration flow"

# Find all files involved
Grep: "def register_user"

# Find test files
Glob: "**/*register*test*.py"

# Understand the implementation
Read: registration.py, test_registration.py
```

### Trace data flow

```
1. Find where data is created
   Semantic: "Where is user object created?"

2. Search for variable usage
   Grep: "user\\." with context lines

3. Follow transformations
   Read: Files that modify user

4. Find where it's consumed
   Grep: "user\\." in relevant files
```

### Find all callsites of a function

```
1. Find function definition
   Grep: "def process_payment"
   Result: payments/processor.py:45

2. Find all imports of that module
   Grep: "from payments.processor import"
   Result: Multiple files

3. Find all calls to the function
   Grep: "process_payment\\("
   Result: All callsites

4. Read each callsite for context
   Read: Each file with context
```

### Understand a feature end-to-end

```
1. Find API endpoint
   Semantic: "Where is user registration endpoint?"
   Result: routes/auth.py

2. Trace to controller
   Read: routes/auth.py
   Find: Calls to AuthController.register

3. Trace to service
   Read: controllers/auth.py
   Find: Calls to UserService.create_user

4. Trace to database
   Read: services/user.py
   Find: Database operations

5. Find tests
   Glob: "**/*auth*test*.py"
   Read: Test files for examples
```

### Find related files

```
1. Start with known file
   Example: models/user.py

2. Find imports of this file
   Grep: "from models.user import"

3. Find files this imports
   Read: models/user.py
   Note: Import statements

4. Build dependency graph
   Map: All related files
```

### Impact analysis

```
Before changing function X:

1. Find all callsites
   Grep: "function_name\\("

2. Find all tests
   Grep: "test.*function_name" -i

3. Check related functionality
   Semantic: "What depends on X?"

4. Review each usage
   Read: Each file using function

5. Plan changes
   Document: Impact and required updates
```

---

## Search optimization

### Context lines

```bash
# See surrounding context
grep -n "pattern" -C 5  # 5 lines before and after
grep -n "pattern" -B 3  # 3 lines before
grep -n "pattern" -A 3  # 3 lines after
```

### Case sensitivity

```bash
# Case insensitive
grep -n "pattern" -i

# Case sensitive (default)
grep -n "Pattern"
```

### File type filtering

```bash
# Specific type
grep -n "pattern" --type py

# Multiple types
grep -n "pattern" --type py,js,ts

# Exclude types
grep -n "pattern" --glob "!*.test.js"
```

### Regex patterns

```bash
# Any character: .
grep -n "function.*Name"

# Start of line: ^
grep -n "^class"

# End of line: $
grep -n "TODO$"

# Optional: ?
grep -n "function_name_?()"

# One or more: +
grep -n "[A-Z_]+"

# Zero or more: *
grep -n "import.*"

# Alternatives: |
grep -n "TODO|FIXME"

# Groups: ()
grep -n "(get|set)_user"

# Escape special chars: \
grep -n "function\(\)"
```

---

## Common scenarios

### Understanding a bug

```
1. Find error message
   Grep: "exact error message"

2. Find where it's thrown
   Read: File with error

3. Find what triggers it
   Semantic: "What causes X error?"

4. Find related code
   Grep: Related function names

5. Check tests
   Glob: "**/*test*.py"
   Look: For related test cases
```

### Learning a new codebase

```
1. Find entry point
   Semantic: "Where does the application start?"
   Common files: main.py, index.js, app.py

2. Find main routes/endpoints
   Grep: "route|endpoint|@app\\."

3. Find data models
   Semantic: "Where are data models defined?"
   Common: models/, entities/

4. Find configuration
   Glob: "**/*config*"

5. Read README and docs
   Read: README.md, docs/
```

### Refactoring preparation

```
1. Find all usages
   Grep: "function_to_change"

2. Find tests
   Grep: "test.*function_to_change"

3. Find dependencies
   Semantic: "What does X depend on?"

4. Check imports
   Grep: "from.*import.*X"

5. Document scope
   List: All affected files
```

### Adding a feature

```
1. Find similar features
   Semantic: "How is similar feature implemented?"

2. Find where to add code
   Semantic: "Where should new feature go?"

3. Check patterns
   Read: Similar implementations

4. Find tests to emulate
   Glob: Test files for similar features

5. Check documentation
   Grep: "TODO.*new feature" -i
```
