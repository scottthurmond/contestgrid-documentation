# ADR 0032: Infrastructure & API Security (Kubernetes, Service Mesh, GitOps)

## Status
Accepted

## Context
We need a modern, cloud-native infrastructure with industry-standard security practices for API protection, certificate management, secrets handling, and observable deployments. The platform requires scalability, zero-downtime deployments, automated SSL/TLS certificate management, and secure service-to-service communication.

## Decision
Adopt a **Kubernetes-based infrastructure** with GitOps workflows, service mesh for traffic management and security, and comprehensive observability. This complements or replaces AWS-managed services where container orchestration provides better control, portability, and standardization.

## Architecture Options

### Local Development: Rancher Desktop (K3s)
- **Compute**: Rancher Desktop with K3s (lightweight Kubernetes)
- **GitOps**: Flux CD for declarative deployments (same as production)
- **Package Management**: Helm charts (same as production)
- **Service Mesh**: Istio (same configuration as production)
- **Ingress**: Traefik (built-in) or Istio Gateway
- **Secrets**: Kubernetes Secrets (local), External Secrets Operator (AWS integration for testing)
- **TLS**: Self-signed certificates via cert-manager or mkcert
- **Observability**: Prometheus + Grafana (optional), logs to stdout
- **Database**: PostgreSQL via Helm chart or Docker container
- **Database Migrations**: Flyway 10+ for version-controlled schema changes
- **Storage**: Local path provisioner (built-in with Rancher Desktop)

**Pros**: Identical to production K8s, fast iteration, works offline, free
**Cons**: Limited resources, single-node cluster, manual setup

**Recommendation**: Use Rancher Desktop for all local development to ensure production parity.

### Production: Kubernetes on EKS (AWS)
- **Compute**: Amazon EKS (Elastic Kubernetes Service)
- **GitOps**: Flux CD for declarative deployments
- **Package Management**: Helm charts for application packaging
- **Service Mesh**: Istio for traffic management, security, observability
- **Ingress**: Istio Gateway or AWS Load Balancer Controller
- **Secrets**: External Secrets Operator with AWS Secrets Manager backend
- **TLS**: cert-manager with Let's Encrypt or AWS ACM integration
- **Observability**: Prometheus, Grafana, Jaeger, Kiali
- **Database**: Aurora PostgreSQL (managed)
- **Database Migrations**: Flyway 10+ for schema versioning and deployment
- **Storage**: EBS CSI driver, EFS for shared storage

**Pros**: Portable, industry-standard, rich ecosystem, fine-grained control, service mesh benefits
**Cons**: Higher operational complexity, requires Kubernetes expertise

### Alternative: AWS-Native (Lambda/API Gateway)
- **Compute**: Lambda functions, ECS Fargate
- **API Gateway**: AWS API Gateway with Cognito authorizers
- **Secrets**: AWS Secrets Manager
- **TLS**: AWS Certificate Manager (ACM)
- **Deployment**: AWS CDK or Terraform with GitHub Actions

**Pros**: Fully managed, less operational overhead, native AWS integrations
**Cons**: Vendor lock-in, limited service mesh capabilities, different from local dev

### Hybrid Approach
- **Frontend/BFF**: EKS with Istio
- **Backend Services**: Mix of EKS and Lambda (event-driven workloads)
- **Data Layer**: Managed services (RDS, OpenSearch, S3)

**Decision**: 
- **Development**: Rancher Desktop (K3s) for local iteration
- **Production**: Kubernetes on EKS with Istio service mesh
- **Infrastructure Parity**: Use identical Helm charts and Kubernetes manifests across environments

---

## Core Components

### 1. Kubernetes Cluster

#### Local Development (Rancher Desktop)
- **Version**: Rancher Desktop 1.12+ with K3s 1.28+
- **Resources**: 8GB RAM, 4 CPUs (configurable in Rancher Desktop settings)
- **Container Runtime**: containerd (default)
- **Networking**: Flannel CNI (built-in with K3s)
- **Storage**: Local path provisioner (automatic PVC provisioning)
- **Ingress**: Traefik (pre-installed) or Istio Gateway
- **Load Balancer**: Built-in K3s ServiceLB (MetalLB alternative)
- **Access**: kubectl configured automatically, contexts switch with Rancher Desktop

**Setup**:
```bash
# Install Rancher Desktop from https://rancherdesktop.io/
# Or via package manager:
brew install rancher-desktop  # macOS
choco install rancher-desktop # Windows
# Linux: Download AppImage from releases

# Verify installation
kubectl cluster-info
kubectl get nodes
```

#### Production (Amazon EKS)
- **Version**: EKS 1.28+ (latest stable)
- **Node Groups**: 
  - System nodes (control plane components): t3.medium
  - Application nodes (workloads): t3.large or c6i instances
  - Autoscaling with Cluster Autoscaler or Karpenter
- **Networking**: AWS VPC CNI with IPv4/IPv6 support
- **Storage**: EBS CSI driver for persistent volumes; EFS for shared storage
- **Multi-AZ**: Deploy across 3 availability zones for high availability

### 2. GitOps with Flux CD
- **Repository Structure**:
  ```
  infrastructure/
  ├── clusters/
  │   ├── production/
  │   │   ├── flux-system/       # Flux controllers
  │   │   ├── namespaces/        # Tenant namespaces
  │   │   ├── ingress/           # Istio gateway configs
  │   │   └── apps/              # Application deployments
  │   ├── staging/
  │   └── development/
  ├── base/                      # Base Kustomize configurations
  └── helm-releases/             # Helm chart references
  ```
- **Deployment Flow**:
  1. Developers merge to `main` branch
  2. GitHub Actions builds Docker images, pushes to ECR
  3. Flux detects image updates, applies manifests automatically
  4. Progressive rollout with Flagger (canary/blue-green)
- **Benefits**: Declarative, auditable, version-controlled infrastructure; automatic drift reconciliation

### 3. Helm for Package Management
- **Charts**: Create Helm charts for all applications:
  - `contestgrid-bff` (Backend for Frontend)
  - `contestgrid-api` (System services)
  - `contestgrid-processor` (Async workloads)
  - `contestgrid-frontend` (Static site or SPA)
- **Chart Repository**: ChartMuseum or AWS ECR (OCI registry)
- **Values Hierarchy**:
  ```
  values.yaml                    # Base defaults
  values-staging.yaml            # Staging overrides
  values-production.yaml         # Production overrides
  values-tenant-specific.yaml    # Per-tenant customization
  ```
- **Versioning**: Semantic versioning for chart releases

### 4. Service Mesh with Istio
- **Version**: Istio 1.20+
- **Components**:
  - **Istiod**: Control plane (installed via Helm)
  - **Istio Gateway**: Ingress/egress traffic management
  - **Envoy Sidecars**: Automatic sidecar injection per namespace
- **Features**:
  - **mTLS**: Automatic mutual TLS for all service-to-service communication
  - **Traffic Management**: Canary deployments, traffic splitting, retries, timeouts
  - **Security**: Authorization policies (RBAC for services), request authentication (JWT validation)
  - **Observability**: Distributed tracing, metrics, access logs

#### Traffic Management Example
```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: contestgrid-core-sys
spec:
  hosts:
  - api.contestgrid.com
  http:
  - match:
    - headers:
        x-api-version:
          exact: "v2"
    route:
    - destination:
        host: contestgrid-core-sys-v2
        port:
          number: 8080
  - route:
    - destination:
        host: contestgrid-core-sys-v1
        port:
          number: 8080
      weight: 90
    - destination:
        host: contestgrid-core-sys-v2
        port:
          number: 8080
      weight: 10  # Canary 10% traffic
```

#### mTLS Configuration
```yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: contestgrid
spec:
  mtls:
    mode: STRICT  # Enforce mTLS for all services
```

#### Authorization Policy
```yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: contestgrid-core-sys-authz
spec:
  selector:
    matchLabels:
      app: contestgrid-core-sys
  action: ALLOW
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/contestgrid/sa/bff"]
    to:
    - operation:
        methods: ["GET", "POST", "PUT", "PATCH", "DELETE"]
        paths: ["/v1/*"]
    when:
    - key: request.auth.claims[tenant_id]
      values: ["*"]  # Must have tenant_id claim
```

---

## API Security Best Practices

### 1. HTTPS/TLS Everywhere
- **External Traffic**: TLS 1.3 minimum; TLS 1.2 with strong ciphers only
- **Certificate Management**:
  - **Local Development**: Self-signed certs via cert-manager + CA issuer, or mkcert for localhost
  - **Production**: cert-manager with Let's Encrypt (ACME) or AWS ACM Private CA
  - **Certificates**: Wildcard certs for `*.contestgrid.com` or per-subdomain

- **Local Development Configuration** (self-signed CA):
  ```yaml
  # Install mkcert for easy local certs
  brew install mkcert  # macOS
  mkcert -install
  mkcert "*.contestgrid.local" localhost 127.0.0.1 ::1
  
  # Or use cert-manager with self-signed ClusterIssuer
  apiVersion: cert-manager.io/v1
  kind: ClusterIssuer
  metadata:
    name: selfsigned-issuer
  spec:
    selfSigned: {}
  ```

- **Production Configuration**:
  ```yaml
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

### 2. API Authentication & Authorization
- **JWT Validation**: Istio RequestAuthentication with JWKS endpoint
  ```yaml
  apiVersion: security.istio.io/v1beta1
  kind: RequestAuthentication
  metadata:
    name: jwt-auth
  spec:
    selector:
      matchLabels:
        app: contestgrid-core-sys
    jwtRules:
    - issuer: "https://cognito-idp.us-east-1.amazonaws.com/us-east-1_XXXXX"
      jwksUri: "https://cognito-idp.us-east-1.amazonaws.com/us-east-1_XXXXX/.well-known/jwks.json"
      audiences:
      - "contestgrid-api"
      forwardOriginalToken: true  # Pass token to backend
  ```
- **API Keys**: For machine-to-machine authentication (stored in Secrets)
- **OAuth2/OIDC**: Cognito or external IdP (Auth0, Okta) via Istio OAuth2 filter
- **Token Refresh**: Short-lived access tokens (15 min); refresh tokens (7 days) with rotation

### 3. API Rate Limiting & Throttling
- **Istio EnvoyFilter** for rate limiting:
  ```yaml
  apiVersion: networking.istio.io/v1alpha3
  kind: EnvoyFilter
  metadata:
    name: rate-limit
  spec:
    workloadSelector:
      labels:
        app: contestgrid-core-sys
    configPatches:
    - applyTo: HTTP_FILTER
      match:
        context: SIDECAR_INBOUND
      patch:
        operation: INSERT_BEFORE
        value:
          name: envoy.filters.http.local_ratelimit
          typed_config:
            "@type": type.googleapis.com/envoy.extensions.filters.http.local_ratelimit.v3.LocalRateLimit
            stat_prefix: http_local_rate_limiter
            token_bucket:
              max_tokens: 100
              tokens_per_fill: 100
              fill_interval: 60s  # 100 req/min per pod
  ```
- **Per-Tenant Limits**: Enforce in application layer with Redis (distributed rate limiting)
- **Headers**: Return `X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Reset`, `Retry-After`

### 4. Secrets Management

#### Local Development
- **Kubernetes Secrets**: Store secrets directly in cluster for local dev
  ```bash
  # Create secrets from files or literals
  kubectl create secret generic contest-db-secret \
    --from-literal=username=postgres \
    --from-literal=password=localdevpassword \
    -n contestgrid
  
  # Or use .env files (never commit!)
  kubectl create secret generic contestgrid-core-sys-config \
    --from-env-file=.env.local \
    -n contestgrid
  ```
- **Sealed Secrets** (optional): Encrypt secrets in Git for local development
  ```bash
  kubeseal --format yaml < secret.yaml > sealed-secret.yaml
  ```

#### Production (AWS Integration)
- **External Secrets Operator**: Sync secrets from AWS Secrets Manager to Kubernetes Secrets
  ```yaml
  apiVersion: external-secrets.io/v1beta1
  kind: SecretStore
  metadata:
    name: aws-secrets-manager
  spec:
    provider:
      aws:
        service: SecretsManager
        region: us-east-1
        auth:
          jwt:
            serviceAccountRef:
              name: external-secrets
  ---
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
      creationPolicy: Owner
    data:
    - secretKey: username
      remoteRef:
        key: prod/contestgrid/db
        property: username
    - secretKey: password
      remoteRef:
        key: prod/contestgrid/db
        property: password
  ```

#### Best Practices (All Environments)
- **Never Commit Secrets**: Use `.gitignore`, secret scanning (git-secrets, GitHub Advanced Security)
- **Rotation**: Automate secret rotation (90 days in production); manual updates in local dev
- **Least Privilege**: Grant minimal permissions needed per service

### 5. Service-to-Service Security
- **mTLS Everywhere**: Istio enforces automatic mutual TLS between all services
- **Authorization Policies**: Define which services can call which endpoints (zero-trust model)
- **Service Accounts**: Kubernetes ServiceAccounts per workload with IAM roles (IRSA for AWS)
- **Network Policies**: Calico or built-in Kubernetes NetworkPolicies for pod-level firewall rules
  ```yaml
  apiVersion: networking.k8s.io/v1
  kind: NetworkPolicy
  metadata:
    name: contestgrid-core-sys-netpol
  spec:
    podSelector:
      matchLabels:
        app: contestgrid-core-sys
    policyTypes:
    - Ingress
    - Egress
    ingress:
    - from:
      - podSelector:
          matchLabels:
            app: bff
      ports:
      - protocol: TCP
        port: 8080
    egress:
    - to:
      - podSelector:
          matchLabels:
            app: postgres
      ports:
      - protocol: TCP
        port: 5432
  ```

### 6. API Versioning & Compatibility
- **URL Versioning**: `/v1/leagues`, `/v2/leagues`
- **Header Versioning**: `X-API-Version: 2` with fallback to v1
- **Deprecation Policy**: 
  - Announce deprecation 6 months before removal
  - Return `Sunset` header with EOL date
  - Support N-1 version (current + previous)

### 7. Input Validation & Sanitization
- **Schema Validation**: OpenAPI 3.1 specs with request/response validation
- **Size Limits**: Max request body 10MB; configurable per endpoint
- **Content-Type Enforcement**: Accept only `application/json`, `multipart/form-data`
- **SQL Injection Prevention**: Use parameterized queries, ORM with prepared statements
- **XSS Prevention**: Sanitize output, use Content Security Policy (CSP) headers

---

## Observability & Monitoring

### 1. Metrics (Prometheus + Grafana)
- **Prometheus**: Scrape metrics from Istio, application exporters
- **Grafana**: Dashboards for RED metrics (Rate, Errors, Duration)
- **Kube-State-Metrics**: Cluster and workload health
- **Custom Metrics**: Application-specific metrics (business KPIs)

### 2. Distributed Tracing (Jaeger)
- **Istio Integration**: Automatic span propagation via Envoy
- **Application Instrumentation**: OpenTelemetry SDKs in services
- **Sampling**: 100% for errors, 1-10% for success (configurable)

### 3. Logging (Fluentd + CloudWatch/Elasticsearch)
- **Structured Logging**: JSON format with `requestId`, `tenantId`, `userId`, `traceId`
- **Log Aggregation**: Fluentd DaemonSet forwards to CloudWatch Logs or ELK stack
- **Retention**: 90 days hot, 1 year cold (archive to S3)

### 4. Alerting (Prometheus Alertmanager)
- **Alerts**:
  - High error rate (>1% 5xx responses)
  - High latency (p99 > 2s)
  - Pod restarts, OOMKills
  - Certificate expiration (<30 days)
  - Rate limit violations (>80% of quota)
- **Notification Channels**: Slack, PagerDuty, email

---

## Deployment Pipeline

### CI/CD Workflow (GitHub Actions)
```yaml
# .github/workflows/production-deploy.yml
name: Production Deploy

on:
  push:
    branches: [main]

jobs:
  build-push:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    - name: Build Docker image
      run: docker build -t contestgrid-core-sys:${{ github.sha }} .
    - name: Push to ECR
      run: |
        aws ecr get-login-password | docker login --username AWS --password-stdin $ECR_REGISTRY
        docker tag contestgrid-core-sys:${{ github.sha }} $ECR_REGISTRY/contestgrid-core-sys:${{ github.sha }}
        docker tag contestgrid-core-sys:${{ github.sha }} $ECR_REGISTRY/contestgrid-core-sys:latest
        docker push $ECR_REGISTRY/contestgrid-core-sys:${{ github.sha }}
        docker push $ECR_REGISTRY/contestgrid-core-sys:latest
    - name: Update Flux image tag
      run: |
        yq e '.spec.values.image.tag = "${{ github.sha }}"' -i infrastructure/clusters/production/apps/contestgrid-core-sys/helmrelease.yaml
        git config user.name "GitHub Actions"
        git config user.email "actions@github.com"
        git add infrastructure/
        git commit -m "Update contestgrid-core-sys to ${{ github.sha }}"
        git push
```

### Flux HelmRelease
```yaml
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: contestgrid-core-sys
  namespace: contestgrid
spec:
  interval: 5m
  chart:
    spec:
      chart: contestgrid-core-sys
      version: '>=1.0.0'
      sourceRef:
        kind: HelmRepository
        name: contest-charts
  values:
    image:
      repository: 123456789.dkr.ecr.us-east-1.amazonaws.com/contestgrid-core-sys
      tag: abc123def456  # Updated by CI
    replicas: 3
    autoscaling:
      enabled: true
      minReplicas: 3
      maxReplicas: 20
      targetCPUUtilizationPercentage: 70
    resources:
      requests:
        cpu: 500m
        memory: 512Mi
      limits:
        cpu: 2000m
        memory: 2Gi
    istio:
      enabled: true
      mTLS: STRICT
    env:
    - name: DATABASE_URL
      valueFrom:
        secretKeyRef:
          name: contest-db-secret
          key: url
```

---

## Security Hardening

### 1. Pod Security Standards
- **Restricted Profile**: No privileged containers, read-only root filesystem
  ```yaml
  apiVersion: v1
  kind: Pod
  metadata:
    name: contestgrid-core-sys
  spec:
    securityContext:
      runAsNonRoot: true
      runAsUser: 1000
      fsGroup: 1000
      seccompProfile:
        type: RuntimeDefault
    containers:
    - name: api
      securityContext:
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        capabilities:
          drop: ["ALL"]
      volumeMounts:
      - name: tmp
        mountPath: /tmp
    volumes:
    - name: tmp
      emptyDir: {}
  ```

### 2. Image Scanning
- **Trivy**: Scan images for CVEs in CI pipeline
- **Admission Controller**: Deny images with HIGH/CRITICAL vulnerabilities
- **Base Images**: Use distroless or Alpine-based images

### 3. Runtime Security
- **Falco**: Detect anomalous behavior (unexpected processes, file access)
- **OPA Gatekeeper**: Policy enforcement (required labels, resource limits)

### 4. RBAC & IAM
- **Kubernetes RBAC**: Least-privilege access for ServiceAccounts
- **IRSA (IAM Roles for Service Accounts)**: Grant AWS permissions without access keys
- **Audit Logging**: Enable EKS control plane audit logs

---

## Development to Production Path

### Phase 0: Local Development Setup (Week 1)
1. Install Rancher Desktop with K3s
2. Set up local Flux CD repository structure
3. Install Istio, cert-manager (with self-signed CA)
4. Deploy PostgreSQL via Helm chart
5. Create namespace and RBAC resources
6. Build and deploy applications locally
7. Test with local DNS (`*.contestgrid.local` via /etc/hosts)

### Phase 1: Production Cluster Setup (Weeks 2-3)
1. Provision EKS cluster with eksctl or Terraform
2. Install identical stack: Flux, Istio, cert-manager, External Secrets Operator
3. Configure AWS integrations (RDS, Secrets Manager, ECR)
4. Set up CI/CD pipeline (GitHub Actions → ECR → Flux)
5. Deploy staging environment first

### Phase 2: Production Deployment (Weeks 4-5)
1. Deploy applications to EKS using same Helm charts as local
2. Configure production DNS and TLS certificates
3. Set up monitoring (Prometheus, Grafana, Jaeger)
4. Load testing and performance tuning
5. Blue-green deployment strategy

### Phase 3: Optimization (Weeks 6-8)
1. Fine-tune resource requests/limits based on metrics
2. Implement autoscaling (HPA, VPA, Cluster Autoscaler)
3. Advanced Istio features (circuit breaking, fault injection)
4. Multi-region setup (if needed)
5. Cost optimization

### Infrastructure Parity Benefits
- **Same Helm charts** work in local Rancher Desktop and production EKS
- **Same Istio configs** ensure consistent security and traffic management
- **Same Flux manifests** enable GitOps workflow in both environments
- **Faster debugging**: Reproduce production issues locally
- **Lower costs**: Develop and test entirely offline

---

## Consequences

### Pros
- **Industry Standard**: Portable, widely adopted, rich ecosystem
- **Security**: mTLS by default, fine-grained authorization, automated certificate management
- **Observability**: Deep insights with distributed tracing, metrics, logs
- **GitOps**: Declarative, auditable, version-controlled deployments
- **Scalability**: Horizontal scaling, autoscaling, multi-region support
- **Cost Efficiency**: Better resource utilization vs Lambda for steady-state workloads

### Cons
- **Complexity**: Steeper learning curve, more operational overhead
- **Initial Investment**: Cluster setup, learning Istio/Flux/Helm
- **Operational Burden**: Need SRE/DevOps expertise for ongoing maintenance

### Mitigations
- **Managed Services**: Use EKS (not self-managed K8s), AWS RDS, S3
- **Automation**: Terraform modules, Flux for GitOps, automated scaling
- **Training**: Invest in team upskilling (Kubernetes, Istio, Helm)
- **Observability**: Comprehensive monitoring to detect issues early

---

## Related ADRs
- ADR-0004: Authentication & Authorization (JWT validation in Istio)
- ADR-0005: API Standards (rate limits, versioning, error handling)
- ADR-0006: Architecture (BFF pattern compatible with service mesh)
- ADR-0015: Data Protection & Encryption (mTLS, TLS 1.3)

---

## References
- [Kubernetes Best Practices](https://kubernetes.io/docs/concepts/security/)
- [Istio Security](https://istio.io/latest/docs/concepts/security/)
- [Flux GitOps Toolkit](https://fluxcd.io/flux/)
- [Helm Best Practices](https://helm.sh/docs/chart_best_practices/)
- [cert-manager Documentation](https://cert-manager.io/docs/)
- [External Secrets Operator](https://external-secrets.io/)
- [OWASP API Security Top 10](https://owasp.org/API-Security/editions/2023/en/0x11-t10/)
