# Release Management

# Gaia

# Summary

The Web UI is essential. And will have to write a _lot_ of code for all our repos. Paused for now.

## Setup

Create a dir for the DB. It uses BoltDB.

```shell
 mkdir data
```

`gaia.yml` is the compose file that spins it up. Useful aliases:

``` shell
alias gaia='docker-compose -f ${PWD}/gaia.yml -p gaia'
```

Login with admin/admin at localhost:8080

# Concourse

# Summary

Concourse is a struggle to work with. Worked with it for 60% of a week
with a few long multi-hour sessions.

Cons:
- idiosyncratic yaml syntax. cf. tasks/build.yaml:inputs.
- docs are ok, many errors, dated to circa 2018
- errors are cryptic, logs are prolix and useless
- had to read source code to figure out yaml format
- running redis in a sidecar for tests is hard due to [bug open since 2016](https://github.com/concourse/concourse/issues/324)
- absolute paths are impossible to set but [there is hope](https://github.com/concourse/concourse/issues/4281)

Pros:
- cool interactive runs that do not require a push
- control-tower promises a lot
- tasks have well defines inputs and outputs
- can be integrated with vault in [theory](https://spr.com/how-to-automate-data-protection-using-concourse-ci-and-hashicorp-vault/), could not replicate
- _everything_ is in code, functional CLI with completion


## Setup 

Create a volume for the DB. It uses Postgres.

```shell
 docker volume create concourse-db
```

`cci.yml` is the compose file that spins it up. Useful aliases:

``` shell
alias cci='docker-compose -f cci.yml -f vault.override.yml -p cci'
alias gw='fly -t gateway'
```

Get the CLI binary from the webui at localhost:8080. Setup completion with `fly completion --shell zsh`.

Run jobs asynchronously as:

``` shell
p=packages.yaml j=build
gw sp -c ${p}.yml -p $p -n && \
    gw tj -j ${p}/${j} && \
    gw watch -j ${p}/${j}
```

Run jobs synchronously and pass secrets from a local file:

``` shell
gw execute -c cci/tasks/build.yml -l cci/gw-creds.yml

```

### Sidecar for tests

## Vault

Follow the [guide](https://concourse-ci.org/vault-credential-manager.html) to configure vault into `cci.yml`. This is NOT production-ready.

Install [certstrap](https://github.com/square/certstrap) as

``` shell
go get github.com/square/certstrap
go install github.com/square/certstrap
```

### Unsealing

``` shellsession
$ vault operator init -key-shares 3 -key-threshold 2
Unseal Key 1: 5tAaIlAsG3hqQwAUtJ1i+oNp+syIkqmSpukvs4u/VGP0
Unseal Key 2: HBxdaTzbwFtxKUgeDKaCY2pP9quHSW2ELwKXnPn9N1gF
Unseal Key 3: S7CfjB5uFTZCftYYUE9Q9YuuopzuNRowh1O9WVJxvXGe
Unseal Key 4: ce03ZTGj2Ds2zFEy4vXDCX3ciFW5wrokv9ewf0Khjk1f
Unseal Key 5: QipLWuh9pdt81a/2Yz+eSqQdQYHVSI3Vj4k9n5W1+TyX

Initial Root Token: s.P02VfGnzgd7ubEVDe7LuG78y

vault operator unseal 5tAaIlAsG3hqQwAUtJ1i+oNp+syIkqmSpukvs4u/VGP0
vault operator unseal HBxdaTzbwFtxKUgeDKaCY2pP9quHSW2ELwKXnPn9N1gF
vault operator unseal S7CfjB5uFTZCftYYUE9Q9YuuopzuNRowh1O9WVJxvXGe
vault login s.P02VfGnzgd7ubEVDe7LuG78y
export VAULT_CACERT=~gw/cci/vault/certs/vault-ca.crt
vault auth enable cert
vault write auth/cert/certs/concourse policies=concourse certificate=@vault/certs/vault-ca.crt ttl=1h
vault secrets enable -version=1 -path=concourse kv
```

### Adding secrets

`concourse-policy.hcl` shown in the guide above is out of date. The format compatible with v1.3.2 is checked in at `vault/policy/concourse.hcl`. The commands to use it are fine.

Enable the secrets engine at the appropriate path and add secrets. All secrets for a part need to specified on the same command line. Concourse looks for keys in the path `concourse/<team name>`. Team name is `main`.

``` shellsession
$ vault secrets enable -version=1 -path=concourse kv
Success! Enabled the kv secrets engine at: concourse/
$ vault kv put concourse/main gpg_passphrase='redacted' gpg_priv_key='redacted'
Success! Data written to: concourse/signing
```

## Repositories

`tyk.conf` is a [myrepos](https://myrepos.branchable.com/)
configuration file. Install it with homebrew or your distro.

A useful alias:
``` shell
alias trel="mr --jobs=5 --config=${PWD}/tyk.conf" # parallelism of 5
```

### To update all repos

``` shell
$ trel up

```
Might take a while on the first run.

### Adding a new repo

``` shell
trel register <dir>
```

