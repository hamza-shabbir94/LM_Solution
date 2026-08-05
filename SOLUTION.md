
# Solution

## Dockerfile

### What changed from the original

Old Dockerfile used `python:3.9.1-buster`. Buster is EOL, no more security patches. It also ran as root, and copied the whole build context before installing dependencies, so every code change busted the Docker cache and reinstalled everything.

### Decisions

- **Base image: `python:3.11-slim-trixie`.** Tried `3.14.6` first. Pydantic v1 (a FastAPI 0.78.0 dependency) doesn't support Python 3.14 at all — that's confirmed upstream, not something I can patch around. Fixing it properly means migrating to Pydantic v2, which is an app rewrite, not something to do the night before a review. Went with 3.11 instead: still fully supported and patched (unlike 3.9.1-buster), old enough that these 2022-era deps actually work against it.
- **Multi-stage build.** Builder stage installs deps into a venv at `/opt/venv`. Final stage only copies that folder over. No pip cache, no build tooling, none of that ends up in the shipped image.
- **Layer order matters.** `requirements.txt` gets copied and installed before the app code. Code changes shouldn't force a full dependency reinstall.
- **Non-root user with a fixed UID (1000).** Kubernetes' `runAsUser` needs an actual number, not a name. A named-only user gets an auto-assigned UID you can't predict or reference later.
- **Port 8000, not 80.** Non-root can't bind under 1024 anyway. Kept 8000 specifically because that's what `tests/test_main.http` already used — easier to keep their test file working as-is than make them edit it.

### Trade-offs / assumptions

Left most of `requirements.txt` alone (it's from ~2022) since this exercise is about infra, not an app dependency audit. Three exceptions, and none of them were optional, the app just didn't run otherwise:

- `PyYAML` `6.0` → `6.0.2`. `6.0` has no wheel for current Python and fails building from source (Cython 3.0 incompatibility, known issue).
- `pydantic` `1.9.1` → `1.10.26`. `1.9.1` throws `ValueError: 'not' is not a valid parameter name` on import under Python 3.11+ — a documented bug, fixed in 1.10. Stayed on the v1 line on purpose so I didn't have to touch FastAPI or app code.
- Dropped `uvloop` and `httptools` entirely. Both fail to compile against current CPython internals. Both are optional uvicorn speed extras, not required — uvicorn just falls back to plain asyncio and the pure-Python `h11` parser, which is already a dependency.

Didn't revert to an older base image to dodge any of this. That would've undone the actual security fix (EOL image, unpatched CVEs) to work around dependency problems that had cleaner, narrower fixes. Everything else here I'd still upgrade for real production use, ideally caught earlier by a CI vulnerability scan — didn't build that pipeline for this exercise.

`EXPOSE 8000` is just documentation, Docker doesn't enforce it and Kubernetes ignores it completely. Routing is controlled by the container's actual listening port and the Service's `targetPort`.

### If I had more time

- Wire Trivy into a CI pipeline, fail the build on critical/high before the image ever gets pushed.

## Kubernetes manifests

### Approach

Kustomize. One environment-agnostic `kubernetes/base/` (Deployment, Service, HPA, PodDisruptionBudget), then `kubernetes/overlays/{dev,staging,production}/` for whatever actually differs — replica counts, resource limits, image tag, HPA bounds. Nothing duplicated across environments.

### Decisions

- **Rolling updates, zero downtime.** `maxUnavailable: 0` so a deploy never drops below current replica count. PDB with `minAvailable: 1` so node drains or scale-downs can't take every replica out at once.
- **HPA targets 70% CPU**, scales between env-specific min/max (2–10 in prod) instead of a fixed replica count.
- **Startup probe hits `/alive`.** `main.py` blocks for 5s on startup (`time.sleep(5)`), so liveness/readiness need to be gated until the app's actually up, otherwise Kubernetes kills a pod that just hasn't finished booting yet.
- **Liveness and readiness point at different endpoints** (`/alive`, `/ready`), even though right now they return the same thing. Set up correctly for when that changes — see below.
- **Security context set at both pod and container level** — non-root, dropped capabilities, read-only root filesystem, no privilege escalation. Don't want to rely purely on the image build getting this right.
- **Plain `LoadBalancer` Service, not an Ingress.** EKS provisions the actual NLB automatically, no extra controller or IAM role needed. Fine for one service per environment.

### Trade-offs / assumptions

`/alive` and `/ready` are identical right now in the app itself. Manifests are written as if they'll diverge, since that's the correct end state, but neither actually checks a real dependency today.

Used Kustomize over Helm — no templating needed here, plain YAML stays readable. Would reach for Helm if this needed to ship as a reusable chart to other teams.

### If I had more time

- Move to an Ingress + AWS Load Balancer Controller once there's more than one service to share an ALB across. Needs IRSA — already enabled on the EKS module, just unused right now.
- Add a NetworkPolicy, default-deny plus only what's actually needed.
- Pod anti-affinity so replicas don't end up stacked on the same node.

## Terraform (EKS platform)

### Approach

One module, `terraform/modules/eks-platform`, builds everything: VPC, EKS cluster, node group. Each environment folder is just a thin wrapper passing in its own sizing.

### Decisions

- Used `terraform-aws-modules/vpc/aws` and `.../eks/aws` instead of hand-writing every resource.
- 3 AZs. Private subnets for nodes, public subnets for the load balancer. Prod gets one NAT gateway per AZ; dev/staging share one NAT gateway to save cost.
- **Turned off private cluster endpoint access, kept public on.** The module defaults to both, which caused a real problem tonight — `kubectl` from outside the cluster's VPC resolved a private IP and just timed out. Nodes still reach the control plane fine through the NAT gateway either way. Public access is scoped by CIDR, open by default, restrict it via local tfvars.
- No in-cluster load balancer controller. One service per environment doesn't need it — plain `LoadBalancer` Service is enough. `enable_irsa` stays on as groundwork in case that changes.
- Docker Hub instead of ECR. Simpler for this exercise, one less AWS resource, matches what I was already using locally.
- S3 remote state with native locking (`use_lockfile`), no DynamoDB table needed.

### If I had more time

- `terraform plan` on PRs, `apply` on merge for non-prod, manual approval gate for production.
