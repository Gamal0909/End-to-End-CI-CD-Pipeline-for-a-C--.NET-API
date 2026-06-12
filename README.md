# 🚀 End-to-End CI/CD Pipeline for a C# .NET API

A production-ready, fully automated CI/CD pipeline that builds, tests, containerizes, and deploys a **C# ASP.NET Core 10 API** to **AWS ECS Fargate** — all triggered by a single `git push`.

![CI/CD](https://img.shields.io/github/actions/workflow/status/Gamal0909/End-to-End-CI-CD-Pipeline-for-a-C--.NET-API/cicd.yml?branch=main&label=CI%2FCD&style=flat-square)
![.NET](https://img.shields.io/badge/.NET-10.0-512BD4?style=flat-square&logo=dotnet)
![Docker](https://img.shields.io/badge/Docker-Containerized-2496ED?style=flat-square&logo=docker)
![AWS](https://img.shields.io/badge/AWS-ECS%20Fargate-FF9900?style=flat-square&logo=amazonaws)
![Terraform](https://img.shields.io/badge/IaC-Terraform-7B42BC?style=flat-square&logo=terraform)

---

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Tech Stack](#tech-stack)
- [Pipeline Stages](#pipeline-stages)
- [Project Structure](#project-structure)
- [Infrastructure (Terraform)](#infrastructure-terraform)
- [Getting Started](#getting-started)
  - [Prerequisites](#prerequisites)
  - [Local Development](#local-development)
  - [Running with Docker](#running-with-docker)
- [CI/CD Setup](#cicd-setup)
  - [GitHub Secrets](#github-secrets)
  - [Deploying Infrastructure](#deploying-infrastructure)
- [Environment Variables](#environment-variables)

---

## Overview

This project demonstrates a complete **DevOps lifecycle** for a minimal ASP.NET Core Web API:

1. **Code** is pushed to `main`
2. **GitHub Actions** automatically triggers the pipeline
3. The app is **built**, **tested**, and **containerized**
4. The Docker image is **pushed to Amazon ECR**
5. **Amazon ECS Fargate** performs a zero-downtime rolling update

---

## Architecture

```
Developer → GitHub (push to main)
               │
               ▼
       GitHub Actions CI/CD
       ┌──────────────────────────────────┐
       │  1. Checkout Code                │
       │  2. Setup .NET 10 SDK            │
       │  3. dotnet restore               │
       │  4. dotnet build (Release)       │
       │  5. dotnet test                  │
       │  6. Configure AWS Credentials    │
       │  7. Login to Amazon ECR          │
       │  8. docker build & push → ECR   │
       │  9. ECS Force New Deployment     │
       └──────────────────────────────────┘
               │
               ▼
        AWS ECS Fargate
        (Zero-downtime rolling update)
```

### AWS Infrastructure

```
Internet
   │
   ▼
[ VPC: 10.0.0.0/16 ]
   ├── Public Subnet AZ-A  (10.0.1.0/24) ──► ECS Fargate Tasks
   ├── Public Subnet AZ-B  (10.0.2.0/24) ──► ECS Fargate Tasks (HA)
   └── Private Subnet AZ-A (10.0.3.0/24)
          │
          └── NAT Gateway ──► Internet

[ ECR Repository: devops-api ]
[ ECS Cluster:    devops-api ]
[ ECS Service:    devops-api ]
[ CloudWatch Logs: /ecs/devops-api ]
```

---

## Tech Stack

| Layer | Technology |
|---|---|
| **Application** | C# / ASP.NET Core 10, OpenAPI |
| **Containerization** | Docker (multi-stage build) |
| **CI/CD** | GitHub Actions |
| **Container Registry** | Amazon ECR |
| **Orchestration** | Amazon ECS Fargate |
| **Infrastructure as Code** | Terraform (AWS provider) |
| **Networking** | AWS VPC, Subnets, NAT Gateway, Internet Gateway |
| **Observability** | AWS CloudWatch Logs |

---

## Pipeline Stages

### 🔵 Continuous Integration (CI)

| Step | Action |
|---|---|
| **Checkout** | Fetches source code at the latest commit |
| **Setup SDK** | Installs .NET 10 SDK on the runner |
| **Restore** | Downloads NuGet dependencies (`dotnet restore`) |
| **Build** | Compiles in Release mode (`dotnet build`) |
| **Test** | Runs all unit tests (`dotnet test`) |

### 🟠 Continuous Deployment (CD)

| Step | Action |
|---|---|
| **AWS Auth** | Authenticates using OIDC / access key secrets |
| **ECR Login** | Authenticates Docker with Amazon ECR |
| **Docker Build & Push** | Builds multi-stage image, tags as `latest`, pushes to ECR |
| **ECS Deploy** | Forces a rolling update on the ECS service (zero downtime) |

---

## Project Structure

```
.
├── .github/
│   └── workflows/
│       └── cicd.yml          # GitHub Actions pipeline
├── DevOpsApi/
│   ├── DevOpsApi.csproj      # .NET 10 project file
│   ├── Program.cs            # Application entry point
│   ├── appsettings.json      # App configuration
│   └── Properties/
├── terraform/
│   ├── main.tf               # AWS infrastructure (VPC, ECR, ECS, IAM)
│   └── provider.tf           # Terraform provider configuration
├── Dockerfile                # Multi-stage Docker build
├── DevOpsApi.sln             # Solution file
└── .gitignore
```

---

## Infrastructure (Terraform)

All AWS infrastructure is defined as code in the `terraform/` directory.

### Resources Created

| Resource | Name | Description |
|---|---|---|
| VPC | `devops-project-vpc` | Isolated network (`10.0.0.0/16`) |
| Public Subnets | `devops-public-subnet-1/2` | Multi-AZ public subnets |
| Private Subnet | `devops-private-subnet-1` | Private subnet for internal workloads |
| Internet Gateway | `devops-api-igw` | Public internet access |
| NAT Gateway | `devops-api-nat-gw` | Outbound internet for private subnet |
| ECR Repository | `devops-api` | Private Docker image registry |
| ECS Cluster | `devops-api` | Fargate container cluster |
| ECS Task Definition | `devops-api-task` | Fargate task (256 CPU / 512 MB RAM) |
| ECS Service | `devops-api` | Manages running tasks with rolling deploys |
| IAM Role | `devops-ecs-execution-role` | ECS task execution permissions |
| Security Group | `devops-api-sg` | Allows inbound on port `8080` |
| CloudWatch Log Group | `/ecs/devops-api` | Container logs (7-day retention) |

---

## Getting Started

### Prerequisites

- [.NET 10 SDK](https://dotnet.microsoft.com/download)
- [Docker](https://docs.docker.com/get-docker/)
- [Terraform](https://developer.hashicorp.com/terraform/install) ≥ 1.0
- [AWS CLI](https://aws.amazon.com/cli/) configured with valid credentials
- A GitHub account with Actions enabled

### Local Development

```bash
# Clone the repository
git clone https://github.com/Gamal0909/End-to-End-CI-CD-Pipeline-for-a-C--.NET-API.git
cd End-to-End-CI-CD-Pipeline-for-a-C--.NET-API

# Restore dependencies
cd DevOpsApi
dotnet restore

# Run the application
dotnet run

# The API will be available at http://localhost:5000
# OpenAPI docs at http://localhost:5000/openapi
```

### Running with Docker

```bash
# Build the image
docker build -t devops-api .

# Run the container
docker run -p 8080:8080 devops-api

# API available at http://localhost:8080
```

---

## CI/CD Setup

### GitHub Secrets

Configure the following secrets in your GitHub repository under **Settings → Secrets and variables → Actions**:

| Secret | Description |
|---|---|
| `AWS_ACCESS_KEY_ID` | AWS IAM access key ID |
| `AWS_SECRET_ACCESS_KEY` | AWS IAM secret access key |
| `AWS_REGION` | AWS region (e.g. `ap-southeast-2`) |

> **Required IAM permissions:** `AmazonEC2ContainerRegistryFullAccess`, `AmazonECS_FullAccess`

### Deploying Infrastructure

Run these commands **once** before triggering the pipeline for the first time:

```bash
cd terraform

# Initialize Terraform
terraform init

# Preview the changes
terraform plan

# Create all AWS resources
terraform apply
```

Once `terraform apply` completes, the pipeline can deploy to the created ECS cluster automatically.

### Triggering the Pipeline

The pipeline runs automatically on every push to `main`:

```bash
git add .
git commit -m "your change"
git push origin main
```

You can also trigger it manually from the **GitHub Actions** tab using `workflow_dispatch`.

---

## Environment Variables

The following environment variables are set at the workflow level in `cicd.yml`:

| Variable | Value | Description |
|---|---|---|
| `ECR_REPOSITORY` | `devops-api` | ECR repository name |
| `ECS_CLUSTER` | `devops-api` | ECS cluster name |
| `ECS_SERVICE` | `devops-api` | ECS service name |

---

## 📄 License

This project is open source and available under the [MIT License](LICENSE).
