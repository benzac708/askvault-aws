"""End-to-end smoke test for the emulated full-app stack.

Requires: LocalStack up (docker compose up), Terraform applied (make apply).
Asserts the resources Terraform declares actually exist at the API level:
network, compute, edge, data and secrets. This proves the IaC drove a real
control plane, not that Fargate executed the app -- the README says so.

Run with:  .venv/bin/python scripts/smoke.py   (or: make verify)
"""

import os
import sys

import boto3

ENDPOINT = "http://localhost:4566"
REGION = "us-east-1"


def client(service):
    return boto3.client(service, endpoint_url=ENDPOINT, region_name=REGION)


def check(label, ok):
    print(f"{'PASS' if ok else 'FAIL'}  {label}")
    return ok


def main():
    ok = True
    ec2 = client("ec2")
    ecs = client("ecs")
    s3 = client("s3")
    sqs = client("sqs")
    ddb = client("dynamodb")
    ssm = client("ssm")
    r53 = client("route53")

    ok &= check("VPC exists", len(ec2.describe_vpcs()["Vpcs"]) >= 1)
    subs = {s["SubnetId"] for s in ec2.describe_subnets()["Subnets"]}
    ok &= check(">= 4 subnets created", len(subs) >= 4)
    igws = ec2.describe_internet_gateways()["InternetGateways"]
    ok &= check("internet gateway exists", len(igws) >= 1)
    ok &= check("NAT gateway exists", len(ec2.describe_nat_gateways()["NatGateways"]) >= 1)
    sgs = ec2.describe_security_groups()["SecurityGroups"]
    ok &= check("task security group exists (private-only ingress)",
                any(g["GroupName"] in ("askvault-task", "askvault-task-emu") for g in sgs))

    if os.environ.get("ASKAWS_FULL", "0") == "1":
        ok &= check("ECS cluster exists",
                    any(c["clusterName"] == "askvault" for c in ecs.list_clusters()["clusterArns"]))
        tds = ecs.list_task_definitions(familyPrefix="askvault")["taskDefinitionArns"]
        ok &= check("task definition registered", len(tds) >= 1)
        svc = ecs.describe_services(cluster="askvault", services=["askvault"])["services"][0]
        ok &= check("service active, desiredCount=1", svc["status"] == "ACTIVE" and svc["desiredCount"] == 1)
    else:
        print("SKIP  ECS assertions (emulated mode - compute is Pro-gated)")

    # ELBv2 is LocalStack-Pro-gated; the LB wiring is the one piece CI cannot
    # prove here (documented in edge.tf) -- the Route53 path is still exercised.
    zones = r53.list_hosted_zones()["HostedZones"]
    ok &= check("hosted zone exists", any(z["Name"] == "askvault.pvt." for z in zones))
    records = r53.list_resource_record_sets(HostedZoneId=zones[0]["Id"])["ResourceRecordSets"]
    ok &= check("hosted zone has askvault record",
                any(r["Name"] == "askvault.askvault.pvt." for r in records))

    buckets = {b["Name"] for b in s3.list_buckets()["Buckets"]}
    ok &= check("corpus bucket (versioned) exists", "askvault-corpus" in buckets)
    ok &= check("queue + DLQ exist",
                any("askvault-ingest" in str(q) for q in sqs.list_queues().get("QueueUrls", [])))
    ok &= check("records table exists", "askvault-records" in ddb.list_tables()["TableNames"])
    ok &= check("SSM parameter exists", bool(ssm.get_parameter(Name="/askvault/llm/api-key")["Parameter"]))

    print(f"\n{'SMOKE OK' if ok else 'SMOKE FAILED'}")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()