# 📝 Prerequisites

Before running any Terraform commands with this project, ensure the following tools are installed on your system:

- [Terraform](https://www.terraform.io/downloads.html)
- [yq](https://github.com/mikefarah/yq) (**Go version by mikefarah, required for env var processing**)

# Environment Variables & Multi-Client Automation Guide

Welcome! This project is designed for seamless infrastructure and configuration management across multiple clients using **Terraform** and **Ansible**. This guide explains how environment variables are managed and how to run commands for different clients.

---

## 🌎 Environment Variables Setup

All environment variables for Terraform and Ansible are managed centrally in [`env_vars.yml`](./env_vars.yml). This YAML file contains:

- **defaults**: Shared variables for all clients.
- **clients**: Client-specific overrides for both Terraform and Ansible.

### Example Structure

```yaml
defaults:
  ansible_vars:
    ansible_python_interpreter: /usr/bin/python3
  terraform_vars:
    # shared terraform vars
clients:
  arlitx:
    ansible_vars:
      client_name: arlitx
      # ...
    terraform_vars:
      aws_region: us-east-2
      # ...
  client_id2:
    ansible_vars:
    terraform_vars:
```

- **To add a new client**: Copy the structure under `arlitx` and update the values as needed.
- **Variables are merged**: Defaults are merged with client-specific values automatically when running commands.

---

## 🚀 Running Terraform Commands

All Terraform commands are executed via the helper script [`run-tf.sh`](./run-tf.sh), which:

- Merges the correct environment variables for your chosen client.
- Writes them to `terraform/generated.auto.tfvars.json`.
- Handles S3 backend configuration for state files (see below).
- Runs the desired Terraform command in the `terraform/` directory.

### S3 State File Bucket Requirement

> **Important:**
>
> - Each client **must** specify an S3 bucket for the Terraform state file in their `terraform_vars` section in [`env_vars.yml`](./env_vars.yml):
>   ```yaml
>   clients:
>     arlitx:
>       terraform_vars:
>         bucket: your-s3-bucket-name
>         # ...other vars...
>   ```
> - **You must create this S3 bucket manually in AWS before running `init` for the first time.**
> - The script will check for the bucket variable and fail with a clear error if it is missing.

### Usage

```bash
./run-tf.sh <init|plan|apply|destroy|...> <client_id> [additional_args...]
```

- `<terraform_command>`: Any Terraform command (e.g., `init`, `plan`, `apply`, `destroy`)
- `<client_id>`: The client key as defined in `env_vars.yml` (e.g., `arlitx`)
- `[additional_args...]`: Any additional arguments for Terraform (e.g., `-reconfigure` for `init`)

#### Examples

Initialize with backend config (bucket must exist):

```bash
./run-tf.sh init arlitx
```

Plan for a client:

```bash
./run-tf.sh plan arlitx
```

Destroy for a client:

```bash
./run-tf.sh destroy arlitx
```

> The script will automatically detect if the backend S3 bucket has changed and add the `-reconfigure` flag to `terraform init` if needed. You can also pass `-reconfigure` manually as an extra argument.

---

## 🛠️ Running Ansible Playbooks

To run Ansible playbooks for a specific client:

1. **Change directory** to the `ansible/` folder:
   ```bash
   cd ansible
   ```
2. **Run the playbook** with the required variables:
   ```bash
   ansible-playbook -i localhost, playbooks/deploy_gateway_b.yml   -e "client_id=arlitx"
   ```
   - Replace `gw-b` and the playbook path as needed for your use case.
   - Change `client_id=arlitx` to your target client.

---

## 📚 References

- [`env_vars.yml`](./env_vars.yml): All environment variables and client configs
- [`run-tf.sh`](./run-tf.sh): Script for running Terraform with correct variables
- [`ansible/`](./ansible/): Ansible playbooks and roles

---

> **Tip:** Always ensure your `client_id` matches a key in `env_vars.yml`.

---

**Happy automating!**
