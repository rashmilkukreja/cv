# How I Installed a Helm Chart on AWS EKS with ALB, Prometheus, Grafana, and HPA

In this article, I’ll walk through the exact process I followed to deploy my CV application on an AWS EKS cluster using Helm.

The cluster was already created using Terraform, and the AWS Load Balancer Controller was installed as part of the infrastructure setup. The next goal was to deploy the application Helm chart, expose it through an internet-facing AWS Application Load Balancer, and enable observability with Prometheus and Grafana.

## What Was Deployed

The Helm chart deployed the following Kubernetes resources:

- CV application Deployment
- Apache exporter sidecar
- NodePort Service
- AWS ALB Ingress
- HorizontalPodAutoscaler
- kube-prometheus-stack
- Prometheus
- Grafana
- ServiceMonitor
- PrometheusRule alerts
- Grafana dashboard ConfigMap

The application container serves the CV website on port `80`, while the Apache exporter sidecar exposes metrics on port `9117`.

## Step 1: Configure kubectl for the EKS Cluster

First, I updated my local kubeconfig so `kubectl` and Helm could connect to the EKS cluster.

```bash
aws eks update-kubeconfig \
  --name eks \
  --region ap-south-1
```

Then I verified the current context:

```bash
kubectl config current-context
```

I also checked that the node group had joined the cluster:

```bash
kubectl get nodes -o wide
```

The expected result was a Ready EKS worker node.

## Step 2: Verify Cluster Add-ons

Before installing the application chart, I checked the cluster system pods:

```bash
kubectl get pods -A
```

The important component for public traffic was the AWS Load Balancer Controller:

```bash
kubectl get pods -n kube-system
```

The controller was already running, which meant Kubernetes Ingress resources could create AWS ALBs automatically.

## Step 3: Add the Helm Repository for Dependencies

The chart depends on `kube-prometheus-stack`, so I added the Prometheus community Helm repository:

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
```

Then I updated the chart dependencies:

```bash
helm dependency update helm/cv-chart
```

This generated a `Chart.lock` file and downloaded the required dependency chart.

## Step 4: Validate the Helm Chart

Before installing anything into the cluster, I linted the chart:

```bash
helm lint helm/cv-chart
```

I also rendered the chart locally:

```bash
helm template cv helm/cv-chart \
  --namespace cv \
  --set ingress.enabled=true \
  --set ingress.host=""
```

This helped catch template issues before applying resources to Kubernetes.

## Step 5: Fix Helm Template Issues

During validation, I found and fixed a few chart issues.

### Grafana Template Escaping

The Grafana dashboard used Prometheus legend templates like:

```text
{{state}}
```

Helm tried to parse this as a Helm function. The fix was to escape it:

```text
{{`{{state}}`}}
```

### Metrics Port Exposure

The Apache exporter exposed metrics on container port `9117`, but the Kubernetes Service also needed to expose that port with a name.

```yaml
ports:
  - name: http
    port: 80
    targetPort: 80
  - name: metrics
    port: 9117
    targetPort: metrics
```

This allowed the ServiceMonitor to scrape the correct endpoint.

### HPA CPU Metrics

The HPA initially showed:

```text
cpu: <unknown>/50%
```

The issue was that the Apache exporter sidecar did not have CPU requests. For HPA CPU utilization to work properly, all containers in the pod should have CPU requests.

I added exporter resource requests:

```yaml
exporter:
  resources:
    limits:
      cpu: 100m
      memory: 128Mi
    requests:
      cpu: 50m
      memory: 64Mi
```

After this, the HPA started reporting correctly.

## Step 6: Install the Helm Chart

Once the chart passed validation, I installed it with Helm:

```bash
helm upgrade --install cv helm/cv-chart \
  --namespace cv \
  --create-namespace \
  --set ingress.enabled=true \
  --set ingress.host="" \
  --wait \
  --timeout 15m
```

Explanation of the command:

- `upgrade --install` installs the release if it does not exist, or upgrades it if it already exists.
- `cv` is the Helm release name.
- `helm/cv-chart` is the chart path.
- `--namespace cv` deploys into the `cv` namespace.
- `--create-namespace` creates the namespace if needed.
- `ingress.enabled=true` enables ALB ingress creation.
- `ingress.host=""` creates a hostless ingress so the ALB can serve traffic directly.
- `--wait` waits for Kubernetes resources to become ready.
- `--timeout 15m` gives enough time for Prometheus, Grafana, and the app pods to start.

## Step 7: Install Metrics Server

The HPA needs the Kubernetes Metrics API. On the fresh EKS cluster, Metrics Server was not available, so I installed it:

```bash
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
```

```bash
helm upgrade --install metrics-server metrics-server/metrics-server \
  --namespace kube-system \
  --wait \
  --timeout 5m
```

Then I verified metrics:

```bash
kubectl top pods -n cv
```

## Step 8: Verify the Helm Release

I checked the Helm release status:

```bash
helm status cv -n cv
```

I also listed all deployed resources:

```bash
kubectl get pods,svc,ingress,hpa -n cv
```

The application pod showed:

```text
cv-cv-app   2/2   Running
```

The `2/2` means both containers were running:

- `cv-app`
- `apache-exporter`

## Step 9: Verify the ALB Ingress

The chart created an ALB Ingress:

```bash
kubectl get ingress cv-cv-app -n cv
```

Example ALB hostname:

```text
k8s-myappgroup-430fe4898e-912724151.ap-south-1.elb.amazonaws.com
```

I tested the application endpoint:

```bash
curl -I http://k8s-myappgroup-430fe4898e-912724151.ap-south-1.elb.amazonaws.com
```

The response was:

```text
HTTP/1.1 200 OK
Server: Apache/2.4.66 (Ubuntu)
```

That confirmed the ALB, Ingress, Service, and Pod were all working.

## Step 10: Verify ALB Target Health

I also checked the AWS target group health:

```bash
aws elbv2 describe-target-health \
  --target-group-arn <target-group-arn> \
  --region ap-south-1
```

The target state was:

```text
healthy
```

## Step 11: Access Grafana

Grafana was installed as part of `kube-prometheus-stack`.

The service is internal:

```bash
kubectl get svc cv-grafana -n cv
```

To access Grafana locally, I used port-forwarding:

```bash
kubectl port-forward svc/cv-grafana -n cv 3000:80
```

Then opened:

```text
http://localhost:3000
```

The chart values configured:

```text
Username: admin
Password: admin
```

Grafana health can be checked with:

```bash
curl http://localhost:3000/api/health
```

## Step 12: Verify Metrics Endpoints

The Apache status endpoint is available through the ALB:

```bash
curl "http://k8s-myappgroup-430fe4898e-912724151.ap-south-1.elb.amazonaws.com/server-status?auto"
```

The Apache exporter metrics are available on port `9117`.

To test locally:

```bash
kubectl port-forward svc/cv-cv-app -n cv 9117:9117
```

```bash
curl http://localhost:9117/metrics
```

## Step 13: Access Prometheus

Prometheus is also installed by `kube-prometheus-stack`.

I used port-forwarding:

```bash
kubectl port-forward svc/cv-kube-prometheus-stack-prometheus -n cv 9090:9090
```

Prometheus health endpoints:

```bash
curl http://localhost:9090/-/healthy
curl http://localhost:9090/-/ready
```

Query Apache availability:

```bash
curl "http://localhost:9090/api/v1/query?query=apache_up"
```

## Step 14: Verify HPA

After Metrics Server and CPU requests were in place, the HPA worked:

```bash
kubectl get hpa cv-cv-app -n cv
```

Example output:

```text
NAME        REFERENCE              TARGETS       MINPODS   MAXPODS   REPLICAS
cv-cv-app   Deployment/cv-cv-app   cpu: 0%/50%   1         5         1
```

## Final Result

At the end of the process:

- Helm release `cv` was deployed successfully.
- Namespace `cv` contained the application and monitoring stack.
- The app was publicly accessible through AWS ALB.
- Prometheus scraped Apache exporter metrics.
- Grafana was available through port-forwarding.
- HPA was able to read CPU metrics.
- The application returned `HTTP/1.1 200 OK`.

Useful final checks:

```bash
helm list -n cv
kubectl get pods,svc,ingress,hpa -n cv
kubectl top pods -n cv
```

## Conclusion

This deployment shows how Helm can be used to package not only an application, but also the operational pieces around it: ingress, autoscaling, metrics, dashboards, and alerts.

The full flow was:

```text
Terraform EKS cluster
  -> kubeconfig update
  -> Helm dependency build
  -> Helm lint and template validation
  -> Helm install
  -> ALB ingress
  -> Prometheus metrics
  -> Grafana dashboard
  -> HPA validation
```

This is a repeatable pattern for deploying containerized applications on EKS with production-style observability.

## Next Step

This Helm-based deployment flow works well, but the next improvement is to streamline it further with GitOps. In upcoming projects, I plan to move this process toward Argo CD or Flux so Kubernetes deployments can be reconciled automatically from Git, with better drift detection, rollback visibility, and environment promotion.
