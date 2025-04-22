# Revised CLAUDE.md Update Plan

## Phase 1: Research and Analysis

1. Gather current project information:
   - Review all test directories for structure consistency
   - Examine assertion implementation in `/home/gregg/Projects/lua-library/firmo/lib/assertion/`
   - Study coverage module in `/home/gregg/Projects/lua-library/firmo/lib/coverage/`
2. Compare with current `/home/gregg/Projects/lua-library/firmo/CLAUDE.md` content
3. Create precise change list:
   - New expect-style assertions to document
   - Verified directory structures
   - Current component architecture including coverage implementation

## Phase 2: Content Updates

1. Assertions Documentation:

   - Audit all expect-style assertion patterns
   - Update "Complete Assertion Pattern Mapping" and "Extended Assertions" with proper firmo syntax
   - Document all assertion types following single responsibility principle

2. Directory Structures:

   - Map current test directory `/home/gregg/Projects/lua-library/firmo/tests/` hierarchy
   - Update "Test Directory Structure" with correct paths

3. Project Structure:

   - Map the entire project and its sub-directories `/home/gregg/Projects/lua-library/firmo/`
   - Update the directory map in the "Project Structure" section to match the current directories

4. Coverage Module:
   - Under the "Coverage Module Architecture" section there is a sub-section titled "Components", it has
     6 items in a list with bulletted lists under them.
   - This "Components" section was written before we replaced the instrumentation-based system with the debug hook system.
   - This whole "Components" section needs to be re-written to match the new debug hook based system.

## Phase 3: Quality Assurance

1. Automated checks:
   - Validate all paths against actual project structure
   - Verify assertion documentation matches source implementations

## Phase 4: Finalization

1. Update changelog following project standards

Important Notes:

- All documentation must reflect debug hook based coverage (not instrumentation-based)
- Maintain single responsibility principle in all documented components
- Use central_config system for settings examples
- Keep all diagnostic disable comments if present
