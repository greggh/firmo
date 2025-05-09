# Integration Plan for `lib/quality` Module

## I. REVIEW AND AUDIT PHASE

### 1. Comprehensive Code Review

- [x] Examine lib/quality/init.lua and lib/quality/level_checkers.lua to understand existing logic, data structures, and any external dependencies.
- [x] Carefully review lib/core/test_definition.lua to decide where to integrate quality.start_test(), quality.end_test(), and quality.track_assertion() (either manual calls inside test blocks or hooking into an existing assertion mechanism).
- [x] Review scripts/runner.lua to see how CLI arguments (e.g., --coverage) are parsed and adapt that code for --quality flags. Identify where to place calls to quality.init(...) and final reporting functions.
- [x] Inspect lib/reporting/init.lua to confirm format_quality and save_quality_report are suitable for generating and persisting the quality analysis.
- [x] Check .firmo-config.lua and lib/core/central_config.lua to see the best approach for default quality configuration (like level, enabled, strict).
- [x] Read documentation files (including knowledge.md files in relevant directories) for up-to-date instructions and note any discrepancies or outdated references.

### 2. Identify Discrepancies

- [x] Compare intended vs. actual behavior for the quality module, referencing data in lib/quality/knowledge.md and user-provided docs. Note any mismatches in APIs or partially implemented features.

### 3. Verify Module Logic

- [x] Confirm that level checker algorithms meet stated requirements.
- [x] Ensure the module’s data flow is consistent with central_config usage (no hard-coded paths or special cases).

## II. IMPLEMENTATION AND INTEGRATION PHASE

### 1. Fix Quality Module Issues

- [x] Resolve any discovered bugs and ensure the algorithms in lib/quality/init.lua and lib/quality/level_checkers.lua correctly handle test data and levels.
- [x] Provide robust error handling and guard against unexpected inputs.

### 2. CLI Argument Handling (scripts/runner.lua)

- [x] Update scripts/runner.lua to parse --quality and optional --quality-level.
- [x] Use central_config.set("quality.enabled", true) or a similar method to enable the module. Initialize the module with quality.init(...) or store values in central_config for later retrieval.

### 3. Test Execution Integration (lib/core/test_definition.lua)

- [x] Where the test blocks are defined (e.g., the it function), add quality.start_test(...) right before the test runs and quality.end_test() afterward. Ensure these calls are conditional on whether quality is enabled.
- [x] Decide on the best approach for quality.track_assertion():
  - [x] Integrate it with existing assertion calls (achieved via dynamic tracking through `lib/assertion/init.lua` calling `quality.track_assertion`).
  - [-] Or rely on the module’s internal file analysis approach if that is more consistent. (Superseded by dynamic tracking)

### 4. Report Generation (scripts/runner.lua)

- [x] After all tests are done, if quality is enabled, call quality.report(format) or quality.save_report(file, format) akin to coverage handling.
- [x] Ensure the --format argument (e.g., --format=html) can be passed for quality output.

### 5. Configuration (.firmo-config.lua & lib/core/central_config.lua)

- [x] Add a default quality config block: quality = { enabled = false, level = 3, strict = false }.
- [x] Confirm that the module respects central_config values instead of hard-coded defaults.

### 6. Reporting Module (lib/reporting/init.lua)

- [x] Double-check that format_quality and save_quality_report properly format the data from the quality module.
- [x] Ensure the final report is user-friendly and matches the expected output style.

## III. VERIFICATION AND DOCUMENTATION PHASE

### 1. Testing

- [x] Run lua test.lua --quality --format=html tests/simple_test.lua to confirm an HTML quality report is generated.
- [x] Test with various --quality-level values to ensure the correct behavior for each level.
- [x] Confirm no errors occur when the --quality flag is absent.
- [x] Test other formats (e.g., JSON, summary) if implemented.

### 2. Documentation Update

- [~] Update JSDoc in all modified files (JSDoc for key files modified during quality module integration and debugging – e.g., `lib/quality/init.lua`, `lib/reporting/init.lua`, `scripts/runner.lua`, `lib/core/central_config.lua`, `lib/tools/json/init.lua`, `lib/assertion/init.lua` – was updated during their respective fixes. A full pass on all other peripherally touched files is pending).
- [x] Refresh Markdowns like docs/api/quality.md, docs/guides/quality.md, lib/quality/knowledge.md. Note any partially implemented features clearly, per the user’s documentation accuracy rules.

### 3. Project Documentation Update

- [x] Consult docs/firmo/plan.md, CLAUDE.md, and docs/firmo/architecture.md. Update them if the integration significantly alters the project plan or architecture details.
- [x] Add references or architectural diagrams as needed to illustrate how the quality module now integrates with the test runner and central_config.

This plan ensures that the quality module is thoroughly audited, correctly integrated, tested, and documented according to the Firmo project's standards.

## Knowledge and Context from Completed Phases

Notes will be added here as phases are completed.

**Phase I, Step 1: Comprehensive Code Review - Summary**

- **`lib/quality/init.lua` & `lib/quality/level_checkers.lua`**:
  - `level_checkers.lua` defines detailed requirements for each quality level (1-5) and evaluation functions.
  - `init.lua` uses `level_checkers.get_level_requirements()` correctly.
  - Potential redundancy: `init.lua` has its own evaluation helpers (e.g., `has_enough_assertions`) which might overlap with `level_checkers.lua`'s more comprehensive `evaluate_test_against_requirements` and its sub-checkers.
- **`lib/core/central_config.lua`**:
  - `quality/init.lua` correctly uses `central_config.get("quality")` and `central_config.set("quality...")`, and registers a change listener. Integration appears sound.
- **`scripts/runner.lua`**:
  - Parses `--quality` and `--quality-level` CLI arguments correctly into `options`.
  - `runner.main` needs modification:
    - To initialize/enable the quality module based on `options.quality` (similar to coverage).
    - To trigger quality report generation after tests run, using `quality.get_report_data()` and then `reporting.auto_save_reports()` or `reporting.save_quality_report()`.
- **`lib/core/test_definition.lua`**:
  - The `M.it` function is the appropriate place to integrate `quality.start_test()` (before test execution) and `quality.end_test()` (after test execution), conditioned on quality module being enabled.
  - Strategy for `quality.track_assertion()` needs decision: manual calls by test authors (invasive), modifying assertion library, or relying on `quality.analyze_file()` (simpler, already partially implemented in `quality/init.lua`).
- **`lib/reporting/init.lua`**:
  - Provides `format_quality(quality_data, format)` and `save_quality_report(file_path, quality_data, format)`.
  - `auto_save_reports` already accepts `quality_data` and has logic to save quality reports for "html" and "json" formats. This simplifies integration in `scripts/runner.lua`.
  - Formatters like HTML, JSON, Summary are primarily designed for coverage data; their ability to meaningfully display quality data from `quality.get_report_data()` needs to be verified/ensured.
- **`.firmo-config.lua`**: Currently does not have a `quality = { ... }` section.
- **Documentation Review (`docs/api/quality.md`, `docs/guides/quality.md`, etc.):**
  - API Namespace Mismatch: `docs/api/quality.md` shows `firmo.quality_options`, `firmo.start_quality()` which is inconsistent with `require("lib.quality")` used by the module itself.
  - `quality.configure` vs. `quality.init`: API docs mention `quality.configure`, but `lib/quality/init.lua` uses `M.init` as its main configuration entry.
  - Custom Rules: Mechanism for `custom_rules` is unclear in documentation versus the structured level requirements in `level_checkers.lua`.
  - CLI Flags: API docs list `--quality-strict`, `--quality-format`, `--quality-output`. `scripts/runner.lua` only has `--quality`, `--quality-level`. Plan is to use common `--format` and `--report-dir`.
- **Formatter Knowledge (`lib/reporting/formatters/knowledge.md`):**
  - Formatters register for specific data types (`coverage`, `quality`, `results`).
  - Formatters for quality will need to handle the data structure from `quality.get_report_data()`.

**Phase I, Step 2: Identify Discrepancies - Summary**

- **API Usage & Namespace:**
  - `docs/api/quality.md` describes `firmo.quality_options`, `firmo.start_quality()`, etc. This is inconsistent with the implemented `require("lib.quality")` pattern.
- **Configuration Entry Point (`quality.configure` vs. `quality.init`):**
  - API docs mention `quality.configure(options)`. `lib/quality/init.lua` uses `M.init(options)` as its effective configuration entry point.
- **Custom Rules Mechanism:**
  - Documentation suggests a flat `quality.custom_rules = { rule = true }` configuration.
  - `lib/quality/level_checkers.lua` uses a structured, hardcoded `requirements` table per level. The link between documented `custom_rules` and the evaluation logic in `level_checkers.lua` is unclear.
- **CLI Flags:**
  - `docs/api/quality.md` lists `--quality-strict`, `--quality-format`, `--quality-output`.
  - `scripts/runner.lua` only parses `--quality`, `--quality-level`. The plan is to use common `--format` and `--report-dir` flags, not quality-specific ones. `--quality-strict` is not currently parsed.
- **`quality.track_assertion()` Strategy:**
  - Docs suggest manual calls (`quality.track_assertion("type")`).
  - `lib/quality/init.lua` implements `track_assertion` for this, but also `analyze_file` for static assertion counting. The integration strategy into `test_definition.lua` is a key decision.
- **Integration of `quality.start_test` and `quality.end_test`:**
  - Intended to be called by runner/test definition system.
  - Currently not called by `lib/core/test_definition.lua` (where `it` blocks are defined). This is a planned integration.
- **Formatter Capability for Quality Data:**
  - `lib/reporting/init.lua` framework supports quality reports (has `format_quality`, `save_quality_report`, `auto_save_reports` handles `quality_data`).
  - Existing formatters (HTML, JSON, Summary) are primarily built for coverage data. They will likely need adaptation or `reporting.format_quality` will need to transform quality data structure to be meaningfully displayed.

**Phase I, Step 3: Verify Module Logic - Summary**

- **Level Checker Algorithms:**
  - The detailed requirements defined in `lib/quality/level_checkers.lua` (via `get_level_requirements` and used by `evaluate_test_against_requirements`) align well with the descriptions of quality levels 1-5 found in `docs/guides/quality.md` and `docs/api/quality.md`.
  - Checks for assertion counts, types, test organization, coverage, and patterns are consistent with documented intentions for each level.
  - `lib/quality/init.lua` correctly delegates the definition of detailed per-level requirements to `lib/quality/level_checkers.lua`.
- **Central Configuration Data Flow:**
  - `lib/quality/init.lua` correctly uses `central_config` for its own settings (`enabled`, `level`, `strict`). It prioritizes options passed to `init()`, then values from `central_config.get("quality")`, then its internal `DEFAULT_CONFIG`.
  - It appropriately registers an `on_change` listener for `quality` settings in `central_config`.
  - For reporting aspects (default format, path templates for quality reports), `lib/quality/init.lua` correctly attempts to read these from the `reporting` section of `central_config`.
  - No hard-coded paths for its own configuration or special-cased configuration logic were observed. The module adheres to using the central configuration system.

**Phase II, Step 1: Fix Quality Module Issues - Summary**

- **Refactored `lib/quality/init.lua`**:
  - Removed redundant internal validation helper functions (`has_enough_assertions`, `has_required_assertion_types`, etc.).
  - Modified `evaluate_test_quality` to correctly use `level_checkers.get_level_checker(level)`, which returns the appropriate `level_checkers.evaluate_level_X` function. These functions in turn call `level_checkers.evaluate_test_against_requirements`, centralizing evaluation logic in `level_checkers.lua`.
  - Ensured `coverage_data` (from `M.config.coverage_data`) is passed to the checker functions within `evaluate_test_quality` to enable coverage-related quality checks.
- **Improved Robustness in `lib/quality/init.lua`**:
  - Added type checking for the `options` parameter in `M.init(options)` to ensure it's a table, defaulting to an empty table if invalid.
  - Added validation for `test_name` in `M.start_test(test_name)` to ensure it's a non-empty string, defaulting to "unnamed_test" if invalid.
  - Added validation for `type_name` in `M.track_assertion(type_name, test_name)` to ensure it's a non-empty string, skipping tracking if invalid.
- **Improved Robustness in `lib/quality/level_checkers.lua`**:
  - Reviewed and confirmed safe access to `test_info` fields (e.g., `test_info.assertion_count or 0`, `test_info.assertion_types or {}`) within its various checker functions.
- Updated JSDoc comments for modified functions to reflect changes.

This step has consolidated the core quality evaluation logic within `lib/quality/level_checkers.lua` and improved the input handling of key public API functions in `lib/quality/init.lua`.

**Phase II, Step 2: CLI Argument Handling (`scripts/runner.lua`) - Summary**

- **Argument Parsing Verified**: Confirmed that `scripts/runner.lua` already correctly parses `--quality` (into `options.quality`) and `--quality-level` (into `options.quality_level`).
- **Quality Module Initialization**:
  - Added logic in `scripts/runner.lua`'s `main` function to initialize the quality module if `options.quality` is true.
  - This involves:
    - Requiring `lib.quality`.
    - Preparing a `quality_config` table setting `enabled = true`.
    - If `options.quality_level` is provided via CLI, it's added to `quality_config.level`.
    - If `options.coverage_instance` exists (coverage is active), it's passed as `quality_config.coverage_data`.
    - Calling `quality_module.init(quality_config)`. This ensures CLI options are prioritized while respecting `central_config` and module defaults.
    - Storing the initialized `quality_module` instance in `options.quality_instance`.
  - The overall success of the test run (`final_success`) now considers `quality_init_success`.
- Updated JSDoc for `RunnerOptions` in `scripts/runner.lua` to include `quality_instance`.

**Phase II, Step 3: Test Execution Integration (`lib/core/test_definition.lua`) - Summary**

- **Integrated `quality.start_test` and `quality.end_test`**:
  - Modified the `M.it` function in `lib/core/test_definition.lua`.
  - `quality_module.start_test(full_test_name)` is now called before the test execution logic (within the `try` block), if the quality module is enabled and the test is not skipped. The `full_test_name` is constructed from the hierarchy of `describe` blocks and the `it` block name.
  - `quality_module.end_test()` is now called after the test execution logic (after the `try` block and its error handling), if the quality module is enabled and the test was not skipped.
  - `lib.quality` is loaded via `try_require` at the top of `lib/core/test_definition.lua`.
- **Strategy for `quality.track_assertion()`**:
  - Decided to rely on the `quality.analyze_file()` method (part of `lib/quality/init.lua`) for assertion tracking for the initial implementation, rather than attempting direct integration with assertion calls within `M.it`. This simplifies the current integration. Direct assertion tracking can be a future enhancement.
- Updated JSDoc for `M.it` to reflect the new quality module hooks.
- **Note on `describe` hooks**: For full accuracy of context like `has_describe` within `quality.start_test`, the quality module would ideally need hooks for `describe` block start/end as well. This is noted as a potential future improvement if `analyze_file` is insufficient.

This step enables the quality module to collect data during the execution of each individual test.

**Phase II, Step 4: Report Generation (`scripts/runner.lua`) - Summary**

- **CLI Format Overrides**:
  - Modified `scripts/runner.lua` to set `central_config.set("reporting.formats_override.quality", options.formats)` if `options.quality` is true and `options.formats` are provided via CLI. This ensures CLI `--format` applies to quality reports.
- **Quality Report Generation Logic**:
  - Added a block in `runner.main` (after coverage reporting) to handle quality report generation if `options.quality`, `options.quality_instance`, and `quality_init_success` are true.
  - This block:
    - Retrieves the `quality_module_instance` and `reporting_module`.
    - Calls `quality_module_instance.get_report_data()` to obtain the quality data.
    - Determines the `report_dir` using the same logic as coverage reports (CLI option or `central_config` or default).
    - Calls `reporting_module.auto_save_reports(nil, quality_data, nil, auto_save_opts_quality)`. The `auto_save_reports` function handles iterating through configured/overridden formats for "quality" and saving them.
    - Includes `pcall` for robustness when getting data and saving reports.
  - A `quality_report_success` flag is maintained and set to `false` if any step fails.
- **Final Success Calculation**:
  - The `final_success` variable in `runner.main` now incorporates `quality_init_success` and `quality_report_success` when `options.quality` is true.

This step enables the generation of quality reports based on CLI flags and central configuration, using the existing reporting infrastructure.

**Phase II, Step 5: Configuration (`.firmo-config.lua` & `lib/core/central_config.lua`) - Summary**

- **Default Configuration Added**:
  - Added a default `quality` configuration block to `.firmo-config.lua`:
  ```lua
  quality = {
    enabled = false, -- Quality validation is disabled by default
    level = 3,       -- Default quality level to aim for if enabled (Comprehensive)
    strict = false,  -- If true, tests might fail if they don't meet the quality level
  },
  ```
- **Central Configuration Respect**:
  - Confirmed (based on Phase I, Step 3 review) that `lib/quality/init.lua` correctly reads from `central_config.get("quality")`, merges with its internal defaults and passed-in options, and registers a change listener. It adheres to the central configuration system for its settings.

This step establishes a default configuration for the quality module within the project's main configuration file.

**Phase II, Step 6: Reporting Module (Formatters) - Summary**

- **`lib/quality/init.lua` Update**:
  - Modified `get_report_data()` to add a `report_type = "quality"` field to the returned data structure, aiding formatters in distinguishing data types.
- **`lib/reporting/formatters/json.lua`**:
  - Updated its `register` function to also register for the "quality" report type (`formatters_registry.quality.json`).
  - Modified its `format` method to check `data.report_type`. If "quality", it directly encodes the provided `quality_data` as JSON.
- **`lib/reporting/formatters/summary.lua`**:
  - Updated its `register` function for the "quality" type (`formatters_registry.quality.summary`).
  - Modified its `format` method to check `data.report_type`.
  - Implemented a new `_format_quality_summary` private method to generate a text-based summary for quality data, including overall level, statistics, assertion types (if detailed), overall issues, and per-test details (if detailed). It uses `lib.quality` for level names.
- **`lib/reporting/formatters/html.lua`**:
  - Updated its `register` function for the "quality" type (`formatters_registry.quality.html`).
  - Modified its `format` method to check `data.report_type`.
  - Implemented a new `_format_quality_html` private method to generate a basic HTML page for quality data, including a title, overall stats, overall issues list, and a simple table for per-test details. It uses `lib.quality` for level names. The HTML styling is basic.
- **Verification of `lib/reporting/init.lua`**:
  - The functions `format_quality` and `save_quality_report` in `lib/reporting/init.lua` were already designed to correctly look up and call formatters registered under the "quality" type. No changes were needed in `lib/reporting/init.lua` itself for this step, beyond ensuring the formatters it calls can handle the data.

This step ensures that the primary report formatters (JSON, Summary, HTML) can now be invoked for quality reports and will produce at least basic, structured output for quality data. The user-friendliness of HTML quality reports is currently basic and can be enhanced later.

## IV. POST-INTEGRATION ENHANCEMENTS AND FIXES

This phase addresses issues and improvements identified after the initial integration and testing of the quality module.

### 1. Improve Assertion Detection

- [x] **Goal**: Shift from static analysis (`analyze_file`) to dynamic tracking for assertion counting and typing by integrating `quality.track_assertion()` directly into the `firmo.expect` assertion mechanism. Static analysis via `analyze_file` will be simplified to focus on structural properties only.
- [x] **Tasks**:
  - [-] Review `analyze_file` and the `patterns` table to identify why assertions in complex tests (e.g., `tests/tools/json_test.lua`) are not being detected. (Superseded by dynamic tracking approach)
  - [-] Expand the `patterns` table or modify the matching logic to correctly identify assertions used within `test_helper.with_error_capture()` blocks. (Superseded by dynamic tracking approach)
  - [-] Improve detection of complex `expect` chains. (Superseded by dynamic tracking approach)
  - [x] Modify `lib/assertion/init.lua` (where `expect` is implemented) to call `quality.track_assertion("assertion_category")` whenever an assertion method is successfully executed.
  - [x] Simplify `lib/quality/init.lua`'s `analyze_file` function to remove assertion counting logic.
  - [x] Ensure `M.start_test` and `M.end_test` in `lib/quality/init.lua` use dynamically tracked assertion data.
- [x] **Notes**:
  - Dynamic assertion tracking was successfully implemented by modifying `lib/assertion/init.lua` to call `quality.track_assertion`.
  - `lib/quality/init.lua`'s `analyze_file` function was simplified to focus on structural analysis, removing static assertion counting.
  - The previously noted issues with `test_helper.with_error_capture` and the `simple_test.lua` assertion counting anomaly were fully resolved during Phase V debugging (see details under Phase V, Step 7).
  - Phase IV, Step 1 is now fully complete.

### 2. Fix JSON Formatter (`lib/reporting/formatters/json.lua`)

- [x] **Goal**: Correct issues in the JSON quality report output. (Completed as of 2025-05-06)
- [x] **Tasks**:
  - [x] Ensure `metadata.tool` correctly shows "Firmo Quality" instead of "Firmo Coverage". (Completed)
  - [x] Ensure the JSON report includes the full data structure from `lib.quality.get_report_data()`, including top-level `level`, `level_name`, and the detailed `tests` table. (Completed)
- [x] **Notes**: This was addressed by modifying `lib/reporting/formatters/json.lua` to correctly structure the output for quality reports. Verified by regenerating and inspecting the JSON report for `tests/simple_test.lua`.

### 3. Implement Unique Report Filenames for Batch Runs

- [x] **Goal**: Enable the generation of uniquely named quality reports when running tests for multiple files in a single command, to prevent overwriting. (Completed)
- [x] **Tasks**:
  - [x] Modify `lib/reporting/init.lua` (`process_template` and `auto_save_reports`) to incorporate the test file's name (as a slug) into generated report filenames for "quality" reports.
  - [x] Modify `scripts/runner.lua` (`run_file` function) to pass the `current_test_file_path` to `auto_save_reports`.
  - [x] Ensure `quality.reset()` is called per file via `firmo.reset()` integration for accurate per-file data.
- [x] **Notes**:
  - Per-file quality reports are now generated with unique names including a slug from the test filename (e.g., `quality-config.json`) when running on a directory. This was verified by `ls` output.
  - The `lib/reporting/init.lua` errors related to `type` parameter shadowing and `get_basename` calls in `process_template` have been resolved.
  - The `unpack` errors in `lib/tools/test_helper/init.lua` (which affected overall test runs) have also been resolved.
  - Timestamps are not currently part of the default generated unique names but can be added by configuring `reporting.templates.quality` or `report_suffix` in `.firmo-config.lua`.

## V. QUALITY MODULE REFINEMENTS AND NEXT STEPS (2025-05-06)

This phase addresses further refinements and outstanding issues identified for the quality module.

### 1. Remove Quality-Specific Code from `tests/simple_test.lua` (User Point 2)

- [x] **Goal**: Ensure `tests/simple_test.lua` does not contain code specific to testing the quality module itself, as it's intended as a generic simple test.
- [x] **Tasks**:
  - [x] Review `tests/simple_test.lua` for any quality-module-specific logic or assertions not intrinsic to a simple pass/fail test.
  - [x] Remove such code if found.
- [x] **Notes**: This test should remain a basic example.

### 2. Fix Assertion Counting Anomaly in `tests/simple_test.lua` (User Point 3)

- [x] **Goal**: Correct the issue where the single assertion in `tests/simple_test.lua` is counted as two assertions ("equality" and "truth"/"other") by the quality module.
- [x] **Tasks**:
  - [x] Investigate the call path from `expect().to.equal()` in `lib/assertion/init.lua` to `quality.track_assertion()` in `lib/quality/init.lua`.
  - [x] Identify why `track_assertion` is effectively called twice or with an incorrect action name ("truth") for this test.
  - [x] Remove the diagnostic mapping for `"truth"` in `action_to_category_map` in `lib/quality/init.lua` if it's confirmed to be an artifact of erroneous calls.
  - [x] Ensure `simple_test.lua` reports 1 "equality" assertion.
- [x] **Notes**: This may involve debugging `ExpectChain` logic or `M.track_assertion`'s argument processing.

### 3. Convert Summary Reports to Markdown Format (User Point 4)

- [x] **Goal**: Change quality summary reports from plain text `.summary` files to human-readable Markdown (`.md`) files.
- [x] **Tasks**:
  - [x] Modify `lib/reporting/formatters/summary.lua`:
    - [x] Change its `EXTENSION` constant from `"summary"` to `"md"`.
    - [x] Update the `_format_quality_summary` method to output valid Markdown syntax for headers, lists, tables, etc.
  - [x] Update `lib/reporting/init.lua`'s `DEFAULT_CONFIG.formats.summary` if necessary (e.g., for content type if that's used).
  - [x] Verify by generating and inspecting a summary report.
- [x] **Notes**: This will improve the readability and usability of summary reports.

### 4. Address "Missing required patterns: should" for `tests/simple_test.lua` (User Point 5)

- [x] **Goal**: Resolve the "Missing required patterns: should" issue reported for `tests/simple_test.lua`.
- [x] **Tasks**:
  - [x] Re-read tests/simple_test.lua to confirm its current name.
  - [x] Review the logic in lib/quality/init.lua (specifically M.start_test) where has_proper_name is determined based on test name patterns "should" and "when". Ensure it correctly parses the full test path string.
  - [x] Review lib/quality/level_checkers.lua (e.g., evaluate_level_2_requirements) to confirm how test_info.has_proper_name is used and if the issue message is generated correctly.
  - [x] Debug and fix the pattern matching or flag propagation if an issue is found.
- [x] **Notes**: This requirement comes from `lib/quality/level_checkers.lua` which checks `test_info.has_proper_name`.

### 5. List All Issues in Reports (Remove Truncation) (User Point 6)

- [x] **Goal**: Modify report formatters to list all quality issues instead of truncating with "...and X more issues."
- [x] **Tasks**:
  - [x] Review `lib/reporting/formatters/summary.lua` (`_format_quality_summary`).
  - [x] Review `lib/reporting/formatters/html.lua` (`_format_quality_html`).
  - [x] Remove or significantly increase any limits on the number of issues displayed (e.g., `max_issues_to_display`).
- [x] **Notes**: Ensures full visibility of all identified quality issues.

### 6. Rephrase "unknown (0)" Quality Level Name (User Point 7)

- [x] **Goal**: Change the display name for Quality Level 0 from "unknown" to something more appropriate like "None" or "Not Assessed".
- [x] **Tasks**:
  - [x] Modify `M.get_level_name` in `lib/quality/init.lua` to return the new preferred term for level 0.
- [x] **Notes**: Improves clarity in reports when no specific quality level is achieved.

### 7. Re-Verify `test_helper.with_error_capture` Fix (User Point 8)

- [x] **Goal**: Confirm that assertion tracking for tests using `test_helper.with_error_capture` (especially when the wrapped function returns `nil, "error_string"`) is working correctly.
- [x] **Tasks**:
  - [x] Assuming `lib/tools/test_helper/init.lua` is now correctly patched on disk, run `tests/tools/json_test.lua` with quality reporting.
  - [x] Inspect the JSON quality report for:
    - [x] "JSON Module / Decoding / should handle invalid JSON gracefully": Expect 3 assertions (`truth`: 2, `equality`: 1).
    - [x] "JSON Module / Encoding / should handle invalid values gracefully": Expect 3 assertions (`truth`: 2, `equality`: 1).
    - [x] "JSON Module / Decoding / should handle invalid input type": Expect 3 assertions (`truth`: 2, `equ  - [x] If assertion counts are still incorrect, re-iterate that this is likely due to file-sync issues preventing the `test_helper.lua` fixes from being active in the execution environment.
- [x] **Notes**: This is a re-verification step for the primary blocker from Phase IV, Step 1.
- [x] **Outcome (2025-05-06)**: Initial re-verification (before extensive debugging of multiple modules) showed that assertion tracking for tests using `test_helper.with_error_capture` was still not fully functional, with problematic tests not tracking all assertions. This was initially suspected to be due to file sync/caching of `lib/tools/test_helper/init.lua`.
- [x] **Final Outcome (2025-05-08)**: After extensive debugging across multiple modules (`test_helper.lua`, `json.lua`, `assertion.lua`, `runner.lua`, `reporting/init.lua`, `central_config.lua`), the persistent issues with `test_helper.with_error_capture` and assertion tracking were fully resolved. The root causes involved:
  - `lib/tools/json/init.lua` not correctly returning `(nil, error_table)` for parser errors. (Fixed)
  - `tests/tools/json_test.lua` incorrectly capturing multiple return values from `test_helper.with_error_capture(...)()`. (Fixed by capturing into a table: `local rets = {test_helper.with_error_capture(...)()}; local res, err = rets[1], rets[2]`).
  - A subtle bug in `lib/assertion/init.lua`'s `pcall_func` for handling arguments to zero-argument assertions like `.to.exist()`. (Fixed by reverting to `unpack(args)`).
- [x] With these fixes, all assertions in the problematic `json_test.lua` tests (e.g., "JSON Module / Decoding / should handle invalid JSON gracefully", "JSON Module / Encoding / should handle invalid values gracefully") are now correctly tracked, with each test reporting 3 assertions as expected.
- [x] Subsequent debugging also resolved the related `exit_code 1` issue that appeared during these tests. The fix involved ensuring `scripts/runner.lua`'s `runner.main` function explicitly returns `final_success` and uses robust boolean comparisons for calculating `final_success`.
- [x] The associated `WARN | central_config | Path must be a string or nil...` messages were also eliminated by modifying `lib/core/central_config.lua`'s internal `log` function to use a bootstrap logger during `central_config`'s own initialization phase, preventing a recursive logging initialization cycle.
- [x] All objectives for Phase V and related debugging are now complete and verified. The system is stable and producing correct exit codes.

## VI. ENHANCE HTML QUALITY REPORT WITH INTERACTIVE EXAMPLES AND UI/UX IMPROVEMENTS (2025-05-09)

This phase aims to improve the HTML quality report by adding interactive "fix-it" examples for common quality issues and enhancing the overall user interface and experience.

_(Steps 1-5 relate to the interactive fix examples feature)_

### 1. Design and Data Structure for Fix Examples

- [x] **Goal**: Determine a clear and consistent way to associate quality issue strings with corresponding code examples and to structure these examples.
- [x] **Tasks**:
  - [x] Task 1.1: Review `lib/quality/level_checkers.lua` to identify common, distinct issue strings.
  - [x] Task 1.2: Create `ISSUE_FIX_EXAMPLES` mapping (Implemented in `lib/reporting/formatters/html.lua`) from issue strings to titles and snippets.
    - [x] A concise title/summary for the fix.
    - [x] A small, generic Lua code snippet demonstrating the fix or correct pattern.
  - [x] Task 1.3: Ensured examples are generic or adaptable.

### 2. Modify HTML Formatter (`lib/reporting/formatters/html.lua`)

- [x] **Goal**: Update the `_format_quality_html` function to include "Show Example" buttons and hidden example content for relevant issues.
- [x] **Tasks**:
  - [x] Task 2.1: In the "Overall Issues" section loop, check if `issue_obj.issue` matches a known issue.
  - [x] Task 2.2: If an example exists, add HTML for an "Expand/Show Example" button.
  - [x] Task 2.3: Add a hidden `div` associated with this button for the code example, pre-formatted in `<pre><code>`.
  - [x] Task 2.4: Used `highlight_lua` for snippets (Note: `highlight_lua` currently only escapes HTML; full syntax highlighting is a future enhancement).
  - [x] Task 2.5: Ensure generated HTML IDs are unique for buttons and example divs (e.g., `fix-example-{{INDEX}}`).

### 3. Add JavaScript for Interactivity

- [x] **Goal**: Implement JavaScript within the HTML report to handle the expand/collapse functionality.
- [x] **Tasks**:
  - [x] Task 3.1: Add a `<script>` section to the HTML template in `_format_quality_html`.
  - [x] Task 3.2: Write JavaScript to add event listeners to "Show Example" buttons.
  - [x] Task 3.3: On button click, toggle the `display` style of the associated example `div`.
  - [x] Task 3.4: Change the button text (e.g., "Show Example" to "Hide Example").
  - [x] Ensured JavaScript is self-contained.

### 4. Update CSS Styling

- [x] **Goal**: Style the new buttons and the expandable example sections.
- [x] **Tasks**:
  - [x] Task 4.1: Add new CSS rules to the `<style>` section in `_format_quality_html`.
  - [x] Task 4.2: Style the "Show Example" button.
  - [x] Task 4.3: Style the hidden example `div` for when it becomes visible.
  - [x] Task 4.4: Style the `<pre><code>` block for code examples.
  - [x] Removed inline styles from HTML elements that are now covered by CSS classes.

### 5. Testing and Refinement

- [x] **Goal**: Verify the new feature works correctly.
- [x] **Tasks**:
  - [x] Task 5.1: Create test file `tests/temp_quality_examples_test.lua` to trigger issues.
  - [x] Task 5.2: Generate HTML quality report and manually verify:
    - [x] Button appearance and placement.
    - [x] Expand/collapse functionality.
    - [x] Correct code examples shown.
    - [x] No layout or styling issues.
  - [x] Task 5.3: Refine based on feedback (Snippet for `before`/`after` was updated).
  - **Note**: Investigated CLI arguments for quality report generation. Current method `lua test.lua --quality <test_file>` works for default HTML. Flags like `--quality-format` and `--quality-output` caused issues with the runner's argument parser, and default config may also be trying to generate unsupported formats (lcov/cobertura) for quality reports. This needs future clarification for optimal CLI usage but does not block the current feature. For now, rely on default HTML report generation or configure via `.firmo-config.lua`.

_(Steps 6-9 relate to new UI/UX enhancements requested on 2025-05-09)_

### 6. Consolidate Existing Work and Prepare for UI Enhancements

- [x] **Goal**: Review the current state and prepare for significant UI additions.
- [x] **Tasks**:
  - [x] Task 6.1: Review current HTML structure and CSS in `lib/reporting/formatters/html.lua`'s `_format_quality_html` to identify integration points for UI enhancements.
  - [x] Task 6.2: Ensure all previous Phase VI changes (interactive examples) are stable and correctly implemented. (User confirmed on 2025-05-09)

### 7. Implement Light/Dark Mode Toggle

- [x] **Goal**: Add a theme toggle to the HTML quality report.
- [x] **Tasks**:
  - [x] Task 7.1: Design CSS variables for theming (light/dark colors for background, text, borders, etc.) in the quality report's HTML.
  - [x] Task 7.2: Add a toggle switch (e.g., using HTML checkbox and CSS, or a simple button) to the top right of the quality report page.
  - [x] Task 7.3: Implement JavaScript to switch theme classes on the `<body>` (or root) element and save user preference (e.g., in `localStorage`).
  - [x] Task 7.4: Update existing CSS and add new CSS rules to respect the theme variables. (Done as part of 7.1 & 7.3)
  - [x] Task 7.5: Test theme switching thoroughly. (User confirmed; Moon icon visibility refined based on feedback).

### 8. Implement Responsive Pie Chart for Summary Statistics

- [x] **Goal**: Add a visual representation of key summary statistics.
- [x] **Tasks**:
  - [x] Task 8.1: Research lightweight JavaScript charting libraries suitable for embedding (e.g., Chart.js, D3.js snippets, or a simple SVG-based solution if possible) or consider a pure CSS pie chart. Select a method. (Pure CSS conic-gradient selected).
  - [x] Task 8.2: Modify `_format_quality_html` to include a placeholder `div` for the chart next to (or near) the summary statistics.
  - [x] Task 8.3: Add JavaScript to extract "Tests Analyzed" and "Tests Meeting Configured Level" from the `quality_data.summary` and render the pie chart.
  - [x] Task 8.4: Implement CSS for responsive behavior. (Done as part of 8.2).
  - [x] Task 8.5: Test chart rendering and responsiveness. (User confirmed).

### 9. Implement Syntax Highlighting for Lua Examples

- [x] **Goal**: Improve readability of Lua code snippets in the "Show Example" sections.
- [x] **Tasks**:
  - [x] Task 9.1: Choose a lightweight JavaScript syntax highlighting library (e.g., Prism.js, Highlight.js) or implement a basic Lua pattern-based highlighter. Select a method. (Conceptual Prism.js approach selected).
  - [x] Task 9.2: If using an external library, determine how to include its necessary JS/CSS assets (embedding is preferred for self-contained reports). (Conceptual assets prepared and embedded).
  - [x] Task 9.3: Modify `_format_quality_html` (remove `highlight_lua`, add class to `<code>`).
  - [x] Task 9.4: Add JavaScript to initialize the syntax highlighter on the relevant code blocks after the page loads.
  - [x] Task 9.5: Test syntax highlighting on various Lua example snippets. (User confirmed conceptual highlighting works. Current implementation is a conceptual placeholder for Prism.js; a full Prism.js integration is a future enhancement).

### 10. Documentation Update

- [x] **Goal**: Document all new features from Phase VI (interactive examples and UI enhancements).
  - [x] **Tasks**:
  - [x] Update `docs/guides/quality.md` to mention the interactive examples and any new UI features (theme toggle, pie chart, syntax highlighting).
  - [x] Consider adding notes to `lib/quality/knowledge.md` if relevant insights were gained. (Added details on HTML report features and correct CLI usage for quality reports).
  - [x] Update JSDoc in `lib/reporting/formatters/html.lua` for `_format_quality_html` and any new helper functions or major CSS/JS structures.

## VII. ADVANCED QUALITY CHECKS (Mock Restoration & Describe Block Completeness) (Future)

This phase introduces more sophisticated quality checks focused on test hygiene and structure.

### 1. Enhance Data Collection for Mock/Spy Tracking

- [ ] **Goal**: Enable the quality module to track the lifecycle of spies to ensure they are properly restored.
- [ ] **Tasks**:
  - [ ] Task 1.1: Modify `lib/quality/init.lua`:
    - [ ] Add internal data structures to track active spies (e.g., `M.active_spies`).
    - [ ] Add `M.track_spy_created(spy_id)` and `M.track_spy_restored(spy_id)`.
    - [ ] Update `M.start_test()` to reset active spy tracking for the current test.
    - [ ] Update `M.end_test()` to check for unrestored spies and record this (e.g., in `test_info.unrestored_spies_found`).
  - [ ] Task 1.2: Modify `lib/mocks/spy.lua` (or its equivalent, where `firmo.spy.on` is defined):
    - [ ] Call `quality.track_spy_created()` upon spy creation.
    - [ ] Call `quality.track_spy_restored()` when a spy's `restore()` method is invoked.
    - [ ] Ensure these calls are conditional on the quality module being enabled.
  - [ ] Task 1.3: Update `QualityTestInfo` definition (e.g., in `lib/quality/level_checkers.lua` JSDoc and relevant structures) to include `unrestored_spies_found: boolean`.

### 2. Implement Mock Restoration Check in `level_checkers.lua`

- [ ] **Goal**: Add a new quality check for mock/spy restoration and integrate it into relevant quality levels.
- [ ] **Tasks**:
  - [ ] Task 2.1: In `lib/quality/level_checkers.lua`, create `M.check_mock_restoration(test_info, requirements)` which checks `test_info.unrestored_spies_found`.
  - [ ] Task 2.2: Update `QualityRequirements` definition (in `level_checkers.lua` JSDoc) to include `test_organization.require_mock_restoration?: boolean`.
  - [ ] Task 2.3: Add `require_mock_restoration = true` to `test_organization` requirements for appropriate quality levels (e.g., Level 3+ or 4+).
  - [ ] Task 2.4: Integrate the call to `M.check_mock_restoration` into `M.evaluate_test_against_requirements` (e.g., as part of organization checks).

### 3. Enhance Data Collection for `describe` Block Completeness

- [ ] **Goal**: Enable the quality module to track `describe` blocks and identify if they are empty.
- [ ] **Tasks**:
  - [ ] Task 3.1: Modify `lib/quality/init.lua`:
    - [ ] Add internal state to track current `describe` context (e.g., `M.current_describe_info = { name = "", it_blocks_found = 0, file_path = "" }`).
    - [ ] Add `M.start_describe(describe_name, file_path)`.
    - [ ] Add `M.end_describe(describe_name, file_path)` to check `it_blocks_found` and record an issue if zero.
    - [ ] Update `M.start_test()` to increment `it_blocks_found` for the current describe context.
  - [ ] Task 3.2: Modify `lib/core/test_definition.lua`:
    - [ ] In `M.describe`, call `quality.start_describe(name, current_file_path)` and `quality.end_describe(name, current_file_path)`.
    - [ ] Ensure calls are conditional on quality module enablement.

### 4. Implement Empty `describe` Block Check

- [ ] **Goal**: Report empty `describe` blocks as a global quality issue.
- [ ] **Tasks**:
  - [ ] Task 4.1: Core logic in `quality.end_describe()` (from Task 3.1) to add an issue to `M.overall_issues` (e.g., `{ file = file_path, scope = describe_name, issue = "Describe block is empty" }`).
  - [ ] Task 4.2: Ensure this new type of global issue is correctly displayed in all relevant report formats (HTML, Summary/Markdown, JSON).

### 5. Testing and Refinement

- [ ] **Goal**: Verify the new checks function correctly and integrate smoothly.
- [ ] **Tasks**:
  - [ ] Task 5.1: Create/modify test files to specifically trigger unrestored spies and empty `describe` blocks.
  - [ ] Task 5.2: Create/modify test files that correctly restore spies and have non-empty `describe` blocks.
  - [ ] Task 5.3: Run tests with various quality levels; verify reports and quality assessments for the new checks.
  - [ ] Task 5.4: Refine issue messages and checker logic as needed.

### 6. Documentation Update

- [ ] **Goal**: Document the new quality checks and any related API/data structure changes.
- [ ] **Tasks**:
  - [ ] Task 6.1: Update JSDoc in `lib/quality/init.lua`, `lib/quality/level_checkers.lua`.
  - [ ] Task 6.2: Update JSDoc in `lib/mocks/spy.lua`, `lib/core/test_definition.lua` for new hooks.
  - [ ] Task 6.3: Update `docs/guides/quality.md` to explain the new checks.
  - [ ] Task 6.4: Update `lib/quality/knowledge.md` with details on new data collection and checks.
  - [ ] Task 6.5: Update this plan file (`docs/firmo/quality_module_integration_plan.md`) with progress for Phase VII.
