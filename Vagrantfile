# this file is what is going to define the virtual machines and how to build them 

# this will contain information for vagrant to be able to create 3 VMs, their IPs, 
# RAM/CPU, port forwards, etc. All the setup script to run for each


# -*- mode: ruby -*-
# vi: set ft=ruby :

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.
Vagrant.configure("2") do |config|
  # The most common configuration options are documented and commented below.
  # For a complete reference, please see the online documentation at
  # https://docs.vagrantup.com.

  # Every Vagrant development environment requires a box. You can search for
  # boxes at https://vagrantcloud.com/search.
  config.vm.box = "hashicorp-education/ubuntu-24-04"
  config.vm.box_version = "0.1.0"

  # --- DB VM ---
  config.vm.define "db" do |db|
    db.vm.hostname = "db"
    # db.vm.network "private_network", ip: "10.10.10.10"
    db.vm.provider "virtualbox" do |vb|
      vb.name   = "cosc349-db"
      vb.memory = 1024
      vb.cpus   = 1
    end
    db.vm.synced_folder "./db", "/opt/db"
    db.vm.provision "shell", path: "provision/db.sh"
  end

  # --- API VM ---
  config.vm.define "api" do |api|
    api.vm.hostname = "api"
    # api.vm.network "private_network", ip: "10.10.10.11"
    api.vm.network "forwarded_port", guest: 3000, host: 3000, auto_correct: true
    api.vm.provider "virtualbox" do |vb|
      vb.name   = "cosc349-api"
      vb.memory = 1024
      vb.cpus   = 1
    end
    api.vm.synced_folder "./api", "/opt/api"
    api.vm.provision "shell", path: "provision/api.sh"
  end

  # --- WEB VM ---
  config.vm.define "web" do |web|
    web.vm.hostname = "web"
    # web.vm.network "private_network", ip: "10.10.10.12"
    web.vm.network "forwarded_port", guest: 80, host: 8080, auto_correct: true
    web.vm.provider "virtualbox" do |vb|
      vb.name   = "cosc349-web"
      vb.memory = 512
      vb.cpus   = 1
    end
    web.vm.synced_folder "./web", "/var/www/html"
    web.vm.provision "shell", path: "provision/web.sh"
  end
  # Disable automatic box update checking. If you disable this, then
  # boxes will only be checked for updates when the user runs
  # `vagrant box outdated`. This is not recommended.
  # config.vm.box_check_update = false

  # Create a forwarded port mapping which allows access to a specific port
  # within the machine from a port on the host machine. In the example below,
  # accessing "localhost:8080" will access port 80 on the guest machine.
  # NOTE: This will enable public access to the opened port
  # config.vm.network "forwarded_port", guest: 80, host: 8080

  # Create a forwarded port mapping which allows access to a specific port
  # within the machine from a port on the host machine and only allow access
  # via 127.0.0.1 to disable public access
  # config.vm.network "forwarded_port", guest: 80, host: 8080, host_ip: "127.0.0.1"

  # Create a private network, which allows host-only access to the machine
  # using a specific IP.
  # config.vm.network "private_network", ip: "192.168.33.10"

  # Create a public network, which generally matched to bridged network.
  # Bridged networks make the machine appear as another physical device on
  # your network.
  # config.vm.network "public_network"

  # Share an additional folder to the guest VM. The first argument is
  # the path on the host to the actual folder. The second argument is
  # the path on the guest to mount the folder. And the optional third
  # argument is a set of non-required options.
  # config.vm.synced_folder "../data", "/vagrant_data"

  # Disable the default share of the current code directory. Doing this
  # provides improved isolation between the vagrant box and your host
  # by making sure your Vagrantfile isn't accessible to the vagrant box.
  # If you use this you may want to enable additional shared subfolders as
  # shown above.
  # config.vm.synced_folder ".", "/vagrant", disabled: true

  # Provider-specific configuration so you can fine-tune various
  # backing providers for Vagrant. These expose provider-specific options.
  # Example for VirtualBox:
  #
  # config.vm.provider "virtualbox" do |vb|
  #   # Display the VirtualBox GUI when booting the machine
  #   vb.gui = true
  #
  #   # Customize the amount of memory on the VM:
  #   vb.memory = "1024"
  # end
  #
  # View the documentation for the provider you are using for more
  # information on available options.

  # Enable provisioning with a shell script. Additional provisioners such as
  # Ansible, Chef, Docker, Puppet and Salt are also available. Please see the
  # documentation for more information about their specific syntax and use.
  # config.vm.provision "shell", inline: <<-SHELL
  #   apt-get update
  #   apt-get install -y apache2
  # SHELL
end
