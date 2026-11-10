# Exists once per account, already there: look it up.
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

data "aws_iam_policy_document" "service_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      # GitHub may send the sub with immutable owner/repo IDs (name@id).
      values = [
        "repo:Daniel-343/csk-w10-service:ref:refs/heads/main",
        "repo:Daniel-343@125360894/csk-w10-service@1452909165:ref:refs/heads/main",
      ]
    }
  }
}

resource "aws_iam_role" "gha_service" {
  name               = "${var.name}-gha-service"
  assume_role_policy = data.aws_iam_policy_document.service_trust.json
}

data "aws_iam_policy_document" "service_ecr_push" {
  statement {
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }
  statement {
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = [aws_ecr_repository.hello.arn]
  }
}

resource "aws_iam_role_policy" "gha_service_ecr" {
  name   = "ecr-push"
  role   = aws_iam_role.gha_service.id
  policy = data.aws_iam_policy_document.service_ecr_push.json
}

data "aws_iam_policy_document" "infra_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:Daniel-343/csk-w10-infra:pull_request",
        "repo:Daniel-343/csk-w10-infra:ref:refs/heads/main",
      ]
    }
  }
}

resource "aws_iam_role" "gha_infra" {
  name               = "${var.name}-gha-infra"
  assume_role_policy = data.aws_iam_policy_document.infra_trust.json
}

resource "aws_iam_role_policy_attachment" "gha_infra_admin" {
  role       = aws_iam_role.gha_infra.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_eks_access_entry" "gha_infra" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = aws_iam_role.gha_infra.arn
}

resource "aws_eks_access_policy_association" "gha_infra" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = aws_eks_access_entry.gha_infra.principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  access_scope {
    type = "cluster"
  }
}