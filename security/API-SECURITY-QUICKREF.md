# API Security & Infrastructure Best Practices - Quick Reference

This document provides a quick reference for all security and infrastructure best practices documented in [ADR-0032](adr/0032-infrastructure-and-api-security.md).

## 🔒 API Security Checklist

### SSL/TLS Configuration
- ✅ **TLS 1.3** minimum for all external traffic
- ✅ **TLS 1.2** with strong ciphers only (fallback)
- ✅ **mTLS** (mutual TLS) for service-to-service communication (automatic with Istio)
- ✅ **HTTPS everywhere** - no unencrypted endpoints
- ✅ **Automatic HTTP → HTTPS redirect**
- ✅ **HSTS headers** with `max-age=31536000; includeSubDomains; preload`

### Certificate Management
- ✅ **cert-manager** with Let's Encrypt for automated certificate issuance and renewal
- ✅ **AWS ACM** integration for managed certificates (ELB/CloudFront)
- ✅ **Wildcard certificates** for `*.contestgrid.com`
- ✅ **90-day expiration alerts** via Prometheus
- ✅ **Automatic renewal** 30 days before expiration

### Authentication & Authorization
- ✅ **JWT tokens** from AWS Cognito (OIDC with PKCE flow)
- ✅ **Short-lived access tokens** (15 minutes)
- ✅ **Refresh tokens** (7 days) with rotation
- ✅ **Bearer token** format: `Authorization: Bearer <jwt>`
- ✅ **JWKS validation** via Istio RequestAuthentication
- ✅ **Scope-based authorization** (`leagues:read`, `teams:write`, etc.)
- ✅ **Tenant isolation** enforced in token claims (`tenantId`)
- ✅ **Role-based access control** (platform-admin, league-admin, official, etc.)

### API Token Best Practices
```yaml
# Istio JWT validation example
apiVersion: security.istio.io/v1beta1
kind: RequestAuthentication
metadata:
  name: jwt-auth
spec:
  jwtRules:
  - issuer: "https://cognito-idp.us-east-1.amazonaws.com/us-east-1_XXXXX"
    jwksUri: "https://cognito-idp.us-east-1.amazonaws.com/us-east-1_XXXXX/.well-known/jwks.json"
    audiences: ["contestgrid-api"]
    forwardOriginalToken: true
```

### Rate Limiting & Throttling
- ✅ **Per-tenant quotas**: 100-1000 req/min based on subscription plan
- ✅ **Per-IP limits**: 1000 req/min (burst protection)
- ✅ **Response headers**: `X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Reset`
- ✅ **429 status code** with `Retry-After` header
- ✅ **Distributed rate limiting** with Redis for multi-pod deployments

### Input Validation & Sanitization
- ✅ **OpenAPI 3.1 schema validation** for all endpoints
- ✅ **Request size limits**: 10MB max (configurable per endpoint)
- ✅ **Content-Type enforcement**: `application/json`, `multipart/form-data` only
- ✅ **Parameterized queries** (prevent SQL injection)
- ✅ **XSS prevention**: Content Security Policy headers
- ✅ **CORS configuration**: Whitelist allowed origins

### API Versioning
- ✅ **URL versioning**: `/v1/leagues`, `/v2/leagues`
- ✅ **Header versioning**: `X-API-Version: 2` (optional)
- ✅ **Deprecation policy**: 6 months notice before removal
- ✅ **Sunset header**: `Sunset: Sat, 31 Dec 2026 23:59:59 GMT`
- ✅ **Support N-1 versions** (current + previous)

### Secrets Management
- ✅ **Never commit secrets to Git** (use `.gitignore`, git-secrets)
- ✅ **AWS Secrets Manager** for centralized secret storage
- ✅ **External Secrets Operator** to sync secrets to Kubernetes
- ✅ **Automatic rotation** every 90 days
- ✅ **IAM roles** for service-to-service auth (no hardcoded API keys)
- ✅ **Kubernetes ServiceAccounts** with IRSA (IAM Roles for Service Accounts)

---

## 🏗️ Infrastructure Components

### Local Development: Rancher Desktop
- **Kubernetes**: K3s 1.28+ (lightweight, built-in with Rancher Desktop)
- **Container Runtime**: containerd
- **Installation**: 
  ```bash
  brew install rancher-desktop  # macOS
  # or download from https://rancherdesktop.io/
  ```
- **Resources**: Configure 8GB RAM, 4 CPUs in Preferences
- **Ingress**: Traefik (pre-installed) or Istio Gateway
- **Storage**: Local path provisioner (automatic)
- **Load Balancer**: Built-in K3s ServiceLB

### Production: Container Orchestration
- **Kubernetes**: Version 1.28+ on Amazon EKS
- **Node groups**: Multi-AZ deployment across 3 availability zones
- **Autoscaling**: Cluster Autoscaler or Karpenter for dynamic scaling
- **Networking**: AWS VPC CNI with security groups for pods

### GitOps with Flux CD
- **Repository structure**: `infrastructure/clusters/{env}/apps/`
- **Automatic synchronization**: Flux reconciles every 5 minutes
- **Image automation**: Auto-update deployments when new images pushed to ECR
- **Progressive delivery**: Canary deployments with Flagger

### Helm for Package Management
- **All applications** packaged as Helm charts
- **Semantic versioning**: `chart-version: 1.2.3`
- **Values hierarchy**: base → environment → tenant-specific
- **Chart repository**: AWS ECR (OCI registry) or ChartMuseum

### Service Mesh with Istio
- **Version**: Istio 1.20+
- **mTLS**: STRICT mode enforced (no plaintext service-to-service traffic)
- **Traffic management**: Canary deployments, retries, timeouts, circuit breaking
- **Authorization**: Service-level RBAC with AuthorizationPolicy
- **Observability**: Automatic distributed tracing with Jaeger

### Certificate Management
```yaml
# cert-manager Certificate resource
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: contestgrid-tls
spec:
  secretName: contestgrid-tls-secret
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
  - contestgrid.com
  - "*.contestgrid.com"
  - api.contestgrid.com
```

### Secrets Synchronization
```yaml
# External Secrets Operator
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: contest-db-credentials
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets-manager
  target:
    name: contest-db-secret
  data:
  - secretKey: password
    remoteRef:
      key: prod/contestgrid/db
      property: password
```

---

## 📊 Observability Stack

### Metrics (Prometheus + Grafana)
- **Prometheus**: Scrape Istio + application metrics every 15s
- **Grafana**: Pre-built dashboards for RED metrics (Rate, Errors, Duration)
- **Kube-State-Metrics**: Cluster health and resource utilization
- **Custom metrics**: Business KPIs (contests created, officials assigned, invoices paid)

### Distributed Tracing (Jaeger)
- **Automatic instrumentation** via Istio Envoy sidecars
- **Trace sampling**: 100% for errors, 10% for successful requests
- **Trace propagation**: W3C Trace Context headers
- **Retention**: 7 days in Jaeger, 30 days in S3

### Logging (Fluentd + CloudWatch)
- **Structured JSON logs** with `requestId`, `tenantId`, `userId`, `traceId`
- **Log aggregation**: Fluentd DaemonSet forwards to CloudWatch Logs
- **Retention**: 90 days hot storage, 1 year archive in S3
- **Security**: Redact PII from logs (SSN, credit cards, passwords)

### Alerting (Prometheus Alertmanager)
```yaml
# Critical alerts
- High error rate: >1% 5xx responses (5-minute window)
- High latency: p99 > 2 seconds (5-minute window)
- Pod crashes: >3 restarts in 10 minutes
- Certificate expiration: <30 days until expiry
- Rate limit violations: Tenant exceeds 80% of quota
- Database connections: >80% of pool exhausted
```

---

## 🚀 Deployment Pipeline

### CI/CD Workflow
```
Developer Push → GitHub Actions → Build/Test → Push Image to ECR
  → Update Git with new image tag → Flux detects change
  → Apply Helm chart → Istio progressive rollout → Production
```

### GitHub Actions Pipeline
1. **Build**: Docker multi-stage build with layer caching
2. **Test**: Unit tests (Vitest), integration tests (MSW), E2E (Playwright)
3. **Scan**: Trivy image scanning for CVEs
4. **Push**: Tag and push to Amazon ECR
5. **Deploy**: Update Flux HelmRelease with new image tag
6. **Verify**: Smoke tests against staging environment

### Progressive Delivery
```yaml
# Flagger canary deployment
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: contestgrid-core-sys
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: contestgrid-core-sys
  service:
    port: 8080
  analysis:
    interval: 1m
    threshold: 5
    maxWeight: 50
    stepWeight: 10
    metrics:
    - name: request-success-rate
      thresholdRange:
        min: 99
    - name: request-duration
      thresholdRange:
        max: 500
```

---

## 🔐 Security Hardening

### Pod Security
```yaml
# Restricted security context
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 1000
  readOnlyRootFilesystem: true
  allowPrivilegeEscalation: false
  capabilities:
    drop: ["ALL"]
  seccompProfile:
    type: RuntimeDefault
```

### Network Policies
- **Default deny**: Block all traffic by default
- **Explicit allow**: Whitelist specific service-to-service communication
- **Egress control**: Limit external access to approved APIs only
- **Namespace isolation**: Separate tenants/environments with NetworkPolicies

### Image Security
- **Base images**: Distroless or Alpine-based (minimal attack surface)
- **Vulnerability scanning**: Trivy in CI/CD pipeline
- **Admission control**: Block images with HIGH/CRITICAL CVEs
- **Image signing**: Cosign for supply chain security
- **Private registry**: Amazon ECR with IAM-based access control

### RBAC & IAM
- **Kubernetes RBAC**: Least-privilege ServiceAccounts
- **IRSA**: IAM Roles for Service Accounts (no access keys in pods)
- **Audit logging**: Enable EKS control plane audit logs
- **MFA enforcement**: Require MFA for human access to AWS console

---

## 📋 Infrastructure Decision Matrix

| Requirement | Local Dev (Rancher) | Production (EKS) | AWS-Native |
|-------------|---------------------|------------------|------------|
| **Time to Setup** | 30 minutes | 3-4 weeks | 1-2 weeks |
| **Operational Complexity** | Low | High | Low |
| **Cost** | Free | $800-1500/mo | $500-1000/mo |
| **Scalability** | Limited (single node) | Excellent | Good |
| **Portability** | High | High | Low (AWS-locked) |
| **Service Mesh** | Full (Istio) | Full (Istio) | Limited |
| **mTLS** | Automatic | Automatic | Manual |
| **GitOps** | Local Flux | Native (Flux) | Via CDK/TF |
| **Production Parity** | ✅ Identical | ✅ Production | ❌ Different |
| **Offline Development** | ✅ Yes | ❌ No | ❌ No |
| **Team Expertise Required** | K8s basics | K8s + Istio + SRE | AWS basics |

### Recommendation
- **For Local Development**: **Rancher Desktop** with K3s (infrastructure parity with production)
- **For Production**: **Kubernetes on EKS** with Istio service mesh
- **Best Path**: Develop on Rancher, deploy to EKS with **identical Helm charts** and manifests

### Infrastructure Parity Benefits
✅ Same Kubernetes manifests work in both environments
✅ Same Helm charts (just different values files)
✅ Same Istio configurations
✅ Test entire stack locally before deploying
✅ Reproduce production issues on your laptop
✅ Work offline without AWS costs

---

## � Local Development with Rancher Desktop

### Quick Start Setup
```bash
# 1. Install Rancher Desktop
brew install rancher-desktop  # macOS
# Windows: choco install rancher-desktop
# Linux: Download AppImage from https://rancherdesktop.io/

# 2. Start Rancher Desktop and verify
kubectl cluster-info
kubectl get nodes

# 3. Create namespace
kubectl create namespace contestgrid
kubectl label namespace contestgrid istio-injection=enabled

# 4. Install infrastructure components
# Install Flux CD
flux install

# Install Istio (service mesh)
curl -L https://istio.io/downloadIstio | sh -
cd istio-*/
export PATH=$PWD/bin:$PATH
istioctl install --set profile=demo -y

# Install cert-manager (self-signed certs for local)
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.0/cert-manager.yaml

# Create self-signed issuer
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned-issuer
spec:
  selfSigned: {}
EOF

# 5. Install PostgreSQL
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install contest-db bitnami/postgresql \
  --namespace contestgrid \
  --set auth.username=postgres \
  --set auth.password=localdevpassword \
  --set auth.database=contestdb

# 6. Install Flyway (database migrations)
brew install flyway  # macOS
# or: choco install flyway.commandline  # Windows

# Configure Flyway for local development (consolidated workspace folder)
cd ../flyway
cp conf/flyway-local.conf.example conf/flyway-local.conf

# Port forward and run migrations
kubectl port-forward -n contestgrid svc/contest-db-postgresql 5432:5432 &
flyway -configFiles=conf/flyway-local.conf migrate

# 7. Set up local DNS (add to /etc/hosts)
echo "127.0.0.1 contestgrid.local api.contestgrid.local" | sudo tee -a /etc/hosts

# 8. Deploy your application
kubectl apply -f k8s/local/ -n contestgrid

# 9. Port forward to access locally
kubectl port-forward -n contestgrid svc/contestgrid-core-sys 8080:80
```

### Local Development Workflow
```bash
# Build Docker image (uses local Docker daemon via Rancher Desktop)
docker build -t contestgrid-core-sys:dev .

# Run database migrations (if schema changed)
kubectl port-forward -n contestgrid svc/contest-db-postgresql 5432:5432 &
cd ../flyway
flyway -configFiles=conf/flyway-local.conf info
flyway -configFiles=conf/flyway-local.conf migrate

# Deploy to local K8s
kubectl set image deployment/contestgrid-core-sys contestgrid-core-sys=contestgrid-core-sys:dev -n contestgrid

# Or use Skaffold for automatic rebuilds
skaffold dev --port-forward

# View logs
kubectl logs -f -l app=contestgrid-core-sys -n contestgrid

# Access services
# API: https://api.contestgrid.local (via Istio Gateway)
# Direct: http://localhost:8080 (via port-forward)
```

### Testing mTLS Locally
```bash
# Verify mTLS is enforced between services
kubectl exec -n contestgrid deploy/contestgrid-core-sys -c istio-proxy -- \
  curl -v http://contest-db:5432

# Should see TLS handshake in logs

# Check Istio proxy certificates
istioctl proxy-config secret deploy/contestgrid-core-sys -n contestgrid
```

### Local Secrets Management
```bash
# Create secrets for local development
kubectl create secret generic contest-db-secret \
  --from-literal=username=postgres \
  --from-literal=password=localdevpassword \
  --from-literal=database=contestdb \
  -n contestgrid

# Or use .env file (never commit!)
kubectl create secret generic contestgrid-core-sys-config \
  --from-env-file=.env.local \
  -n contestgrid

# View secrets (base64 encoded)
kubectl get secret contest-db-secret -n contestgrid -o yaml
```

### Debugging Tips
```bash
# Flyway commands
cd ../flyway
flyway -configFiles=conf/flyway-local.conf info       # Show migration status
flyway -configFiles=conf/flyway-local.conf validate   # Validate migrations
flyway -configFiles=conf/flyway-local.conf repair     # Fix metadata checksums

# Check database schema
kubectl exec -n contestgrid contest-db-postgresql-0 -c postgresql -- \
  psql -U postgres -d contestdb -c "\\dt"

# View migration history
kubectl exec -n contestgrid contest-db-postgresql-0 -c postgresql -- \
  psql -U postgres -d contestdb -c "SELECT * FROM flyway_schema_history;"

# Check Istio sidecar injection
kubectl get pods -n contestgrid -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].name}{"\n"}{end}'

# Should see: app-container istio-proxy

# View Istio configuration
istioctl analyze -n contestgrid

# Check certificate status
kubectl get certificate -n contestgrid

# Restart pods to pick up new configs
kubectl rollout restart deployment -n contestgrid

# Access Kiali dashboard (service mesh visualization)
istioctl dashboard kiali

# Access Grafana (metrics)
istioctl dashboard grafana

# Access Jaeger (distributed tracing)
istioctl dashboard jaeger
```

---

## 🔗 External Resources

- **Primary ADR**: [ADR-0032: Infrastructure & API Security](adr/0032-infrastructure-and-api-security.md)
- **Related ADRs**:
  - [ADR-0004: Authentication & Authorization](adr/0004-auth-aws-rbac.md)
  - [ADR-0005: API Standards](adr/0005-api-standards.md)
  - [ADR-0006: Architecture (BFF Pattern)](adr/0006-architecture-bff-proc-system.md)
  - [ADR-0015: Data Protection & Encryption](adr/0015-data-protection-and-encryption.md)

## 🔗 External Resources
- [OWASP API Security Top 10](https://owasp.org/API-Security/)
- [Kubernetes Security Best Practices](https://kubernetes.io/docs/concepts/security/)
- [Istio Security Documentation](https://istio.io/latest/docs/concepts/security/)
- [Flux GitOps Toolkit](https://fluxcd.io/flux/)
- [cert-manager Documentation](https://cert-manager.io/docs/)
- [12-Factor App Methodology](https://12factor.net/)
