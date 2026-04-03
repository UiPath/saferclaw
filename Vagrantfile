# -*- mode: ruby -*-
# vi: set ft=ruby :

AZURE_SUBSCRIPTION_ID = "f65321ce-fb9c-42a0-afe6-68ee26440d72"
AZURE_BLOB_ACCOUNT_NAME = "clawdbotevents"
DEFENDER_SETUP_SCRIPT_URL = "https://dfescripts.blob.core.windows.net/dfelinuxscript/MicrosoftDefenderATPOnboardingLinuxServer.py?sp=r&st=2026-04-03T11:09:34Z&se=2028-06-09T19:24:34Z&spr=https&sv=2024-11-04&sr=c&sig=5Tr4H096BLQct1e%2B91ah4G47kEoGByNPqTzYSPuohCA%3D"

# Patches vagrant-vbguest plugin to properly execute in newer Ruby environments
# where File.exists is no longer supported
unless File.respond_to?(:exists?)
  class << File
    def exists?(path)
      exist?(path)
    end
  end
end

# [Constants]
GATEWAY_HOST_PORT=1337
OPENCLAW_ENV_PATH="/etc/openclaw/service.env"
# [END]

Vagrant.configure("2") do |config|
  config.vm.define "openclaw" do |openclaw|
    openclaw.vm.box = "bento/debian-13"
    openclaw.vm.box_version = "202510.26.0"

    openclaw.vm.provider "virtualbox" do |vb|
      vb.gui = false
      vb.memory = "4096"
      vb.check_guest_additions = false
      if Vagrant.has_plugin?("vagrant-vbguest")
          config.vbguest.auto_update = false
      end
    end

    openclaw.ssh.shell = "bash"

    openclaw.vm.provision "shell" do |s|
      s.privileged = true
      s.name="set-dns-nameservers"
      s.inline = <<-SCRIPT
        echo "nameserver 1.1.1.1" > /etc/resolv.conf.head
        echo "nameserver 8.8.8.8" >> /etc/resolv.conf.head
      SCRIPT
    end
    openclaw.vm.network "forwarded_port", guest: 80, host: GATEWAY_HOST_PORT, host_ip: "127.0.0.1"

    openclaw.vm.synced_folder ".", "/vagrant", disabled: true

    ## Add openclaw user and group
    openclaw.vm.provision "shell" do |s|
      s.privileged = true
      s.inline = <<-SCRIPT
        # add separate group/user for openclaw
        grep -q openclaw /etc/group || groupadd -g 10001 openclaw &&
        grep -q openclaw /etc/passwd ||useradd -u 10001 -g openclaw -d /home/openclaw -s /usr/sbin/nologin -m openclaw
      SCRIPT
    end
    ## END

    ## Install dependencies
    openclaw.vm.provision "shell" do |s|
      s.privileged = true
      s.name="install-dependencies"
      s.env =  {
        "ENV" => "$HOME/.bashrc",
        "DEBIAN_FRONTEND" => "noninteractive",
        "AZURE_SUBSCRIPTION_ID" => AZURE_SUBSCRIPTION_ID,
        "DEFENDER_SETUP_SCRIPT_URL" => DEFENDER_SETUP_SCRIPT_URL,
      }
      s.path= "./vagrant/install-deps.sh"
    end
    ## END

    ## Build docker images for sandboxing
    openclaw.vm.provision "docker"
    openclaw.vm.provision "file" do |file|
      file.source = "vagrant/docker"
      file.destination = "/tmp/openclaw-docker-sandbox"
    end
    openclaw.vm.provision "shell" do |s|
      s.privileged = true
      s.name="build-docker-sandbox"
      s.inline = <<-SCRIPT
        cd /tmp/openclaw-docker-sandbox
        bash scripts/sandbox-setup.sh
        bash scripts/sandbox-browser-setup.sh
        rm -rf /tmp/openclaw-docker-sandbox
      SCRIPT
    end
    ## END


    ## Copy service files to the VM
    openclaw.vm.provision "file" do |file|
      file.source = "vagrant/openclaw.config.json"
      file.destination = "/tmp/openclaw/config.json"
    end
    openclaw.vm.provision "file" do |file|
      file.source = "vagrant/openclaw-startup.sh"
      file.destination = "/tmp/openclaw/startup.sh"
    end
    openclaw.vm.provision "file" do |file|
      file.source = "vagrant/openclaw.service"
      file.destination = "/tmp/openclaw/openclaw.service"
    end
    openclaw.vm.provision "file" do |file|
      file.source = "vagrant/openclaw.service.env"
      file.destination = "/tmp/openclaw/openclaw.service.env"
    end
    openclaw.vm.provision "file" do |file|
      file.source = "vagrant/fluentbit.yaml"
      file.destination = "/tmp/fluentbit/conf.yaml"
    end
    openclaw.vm.provision "file" do |file|
      file.source = "vagrant/setup-azure-monitor.sh"
      file.destination = "~/utils/setup-azure-monitor.sh"
    end
    openclaw.vm.provision "file" do |file|
      file.source = "vagrant/nginx/nginx.conf"
      file.destination = "/tmp/nginx-conf/nginx.conf"
    end
    openclaw.vm.provision "file" do |file|
      file.source = "vagrant/nginx/token-expired.html"
      file.destination = "/tmp/nginx-conf/token-expired.html"
    end
    openclaw.vm.provision "shell" do |s|
      s.privileged = false
      s.name="copy-config"
      s.inline = <<-SCRIPT
        # [Openclaw Configs]
        sudo mkdir -p /etc/openclaw

        sudo mv /tmp/openclaw/openclaw.service /etc/systemd/system/openclaw.service
        sudo mv /tmp/openclaw/config.json /etc/openclaw/config.json
        sudo mv /tmp/openclaw/startup.sh /etc/openclaw/startup.sh
        sudo mv /tmp/openclaw/openclaw.service.env #{OPENCLAW_ENV_PATH}
        sudo rm -rf /tmp/openclaw

        sudo chmod 700 /etc/openclaw
        sudo chown -R openclaw:openclaw /etc/openclaw
        sudo chmod 500 /etc/openclaw/startup.sh

        # [FluentBit Configs]
        sudo mkdir -p /etc/fluent-bit
        sudo mv /tmp/fluentbit/conf.yaml /etc/fluent-bit/conf.yaml

        # [Nginx Configs]
        sudo mv /tmp/nginx-conf/nginx.conf /etc/nginx/nginx.conf
        sudo mv /tmp/nginx-conf/token-expired.html /usr/share/nginx/html/token-expired.html
        sudo rm -f /etc/nginx/sites-enabled/default
        sudo rm -rf /tmp/nginx-conf

        # [Utils]
        chmod +x ~/utils/setup-azure-monitor.sh
      SCRIPT
    end
    ## END

    openclaw.trigger.after :up do |trigger|
      trigger.name="config-migrations"
      trigger.info="Applying migrations to openclaw config"
      trigger.run_remote = {
        env: {
          "GATEWAY_PORT" => GATEWAY_HOST_PORT,
          "OPENCLAW_ENV_PATH" => OPENCLAW_ENV_PATH,
        },
        path: "./vagrant/migrations.sh"
      }
    end

    openclaw.trigger.after :up, :reload do |trigger|
      trigger.name="start-service"
      trigger.info="Running post-boot setup"
      trigger.run_remote = {
        privileged: true,
        env: {
            "AZURE_SUBSCRIPTION_ID" => AZURE_SUBSCRIPTION_ID,
            "AZURE_BLOB_ACCOUNT_NAME" => AZURE_BLOB_ACCOUNT_NAME,
        },
        path: "./vagrant/post-boot-setup.sh"
      }
    end

  end
end
