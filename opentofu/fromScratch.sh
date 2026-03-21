# 
rm -rf .terraform .terraform terraform.tfstate terraform.tfstate.backup

./packer_built_all.sh

# initialize tofu
tofu init

tofu import -var-file="credentials.tfvars" 'module.management.proxmox_virtual_environment_vm.management' pve/100

# create network
tofu apply -var-file="credentials.tfvars"