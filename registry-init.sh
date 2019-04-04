#!/bin/bash
# Setup a Docker private registry with TLS communication encryption
# and Basic Authentication.
#
# Pre-requisites:
# - Host OS: Ubuntu 18.04 LTS.
# - Environment Variables:
#     REGISTRY_ADMIN_EMAIL     - required by Lets Encrypt
#     REGISTRY_ADMIN_PASSWORD  - for authenticating as the 'admin' user with the registry
#     REGISTRY_FQDN            - the fully qualified domain name to obtain a TLS certificate for
#
# Optional:
# - Environment Variables: 
#     REGISTRY_S3_CHECK_HEALTH - MUST be "false" if using Digital Ocean spaces
#     REGISTRY_S3_ENCRYPT      - MUST be "false" if using Digital Ocean spaces
#     REGISTRY_S3_ACCESSKEY    - 
#     REGISTRY_S3_SECRETKEY    - 
#     REGISTRY_S3_BUCKET       - e.g. "my-bucket"
#     REGISTRY_S3_REGION       - e.g. "aws3"
#     REGISTRY_S3_ENDPOINT     - e.g. "https://ams3.digitaloceanspaces.com"
#     REGISTRY_HTTP_SECRET     - for load balanced setups - see: https://docs.docker.com/registry/#load-balancing-considerations
#
# After installation the registry will be usable like so:
#	 - (browser) https://${REGISTRY_FQDN}/v2/_catalog
#	 - (cli)		 docker login ${REGISTRY_FQDN}
#	 - (cli)		 docker pull <repo>/<image>:<tag>
#	 - (cli)		 docker tag <repo>/<image>:<tag> ${REGISTRY_FQDN}/<repo>/<image>:<tag> && \
#							 docker push ${REGISTRY_FQDN}/<repo>/<image>:<tag>
#
# With the following credentials:
#		Username: admin
#		Password: the REGISTRY_ADMIN_PASSWORD given to this script.
#
# Security:
# For CertBot to renew the certificate every 90 days it will 
set -o errexit

abort_missing_var() {
		VARNAME="$1"
		echo >&2 "ERROR: Variable '$VARNAME' must be set. Aborting."
		exit 1
}

[ -z "${REGISTRY_ADMIN_EMAIL}" ] && abort_missing_var REGISTRY_ADMIN_EMAIL
[ -z "${REGISTRY_ADMIN_PASSWORD}" ] && abort_missing_var REGISTRY_ADMIN_PASSWORD
[ -z "${REGISTRY_FQDN}" ] && abort_missing_var REGISTRY_FQDN

set -o nounset

# See: https://github.com/docker/distribution/issues/2695 "Registry 2.6.2 with s3 backend panic: runtime error: invalid
# memory address or nil pointer dereference" - I encountered the same issue when using Digital Ocean spaces as the S3
# backend with the "latest" 2.x version of the registry available at the time. Downgrading to v2.5.2 solves the problem.
DOCKER_REGISTRY_VERSION=2.5.2
ETC_REGISTRY=/etc/registry
DOCKER_RUN_ENV_VARS_PATH=$ETC_REGISTRY/docker.env
REGISTRY_AUTH_PATH=$ETC_REGISTRY/auth
CERTBOT_ETC=/etc/letsencrypt
CERTBOT_CERTS_PATH=$CERTBOT_ETC/live/${REGISTRY_FQDN}
CERTBOT_PRE_HOOK=$CERTBOT_ETC/renewal-hooks/pre/stop-registry-and-allow-http
CERTBOT_POST_HOOK=$CERTBOT_ETC/renewal-hooks/post/start-registry-and-disallow-http

# Install and configure the Let's Encrypt CertBot to automatically issue a 90-day
# TLS certificate.
apt-get update
apt-get remove -y --purge man-db
apt-get install --no-install-recommends -y software-properties-common
add-apt-repository -y universe
add-apt-repository -y ppa:certbot/certbot
apt-get update
apt-get install --no-install-recommends -y certbot

# Temporarily allow Lets Encrypt servers to contact CertBot on port 80
ufw allow http

# Ask CertBot to obtain a TLS certificate for our domain by answering a HTTP challenge issued by the LetsEncrypt
# servers using so-called "standalone" mode (because CertBot will run a temporary standalone web server).
certbot certonly \
	--non-interactive \
	--standalone \
	--domain ${REGISTRY_FQDN} \
	--agree-tos \
	--email "${REGISTRY_ADMIN_EMAIL}" \
	--keep-until-expiring

# Remove the temporary firewall that granted CertBot access on port 80
ufw delete allow http

# Configure CertBot to restart the Docker registry container around certificate renewal so that the new certificate
# will be used and so that CertBot can bind to port 443 temporarily to prove ownership of the domain in order to renew
# the certificate.
echo 'docker stop registry && ufw allow http' > $CERTBOT_PRE_HOOK && chmod +x $CERTBOT_PRE_HOOK
echo 'docker start registry && ufw delete allow http' > $CERTBOT_POST_HOOK && chmod +x $CERTBOT_POST_HOOK

# Download the Docker private registry image from the master Docker registry
docker pull registry

# Use the htpasswd command of the registry Docker image to prepare the admin user credentials in the auth file that will
# be used by the Docker private registry. You can also run a command like this later from the host VM to create more
# users.
mkdir -p $REGISTRY_AUTH_PATH
docker run --entrypoint htpasswd registry:2 -Bbn admin "${REGISTRY_ADMIN_PASSWORD}" > $REGISTRY_AUTH_PATH/htpasswd

# Allow registry clients to contact the private registry on port 443
ufw allow https

# Create a file containing environment variable definitions that when passed to the Docker private registry image will
# override its' defaults. By using a file instead of --env arguments to docker run we can optionally configure S3-like
# remote storage backend if wanted by the caller.
cat <<-EOF > $DOCKER_RUN_ENV_VARS_PATH
	REGISTRY_AUTH=htpasswd
	REGISTRY_AUTH_HTPASSWD_REALM=Registry Realm
	REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd
	REGISTRY_HTTP_TLS_CERTIFICATE=$CERTBOT_CERTS_PATH/fullchain.pem
	REGISTRY_HTTP_TLS_KEY=$CERTBOT_CERTS_PATH/privkey.pem
EOF

if [ ! -z "${REGISTRY_S3_ENDPOINT}" ]; then
	cat <<-EOF >> $DOCKER_RUN_ENV_VARS_PATH
		REGISTRY_STORAGE_DELETE_ENABLED=true
		REGISTRY_STORAGE=s3
		REGISTRY_STORAGE_S3_ENCRYPT=${REGISTRY_S3_ENCRYPT}
		REGISTRY_STORAGE_S3_ACCESSKEY="${REGISTRY_S3_ACCESSKEY}"
		REGISTRY_STORAGE_S3_SECRETKEY="${REGISTRY_S3_SECRETKEY}"
		REGISTRY_STORAGE_S3_BUCKET="${REGISTRY_S3_BUCKET}"
		REGISTRY_STORAGE_S3_REGION="${REGISTRY_S3_REGION}"
		REGISTRY_STORAGE_S3_REGIONENDPOINT="${REGISTRY_S3_ENDPOINT}"
		REGISTRY_HEALTH_STORAGEDRIVER_ENABLED=${REGISTRY_S3_CHECK_HEALTH}
EOF
fi

if [ ! -z "${REGISTRY_HTTP_SECRET}" ]; then
	cat <<-EOF >> $DOCKER_RUN_ENV_VARS_PATH
		REGISTRY_HTTP_SECRET=${REGISTRY_HTTP_SECRET}
EOF
fi

# Launch our Docker private registry, listening on host port 443 for TLS encrypted and # Basic Authentication
# authenticated connections.
# Note: We do not use the Docker private registry built-in Lets Encrypt support because it no longer works since issue
# 2545 whereby Lets Encrypt disabled support for SNI based proof-of-domain-ownership, the only proof mechanism supported
# by the registry image. Instead we rely on the Lets Encrypt certbot to obtain the certificate and we use the obtained
# files here. Alternative solutions are to use NGINX+CertBot or Caddy (includes CertBot built-in) as a proxy in front of
# the Docker registry but that adds complexity when diagnosing issues.
# See: https://www.digitalocean.com/community/tutorials/how-to-set-up-a-private-docker-registry-on-ubuntu-18-04
# See: https://github.com/docker/distribution/issues/2545
# See: https://docs.docker.com/registry/configuration/#override-specific-configuration-options
docker run -d \
	--name registry \
	--restart=always \
	--publish 443:5000 \
	--volume $REGISTRY_AUTH_PATH:/auth \
	--volume $CERTBOT_ETC:$CERTBOT_ETC \
	--env-file $DOCKER_RUN_ENV_VARS_PATH \
	registry:$DOCKER_REGISTRY_VERSION
