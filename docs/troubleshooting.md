
# Troubleshooting
The installation process would take 30-35 minutes depending upon path_routing configuration. If the installation is not complete within this time, cancel the `install.sh` script execution and follow instruction in this document to troubleshoot the issues.]

## Investigating Failures
All adoons are deployed as ArgoCD application in a two-step process. 
+ Bootstraping the EKS cluster with Argo CD and External Secret Operator using idpbuilder
+ Creating rest of the addons through Argo CD on EKS cluster.

Therefore, the best way to investigate and issue is to navigate to respective ArgoCD UI and review any errors in Argo CD application or in logs of the specific addon.

First, switch context to `kind-localdev` cluster (idpbuilder) or EKS cluster and run following command to retrieve passwordof Argo CD.

```bash
kubectl get secrets -n argocd argocd-initial-admin-secret -oyaml | yq '.data.password' | base64 -d

# OR

idpbuilder get secrets -p argocd -o yaml
``` 

**To Access **`idpbuilder`** Argo CD:**

In a web browser, Visit `https://cnoe.localtest.me:8443/argocd`.

**To Access **`EKS Cluster`** Argo CD:**
Verify if the Argo CD, Ingress NGINX and Cert-Manager addons on EKS cluster are healthy.

```
kubectl get applications -n argocd
```

If these addons are healthy then the EKS cluster Argo CD can be accessed directly in web browser using URL `https://argocd.[domain_name]` or `https://[domain_name]/argocd`

Otherwise, start a kubernetes port forward session for Argo CD:

```
kubectl port-forward -n argocd svc/argocd-server 8080:80
```
After this, visit `https://localhost:8080` or `https://localhost:8080/argocd` in a web browser.


## Common issues

### DNS Records not updated after reinstallation
External DNS does not delete DNS records during uninstallation. After reinstallation, External DNS might not be able to update the records with new values. in such cases, delete A, AAAA and TXT records from the Route 53 Hosted Zone and restart the external DNS pods. This will trigger a creation of new records. 

### Certificate not issued by Cert Manager
+ Describe the pending certificate challenge. If it shows message similar to:

```
Reason:      Waiting for HTTP-01 challenge propagation: failed to perform self check GET request 'http://DOMAIN_NAME/.well-known/acme-challenge/6AQ5cRc7J6FNQ9xGOBDI5_G1lHsNM5J5ivbS3iSHd3c': Get "http://DOMAIN_NAME/.well-known/acme-challenge/6AQ5cRc7J6FNQ9xGOBDI5_G1lHsNM5J5ivbS3iSHd3c": dial tcp: lookup argo.DOMAIN_NAME on 10.100.0.10:53: no such host
```
This is due to DNS propagation delay in the cluster. Once DNS entries are propagated (may take ~10 min), certificate should be issued.

+ The reference implentation uses Lets Encrypt production API for requesting certificates. This API has certain limits on number of certificates issued. Due to these rate limits certificates may not be issued. Refer to [Lets Encrypt documentation](https://letsencrypt.org/docs/rate-limits/) for more information about this API throttling.
