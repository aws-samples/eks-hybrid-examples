# EKS Hybrid Nodes Network Testing Setup

This guide details the environment setup used to test network disconnections with EKS Hybrid Nodes as detailed in the EKS Best Practices Guide.

## Overview

The table below summarizes the environment configuration. Note, at least 5 nodes are required for majority/minority zone disruption.

| Component   | Value |
| ----------- | ----- |
| K8s version | 1.31  |
| Node count  | 5     |
| Node operating system | Ubuntu 22.04 |
| Node environment | vSphere |
| Credential provider | SSM, IAM Roles Anywhere |
| CNI | Cilium |
| Load Balancer | MetalLB L2 |
| Application | Kubernetes Guestbook |

## Procedure

The steps for the hybrid nodes prerequisites, EKS cluster creation, hybrid node setup, and CNI installation follow the standard procedures in the EKS User Guide.

See the links below for those steps.

- [Hybrid nodes prerequisites](https://docs.aws.amazon.com/eks/latest/userguide/hybrid-nodes-prereqs.html)
- [EKS cluster creation](https://docs.aws.amazon.com/eks/latest/userguide/hybrid-nodes-cluster-create.html)
- [Connecting hybrid nodes](https://docs.aws.amazon.com/eks/latest/userguide/hybrid-nodes-join.html)
- [Configure CNI](https://docs.aws.amazon.com/eks/latest/userguide/hybrid-nodes-cni.html)

### Install MetalLB

For the tests, MetalLB's L2 mode was used to advertise an IP address for the Guestbook application to the on-premises network. The IP used for the application must not conflict with any other IPs on the on-premises network. See the [manifests](/manifests) directory for the MetalLB configuration. Replace the `spec.addresses` field with the IP(s) for your network.

```bash
kubectl apply -f metallb.yaml
```

### Install Guestbook Application

The Kubernetes tutorial [Guestbook application](https://kubernetes.io/docs/tutorials/stateless-application/guestbook/) was used to observe application traffic through the network disconnection. See the [manifests](/manifests) directory for the Guestbook application configuration.

```bash
kubectl apply -f guestbook-all-in-one.yaml
```