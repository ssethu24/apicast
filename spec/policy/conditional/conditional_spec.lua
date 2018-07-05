local ConditionalPolicy = require('apicast.policy.conditional')
local Policy = require('apicast.policy')
local PolicyChain = require 'apicast.policy_chain'

describe('Conditional policy', function()
  local test_policy_1
  local test_policy_2
  local test_policy_chain
  local context
  local condition

  before_each(function()
    test_policy_1 = Policy.new('1')
    test_policy_1.rewrite = spy.new(function() end)

    test_policy_2 = Policy.new('2')
    test_policy_2.rewrite = spy.new(function() end)

    test_policy_chain = PolicyChain.build({ test_policy_1, test_policy_2 })

    context = {}

    condition = [[
      {%- assign header_val = 'Backend' | get_header -%}
      {%- if header_val == 'prod' -%}
      {{ 'true' }}
      {%- else -%}
      {{ 'false' }}
      {%- endif -%}
    ]]
  end)

  -- TODO: rewrite is just an example. We should test all the phases.
  describe('.rewrite', function()
    describe('when the condition (liquid) is met', function()
      it('calls rewrite on the policies of the chain', function()
        stub(ngx.req, 'get_headers', function() return { Backend = 'prod' } end)

        local conditional = ConditionalPolicy.new(
          {
            -- TODO: The vars assigned with 'assign' will be stored in the
            -- context passed to render()!
            condition = condition
          }
        )

        conditional.policy_chain = test_policy_chain

        conditional:rewrite(context)

        assert.spy(test_policy_1.rewrite).was_called(1)
        assert.spy(test_policy_1.rewrite).was_called_with(test_policy_1, context)
        assert.spy(test_policy_2.rewrite).was_called(1)
        assert.spy(test_policy_2.rewrite).was_called_with(test_policy_2, context)
      end)
    end)

    describe('when the condition (liquid) is not met', function()
      it('does not call rewrite on the policies of the chain', function()
        stub(ngx.req, 'get_headers', function() return { Backend = 'staging' } end)

        local conditional = ConditionalPolicy.new(
          {
            -- TODO: The vars assigned with 'assign' will be stored in the
            -- context passed to render()!
            condition = condition,
            policy_chain = test_policy_chain
          }
        )

        conditional.policy_chain = test_policy_chain

        conditional:rewrite(context)

        assert.spy(test_policy_1.rewrite).was_not_called()
        assert.spy(test_policy_2.rewrite).was_not_called()
      end)
    end)
  end)
end)
