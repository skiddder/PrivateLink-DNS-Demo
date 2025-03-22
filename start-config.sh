#!/bin/bash
# Retrieve values from fixtures.tfvars
resource_group_name="rg-privatelink-dns"
location="germanywestcentral"
admin_username="REPLACE-ME"
public_key="REPLACE-ME"
admin_password="REPLACE-ME"

# Print the variables to verify
echo "resource_group_name='$resource_group_name'"
echo "location='$location'"
echo "admin_username='$admin_username'"
echo "public_key='$public_key'"
echo "admin_password='$admin_password'"

# update ansible inventory file with username and password
sed -i "s/<admin_username>/$admin_username/" ./ansible/inventory.ini
sed -i "s/<admin_password>/$admin_password/" ./ansible/inventory.ini

# set subscription_id in provider.tf 
subscription_id=$(az account show --query id -o tsv)
sed -i "s/<subscription_id>/$subscription_id/" ./provider.tf

# create a fixtures.tfvars file with the variables
cat <<EOF > fixtures.tfvars
resource_group_name = "$resource_group_name"
location = "$location"
admin_username = "$admin_username"
public_key = "$public_key"
admin_password = "$admin_password"
EOF

terraform init
terraform plan -out=tfplan -var-file=fixtures.tfvars 
terraform apply -auto-approve tfplan | tee output.txt

# the vm names are hard coded in main.tf
vms=$(az vm list-ip-addresses -g $resource_group_name --query "[?contains(virtualMachine.name, 'srv')]" -o json)



for vm in $(echo "$vms" | jq -r '.[].virtualMachine.name'); do
    echo "processing $vm"
    # enable winrm so we can run ansible playbooks on the VMs
    echo "az vm run-command create --name set-winrm-$vm --vm-name $vm -g $resource_group_name --location $location --script @enable-win-rm.ps1 --async-execution"
    az vm run-command create --name set-winrm-$vm --vm-name $vm -g $resource_group_name --location $location --script @enable-win-rm.ps1 --async-execution

    # adjust the ansible inventory file to use the public IPs of the VMs
    ip_address=$(echo $vms | jq -r --arg vm "$vm" '.[] | select(.virtualMachine.name == $vm) | .virtualMachine.network.publicIpAddresses[0].ipAddress')
    sed -i "s/<replace-with-$vm-ip>/$ip_address/" ./ansible/inventory.ini
done

cd ansible
# run the ansible playbook to install the DNS server
ansible-playbook -i inventory.ini playbook.yml
cd ..

