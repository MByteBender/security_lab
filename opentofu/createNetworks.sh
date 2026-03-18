tofu init
tofu plan -var-file="credentials.tfvars"
tofu apply -var-file="credentials.tfvars" -parallelism=1