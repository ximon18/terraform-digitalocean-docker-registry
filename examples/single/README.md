# Deploy a single Docker private registry on Digital Ocean using Terraform
This example template deploys a [private v2 Docker registry](https://docs.docker.com/registry/) on a small [Digital Ocean](https://digitalocean.com/) Droplet (1 vCPU, 1 GiB RAM), with a [Lets Encrypt](https://letsencrypt.org/) TLS certificate and optional Digital Ocean Space storage of registry images, reachable via a subdomain of a domain that you control.

## Requirements
To use this module you will need to:
- Buy a domain name if you don't already control one.
- Create a Digital Ocean account.
- Add a parent domain that you control to Digital Ocean (see Networking -> Domains in the Digital Ocean portal).
- Create a Digital Ocean API token (see API -> Tokens/Keys in the Digital Ocean portal) and set it in the `DIGITALOCEAN_TOKEN` environment variable:
    IFS= read -rs DIGITALOCEAN_TOKEN < /dev/tty
- Install [Terraform](https://terraform.io/) (tested with v0.11.13 on Ubuntu Linux 18.10)

Optionally you may also:
- Create an SSH public/private key pair (e.g. use `ssh-keygen`) for shell access to the Droplet on which the registry will run. The demo template defaults to using the file commonly stored in `~/.ssh/id_rsa.pub`.
- Create a Digital Ocean Space for storing registry images (see Spaces in the Digital Ocean portal). If not specified the images will be stored with the registry Docker container on the Digital Ocean Droplet and will be lost if either the Docker container or the Droplet are lost.
- Install [wait-for-it](https://github.com/vishnubob/wait-for-it) in your PATH for demonstration of a post check that waits for the registry to be reachable after finishing deployment. Without this Terraform completes as soon as the Digital Ocean Droplet and DNS record have been created.

## Known issues
- This template does NOT yet demonstrate a load-balanced setup. if you wish to do so you should set the registry_HTTP_secret module input variable. For more information see: https://docs.docker.com/registry/#load-balancing-considerations.

## Usage
Deploy with the usual Terraform recipe:

    terraform init
    terraform plan
    terraform apply

*Tip:* Make your life easier by using a [`terraform.tfvars`](https://learn.hashicorp.com/terraform/getting-started/variables#assigning-variables) file.

See the module [README.md](../../README.md) for more information.
    
END
