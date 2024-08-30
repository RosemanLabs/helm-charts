# Deploying your own VDL server using helm
For ease of use, a Helm chart can be used to setup a complete VDL node on an existing Kubernetes cluster. This helm chart will deploy a StatefulSet which manages the VDL node, the services for connecting to it, a Kubernetes Secret for storing key material, and a persistent volume claim for storage. Optionally, a VPN client sidecar container will be deployed in the pod containing the VDL node, which can be used to connect the VDL node to any already existing OpenVPN server.

Due to the large number of values that need to be overwritten, we recomend deploying by running `deploy_single_node.sh` from the `scripts` directory instead of using helm commands directly.

With the following steps, you can setup your own VDL node:

1. Add the Roseman Labs helm chart repository (replace `REPO_NAME` with any name you want): `helm repo add REPO_NAME https://helm.rosemancloud.com`.
2. Receive from Roseman Labs the credentials needed for pulling the docker image (which will be used by the k8s/helm server).
3. Acquire the needed key material (discuss with your Roseman Labs contact on how to do this) and store it all in a single directory.
4. Create your override file based on the following template (see appendix 1 for details on the parameters):

    ```yaml
    imageCredentials:
      username: "USERNAME"
      password: "PASSWORD"
    core:
      nodeNr: "2"
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
5. Run the `deploy_single_node.sh` script with the following format:
```
./deploy_single_node.sh [-c <openvpn_file>] <namespace> <override_file> <override_secrets_dir>
```
  - `-c <openvpn_file>`: VPN configuration _(optional)_
  - `<namespace>`: Kubernetes namespace where the objects will be created
  - `<override_file>`: the name of the previously created override file
  - `<override_secrets_dir>`: the name of the directory that stores the generated (override) key material

# appendix I: values you can configure in the helm chart

During install, the following values should be specified or can be overridden:

| Name                      | Required                 | Default                 | Explanation                                                                            |
| ------------------------- | ------------------------ | ----------------------- | -------------------------------------------------------------------------------------- |
| image.repository          |                          | ghcr.io/rosemanlabs/vdl | Repository to pull the VDL image from                                                  |
| image.pullPolicy          |                          | Always                  | sets the pull policiy for all images                                                   |
| image.tag                 |                          |                         | Overrides the default app version tag                                                  |
| imageCredentials.name     | yes                      |                         | "name of the credentials used to pull the images                                       |
| imageCredentials.registry |                          | ghcr.io/rosemanlabs/vdl | Image registry the credentials belong to                                               |
| imageCredentials.username | yes                      |                         | Username needed for pulling the image                                                  |
| imageCredentials.password | yes                      |                         | Password or PAT needed for pulling the image                                           |
| imageCredentials.email    |                          | ""                      | Email belonging to the image credentials                                               |
| nameOverride              |                          | ""                      | Overrides part of the fully qualified app name with which to reach the node            |
| fullnameOverride          |                          | ""                      | Overrides the default fully qualified app name with which to reach the node            |
| core.nodeNR               | yes                      |                         | Number in range \[0, 1, 2\], nodes should be deployed in descending order              |
| core.peerAHostname        | yes                      | "tbd"                   | Sets the hostname or URL at which peer A should be reachable                           |
| core.peerBHostname        | yes                      | "tbd"                   | Sets the hostname or URL at which peer B should be reachable                           |
| core.peerAPort            | yes                      | "6000"                  | Sets the port that peer A has opened for connecting to the others                      |
| core.peerBPort            | yes                      | "6000"                  | Sets the port that peer B has opened for connecting to the others                      |
| core.cores                |                          | "1"                     | Number of cores the VDL node can use                                                   |
| core.memory               |                          | "900M"                  | Number of Bytes of memory the VDL node can use                                         |
| core.logLevel             |                          | "debug"                 | Sets the log level                                                                     |
| core.persistenceMode      |                          | "1"                     | If set to "1" or "true", store tables to disk (data survives server reboots)           |
| core.dynamicConfigMode    |                          | "0"                     | If set to "1" or "true", enable dynamic config mode (required for approvals)           |
| core.scriptSignMode       |                          | "0"                     | (legacy) If set to "1" or "true", enforces script sign mode                            |
| core.scriptSignKeys       |                          |                         | (legacy) If core.scriptSignMode has been set, select which keys are used               |
| secrets.selfsignedcaCrt   | yes                      |                         | The certificate authority used for each of the TLS keys                                |
| secrets.licenseKey        | yes                      |                         | License key necessary for using the Virtual Data Lake software                         |
| secrets.httpd0Crt         | yes                      |                         |                                                                                        |
| secrets.httpd0Key         | yes                      |                         |                                                                                        |
| secrets.httpd1Crt         | yes                      |                         |                                                                                        |
| secrets.httpd1Key         | yes                      |                         |                                                                                        |
| secrets.httpd2Crt         | yes                      |                         |                                                                                        |
| secrets.httpd2Key         | yes                      |                         |                                                                                        |
| secrets.server0Crt        | yes                      |                         |                                                                                        |
| secrets.server0Key        | yes                      |                         |                                                                                        |
| secrets.server0Pk         | yes                      |                         |                                                                                        |
| secrets.server0SkB64      | yes                      |                         |                                                                                        |
| secrets.server1Crt        | yes                      |                         |                                                                                        |
| secrets.server1Key        | yes                      |                         |                                                                                        |
| secrets.server1Pk         | yes                      |                         |                                                                                        |
| secrets.server1SkB64      | yes                      |                         |                                                                                        |
| secrets.server2Crt        | yes                      |                         |                                                                                        |
| secrets.server2Key        | yes                      |                         |                                                                                        |
| secrets.server2Pk         | yes                      |                         |                                                                                        |
| secrets.server2SkB64      | yes                      |                         |                                                                                        |
| secrets.webAppPk          | yes                      |                         |                                                                                        |
| secrets.sign0PkB64        | if `core.scriptSignMode` |                         | (legacy)                                                                               |
| secrets.sign1PkB64        | if `core.scriptSignMode` |                         | (legacy)                                                                               |
| secrets.sign2PkB64        | if `core.scriptSignMode` |                         | (legacy)                                                                               |
| secrets.sign0Pk           | if `core.scriptSignMode` |                         | (legacy)                                                                               |
| secrets.sign1Pk           | if `core.scriptSignMode` |                         | (legacy)                                                                               |
| secrets.sign2Pk           | if `core.scriptSignMode` |                         | (legacy)                                                                               |
| vpnEnabled                |                          | false                   | If true, a VPN client sidecar is created to connect the VDL node to a VPN              |
| vpnLogLevel               | if `vpnEnabled`          |                         | The verbosity of OpenVPN                                                               |
| vpnConfigFile             | if `vpnEnabled`          |                         | Content of a .ovpn file, for connecting to an OpenVPN server                           |
| loggingEnabled            |                          | false                   | if true, a FileBeat sidecar is created to send the VDL logs to a Logbeat server        |
| elasticCloudID            | if `loggingEnabled`      |                         | Sets cloud.id in the filebeat config for connecting to Elastic Cloud                   |
| elasticCloudAuth          | if `loggingEnabled`      |                         | Sets cloud.auth in the filebeat config for connecting to Elastic Cloud                 |
| elasticIndex              | if `loggingEnabled`      | "onpremise"             | Sets the index name to which the filebeat will write its logs                          |
| logstashHost              | if `loggingEnabled`      |                         | Host name/IP (add :port to override default 5044) of the logstash server to connect to |
| loggingCaCrt              | if `loggingEnabled`      |                         | CA certificate for setting up a self signed TLS tunnel between Logstash and Filebeat   |
| filebeatCrt               | if `loggingEnabled`      |                         | TLS certificate authenticating Filebeat to the Logstash server                         |
| filebeatKey               | if `loggingEnabled`      |                         | Secret key belonging to the filebeatCrt certificate                                    |
| podAnnotations            |                          | {}                      | sets extra pod annotations                                                             |
| securityContext           |                          | {}                      | sets the securityContext                                                               |
| serviceN2n.type           |                          | LoadBalancer            | sets the type of the service for node to node communication                            |
| serviceN2n.exposePort     |                          | 6000                    | sets the port with which other nodes can contact this node                             |
| serviceCrandas.enabled    |                          | true                    | If true, enables users to connect their Crandas environment to this node               |
| serviceCrandas.type       |                          | LoadBalancer            | sets the type of the service for connecting with Crandas                               |
| serviceCrandas.exposePort |                          | 9820                    | sets the port with which Crandas can connect                                           |
| pvc.storageClassName      | yes                      |                         | provide the name or the storace class, cloud dependent                                 |
| ingress.enabled           |                          | false                   | TODO add explanation for the ingress                                                   |
| ingress.className         |                          | ""                      |                                                                                        |
| annotations               |                          | {}                      |                                                                                        |
| hosts                     |                          |                         |                                                                                        |
| externalDns.target        | if externalDns.enabled   |                         | The target IP for the DNS record                                                       |
| externalDns.host          | if externalDns.enabled   |                         | The hostname for the DNS record                                                        |

# appendix II: values recognized by docker image

The docker image recognizes the following parameters. Not all of these values can be set via Helm; if you need to change those, you need to create a fork of our chart.

## Required environmental variables:

| Name                 | Description                                                                        |
| -------------------- | ---------------------------------------------------------------------------------- |
| NODE_NR              | Number in range \[0, 1, 2\], nodes should be deployed in descending order          |
| NODE_PEER_A_HOSTNAME | Hostname or IP address of peer a; Node 0 uses this to connect to Node 1            |
| NODE_PEER_B_HOSTNAME | Hostname or IP address of peer b; Node 0 and Node 1 use this to connect to node 2  |

## Optional environmental variables:

| Name                         | Description                                                                                                   |
| ---------------------------- | ------------------------------------------------------------------------------------------------------------- |
| NODE_PORT_OFFSET_MODE        | if set to 1, will add the node number to the port numbers; can be used for single-machine deployments         |
| NODE_CORES                   | determine the number of cores the node will use; if <= 0, then it will use all available cores                |
| NODE_MEMORY                  | determine the amount of memory the node will use; if unset, then will use all available memory                | 
| NODE_BASE_VDL_PORT           |                                                                                                               |
| NODE_BASE_HTTPS_PORT         |                                                                                                               |
| NODE_BASE_PROMETHEUS_PORT    |                                                                                                               |
| NODE_BASE_LIVENESS_PORT      |                                                                                                               |
| NODE_VDL_PORT                | Port number that can be used to connect to this VDL instance                                                  |
| NODE_HTTPS_PORT              |                                                                                                               |
| NODE_PEER_A_PORT             |                                                                                                               |
| NODE_PEER_B_PORT             |                                                                                                               |
| NODE_PROMETHEUS_PORT         |                                                                                                               |
| NODE_LIVENESS_PORT           |                                                                                                               |
| NODE_SECRETS_DIR_INIT        |                                                                                                               |
| NODE_SECRETS_DIR             |                                                                                                               |
| NODE_STATE_PATH              |                                                                                                               |
| NODE_PERSISTENCE_MODE        |  \[true\|false\], enables persistence mode                                                                    |
| NODE_PORT_PER_CORE_MODE      |                                                                                                               |
| NODE_SCRIPT_SIGN_MODE        | \[true\|false\], if set to true, only signed scripts can be executed                                          |
| NODE_SCRIPT_SIGN_KEYS        | Filenames script approver public keys (NB: no chars from $IFS, such as spaces, are allowed in the filenames)  |
| NODE_TCP_KEEPALIVE_COUNT     |                                                                                                               |
| NODE_TCP_KEEPALIVE_IDLE      |                                                                                                               |
| NODE_TCP_KEEPALIVE_INTERVAL  |                                                                                                               |
| NODE_HEARTBEAT_PERIOD        |                                                                                                               |
| NODE_HEARTBEAT_TIMEOUT_DELTA |                                                                                                               |
| NODE_LOG_LEVEL               | Sets the log level \[debug etc.\]                                                                             |
| NODE_AUX_FLAGS               | utility flag to add any flags not covered by the above                                                        |
