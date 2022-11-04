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
  config.vm.box = "bento/ubuntu-20.04"

  config.vm.provider "virtualbox" do |vb|
    # Display the VirtualBox GUI when booting the machine
    # vb.gui = true

    # Customize the amount of memory on the VM:
    vb.memory = 10096 # MB
    vb.cpus = 7
  end

  # Enable provisioning with a shell script. Additional provisioners such as
  # Ansible, Chef, Docker, Puppet and Salt are also available. Please see the
  # documentation for more information about their specific syntax and use.
  config.vm.provision "shell", inline: <<-SHELL
    # speed up provision
    sudo apt-get remove -y --purge man-db # no need for man

    # install dependencies
    apt-get update
    sudo apt-get remove docker docker-engine docker.io containerd runc
    apt-get install -y make git gcc build-essential jq python3-pip lttng-modules-dkms lttng-tools liblttng-ust-* apt-transport-https ca-certificates curl gnupg-agent software-properties-common zip unzip golang-cfssl
    sudo pip install pyyaml

    # install go
    wget -q https://go.dev/dl/go1.19.linux-amd64.tar.gz
    tar -xf go1.19.linux-amd64.tar.gz
    sudo rm -rf /usr/local/go && sudo mv go /usr/local
    rm go1.19.linux-amd64.tar.gz
    echo "export PATH=$PATH:/usr/local/go/bin:/home/vagrant/go/bin" >> /home/vagrant/.profile
    echo "export PATH=$PATH:/usr/local/go/bin:/home/vagrant/go/bin" >> /root/.profile
    export PATH=$PATH:/usr/local/go/bin:/home/vagrant/go/bin

    # install docker and containerd
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io
    sudo usermod -aG docker vagrant

    ## install etcd
    # k8s/hack/install-etcd.sh
    # echo "export PATH=/home/vagrant/k8s/third_party/etcd:$PATH" >> /home/vagrant/.profile
    # echo "export PATH=/home/vagrant/k8s/third_party/etcd:$PATH" >> /root/.profile
    # export PATH="/home/vagrant/k8s/third_party/etcd:${PATH}"

    # install benchmark
    git clone https://github.com/huaqiangwang/DeathStarBench-1/ benchmark
    (cd benchmark && git checkout 5a08c1ddf429d19b6549d3a24e13da98834d2b36)

    # lttng setup
    usermod -a -G tracing vagrant
  SHELL
end
