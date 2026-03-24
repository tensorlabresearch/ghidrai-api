# ghidrai-api

Docker image, Helm chart, and deployment automation for the `ghidrAI` HeadlessElectron API from [`mattfj10/ghidrAI`](https://github.com/mattfj10/ghidrAI).

## What this packages

- Builds the upstream `Ghidra/Features/HeadlessElectron` API at pinned commit `9e33b0bd83c90abfe442f1002d0a7d5711493bd9`
- Patches the upstream server to honor `GHIDRA_ELECTRON_HOST` so it can bind to `0.0.0.0` in Kubernetes
- Ships a Helm chart for the API service plus an optional dedicated `cloudflared` connector
- Includes scripts to create a dedicated Cloudflare Tunnel and deploy the release on Kubernetes

## Repository layout

- `Dockerfile`: multi-stage build for the HeadlessElectron API
- `docker/entrypoint.sh`: runtime launcher for the backend API
- `charts/ghidrai-api`: Helm chart
- `deploy/values.yaml`: default Helm values for a cluster deployment
- `deploy/cloudflare.env.example`: example project-local Cloudflare settings file
- `scripts/create-cloudflare-tunnel.sh`: creates a dedicated tunnel, DNS record, and scoped token secret through the Cloudflare API
- `scripts/deploy.sh`: installs the Helm release
- `scripts/smoke-test.sh`: checks pod rollout plus internal and external health

## Build and publish

`ghidrai-api` is wired for branch-triggered upstream builds:

- `tensorlabresearch/ghidrAI` pushes on `master` dispatch a build into `tensorlabresearch/ghidrai-api`
- the packaging workflow rebuilds from the exact pushed source SHA
- the image is published to `ghcr.io/tensorlabresearch/ghidrai-api`
- the chart metadata is updated automatically with the new image tag and committed back to `main`

Manual runs are still available through GitHub Actions `workflow_dispatch`.

## Trigger model

The webhook-style trigger is implemented with `repository_dispatch`.

- source repo: `tensorlabresearch/ghidrAI`
- watched branch: `master`
- target repo: `tensorlabresearch/ghidrai-api`
- event type: `ghidrai-upstream-push`

After this is set up, you do not need a commit in `ghidrai-api` for normal rebuilds. A push to the watched `ghidrAI` branch is what triggers the image build and chart update.

## Deploy

1. Create a pull secret for GHCR:

```bash
kubectl create namespace ghidrai-api --dry-run=client -o yaml | kubectl apply -f -
kubectl -n ghidrai-api create secret docker-registry ghcr-pull-secret \
  --docker-server=ghcr.io \
  --docker-username=kai5263499 \
  --docker-password="$(gh auth token)" \
  --dry-run=client -o yaml | kubectl apply -f -
```

2. Create the dedicated Cloudflare Tunnel and token-backed Kubernetes secret:

```bash
cp deploy/cloudflare.env.example deploy/cloudflare.env
# edit deploy/cloudflare.env with your Cloudflare account, zone, and hostname
./scripts/create-cloudflare-tunnel.sh
```

If you need to re-run the tunnel bootstrap against an existing tunnel, pass its ID:

```bash
TUNNEL_ID=<existing-tunnel-uuid> ./scripts/create-cloudflare-tunnel.sh
```

3. Deploy the Helm release:

```bash
./scripts/deploy.sh
```

4. Verify:

```bash
./scripts/smoke-test.sh
```

## Source automation secret

The source-side dispatch workflow needs a token in `tensorlabresearch/ghidrAI`:

```bash
gh secret set --repo tensorlabresearch/ghidrAI GHIDRAI_API_DISPATCH_TOKEN
```

That token needs enough GitHub access to call `repository_dispatch` on `tensorlabresearch/ghidrai-api`.

## Runtime notes

- The API listens on port `8089`.
- Stateful project and artifact data live under `/data`.
- The checked-in `deploy/values.yaml` currently defaults to a `local-path` PVC; override it as needed for your cluster.
- The tunnel bootstrap reads Cloudflare settings from `deploy/cloudflare.env` if present, then falls back to `~/.cloudflared/.env`.
