# Getting Started with Repomix

## What We're Doing

We're going to pack a repository into a single file that an LLM can easily analyze. This is our first step in understanding how Repomix works.

## Why

When working with large codebases, LLMs need context. Repomix creates a structured, AI-friendly snapshot of an entire repository in one file.

## Step 1: Install Repomix

```bash
# Via npm
npm install -g repomix

# Or via Homebrew (if available)
brew install repomix
```

## Step 2: Pack Your First Repo

Let's start with a simple example - packing the current directory:

```bash
cd /path/to/your/repo
repomix --output analysis.xml
```

This creates `analysis.xml` with the entire repository structure and code.

## What Happens

Repomix:
1. Scans all files in the repository
2. Respects `.gitignore` patterns
3. Organizes content by file structure
4. Outputs in XML format (default) or Markdown/JSON

## Our First Real Use

When we analyzed `toolchain-2026` to identify migration candidates, we ran:

```bash
cd /Users/me/tools/toolchain-2026
repomix --output repomix-analysis.xml
```

This gave us an 11MB XML file containing the entire repository structure, which we then analyzed to identify:
- Data files that should move to data repos
- Scripts that belong in devx-companion
- Code that should stay in toolchain-2026

## Next Steps

- [01-pack-local-repo.md](01-pack-local-repo.md) - More detailed local packing
- [04-migration-analysis.md](04-migration-analysis.md) - Using Repomix for migration planning

