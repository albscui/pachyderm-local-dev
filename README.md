# Local Pachyderm Dev Environment

At a high level, the steps to develop Pachyderm locally are the following:

0. Checkout Pachyderm's repo at github.com/pachyderm/pachyderm
1. Compile Pachyderm binaries and build Docker images
2. Spin up a K8s cluster for local development
3. Load your locally built docker images to the K8s cluster
4. Use helm to deploy Pachyderm with local config values

This repo has some scripts to accomplish these steps more easily.

Requirements:

- install `docker`, `kubectl`, `kind`, and `helm` 
- this repo is opinionated by turning on Pachyderm Enterprise by default, because I need to test enterprise features
  - generate a Pachyderm enterprise license key via `https://enterprise-token-gen.pachyderm.io/dev`
  - by setting `pachd.enterpriseLicenseKey` you activate enterprise automatically
- if you don't have enterprise key then you can't test enterprise features, and should:
  - disable auth by setting `pachd.activateAuth: false` in `values.yaml`
  - remove `pachd.rootToken`
  - in `rebuild.sh` remove the `session_token`
- get the IP address of your Linux VM that's hosting Docker

Finally run:
```
cd $PATH_TO_PACHYDERM_REPO
$YOUR_SCRIPT_DIR/setup.sh
```

How to run unit tests

```
go test -v -tags=unit_test ./path/to/your/package -run TestName
```

How to run integration tests

```
go test -v -tags=k8s ./path/to/your/package \
    -testenv.host=localhost \
    -clusters.pool=1 \
    -clusters.reuse=true \
    -clusters.data.cleanup=false \
    -run TestName
```
