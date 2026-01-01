# Exercise: Identify Budding Shoots

## Objective

Use Repomix to identify code or data in a repository that should be moved to a separate repository.

## Steps

1. **Pack a repository**:
   ```bash
   cd /path/to/repo
   repomix --output analysis.xml
   ```

2. **Analyze the output**:
   - Look for large files
   - Identify data directories
   - Find tool-specific code

3. **Create a migration plan**:
   - What should move?
   - Where should it go?
   - Why?

4. **Document your findings**:
   - Create a migration plan
   - List files to move
   - Explain the reasoning

## Example

We identified:
- `screenshot-analysis/` → `data-private-2026/screenshots/`
- `audit/` → `data-private-2026/system-inventory/`
- `ideas/*.mhtml` → `data-public-2026/research/`

## Reflection

After completing the exercise, consider:
- What patterns did you notice?
- What was easy to identify?
- What was surprising?
- How would you improve the process?

