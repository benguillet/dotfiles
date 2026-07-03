# YC Architecture Notes

## How apply talks to internal

```
Browser (founder)
  │  GraphQL — apply's own /graphql, user session auth
  ▼
apply (Rails)
  │  REST JSON via ApiClient (apply/app/services/api_client.rb)
  │  headers: X-HNID (acting user), X-IMPERSONATOR-HNID — NO shared secret
  ▼
internal-bare.ycinside.com — "bare" internal ALB
  │  no Cognito, no Cloudflare, not internet-reachable
  │  ingress = SG allowlist (apply web, bookface web+worker, agent
  │  workers, VPN, rails console) — infra/prod/main.tf `bare_ingress_sources`
  ▼
ycinternal /api/apply/*  (config/routes/api_apply.rb)
     Api::BaseController#current_user: X-HNID → User lookup
```

**Authentication:** none at the app layer. Trust is network-level — only
security groups on the allowlist can reach the bare ALB. The caller asserts
the acting user's identity per-request via `X-HNID`; ycinternal just looks
that user up. GraphQL is only the browser→apply layer, never app-to-app.

Same pattern is available to any other app in the services VPC
(`vpc-85aacce2`, yc-prod): add its SG to `bare_ingress_sources`, call
`internal-bare.ycinside.com` directly.
