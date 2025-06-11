# # Convert GithubApp Yaml to JSON
# yq -o=json eval '.' private/backstage-github-app.yaml > private/backstage-github-app.json
# # Print private key in online
# yq eval '.privateKey' private/argocd-github-app.yaml | tr -d '\n'