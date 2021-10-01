# Service Bus Messaging Environment with Private Endpoints

## About This Repository

This repository builds an Azure Service Bus messaging environment using private endpoints to secure the environment.  Resources are only accessible from within the virtual network.  The repository consists of a variety of ARM Templates that are executed via a Bash shell script.

## How To Use This Repository

* The repository can be cloned locally or within Azure Cloud Shell.
  * Locally, is can be run from within Visual Studio Code using a Git Bash terminal.
  * Using Azure Cloud Shell, make sure Bash is selected and not PowerShell.
* Open the service-bus-messaging-environment.sh script file to edit the variables listed below

Variable Name | Description
------------- | -----------
environment | The name chosen will be used as a prefix for resource names.
location | Azure location where resources are to be built.
organizationName |  Name of organization to be used when setting up the API Management Service.
adminEmail |  Email address for the administrator of the API Management Service.
storageAccountName |  Storage account used by environment applications. Standard storage account naming convention applies. (Ex: svcbusmsgingdev01stg)
functionStorageAccountName |  Storage account used for Azure Function App. Standard storage account naming convention applies. (Ex: svcbusmsgingdev01funcstg)
serviceBusSku |  Premium SKU is required to utilize private endpoints.
serviceBusQueueName |  Name of queue to be created in the Service Bus namespace.
vmAdminUsername |  Admin user for logging into the virtual machine.
vmAdminPassword |  Admin user password for logging into the virtual machine.
tags |  Tags to be applied to resources.  Replace with tag Name and Value of our choice.  Be sure to maintain the JSON format.

* Be sure to save the chages to the script file.
* Change directory to the scripts directory.
* Execute the shell script to build the environment.

```bash
./service-bus-messaging-environment.sh
```
