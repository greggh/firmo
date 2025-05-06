# Documentation Update Implementation Plan

## Overview

This plan outlines the steps to update all documentation in the docs/api and docs/guides directories to reflect
changes made in the codebase over the past week. The updates will ensure all new functionality, architectural
changes, and module integrations are accurately documented while adhering to firmo's architectural principles.

It also documents plans for many updates to other files in the firmo project.

After work is done on a plan, please mark it as complete in the list at the bottom of this file.

## Planning Documents Practice

This document exemplifies the project's practice of creating dedicated plan documents within the `docs/firmo/` directory for significant refactoring efforts, large feature implementations, or complex bug fixes. These documents serve to:

*   Outline clear goals and scope.
*   Detail the chosen approach and alternatives considered.
*   Record key decisions and rationale.
*   Track progress and status.
*   Facilitate knowledge sharing and collaboration.

Maintaining such plans helps ensure structured development and provides valuable historical context for major changes.

## Documentation Updates by Area

### 1. JSDoc Updates

This sub-plan is documented in the docs/firmo/jsdoc_cleanup_plan.md

### 2. Knowledge Files Updates

This sub-plan is documented in the docs/firmo/knowledge_documentation_standardization_plan.md

### 3. Example Files Updates

This sub-plan is documented in the docs/firmo/examples_cleanup_plan.md

### 4. CLAUDE.md file Updates

This sub-plan is documented in the docs/firmo/claude_document_update_plan.md

### 5. lib/mocking/stub.lua file Updates

~~This file has many duplicate function definitions and we don't know which are the good ones.~~
~~Can you review this file and remove the duplicate functions based on which one is correct.~~
Reviewed `lib/mocking/stub.lua`. No duplicate top-level function definitions were found. Methods like `.returns()` are defined dynamically within constructor functions (`stub.new`, `stub.on`), which is not harmful duplication. The unimplemented `stub.sequence` is noted. No code removal needed.

### 6. Unused files update

These are files that I don't beleive are used, and can be deleted. Can you review these files and
the codebase to verify they aren't used and remove them if needed.

- lib/core/init.lua
- lib/core/fix_expect.lua
- lib/tools/hash/init.lua

  **Outcome:**
  `lib/core/init.lua`: Removed (unused).
  `lib/core/fix_expect.lua`: Removed (unused and obsolete).
  `lib/tools/hash/init.lua`: Kept (used in examples/tests).

### 7. lib/core/module_reset.lua review/audit

Can you review the lib/core/module_reset.lua and it's usage in scripts/runner.lua. I am not sure it is
being used as much as it should. It seems like it gets required and configured, but then never used again.
I am wondering if it needs to be used more, and if any of the test logic in runner.lua or other locations
needs to be moved to the module_reset.lua and then used correctly in the runner.lua

**Findings:**

- Reviewed `lib/core/module_reset.lua` and usage in `scripts/runner.lua`.
- The module _is_ correctly registered via `register_with_firmo` in `runner.run_all`.
- The enhanced `firmo.reset` (which includes `module_reset.reset_all`) is called _before each file_ within `runner.run_all`, providing **file-level isolation** when running multiple files (e.g., from a directory).
- The `runner.run_file` function (used for single file execution) does _not_ trigger the module reset. This is acceptable as single-file runs typically occur in fresh processes, making inter-file isolation less critical in that context. Per-test isolation _within_ a file is not the default goal of this integration point.
- No obvious redundant logic found in `runner.lua`; the integration provides the intended file-level isolation.
- Conclusion: Current usage is appropriate for its purpose. No code changes deemed necessary from this review.

### 8. version_bump.lua and version_check.lua updates

I believe both scripts/version_bump.lua and scripts/version_check.lua do not load lib/core/version.lua correctly.
Can you verify this, and verify their functionality actually does what we want.

### 9. Duplicate JSON modules

We have two JSON modules. One in lib/reporting/json.lua and one in lib/tools/json/init.lua.
The lib/tools/json/init.lua seems like the more complete module. Should we remove the
lib/reporting/json.lua and replace any uses of it in firmo with the lib/tools/json/init.lau module?

### 10. add fit_async, xit_async, describe_async, fdescribe_async, xdescribe_async

This sub-plan is documented in the docs/firmo/add_more_async_functions_plan.md

### 11. Review pcall and xpcall usage in the codebase

This sub-plan is documented in the docs/firmo/pcall_update_plan_initial_review.md

## Progress

- [x] JSDoc Updates
- [x] Knowledge Files Updates
- [x] Example Files Updates <!-- User: Please verify if 'Example Files Updates' are truly complete. -->
- [x] CLAUDE.md file Updates
- [x] lib/mocking/stub.lua file updates
- [x] Unused file update
- [x] lib/core/module_reset.lua review/audit
- [x] version_bump.lua and version_check.lua updates
- [x] Duplicate JSON modules
- [x] add fit_async, xit_async, describe_async, fdescribe_async, xdescribe_async
- [x] Review pcall and xpcall usage in the codebase
