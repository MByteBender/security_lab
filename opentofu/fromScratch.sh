
# initialize tofu
tofu init

# create network
tofu plan -var-file="credentials.tfvars"
tofu apply -var-file="credentials.tfvars"