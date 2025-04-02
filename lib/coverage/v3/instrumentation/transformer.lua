-- AST transformer for adding coverage instrumentation
local error_handler = require("lib.tools.error_handler")
local logging = require("lib.tools.logging")
local central_config = require("lib.core.central_config")

-- Initialize module logger
local logger = logging.get_logger("coverage.v3.instrumentation.transformer")

---@class coverage_v3_instrumentation_transformer
---@field transform fun(ast: table): table|nil, table? Transform AST to add coverage tracking
---@field generate fun(ast: table): string|nil Generate code from AST
---@field _VERSION string Module version
local M = {
  _VERSION = "3.0.0",
}

-- Helper to create a tracking call node
-- Creates a proper AST for: _firmo_coverage.track(line_number)
local function create_tracking_call(line, pos)
  pos = pos or 0
  -- Create a properly structured AST node for _firmo_coverage.track(line)
  return {
    tag = "Call",  -- This is a function call
    pos = pos,
    end_pos = pos,
    [1] = {  -- Function expression (Index node for _firmo_coverage.track)
      tag = "Index", 
      pos = pos,
      end_pos = pos,
      [1] = {  -- The base object (_firmo_coverage)
        tag = "Id",
        pos = pos,
        end_pos = pos,
        [1] = "_firmo_coverage"
      },
      [2] = {  -- The property name (track) as a string that will be rendered as .track
        tag = "String",
        pos = pos,
        end_pos = pos,
        [1] = "track"
      }
    },
    [2] = {  -- First argument: line number as a Number node
      tag = "Number",
      pos = pos,
      end_pos = pos,
      [1] = line
    }
  }
end
-- Helper to insert tracking before a node
local function insert_tracking(node, tracking)
  if node.tag == "Block" then
    -- For blocks, just insert at the beginning
    table.insert(node, 1, tracking)
    return node
  else
    -- Wrap in a block
    local block = {
      tag = "Block",
      pos = node.pos or 0,
      end_pos = node.end_pos or 0,
      [1] = tracking,
      [2] = node,
    }
    
    -- Copy metadata properties (but not numeric indices)
    for k, v in pairs(node) do
      if type(k) ~= "number" then
        block[k] = v
      end
    end
    
    return block
  end
end
-- Transform AST to add coverage tracking
---@param ast table The AST to transform
---@return table|nil transformed_ast The transformed AST, or nil on error
---@return table? source_map Source map for line number mapping
function M.transform(ast)
  if not ast or type(ast) ~= "table" then
    return nil, error_handler.validation_error("Invalid AST")
  end

  -- Create source map
  local source_map = {
    original_to_instrumented = {}, -- Map original lines to instrumented lines
    instrumented_to_original = {}, -- Map instrumented lines to original lines
    tracking_lookup = {}, -- Record which lines contain tracking calls
    current_line = 1, -- Current line in instrumented code
  }
  -- Add coverage tracking to executable nodes
  local function transform_node(node)
    if not node or type(node) ~= "table" then
      return node
    end

    -- Skip non-executable nodes
    if not node.tag then
      return node
    end

    -- Add tracking based on node type
    local tracking
    if
      node.line
      and (
        node.tag == "Local"
        or node.tag == "Localrec"
        or node.tag == "Return"
        or node.tag == "If"
        or node.tag == "Forin"
        or node.tag == "Fornum"
        or node.tag == "Repeat"
        or node.tag == "While"
        or node.tag == "Call"
        or node.tag == "Invoke"
        or node.tag == "Set"
      )
    then
      -- Create a tracking call with node position information for more accurate source mapping
      tracking = create_tracking_call(node.line, node.pos)
      
      -- Mark this line as containing a tracking call
      source_map.tracking_lookup[source_map.current_line] = true
      
      -- Map original line to instrumented line
      -- +1 because tracking comes before the statement
      source_map.original_to_instrumented[node.line] = source_map.current_line + 1
      
      -- Increment line counter for the tracking statement itself
      source_map.current_line = source_map.current_line + 1
    end

    -- Transform child nodes
    for i, child in ipairs(node) do
      node[i] = transform_node(child)
    end

    -- Insert tracking if needed
    if tracking then
      node = insert_tracking(node, tracking)
      
      -- Record the position of the node after inserting tracking
      if node.line then
        -- Update our line count for the actual node (after tracking)
        source_map.current_line = source_map.current_line + 1
        source_map.instrumented_to_original[source_map.current_line] = node.line
      end
    end

    return node
  end

  -- Transform the AST
  local transformed = transform_node(ast)
  if not transformed then
    return nil, error_handler.validation_error("Failed to transform AST")
  end
  
  -- Add additional source map metadata
  source_map.original_line_count = 0
  source_map.instrumented_line_count = source_map.current_line - 1
  
  -- Count original lines by finding the highest mapped line
  for orig_line, _ in pairs(source_map.original_to_instrumented) do
    if orig_line > source_map.original_line_count then
      source_map.original_line_count = orig_line
    end
  end

  -- Log source map statistics
  if central_config.get("logging.level") == "debug" then
    logger.debug("Source map created", {
      original_lines = source_map.original_line_count,
      instrumented_lines = source_map.instrumented_line_count,
      tracking_lines = 0
    })
    
    -- Count tracking lines
    local tracking_count = 0
    for _ in pairs(source_map.tracking_lookup) do
      tracking_count = tracking_count + 1
    end
    source_map.tracking_lines = tracking_count
  end

  return transformed, source_map
end

-- Generate code from AST
---@param ast table The AST to generate code from
---@return string|nil code The generated code, or nil on error
---@return string? error Error message if generation failed
function M.generate(ast)
  if not ast or type(ast) ~= "table" then
    return nil, error_handler.validation_error("Invalid AST")
  end

  -- Track indentation level
  local indent = 0
  local indent_str = "  "

  -- Buffer for output
  local output = {}

  -- Helper to add indentation
  local function add_indent()
    return string.rep(indent_str, indent)
  end

  -- Generate code for a node
  local function generate_node(node)
    if not node or type(node) ~= "table" then
      return
    end

    -- Handle different node types
    if node.tag == "Block" then
      indent = indent + 1
      for _, stmt in ipairs(node) do
        table.insert(output, add_indent())
        generate_node(stmt)
        table.insert(output, "\n")
      end
      indent = indent - 1
    elseif node.tag == "Call" then
      -- Function call
      generate_node(node[1])
      table.insert(output, "(")
      for i = 2, #node do
        if i > 2 then
          table.insert(output, ", ")
        end
        generate_node(node[i])
      end
      table.insert(output, ")")
    elseif node.tag == "Index" then
      -- Table index
      generate_node(node[1])
      
      -- Check if the index is a string key that's a valid identifier
      local is_valid_key = false
      if type(node[2]) == "table" and node[2].tag == "String" then
        local key = node[2][1]
        -- Check if the key is a valid Lua identifier (starts with letter or _, followed by letters, numbers, or _)
        if key:match("^[%a_][%w_]*$") then
          table.insert(output, ".")
          table.insert(output, key)
          is_valid_key = true
        end
      end
      
      -- If not a valid identifier key, use bracket notation
      if not is_valid_key then
        table.insert(output, "[")
        if type(node[2]) == "table" then
          generate_node(node[2])
        else
          table.insert(output, tostring(node[2]))
        end
        table.insert(output, "]")
      end
    elseif node.tag == "Id" then
      -- Identifier
      table.insert(output, node[1])
    elseif node.tag == "String" then
      -- String literal
      table.insert(output, string.format("%q", node[1]))
    elseif node.tag == "Number" then
      -- Number literal
      table.insert(output, tostring(node[1]))
    elseif node.tag == "Return" then
      -- Return statement
      table.insert(output, "return ")
      if node[1] then
        generate_node(node[1])
      end
    elseif node.tag == "Local" then
      -- Local variable declaration
      table.insert(output, "local ")
      for i, name in ipairs(node[1]) do
        if i > 1 then
          table.insert(output, ", ")
        end
        generate_node(name)
      end
      if node[2] then
        table.insert(output, " = ")
        for i, expr in ipairs(node[2]) do
          if i > 1 then
            table.insert(output, ", ")
          end
          generate_node(expr)
        end
      end
    elseif node.tag == "Set" then
      -- Assignment
      for i, var in ipairs(node[1]) do
        if i > 1 then
          table.insert(output, ", ")
        end
        generate_node(var)
      end
      table.insert(output, " = ")
      for i, expr in ipairs(node[2]) do
        if i > 1 then
          table.insert(output, ", ")
        end
        generate_node(expr)
      end
    elseif node.tag == "If" then
      -- If statement
      table.insert(output, "if ")
      generate_node(node[1])
      table.insert(output, " then\n")
      generate_node(node[2])
      for i = 3, #node - 1, 2 do
        table.insert(output, add_indent() .. "elseif ")
        generate_node(node[i])
        table.insert(output, " then\n")
        generate_node(node[i + 1])
      end
      if #node % 2 == 1 then
        table.insert(output, add_indent() .. "else\n")
        generate_node(node[#node])
      end
      table.insert(output, add_indent() .. "end")
    elseif node.tag == "Function" then
      -- Function definition
      if node.name then
        table.insert(output, "function ")
        generate_node(node.name)
      else
        table.insert(output, "function(")
        if node[1] then
          for i, param in ipairs(node[1]) do
            if i > 1 then
              table.insert(output, ", ")
            end
            generate_node(param)
          end
        end
        table.insert(output, ")")
      end
      table.insert(output, "\n")
      generate_node(node[2])
      table.insert(output, add_indent() .. "end")
    end

    -- Preserve comments
    if node.comments then
      for _, comment in ipairs(node.comments) do
        if comment.type == "line" then
          table.insert(output, add_indent() .. comment.text .. "\n")
        else
          table.insert(output, add_indent() .. comment.text)
        end
      end
    end
  end

  -- Generate code from AST
  generate_node(ast)

  -- Return generated code
  return table.concat(output)
end

return M
