# Automating a CV Website Deployment on AWS EKS with Terraform, Helm, ALB, GitHub Actions, and Grafana

I recently automated the deployment of my CV website on Amazon EKS using a full DevOps workflow: Terraform for infrastructure, Helm for Kubernetes packaging, AWS Load Balancer Controller for public access, GitHub Actions for CI/CD, and kube-prometheus-stack for monitoring.

The goal was simple: every push to `main` should build a fresh Docker image, publish it, deploy it to EKS through Helm, expose it through an AWS Application Load Balancer, and keep the deployment observable through Prometheus and Grafana.

## Architecture

The setup has five main parts:

- Terraform provisions the AWS network, EKS cluster, managed node group, IAM roles, and AWS Load Balancer Controller.
- Docker packages the static CV website with Apache.
- Helm deploys the application, service, ingress, HPA, Prometheus rules, ServiceMonitor, and Grafana dashboard.
- GitHub Actions builds, tests, and deploys the application on every push to `main`.
- kube-prometheus-stack provides Prometheus, Alertmanager, Grafana, ServiceMonitor support, dashboards, and alerting rules.

The public traffic flow is:

```text
User
  -> AWS Application Load Balancer
  -> Kubernetes Ingress
  -> NodePort Service
  -> Apache CV Pod
```

The observability flow is:

```text
Apache exporter sidecar
  -> Service metrics port 9117
  -> ServiceMonitor
  -> Prometheus
  -> Grafana dashboard and PrometheusRule alerts
```

## Terraform EKS Foundation

The EKS cluster was created from a Terraform project that provisions:

- VPC
- Public and private subnets
- NAT gateway
- EKS control plane
- EKS node group
- IAM roles
- OIDC provider
- AWS Load Balancer Controller

After Terraform created the cluster, I updated kubeconfig and verified the cluster:

```bash
aws eks update-kubeconfig --name eks --region ap-south-1
kubectl get nodes
kubectl get pods -A
```

The AWS Load Balancer Controller was already running in `kube-system`, which meant the application chart could create an ALB through a Kubernetes Ingress.

## Helm Chart for the CV App

The application is packaged as a Helm chart under:

```text
helm/cv-chart
```

The chart deploys:

- CV website Deployment
- Apache exporter sidecar
- NodePort Service
- ALB Ingress
- HorizontalPodAutoscaler
- kube-prometheus-stack dependency
- ServiceMonitor for Prometheus scraping
- PrometheusRule alerts
- Grafana dashboard ConfigMap

The app container serves the CV website on port `80`. The sidecar exporter exposes Apache metrics on port `9117`.

The service exposes both ports:

```yaml
ports:
  - name: http
    port: 80
    targetPort: 80
  - name: metrics
    port: 9117
    targetPort: metrics
```

The Ingress uses the AWS Load Balancer Controller:

```yaml
annotations:
  alb.ingress.kubernetes.io/scheme: internet-facing
  alb.ingress.kubernetes.io/target-type: instance
```

The chart is installed with:

```bash
helm upgrade --install cv ./helm/cv-chart \
  --namespace cv \
  --create-namespace \
  --set ingress.enabled=true \
  --set ingress.host="" \
  --wait \
  --timeout 15m
```

## Fixes Needed Before Deployment

A few small chart issues showed up during validation.

First, Grafana dashboard templates had Prometheus legend values like:

```text
{{state}}
```

Helm tried to interpret that as a Helm template function. The fix was to escape it:

```text
{{`{{state}}`}}
```

Second, the Apache exporter metrics port needed to be named and exposed through the service so the ServiceMonitor could scrape it.

Third, the HPA initially showed:

```text
cpu: <unknown>/50%
```

The reason was that the sidecar container had no CPU request. Kubernetes HPA needs CPU requests for all containers in the pod when calculating utilization. Adding exporter resource requests fixed the HPA:

```yaml
exporter:
  resources:
    requests:
      cpu: 50m
      memory: 64Mi
```

After installing Metrics Server and updating the sidecar resources, HPA started reporting correctly:

```text
cpu: 0%/50%
```

## CI/CD with GitHub Actions

The GitHub Actions workflow runs on every push to `main`.

The pipeline does the following:

1. Checks out the code.
2. Builds the Docker image.
3. Pushes the image to Docker Hub as:

```text
rakukrej/devops-cv:<git-sha>
rakukrej/devops-cv:latest
```

4. Builds Helm chart dependencies.
5. Runs Helm lint.
6. Runs Helm unit tests.
7. Renders the Helm templates.
8. Authenticates to AWS.
9. Updates kubeconfig for EKS.
10. Ensures Metrics Server is installed.
11. Deploys the Helm chart.
12. Prints Kubernetes deployment status.

The workflow deploy command is:

```bash
helm upgrade --install "$HELM_RELEASE" "$CHART_PATH" \
  --namespace "$HELM_NAMESPACE" \
  --create-namespace \
  --set image.repository="${IMAGE_REPOSITORY}" \
  --set image.tag="${IMAGE_TAG}" \
  --set ingress.enabled=true \
  --set ingress.host="" \
  --wait \
  --timeout 15m
```

## GitHub OIDC for AWS Access

Initially, I tested AWS credentials as GitHub repository secrets. That worked only if the credentials were long-lived. My local AWS setup used temporary login credentials, so the GitHub Actions run failed with:

```text
The security token included in the request is invalid.
```

The better fix was to use GitHub OIDC.

I created an IAM role for GitHub Actions:

```text
arn:aws:iam::227037544501:role/GitHubActionsEksDeploy
```

The trust policy allows only this repository and the `main` branch to assume the role:

```text
repo:rashmilkukreja/cv:ref:refs/heads/main
```

Then I mapped that IAM role into the EKS `aws-auth` ConfigMap so GitHub Actions could deploy to the cluster.

The workflow now uses:

```yaml
permissions:
  contents: read
  id-token: write

with:
  role-to-assume: arn:aws:iam::227037544501:role/GitHubActionsEksDeploy
  aws-region: ap-south-1
```

This removes the need for static AWS access keys in GitHub Secrets.

## Accessing the Application

The application is exposed through an internet-facing ALB:

```bash
kubectl get ingress cv-cv-app -n cv
```

Example output:

```text
k8s-myappgroup-430fe4898e-912724151.ap-south-1.elb.amazonaws.com
```

Health check:

```bash
curl -I http://k8s-myappgroup-430fe4898e-912724151.ap-south-1.elb.amazonaws.com
```

Expected response:

```text
HTTP/1.1 200 OK
Server: Apache/2.4.66 (Ubuntu)
```

Apache status endpoint:

```bash
curl "http://k8s-myappgroup-430fe4898e-912724151.ap-south-1.elb.amazonaws.com/server-status?auto"
```

## Accessing Grafana

Grafana is installed as part of kube-prometheus-stack.

Port-forward Grafana:

```bash
kubectl port-forward svc/cv-grafana -n cv 3000:80
```

Open:

```text
http://localhost:3000
```

Default credentials from the chart values:

```text
Username: admin
Password: admin
```

Grafana health endpoint:

```bash
curl http://localhost:3000/api/health
```

The custom CV dashboard is loaded through a ConfigMap labeled for Grafana dashboard discovery:

```bash
kubectl get configmap cv-app-dashboard -n cv
```

## Prometheus and Metrics Endpoints

Port-forward the Apache exporter metrics:

```bash
kubectl port-forward svc/cv-cv-app -n cv 9117:9117
curl http://localhost:9117/metrics
```

Port-forward Prometheus:

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

Useful Kubernetes checks:

```bash
kubectl get pods,svc,ingress,hpa -n cv
kubectl get servicemonitor,prometheusrule -n cv
kubectl top pods -n cv
```

## Final Result

The final CI/CD run completed successfully and deployed this image:

```text
rakukrej/devops-cv:40dd08f50921
```

The application pod was running:

```text
cv-cv-app-856859bdd7-4hbkt   2/2   Running
```

The ALB returned:

```text
HTTP/1.1 200 OK
```

And HPA was healthy:

```text
cpu: 0%/50%
```

## Closing Thoughts

This project is a compact but complete DevOps workflow:

- Infrastructure with Terraform
- Kubernetes deployment with Helm
- Public traffic through AWS ALB
- CI/CD with GitHub Actions
- Secure AWS authentication with GitHub OIDC
- Metrics with Prometheus
- Dashboards with Grafana
- Autoscaling with HPA

It is a good reference pattern for small static applications, portfolio sites, internal tools, and demo apps that still deserve production-style deployment and observability.
