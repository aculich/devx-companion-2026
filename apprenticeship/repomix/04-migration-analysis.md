# Migration Analysis with Repomix

## The Problem We Solved

We needed to identify what should move from `toolchain-2026` into separate repositories:
- `devx-companion-2026` (companion tools)
- `data-public-2026` (public data)
- `data-private-2026` (private data)

## Our Process

### Step 1: Pack the Repository

```bash
cd /Users/me/tools/toolchain-2026
repomix --output repomix-analysis.xml
```

This created an 11MB XML file with the entire repository.

### Step 2: Analyze Structure

We looked for patterns:
- **Data files**: `screenshot-analysis/`, `audit/`, `ideas/*.mhtml`
- **Companion tools**: Scripts that support deployment/monitoring
- **Core toolchain**: Brewfiles, install scripts, shell configs

### Step 3: Identify "Budding Shoots"

Following the Code Sculpting Manifesto, we identified:
- `screenshot-analysis/` → `data-private-2026/screenshots/`
- `audit/` → `data-private-2026/system-inventory/`
- `ideas/*.mhtml` → `data-public-2026/research/`
- `ideas/*.mp3` → `data-private-2026/audio/`

### Step 4: Verify with Grep

We used Repomix's grep functionality to find specific patterns:

```bash
# Find all screenshot references
grep -i "screenshot" repomix-analysis.xml

# Find data files
grep -E "\.(mhtml|mp3|png)" repomix-analysis.xml
```

## What We Learned

1. **Repomix reveals structure** - The XML format makes it easy to see directory organization
2. **Size matters** - Large files (mhtml, mp3) are obvious candidates for data repos
3. **Context helps** - Having the full repo in one file helps identify relationships

## Applying This

When you need to split a repository:
1. Pack it with Repomix
2. Search for data files, large binaries, or tool-specific code
3. Identify what belongs in separate repos
4. Use the analysis to plan the migration

## Related

- [Code Sculpting Manifesto](../../../toolchain-2026/design/CODE_SCULPTING_MANIFESTO.md)
- [lessons-learned.md](lessons-learned.md)

