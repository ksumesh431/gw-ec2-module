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

