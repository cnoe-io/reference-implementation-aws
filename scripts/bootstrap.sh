# # Convert GithubApp Yaml to JSON
# yq -o=json eval '.' private/backstage-github-app.yaml > private/backstage-github-app.json