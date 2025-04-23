# Documentation Update Implementation Plan

## Overview

This plan outlines the steps to update all documentation in the docs/api and docs/guides directories to reflect
changes made in the codebase over the past week. The updates will ensure all new functionality, architectural
changes, and module integrations are accurately documented while adhering to firmo's architectural principles.

It also documents plans for many updates to other files in the firmo project.

## Documentation Updates by Area

### 1. JSDoc Updates

This sub-plan is documented in the docs/firmo/jsdoc_cleanup_plan.md

### 2. Knowledge Files Updates

This sub-plan is documented in the docs/firmo/knowledge_documentation_standardization_plan.md

### 3. Example Files Updates

This sub-plan is documented in the docs/firmo/examples_cleanup_plan.md

### 4. CLAUDE.md file Updates

This sub-plan is documented in the docs/firmo/claude_document_update_plan.md

### 5. Unused files update

These are files that I don't beleive are used, and can be deleted. Can you review these files and
the codebase to verify they aren't used and remove them if needed.

- lib/core/init.lua
- lib/core/fix_expect.lua
- lib/tools/hash/init.lua

### 6. lib/core/module_reset.lua review/audit

Can you review the lib/core/module_reset.lua and it's usage in scripts/runner.lua. I am not sure it is
being used as much as it should. It seems like it gets required and configured, but then never used again.
I am wondering if it needs to be used more, and if any of the test logic in runner.lua or other locations
needs to be moved to the module_reset.lua and then used correctly in the runner.lua

### 7. version_bump.lua and version_check.lua updates

I believe both scripts/version_bump.lua and scripts/version_check.lua do not load lib/core/version.lua correctly.
Can you verify this, and verify their functionality actually does what we want.

### 8. Duplicate JSON modules

We have two JSON modules. One in lib/reporting/json.lua and one in lib/tools/json/init.lua.
The lib/tools/json/init.lua seems like the more complete module. Should we remove the
lib/reporting/json.lua and replace any uses of it in firmo with the lib/tools/json/init.lau module?

### 9. check_assertion_patterns.lua updates

I think the scripts/check_assertion_patterns.lua file is out of date and does not contain checks
for all of our assertions. Can you review it and update it as needed.

## Progress

- [ ] JSDoc Updates
- [ ] Knowledge Files Updates
- [ ] Example Files Updates
- [ ] CLAUDE.md file Updates
- [ ] Unused file update
- [ ] lib/core/module_reset.lua review/audit
- [ ] version_bump.lua and version_check.lua updates
- [ ] Duplicate JSON modules
- [ ] check_assertion_patterns.lua updates
