---
- name: Configure gw-b server
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
    old_gw_b_server_ip: ${old_gw_b_server_ip}
    recipient: "iblaggan@frontlineed.com"
    pattern: "Ok: queued as"
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
            cmd: hostnamectl set-hostname "{{ client_name }}-gw-b-v2"
          when: current_hostname.stdout != client_name + "-gw-b-v2"

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

    - name: Postfix Initial Setup
      block: # Postfix Installation and Setup Block
        - name: Install postfix,rsync and nc packages for email delivery setup
          ansible.builtin.dnf:
            name:
              - postfix
              - rsync
              - nc
            state: present

        - name: Create modified proot password
          set_fact:
            proot_password_modified: "{{ proot_password | regex_replace('23$', '') }}"

        - name: Install pexpect library in the Python environment (dependency for copying files from old server)
          ansible.builtin.pip:
            name: pexpect
            state: present

        - name: Ensure the target directory exists on this server
          ansible.builtin.file:
            path: /etc/postfix
            state: directory
            owner: root
            group: root
            mode: '0755'

    - name: Postfix Configuration File Transfer
      block: # Postfix Configuration File Copy Block
        - name: Check if /etc/postfix/access exists
          ansible.builtin.stat:
            path: "/etc/postfix/access"
          register: access_file

        - name: Copy /etc/postfix/access file from old gateway server using expect
          ansible.builtin.expect:
            command: "scp -o StrictHostKeyChecking=no proot@{{ old_gw_b_server_ip }}:/etc/postfix/access /etc/postfix/"
            responses:
              password: "{{ proot_password_modified }}"
          when: not access_file.stat.exists
          register: scp_access_result

        - name: Check if /etc/postfix/blacklisted_domains exists
          ansible.builtin.stat:
            path: "/etc/postfix/blacklisted_domains"
          register: blacklisted_domains_file

        - name: Copy /etc/postfix/blacklisted_domains file from old gateway server using expect
          ansible.builtin.expect:
            command: "scp -o StrictHostKeyChecking=no proot@{{ old_gw_b_server_ip }}:/etc/postfix/blacklisted_domains /etc/postfix/"
            responses:
              password: "{{ proot_password_modified }}"
          when: not blacklisted_domains_file.stat.exists
          register: scp_blacklisted_domains_result

        - name: Check if /etc/postfix/blacklisted_senders exists
          ansible.builtin.stat:
            path: "/etc/postfix/blacklisted_senders"
          register: blacklisted_senders_file

        - name: Copy /etc/postfix/blacklisted_senders file from old gateway server using expect
          ansible.builtin.expect:
            command: "scp -o StrictHostKeyChecking=no proot@{{ old_gw_b_server_ip }}:/etc/postfix/blacklisted_senders /etc/postfix/"
            responses:
              password: "{{ proot_password_modified }}"
          when: not blacklisted_senders_file.stat.exists
          register: scp_blacklisted_senders_result

        - name: Check if /etc/postfix/sasl_passwd exists
          ansible.builtin.stat:
            path: "/etc/postfix/sasl_passwd"
          register: sasl_passwd_file

        - name: Copy /etc/postfix/sasl_passwd file from old gateway server using expect
          ansible.builtin.expect:
            command: "scp -o StrictHostKeyChecking=no proot@{{ old_gw_b_server_ip }}:/etc/postfix/sasl_passwd /etc/postfix/"
            responses:
              password: "{{ proot_password_modified }}"
          when: not sasl_passwd_file.stat.exists
          register: scp_sasl_passwd_result

        - name: Copy /etc/postfix/main.cf file from old gateway server using expect
          ansible.builtin.expect:
            command: "scp -o StrictHostKeyChecking=no proot@{{ old_gw_b_server_ip }}:/etc/postfix/main.cf /etc/postfix/"
            responses:
              password: "{{ proot_password_modified }}"
          register: scp_main_cf_result

    - name: Postfix Service Configuration
      block: # Postfix Configuration and Service Block
        - name: Change ownership of /etc/postfix directory to root
          ansible.builtin.file:
            path: /etc/postfix
            owner: root
            group: root
            recurse: yes

        - name: Set permissions of /etc/postfix directory to 744
          ansible.builtin.file:
            path: /etc/postfix
            mode: '0744'

        - name: Ensure postfix service is enabled and running
          ansible.builtin.service:
            name: postfix
            state: started
            enabled: yes

        - name: Generate postmap for access file
          command: postmap /etc/postfix/access
          args:
            creates: /etc/postfix/access.db

        - name: Generate postmap for blacklisted_domains file
          command: postmap /etc/postfix/blacklisted_domains
          args:
            creates: /etc/postfix/blacklisted_domains.db

        - name: Generate postmap for blacklisted_senders file
          command: postmap /etc/postfix/blacklisted_senders
          args:
            creates: /etc/postfix/blacklisted_senders.db

        - name: Generate postmap for sasl_passwd file
          command: postmap /etc/postfix/sasl_passwd
          args:
            creates: /etc/postfix/sasl_passwd.db

        - name: Restart postfix service
          ansible.builtin.service:
            name: postfix
            state: restarted

    - name: Mail Testing
      block: # Mail Testing Block
        - name: Get domain from AWS SES in us-east-2
          command: aws ses list-identities --region us-east-2
          register: ses_output_us_east_2
          ignore_errors: true

        - name: Get domain from AWS SES in us-east-1 if not found in us-east-2
          command: aws ses list-identities --region us-east-1
          register: ses_output_us_east_1
          when: ses_output_us_east_2.rc != 0 or 'Identities' not in ses_output_us_east_2.stdout
          ignore_errors: true

        - name: Set domain variable from AWS SES response
          set_fact:
            domain: "{{ (ses_output_us_east_2.stdout | from_json).Identities[0] if 'Identities' in (ses_output_us_east_2.stdout | from_json) and (ses_output_us_east_2.stdout | from_json).Identities else (ses_output_us_east_1.stdout | from_json).Identities[0] if 'Identities' in (ses_output_us_east_1.stdout | from_json) and (ses_output_us_east_1.stdout | from_json).Identities else '' }}"

        - name: Debug domain variable
          debug:
            msg: "Domain fetched: {{ domain }}"

        - name: Send test email using netcat
          shell: |
            echo -e "HELO {{ domain }}\nMAIL FROM: <donotreply@{{ domain }}>\nRCPT TO: <{{ recipient }}>\nDATA\nSubject: test\n\nThis is a test email from Postfix.\n.\nQUIT" | nc localhost 25
          register: email_test_output

        - name: Verify email was queued successfully
          fail:
            msg: "Postfix email test failed! Output: {{ email_test_output.stdout }}"
          when: not email_test_output.stdout is search(pattern)
