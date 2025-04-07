# Coverage Repair Session Start Prompt

I'm continuing work on the firmo coverage module repair project. Please read CLAUDE.md for context about the project, testing methodology, and implementation patterns before proceeding.

## PRE-AUTHORIZATION FOR AUTONOMOUS OPERATION

I EXPLICITLY AUTHORIZE YOU TO:

1. Read any files in the firmo project WITHOUT asking permission
2. Use the LS command to explore directories WITHOUT asking permission
3. Update documentation files in the docs/coverage_repair directory WITHOUT asking permission
4. View, analyze, and understand code in any firmo files WITHOUT asking permission
5. Update test files in the tests directory WITHOUT asking permission
6. Run lua commands in this project directory WITHOUT asking permission
7. Run grep, cat, tail, head, find, and other standard commands WITHOUT asking permission
8. Run test commands WITHOUT asking permission

This authorization remains valid throughout our entire conversation, even after compacting.

## Current Focus

Based on our consolidated plan, we are currently focusing on these tasks in order:

1. **Assertion Module Extraction**

   - Extract assertion functions into a standalone module
   - Implement consistent error handling for assertions
   - Resolve circular dependencies

2. **Coverage/init.lua Error Handling Rewrite**

   - Implement comprehensive error handling throughout
   - Ensure proper data validation
   - Fix report generation issues
   - Improve file tracking

3. **Error Handling Test Suite**
   - Create comprehensive tests for error scenarios
   - Verify proper error propagation
   - Test recovery mechanisms

## Documentation Responsibilities

As we work on the coverage module repair, you MUST:

1. **Create session summaries in the `/docs/coverage_repair/session_summaries/` directory**

   - Name session summaries as `session_summary_YYYY-MM-DD_topic.md` (use current date)
   - Document key changes, decisions, and findings

2. **Update consolidated_plan.md with progress**

   - Mark completed tasks with ✓
   - Add implementation notes for completed work

3. **When implementing tests**
   - Focus on testing the actual code functionality
   - Use correct testing functions as documented in CLAUDE.md
   - Fix root causes of test failures, not symptoms
   - Ensure test isolation and independence

Please read the following key documents for the current task:

1. `/home/gregg/Projects/lua-library/firmo/docs/coverage_repair/consolidated_plan.md`
2. `/home/gregg/Projects/lua-library/firmo/docs/coverage_repair/assertion_extraction_plan.md`
3. `/home/gregg/Projects/lua-library/firmo/docs/coverage_repair/error_handling_test_plan.md`

Let's continue work on the current task from where we left off.
