# Tailscale 1Password Secrets Automation Proxy

(there's probably a more clever name for this, PRs welcome)

tl;dr: Securely access secrets from 1Password Secrets Automation without using a bunch of 1Password Secrets Automation tokens while exploiting Tailscale ACL tags.

Whew.

## Prerequisites

1. Tailscale on every relevant node with useful ACL tags denoting node-level roles
2. 1Password
3. Bloodymindedness in the dimension of not wanting to run Vault or k8s or something else sane.

## Usage

1. Set up [1Password Secrets Automation](https://developer.1password.com/docs/connect) to the point where you have your credentials file, a token, a vault, and a running connect and sync container.
2. Use their `curl` examples to note down the ID for the vault you set up
3. Create a secure note in that vault with some fields where the label is something like `DATABASE_URL` and the value is the database URL in question. Tag it, for example, `test`.
4. Run this thing, passing `OP_CONNECT_API_TOKEN` and `OP_CONNECT_VAULT_ID` as environment variables, the tailscale socket as a volume, and ensuring that it listens on a tailscale interface.
5. Ensure ACLs are set such that every other node can access the node running this proxy on port 9292 and this node can at least see every other node, even if it's not on a port bound to anything. Tag one of the other nodes `tag:test`.
5. `curl http://<your tailscale ip>:9292/secrets` from the node tagged `tag:test`. You should get back something like 

```json
[["DATABASE_URL", "some://url"]]
```

See the included `docker-compose.yml` for how I run it in homeprod.

## Caveats

* I am not affiliated with Tailscale or 1Password.
* I wrote this in Ruby because that's what I reach for when I want to do something quick and dirty.
* It access the Tailscale socket directly rather than going through the Tailscale golang client library. This is gross. No one at Tailscale will like this, although they seem pretty chill in general so I don't think they'll yell at me.
* Caveat emptor. You almost certainly shouldn't use this in production. I sure as heck wouldn't.
