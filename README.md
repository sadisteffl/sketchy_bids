# Sketchy-Bids: A Technical Exercise

This repository contains the infrastructure-as-code (IaC) and application deployment configurations for Sketchy-Bids, a cloud-native pictionary-style game built as a solution for the Technical Exercise v3.0.

The "sketchy" name is a pun. It refers not only to the sketching in the game but also to the infrastructure's security posture, which was built to be **"sketchy" by design** for this exercise. The project's objective is to deploy a three-tier web application with these intentionally vulnerable configurations to demonstrate proficiency in identifying and mitigating security risks using cloud-native tools and modern DevOps practices.

The entire application is built on a modern tech stack, fully automated with GitHub Actions CI/CD, and deployed on AWS using Terraform, ECR, and EKS.


## Meeting All Exercise Requirements

This project successfully implements every technical requirement outlined in the **Technical Exercise** document. The infrastructure was built with all specified weaknesses, the deployment is fully automated, and the required security controls are in place.


## Tech Stack & Architecture

This project follows a standard three-tier architecture, containerized and orchestrated with Kubernetes.

***Frontend:** A **React** single-page application, served by **Nginx** and containerized with Docker. This is publicly exposed via application load balancer with a WAF. 
***Backend:** A **Python/Flask** API that handles game logic and database interaction, also containerized with Docker. This is containerized runninf on internal EKS. 
***Database:** A **MongoDB** outaded image running on a dedicated EC2 virtual machine with a public bucket for backups. 

### Core Technologies

***Cloud Provider:** Amazon Web Services (AWS)
***Infrastructure as Code:** Terraform
***Container Orchestration:** Amazon EKS (Kubernetes)
***Container Registry:** Amazon ECR
***CI/CD:** GitHub Actions


## Full Automation with CI/CD

The entire software development and deployment lifecycle is automated using GitHub Actions, ensuring consistency and repeatability.

### Infrastructure as Code Pipeline (`.github/workflows/terraform.yml`)

This workflow manages the deployment of all AWS infrastructure using Terraform.
***Trigger**: Runs on every `pull_request` to `main` and on every push to `main`.
***On Pull Request**: Validates the Terraform code by running `terraform init`, `fmt`, and `plan`. This allows the team to review infrastructure changes before they are merged.
***On Push to `main`**: Automatically applies the changes to the AWS environment using `terraform apply -auto-approve`.

### Application Build Pipeline (`.github/workflows/app-build-push.yml`)

This workflow builds the frontend and backend container images and pushes them to Amazon ECR.
***Trigger**: Runs on pushes to the `main` branch whenever there are changes in the `src/frontend` or `src/backend` directories.
***Key Steps**: Uses a secure, passwordless OIDC connection to authenticate with AWS, builds the Docker images, and pushes them to their respective ECR repositories.

### Security Scanning Pipeline (`.github/workflows/trivvy.yaml`)

This workflow uses Trivy as a security gate for the repository.
***Trigger**: Runs on every `pull_request` to `main` and on every push to `main`.
***Scans Performed**: Includes IaC misconfiguration scanning, vulnerability scanning of application dependencies, secret scanning, and SBOM generation.

### Automated Database Backups (`infra/terraform/user_data.sh`)

*The database VM uses a `user_data` script to install a cron job at launch.
*The cron job executes a backup script every **six hours**, sending database backups to the public S3 bucket.

## Security Deep Dive: Controls & Logging

A multi-layered security posture is enforced through the following preventative, detective, and responsive controls.

### Preventative Controls

***Branch Protection:** The `main` branch is protected, requiring pull requests and mandatory passing of status checks (including the Trivy scan) before merging.
***IaC & Code Scanning:** The Trivy workflow acts as a CI/CD gate, failing any build that introduces high or critical severity IaC misconfigurations or hardcoded secrets.
***Web Application Firewall (`security.tf`):** An AWS WAF is associated with the Application Load Balancer, using managed rule sets like `AWSManagedRulesCommonRuleSet` and `AWSManagedRulesSQLiRuleSet` to block common web exploits.

### Detective Controls

***Vulnerability Scanning:** Amazon ECR is configured for `scan_on_push`, and the Trivy workflow scans application code for known vulnerabilities.
***Threat Detection (`security.tf`):** **AWS GuardDuty** is enabled to monitor for malicious activity. High-severity findings automatically trigger SNS notifications.
***Compliance & Monitoring (`security.tf`):** **AWS Security Hub** is enabled with the Foundational Security Best Practices standard, and **AWS Config** is deployed to track resource configuration changes against best practices. This provides centralized visibility into the security posture, including flagging open ports like SSH.

### Monitoring, Logging, and Security

This infrastructure is configured with a comprehensive suite of tools for robust security, auditing, and monitoring.

---

### Auditing & Compliance

***AWS CloudTrail (`security.tf`):***  
A multi-region **CloudTrail** trail named `sketchy-bids-cloudtrail` captures **all API activity**, including S3 and Lambda data events.  
- Logs are validated and encrypted with a dedicated **KMS key**  
- Stored in a **CloudWatch Log Group** for 365 days  
- Delivered to a secure **S3 bucket**  
- Uses **CloudTrail Insights** to detect unusual API call rates  

***AWS Config (`config.tf`):***  
Records all resource configurations and changes across the account (including global resources).  
- Configuration data is delivered to a dedicated S3 bucket:  


***Kubernetes Control Plane Logging (`eks.tf`):***  
The EKS cluster has **api, audit, authenticator, controllerManager, and scheduler** logging enabled.  
- Logs are sent directly to **AWS CloudWatch** for monitoring and forensics  


### Threat & Vulnerability Detection

***AWS Security Hub (`security.tf`):***  
Aggregates security findings and provides continuous compliance checks against **AWS Foundational Security Best Practices**.

***Amazon GuardDuty (`security.tf`):***  
Detects malicious activity and unauthorized behavior.  
- An **EventBridge** rule triggers **SNS email notifications** for findings with severity ≥ **7 (high)**  

***AWS WAF (`waf.tf`):***  
Protects the **Application Load Balancer** using multiple **AWS Managed Rule Sets**.  
- Blocks common threats: bad inputs, SQL injection, and malicious IPs  

***Amazon Inspector (`inspector.tf`):***  
Automatically scans **EC2 resources** for software vulnerabilities and network exposure.  
- Configured to export **SBOM (Software Bill of Materials)** reports to an S3 bucket  

***ECR Image Scanning (`ecr.tf`):***  
All container images (frontend and backend) are scanned for vulnerabilities on push:  


***CloudTrail Insights Alarm (`cloudwatch.tf`):***  
A **CloudWatch Alarm** monitors for unusual API activity.  
- Triggers **SNS notifications** when ≥1 unusual event occurs within a **5-minute** period  

### Operational Monitoring & Backups

***EC2 Detailed Monitoring (`ec2.tf`):***  
The MongoDB virtual machine has **1-minute detailed monitoring** enabled in **CloudWatch** for better performance metrics and alerting.

***Database Backups (`backup.sh`):***  
A **cron job** on the MongoDB server backs up the `sketchydb` database every **6 hours**.  
- Backups are uploaded to an **S3 bucket:**  


### Enforcement & Remediation

Due to the nature of the insecure vulnerabilites which were provided, I wanted to provide a couple of examples to ensure the infrasturcture around it is secure and that security compliance is being upheld. 

1. Automated S3 Remediation:** An event-driven, serverless workflow automatically remediates public S3 buckets. An EventBridge rule detects `PutBucketAcl` events and triggers a Lambda function, which invokes an **SSM Automation document** to re-apply `BlockPublicAccess` settings. 
2. This code is located in `infra/terraform/security_enforcement/public-bucket-takedown-ssm-lambda/`. ***Patch Management (Planned):** The recommended solution to remediate the outdated AMI on the database VM would be to use **SSM Patch Manager** to automate the patching process, triggered by findings from AWS Inspector.
3. Included in this repo is an example of an RCP which is applied at the org level to ensure no other resources are povisioned with overpermisisve policies. 
4. /infra/terraform/security_enforcement/vulnerability-remediation provides an example of a zero-day which the team found wihtin the last couple of weeks. Not only does it demonstrate how to replicate the attack, it also provides the automated way to remediate the vulnerability. 

## Conclusion

This project successfully demonstrates the ability to build, deploy, and secure a modern, cloud-native application. It showcases a deep understanding of infrastructure as code, CI/CD automation, and the implementation of a multi-layered security strategy to address intentional vulnerabilities. Despite running into real-world constraints like account limits, the core objectives of the  Technical Exercise  were met, and the project serves as a comprehensive example of modern cloud engineering and security practices.
