# eks-ecr-ci-infra

Terraform for a small EKS setup on AWS (eu-north-1), deployed from GitHub Actions. The app itself lives in [flask-ecr-ci-service](https://github.com/Daniel-343/flask-ecr-ci-service). That repo builds the image and pushes it to the ECR repo created here.

## What's in it

- `network.tf`: VPC with two public subnets in two AZs, internet gateway and routing
- `eks.tf`: EKS cluster and a managed node group (t3.medium, 1–3 nodes)
- `ecr.tf`: ECR repo with immutable tags
- `github-oidc.tf`: IAM roles that GitHub Actions assumes through OIDC, one per repo
- `k8s.tf`, `k8s/deployment.yaml`: namespace and a 5-replica deployment of the `hello` image

State is kept in S3.

## CI/CD

A pull request runs `fmt`, `validate` and `plan`. A merge to `main` runs the same steps and then `apply`.

No AWS keys are stored in GitHub. Both workflows get short-lived credentials via OIDC. Each role's trust policy only accepts tokens from its own repo and branch, and the service role can only push to the one ECR repo. The infra role gets cluster access through an EKS access entry instead of the old `aws-auth` ConfigMap.

## Running it locally

```bash
terraform init
terraform apply
$(terraform output -raw update_kubeconfig_command)
kubectl -n hello get pods
```

On a fresh account, the cluster has to exist before `kubernetes_manifest` can be planned. So the first apply needs to be split in two.
