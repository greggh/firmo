# Library Knowledge

## Module Organization
- assertion.lua: Standalone assertion module
- core/: Core utilities (type checking, fix_expect, version)
- async/: Asynchronous testing functionality
- coverage/: Code coverage tracking
- quality/: Quality validation
- reporting/: Test reporting system
- tools/: Utilities and helpers
- mocking/: Mocking system (spy, stub, mock)

## Critical Rules
- NEVER import coverage module in test files
- ALWAYS use central_config for settings
- NEVER create custom configuration systems
- NEVER add special case code
- ALWAYS handle errors properly

## Error Handling Pattern
- Return nil, error_object for failures
- Use error_handler.try for risky operations
- Validate all input parameters
- Include context in error objects
- Clean up resources in error cases

## Module Guidelines
- Keep modules focused and single-purpose
- Use consistent error handling patterns
- Document public APIs with type annotations
- Add debug logging for complex operations
- Test all public functionality

## Dependencies
- Minimal external dependencies
- Vendor dependencies in tools/vendor/
- Document all third-party code
- Version lock dependencies when possible