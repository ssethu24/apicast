local pcall = pcall

local policy = require('apicast.policy')
local policy_phases = require('apicast.policy').phases
local PolicyChain = require('apicast.policy_chain')
local sandbox = require('apicast.sandbox')

local _M = policy.new('Conditional policy')

local new = _M.new

-- TODO: this could be somewhere else shared with TemplateString.
local allowed_funcs = {
  -- TODO: just an example of what we could expose.
  get_header = function(header)
    return ngx.req.get_headers()[header]
  end
}

local function build_policy_chain(chain)
  if not chain then return {} end

  local policies = {}

  for i=1, #chain do
    policies[i] = PolicyChain.load_policy(
      chain[i].name,
      chain[i].version,
      chain[i].configuration
    )
  end

  return PolicyChain.new(policies)
end

function _M.new(config)
  local self = new(config)
  self.condition = config.condition
  self.policy_chain = build_policy_chain(config.policy_chain)
  return self
end

local function check_condition(condition)
  -- TODO: add quota to sandbox call to prevent resource exhaustion.
  local ok, result = pcall(sandbox.run, 'return ' .. condition, { env = allowed_funcs })

  if ok then
    return result
  else
    -- TODO: show error and return false
  end
end

for _, phase in policy_phases() do
  _M[phase] = function(self, context)
    if check_condition(self.condition) then
      ngx.log(ngx.DEBUG, 'Condition met in conditional policy')
      self.policy_chain[phase](self.policy_chain, context)
    else
      ngx.log(ngx.DEBUG, 'Condition not met in conditional policy')
    end
  end
end

-- TODO: handle context of the chain: export()

-- TODO: verify this.
_M.init = function() end
_M.init_worker = function() end

return _M
