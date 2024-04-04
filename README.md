# kube.acme.sh

A simple wrapper to adopt [acme.sh](https://acme.sh) to Kubernetes.

Once the configuration is setup, `kube.acme.sh` will create, and periodically update, a secret in each defined namespaces containing the certificate.

While you can setup `kube.acme.sh` anyway you want, it was created to be used with DNS verification, meaning you do not have to expose your ingress controller. 

If exposing the ingress controller is not a problem, [jcmoraisjr/haproxy-ingress](https://github.com/jcmoraisjr/haproxy-ingress) or others, are probably better options, which has a native Let's Encrypt implementation build into the service.

If your DNS provider has support for [cert-manager](https://cert-manager.io/), that is most likely also a better option.

If you are still here, welcome. Let's get started setting it up!

## Installing

First you need to clone this repository and `cd` to it:

```sh
git clone https://github.com/dxlr8r/kube.acme.sh.git
cd kube.acme.sh
cp example.config.jsonnet config.jsonnet
```

Then setup the `config.jsonnet` file, created with `example.config.jsonnet` as a template and reference.

Then provision the chart, to the current kubectl context, using [`tk`](https://tanka.dev/install):

```sh
tk apply chart --tla-str context=$(kubectl config current-context) --tla-code config='import "config.jsonnet"'
```

## Run manually/check if working

Not wanting to wait for the CronJob? Or you want to check if your configuration is right?

```sh
config=$(tk eval chart --tla-code config='import "config.jsonnet"' --tla-code patch='function(c,l,m)c' -e 'data'); export config
name=$(jq -rn '$ENV.config | fromjson | .name')
namespace=$(jq -rn '$ENV.config | fromjson | .namespace')
kubectl create -n $namespace job ${name}-$RANDOM --from=cronjob/$name
kubectl logs -f -n $namespace $(kubectl get -n $namespace pods -o name | head -n1)
```

Verify that the secrets was written to your targeted namespaces:

```sh
kubectl get secrets --all-namespaces -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name | awk -v NAME="$name" 'NR==1 || $2==NAME' | column -t
```

Cleanup with:

```sh
kubectl delete -n $namespace $(kubectl get -n $namespace job -o name)
```

## Miscellaneous

### Orphaned secrets

`kube.acme.sh` will not clean-up/delete orphaned certificate secrets.
