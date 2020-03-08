# labK8Scluster
Collection of things I use for my test Openstack/K8s cluster

New thing I learned when setting up Ubuntu nodes with Rasberry Pi... make sure you add the following to /boot/cmdline.txt

This was the error I was receiving;


CGROUPS_MEMORY: missing
error execution phase preflight: [preflight] Some fatal errors occurred:
        [ERROR FileContent--proc-sys-net-bridge-bridge-nf-call-iptables]: /proc/sys/net/bridge/bridge-nf-call-iptables does not exist
        [ERROR FileContent--proc-sys-net-ipv4-ip_forward]: /proc/sys/net/ipv4/ip_forward contents are not set to 1
        [ERROR SystemVerification]: missing cgroups: memory
[preflight] If you know what you are doing, you can make a check non-fatal with `--ignore-preflight-errors=...`
To see the stack trace of this error execute with --v=5 or higher
