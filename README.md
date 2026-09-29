# askvault-aws

AskVault as *cloud resources*: the full app spelled out in Terraform - VPC
with public/private subnets and NAT, ECS Fargate running the same image the
cluster runs, ALB + Route53 edge, corpus S3, ingest queue, DynamoDB records,
SSM secrets, and least-privilege IAM - validated end-to-end against
[LocalStack](https://www.localstack.cloud/) in CI, with zero AWS spend.

It is the cloud counterpart to the single-VPS estate (`askvault` +
`askvault-gitops` + `k3s-vps`): same immutable-artifact principle, same
config-vs-credential split, same apply -> smoke -> destroy discipline, now in
HCL.

**CI:** public repository, free minutes. Every push: fmt/validate, actionlint,
gitleaks, then a real emulated cycle - LocalStack boot -> `terraform apply` ->
`scripts/smoke.py` (emulated mode) -> `terraform destroy`.

## What it provisions

```
corpus S3 (versioned)  SQS(+DLQ)  DynamoDB records        [data]
         │
Route53 -> [ALB ->] ECS Fargate (askvault image, stateless)  [edge/compute]
                 task role: read corpus, put records, send queue
                 execution role: pull image, ship logs, read SSM
                 LLM_API_KEY from SSM Parameter (/askvault/llm/api-key)
VPC: 2 public + 2 private subnets, IGW + NAT, SG pairs          [network]
```

### Emulated vs full (the toggle)

One config, two targets, controlled by `var.emulated` (default `true`):

- **`emulated = true` (LocalStack community):** everything except the compute
  plane - VPC/subnets/NAT/SGs, Route53, S3, SQS, DynamoDB, SSM, IAM. ECS and
  ELBv2 are LocalStack-**Pro** features, so those resources are `count = 0`
  here while still present in the config, validated, and ready.
- **`emulated = false` (real AWS):** the ECS cluster, Fargate task definition
  and service, plus the ALB + target group + listener activate automatically;
  the service wires into the load balancer, and `ASKAWS_FULL=1` makes the
  smoke test assert the compute plane instead of skipping it.

In other words: the config a pro deploys is the same file this CI exercises,
just with one variable flipped and the `endpoints` block deleted.

Design notes, stated so they read as decisions:

- **The task is stateless.** AskVault derives its SQLite index from the baked
  corpus at startup, so there is no EFS, no volume racket, no multi-AZ storage
  dance. A production upgrade path (pgvector) is a task-def change, not a
  network redesign.
- **No second build.** The task definition points at
  `ghcr.io/benzac708/askvault:main`; the app repo ships immutable `sha-`
  tags and this repo only points at them. Promotion here means changing one
  variable, exactly like the k8s `newTag` edit.
- **The only credential is a Parameter.** `aws_ssm_parameter` with a
  placeholder default; production overwrites it out of band. No literal in
  this repository (gitleaks runs in CI to keep it that way).
- **IAM is written as if enforced.** LocalStack does not enforce it; the
  policies are the product. Same honesty note as `aws-localstack`.

## Why LocalStack, and what it cannot prove

Same argument as `aws-localstack`: an emulated control plane is enough to
prove the *IaC* - the VPC/subnets/NAT/SGs exist exactly as declared, the task
definition and IAM are the exact JSON the `apply` produced, the ALB/target
group/Route53 wiring resolves. What it cannot prove, and the README says so:
real Fargate execution, real DNS/Routing, real TLS (no ACM/CloudFront here by
design), and enforced IAM. It makes this a *deployment-topology demo*, not a
*security or HA audit*.

## Running locally

```bash
docker compose up -d localstack
cd terraform && terraform init -backend=false && terraform apply -auto-approve
python3 scripts/smoke.py        # venv with boto3, or: pip install boto3
cd terraform && terraform destroy -auto-approve
```

To run this same config against a real account: delete the `endpoints` block
in `terraform/providers.tf`, set real `AWS_*` credentials, flip
`emulated = false`, and use remote state. Nothing else changes - the compute
and load-balancing resources come alive with that one variable.

## Layout

```
terraform/   network, compute, edge, data, secrets, iam, providers, outputs
scripts/smoke.py        apply-verify: asserts every declared resource exists
.github/workflows/ci.yml  the gate described above
```

## Licence

MIT - see [LICENSE](LICENSE).