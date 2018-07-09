use lib 't';
use Test::APIcast::Blackbox 'no_plan';

run_tests();

__DATA__

=== TEST 1: Conditional policy calls its chain when the condition is true
This test defines a conditional policy with a condition for the upstream
policy. It will only run the upstream policy when the 'Backend' Header is
'prod'. 'api_backend' is invalid (example.com), so the test will only pass if
the condition is evaluated, is true, and it runs the upstream policy to proxy
the request to a valid backend.
--- configuration
{
  "services": [
    {
      "id": 42,
      "backend_version":  1,
      "backend_authentication_type": "service_token",
      "backend_authentication_value": "token-value",
      "proxy": {
        "api_backend": "http://example.com:80/",
        "proxy_rules": [
          { "pattern": "/", "http_method": "GET", "metric_system_name": "hits", "delta": 2 }
        ],
        "policy_chain": [
          {
            "name": "apicast.policy.conditional",
            "configuration": {
              "condition": "get_header('Backend') == 'prod'",
              "policy_chain": [
                {
                  "name": "apicast.policy.upstream",
                  "version": "builtin",
                  "configuration":
                    {
                      "rules": [ { "regex": "/", "url": "http://test:$TEST_NGINX_SERVER_PORT" } ]
                    }
                }
              ]
            }
          },
          {
            "name": "apicast.policy.apicast"
          }
        ]
      }
    }
  ]
}
--- backend
  location /transactions/authrep.xml {
    content_by_lua_block {
      ngx.exit(200)
    }
  }
--- upstream
  location / {
     content_by_lua_block {
       ngx.say('yay, api backend');
     }
  }
--- request
GET /a_path?user_key=uk&a_param=a_value
--- more_headers
Backend: prod
--- response_body
yay, api backend
--- error_code: 200
--- no_error_log
[error]

=== TEST 2: Conditional policy does not call its chain when the condition is false
This test defines a conditional policy with a condition for the upstream
policy. It will only run the upstream policy when the 'Backend' Header is
'prod'. That header is not included in this test, so the condition will not be
met. We will now because if the upstream policy ran, the test would fail
because it points to an invalid backend (example.com).
--- configuration
{
  "services": [
    {
      "id": 42,
      "backend_version":  1,
      "backend_authentication_type": "service_token",
      "backend_authentication_value": "token-value",
      "proxy": {
        "api_backend": "http://test:$TEST_NGINX_SERVER_PORT",
        "proxy_rules": [
          { "pattern": "/", "http_method": "GET", "metric_system_name": "hits", "delta": 2 }
        ],
        "policy_chain": [
          {
            "name": "apicast.policy.conditional",
            "configuration": {
              "condition": "false",
              "policy_chain": [
                {
                  "name": "apicast.policy.upstream",
                  "version": "builtin",
                  "configuration":
                    {
                      "rules": [ { "regex": "/", "url": "http://example.com:80/" } ]
                    }
                }
              ]
            }
          },
          {
            "name": "apicast.policy.apicast"
          }
        ]
      }
    }
  ]
}
--- backend
  location /transactions/authrep.xml {
    content_by_lua_block {
      ngx.exit(200)
    }
  }
--- upstream
  location / {
     content_by_lua_block {
       ngx.say('yay, api backend');
     }
  }
--- request
GET /a_path?user_key=uk&a_param=a_value
--- response_body
yay, api backend
--- error_code: 200
--- no_error_log
[error]
