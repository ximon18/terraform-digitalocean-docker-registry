# Terraform module to deploy a Docker private registry on Digital Ocean
This template enables you to use [Terraform](https://terraform.io/) to deploy a [private v2 Docker registry](https://docs.docker.com/registry/) on a small [Digital Ocean](https://digitalocean.com/) Droplet (1 vCPU, 1 GiB RAM), with a [Lets Encrypt](https://letsencrypt.org/) TLS certificate and optional Digital Ocean Space storage of registry images. You might want to do this if your images contain sensitive information that should not be freely available to all at on [Docker Hub](https://hub.docker.com/) but you want the convenience of a registry over moving Docker images around manually.

## Disclaimers
I have not hardened the registry for production use - use at your own risk!

By using this module you accept the Lets Encrypt [Subscriber Agreement](https://letsencrypt.org/repository/)

This module does NOT encrypt the image storage and thus you are still dependent on the configured Digital Ocean access controls and on Digital Ocean data protection policy.

The rights of law enforcement agencies to access data stored by Digital Ocean may also depend on the region in which you deploy your registry.

I take no responsibility for the security of your data or the choices you make concerning how you store it.

## Requirements
To use this module you will need to:
- Create a Digital Ocean API token (see API -> Tokens/Keys in the Digital Ocean portal) and set it in the `DIGITALOCEAN_TOKEN` environment variable.
- Add a parent domain that you own to Digital Ocean (see Networking -> Domains in the Digital Ocean portal).

Optionally you may also:
- Create an SSH public/private key pair (e.g. use `ssh-keygen`) for shell access to the Droplet on which the registry will run. The demo template defaults to using the file commonly stored in `~/.ssh/id_rsa.pub`.
- Create a Digital Ocean Space for storing registry images (see Spaces in the Digital Ocean portal). If not specified the images will be stored with the registry Docker container on the Digital Ocean Droplet and will be lost if either the Docker container or the Droplet are lost.
- Install [wait-for-it](https://github.com/vishnubob/wait-for-it) in your PATH for demonstration of a post check that waits for the registry to be reachable after finishing deployment. Without this Terraform completes as soon as the Digital Ocean Droplet and DNS record have been created.

## Known issues
1. This template does NOT yet demonstrate a load-balanced setup. if you wish to do so you should set the `registry_http_secret` module input variable. For more information see: https://docs.docker.com/registry/#load-balancing-considerations.

2. At the time of writing the module deploys v2.5.2 of the Docker Registry as the newer version suffers from a backend panic with Digital Ocean Spaces. For more information see: https://github.com/docker/distribution/issues/2695.

## Usage
Deploy with the usual Terraform recipe:

    terraform init
    terraform apply

*Tip:* Make your life easier by using a [`terraform.tfvars`](https://learn.hashicorp.com/terraform/getting-started/variables#assigning-variables) file.

*Tip:* The demo Terraform template outputs some handy SSH commands you can use to connect to the registry Droplet via SSH to diagnose problems and administer the VM/registry as needed.

After deployment (and DNS propagation delay) you can:

Note: _remember to replace \<placeholders\> with real values!_<br/>
Note: _operations on the registry require that you be logged in first!_

### View the registry catalog in your browser
Browse to https://\<fqdn\>/v2/_catalog

### Login to the registry
    docker login -u admin <fqdn>
### View the list of images stored in the registry
    docker image ls
### Push to the registry by first tagging then pushing
    docker tag <repo>/<image>:<tag> <fqdn>/<repo>/<image>/<tag>
    docker push <fqdn>/<repo>/<image>/<tag>
### Pull from the registry
    docker pull <repo>/<image>/<tag>
    docker pull <fqdn>/<repo>/<image>/<tag>
### Manage user access rights to the registry
Access is controlled by entries in an `/etc/registry/auth/htpasswd` file stored on the Digital Ocean Droplet. You can revoke access by deleting lines from the file. You can grant access to new users by executing a command like this on the Droplet when connected via SSH:

  	docker run --entrypoint htpasswd registry:2 -Bbn <username> "<password>" > /etc/registry/auth/htpasswd

And then because the registry [only reads the `htpasswd` file on startup](https://docs.docker.com/registry/configuration/#htpasswd) you'll need to restart the registry:

    docker restart registry
    
# Links
- https://docs.docker.com/registry/
- https://www.digitalocean.com/community/tutorials/how-to-set-up-a-private-docker-registry-on-ubuntu-18-04
- https://medium.com/@pcj/your-own-private-docker-repository-with-digitalocean-and-caddy-aug-26-2017-3e30859363ae

# FAQ
Q: Why don't you use NGINX like [Digital Ocean](https://www.digitalocean.com/community/tutorials/how-to-set-up-a-private-docker-registry-on-ubuntu-18-04) and even [Docker themselves](https://docs.docker.com/registry/deploying/#more-advanced-authentication) suggest?

A: I didn't want the additional complexity of a proxy in front of Docker, both for configuration, operation and when diagnosing issues, and Basic Authentication within TLS was good enough for my use case.

Q: Why don't you use the Docker out-of-the-box support for Lets Encrypt?

A: It's been broken since [issue 2545](https://github.com/docker/distribution/issues/2545).

Q: Why don't you use Caddy like [Paul Cody suggests](https://medium.com/@pcj/your-own-private-docker-repository-with-digitalocean-and-caddy-aug-26-2017-3e30859363ae)?

A: I didn't want the additional complexity (see above), and I experienced authentication issues when using Caddy, but it's possible that I had just made some other mistake in my testing at that point as others report no issues using Caddy in front of a Docker registry.

Q: Why don't you use the [Digital Ocean DNS plugin for CertBot](https://certbot-dns-digitalocean.readthedocs.io/en/stable/)?

A: I didn't want the additional complexity, and I didn't want to store my Digital Ocean API credentials on the registry Droplet.

Q: Why did you spend the time creating this? Didn't you see that XXX has already done this?

A: Partly as a learning exercise about Terraform. Despire some Googling I may have course missed something on the vast web so no I didn't see XXX and I would love to hear about any other solutions out there that I may have missed.

END
