#!/bin/bash

# Exit if any command fails
set -e

# Get the absolute path to your credentials file
# Tofu/Terraform uses .tfvars files for variables
VARS_FILE="$(pwd)/credentials.tfvars"

# Loop through every directory in the current folder
for dir in */; do
    # Remove trailing slash
    dir=${dir%/}

    # Skip hidden folders like .git or .terraform
    [[ "$dir" == .* ]] && continue

    # Check if the folder actually contains OpenTofu files
    if ls "$dir"/*.tf 1> /dev/null 2>&1; then
        echo "------------------------------------------------"
        echo " DEPLOYING INFRASTRUCTURE: $dir"
        echo "------------------------------------------------"

        (
            cd "$dir"

            # 1. Initialize (installs Proxmox provider)
            tofu init

            # 2. Plan (Optional but recommended for logs)
            # tofu plan -var-file="$VARS_FILE"

            # 3. Apply (Auto-approve so the script doesn't stop for input)
            tofu apply -var-file="$VARS_FILE" -auto-approve
        )

        echo "Successfully deployed $dir"
    else
        echo "Skipping $dir: No .tf files found."
    fi
done

echo "All infrastructure deployments are complete!"