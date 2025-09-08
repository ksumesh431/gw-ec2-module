#!/bin/bash

# Update the package index
dnf update -y

# Install the latest version of Python 3 available in the repositories
dnf install -y python3

# Install pip for Python 3
dnf install -y python3-pip

# Install ansible 
dnf install -y ansible

# Install cron
dnf install -y cronie cronie-anacron

# Enable and start the cron daemon
systemctl enable --now crond





# # Create a virtual environment
# python3 -m venv /root/ansible-venv

# # Activate the virtual environment and install Ansible
# source /root/ansible-venv/bin/activate
# pip install ansible

# # Verify the Ansible installation
# ansible --version

# # Create directories and write the Ansible playbook
# mkdir -p /root/ansible/logs
# cat <<EOF >>/root/ansible/ansible_playbook.yml
# ${ansible_playbook}
# EOF

# # Run playbook
# ansible-playbook -i local, /root/ansible/ansible_playbook.yml >>/root/ansible/logs/playbook_output.log

# # # Deactivate the virtual environment
# deactivate
