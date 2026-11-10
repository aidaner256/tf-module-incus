# incus-lab

Terraform for a local Incus lab: project, bridge network, per-role ACLs,
port forwards and Debian VMs (k3s master + workers) provisioned via cloud-init.

## Layout

| Path | What |
|---|---|
| `main.tf` | backend, provider, project, network, ACLs, forwards, image, nodes |
| `variables.tf` / `terraform.tfvars` | lab topology: subnet, nodes, ingress rules, forwards |
| `modules/incus-node/` | one role = profile + N instances (+ data volumes, snapshots) |
| `*.example` | templates for the git-ignored secret files |

## Requirements

- Terraform >= 1.10, provider `lxc/incus` 1.2.x
- Incus with the API enabled: `incus config set core.https_address <ip>:8443`
- S3-compatible storage for state (MinIO) with a bucket `tf-state`

## Secrets

| File | Contains | Where to get it |
|---|---|---|
| `secrets.auto.tfvars` | `incus_token`, `incus_ip`, `incus_port` | `incus config trust add terraform` |
| `backend.secret.hcl` | S3 `endpoints`, `access_key` / `secret_key` | MinIO address and access key |

```sh
cp secrets.auto.tfvars.example secrets.auto.tfvars
cp backend.secret.hcl.example  backend.secret.hcl
# fill in values
```

## Usage

```sh
terraform init -backend-config=backend.secret.hcl
terraform plan
terraform apply
terraform output hosts
```

Nodes resolve as `<name>.lab` inside the bridge network.
