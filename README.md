# Azure Terraform project template

This template repository bootstraps a project for managing Azure infrastructure with Terraform.

## TOC

<details>
<summary>Table of Contents</summary>

- [Features](#features)
- [Get Started](#get-started)
    - [Prerequisites](#prerequisites)
    - [1. Configure a Managed Identity](#1-configure-a-managed-identity)
        - [1a. Create a new Managed Identity](#create-a-new-managed-identity)
        - [1b. Use an existing Managed Identity](#use-an-existing-managed-identity)
    - [2. Configure an Azure Storage Account](#2-configure-an-azure-storage-account-for-remote-state)
        - [2a. Create a new Storage Account](#create-a-new-storage-account)
        - [2b. Use an existing Storage Account](#use-an-existing-storage-account)
    - [3. Run the setup script](#3-authenticate-and-run-the-setup-script)
    - [4. Assign Roles](#4-assign-roles-to-the-managed-identity)
    - [5. Setup your Terraform project](#5-create-or-import-your-terraform-project-files)
    - [6. Configure automatic resource locking](#6-configure-automatic-resource-locking)

</details>

## Features

🔄 Continuous-integration with `terraform plan` on every pull-request  
🚀 Continuous-deployment with `terraform apply` on every merge to the main branch  
🔎 Static code analysis with `terraform validate`  
🔐 Federated authentication to Azure from Github w/ [OIDC](https://openid.net/developers/how-connect-works/) (no credentials to manage)  
📦️ Remote terraform state in Azure Blob Storage  
📈 Rich change tracking with formatted information parsed from terraform's execution plan  
🦺 Automatic resource locking in Azure (prevents configuration drift due to manual operations)  

## Get Started

Setup your own project by following these steps

### Prerequisites

- An Azure subscription
- An account with the required permissions on the subscription
    - [Managed Identity Contributor](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/identity#managed-identity-contributor) or more privileged role
    - [Role Based Access Control Administrator](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/privileged#role-based-access-control-administrator) or more privileged role
    - [Storage Account Contributor](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/storage#storage-account-contributor) or more privileged role
    - [Key Vault Administrator](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/security#key-vault-administrator) role on the KeyVault
- An Azure Resource Group to deploy to
- An Azure Key Vault (with [Soft-delete and Purge Protection](https://learn.microsoft.com/en-us/azure/key-vault/general/key-vault-recovery?tabs=azure-portal) enabled) to store an encryption key

### 0. Create a new repository from this template

### 1. Configure a Managed Identity

#### Create a new Managed Identity

1. Clone the new repository to your local machine
2. Edit the `utils/bootstrap/terraform.tfvars` file, replacing the indicated values

    | Variable | Required | Description | example/default |
    |-|-|-|-|
    | location | no | Azure region to provision the managed identity | northcentralus
    | create_new_identity | yes | Whether to create a new managed identity (to use an existing identity see [here](#use-an-existing-managed-identity)) | true
    | resource_group_name | yes | Azure resource group to provision the managed identity in
    | managed_identity_name | yes | Name to give the user assigned managed identity | {App}-Terraform
    | federated_credential_name | yes | Name to give the Github federated credential | {App}-GH
    | github_org | yes | The organization the new repository is in
    | github_repository | yes | The name of the repository created from this template

    *leave the `create_storage_account` and `storage_account_name` variables for now*

3. Continue to [Configuring a Storage Account for remote state](#2-configure-an-azure-storage-account-for-remote-state)

#### Use an existing Managed Identity

1. Clone the new repository to your local machine
2. Edit the `utils/bootstrap/terraform.tfvars` file, replacing the indicated values

    | Variable | Required | Description | example/default |
    |-|-|-|-|
    | create_new_identity | yes | Whether to create a new identity or use an existing one. This should be changed to `false` | true
    | resource_group_name | yes | Azure resource group the managed identity is in
    | managed_identity_name | yes | Name of the managed identity to use
    | federated_credential_name | yes | Name to give the Github federated credential | {App}-GH
    | github_org | yes | The organization the new repository is in
    | github_repository | yes | The name of the repository created from this template

    *leave the `create_storage_account` and `storage_account_name` variables for now*

4. Continue to [Configuring a Storage Account for remote state](#2-configure-an-azure-storage-account-for-remote-state)

### 2. Configure an Azure Storage Account for remote state

#### Create a new Storage Account

1. Edit the `utils/bootstrap/terraform.tfvars` file, replacing the indicated values

    | Variable | Required | Description | example/default |
    |-|-|-|-|
    | create_storage_account | yes | Whether to create a new storage account. This should be changed to true | false
    | storage_account_name | yes | The name of the storage account to create | {App}-Infrastructure-Storage
    | keyvault_name | yes | Keyvault to store a user managed encryption key for the storage account
    | keyvault_resource_group | no | The resource group the keyvault is in. If not provided, uses the var.resource_group_name variable | var.resource_group_name
    | storage_account_whitelist_ips | yes | Set of IPs that are allowed to access the storage account. The IP of the execution environment for the setup script is included by default
    | subscriptions_prefix | yes | Prefix of Azure subscription that the user has permissions to assign role assignment scopes to | {Organization}-

2. Continue to [Run the setup script](#3-authenticate-and-run-the-setup-script)

#### Use an existing Storage Account

*This capability hasn't been added yet. Pull requests welcome!*

### 3. Authenticate and run the setup script

The initial setup requires that you authenticate as your user principal to both Azure and Github.

Both providers can leverage access tokens issued to their CLI clients.

1. Authenticate with the Azure cli

    If your user principal has all required permissions in Azure, you should be able to simply login.

    `az login`

    This will issue an access token (managed by the cli application) that the azurerm terraform provider will use to perform operations in Azure on your behalf.

2. Authenticate with the Github cli

    To authenticate to Github and allow organization-level access, you need to configure two things.

    - Set `GITHUB_OWNER='<your-github-org>'` environment variable
        
        This tells the Github cli to operate on your org, and not your personal account.

    - Create a classic Personal-Access-Token on your Github account

        Required scopes:

        - repo
        - admin:org
        - admin:public_key

        Copy the token for the next step.

        *You may need to configure SSO if your enterprise uses Saml auth. Click the "Configure SSO" dropdown next to your new token and select the organization to authorize the token for.*

    - Login to the Github cli

        `gh auth login`

        - select "GitHub.com"
        - select "SSH" for the git protocol
        - select an SSH key associated with your Github account
        - press Enter for the SSH key title
        - select "Paste an authentication token" and paste the previously created PAT

        This will issue an access token (managed by the cli application) that the github terraform provider will use to perform operations in your Github org on your behalf.

3. From the `utils/bootstrap` directory, run 

    ```shell
    terraform init

    terraform apply
    ```
    
    This will configure your managed identity, create a federated token, create a storage account, and create some repository secret values in Github.

    See [bootstrap](./utils/bootstrap) for more details.

### 4. Assign Roles to the Managed Identity

By default, the managed identity has only one RBAC role assigned.

- [Storage Blob Data Contributor](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/storage#storage-blob-data-contributor) role

This role is required to allow the identity to manage remote terraform state in the storage account.

Other access and roles needed for managing your infrastructure must be setup yourself.

### 5. Create or import your Terraform project files

The project's main terraform script file must be at the project root.

### 6. Configure automatic resource locking

Azure resources can be locked to prevent malicious or accidental misconfiguration by a user.

The included continuous-deployment pipeline provides automated resource locking after every deploy.

The only thing you need to do to opt-in to this feature is to add the desired resources to the [locks.tf](./locks.tf) file.

Resource locks are recursively enforced. This means if you apply a resource lock on an Azure Resource Group, that lock also applies to all contained resources.

Creating and destroying resource locks with Terraform takes comparatively longer than most other resources (it takes between 90 and 150 seconds per lock for both destroy and create), so it's best to use as few as possible to keep your CI/CD runs short.
