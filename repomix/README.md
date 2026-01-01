# Repomix Integration

Integration with [Repomix](https://repomix.com/) for AI-optimized codebase snapshots.

## What is Repomix?

Repomix packs your entire repository into a single, AI-friendly file. Perfect for feeding codebases to Large Language Models (LLMs) like Claude, ChatGPT, Gemini, and more.

## Usage

### CLI Usage

```bash
# Generate compressed code context for LLM
npx repomix@latest --compress --style xml --output repomix-output.xml

# Or use local config
npx repomix@latest --config repomix/config.json
```

### MCP Server (Cursor/Claude)

Repomix is available as an MCP server in Cursor. Use the following tools:

- `mcp_repomix_pack_codebase` - Package local code directory
- `mcp_repomix_pack_remote_repository` - Fetch and package GitHub repo
- `mcp_repomix_attach_packed_output` - Attach existing packed output
- `mcp_repomix_read_repomix_output` - Read packed output
- `mcp_repomix_grep_repomix_output` - Search packed output

### Configuration

See `config.json` for Repomix configuration including:
- Output style (xml, markdown, json, plain)
- Compression settings
- Include/exclude patterns

## Use Cases

1. **Code Review**: Package codebase for comprehensive AI review
2. **Refactoring**: Get full context for refactoring decisions
3. **Documentation**: Generate documentation from codebase
4. **Learning**: Analyze codebases for patterns and best practices
5. **Sentinel Analysis**: Package codebase for sentinel LLM analysis

## Related

- [Repomix Documentation](https://repomix.com/guide/)
- [Repomix GitHub](https://github.com/yamadashy/repomix)

