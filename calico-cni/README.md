# Using Calico CNI with EKS Hybrid Nodes

- It is recommended to run Calico in overlay / tunnel mode with VXLAN as the [encapsulation method](https://docs.tigera.io/calico/latest/networking/configuring/vxlan-ipip). This mode has the fewest requirements on the underlying physical network. For more information on the different Calico networking modes, see [Determining the best networking option](https://docs.tigera.io/calico/latest/networking/determine-best-networking) in the Calico documentation.
- It is recommended to run Calico with `natOutgoing` set to `true`. With `natOutgoing` set to `true`, the source IP address of all pod traffic leaving the cluster is translated to the IP address of the node. If you disable `natOutgoing`, then your pod CIDRs must be routable on your on-premises network and you must configure your EKS cluster with your remote pod networks.
- If you are running webhooks on your hybrid nodes, your pod CIDRs must be routable on your on-premises network and you must configure your EKS cluster with your remote pod networks. If your pod CIDRs are not routable on your on-premises network, then it is recommended to run webhooks on cloud nodes in the same cluster.
- A common way to make your pod CIDR routable on your on-premises network is to advertise pod addresses with BGP. To use BGP with Calico, you must set `installation.calicoNetwork.bgp: Enabled` in your Helm configuration. For more information on Calico's BGP support, see [Configure BGP peering](https://docs.tigera.io/calico/latest/networking/configuring/bgp) in the Calico documentation.
- The default IP Address Management (IPAM) in Calico is called [Calico IPAM](https://docs.tigera.io/calico/latest/networking/ipam/get-started-ip-addresses#calico-ipam), where the `calico-ipam` plugin allocates IP addresses for each node based on user-configured pod CIDRs. The pod CIDRs are configured with the `installation.calicoNetwork.ipPools.cidr` Helm value, which should match the remote pod network CIDRs you configured for your Amazon EKS cluster. Calico allocates segments from the `ipPools.cidr` to each node. The size of the per node segments is configured with the `ipPools.blockSize` Helm value. For more information on IPAM with Calico, see [Get started with IP address management](https://docs.tigera.io/calico/latest/networking/ipam/get-started-ip-addresses) in the Calico documentation.

## Install Calico on hybrid nodes

1. Install the helm CLI on your command-line environment. See the [Helm documentation](https://helm.sh/docs/intro/quickstart/) for installation instructions.

2. Install the Calico Helm repo.

   ```bash
   helm repo add projectcalico https://docs.tigera.io/calico/charts
   ```

3. Create a YAML file called `calico-values.yaml`. The following example configures all Calico components to run only on hybrid nodes by setting affinity for the `eks.amazonaws.com/compute-type: hybrid` label.
- Replace `POD_CIDR` with the CIDR ranges for your pods. If you configured your Amazon EKS cluster with remote pod networks, the `POD_CIDR` that you specify for Calico should be the same as the remote pod networks. For example, `10.100.0.0/24`. Your on-premises pod CIDR must not overlap with your on-premises node CIDR when running the CNI in overlay / tunnel mode.
- Replace `CIDR_SIZE` with the size of the CIDR segment you want to allocate to each node. For example, `25` for a /25 segment size of 128 pod addresses per node. For more information on CIDR `blockSize` and changing the `blockSize`, see [Change IP pool block size](https://docs.tigera.io/calico/latest/networking/ipam/change-block-size) in the Calico documentation.
- In the example below, `natOutgoing` is enabled and `bgp` is disabled. Modify these values based on your target configuration.

   ```yaml
   installation:
     enabled: true
     cni:
       type: Calico
       ipam:
         type: Calico
     calicoNetwork:
       bgp: Disabled
       ipPools:
       - cidr: POD_CIDR
         blockSize: CIDR_SIZE
         encapsulation: VXLAN
         natOutgoing: Enabled
         nodeSelector: eks.amazonaws.com/compute-type == "hybrid"
     controlPlaneReplicas: 1
     controlPlaneNodeSelector:
       eks.amazonaws.com/compute-type: hybrid
     calicoNodeDaemonSet:
       spec:
         template:
           spec:
             nodeSelector:
               eks.amazonaws.com/compute-type: hybrid
     csiNodeDriverDaemonSet:
       spec:
         template:
           spec:
             nodeSelector:
               eks.amazonaws.com/compute-type: hybrid
     calicoKubeControllersDeployment:
       spec:
         template:
           spec:
             nodeSelector:
               eks.amazonaws.com/compute-type: hybrid
     typhaDeployment:
       spec:
         template:
           spec:
             nodeSelector:
               eks.amazonaws.com/compute-type: hybrid
   ```

4. Install Calico on your cluster.
   - Replace `CALICO_VERSION` with a Calico version (for example `v3.29.5`), see the [Calico releases](https://github.com/projectcalico/calico/releases) to find the latest patch release for your Calico minor version.
   - If you are using a specific `kubeconfig` file, use the `--kubeconfig` flag.

   ```bash
   helm install calico projectcalico/tigera-operator \
       --version CALICO_VERSION \
       --namespace kube-system \
       -f calico-values.yaml
   ```

5. You can confirm your Calico installation was successful with the following commands. You should see the `tigera-operator` deployment, the `calico-node` agent running on each of your hybrid nodes, the `calico-apiserver`, `csi-node-driver`, and `calico-kube-controllers` deployed. Additionally, your hybrid nodes should now have status `Ready`. If you are using `natOutgoing: Disabled`, then all of the Calico components will not be able to start successfully until you advertise your pod addresses with your on-premises network. For information on how to configure BGP for Calico, proceed to the next step.

   ```bash
   kubectl get pods -A
   ```

   ```bash
   NAMESPACE          NAME                                       READY   STATUS    RESTARTS   AGE
   calico-apiserver   calico-apiserver-6c77bb6d46-2n8mq          1/1     Running   0          69s
   calico-system      calico-kube-controllers-7c5f8556b5-7h267   1/1     Running   0          68s
   calico-system      calico-node-s5nnk                          1/1     Running   0          68s
   calico-system      calico-typha-6487cc9d8c-wc5jm              1/1     Running   0          69s
   calico-system      csi-node-driver-cv42d                      2/2     Running   0          68s
   kube-system        coredns-7bb495d866-2lc9v                   1/1     Running   0          6m27s
   kube-system        coredns-7bb495d866-2t8ln                   1/1     Running   0          157m
   kube-system        kube-proxy-lxzxh                           1/1     Running   0          18m
   kube-system        tigera-operator-f8bc97d4c-28b4d            1/1     Running   0          90s
   ```

   ```bash
   kubectl get nodes
   ```

   ```bash
   NAME                  STATUS   ROLES    AGE    VERSION
   mi-0c6ec2f6f79176565  Ready    <none>   5h13m  v1.31.0-eks-a737599
   ```

6. If you installed Calico without BGP, skip this step. To configure BGP, create a file called `calico-bgp.yaml` with a `BGPPeer` configuration and a `BGPConfiguration`. It is important to distinguish `BGPPeer` and `BGPConfiguration`. The `BGPPeer` is the BGP-enabled router or remote resource with which the nodes in a Calico cluster will peer. Replace `ONPREM_ROUTER_IP`, `ONPREM_ROUTER_ASN`, and `LOCAL_ASN` in the example below with the values for your on-premises environment, which you might have to obtain from your network administrator. The `keepOriginalNextHop: true` setting is used to ensure each node advertises only the pod network CIDR that it owns.

   ```bash
   apiVersion: projectcalico.org/v3
   kind: BGPPeer
   metadata:
     name: calico-hybrid-nodes
   spec:
     peerIP: ONPREM_ROUTER_IP
     asNumber: ONPREM_ROUTER_ASN
     keepOriginalNextHop: true
   ---
   apiVersion: projectcalico.org/v3
   kind: BGPConfiguration
   metadata:
     name: default
   spec:
     nodeToNodeMeshEnabled: false
     asNumber: LOCAL_ASN
   ```

7. Apply the file to your cluster.

   ```bash
   kubectl apply -f calico-bgp.yaml
   ```

8. Confirm the Calico pods are running with the following command.

   ```bash
   kubectl get pods -n calico-system -w
   ```

   ```bash
   NAMESPACE          NAME                                       READY   STATUS    RESTARTS       AGE
   calico-apiserver   calico-apiserver-598bf99b6c-2vltk          1/1     Running   0              3h24m
   calico-system      calico-kube-controllers-75f84bbfd6-zwmnx   1/1     Running   31 (59m ago)   3h20m
   calico-system      calico-node-9b2pg                          1/1     Running   0              5h17m
   calico-system      calico-typha-7d55c76584-kxtnq              1/1     Running   0              5h18m
   calico-system      csi-node-driver-dmnmm                      2/2     Running   0              5h18m
   kube-system        coredns-7bb495d866-dtn4z                   1/1     Running   0              6h23m
   kube-system        coredns-7bb495d866-mk7j4                   1/1     Running   0              6h19m
   kube-system        kube-proxy-vms28                           1/1     Running   0              6h12m
   kube-system        tigera-operator-55f9d9d565-jj9bg           1/1     Running   0              73m
   ```

If you encountered issues during these steps, see the [troubleshooting guidance](https://docs.tigera.io/calico/latest/operations/troubleshoot/vpp) in the Calico documentation.

## Upgrade Calico on hybrid nodes

Before upgrading your Calico deployment, carefully review the [Calico upgrade documentation](https://docs.tigera.io/calico/latest/operations/upgrading/kubernetes-upgrade) and the [release notes](https://docs.tigera.io/calico/latest/release-notes/) to understand the changes in the target Calico version. The upgrade steps vary based on whether you are using Helm, the Calico operator, and the type of datastore. The steps below assume use of Helm.

1. Download the operator manifest for the version of Calico you are upgrading to. Replace `CALICO_VERSION` with the version you are upgrading to, for example `v3.29.0`. Make sure to prepend the `v` to the major.minor.patch.

   ```bash
   kubectl apply --server-side --force-conflicts \
       -f https://raw.githubusercontent.com/projectcalico/calico/CALICO_VERSION/manifests/operator-crds.yaml
   ```

2. Run `helm upgrade` to upgrade your Calico deployment. Replace `CALICO_VERSION` with the version you are upgrading to, for example `v3.29.0`. Create the `calico-values.yaml` file from the configuration values that you used to install Calico.

   ```bash
   helm upgrade calico projectcalico/tigera-operator \
       --version CALICO_VERSION \
       --namespace kube-system \
       -f calico-values.yaml
   ```

## Delete Calico from hybrid nodes

1. Run the following command to uninstall Calico components from your cluster. Note that uninstalling the CNI might impact the health of nodes and pods and shouldn't be performed on production clusters. If you installed Calico in a namespace other than `kube-system` change the namespace in the command below.

   ```bash
   helm uninstall calico --namespace kube-system
   ```

   Note that the interfaces and routes configured by Calico are not removed by default when you remove the CNI from the cluster.

2. To clean up the on-disk configuration files and resources, remove the Calico files from the `/opt/cni` and `/etc/cni` directories.

3. To remove the Calico CRDs from your cluster, run the following commands.

   ```bash
   kubectl get crds -oname | grep "calico" | xargs kubectl delete
   ```

   ```bash
   kubectl get crds -oname | grep "tigera" | xargs kubectl delete
   ```
