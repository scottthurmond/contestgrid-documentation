# Local Development Setup with Rancher Desktop

This guide walks you through setting up a complete local Kubernetes development environment that mirrors production EKS infrastructure.

## Prerequisites

- **macOS**: 10.15+, 8GB RAM minimum (16GB recommended)
- **Windows**: Windows 10 Pro/Enterprise with WSL2
- **Linux**: Ubuntu 20.04+, Fedora 35+
- **Disk Space**: 20GB free
- **Admin/sudo access**: Required for DNS configuration

## Why Rancher Desktop?

✅ **Infrastructure Parity**: Identical K8s environment to production EKS
✅ **Free**: No AWS costs during development
✅ **Offline**: Work without internet connection
✅ **Fast**: Instant feedback loop (build → test → debug)
✅ **Complete**: Includes Docker, kubectl, Helm out of the box

---

## Step 1: Install Rancher Desktop

### macOS
```bash
# Using Homebrew (recommended)
brew install rancher-desktop

# Or download from https://rancherdesktop.io/
```

### Windows
```powershell
# Using Chocolatey
choco install rancher-desktop

# Or download installer from https://rancherdesktop.io/
```

### Linux
```bash
# Download AppImage
wget https://github.com/rancher-sandbox/rancher-desktop/releases/latest/download/Rancher.Desktop-*.AppImage
chmod +x Rancher.Desktop-*.AppImage
./Rancher.Desktop-*.AppImage

# Or use package manager (varies by distro)
```

### Configuration
1. Launch Rancher Desktop
2. Go to **Preferences** → **Kubernetes**:
   - Kubernetes version: **1.28.x** (match production EKS)
   - Container runtime: **containerd** (default)
3. Go to **Preferences** → **Resources**:
   - Memory: **8GB** (or more if available)
   - CPUs: **4** (or more if available)
4. Click **Apply & Restart**

### Verify Installation
```bash
# Check Rancher Desktop is running
kubectl cluster-info
# Should show: Kubernetes control plane is running at https://127.0.0.1:XXXXX

# Check nodes
kubectl get nodes
# Should show 1 node in Ready state

# Check kubectl version
kubectl version --short
# Client and Server should both be v1.28.x

# Docker should also work
docker ps
```

---

## Step 2: Install Infrastructure Components

### Install Flux CD (GitOps)
```bash
# Install Flux CLI
brew install fluxcd/tap/flux  # macOS
# or: curl -s https://fluxcd.io/install.sh | sudo bash

# Verify
flux --version

# Install Flux controllers to cluster
flux install

# Verify installation
kubectl get pods -n flux-system
# All pods should be Running
```

### Install Istio (Service Mesh)
```bash
# Download Istio
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.20.3 sh -

# Add to PATH (add to ~/.bashrc or ~/.zshrc for persistence)
cd istio-1.20.3
export PATH=$PWD/bin:$PATH

# Install Istio with demo profile (includes ingress/egress gateways)
istioctl install --set profile=demo -y

# Verify installation
kubectl get pods -n istio-system
# All pods should be Running

# Enable Kiali, Prometheus, Grafana, Jaeger (observability stack)
kubectl apply -f samples/addons/
kubectl rollout status deployment/kiali -n istio-system
```

### Install cert-manager (TLS Certificates)
```bash
# Install cert-manager CRDs and controllers
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.0/cert-manager.yaml

# Verify installation
kubectl get pods -n cert-manager
# All pods should be Running

# Create self-signed ClusterIssuer for local development
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned-issuer
spec:
  selfSigned: {}
EOF

# Verify
kubectl get clusterissuer
```

---

## Step 3: Set Up Application Namespace

```bash
# Create namespace for Contest Schedule app
kubectl create namespace contestgrid

# Enable automatic Istio sidecar injection
kubectl label namespace contestgrid istio-injection=enabled

# Verify label
kubectl get namespace contestgrid --show-labels
# Should see: istio-injection=enabled
```

---

## Step 4: Install PostgreSQL Database

```bash
# Add Bitnami Helm repository
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Install PostgreSQL
helm install contest-db bitnami/postgresql \
  --namespace contestgrid \
  --set auth.username=postgres \
  --set auth.password=localdevpassword \
  --set auth.database=contestdb \
  --set primary.persistence.size=5Gi

# Wait for pod to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=postgresql -n contestgrid --timeout=120s

# Verify installation
kubectl get pods -n contestgrid
# Should see pod: contest-db-postgresql-0 with 2/2 containers (app + istio-proxy)

# Test connection
kubectl exec -n contestgrid contest-db-postgresql-0 -c postgresql -- psql -U postgres -d contestdb -c "SELECT version();"
```

---

## Step 5: Install Flyway (Database Migrations)

Flyway manages database schema changes with version-controlled SQL migrations.

### Install Flyway CLI

#### macOS
```bash
brew install flyway

# Verify installation
flyway -v
# Should show: Flyway Community Edition 10.x.x
```

#### Windows
```powershell
# Using Chocolatey
choco install flyway.commandline

# Or download from https://flywaydb.org/download
```

#### Linux
```bash
# Download and install
wget -qO- https://repo1.maven.org/maven2/org/flywaydb/flyway-commandline/10.8.1/flyway-commandline-10.8.1-linux-x64.tar.gz | tar xvz
sudo ln -s `pwd`/flyway-10.8.1/flyway /usr/local/bin

# Verify
flyway -v
```

### Set Up Flyway Configuration

```bash
# Flyway assets are centralized in ../flyway
cd ../flyway

# Copy the example config, then edit DB name/user as needed
cp conf/flyway-local.conf.example conf/flyway-local.conf

# Port forward PostgreSQL to localhost
kubectl port-forward -n contestgrid svc/contest-db-postgresql 5432:5432 &
```

### Create Your First Migration

```bash
# From contestgrid-fe/, run migrations from the consolidated flyway/ folder
cd ../flyway

# Create initial migration file
cat > db/migrations/V001__create_tenants_table.sql <<EOF
-- V001__create_tenants_table.sql
-- Description: Create tenants table for multi-tenancy support

CREATE TABLE tenants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    subdomain VARCHAR(100) NOT NULL UNIQUE,
    status VARCHAR(50) DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_tenants_subdomain ON tenants(subdomain);
CREATE INDEX idx_tenants_status ON tenants(status);

COMMENT ON TABLE tenants IS 'Multi-tenant organizations';
EOF

# Create second migration
cat > db/migrations/V002__create_users_table.sql <<EOF
-- V002__create_users_table.sql
-- Description: Create users table

CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    email VARCHAR(255) NOT NULL,
    name VARCHAR(255) NOT NULL,
    role VARCHAR(50) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(tenant_id, email)
);

CREATE INDEX idx_users_tenant_id ON users(tenant_id);
CREATE INDEX idx_users_email ON users(email);
EOF
```

### Run Migrations

```bash
# From contestgrid-fe/, run Flyway from the consolidated flyway/ folder
cd ../flyway

# Check migration status
flyway -configFiles=conf/flyway-local.conf info

# Run pending migrations
flyway -configFiles=conf/flyway-local.conf migrate

# Output should show:
# Successfully applied 2 migrations to schema "public"

# Verify in database
kubectl exec -n contestgrid contest-db-postgresql-0 -c postgresql -- \
  psql -U postgres -d contestdb -c "\dt"

# Should see: tenants, users, flyway_schema_history tables

# View migration history
kubectl exec -n contestgrid contest-db-postgresql-0 -c postgresql -- \
  psql -U postgres -d contestdb -c "SELECT installed_rank, version, description, success FROM flyway_schema_history;"
```

### Flyway Daily Workflow

```bash
# From contestgrid-fe/, run Flyway from the consolidated flyway/ folder
cd ../flyway

# Check current migration status
flyway -configFiles=conf/flyway-local.conf info

# Create new migration (use timestamp for version)
touch db/migrations/V$(date +%s)__add_leagues_table.sql

# Edit the migration file with your SQL
# ...

# Test migration
flyway -configFiles=conf/flyway-local.conf validate
flyway -configFiles=conf/flyway-local.conf migrate

# If migration fails and you need to fix it:
# 1. Fix the SQL in the migration file
# 2. Repair Flyway metadata
flyway -configFiles=conf/flyway-local.conf repair
# 3. Re-run migration
flyway -configFiles=conf/flyway-local.conf migrate
```

---

## Step 6: Create Local DNS Entries

### macOS / Linux
```bash
# Add to /etc/hosts
echo "127.0.0.1 contestgrid.local api.contestgrid.local admin.contestgrid.local" | sudo tee -a /etc/hosts

# Verify
ping -c 1 contestgrid.local
```

### Windows
```powershell
# Open PowerShell as Administrator
Add-Content -Path C:\Windows\System32\drivers\etc\hosts -Value "127.0.0.1 contestgrid.local api.contestgrid.local admin.contestgrid.local"

# Verify
ping contestgrid.local
```

---

## Step 7: Create Secrets

```bash
# Database credentials (already created by Helm, but good to know how)
kubectl create secret generic contest-db-secret \
  --from-literal=username=postgres \
  --from-literal=password=localdevpassword \
  --from-literal=database=contestdb \
  --from-literal=host=contest-db-postgresql.contestgrid.svc.cluster.local \
  --from-literal=port=5432 \
  --namespace contestgrid \
  --dry-run=client -o yaml | kubectl apply -f -

# Application secrets (example)
kubectl create secret generic contestgrid-core-sys-config \
  --from-literal=JWT_SECRET=local-dev-jwt-secret-change-in-production \
  --from-literal=API_KEY=local-dev-api-key \
  --namespace contestgrid \
  --dry-run=client -o yaml | kubectl apply -f -

# Verify secrets
kubectl get secrets -n contestgrid
```

---

## Step 8: Deploy Application (Example)

Create a sample deployment to test the setup:

```bash
# Create a test deployment
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: contestgrid-core-sys
  namespace: contestgrid
spec:
  replicas: 1
  selector:
    matchLabels:
      app: contestgrid-core-sys
  template:
    metadata:
      labels:
        app: contestgrid-core-sys
        version: v1
    spec:
      containers:
      - name: contestgrid-core-sys
        image: nginx:alpine  # Replace with your actual image
        ports:
        - containerPort: 80
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: contest-db-secret
              key: username
---
apiVersion: v1
kind: Service
metadata:
  name: contestgrid-core-sys
  namespace: contestgrid
spec:
  selector:
    app: contestgrid-core-sys
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: contest-gateway
  namespace: contestgrid
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "*.contestgrid.local"
---
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: contestgrid-core-sys
  namespace: contestgrid
spec:
  hosts:
  - "api.contestgrid.local"
  gateways:
  - contest-gateway
  http:
  - route:
    - destination:
        host: contestgrid-core-sys
        port:
          number: 80
EOF

# Wait for deployment
kubectl wait --for=condition=available deployment/contestgrid-core-sys -n contestgrid --timeout=120s

# Verify pods (should have 2 containers: app + istio-proxy)
kubectl get pods -n contestgrid -l app=contestgrid-core-sys
```

### Access the Application

The Istio ingress gateway uses `hostNetwork: true`, which binds directly to the
Lima VM network interfaces. Lima's SSH tunnel automatically forwards these to the host.

**Ports:**
- `8080` — HTTP (redirects to HTTPS)
- `8443` — HTTPS (TLS termination via Istio)

**Prerequisites (one-time setup):**

```bash
# 1. Allow Lima SSH to bind ports < 1024 (optional if using 8080/8443)
sudo sysctl -w net.ipv4.ip_unprivileged_port_start=80
# Make persistent:
echo "net.ipv4.ip_unprivileged_port_start=80" | sudo tee /etc/sysctl.d/99-contestgrid-ports.conf

# 2. Add DNS entry
echo "127.0.0.1 api.contestgrid.local" | sudo tee -a /etc/hosts

# 3. Disable Traefik (ports 80/443 conflict with Istio)
#    Inside the VM:
LIMA_HOME=~/.local/share/rancher-desktop/lima \
  /opt/rancher-desktop/resources/resources/linux/lima/bin/limactl shell 0 \
  sudo sh -c 'printf "disable:\n  - traefik\n" > /etc/rancher/k3s/config.yaml'
```

**Test connectivity:**

```bash
# HTTP → HTTPS redirect
curl -sI http://api.contestgrid.local:8080
# Expected: HTTP/1.1 301 Moved Permanently

# HTTPS (TLS 1.3, HTTP/2)
curl -skI https://api.contestgrid.local:8443
# Expected: HTTP/2 503 (no backend) or HTTP/2 200 (with contestgrid-core-sys deployed)

# Verify TLS certificate
openssl s_client -connect localhost:8443 -servername api.contestgrid.local </dev/null 2>&1 | head -20
```

---

## Step 9: Set Up Observability Dashboards

### Kiali (Service Mesh Visualization)
```bash
# Open Kiali dashboard
istioctl dashboard kiali

# Opens browser at http://localhost:20001/kiali
# Username: admin (no password for demo installation)
```

### Grafana (Metrics)
```bash
# Open Grafana dashboard
istioctl dashboard grafana

# Opens browser at http://localhost:3000
# Pre-installed dashboards for Istio metrics
```

### Jaeger (Distributed Tracing)
```bash
# Open Jaeger UI
istioctl dashboard jaeger

# Opens browser at http://localhost:16686
```

### Prometheus (Raw Metrics)
```bash
# Open Prometheus UI
istioctl dashboard prometheus

# Opens browser at http://localhost:9090
```

---

## Development Workflow

### Build and Deploy Changes

```bash
# Build Docker image (Rancher Desktop uses local Docker daemon)
docker build -t contestgrid-core-sys:dev .

# Deploy to Kubernetes
kubectl set image deployment/contestgrid-core-sys contestgrid-core-sys=contestgrid-core-sys:dev -n contestgrid

# Or restart deployment to pick up new image
kubectl rollout restart deployment/contestgrid-core-sys -n contestgrid

# Watch rollout status
kubectl rollout status deployment/contestgrid-core-sys -n contestgrid

# View logs
kubectl logs -f -l app=contestgrid-core-sys -c contestgrid-core-sys -n contestgrid
```

### Using Skaffold (Hot Reload - Recommended)

```bash
# Install Skaffold
brew install skaffold  # macOS
# or: curl -Lo skaffold https://storage.googleapis.com/skaffold/releases/latest/skaffold-linux-amd64 && chmod +x skaffold && sudo mv skaffold /usr/local/bin

# Create skaffold.yaml in project root
cat > skaffold.yaml <<EOF
apiVersion: skaffold/v4beta6
kind: Config
build:
  artifacts:
  - image: contestgrid-core-sys
    docker:
      dockerfile: Dockerfile
  local:
    push: false
deploy:
  kubectl:
    manifests:
    - k8s/*.yaml
portForward:
- resourceType: service
  resourceName: contestgrid-core-sys
  namespace: contestgrid
  port: 80
  localPort: 8080
EOF

# Run Skaffold in dev mode (auto-rebuild on file changes)
skaffold dev --port-forward

# Press Ctrl+C to stop
```

### Testing mTLS

```bash
# Deploy a test client pod
kubectl run -n contestgrid test-client --image=curlimages/curl --rm -it --restart=Never -- sh

# Inside the pod, try to access API
curl http://contestgrid-core-sys.contestgrid.svc.cluster.local/

# Check if mTLS is enforced
kubectl exec -n contestgrid deploy/contestgrid-core-sys -c istio-proxy -- \
  curl -v http://contestgrid-core-sys.contestgrid.svc.cluster.local/
```

---

## Troubleshooting

### Pod Not Starting
```bash
# Check pod status
kubectl get pods -n contestgrid

# Describe pod for events
kubectl describe pod <pod-name> -n contestgrid

# Check logs
kubectl logs <pod-name> -c api -n contestgrid
kubectl logs <pod-name> -c istio-proxy -n contestgrid
```

### Istio Sidecar Not Injected
```bash
# Verify namespace label
kubectl get namespace contestgrid --show-labels

# Re-label if needed
kubectl label namespace contestgrid istio-injection=enabled --overwrite

# Restart deployment
kubectl rollout restart deployment/contestgrid-core-sys -n contestgrid
```

### Cannot Access Application via DNS
```bash
# Check Istio Ingress Gateway
kubectl get svc -n istio-system istio-ingressgateway

# Check Gateway and VirtualService
kubectl get gateway,virtualservice -n contestgrid

# Verify DNS resolution
ping contestgrid.local

# If DNS not working, use port-forward
kubectl port-forward -n contestgrid svc/contestgrid-core-sys 8080:80
# Access at http://localhost:8080
```

### Reset Everything
```bash
# Delete namespace (removes all resources)
kubectl delete namespace contestgrid

# Recreate and start over
kubectl create namespace contestgrid
kubectl label namespace contestgrid istio-injection=enabled
```

---

## Next Steps

1. ✅ Deploy your actual application Helm charts
2. ✅ Set up Flux to sync from Git repository
3. ✅ Configure CI/CD pipeline (GitHub Actions → Rancher for testing)
4. ✅ Test with production-like data and load
5. ✅ Validate that same Helm charts work on EKS (production)

---

## Useful Commands Cheat Sheet

```bash
# Flyway commands
cd ../flyway
flyway -configFiles=conf/flyway-local.conf info          # Show migration status
flyway -configFiles=conf/flyway-local.conf validate      # Validate migration files
flyway -configFiles=conf/flyway-local.conf migrate       # Run pending migrations
flyway -configFiles=conf/flyway-local.conf repair        # Repair metadata table
flyway -configFiles=conf/flyway-local.conf baseline      # Baseline existing database

# View all resources in namespace
kubectl get all -n contestgrid

# Port forward to any service
kubectl port-forward -n contestgrid svc/<service-name> <local-port>:<service-port>

# Execute commands in pod
kubectl exec -it -n contestgrid <pod-name> -c <container-name> -- /bin/sh

# View logs with follow
kubectl logs -f -n contestgrid <pod-name> -c <container-name>

# Get resource YAML
kubectl get <resource> <name> -n contestgrid -o yaml

# Apply manifests from directory
kubectl apply -f k8s/ -n contestgrid

# Delete resource
kubectl delete <resource> <name> -n contestgrid

# Restart deployment (rolling)
kubectl rollout restart deployment/<name> -n contestgrid

# Scale deployment
kubectl scale deployment/<name> --replicas=3 -n contestgrid

# Check Istio proxy configuration
istioctl proxy-config routes deploy/<name> -n contestgrid
istioctl proxy-config listeners deploy/<name> -n contestgrid
istioctl proxy-config clusters deploy/<name> -n contestgrid

# Analyze Istio configuration issues
istioctl analyze -n contestgrid

# Check certificate status
kubectl get certificate -n contestgrid
kubectl describe certificate <name> -n contestgrid
```

---

## Additional Resources

- [Rancher Desktop Documentation](https://docs.rancherdesktop.io/)
- [Istio Documentation](https://istio.io/latest/docs/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Helm Documentation](https://helm.sh/docs/)
- [Flux Documentation](https://fluxcd.io/flux/)
- [Skaffold Documentation](https://skaffold.dev/docs/)
