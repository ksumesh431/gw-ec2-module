# EC2 Instance Module

This project is a Terraform EC2 deployment that uses a remote S3 backend for state files.

## Prerequisites

- Terraform installed on your local machine.
- AWS credentials configured on your local machine.
- The `TF_VAR_s3_bucket_name` environment variable set to the name of the S3 bucket where you want to store the Terraform state files.

## Usage

1. Clone the repository:

   ```bash
   git clone <repository-url>
   cd <repository-directory>
   ```

2. Set the `TF_VAR_s3_bucket_name` environment variable:

   ```bash
   export TF_VAR_s3_bucket_name=<your-s3-bucket-name>
   ```

3. Initialize the Terraform project:

   ```bash
   terraform init -backend-config="bucket=${TF_VAR_s3_bucket_name}"
   ```

4. Plan the deployment:

   ```bash
   terraform plan
   ```

5. Apply the deployment:

   ```bash
   terraform apply
   ```

6. To destroy the deployment:

   ```bash
   terraform destroy
   ```

## Project Structure

- `main.tf`: Contains the main Terraform configuration.
- `provider.tf`: Specifies the provider for the deployment.
- `variables.tf`: Defines the input variables for the project.
- `terraform.tfvars`: Provides default values for the variables.
- `modules/`: Contains reusable modules for the deployment.

## Notes

- Ensure that the S3 bucket specified in `TF_VAR_s3_bucket_name` exists and is accessible.
- The AWS region is specified in the `terraform.tfvars` file and can be modified as needed.
