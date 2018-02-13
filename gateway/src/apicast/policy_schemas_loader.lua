--- Policy schemas loader
-- Finds the schemas for the builtin policies and the other ones loaded.

local pl_file = require('pl.file')
local pl_dir = require('pl.dir')
local pl_path = require('pl.path')
local cjson = require('cjson')
local format = string.format
local ipairs = ipairs
local insert = table.insert
local policy_loader = require('apicast.policy_loader')

local _M = {}

local builtin_policy_load_path = policy_loader.builtin_policy_load_path
local policy_load_paths = policy_loader.policy_load_paths

local policy_schema_name = 'apicast-policy.json'

local function builtin_policy_schema_path(name)
  return format('%s/%s/%s', builtin_policy_load_path, name, policy_schema_name)
end

local function loaded_policy_schema_paths(name, version)
  local paths = {}

  for _, load_path in ipairs(policy_load_paths) do
    local path = format('%s/%s/%s/%s', load_path, name, version, policy_schema_name)
    insert(paths, path)
  end

  return paths
end

local function all_builtin_policy_schemas()
  local schemas = {}

  local builtin_policy_dirs = pl_dir.getdirectories(builtin_policy_load_path)

  for _, policy_dir in ipairs(builtin_policy_dirs) do
    local schema_file = format('%s/%s', policy_dir, policy_schema_name)
    local schema = pl_file.read(schema_file)
    if schema then insert(schemas, schema) end
  end

  return schemas
end

local function all_loaded_policy_schemas()
  local schemas = {}

  for _, load_path in ipairs(policy_load_paths) do
    if pl_path.exists(load_path) then
      local policy_dirs = pl_dir.getdirectories(load_path)
      for _, policy_dir in ipairs(policy_dirs) do
        local version_dirs = pl_dir.getdirectories(policy_dir)
        for _, version_dir in ipairs(version_dirs) do
          local schema_file = format('%s/%s', version_dir, policy_schema_name)
          local schema = pl_file.read(schema_file)
          if schema then insert(schemas, schema) end
        end
      end
    end
  end

  return schemas
end

--- Get a policy schema
-- Returns a the schema of a policy given its name and version. When version is
-- not provided, 'builtin' is assumed.
-- @tparam string name Name of the policy.
-- @tparam[opt] string version Version of the policy.
-- @treturn string Schema of the policy.
function _M.get(name, version)
  local schema

  if not version or version == 'builtin' then
    local path = builtin_policy_schema_path(name)
    schema = pl_file.read(path)
  else
    local paths = loaded_policy_schema_paths(name, version)
    for _, path in ipairs(paths) do
      local file = pl_file.read(path)
      if file then
        local schema_version = cjson.decode(file).version
        if schema_version == version then
          schema = file
          break
        end
      end
    end
  end

  return schema
end

--- Get the schemas for all the policies. Both the builtin policies and the
-- ones present in the directories configured as directories that can
-- include policies.
-- @treturn table Schemas for all the policies.
function _M.get_all()
  local schemas = all_builtin_policy_schemas()

  for _, schema in ipairs(all_loaded_policy_schemas()) do
    insert(schemas, schema)
  end

  return schemas
end

return _M
