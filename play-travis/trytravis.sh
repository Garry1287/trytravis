#!/bin/bash
set -x

########### Installing section #########################
# Upgrade pip
sudo pip install --upgrade pip
# Install Ansible
sudo pip install ansible
# Install Ansible-lint
sudo pip install ansible-lint

echo '=============== intalling terraform ==============='
wget -O /tmp/terraform.zip https://releases.hashicorp.com/terraform/0.12.16//terraform_0.12.16_linux_amd64.zip 
sudo unzip -o -d  /usr/local/bin/ /tmp/terraform.zip
echo '=============== intalling packer ==============='
wget -O /tmp/packer.zip https://releases.hashicorp.com/packer/1.4.4/packer_1.4.4_linux_amd64.zip
sudo unzip -o -d  /usr/local/bin/ /tmp/packer.zip
echo '=============== intalling tflint ==============='
wget -O /tmp/tflint.zip https://github.com/wata727/tflint/releases/download/v0.7.4/tflint_linux_amd64.zip
sudo unzip -o -d  /usr/local/bin/ /tmp/tflint.zip


############ Test section ###########################
echo '=============== start ansible-lint ==============='
cd ansible
ansible-lint playbooks/site.yml --exclude=roles/jdauphant.nginx

cd ..
echo '=============== start packer validate ==============='
echo '=============== validate app.json ==============='
packer validate -var-file=packer/variables.json.example packer/app.json
echo '=============== validate db.json ==============='
packer validate -var-file=packer/variables.json.example packer/db.json


ssh-keygen -f ~/.ssh/appuser -q -N ""


cd ../terraform/prod
cp terraform.tfvars.example terraform.tfvars
echo "=============== terraform get ==============="
terraform get
echo "=============== terraform init ==============="
terraform init
echo "=============== terraform validate ==============="
terraform validate
echo "=============== terraform tflint ==============="
tflint 

cd ../stage/
cp terraform.tfvars.example terraform.tfvars
echo "=============== terraform get ==============="
terraform get
echo "=============== terraform init ==============="
terraform init
echo "=============== terraform validate ==============="
terraform validate
echo "=============== terraform tflint ==============="
tflint
