# How to manage Dynamic Database Credentials using Hashicorp Vault
- - - -
## Estimated Time to Complete
20 minutes

## Introduction
Vault is a secrets management tool used in enterprises worldwide to 

## Prerequisites
This guide assumes that you have a Vault instance or cluster installed, initialized, and unsealed, and that you can authenticate to it.

You will also need a database for which Vault has network access. In this guide we will use the PostgreSQL database, but others can be used. For the full supported list, see the [Vault Database Backend Documentation](https://www.vaultproject.io/docs/secrets/databases/index.html)

For convenience, the Terraform code in this guide can provision these for you in AWS. To use it, make sure you have the [aws-cli](https://aws.amazon.com/cli/) installed and configured with your IAM credentials, then clone the repo and run:

```shell
cd terraform-aws
vi vars.tfvars  # Enter relevant values into this file
terraform plan -out=./tfplan.out -var-file=./vars.tfvars
terraform apply ./tfplan.out
```

Make sure to store the output values of the `terraform apply` command for use later in this guide, and when you SSH into the Vault server, run the following before executing any CLI commands:

```shell
export VAULT_ADDR="http://127.0.0.1:8200"
```

This guide will use Vault’s CLI to demonstrate the process. Should you want to automate it, please refer to the [API Documentation](https://www.vaultproject.io/api/system/seal-status.html). Every CLI command shown here has a 1:1 correlation with an API call.

## Step 1: Collect Required Credentials
If the included Terraform config was used, the outputs at the end of the apply phase will contain everything you need.

If set up manually, you will need the following:
- [ ] Database URL
- [ ] Database Root Username
- [ ] Database Root Password
- [ ] Vault Root Token (or another token/authentication with permissions to mount a secret backend and use it)

Within this guide, we will use the values provided by the included Terraform config. Replace the values as needed when using your own infrastructure.

## Step 2: Mount the Database Secret Backend
To set up Vault to connect to a database, the first thing it needs is to have a backend mounted specifically for that database. This step would typically be part of a company's runbook when provisioning a database.

To mount the backend, run:

```shell
vault mount -path=mydb database
```

This mounts the database backend with the `mydb` path prefix. If you'd like to manage multiple databases, you'll need to mount the backend once for each database using a unique path each time.

## Step 3: Configure the Database Connection
Now that the database backend is mounted, we need to tell Vault how to reach the database on the network and provide it the root credentials to manage the database with. This can all be done with a single command:

```shell
vault write mydb/config/postgresql \
    plugin_name=postgresql-database-plugin \
    allowed_roles="webtier,admin" \
    connection_url="postgresql://<dbuser>:<dbpass>@<ip>:5432/<dbname>"
```

In this command, we're setting the following:

* **plugin_name**: This indicates the type of database that we want to connect to
* **allowed_roles**: This whitelists a set of roles that are allowed to connect to the database. Typically, a role would be set up for each application that connects and for each position in the company. For this example we're whitelisting a role for the web tier of a web application (this could be Wordpress, Rails, or anything else) and a role for the administrator.
* **connection_url**: The connection string for reaching the database, including the username and password.

## Step 4: Configure a Role
With the database connected, we can now set up a role. This role can be thought of as a template for how user-level credentials will be created.

```shell
vault write mydb/roles/admin \
    db_name=postgresql \
    creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; \
        GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO \"{{name}}\";" \
    default_ttl="1h" \
    max_ttl="24h"
```

Here, we're setting a few parameters. The `default_ttl` and `max_ttl` parameters tell Vault what the lifetime of the credentials should be. Then we set the `creation_statements` parameter. This required parameter allows you to enter the statements that you'd like to execute when creating a user. This can be any valid SQL. Should you choose to use any additional statements aside from `CREATE_ROLE` and `GRANT`, you can also add the optional parameters of `revocation_statements`, `rollback_statements`, and `renew_statements` to apply custom SQL at those points in the credential lifecycle.

## Step 5: Create Credentials and Access Database
Now, you can generate new credentials by calling:

```shell
vault read mydb/creds/admin
```

For the purposes of this guide we're using the same token, but in production you'd have this command executed by a client with its own access token to Vault. It's policy would ideally only allow access to the path above so that it is unable to modify the role or connection.

## Exercise: Simulate a production setup
Make this setup production ready! Configure the policy for your authorized application to allow generating new credentials, and make sure it's not allowed to access the other paths related to the backend configuration, and access it via an API call.


## Additional Reading

[Database Backend](https://www.vaultproject.io/docs/secrets/databases/index.html)

[Postgres Backend](https://www.vaultproject.io/docs/secrets/databases/postgresql.html)

[Database Backend API](https://www.vaultproject.io/api/secret/databases/index.html)

[Postgres Backend API](https://www.vaultproject.io/api/secret/databases/postgresql.html)
