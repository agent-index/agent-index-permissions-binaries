# agent-index-permissions-binaries

Pre-built native binaries for [agent-index](https://github.com/agent-index/agent-index-core) permission tooling. This repo only hosts compiled release artifacts; source code for the tools lives in the agent-index-core repo under `lib/permission-helper-go/`.

## What's published here

Each git tag (`v0.2.0`, `v0.3.0`, …) corresponds to a versioned release of one or more permission-tool binaries. Per-platform binaries are attached as GitHub Release assets.

Currently published:

- **`agent-index-show-plan`** — review-and-apply helper for permission changes. Registers itself as the `agent-index://` URL scheme handler. Source: `agent-index-core/lib/permission-helper-go/`.

## Verifying downloads

Every release asset has a published SHA256 in the agent-index registry (`infrastructure-directory.json` → `binaries[]`). The `apply-updates` task on the agent-index install side verifies the SHA256 automatically before placing the binary on disk; manual verifiers can use:

```bash
shasum -a 256 agent-index-show-plan-0.2.0-darwin-arm64
```

The published SHA256 for each platform-binary is the value in `infrastructure-directory.json`'s `binaries[].platforms[].sha256` field for that version.

## Release-tag conventions

| Convention | Value |
|---|---|
| Tag format | `v<semver>` (e.g. `v0.2.0`) |
| Asset naming | `agent-index-show-plan-<version>-<os>-<arch>` (`.exe` suffix on Windows) |
| Supported platforms | `windows-amd64`, `windows-arm64`, `darwin-amd64`, `darwin-arm64`, `linux-amd64`, `linux-arm64` |
| Release notes | Cross-link to the corresponding `agent-index-core` CHANGELOG entry where the helper version was introduced. |

## Release process

Each new release:

1. Build all platform binaries via `goreleaser release --snapshot --clean --skip publish` (or the equivalent local build matrix). Confirm filenames match the asset-naming convention above.
2. Compute SHA256 for each artifact:
   ```bash
   shasum -a 256 dist/*.zip dist/agent-index-show-plan-* > checksums.txt
   ```
3. Create a git tag `v<version>` on this repo. Push the tag.
4. On GitHub, create a Release on the tag. Upload all platform binaries as assets.
5. Update `agent-index-core/agent-index-resource-listings/infrastructure-directory.json`:
   - Bump `binaries[].current_version` to the new version.
   - Update each `platforms[].sha256` with the actual hash from step 2.
   - If this release fixes a critical bug, also bump `min_required_version` to lock everyone out of the older release.
6. Push the resource-listings change. Members will pick it up on their next `@ai:check-updates`.

## Repo policies

- Public visibility — there are no secrets in compiled binaries; download tokens add friction without security gain.
- Source comes from the private `agent-index-core` repo; this repo's only commits are the README + release tags.
- Do not commit the binaries themselves to the git history — they go on GitHub Releases as assets only. Keeps `git clone` lightweight.
- Tag immutability: never re-tag a published version. If a release needs replacing, cut a new version (`0.2.1` instead of re-issuing `0.2.0`).
