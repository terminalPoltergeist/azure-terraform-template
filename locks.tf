/*
This file is used by the continuous-deployment pipeline to automatically unlock resources
before every deploy and automatically re-lock them after.

Resource locks are recursive. So if you apply a lock to a container resource (like a resource group)
it will also lock all contained resources.

To include a resource, follow the below example:

output "dolock_SOME-NAME" {
    value = some_azure_provider.some_resource.id
}

The only two requirements are that the output name starts with "dolock_" and the value is the resource ID.
*/
