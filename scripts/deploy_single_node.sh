#!/bin/bash

set -e

die(){
  echo ERROR: "$@"
  exit 1
}

help() {
  # Display help message
  echo "deploy_single_node.sh is designed to simplify deployment of a single VDL node"
  echo 
  echo "$USAGE_STRING"
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

USAGE_STRING="usage: $0 [-h][-c <vpnconfig.ovpn>][-t <filebeat_tls_certs_dir>][-p <chart.tgz>][-f] <namespace> <override_file> <secrets_dir>"

while getopts 'hfp:c:l:g:t:' opt; do
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
    l)
      loki_vpn_config_file=$OPTARG
      if [[ ! -f "$loki_vpn_config_file" ]]; then
		    die "$loki_vpn_config_file vpn config file does not exist"
      fi
      ;;
    g)
      grafana_vpn_config_file=$OPTARG
      if [[ ! -f "$grafana_vpn_config_file" ]]; then
		    die "$grafana_vpn_config_file vpn config file does not exist"
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

if [[ -z "$KUBECONFIG" ]]; then
  die "Environment variable KUBECONFIG is unset, please set it to point to the correct config file before running this script."
fi

namespace=$1
if $delete_namespace; then
  ! kubectl delete namespace "$namespace"
fi

if ! $local_chart; then
	# Exctract repo name pointing to https://helm.rosemancloud.com and append /vdl to get the chart name
	chartname="$(helm repo list | sed -rne 's/[ \t]+https:\/\/helm\.rosemancloud\.com.*/\/vdl/p')"
fi

if [[ -z "$chartname" ]]; then
  echo "No helm repository found for https://helm.rosemancloud.com"
  die "Please add it before running this script, execute: helm repo add REPONAME https://helm.rosemancloud.com"
fi

override_file=$2
if [[ ! -f "$override_file" ]]; then
	die "$override_file overwrite file does not exists"
elif ! (echo "$override_file" | grep -Eq '.*\.ya?ml') ; then
	die "$override_file is not a .yml or .yaml file"
fi

secrets_dir=$3
if [[ ! -d "$secrets_dir" ]]; then
	die "$secrets_dir directory does not exists"
fi

node_nr=$(grep -oP '(?<=nodeNr: \").' "$override_file")
if [[ ! ("${node_nr}" == "0" || "${node_nr}" == "1" || "${node_nr}" == "2") ]]; then
	die "nodeNr: ${node_nr} in $override_file is not a valid node numer, should be either 0, 1, or 2"
fi

peer_a=$(((node_nr + 2) % 3))
peer_b=$(((node_nr + 1) % 3))

# Save base64 encodings as files for all keys, to be used with --set-file option for setting Helm values 
tmpdir=$(mktemp -d)
base64 -w0 < "$secrets_dir/selfsignedca.crt" > "$tmpdir/selfsignedca.crt.b64"
base64 -w0 < "$secrets_dir/license.key" > "$tmpdir/license.key.b64"
base64 -w0 < "$secrets_dir/httpd${node_nr}.crt" > "$tmpdir/httpd${node_nr}.crt.b64"
base64 -w0 < "$secrets_dir/httpd${node_nr}.key" > "$tmpdir/httpd${node_nr}.key.b64"
base64 -w0 < "$secrets_dir/server${peer_a}.crt" > "$tmpdir/server${peer_a}.crt.b64"
base64 -w0 < "$secrets_dir/server${peer_b}.crt" > "$tmpdir/server${peer_b}.crt.b64"
base64 -w0 < "$secrets_dir/server${node_nr}.crt" > "$tmpdir/server${node_nr}.crt.b64"
base64 -w0 < "$secrets_dir/server${node_nr}.key" > "$tmpdir/server${node_nr}.key.b64"
base64 -w0 < "$secrets_dir/server${node_nr}.sk.b64" > "$tmpdir/server${node_nr}.sk.b64.b64"

# Construct install command (add necessary key material into helm values)
install_params=("$chartname" --create-namespace --namespace "$namespace" --values "$override_file" )
install_params+=( --set-file "secrets.selfsignedcaCrt=$tmpdir/selfsignedca.crt.b64" )
install_params+=( --set-file "secrets.licenseKey=$tmpdir/license.key.b64" )
install_params+=( --set-file "secrets.httpd${node_nr}Crt=$tmpdir/httpd${node_nr}.crt.b64" )
install_params+=( --set-file "secrets.httpd${node_nr}Key=$tmpdir/httpd${node_nr}.key.b64" )
install_params+=( --set-file "secrets.server${peer_a}Crt=$tmpdir/server${peer_a}.crt.b64" )
install_params+=( --set-file "secrets.server${peer_b}Crt=$tmpdir/server${peer_b}.crt.b64" )
install_params+=( --set-file "secrets.server${node_nr}Crt=$tmpdir/server${node_nr}.crt.b64" )
install_params+=( --set-file "secrets.server${node_nr}Key=$tmpdir/server${node_nr}.key.b64" )
install_params+=( --set-file "secrets.server${node_nr}SkB64=$tmpdir/server${node_nr}.sk.b64.b64" )

if grep -Eq 'dynamicConfigMode: *"(1|true)"' "$override_file"; then
	base64 -w0 < "$secrets_dir/web_app.pk" > "$tmpdir/web_app.pk.b64"

	install_params+=( --set-file "secrets.webAppPk=$tmpdir/web_app.pk.b64" )
fi

# Legacy script signing approach (deprecated)
! num_approvers=$(grep -oP '(?<=scriptSignMode: \").' "$override_file")
if [[ $num_approvers -gt 0 ]]; then
	base64 -w0 < "$secrets_dir/sign0.pk.b64" > "$tmpdir/sign0.pk.b64.b64"
	base64 -w0 < "$secrets_dir/sign1.pk.b64" > "$tmpdir/sign1.pk.b64.b64"

	install_params+=( --set-file "secrets.sign0PkB64=$tmpdir/sign0.pk.b64.b64" )
	install_params+=( --set-file "secrets.sign1PkB64=$tmpdir/sign1.pk.b64.b64" )
fi

grep -qP '(?<=vpnEnabled: )true' "$override_file" && vpn_enabled=1 || vpn_enabled=0
grep -qP '(?<=loggingEnabled: )true' "$override_file" && send_logs_enabled=1 || send_logs_enabled=0

if [[ "$vpn_enabled" -eq 1 ]]; then
  if ! [ -r "$vpn_config_file" ]; then
    die "VPN enabled but vpn_config_file(='$vpn_config_file') not defined/found"
  fi
	base64 -w0 < "$vpn_config_file" > "$tmpdir/vpnconf.ovpn.b64"
	install_params+=( --set-file "vpnConfigFile=$tmpdir/vpnconf.ovpn.b64" )
fi

if [[ "$send_logs_enabled" -eq 1 ]]; then
  if [[ "$vpn_enabled" -eq 0 ]]; then
    die "Logging is enabled but VPN is disabled. VPN is a requirement for logging to work."
  fi
  if ! [ -r "$loki_vpn_config_file" ]; then
    die "Logging enabled but loki_vpn_config_file(='$loki_vpn_config_file') not defined/found"
  fi
  if ! [ -r "$grafana_vpn_config_file" ]; then
    die "Logging enabled but grafana_vpn_config_file(='$grafana_vpn_config_file') not defined/found"
  fi

	base64 -w0 < "$loki_vpn_config_file" > "$tmpdir/loki_vpnconf.ovpn.b64"
	install_params+=( --set-file "lokiVpnConfigFile=$tmpdir/loki_vpnconf.ovpn.b64" )
	base64 -w0 < "$grafana_vpn_config_file" > "$tmpdir/grafana_vpnconf.ovpn.b64"
	install_params+=( --set-file "grafanaVpnConfigFile=$tmpdir/grafana_vpnconf.ovpn.b64" )
fi

set -x
helm repo update
#helm template vdl "${install_params[@]}"
helm upgrade --install vdl "${install_params[@]}"
{ set +x; } 2>&-
rm -rf "$tmpdir"

if [[ "$vpn_enabled" -eq 0 ]]; then
  echo "Fetching n2n service ip... (this might take a few minutes)"
  until IP=$(kubectl get svc --namespace "$namespace" vdl-n2n --template '{{ range (index .status.loadBalancer.ingress 0) }}{{.}}{{ end }}' 2>/dev/null); do sleep 2s; done
  echo "$IP"
fi
