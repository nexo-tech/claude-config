---
description: Create a reflection note about the current session for content creation and knowledge retention
allowed-tools: Write, Bash(date:*)
argument-hint: [optional-title]
---

# Session Reflection

Create a reflection note about our current Claude Code session. Generate a markdown file in `~/docs/inbox/` with the following structure:

## File naming
- Use format: `YYYY-MM-DD-{slug}.md` where slug is derived from the main topic
- Today's date: !`date +%Y-%m-%d`
- If an argument is provided, use it as the title/slug: $ARGUMENTS

## Note structure

The note should contain these sections:

### 1. Session Summary
A brief 2-3 sentence overview of what was accomplished in this session.

### 2. Challenges & Solutions
- What technical challenges were encountered?
- How were they solved?
- Any debugging insights worth remembering?

### 3. Interesting Discoveries
- Novel approaches or techniques used
- New tools, commands, or patterns learned
- Unexpected findings or behaviors

### 4. Content Ideas (LinkedIn/Twitter)
Generate 2-3 potential post ideas for a software engineering/AI/tech expert audience:
- Each idea should have a hook, key insight, and call-to-action angle
- Focus on practical learnings that provide value to others
- Make them authentic and experience-based, not generic advice

### 5. Key Takeaways
Bullet points of important information to remember for future reference:
- Technical details worth noting
- Gotchas to avoid
- Patterns to replicate

### 6. Tags
Add relevant tags at the bottom for easy searching (e.g., #nix #debugging #ai #devtools)

---

Write the reflection note to `~/docs/inbox/` using the Write tool. Be specific and detailed based on our actual conversation - avoid generic statements. If this session didn't have much technical content, note that and focus on any administrative or organizational work done.
