# SSL/TLS Implementation Standard

## Decision

ContestGrid will use cert-manager as the standard tool for certificate generation and rotation in Kubernetes environments.

## Why This Tool

- Automated issuance and renewal
- Native integration with Istio ingress and Kubernetes secrets
- Supports local self-signed certs and production ACME workflows
- Aligns with existing ADR and infrastructure documentation

## Scope: "All Connections Over SSL"

- External traffic: HTTPS only (TLS 1.3 minimum, TLS 1.2 fallback)
- HTTP endpoint behavior: automatic HTTP to HTTPS redirect
- Service-to-service traffic: Istio mTLS in STRICT mode
- Database traffic: SSL enabled for PostgreSQL connections

## Certificate Sources by Environment

- Local: self-signed certificates via cert-manager ClusterIssuer
- Production (Kubernetes ingress): Let's Encrypt via cert-manager ACME ClusterIssuer
- Production AWS edge option: ACM-managed certificates for ALB/API Gateway/CloudFront

## Installed Locations

- TLS secret at ingress namespace/application namespace:
  - `contestgrid-tls-secret` in namespace `contestgrid`
- Istio Gateway references `credentialName: contestgrid-tls-secret`
- VirtualService routes HTTPS traffic to `contestgrid-core-sys` service

## Baseline Manifests Added

- `k8s/security/local/clusterissuer-selfsigned.yaml`
- `k8s/security/local/certificate-contestgrid-local.yaml`
- `k8s/security/prod/clusterissuer-letsencrypt-prod.yaml`
- `k8s/security/prod/certificate-contestgrid-prod.yaml`
- `k8s/ingress/contestgrid-gateway-tls.yaml`
- `k8s/ingress/contestgrid-virtualservice.yaml`
- `k8s/security/README.md`

## Initial Rollout Commands

```bash
kubectl apply -f k8s/security/local/clusterissuer-selfsigned.yaml
kubectl apply -f k8s/security/local/certificate-contestgrid-local.yaml
kubectl apply -f k8s/ingress/contestgrid-gateway-tls.yaml
kubectl apply -f k8s/ingress/contestgrid-virtualservice.yaml
```

## Validation

```bash
kubectl get certificate -n contestgrid
kubectl get secret contestgrid-tls-secret -n contestgrid
curl -I http://api.contestgrid.local
curl -I https://api.contestgrid.local
```

## Follow-up Required Before Production

- Replace ACME contact email in `clusterissuer-letsencrypt-prod.yaml`
- Confirm DNS records for `api.contestgrid.com`
- Confirm cert-manager HTTP-01 challenge strategy with ingress setup
- Add certificate expiry alerting in monitoring stack
