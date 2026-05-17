<!--<h1 align="center">Hi 👋, I'm Rashmil Kukreja</h1>-->
<h1 align="center">
    <img src="https://readme-typing-svg.herokuapp.com/?font=Righteous&size=35&center=true&vCenter=true&width=500&height=70&duration=4000&lines=Hi+There!+👋;+I'm+Rashmil+Kukreja!;" />
</h1>

<h3 align="center">Senior DevOps Engineer | CKA | KCNA | Terraform Certified</h3>

<p align="center">
  <a href="https://www.linkedin.com/in/rashmilkukreja/" target="_blank">
    <img src="https://img.shields.io/badge/LinkedIn-Rashmil_Kukreja-0077B5?style=for-the-badge&logo=linkedin&logoColor=white"/>
  </a>
  <a href="https://medium.com/@rashmil.kukreja" target="_blank">
    <img src="https://img.shields.io/badge/Medium-Blogs-000000?style=for-the-badge&logo=medium&logoColor=white"/>
  </a>
  <a href="mailto:rashmil.kukreja@gmail.com">
    <img src="https://img.shields.io/badge/Gmail-Contact_Me-EA4335?style=for-the-badge&logo=gmail&logoColor=white"/>
  </a>
</p>

---

## 👨‍💻 About Me

- 🌱 Currently learning and building in **DevOps & Cloud Technologies**
- ⚙️ Passionate about **CI/CD, Automation, and Infrastructure as Code**
- 📝 I write technical articles on Medium
- 💬 Ask me about DevOps, Containers, CI/CD, and Cloud
- 📫 Reach me at: **rashmil.kukreja@gmail.com**

---

## 🏆 Certifications

- **Certified Kubernetes Administrator (CKA)** — CNCF / Linux Foundation
- **Kubernetes and Cloud Native Associate (KCNA)** — CNCF / Linux Foundation
- **HashiCorp Terraform Associate (003)** — HashiCorp
- **Oracle Cloud Infrastructure Foundations Associate (2023)** — Oracle
- **Oracle Certified Java Programmer (OCJP 7)** — Oracle
- **Pega Certified System Architect (PCSA 8.4)** — Pega

---

## 🛠️ Tech Stack

### 💻 Programming
<p>
<img src="https://img.shields.io/badge/Java-ED8B00?style=for-the-badge&logo=java&logoColor=white"/>
<img src="https://img.shields.io/badge/Shell_Scripting-121011?style=for-the-badge&logo=gnu-bash&logoColor=white"/>
</p>

### 🖥️ IDE & Tools
<p>
<img src="https://img.shields.io/badge/IntelliJ_IDEA-000000?style=for-the-badge&logo=intellij-idea&logoColor=white"/>
<img src="https://img.shields.io/badge/VS_Code-0078D4?style=for-the-badge&logo=visual-studio-code&logoColor=white"/>
<img src="https://img.shields.io/badge/Git-F05032?style=for-the-badge&logo=git&logoColor=white"/>
</p>

### ☁️ DevOps & Cloud
<p>
<img src="https://img.shields.io/badge/Jenkins-D24939?style=for-the-badge&logo=jenkins&logoColor=white"/>
<img src="https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white"/>
<img src="https://img.shields.io/badge/Kubernetes-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white"/>
<img src="https://img.shields.io/badge/AWS-232F3E?style=for-the-badge&logo=amazon-aws&logoColor=white"/>
<img src="https://img.shields.io/badge/Terraform-623CE4?style=for-the-badge&logo=terraform&logoColor=white"/>
<img src="https://img.shields.io/badge/Grafana-F46800?style=for-the-badge&logo=grafana&logoColor=white"/>
</p>

### 🗄️ Databases
<p>
<img src="https://img.shields.io/badge/MySQL-00000F?style=for-the-badge&logo=mysql&logoColor=white"/>
</p>

### 💻 Operating Systems
<p>
<img src="https://img.shields.io/badge/Linux-FCC624?style=for-the-badge&logo=linux&logoColor=black"/>
<img src="https://img.shields.io/badge/Ubuntu-E95420?style=for-the-badge&logo=ubuntu&logoColor=white"/>
<img src="https://img.shields.io/badge/Windows-0078D6?style=for-the-badge&logo=windows&logoColor=white"/>
</p>

---

## 🚀 DevOps Mindset

> Automate everything.  
> Monitor everything.  
> Improve continuously.  

---

## 🚢 CI/CD and Kubernetes Deployment

<!-- This section documents the production deployment flow for reviewers and recruiters. -->
This repository deploys the CV website to an AWS EKS cluster using GitHub Actions and Helm.

- Workflow: `.github/workflows/ci-cd.yaml`
- Trigger: push to `main` or manual `workflow_dispatch`
- Image: `rakukrej/devops-cv:<git-sha>`
- Helm release: `cv`
- Namespace: `cv`
- EKS cluster: `eks`
- AWS region: `ap-south-1`
- Ingress: AWS Load Balancer Controller with an internet-facing ALB

Current public application URL:

```bash
http://k8s-myappgroup-430fe4898e-912724151.ap-south-1.elb.amazonaws.com
```

Check the live ingress hostname:

```bash
kubectl get ingress cv-cv-app -n cv
```

Check deployment status:

```bash
kubectl get pods,svc,ingress,hpa -n cv
kubectl rollout status deployment/cv-cv-app -n cv
```

---

## 📊 Grafana Access

<!-- Grafana is installed by the Helm dependency and loaded with the dashboard ConfigMap. -->
Grafana is installed through `kube-prometheus-stack` as part of the Helm chart.

Port-forward Grafana locally:

```bash
kubectl port-forward svc/cv-grafana -n cv 3000:80
```

Open Grafana:

```bash
http://localhost:3000
```

Login credentials:

```text
Username: admin
Password: admin
```

The custom dashboard is loaded from the Helm chart ConfigMap:

```bash
kubectl get configmap cv-app-dashboard -n cv
```

Grafana health endpoint:

```bash
curl http://localhost:3000/api/health
```

---

## 📈 Metrics and Health Endpoints

<!-- These commands validate the app, exporter, Prometheus, and Kubernetes autoscaling signals. -->
Application health check:

```bash
curl -I http://k8s-myappgroup-430fe4898e-912724151.ap-south-1.elb.amazonaws.com
```

Apache status endpoint:

```bash
curl http://k8s-myappgroup-430fe4898e-912724151.ap-south-1.elb.amazonaws.com/server-status?auto
```

Apache exporter metrics are exposed inside the cluster on service port `9117`.

Port-forward exporter metrics:

```bash
kubectl port-forward svc/cv-cv-app -n cv 9117:9117
curl http://localhost:9117/metrics
```

Prometheus is available inside the cluster through `cv-kube-prometheus-stack-prometheus`.

Port-forward Prometheus:

```bash
kubectl port-forward svc/cv-kube-prometheus-stack-prometheus -n cv 9090:9090
```

Prometheus endpoints:

```bash
curl http://localhost:9090/-/healthy
curl http://localhost:9090/-/ready
curl "http://localhost:9090/api/v1/query?query=apache_up"
```

Useful Kubernetes checks:

```bash
kubectl get servicemonitor,prometheusrule -n cv
kubectl top pods -n cv
kubectl get hpa cv-cv-app -n cv
```

---

<p align="center">
  ⭐ If you like my work, consider giving a star to my repositories!
</p>
