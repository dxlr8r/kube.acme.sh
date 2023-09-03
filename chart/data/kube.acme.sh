#!/bin/sh
# SPDX-FileCopyrightText: 2023 Simen Strange <https://github.com/dxlr8r/kube.acme.sh>
# SPDX-License-Identifier: MIT

KUBE_API='kubernetes.default.svc:443'
CA_CERT=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
AUTH="Authorization: Bearer $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)"
ACME_INSTALL_DIR='/workdir/.acme.sh'
alias acme.sh="$ACME_INSTALL_DIR/acme.sh --home /acme.sh"

kurl() (
  rel_ref=$(echo $1 | sed 's#^/##')
  shift
  url="https://$KUBE_API/$rel_ref"
  curl -f --no-progress-meter --cacert "$CA_CERT" -H "$AUTH" "$url" "$@"
)
singularise() {
  echo "$1" | sed 's/s$//' | awk '{ print toupper(substr($0, 1, 1)) substr($0, 2); }'
}
pluralise() {
  echo "$1" | sed 's/$/s/' | tr '[:upper:]' '[:lower:]'
}
ensure() (
  pkind=$(pluralise "$kind")
  if kurl "/api/v1/namespaces/$namespace/$pkind" | jq --arg name "$name" '.items[].metadata.name == $name // false' | grep -xq 'true'; then
    method=PUT # UPDATE
    action="/api/v1/namespaces/$namespace/$pkind/$name"
  else
    method=POST # CREATE
    action="/api/v1/namespaces/$namespace/$pkind"
  fi
  resource=$(jq -n "$resource")
  kurl "$action" -X "$method" -H 'Content-Type: application/json' -d "$resource"
)

if ! test -f '/acme.sh/account.conf'; then
  cd $ACME_INSTALL_DIR; acme.sh --nocron --no-profile --email $ACME_EMAIL --install
fi

while IFS= read -r env; do
  export "$env"
done << EOF
$(jq -rjn '$ENV.ACME_ENV | fromjson | to_entries | .[] | .key, "=", .value, "\n"')
EOF

mkdir -p /acme.sh/certs
acme.sh --issue --key-file /acme.sh/certs/key --ca-file /acme.sh/certs/ca --cert-file /acme.sh/certs/crt --fullchain-file /acme.sh/certs/chain $ACME_ARGS

export TLS_CRT=$(base64 -w0 /acme.sh/certs/chain)
export TLS_KEY=$(base64 -w0 /acme.sh/certs/key)

for target in $(jq -jrn '$ENV.TARGETS | fromjson | @tsv'); do
  kind=Secret name=$NAME namespace=$target labels=$POD_LABELS \
  resource='
  {
    "apiVersion": "v1",
    "kind": $ENV.kind,
    "metadata": {
      "name": $ENV.name,
      "namespace": $ENV.namespace,
      "labels": $ENV.labels|fromjson
    },
    "data": {
      "tls.crt": $ENV.TLS_CRT,
      "tls.key": $ENV.TLS_KEY
    }
  }' ensure | sed 's;\(.*"tls\....":\).*;\1 <redacated>;'
done
