# Plan for Extending Async Testing in Firmo

## Phase 1: Async Function Implementation

1. **Review Existing Async Module**:

   - Examine `lib/async/init.lua` to understand current async implementation
   - Analyze test patterns from synchronous functions in `test_definition.lua` and `firmo.lua`

2. **Implement New Async Functions**:

   - Create `fit_async` following same pattern as `it_async` but with focus behavior
   - Create `xit_async` following same pattern as `it_async` but with skip behavior
   - Implement nested `describe_async` suite with proper context propagation
   - Add focused/skipped variants (`fdescribe_async`, `xdescribe_async`)

3. **Integrate with Firmo Core**:
   - Expose new functions in `lib/firmo.lua` following existing patterns
   - Ensure backwards compatibility with current async test usage
   - Add proper JSDoc documentation for all new functions

## Phase 2: Testing Infrastructure

4. **Create Test Suite**:

   - Basic functionality tests for each new async function
   - Focus/exclusion behavior verification tests
   - Timeout handling tests
   - Parent/child relationship tests for describe blocks
   - Error handling and reporting tests

5. **Implement Test Helpers**:
   - Create reusable test utilities for async assertions in the test_helper module
   - Set up dedicated test files for new functionality

## Phase 3: Documentation & Examples

6. **Update Documentation**:

   - Add API reference in `docs/api/async.md` for each new function
   - Update `docs/guides/async.md` with usage patterns and examples

7. **Create Examples**:

   - Basic async test examples in `/examples/basic_async.lua`
   - Focus/skip patterns in `/examples/async_focus_skip.lua`
   - Nested describe scenarios in `/examples/nested_async.lua`
   - Complex async patterns in `/examples/advanced_async.lua`

8. **Update Architecture Docs**:
   - Add notes about new async capabilities to `docs/firmo/architecture.md`
   - Update `docs/firmo/plan.md` and mark this plan as complete

## Phase 4: Quality Assurance

9. **Code Review**:
   - Verify single responsibility principle is maintained
   - Check for proper polymorphism usage
   - Ensure consistent data structures at boundaries
