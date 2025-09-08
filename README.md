# Project Overview & Usage Guide

## Prerequisites

Before using this project, please ensure the following tools are installed on your system:

- [Terraform](https://www.terraform.io/downloads.html)
- [yq](https://github.com/mikefarah/yq) (Go version by mikefarah, required for environment variable processing)

---

## Environment Variable Management

All environment variables for Terraform and Ansible are centrally managed in [`env_vars.yml`](./env_vars.yml). This file is structured as follows:

- **defaults**: Shared variables applied to all clients
- **clients**: Client-specific overrides for both Terraform and Ansible

**Example Structure:**

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

**To add a new client:**

- Duplicate the structure under `arlitx` and update the values as required.

**Variable Merging:**

- Default values are automatically merged with client-specific overrides when running commands.

---

## Terraform Workflow

All Terraform operations are managed via the [`run-tf.sh`](./run-tf.sh) helper script. This script:

- Merges and applies the appropriate environment variables for the selected client
- Writes variables to `terraform/generated.auto.tfvars.json`
- Configures the S3 backend for state file management
- Executes the specified Terraform command within the `terraform/` directory

### S3 State File Bucket Requirement

Each client **must** define an S3 bucket for the Terraform state file in their `terraform_vars` section of [`env_vars.yml`](./env_vars.yml):

```yaml
clients:
  arlitx:
    terraform_vars:
      bucket: your-s3-bucket-name
      # ...other vars...
```

> **Note:**
>
> - The S3 bucket must be created manually in AWS before running `init` for the first time.
> - The script will validate the presence of the `bucket` variable and provide a clear error if it is missing.

### Usage

```bash
./run-tf.sh <init|plan|apply|destroy|...> <client_id> [additional_args...]
```

- `<terraform_command>`: Any valid Terraform command (e.g., `init`, `plan`, `apply`, `destroy`)
- `<client_id>`: The client key as defined in `env_vars.yml` (e.g., `arlitx`)
- `[additional_args...]`: Optional additional arguments for Terraform (e.g., `-reconfigure` for `init`)

**Examples:**

Initialize with backend configuration (bucket must exist):

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

> The script will automatically detect changes to the backend S3 bucket and add the `-reconfigure` flag to `terraform init` if necessary. You may also pass `-reconfigure` manually as an extra argument.

---

## Ansible Playbook Execution

To execute Ansible playbooks for a specific client:

1. Navigate to the `ansible/` directory:
   ```bash
   cd ansible
   ```
2. Run the desired playbook, specifying the client ID:
   ```bash
   ansible-playbook -i localhost, playbooks/deploy_gateway_b.yml -e "client_id=arlitx"
   ```
   - Adjust the playbook path and `client_id` as appropriate for your use case.

---

## Reference Files

- [`env_vars.yml`](./env_vars.yml): Centralized environment variable and client configuration
- [`run-tf.sh`](./run-tf.sh): Script for executing Terraform with the correct variables
- [`ansible/`](./ansible/): Ansible playbooks and supporting roles

---

> **Tip:** Ensure your `client_id` matches a key defined in `env_vars.yml`.
