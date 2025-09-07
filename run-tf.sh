#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status.

# --- Configuration ---
CONFIG_FILE="env_vars.yml"
TF_VARS_FILE="terraform/generated.auto.tfvars.json"

# --- Script Logic ---
if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <plan|apply|destroy|...> <client_id>"
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

echo ">>> Running 'terraform ${TF_COMMAND}' in terraform/ directory..."
(cd terraform && terraform ${TF_COMMAND} "$@")