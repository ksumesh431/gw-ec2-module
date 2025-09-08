#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status.

# --- Configuration ---
CONFIG_FILE="env_vars.yml"
TF_VARS_FILE="terraform/generated.auto.tfvars.json"

# --- Script Logic ---
if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <init|plan|apply|destroy|...> <client_id> [additional_args...]"
    echo "Example: $0 init client_id1"
    echo "Example: $0 init client_id1 -reconfigure"
    echo "Example: $0 plan client_id1"
    exit 1
fi

TF_COMMAND=$1
CLIENT_ID=$2
shift 2

if ! command -v yq &> /dev/null; then
    echo "Error: yq (the Go version from mikefarah) is not installed."
    exit 1
fi

echo ">>> Generating Terraform variables for client: ${CLIENT_ID}"

# Modern yq can do the check, merge, and output in one go!
# It merges the defaults with the client-specific vars (or an empty object if none exist)
MERGED_JSON=$(yq "(.defaults.terraform_vars * (.clients.${CLIENT_ID}.terraform_vars // {}))" ${CONFIG_FILE} -o=json)

# Check if the client existed by seeing if the result is empty or just `{}`
if [ -z "$MERGED_JSON" ] || [ "$MERGED_JSON" == "{}" ]; then
    # Check if the key exists at all in the file to be sure
    if ! yq ".clients | has(\"${CLIENT_ID}\")" ${CONFIG_FILE} | grep -q "true"; then
      echo "Error: Client ID '${CLIENT_ID}' not found in ${CONFIG_FILE}"
      exit 1
    fi
fi

echo "$MERGED_JSON" > $TF_VARS_FILE
echo ">>> Wrote variables to ${TF_VARS_FILE}"
cat $TF_VARS_FILE

# Special handling for terraform init
if [ "$TF_COMMAND" == "init" ]; then
    echo ">>> Extracting S3 bucket for terraform init..."
    
    # Extract bucket name from the client's terraform_vars
    BUCKET_NAME=$(yq ".clients.${CLIENT_ID}.terraform_vars.bucket" ${CONFIG_FILE})
    
    if [ "$BUCKET_NAME" == "null" ] || [ -z "$BUCKET_NAME" ]; then
        echo "Error: No 'bucket' specified for client '${CLIENT_ID}' in terraform_vars"
        echo "Please add 'bucket: your-bucket-name' to the client's terraform_vars section"
        exit 1
    fi
    
    echo ">>> Using S3 bucket: ${BUCKET_NAME}"
    
    # Check if .terraform directory exists and if backend config might be different
    if [ -d "terraform/.terraform" ]; then
        echo ">>> Existing .terraform directory found"
        
        # Check if user explicitly passed reconfigure flag
        RECONFIGURE_FLAG=""
        for arg in "$@"; do
            if [[ "$arg" == "-reconfigure" || "$arg" == "--reconfigure" ]]; then
                RECONFIGURE_FLAG="-reconfigure"
                echo ">>> Reconfigure flag detected"
                break
            fi
        done
        
        # If no explicit reconfigure flag, check if we need to reconfigure
        if [ -z "$RECONFIGURE_FLAG" ]; then
            echo ">>> Checking if backend reconfiguration is needed..."
            
            # Try to read current backend config (this is a simple heuristic)
            if [ -f "terraform/.terraform/terraform.tfstate" ]; then
                CURRENT_BACKEND=$(cat terraform/.terraform/terraform.tfstate 2>/dev/null | grep -o '"bucket":"[^"]*"' | cut -d'"' -f4 || echo "")
                
                if [ "$CURRENT_BACKEND" != "$BUCKET_NAME" ]; then
                    echo ">>> Backend bucket change detected: $CURRENT_BACKEND -> $BUCKET_NAME"
                    echo ">>> Adding -reconfigure flag automatically"
                    RECONFIGURE_FLAG="-reconfigure"
                fi
            fi
        fi
        
        echo ">>> Running 'terraform init' with backend config..."
        (cd terraform && terraform init -backend-config="bucket=${BUCKET_NAME}" $RECONFIGURE_FLAG "$@")
    else
        echo ">>> First time init - no .terraform directory found"
        echo ">>> Running 'terraform init' with backend config..."
        (cd terraform && terraform init -backend-config="bucket=${BUCKET_NAME}" "$@")
    fi
else
    echo ">>> Running 'terraform ${TF_COMMAND}' in terraform/ directory..."
    (cd terraform && terraform ${TF_COMMAND} "$@")
fi