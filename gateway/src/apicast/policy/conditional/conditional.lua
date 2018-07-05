local ipairs = ipairs

local TemplateString = require('apicast.template_string')
local policy = require('apicast.policy')
local policy_phases = require('apicast.policy').phases
local PolicyChain = require('apicast.policy_chain')

local _M = policy.new('Conditional policy')

local new = _M.new

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

  self.condition_template_string = TemplateString.new(
    config.condition or "", "liquid"
  )

  self.policy_chain = build_policy_chain(config.policy_chain)

  return self
end

local function check_condition(condition_template_string, context)
  local res = condition_template_string:render(context or {})

  -- TODO: Can't return a bool when rendering. Find a fix.
  return res ~= 'false' and res ~= false and res ~= nil
end

for _, phase in policy_phases() do
  _M[phase] = function(self, context)
    if check_condition(self.condition_template_string, context) then
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
