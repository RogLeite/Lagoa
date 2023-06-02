rm -f /.cockroach-certs/*.key /.cockroach-certs/*.crt &&
cockroach cert create-ca --certs-dir=/.cockroach-certs --ca-key=/.cockroach-certs/ca.key &&
cockroach cert create-node localhost $(hostname) --certs-dir=/.cockroach-certs --ca-key=/.cockroach-certs/ca.key &&
cockroach cert create-client root --certs-dir=/.cockroach-certs --ca-key=/.cockroach-certs/ca.key