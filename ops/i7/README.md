# i7 T3 Code deployments

The development checkout on the Mac is the release authority. Remote
environments run production builds of exact commits from `i7hq/t3code`.

## Local development

The ignored repository-root `.env.local` enables the production T3 Connect
account and relay in source builds:

```sh
vp run dev
```

Development state remains isolated from the installed T3 Code state.

The production Clerk application rejects the normal `t3code-dev://app`
renderer origin. This fork sets `T3CODE_DESKTOP_USE_PRODUCTION_ORIGIN=true`
for Electron development so `vp run dev:desktop` retains HMR and isolated
development state while authenticating against production T3 Connect. While
that process is running, it owns the `t3code://` protocol handler; do not run
the installed production app at the same time.

## Remote environments

Deploy and activate a commit that is already present on `origin`:

```sh
ops/i7/deploy-all.sh HEAD --activate
```

Each host uses:

- checkout: `~/dev/t3code`
- data: `~/.t3`
- service: `t3code-i7.service`
- source: one exact detached commit from `i7hq/t3code`

`deploy-all.sh` resolves the revision once before deploying, so both
environments receive the same commit. Use `deploy-host.sh` directly when
intentionally updating only one environment.

The custom unit intentionally omits T3's managed-service marker. Official
clients therefore cannot replace the fork through the npm self-update path.

Link a new remote environment from an SSH session:

```sh
node ~/dev/t3code/apps/server/dist/bin.mjs connect link --headless --base-dir ~/.t3
```

Open the printed URL, sign in to T3 Connect, then paste the resulting
authorization code into the SSH session.

## Updating

1. Integrate upstream changes locally.
2. Commit and push the desired fork revision.
3. Finish active remote agent turns.
4. Deploy the same revision to every environment.
5. Confirm `t3code-i7.service` and T3 Connect status on each host.
