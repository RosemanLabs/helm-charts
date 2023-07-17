#!/bin/bash

set -e

die(){
  echo "$@"
  exit 1
}

help() {
  # Display help message
  echo "deploy_single_node.sh is designed to simplify deployment of a single VDL node"
  echo 
  echo "Syntax: ./deploy_single_node.sh [-h][-c <vpnconfig.ovpn>][-t <filebeat_tls_certs_dir>][-p <chart.tgz>][-f] <namespace> <override_file> <secrets_dir>"
  echo ""
  echo "Positional arguments:"
  echo "<namespace>                         Kubernetes namespace to deploy the chart in"
  echo "<override_file>                     Path to the file containing all values that need to be overwritten, except for the secrets"
  echo "<secrets_dir>                       Path to the folder containing all keys for overwriting all .Values.secrets. values"
  echo ""
  echo "Optional general arguments:"
  echo "  -h                                Print this help message"
  echo "  -f                                Deletes any existing namespace (with the same name) before installing the chart"
  echo "  -p <chart.tgz>                    Use a local .tgz chart instead of the vdl chart of the rosemanlabs repo"
  echo ""
  echo "Optional modus-specific arguments:"
  echo "  -c <vpnconfig.ovpn>               For VPN mode: sets the VPN config file path"
  echo "  -t <filebeat_tls_certs_dir>       For log-forwarding mode: sets the path to TLS secrets for filebeat (if not set, and logging is enabled, TLS certs are expected to be in the standard secrets directory)"
}

local_chart=false
delete_namespace=false

USAGE_STRING="usage: $0 [-c </path/to/vpnconfig.ovpn>][-p </path/to/chart.tgz>][-t </path/to/filebaet/tls/certs>][-f]  <namespace> </path/to/value/overwrite/file> <path/to/secrets/dir/>"

while getopts 'hfp:c:t:' opt; do
  case "$opt" in
    h)
      help
      exit ;;
    f)
      delete_namespace=true
      ;;
    p)
      local_chart=true
	    chartname=$OPTARG
      ;;
    c)
      vpn_config_file=$OPTARG
      if [[ ! -f "$vpn_config_file" ]]; then
		    die "$vpn_config_file vpn config file does not exist"
      fi
      ;;
    t)
      filebeat_tls_certs_dir=$OPTARG
      if [[ ! -d "$filebeat_tls_certs_dir" ]]; then
        die "$filebeat_tls_certs_dir directory does not exist"
      fi
      ;;
    :)
      die "Missing required argument for optional flag."
      ;;
    ?)
      die "$USAGE_STRING"
      ;;
  esac
done

shift "$((OPTIND-1))"

# Because there are optional arguments, use OPTIND for indexing required commands (see getopts documentation)
if [ $# -lt 3 ]; then
  echo "Please provide all three required arguments"
  die "$USAGE_STRING"
fi

if [[ -z $KUBECONFIG ]]; then
  die "Environment varialbe KUBECONFIG is unset, please set it to point to the correct config file before running this script."
fi

namespace=$1

if $delete_namespace; then
  # Add || true to not fail if namespace does not exist  
  kubectl delete namespace "$namespace" || true
fi

if ! $local_chart ; then
	# Exctract repo name pointing to https://helm.rosemancloud.com and append /vdl to get the chart name
	chartname="$(helm repo list | sed -rne 's/[ \t]+https:\/\/helm\.rosemancloud\.com.*/\/vdl/p')"
fi

if [[ -z "$chartname" ]]; then
  echo "No helm repository found for https://helm.rosemancloud.com"
  die "Please add it before running this script, execute: helm repo add REPONAME https://helm.rosemancloud.com"
fi

overwritefile=$2
if [[ ! -f "$overwritefile" ]]; then
	die "$overwritefile overwrite file does not exists"
elif ! (echo "$overwritefile" | grep -Eq '.*\.ya?ml') ; then
	die "$overwritefile is not a .yml or .yaml file"
fi

secrets_dir=$3
if [[ ! -d "$secrets_dir" ]]; then
	die "$secrets_dir directory does not exists"
fi

node=$(grep -oP '(?<=nodeNr: \").' "$overwritefile")
if [[ ! ("$node" == "0" || "$node" == "1" || "$node" == "2") ]]; then
	die "nodeNr: $node in $overwritefile is not a valid node numer, should be either 0, 1, or 2"
fi

# || true is needed, otherwise -e causes an error if 0 is returned by expr()
peer_a=$(( $(( "$node" + 2 )) % 3 ))
peer_b=$(( $(( "$node" + 1 )) % 3 ))

# Save base64 encodings as files for all keys, to be used with --set-file option for setting Helm values 
ts=$(date -I)
tmpdir="/tmp/helm_secrets_$ts"
mkdir -p "$tmpdir"
base64 -w0 < "$secrets_dir/selfsignedca.crt" > "$tmpdir/selfsignedca.crt.b64"
base64 -w0 < "$secrets_dir/license.key" > "$tmpdir/license.key.b64"
base64 -w0 < "$secrets_dir/httpd$node.crt" > "$tmpdir/httpd$node.crt.b64"
base64 -w0 < "$secrets_dir/httpd$node.key" > "$tmpdir/httpd$node.key.b64"
base64 -w0 < "$secrets_dir/server$peer_a.crt" > "$tmpdir/server$peer_a.crt.b64"
base64 -w0 < "$secrets_dir/server$peer_b.crt" > "$tmpdir/server$peer_b.crt.b64"
base64 -w0 < "$secrets_dir/server$node.crt" > "$tmpdir/server$node.crt.b64"
base64 -w0 < "$secrets_dir/server$node.key" > "$tmpdir/server$node.key.b64"
base64 -w0 < "$secrets_dir/server$node.sk.b64" > "$tmpdir/server$node.sk.b64.b64"

# Construct install command (add necesairy key material into helm values)
install_params=("$chartname" --create-namespace --namespace "$namespace" --values "$overwritefile" )
install_params+=( --set-file "secrets.selfsignedcaCrt=$tmpdir/selfsignedca.crt.b64" )
install_params+=( --set-file "secrets.licenseKey=$tmpdir/license.key.b64" )
install_params+=( --set-file "secrets.httpd${node}Crt=$tmpdir/httpd$node.crt.b64" )
install_params+=( --set-file "secrets.httpd${node}Key=$tmpdir/httpd$node.key.b64" )
install_params+=( --set-file "secrets.server${peer_a}Crt=$tmpdir/server$peer_a.crt.b64" )
install_params+=( --set-file "secrets.server${peer_b}Crt=$tmpdir/server$peer_b.crt.b64" )
install_params+=( --set-file "secrets.server${node}Crt=$tmpdir/server$node.crt.b64" )
install_params+=( --set-file "secrets.server${node}Key=$tmpdir/server$node.key.b64" )
install_params+=( --set-file "secrets.server${node}SkB64=$tmpdir/server$node.sk.b64.b64" )

# || true is needed, otherwise -e causes an error if 0 is returned by grep
num_approvers=$(grep -oP '(?<=scriptSignMode: \").' "$overwritefile") || true
if [[ $num_approvers -gt 0 ]]; then
	base64 -w0 < "$secrets_dir/sign0.pk.b64" > "$tmpdir/sign0.pk.b64.b64"
	base64 -w0 < "$secrets_dir/sign1.pk.b64" > "$tmpdir/sign1.pk.b64.b64"

	install_params+=( --set-file "secrets.sign0PkB64=$tmpdir/sign0.pk.b64.b64" )
	install_params+=( --set-file "secrets.sign1PkB64=$tmpdir/sign1.pk.b64.b64" )
fi

# set +e because grep exits with an error if vpnEnabled: false (which is what we test here for)
set +e
grep -qP '(?<=vpnEnabled: )true' "$overwritefile"
# Store exit status in vpn_enabled
vpn_enabled=$?
set -e

# test to see if exit status of $vpn_enabled is 0
if [[ "$vpn_enabled" -eq "0" ]]; then
	base64 -w0 < "$vpn_config_file" > "$tmpdir/vpnconf.ovpn.b64"
	install_params+=( --set-file "vpnConfigFile=$tmpdir/vpnconf.ovpn.b64" )
fi

# set +e because grep exits with an error if loggingEnabled: false (which is what we test here for)
set +e
grep -qP '(?<=loggingEnabled: )true' "$overwritefile"
# Store exit status in vpn_enabled
send_logs_enabled=$?
set -e

# test to see if exit status of $vpn_enabled is 0
if [[ "$send_logs_enabled" -eq "0" ]]; then
  if [[ -z "$filebeat_tls_certs_dir" ]]; then
    filebeat_tls_certs_dir="$secrets_dir"
    echo "No option -t </path/to/filebeat/tls/certs/> was provided, we assume tls certs are present in the default secrets directory"
	fi
  base64 -w0 < "$filebeat_tls_certs_dir"/filebeat-client.key > "$tmpdir/filebeat-client.key.b64"
  base64 -w0 < "$filebeat_tls_certs_dir"/filebeat-client.crt > "$tmpdir/filebeat-client.crt.b64"
  base64 -w0 < "$filebeat_tls_certs_dir"/logging-ca.crt > "$tmpdir/logging-ca.crt.b64"

	install_params+=( --set-file "filebeatKey=$tmpdir/filebeat-client.key.b64" )
  install_params+=( --set-file "filebeatCrt=$tmpdir/filebeat-client.crt.b64" )
  install_params+=( --set-file "loggingCaCrt=$tmpdir/logging-ca.crt.b64" )
fi

set -x
helm upgrade --install vdl "${install_params[@]}"
set +x
#clean up temporary directory with helm secrets
rm -r "$tmpdir"

# TODO check if vdl-n2n needs to be parameterized
if [[ ! "$vpn_enabled" -eq "0"  ]]; then
  echo "Fetching service ip... (this might take a few minutes)"
  until IP=$(kubectl get svc --namespace "$namespace" vdl-n2n --template '{{ range (index .status.loadBalancer.ingress 0) }}{{.}}{{ end }}' 2>/dev/null); do sleep 2s; done
  echo "$IP"
fi
