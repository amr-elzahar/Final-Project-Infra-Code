# ITI Final Project

Deploy a fully automated node js application on GKE cluster using CI/CD with jenkins and configuration management with Ansible. 


## Usage
This repo has 3 main directories:


1) terraform directory has a code to build infrastructute on Google Cloud. You need to get into this directory and the run terraform commands.

NOTE: I use local-exec provisioner to echo the public IP of the management VM to the inventory.txt file in ansible directory. So make sure to change the path in this local-exec provisioner to match your path.

Then you can safely tun the following comands:
```
#To authenticate (you may use this link https://registry.terraform.io/providers/hashicorp/google/latest/docs/guides/getting_started):
cloud auth application-default login
  
#To initialize working directory containing configuration files 
terraform init

#To format your code
terraform fmt

#To create the infrastructure 
terraform apply --auto-approve
```

2) ansible directory contains on main.yaml file and the inverntory.txt that contains the puplic IP of the management VM and ansible.cfg that contains the ansible configuration. To generate such a file, You need to run this command:
```
ansible-config init --disabled > ansible.cfg
``` 
then you have to add defaults section at the very beginning of the file and make sure to provide the private_key_file and the path to inventory.txt which is located in this directory.

What is ansible gonna do? 

ansibe main.yaml file has some to tasks to perform, it creates two directories: one for the master node and the other one for the slave node. Then it copys the deployment files for each node from the local machine to the remote host finally run kubectl commands for each node as well.

NOTE: make sure to change paths in the main.yaml file and always use absolute path not relative path. 

Finally you can run this command:
```
#Run Ansible playbook
ansible-playbook main.yaml
```


3) jenkins-deployment directory that contains two subdirectories: one for the slave node and the other for master node. Each directory has the deployment files set up jenkins server and a salve node on the GKE. 

