# kube.acme.sh

A simple wrapper to adopt [acme.sh](https://acme.sh) to Kubernetes.

Once the configuration is setup, `kube.acme.sh` will create, and periodically update, a secret in each defined namespaces containing the certificate.

While you can setup `kube.acme.sh` anyway you want, it was created to be used with DNS verification, meaning you do not have to expose your ingress controller. 

If exposing the ingress controller is not a problem, [jcmoraisjr/haproxy-ingress](https://github.com/jcmoraisjr/haproxy-ingress) or others, are probably better options.

If your DNS provider has support for [cert-manager]<https://cert-manager.io/>, that is most likely also a better option.

If you are still here, welcome. Let's get started setting it up!

## Installing

First you need to install [tanka]<https://tanka.dev/install>, for this project `Jsonnet Bundler` is not used.


```sh
mkdir kube.acme.sh
cd kube.acme.sh
git clone https://github.com/dxlr8r/kube.acme.git chart
cp example.config.jsonnet config.jsonnet
```

Then setup the config file, using `example.config.jsonnet` as a template and reference.

Then provision the chart to your current kubectl context using `tk` (tanka):

```sh
tk apply chart --tla-str context=$(kubectl config current-context) --tla-code config="$(cat config.jsonnet)"
```

kubectl delete -n acme-sh $(kubectl get -n acme-sh job -o name)
kubectl create -n acme-sh job acme-sh-run --from=cronjob/acme-sh
kubectl logs -n acme-sh $(kubectl get -n acme-sh pods -o name | head -n1)
