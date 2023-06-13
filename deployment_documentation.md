# Deployments
Each instance of the Virtual Data Lake consists of three separate servers, or nodes, that store the secret shared data, perform operations on it, and communicate with each other to compute the desired result. RosemanLabs offers a few different ways of hosting the servers and of interacting with those. To enable other important functionalities, like user management and script approval, RosemanLabs also offers the Web Portal that can be used to interface with the VDL. Finally, to enable easy testing and prototyping of Crandas scripts, a fully featured Jupyter environment will be included our testing and acceptance environments. This Jupyter environment will be preconfigured to connect to the VDL seamlessly. See Figure XXX for an overview.

TODO: add figure with all components and their structure

## Production environments
Production environments come in two different types. In the first variant, RosemanLabs hosts all three of the VDL servers at three different cloud providers. We ensure each server is managed by a different employee, who have absolutely no access to the server managed by the other employees. This ensures the shares of the secret shared data is safely distributed over three entities. However, this theoretically means RosemanLabs could disclose all data. Therefore, we offer a second variant: each party who wishes to participate in a multiparty computation agreement, can host their own VDL server. If more than three parties participate, only three parties should be selected to manage a server. If only two parties participate, RosemanLabs is able to host the third server. To learn how to deploy your own VDL-server, see Section Deploying your won VDL server.

Do note: when using a production environment, no pre-configured Jupyter environment will be provided by RosemanLabs, as these environments normally contain keys for multiple parties to make testing/development easier. However, it would break the security principle if this would be done for a production environment. To be able to execute Crandas scripts on a production environment, you should follow the Getting Started/installation (on-premise) tutorial on the [crandas documentation](https://rosemanlabs.com/rldocs/gettingstarted/02-installing.html)

## Testing environments
For testing environments, all three VDL nodes are usually hosted by RosemanLabs. Furthermore, no separate admins are present per node, which means a single RosemanLabs server admin can access all servers. Do note, this means they could theoretically reconstruct all data from the secret shares uploaded to the VDL. This means testing/acceptance environments should never be used with production data. This might not offer the guaranteed data protection that a production environment offers, but it enables us to solve any problem that might arise with less effort. Furthermore it enables us to provide a Jupyter environment that has Crandas installed and is configured to communicate with the correct VDL servers.


# Deploying your own VDL server 
The docker image needed for hosting your own VDL server can be found at ghcr.io/rosemanlabs/vdl or ghcr.io/rosemanlabs/vdl-priv. It has the following configuration options:

## Required environmental variables:
| Name | Description |
| ----------- | ----------- |
| NODE_NR | Either 0, 1 or 2, determines the order in which each node should be deployed. First node 2, then 1, then 0.|
| NODE_PEER_A_HOSTNAME | Hostname or IP address of peer a. Node 0 uses this to connect to Node 1. |
| NODE_PEER_B_HOSTNAME | Hostname or IP address of peer b. Node 0 and Node 1 use this to connect to node 2 |
## Optional environmental variables:
| Name | Description |
| ----------- | ----------- |
| NODE_PORT_OFFSET_MODE | if set to 1, will add the node number to the port numbers; can be used for single-machine deployments |
| NODE_CORES | determine the number of cores the node will use. If <= 0, then it will use all available cores |
| NODE_MEMORY | determine the amount of memory the node will use. If unset, then will use all available memory | 
| NODE_BASE_VDL_PORT | |
| NODE_BASE_HTTPS_PORT | |
| NODE_BASE_PROMETHEUS_PORT | |
| NODE_BASE_LIVENESS_PORT | |
| NODE_VDL_PORT | Port number that can be used to connect to this VDL instance. |
| NODE_HTTPS_PORT | |
| NODE_PEER_A_PORT | |
| NODE_PEER_B_PORT | |
| NODE_PROMETHEUS_PORT | |
| NODE_LIVENESS_PORT | |
| NODE_SECRETS_DIR_INIT | |
| NODE_SECRETS_DIR | |
| NODE_STATE_PATH | |
| NODE_PERSISTENCE_MODE | \[true|false\] enables persistence mode. |
| NODE_PORT_PER_CORE_MODE | |
| NODE_SCRIPT_SIGN_MODE | \[true|false\] If set to true, only signed scripts can be executed. |
| NODE_SCRIPT_SIGN_KEYS | Filenames script approver public keys. (NB: no chars from $IFS, such as spaces, are allowed in the filenames) |
| NODE_TCP_KEEPALIVE_COUNT
| NODE_TCP_KEEPALIVE_IDLE
| NODE_TCP_KEEPALIVE_INTERVAL
| NODE_HEARTBEAT_PERIOD
| NODE_HEARTBEAT_TIMEOUT_DELTA
| NODE_LOG_LEVEL | Sets the log level \[debug etc.\]|
| NODE_AUX_FLAGS | utility flag to add any flags not covered by the above. |

These values can be passed either by setting their environment variables or as command line arguments. (TODO check if this is true.)

## Deployment via Helm chart (standalone)
For ease of use, a Helm chart can be used to setup a complete VDL node on an existing Kubernetes cluster. This helm chart will deploy a stateful set which manages the VDL node, the services for connecting to it, a Kubernetes Secret for storing key material, and a persistent volume claim for storage. Optionally, a VPN client sidecar container will be deployed in the pod containing the VDL node, which can be used to connect the VDL node to any already existing OpenVPN server. 

For now, the Helm chart is not being hosted on any chart repository. Contact RosemanLabs if you would wish to use it. A proper repository will be launched in due time.

Once you have obtained the chart .tgz file, you can deploy it by running: 

'''
helm install CHART_NAME \</path/to/chart.tgz\> 
'''

The following values should be specified or can be overridden:
| Name | Required | Default | Explanation |
| ----------- | ----------- | ----------- | ----------- |
| image.repository | | ghcr.io/rosemanlabs/vdl | Repository to pull the VDL image from |
| image.pullPolicy | | Always | sets the pull policiy for all images |
| image.tag | | | Overrides the default app version tag |
| imageCredentials.name | yes | | "name of the credentials used to pull the images |
| imageCredentials.registry | | ghcr.io/rosemanlabs/vdl | Image registry the credentials belong to. |
| imageCredentials.username | yes | | Username needed for pulling the image. |
| imageCredentials.password | yes | | Password or PAT needed for pulling the image. |
| imageCredentials.email | | "" | Email belonging to the image credentials. |
| nameOverride | | "" | Overrides part of the fully qualified app name with which to reach the node. |
| fullnameOverride | | "" | Overrides the default fully qualified app name with which to reach the node. |
| core.nodeNR | yes | | Number in range \[0, 1, 2\], determines the required order of deployment of the nodes. |
| core.peerAHostname | yes | "tbd" | Sets the hostname or URL at which peer A should be reachable. |
| core.peerBHostname | yes | "tbd" | Sets the hostname or URL at which peer B should be reachable. |
| core.peerAPort | yes | "6000" | Sets the port that peer A has opened for connecting to the others. |
| core.peerBPort | yes | "6000" | Sets the port that peer B has opened for connecting to the others. |
| core.cores | | "1" | Number of cores the VDL node can use |
| core.memory | | "900M" | Number of Bytes of memory the VDL node can use |
| core.logLevel | | "debug" | Sets the log level. |
| core.scriptSignMode | | "0" | If set to "1" or "true", enforces script sign mode. |
| core.scriptSignKeys | | | If core.scriptSignMode has been set, select which keys are used for scriptSigning |
| secrets.selfsignedcaCrt | yes | | TODO add explanation of each key file |
| secrets.licenseKey | yes | | Each key should be passed as string to helm, helm will store it in a kubernetes secret|
| secrets.httpd0Crt | yes | | |
| secrets.httpd0Key | yes | | |
| secrets.httpd1Crt | yes | | |
| secrets.httpd1Key | yes | | |
| secrets.httpd2Crt | yes | | |
| secrets.httpd2Key | yes | | |
| secrets.server0Crt | yes | | |
| secrets.server0Key | yes | | |
| secrets.server0Pk | yes | | |
| secrets.server0SkB64 | yes | | |
| secrets.server1Crt | yes | | |
| secrets.server1Key | yes | | |
| secrets.server1Pk | yes | | |
| secrets.server1SkB64 | yes | | |
| secrets.server2Crt | yes | | |
| secrets.server2Key | yes | | |
| secrets.server2Pk | yes | | |
| secrets.server2SkB64 | yes | | |
| secrets.sign0PkB64 | if scriptSignMode has been set | |  |
| secrets.sign1PkB64 | if scriptSignMode has been set | | |
| secrets.sign2PkB64 | if scriptSignMode has been set | | |
| secrets.sign0Pk | if scriptSignMode has been set | | |
| secrets.sign1Pk | if scriptSignMode has been set | | |
| secrets.sign2Pk | if scriptSignMode has been set | | |
| podAnnotations | | {} | sets extra pod annotations |
| securityContext | | {} | sets the securityContext |
| serviceN2n.type | | LoadBalancer | sets the type of the service for node to node communication. |
| serviceN2n.exposePort | | 6000 | sets the port with which other nodes can contact this node. |
| serviceCrandas.enabled | | true | If true, enables users to connect their Crandas environment to this node. |
| serviceCrandas.type | | LoadBalancer | sets the type of the service for connecting with Crandas. |
| serviceCrandas.exposePort | | 9820 | sets the port with which Crandas can connect. |
| pvc.storageClassName | yes | | provide the name or the storace class, cloud dependent (standard for Google Cloud, do-block-storage for DigitalOcean, etc...) |
| ingress.enabled | | false | TODO add explanation for the ingress |
| ingress.className | |"" | |
| annotations | | {} | |
| hosts| | | |
| tls | | [] | |
| resources.limits.cpu | | 1 | sets cpu resource limits in kubernetes |
| resources.limits.memory | | 1024Mi | sets memory resource limits in kubernetes |
| resources.requests.cpu | | 1 | sets cpu resource requests in kubernetes |
| resources.requests.memory | | 1024Mi | sets memory resource requests in kubernetes |
| nodeSelector | | {} | sets nodeSelector for the VDL statefulset pod |
| tolerations | | {} | sets tolerations for the VDL statefulset pod |
|affinity | | {} |sets node affinity for the VDL statefulset pod |
| vpnEnabled | | false | if set to true, a VPN-client sidecar is created for connecting the VDL node to an existing OpenVPN-server |
| vpnConfigFile | | | if vpnEnabled, sets the contents of the .ovpn file used for connecting to the vpn server. |

This Helm chart does have quite a few required values. We recommend the following template for your overwrite file: 

```yaml
imageCredentials:
  username: "USERNAME"
  password: "PASSWORD"
core:
  nodeNr: "0"
  peerAHostname: "HOSTNAME"
  peerBHostname: "HOSTNAME"
  peerAPort: "6000"
  peerBPort: "6000"
pvc:
  storageClassName: "standard"
resources:
  limits:
    cpu: 1
    memory: 2Gi
  requests:
    cpu: 1
    memory: 2Gi
```

This can be used with the `--values overwritefile.yaml` flag of the `helm install` command. 

For setting the all of the secrets values and the vpnConfigFile, we reccomend using the `--set-file secrets.selfsignedcaCrt=/Path/to/selfsignedca.crt` flag with your `helm install` command.

## Deployment via Helm Chart (deploy_single_node.sh script)
To easily deploy a single VDL node, the `deploy_single_node.sh` script is provided. With these steps, you can setup your own VDL node:
1. Acquire the needed key material (if needed, use the scripts in the cranmera repository to generate those) and store all in a single directory
2. Create your overwrite file, a template can be found above. Be sure to set the right values.
3. Run the `deploy_single_node.sh` script with the following required arguments: <namespace> </path/to/value/overwrite/file> <path/to/secrets/dir/> where <namespace> should be the Kubernetes namespace that should be used, </path/to/value/overwrite/file> should be the location of the previously created overwrite file and <path/to/secrets/dir/> should be the path to the directory that stores the generated key material.

