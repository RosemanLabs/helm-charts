#!/bin/bash

set -e

die(){
  echo "$@"
  exit 1
}

helmx (){
	r=0
	set -x
	$@ || r=1
	{ set +x; } 2>&-
	return $r
}

local_chart=false
delete_namespace=false

while getopts 'fp:c:' opt; do
  case "$opt" in
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
    :)
      die "Missing required argument for optional flag."
      ;;
    ?)
      die "usage: $0 [-c </path/to/vpnconfig.ovpn>][-p </path/to/chart.tgz>][-f]  <namespace> </path/to/value/overwrite/file> <path/to/secrets/dir/>"
      ;;
  esac
done

if [ $(( $# - $OPTIND )) -lt 2 ]; then
 die "usage: $0 [-c </path/to/vpnconfig.ovpn>][-f][-p] <namespace> </path/to/value/overwrite/file> <path/to/secrets/dir/>"
fi

if [[ -z $KUBECONFIG ]]; then
  die "Environment varialbe KUBECONFIG is unset, please set it to point to the correct config file before running this script."
fi

namespace=${@:$OPTIND:1}

if $delete_namespace; then
  ! kubectl delete namespace $namespace
fi

if $local_chart; then
	# Extract chartname from helm package command (extract "/path/to/chart.tgz")
	pushd charts >/dev/null
	chartname=$(helm package ../vdl | grep -o '/.*\.tgz')
	popd >/dev/null

	echo "Chart successfully created at $chartname"
else
	# Test to see if gcs plugin is present (this is needed for connecting to the right helm chart repo)
	if ! $(helm plugin list | grep -q "^gcs"); then
		die "please install the helm gcs plugin first: helm plugin install https://github.com/hayorov/helm-gcs.git --version 0.4.2 "
	fi

	# Exctract repo name pointing to the google cloud bucket
	chartname="$(helm repo list | sed -n -e 's/\tgs:\/\/rosemanlabs-helm-repository.*/\/vdl/p')"
fi

overwritefile=${@:$OPTIND+1:1}
if [[ ! -f "$overwritefile" ]]; then
	die "$overwritefile overwrite file does not exists"
elif !(echo "$overwritefile" | grep -Eq '.*\.ya?ml'); then
	die "$overwritefile is not a .yml or .yaml file"
fi

secrets_dir=${@:$OPTIND+2:1}
if [[ ! -d "$secrets_dir" ]]; then
	die "$secrets_dir directory does not exists"
fi

node=$(grep -oP '(?<=nodeNr: \").' $overwritefile)
if [[ !($node == "0" || $node == "1" || $node == "2") ]]; then
	die "$node is not a valid node numer, either 0, 1, or 2"
fi

# || true is needed, otherwise -e causes an error if 0 is returned by expr()
peer_a=$(expr $(expr $node + 2) % 3) || true
peer_b=$(expr $(expr $node + 1) % 3) || true

# Save base64 encodings as files for all keys, to be used with --set-file option for setting Helm values 
ts=$(date -I)
tmpdir=/tmp/helm_secrets_$ts/
mkdir -p $tmpdir
base64 -w0 < $secrets_dir/selfsignedca.crt > $tmpdir/selfsignedca.crt.b64
base64 -w0 < $secrets_dir/license.key > $tmpdir/license.key.b64
base64 -w0 < $secrets_dir/httpd$node.crt > $tmpdir/httpd$node.crt.b64
base64 -w0 < $secrets_dir/httpd$node.key > $tmpdir/httpd$node.key.b64
base64 -w0 < $secrets_dir/server$peer_a.crt > $tmpdir/server$peer_a.crt.b64
base64 -w0 < $secrets_dir/server$peer_b.crt > $tmpdir/server$peer_b.crt.b64
base64 -w0 < $secrets_dir/server$node.crt > $tmpdir/server$node.crt.b64
base64 -w0 < $secrets_dir/server$node.key > $tmpdir/server$node.key.b64
base64 -w0 < $secrets_dir/server$node.sk.b64 > $tmpdir/server$node.sk.b64.b64

# Construct install command (add necesairy key material into helm values)
install_command=(helm upgrade --install vdl $chartname --create-namespace --namespace $namespace --values $overwritefile )
install_command+=( --set-file secrets.selfsignedcaCrt=$tmpdir/selfsignedca.crt.b64 )
install_command+=( --set-file secrets.licenseKey=$tmpdir/license.key.b64 )
install_command+=( --set-file secrets.httpd${node}Crt=$tmpdir/httpd$node.crt.b64 )
install_command+=( --set-file secrets.httpd${node}Key=$tmpdir/httpd$node.key.b64 )
install_command+=( --set-file secrets.server${peer_a}Crt=$tmpdir/server$peer_a.crt.b64 )
install_command+=( --set-file secrets.server${peer_b}Crt=$tmpdir/server$peer_b.crt.b64 )
install_command+=( --set-file secrets.server${node}Crt=$tmpdir/server$node.crt.b64 )
install_command+=( --set-file secrets.server${node}Key=$tmpdir/server$node.key.b64 )
install_command+=( --set-file secrets.server${node}SkB64=$tmpdir/server$node.sk.b64.b64 )

# || true is needed, otherwise -e causes an error if 0 is returned by grep
num_approvers=$(grep -oP '(?<=scriptSignMode: \").' $overwritefile) || true
if [[ num_approvers > 0 ]]; then
	base64 -w0 < $secrets_dir/sign0.pk.b64 > $tmpdir/sign0.pk.b64.b64
	base64 -w0 < $secrets_dir/sign1.pk.b64 > $tmpdir/sign1.pk.b64.b64

	install_command+=( --set-file secrets.sign0PkB64=$tmpdir/sign0.pk.b64.b64 )
	install_command+=( --set-file secrets.sign1PkB64=$tmpdir/sign1.pk.b64.b64 )
fi

# set +e because grep exits with an error if vpnEnabled: false (which is what we test here for)
set +e
$(grep -qP '(?<=vpnEnabled: )true' $overwritefile)
# Store exit status in vpn_enabled
vpn_enabled=$?
set -e

# test to see if exit status of $vpn_enabled is 0
if [[ $vpn_enabled -eq "0" ]]; then
	base64 -w0 < $vpn_config_file > $tmpdir/vpnconf.ovpn.b64

	install_command+=( --set-file vpnConfigFile=$tmpdir/vpnconf.ovpn.b64 )
fi

# echo ${install_command[@]}
helmx ${install_command[@]}

#clean up temporary directory with helm secrets
rm -r $tmpdir

# TODO check if vdl-n2n needs to be parameterized
echo "Fetching service ip... (this might take a few minutes)"
until IP=$(kubectl get svc --namespace $namespace vdl-n2n --template '{{ range (index .status.loadBalancer.ingress 0) }}{{.}}{{ end }}' 2>/dev/null); do sleep 2s; done
echo $IP
