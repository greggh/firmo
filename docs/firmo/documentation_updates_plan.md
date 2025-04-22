# API and Guides Documentation Update Execution Plan

## Phase 1: Documentation Audit

1. Review project architecture docs (docs/firmo/architecture.md) to understand module relationships
2. Each documentation file is listed below in the "List of files to review for updates" section
3. For each documentation file:
   - Validate against current implementation
   - Check configuration references point to .firmo-config.lua
   - Ensure all table operations use `#` operator
4. Create audit report with needed updates

## Phase 2: Updates & Creation

1. Update API documentation:
   - Add missing JSDoc for new methods, remember the standards in docs/firmo/jsdoc_standards.md
   - Remove deprecated functionality
   - Update examples using central_config
   - Update all code and API information to match the current implementation
2. Update guides:
   - Add examples for new features
   - Ensure consistent terminology
   - Fix broken cross-references
   - Update all code and information to match the current implementation
3. Add changelog entries
4. Update the list of files below, mark finished files as done.

## Phase 3: Quality Assurance

1. Automated validation:
   - Check all links
   - Verify test commands
   - Validate terminology consistency
   - Confirm against source code
   - Check for special cases

## Phase 4: Maintenance Setup

1. Update CONTRIBUTING.md with:
   - Documentation standards

## List of files to review for updates

- [ ] docs/api/assertion.md
- [ ] docs/api/async.md
- [ ] docs/api/benchmark.md
- [ ] docs/api/central_config.md
- [ ] docs/api/cli.md
- [ ] docs/api/codefix.md
- [ ] docs/api/core.md
- [ ] docs/api/coverage.md
- [ ] docs/api/discover.md
- [ ] docs/api/discovery.md
- [ ] docs/api/error_handling.md
- [ ] docs/api/filesystem.md
- [ ] docs/api/filtering.md
- [ ] docs/api/focus.md
- [ ] docs/api/hash.md
- [ ] docs/api/interactive.md
- [ ] docs/api/json.md
- [ ] docs/api/knowledge.md
- [ ] docs/api/logging.md
- [ ] docs/api/logging_components.md
- [ ] docs/api/markdown.md
- [ ] docs/api/mocking.md
- [ ] docs/api/module_reset.md
- [ ] docs/api/output.md
- [ ] docs/api/parallel.md
- [ ] docs/api/parser.md
- [ ] docs/api/quality.md
- [ ] docs/api/reporting.md
- [ ] docs/api/temp_file.md
- [ ] docs/api/test_helper.md
- [ ] docs/api/test_runner.md
- [ ] docs/api/watcher.md
- [ ] docs/api/formatters/cobertura_formatter.md
- [ ] docs/api/formatters/csv_formatter.md
- [ ] docs/api/formatters/html_formatter.md
- [ ] docs/api/formatters/json_formatter.md
- [ ] docs/api/formatters/junit_formatter.md
- [ ] docs/api/formatters/lcov_formatter.md
- [ ] docs/api/formatters/summary_formatter.md
- [ ] docs/api/formatters/tap_formatter.md
- [ ] docs/guides/assertion.md
- [ ] docs/guides/async.md
- [ ] docs/guides/benchmark.md
- [ ] docs/guides/central_config.md
- [ ] docs/guides/ci_integration.md
- [ ] docs/guides/cli.md
- [ ] docs/guides/codefix.md
- [ ] docs/guides/core.md
- [ ] docs/guides/coverage.md
- [ ] docs/guides/discover.md
- [ ] docs/guides/error_handling.md
- [ ] docs/guides/filesystem.md
- [ ] docs/guides/filtering.md
- [ ] docs/guides/focus.md
- [ ] docs/guides/getting-started.md
- [ ] docs/guides/hash.md
- [ ] docs/guides/interactive.md
- [ ] docs/guides/json.md
- [ ] docs/guides/knowledge.md
- [ ] docs/guides/logging.md
- [ ] docs/guides/logging_components.md
- [ ] docs/guides/markdown.md
- [ ] docs/guides/mocking.md
- [ ] docs/guides/module_reset.md
- [ ] docs/guides/output.md
- [ ] docs/guides/parallel.md
- [ ] docs/guides/parser.md
- [ ] docs/guides/quality.md
- [ ] docs/guides/reporting.md
- [ ] docs/guides/temp_file.md
- [ ] docs/guides/test_helper.md
- [ ] docs/guides/test_runner.md
- [ ] docs/guides/watcher.md
