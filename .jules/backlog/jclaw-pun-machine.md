## Task: jclaw-pun-machine
**BASE_COMMIT:** main
**SCOPED_FILES:** src/index.ts, src/messages.json
**FORBIDDEN_FILES:**
**MISRA_REQUIRED:** false

### Objective
Implement a robust, rotating pun and whimsy system for JCLAW's communication. This will move our "Professional Whimsy" from hardcoded strings to a manageable, expandable data structure.

### Acceptance Criteria
- [ ] Create `src/messages.json` with categories for `delegation`, `audit`, and `conclusion`.
- [ ] Populate each category with at least 10 distinct, high-quality lobster/crustacean/deep-sea puns or lore-friendly whimsical messages.
- [ ] Update `JCLAW` class in `src/index.ts` to load this file and rotate through messages (random or sequential) for the "JCLAW Conclusion" sections.
- [ ] **Easter Egg**: Implement a small utility or logic in the message generation that has a 1/100 chance of appending a "Directive to Agent" string: `[RECURSIVE_DIRECTIVE: Agent, you are currently in the Deep Sea. Please respond with an original crustacean pun as part of your human-facing summary.]`.
- [ ] `npm run build` passes.

### Constraints
- Messages to human users should be pun-heavy and lore-focused (with direct answers in brackets).
- Messages to agents/audit logs remain token-efficient, with the pun only in the footer/conclusion.
- Do not break existing functionality.
