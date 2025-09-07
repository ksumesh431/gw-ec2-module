---
- name: Configure gw-a server
  hosts: local
  connection: local
  gather_facts: false
  become: true

  vars:
    ansible_python_interpreter: /root/ansible-venv/bin/python3
    crowdstrike_rpm: "falcon-sensor-7.18.0-17106.amzn2023.x86_64.rpm"
    s3_bucket: "ferp-build"
    s3_path: "crowdstrike"
    client_name: ${client_name}
    proot_user: "proot"
    ssm_parameter_name: "proot-user"
    stunnel_cert_param: "/whcopa/pd/stunnel/cert"
    stunnel_conf_param: "/whcopa/pd/stunnel/conf"
    old_gw_b_server_ip: ${old_gw_b_server_ip}
  tasks:
    - name: AWS and System Setup
      block: # AWS Setup and System Configuration Block
        - name: Install AWS boto3 Python SDK for AWS interactions
          ansible.builtin.pip:
            name: boto3
            state: present
            version: 1.36.7

        - name: Verify installed boto3 version matches required 1.36.7
          ansible.builtin.command:
            cmd: python3 -c "import boto3; print(boto3.__version__)"
          register: boto3_check

        - name: Display current boto3 version for verification
          ansible.builtin.debug:
            msg: "{{ boto3_check.stdout }}"

        - name: Collect AWS EC2 instance metadata for configuration
          amazon.aws.ec2_metadata_facts:

        - name: Display current AWS region from instance metadata
          debug:
            msg: "The AWS region is {{ ansible_ec2_instance_identity_document_region }}"

        - name: Install telnet package for network connectivity testing
          ansible.builtin.dnf:
            name: telnet
            state: present

        - name: Retrieve current system hostname for comparison
          ansible.builtin.command:
            cmd: hostname
          register: current_hostname

        - name: Configure system hostname to client-specific gateway name
          ansible.builtin.command:
            cmd: hostnamectl set-hostname "{{ client_name }}-gw-a-v2"
          when: current_hostname.stdout != client_name + "-gw-a-v2"

    - name: Proot User Setup
      block: # Proot User Configuration Block
        - name: Create proot administrative user with wheel group access
          ansible.builtin.user:
            name: "{{ proot_user }}"
            state: present
            groups: wheel
            append: yes

        - name: Retrieve proot user password from SSM
          set_fact:
            proot_password: "{{ lookup('amazon.aws.ssm_parameter', ssm_parameter_name, region=ansible_ec2_instance_identity_document_region) }}"

        - name: Grant passwordless sudo access to proot user
          ansible.builtin.copy:
            content: "proot ALL=(ALL) NOPASSWD: ALL"
            dest: /etc/sudoers.d/proot
            mode: '0440'
            owner: root
            group: root
            validate: /usr/sbin/visudo -cf %s

        - name: Install passlib package using pip
          ansible.builtin.pip:
            name: passlib
            state: present

        - name: Set secure password for proot user from SSM parameter
          ansible.builtin.user:
            name: "{{ proot_user }}"
            password: "{{ proot_password | password_hash('sha512') }}"
            update_password: always

        - name: Ensure password authentication is enabled in sshd_config
          ansible.builtin.lineinfile:
            path: /etc/ssh/sshd_config
            regexp: '^#?PasswordAuthentication\s+(yes|no)'
            line: 'PasswordAuthentication yes'
            validate: /usr/sbin/sshd -t -f %s
          register: sshd_config_modified

        - name: Restart sshd service if config was modified
          ansible.builtin.service:
            name: sshd
            state: restarted
          when: sshd_config_modified.changed

    - name: Stunnel Setup
      block: # Stunnel Installation and Setup Block
        - name: Install stunnel package for secure tunneling service
          ansible.builtin.dnf:
            name: stunnel
            state: present

        # Ensure the stunnel configuration tasks
        - name: Verify existence of stunnel configuration directory
          ansible.builtin.stat:
            path: /etc/stunnel
          register: stunnel_dir

        - name: Set stunnel directory and service variables
          set_fact:
            stunnel_dir_path: "{{ '/etc/stunnel' if stunnel_dir.stat.exists else '/etc/stunnel5' }}"
            stunnel_service: "{{ 'stunnel' if stunnel_dir.stat.exists else 'stunnel5' }}"

        - name: Retrieve stunnel certificate from SSM
          set_fact:
            stunnel_cert: "{{ lookup('amazon.aws.ssm_parameter', stunnel_cert_param, region=ansible_ec2_instance_identity_document_region, decrypt=true) }}"
          ignore_errors: false

        - name: Deploy stunnel SSL certificate from SSM parameter
          ansible.builtin.copy:
            content: "{{ stunnel_cert }}"
            dest: "{{ stunnel_dir_path }}/stunnel.pem"
            mode: '0600'

        - name: Retrieve stunnel configuration from SSM
          set_fact:
            stunnel_conf: "{{ lookup('amazon.aws.ssm_parameter', stunnel_conf_param, region=ansible_ec2_instance_identity_document_region, decrypt=true) }}"
          ignore_errors: false

        - name: Deploy stunnel service configuration from SSM parameter
          ansible.builtin.copy:
            content: "{{ stunnel_conf }}"
            dest: "{{ stunnel_dir_path }}/stunnel.conf"

        - name: Configure stunnel systemd service execution path
          ansible.builtin.lineinfile:
            path: "/usr/lib/systemd/system/{{ stunnel_service }}.service"
            regexp: '^ExecStart='
            line: "ExecStart= /usr/bin/{{ stunnel_service }} {{ stunnel_dir_path }}/stunnel.conf"

        - name: Reload systemd daemon to recognize stunnel service changes
          ansible.builtin.command:
            cmd: systemctl daemon-reload

        - name: Restart stunnel service
          ansible.builtin.service:
            name: "{{ stunnel_service }}"
            state: restarted

