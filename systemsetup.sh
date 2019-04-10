#!/bin/bash

{

echo "Beginning Kubernetes lab node setup" > /dev/tty
echo "-----------------------------------" > /dev/tty
echo "logging to" + " " + pwd"/k8slabsetup.log" > /dev/tty
echo "-----------------------------------" > /dev/tty

# This script was created to automate the creation of a Kubernetes node on a Rackspace cloud server
# It *should* be able to work for Centos 7 or Ubuntu 18.04+
# Ensure you create a cloud server with more then a single CPU or it will not work

# add a user
kubeadduser () {
    if [ $(id -u) -eq 0 ]; then
        read -p "Enter username : " username
        read -s -p "Enter password : " password
        egrep "^$username" /etc/passwd >/dev/null
        if [ $? -eq 0 ]; then
            echo "$username exists!"
            exit 1
        else
            pass=$(perl -e 'print crypt($ARGV[0], "password")' $password)
            useradd -m -p $pass $username
            [ $? -eq 0 ] && echo "User has been added to system!" || echo "Failed to add a user!"
       fi
   else
       echo "Only root may add a user to the system"
       exit 2
   fi
}

# create uuid to attach to server names
uuid=$(cat /dev/urandom | tr -dc 'a-zA-Z' | fold -w 8 | head -n1)

echo "Determine OS" > /dev/tty
# determine operating system - really only concerned if it is NOT ubuntu or redhat/centos
if [[ -f /etc/lsb-release ]]; then
    OS=$(lsb_release -si)
    VER=$(lsb_release -sr)
elif [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$NAME
    VER=$VERSION_ID
else
    OS=$(uname -s)
    VER=$(uname -r)
fi

# set hostname, backup /etc/hosts, re-create /etc/hosts,
if [[ $OS == 'Ubuntu' ]]; then
    echo -n "OS [ Ubuntu ]" > /dev/tty
    echo -n "Set Hostname, backup/re-create /etc/hosts" > /dev/tty
    hostnamectl set-hostname "k8slab-node-$OS-$(date +'%Y%m%d')-$uuid"
    mv /etc/hosts /etc/hosts.orig
    (echo -n "127.0.0.1 "; echo "localhost") > /etc/hosts && chmod 644 /etc/hosts
    IP=$(ifconfig eth0 | grep inet | head -n1 | awk '{print $2}')
    (echo -n "$IP "; echo $HOSTNAME) >> /etc/hosts
    
    # add non-root user
    echo -n "Add a user" > /dev/tty
    kubeadduser 
    
    # add kubernetes repository key and repository
    echo -n "Add Kubernetes key/repository, install/start-enable Docker, install dependencies" > /dev/tty
    curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add
    add-apt-repository "deb http://apt.kubernetes.io/ kubernetes-xenial main"

    # install docker
    apt install docker.io -y

    # start and enable docker
    systemctl start docker
    systemctl enable docker
  
    # install dependencies
    apt install apt-transport-https curl -y

    # disable swap
    echo "Disable swap, install kubeadm, initialize Kubernetes cluster" > /dev/tty
    swapoff -a

    # install kubeadm
    apt install kubeadm -y

    # initialize and start Kubernetes cluster
    echo -n "This part may take a while... [initializing Kubernetes node]" > /dev/tty
    sudo kubeadm init --pod-network-cidr=172.168.10.0/24
    clear
    echo -n "Kubernetes lab node setup complete!" > /dev/tty

elif [[ $OS == 'CentOS Linux' ]]; then
    echo "OS [ CentOS ]" > /dev/tty
    #set hostname, backup old /etc/hosts
    hostnamectl set-hostname "k8slab-node-$OS-$(date +'%Y%m%d')-$uuid"
    mv /etc/hosts /etc/hosts.orig
    echo "Enable br_netfilter module, set /proc/sys/net/bridge/bridge-nf-call-iptables to 1" > /dev/tty
    # ensure netilter module is loaded
    # set bridge-nf-call-iptables to 1    
    modprobe br_netfilter
    echo -n "Set Hostname, backup/re-create /etc/hosts" > /dev/tty
    echo "1" > /proc/sys/net/bridge/bridge-nf-call-iptables`
    # re-populate /etc/hosts
    (echo -n "127.0.0.1 "; echo "localhost") > /etc/hosts && chmod 644 /etc/hosts
    IP=$(ifconfig eth0 | grep inet | head -n1 | awk '{print $2}')
    export HOSTNAME=$(hostname)
    (echo -n "$IP "; echo $HOSTNAME) >> /etc/hosts
 
    echo -n "Disable SELinux" > /dev/tty
    # disable SELinux
    setenforce 0
    sed -i --follow-symlinks 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux

    echo -n "Set firewall rules. [--add-port, 6443,2379-2380,10250,10251,10252,10255]" > /dev/tty
    # set firewall rules
    firewall-cmd --permanent --add-port=6443/tcp
    firewall-cmd --permanent --add-port=2379-2380/tcp
    firewall-cmd --permanent --add-port=10250/tcp
    firewall-cmd --permanent --add-port=10251/tcp
    firewall-cmd --permanent --add-port=10252/tcp
    firewall-cmd --permanent --add-port=10255/tcp
    firewall-cmd --reload
   
    echo -n "Add a user" > /dev/tty
    # add non-root user
    kubeadduser 

    echo -n "Add Kubernetes repository" > /dev/tty
    # add kubernetes repository
    cat << EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg
       https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF

    echo -n "Disable Swap, install kubeadm and Docker" > /dev/tty
    # disable swap
    swapoff -a

    # install kubeadm and docker
    yum update -y
    yum install kubeadm docker -y
 
    # start and enable kubeadm and docker
    systemctl enable docker && systemctl restart docker
    systemctl enable kubelet && systemctl restart kubelet

    echo -n "Start and enable kubeadm/Docker. Initialize Kubernetes cluster... (This part may take a while...)" > /dev/tty
    # initialize and start Kubernetes cluster
    sudo kubeadm init --pod-network-cidr=172.168.10.0/24
    clear
    echo -n "Kubernetes lab node setup complete!" > /dev/tty

elif [[ $OS == 'uname -s' ]]; then
    echo "Sorry, this script does not support your OS at this time." > /dev/tty
    exit 1
    
fi
} &> k8slabsetup.log
