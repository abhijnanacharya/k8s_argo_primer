# Spring Boot + Kustomize + ArgoCD Starter Kit

A full local GitOps setup: Spring Boot app → Docker image → Kubernetes (Docker Desktop) → ArgoCD syncs from GitHub.

---

## Prerequisites

Make sure you have all of these installed:

| Tool | Check | Install |
|---|---|---|
| Docker Desktop | `docker version` | https://www.docker.com/products/docker-desktop |
| Kubernetes (Docker Desktop) | Enable in Docker Desktop → Settings → Kubernetes | — |
| kubectl | `kubectl version` | Bundled with Docker Desktop |
| Java 21 | `java -version` | https://adoptium.net |
| ArgoCD CLI (optional) | `argocd version` | `brew install argocd` |

**Enable Kubernetes in Docker Desktop:**
Settings → Kubernetes → ✅ Enable Kubernetes → Apply & Restart

---

## Project Structure

```
k8s-starter/
├── app/                              # Spring Boot + Gradle project
│   └── src/main/java/com/example/hello/
│       ├── HelloApplication.java
│       └── HelloController.java
│
└── gitops/                           # Everything ArgoCD watches
    ├── base/                         # Shared k8s manifests
    │   ├── deployment.yaml
    │   ├── service.yaml
    │   ├── configmap.yaml
    │   └── kustomization.yaml
    ├── overlays/
    │   ├── dev/                      # Dev-specific patches (1 replica, dev message)
    │   │   └── kustomization.yaml
    │   └── prod/                     # Prod-specific patches (2 replicas, prod message)
    │       └── kustomization.yaml
    └── argocd/
        └── app-dev.yaml              # ArgoCD Application resource
```

---

## Step 1 — Push to GitHub

Create a new GitHub repo (can be private), then:

```bash
cd k8s-starter
git init
git add .
git commit -m "initial gitops starter"
git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO.git
git push -u origin main
```

Then update the `repoURL` in `gitops/argocd/app-dev.yaml`:

```yaml
repoURL: https://github.com/YOUR_USERNAME/YOUR_REPO.git
```

---

## Step 2 — Build the Docker Image

From the `app/` directory:

```bash
cd app
./gradlew bootBuildImage
```

This uses Spring Boot's Cloud Native Buildpacks — no Dockerfile needed.
The image lands in your local Docker daemon as `hello-spring:0.0.1`.

**Verify it works before deploying:**
```bash
docker run -p 8080:8080 hello-spring:0.0.1
curl http://localhost:8080/
# → {"message":"Hello from Spring Boot!","environment":"local"}
```

> **Docker Desktop note:** Because Docker Desktop's Kubernetes node shares the
> same Docker daemon as your desktop, images you build locally are immediately
> available in the cluster — no `minikube image load` or registry push needed.

---

## Step 3 — Install ArgoCD into the Cluster

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

Wait for all pods to be ready (~2 minutes):

```bash
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s
```

**Access the ArgoCD UI:**

```bash
# Port-forward the ArgoCD server to localhost
kubectl port-forward svc/argocd-server -n argocd 8090:443
```

Open https://localhost:8090 in your browser (accept the self-signed cert warning).

**Get the initial admin password:**

```bash
kubectl get secret argocd-initial-admin-secret -n argocd \
  -o jsonpath="{.data.password}" | base64 -d && echo
```

Login: `admin` / `<password from above>`

---

## Step 4 — Register Your GitHub Repo with ArgoCD

If your repo is **public**, skip this step.

If **private**, add credentials via the ArgoCD UI:
Settings → Repositories → Connect Repo → HTTPS → enter your GitHub URL + a Personal Access Token.

Or via CLI:
```bash
argocd login localhost:8090 --insecure
argocd repo add https://github.com/YOUR_USERNAME/YOUR_REPO.git \
  --username YOUR_USERNAME \
  --password YOUR_GITHUB_PAT
```

---

## Step 5 — Deploy the ArgoCD Application

```bash
kubectl apply -f gitops/argocd/app-dev.yaml
```

ArgoCD will now:
1. Clone your GitHub repo
2. Find `gitops/overlays/dev/kustomization.yaml`
3. Run kustomize to produce the final manifests
4. Apply them to the `hello-dev` namespace

**Watch it sync in the UI** at https://localhost:8090, or via CLI:

```bash
argocd app get hello-spring-dev
argocd app sync hello-spring-dev   # force immediate sync (normally auto)
```

---

## Step 6 — Verify the App is Running

```bash
kubectl get pods -n hello-dev
kubectl get svc -n hello-dev
```

**Hit the app:**

```bash
# Port-forward the service
kubectl port-forward svc/hello-spring -n hello-dev 8080:80

curl http://localhost:8080/
# → {"message":"Hello from Dev!","environment":"dev"}
```

---

## The GitOps Loop — Making a Change

This is the core workflow you'll use going forward:

1. **Edit** `gitops/overlays/dev/kustomization.yaml` — e.g. change the message patch
2. **Commit and push** to GitHub
3. ArgoCD detects the change within ~3 minutes and auto-syncs
4. Run `kubectl port-forward` again and see the change

**Example — bump the image tag after a new build:**

```bash
# 1. Build new image
./gradlew bootBuildImage   # produces hello-spring:0.0.1

# 2. Update the tag in the overlay
# In gitops/overlays/dev/kustomization.yaml, change:
#   newTag: "0.0.1"
# to:
#   newTag: "0.0.2"   (after bumping version in build.gradle)

# 3. Push
git add gitops/overlays/dev/kustomization.yaml
git commit -m "deploy hello-spring:0.0.2 to dev"
git push
```

ArgoCD picks up the push and rolls out the new image.

---

## Preview the Kustomize Output (Without Deploying)

Useful to verify what manifests ArgoCD will actually apply:

```bash
kubectl kustomize gitops/overlays/dev
```

This prints the fully-merged YAML — great for debugging overlay patches.

---

## What Each File Does

| File | Purpose |
|---|---|
| `base/deployment.yaml` | Defines the Pod spec, probes, env var references |
| `base/service.yaml` | ClusterIP service — routes traffic to pods |
| `base/configmap.yaml` | Base env values (overridden per overlay) |
| `base/kustomization.yaml` | Declares which base resources exist |
| `overlays/dev/kustomization.yaml` | Patches for dev: namespace, image tag, config values, replicas |
| `overlays/prod/kustomization.yaml` | Patches for prod: 2 replicas, prod message |
| `argocd/app-dev.yaml` | Tells ArgoCD which repo/path/cluster to sync |

---

## Troubleshooting

**ArgoCD shows "ImagePullBackOff"**
Docker Desktop's k8s shares the local Docker daemon, but the image must exist there.
Run `docker images | grep hello-spring` to confirm. If missing, re-run `./gradlew bootBuildImage`.

**ArgoCD shows "OutOfSync" and won't sync**
Check the diff in the ArgoCD UI — it shows exactly what differs between Git and the cluster.
Common cause: you applied something manually with `kubectl` that conflicts.

**Pod keeps restarting**
Check logs: `kubectl logs -n hello-dev deployment/hello-spring`
The readiness probe hits `/health` — make sure the app started on port 8080.

**ArgoCD can't reach your GitHub repo**
If private, re-check the PAT has `repo` scope and is correctly added under Settings → Repositories.
