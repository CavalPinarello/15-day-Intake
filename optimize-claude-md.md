---
allowed-tools: Read, Write, Edit, MultiEdit, Bash(wc:*), Bash(du:*), Grep, Glob, TodoWrite
argument-hint: [optional: max size in KB for CLAUDE.md]
description: Optimize CLAUDE.md size while preserving information
---

We need to optimize CLAUDE.md because it's too large and could affect Claude Code performance. But we need to keep those info in README.md or separated document. Figure out the best strategy. Ultrathink.

## Deep Analysis & Strategy Development:

1. **Analyze current CLAUDE.md**
   2. Check file size and line count
   3. Identify content categories (commands, patterns, conventions, history, etc.)
   4. Assess information criticality (essential vs. nice-to-have)
   5. Evaluate redundancy and outdated information

2. **Develop optimization strategy**
   2. Think deeply about the best structure for documentation
   3. Consider these organization patterns:
	 * Keep only critical, frequently-needed info in CLAUDE.md
	 * Move historical/session logs to `docs/sessions/`
	 * Move command references to `docs/commands.md`
	 * Move coding patterns to `docs/patterns.md`
	 * Move project-specific info to README.md
	 * Create `.claude/templates/` for reusable prompts

3. **Information categorization**
   2. **Essential for CLAUDE.md** (keep):
	 * Current project context
	 * Active conventions and patterns
	 * Critical commands to run (lint, test, build)
	 * Important warnings or gotchas
	 * Quick reference for common tasks
   3. **Move to README.md**:
	 * Project overview and setup
	 * Architecture decisions
	 * Public-facing documentation
   4. **Move to separate docs**:
	 * Session histories → `docs/claude-sessions/`
	 * Detailed patterns → `docs/development-patterns.md`
	 * Command history → `docs/command-log.md`
	 * Learning notes → `docs/learnings.md`

4. **Implement the reorganization**
   2. Create necessary directories and files
   3. Move content to appropriate locations
   4. Update CLAUDE.md with links to moved content
   5. Ensure CLAUDE.md stays under 100 lines (or specified limit)
   6. Add a table of contents for easy navigation

5. **Create index system**
   2. Add a brief index in CLAUDE.md pointing to other docs
   3. Use clear naming conventions for split documents
   4. Maintain cross-references between documents

6. **Optimization targets**
   2. CLAUDE.md: \< 100 lines or ${ARGUMENTS:-50}KB
   3. Focus on actionable, current information
   4. Remove duplicate or outdated content
   5. Use concise language and bullet points

7. **Validate the optimization**
   2. Ensure no critical information is lost
   3. Verify all links and references work
   4. Check that CLAUDE.md loads quickly
   5. Confirm Claude Code can efficiently parse the optimized structure