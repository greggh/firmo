# Interactive CLI API Reference


The Interactive CLI module provides a powerful and flexible command-line interface for the Firmo test framework. It allows users to run tests, manage test filters, configure watch mode, and work with codefix features in an interactive shell environment.

## Table of Contents



- [Module Overview](#module-overview)
- [Configuration](#configuration)
- [Core Functions](#core-functions)
- [Command Interface](#command-interface)
- [Integration with Other Modules](#integration-with-other-modules)


## Module Overview


The interactive module provides a command-line interface with the following capabilities:


- Running tests interactively through a command shell
- Filtering tests by name, patterns, and tags
- Watching files for changes to automatically rerun tests
- Running codefix operations to fix code quality issues
- History management for previously entered commands
- Extensive configuration options and central config integration


## Configuration


The interactive module provides several configuration options that can be set via the initialization function or updated during runtime:


```lua
-- Default configuration
{
  -- Test configuration
  test_dir = "./tests",
  test_pattern = "*_test.lua",

  -- Watch mode configuration
  watch_mode = false,
  watch_dirs = { "." },
  watch_interval = 1.0,
  exclude_patterns = { "node_modules", "%.git" },

  -- CLI configuration
  max_history = 100,
  colorized_output = true,
  prompt_symbol = ">",

  -- Debug configuration
  debug = false,
  verbose = false
}
```



## Core Functions


### init


Initialize the module with custom configuration options.


```lua
function interactive.init(options)
```


**Parameters:**


- `options` (table, optional): Custom configuration options to override defaults

**Returns:**


- (interactive_module): The module instance for method chaining

**Example:**


```lua
local interactive = require("lib.tools.interactive")
interactive.init({
  test_dir = "tests/unit",
  test_pattern = "*_spec.lua",
  watch_mode = true,
  watch_interval = 0.5
})
```



### configure


Configure the interactive CLI with custom options.


```lua
function interactive.configure(options)
```


**Parameters:**


- `options` (table, optional): Configuration options to override defaults

**Returns:**


- (interactive_module): The module instance for method chaining

**Example:**


```lua
interactive.configure({
  prompt_symbol = "$",
  colorized_output = true,
  test_dir = "tests/integration"
})
```



### start


Start the interactive CLI session.


```lua
function interactive.start(firmo, options)
```


**Parameters:**


- `firmo` (table): The firmo framework instance
- `options` (table, optional): Additional options for the CLI session

**Returns:**


- (boolean): Whether the session was started successfully

**Example:**


```lua
local firmo = require("firmo")
interactive.start(firmo, {
  test_dir = "tests",
  watch_mode = true
})
```



### reset


Reset the interactive CLI to default configuration.


```lua
function interactive.reset()
```


**Returns:**


- (interactive_module): The module instance for method chaining

**Example:**


```lua
interactive.reset()
```



### full_reset


Fully reset both configuration and state.


```lua
function interactive.full_reset()
```


**Returns:**


- (interactive_module): The module instance for method chaining

**Example:**


```lua
interactive.full_reset()
```



### debug_config


Get debug information about the current configuration.


```lua
function interactive.debug_config()
```


**Returns:**


- (table): Detailed information about the current configuration and state

**Example:**


```lua
local config_info = interactive.debug_config()
print(config_info.runtime_state.file_count)
```



## Command Interface


The interactive CLI supports the following commands:
| Command | Description | Example |
|---------|-------------|---------|
| `help`, `h` | Show help information | `help` |
| `exit`, `quit`, `q` | Exit the interactive CLI | `exit` |
| `clear`, `cls` | Clear the screen | `clear` |
| `status` | Show current settings | `status` |
| `list`, `ls` | List available test files | `list` |
| `run`, `r` | Run all tests or a specific test file | `run tests/unit/my_test.lua` |
| `dir`, `directory` | Set or display the test directory | `dir tests/unit` |
| `pattern`, `pat` | Set or display the test pattern | `pattern *_test.lua` |
| `filter` | Set or clear a test name filter | `filter string_utils` |
| `focus` | Set or clear a test focus filter | `focus validate` |
| `tags` | Set or clear a test tag filter | `tags unit,fast` |
| `watch` | Toggle or set watch mode | `watch on` |
| `watch-dir`, `watchdir` | Add a directory to watch | `watch-dir src` |
| `watch-exclude`, `exclude` | Add a pattern to exclude from watching | `watch-exclude node_modules` |
| `codefix` | Run codefix operations | `codefix fix src` |
| `history`, `hist` | Show command history | `history` |

## Integration with Other Modules


### Integration with Central Config


The interactive module integrates with the central configuration system to ensure consistency across the framework. When central_config is available, it:


1. Loads initial settings from central_config
2. Registers changes made to settings
3. Updates central_config when settings are changed through commands
4. Responds to changes in central_config made by other modules

Example of central_config integration:


```lua
-- The module automatically integrates with central_config
-- This happens when the module is required or initialized
-- Changes made via the CLI will update central_config
-- For example, using the 'dir' command:
-- > dir tests/unit
--
-- This will update central_config.interactive.test_dir to "tests/unit"
-- Similarly, changes made via other modules will be reflected in the CLI
-- For example:
local central_config = require("lib.core.central_config")
central_config.set("interactive.watch_mode", true)
-- This will enable watch mode in the interactive CLI
```



### Integration with Watcher Module


The interactive module integrates with the watcher module to provide file watching capabilities:


1. Configures the watcher with watch directories and exclude patterns
2. Handles file change events to rerun tests automatically
3. Controls watcher settings through CLI commands

Example of watcher integration:


```lua
-- Watch mode is started automatically when watch_mode is true
-- It can be manually controlled via commands:
-- > watch on
-- > watch-dir src
-- > watch-exclude node_modules
-- The watcher integration will:
-- 1. Monitor specified directories
-- 2. Rerun tests when changes are detected
-- 3. Provide feedback on which files changed
```



### Integration with Codefix Module


The interactive module integrates with the codefix module to provide code quality fixing capabilities:


1. Initializes codefix with appropriate settings
2. Provides commands to run codefix operations
3. Displays results of codefix operations

Example of codefix integration:


```lua
-- Codefix can be run via commands:
-- > codefix check src
-- > codefix fix src
-- This will:
-- 1. Initialize the codefix module
-- 2. Run the specified operation
-- 3. Display results
```
