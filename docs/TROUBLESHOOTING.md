
# Troubleshooting steps

All applications are deployed as ArgoCD application. The best way is to navigate to ArgoCD UI and look at logs for each application.

```bash
# Get the admin ArgoCD password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
# Port forward to 8081. 8080 could be in-use by the install / uninstall scripts.
kubectl port-forward svc/argocd-server -n argocd 8081:80

Go to http://localhost:8081
```


# Common issues

## Argo Workflows

### Argo Workflows controller stuck in Crash Loop. 

You may see error message like:

```
Error: Get "https://<DOMAIN>/realms/cnoe/.well-known/openid-configuration": dial tcp: lookup <DOMAIN> on 10.100.0.10:53: no such host
```

This is due to DNS propagation delay in the cluster. Once DNS entries are propagated (may take ~10 min), pods should start running.

## Backstage

### Backstage pod stuck in crash loop

You may see error message like:

```
Error: getaddrinfo ENOTFOUND keycloak.a2.mccloman.people.aws.dev
    at GetAddrInfoReqWrap.onlookup [as oncomplete] (node:dns:107:26) {
  errno: -3008,
  code: 'ENOTFOUND',
  syscall: 'getaddrinfo',
  hostname: 'keycloak.<DOMAIN>'

}
```
This is due to DNS propagation delay in the cluster. Once DNS entries are propagated (may take ~10 min), pods should start running.


## Certificates

General steps are [outlined here](https://cert-manager.io/docs/troubleshooting/). 

### Certificates not issued
You may see something like this

```bash
$ kubectl -n argo get certificate 
NAME                      READY   SECRET                    AGE
argo-workflows-prod-tls   FALSE    argo-workflows-prod-tls   3m52s

$ kubectl -n argo get challenge
NAME                                                  STATE     DOMAIN                            AGE
argo-workflows-prod-tls-qxfjq-1305584735-1533108683   pending   argo.<DOMAIN>   91s
```

If you describe the challenge, you may see something like this.

```
Reason:      Waiting for HTTP-01 challenge propagation: failed to perform self check GET request 'http://argo.DOMAIN_NAME/.well-known/acme-challenge/6AQ5cRc7J6FNQ9xGOBDI5_G1lHsNM5J5ivbS3iSHd3c': Get "http://argo.DOMAIN_NAME/.well-known/acme-challenge/6AQ5cRc7J6FNQ9xGOBDI5_G1lHsNM5J5ivbS3iSHd3c": dial tcp: lookup argo.DOMAIN_NAME on 10.100.0.10:53: no such host
```
This is due to DNS propagation delay in the cluster. Once DNS entries are propagated (may take ~10 min), certs should be issued.

