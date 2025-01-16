# EKS Hybrid Nodes Network Testing Procedure

This guide details the test procedure used to test network disconnections with EKS Hybrid Nodes as detailed in the EKS Best Practices Guide.

## Overview

Network disconnections can be simulated in a number of ways including blocking traffic at the on-premises firewall, at the Amazon VPC, or at the host layer. We ran multiple tests injecting network issues at both the on-premises network and host layers. You can alternatively use tools such as [AWS Fault Injection Service (FIS)](https://docs.aws.amazon.com/fis/latest/userguide/what-is.html) to inject and simulate different forms of network issues. The steps in this guide show how to block traffic at the host layer, which should be portable across different types of environments.

During the test runs, we monitor the node status, pod status, node condition status, application writes, and application reads to observe the behavior of the cluster and application. It is also useful to observe the `kube-controller-manager` `node-lifecycle-controller` logs on the EKS control plane to view how the cluster perceives the node status changes. To enable the EKS control plane logs, see [Send control plane logs to CloudWatch Logs](https://docs.aws.amazon.com/eks/latest/userguide/control-plane-logs.html) in the EKS User Guide.

## Procedure

### Start collection

Before disconnecting your nodes, start collecting the primary cluster and application status indicators with the following commands.

**Collect node status**

```bash
watch -n 5 '(date +%b%d::%H:%M:%S ; kubectl get nodes -o wide) \
| tee -a node-status.txt' &>/dev/null &
```

**Collect pod status**

```bash
watch -n 5 '(date +%b%d::%H:%M:%S ; kubectl get nodes -o wide) \
| tee -a pod-status.txt' &>/dev/null &
```

**Collect node condition status**

```bash
watch -n 5 \
'(date +%b%d::%H:%M:%S ; kubectl get nodes -o json \
| jq ".items[]|{name:.metadata.name, taints:.spec.taints, status:.status.conditions[] \
| select(.type == \"Ready\")}") | tee -a taints-status.txt'  &>/dev/null &
```

**Start application writes**

```bash
watch -n 5 \
'(date +%b%d::%H:%M:%S ; curl -X POST "http://<your-LB-ip>:80/guestbook.php?cmd=set&key=test&value=$(date +%b%d::%H:%M:%S)" ; printf "\n";) \
| tee -a app-write.txt'  &>/dev/null &
```

**Start application reads**

```bash
watch -n 5 \
'(date +%b%d::%H:%M:%S ; curl -X GET "http://<your-LB-ip>:80/guestbook.php?cmd=get&key=test" ; printf "\n";) \
| tee -a app-read.txt'  &>/dev/null &
```

### Disconnect nodes

The following IP table rule blocks outgoing traffic on port 443 (control plane port) and incoming traffic on port 10250 (kubelet port)

```bash
sudo iptables -A OUTPUT -p tcp --dport 443 -j DROP; sudo iptables -A INPUT -p tcp  --dport 10250 -j DROP;
```

To enable the traffic at the end of the test run, you can use the following command.

```bash
sudo iptables -D OUTPUT -p tcp --dport 443 -j DROP; sudo iptables -D INPUT -p tcp  --dport 10250 -j DROP;
```

Note, IP tables rules do not persist through reboots. You can use the [block-traffic-persist.sh](scripts/block-traffic-persist.sh) script if you need to persist IP tables rules through reboot.

### Observe network traffic

There are a number of ways to observe the network traffic between your hybrid nodes and the EKS control plane, such as those covered in the EKS Best Practices guide for hybrid nodes. To observe traffic at the host level, you can use tools such as `iftop`. 

Install `iftop` (Ubuntu)

```bash
sudo apt install libpcap0.8 libpcap0.8-dev libncurses5 libncurses5-dev
sudo apt install iftop
```

Get IPs of the ENIs for EKS control plane connectivity

```bash
aws ec2 describe-network-interfaces \
--query 'NetworkInterfaces[?(VpcId == VPC_ID && contains(Description,Amazon EKS))].PrivateIpAddress'
```

Collect summary of network traffic in/out. In the example below, `10.226.2.64` and `10.226.3.211` are the IPs of the ENIs that EKS attached to the subnets in the user VPC. The command below will output the network information collected over 3600 seconds (60 minutes).

```bash
sudo iftop -t -B -s 3600 -L 2 -f "dst host 10.226.2.64 or 10.226.3.211" > iftop-60mins-out.txt &
sudo iftop -t -B -s 3600 -L 2 -f "src host 10.226.2.64 or 10.226.3.211" > iftop-60mins-in.txt &
```
