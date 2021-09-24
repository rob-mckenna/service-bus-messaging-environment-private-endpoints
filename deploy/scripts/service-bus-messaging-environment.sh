#!/bin/bash
# This script deploys resources to set up a Service Bus messaging environment
# Set variables
echo "Set Variables - START"

environment="<ENVIRONMENT_NAME>"     # The name chosen will be used as a prefix for resource names.
location="<LOCATION>"                   # Azure location where resources are to be built.
organizationName="<ORGANIZATION_NAME>"      # Name of organization to be used when setting up the API Management Service.
adminEmail="<ADMIN_EMAIL_ADDRESS>"          # Email address for the administrator of the API Management Service.
storageAccountName="<STORAGE_ACCOUNT_NAME>"      # Storage account used by environment applications. Standard storage account naming convention applies. (Ex: svcbusmsgingdev01stg)
functionStorageAccountName="<AZURE_FUNCTION_STORAGE_ACCOUNT_NAME>"       # Storage account used for Azure Function App. Standard storage account naming convention applies. (Ex: svcbusmsgingdev01funcstg)
serviceBusSku="Premium"     # Premium SKU is required to utilize private endpoints.
serviceBusQueueName="<SERVICE_BUS_QUEUE_NAME>"      # Name of queue to be created in the Service Bus namespace.=
vmAdminUsername="<VM_ADMIN_USERNAME>"      # Admin user for logging into the virtual machine.
vmAdminPassword="<VM_ADMIN_PWD>"      # Admin user password for logging into the virtual machine.
tags="{'tagName':'tagValue'}"    # Tags to be applied to resources.  Replace with tag Name and Value of our choice.

resourceGroupName="$environment-rg"
tenantId="$(az account show --query tenantId -o tsv)"
currentUserObjectId=$(az ad signed-in-user show --query objectId -o tsv)
currentSubscriptionId=$(az account show --query id -o tsv)

logAnalyticsWorkspaceName="$environment-logwkspc"
appInsightsName="$environment-appinsights"
virtualNetworkName="$environment-vnet"
subnetName="applicationSubnet"

serviceBusSku="Premium"
apimName="$environment-apim"
echo "Set Variables - END"

echo "Create Resource Group - START"
az group create --name $resourceGroupName --location $location
echo "Create Resource Group - END"

echo "Log Analytics Workspace - START"
# Log Analytics Workspace
workspaceResourceId=$(az deployment group create \
    --resource-group $resourceGroupName \
    --name log-analytics-workspace \
    --template-file ../templates/log-analytics-workspace/log-analytics-workspace.deploy.json \
    --parameters @../templates/log-analytics-workspace/log-analytics-workspace.parameters.json \
    --parameters name=$logAnalyticsWorkspaceName location=$location tags=$tags --query properties.outputResources[0].id -o tsv)

echo "Log Analytics Workspace - END"

echo "Application Insights - START"
# Application Insights
appInsightsId=$(az deployment group create \
    --resource-group $resourceGroupName \
    --name application-insight \
    --template-file ../templates/application-insights/application-insight.deploy.json \
    --parameters @../templates/application-insights/application-insight.parameters.json \
    --parameters name=$appInsightsName regionId=$location tagsArray=$tags \
        logAnalyticsWorkspaceName=$logAnalyticsWorkspaceName --query id -o tsv)

echo "Application Insights - END"

echo "Virtual Network with Azure Bastion - START"
az deployment group create \
    --resource-group $resourceGroupName \
    --name virtual-network \
    --template-file ../templates/virtual-network/virtual-network.deploy.json \
    --parameters @../templates/virtual-network/virtual-network.parameters.json \
    --parameters virtualNetworkName=$virtualNetworkName location=$location resourceGroup=$resourceGroupName \
        bastionName="$environment-bastion" publicIpAddressForBastionName="$environment-bastion-pip" \
        tags=$tags

echo "Virtual Network with Azure Bastion - START"

echo "Virtual Machine for Jumpbox - START"
virtualMachineName="$environment-vm01"
virtualMachineComputerName=${virtualMachineName:0:15}
networkInterfaceName="$environment-nic"
networkInterfaceIpConfigName="ipconfig1"
az deployment group create \
    --resource-group $resourceGroupName \
    --name virtual-machine \
    --template-file ../templates/virtual-machine/virtual-machine.deploy.json \
    --parameters @../templates/virtual-machine/virtual-machine.parameters.json \
    --parameters virtualMachineName=$virtualMachineName virtualMachineRG=$resourceGroupName location=$location \
        networkInterfaceName=$networkInterfaceName networkInterfaceIpConfigName=$networkInterfaceIpConfigName networkSecurityGroupName="$virtualMachineName-nsg" \
        virtualMachineComputerName=$virtualMachineComputerName subnetName=$subnetName virtualNetworkName=$virtualNetworkName \
        adminUsername=$vmAdminUsername adminPassword=$vmAdminPassword tags=$tags

echo "Virtual Machine for Jumpbox - END"

echo "Virtual Machine for DevOps - START"
virtualMachineName="$environment-devops-vm01"
virtualMachineComputerName="${virtualMachineName:0:8}-devops"
networkInterfaceName="$environment-devops-nic"
networkInterfaceIpConfigName="ipconfig2"
az deployment group create \
    --resource-group $resourceGroupName \
    --name virtual-machine \
    --template-file ../templates/virtual-machine/virtual-machine.deploy.json \
    --parameters @../templates/virtual-machine/virtual-machine.parameters.json \
    --parameters virtualMachineName=$virtualMachineName virtualMachineRG=$resourceGroupName location=$location \
        networkInterfaceName=$networkInterfaceName networkInterfaceIpConfigName=$networkInterfaceIpConfigName networkSecurityGroupName="$virtualMachineName-nsg" \
        virtualMachineComputerName=$virtualMachineComputerName subnetName=$subnetName virtualNetworkName=$virtualNetworkName \
        adminUsername=$vmAdminUsername adminPassword=$vmAdminPassword tags=$tags

echo "Virtual Machine for DevOps - END"

echo "Key Vault - START"
# Key Vault
az deployment group create \
    --resource-group $resourceGroupName \
    --name key-vault \
    --template-file ../templates/key-vault/key-vault.deploy.json \
    --parameters @../templates/key-vault/key-vault.parameters.json \
    --parameters name="$environment-kv" location=$location tags=$tags \
        tenantId=$tenantId currentUserObjectId=$currentUserObjectId

echo "Key Vault - END"

echo "Storage Account with Private Endpoint - START"
# Storage Account
az deployment group create \
    --resource-group $resourceGroupName \
    --name storage-account \
    --mode incremental \
    --template-file ../templates/storage-account-with-private-endpoint/storage-account-with-private-endpoint.deploy.json \
    --parameters @../templates/storage-account-with-private-endpoint/storage-account-with-private-endpoint.parameters.json \
    --parameters storageAccountName=$storageAccountName location=$location tags=$tags \
        virtualNetworkName=$virtualNetworkName subnetName=$subnetName virtualNetworkResourceGroup=$resourceGroupName \
        privateEndpointName="$environment-prvendpnt04"

echo "Storage Account with Private Endpoint - END"

echo "Service Bus - START"
# Service Bus namespace and queue(s)
az deployment group create \
    --resource-group $resourceGroupName \
    --name service-bus \
    --template-file ../templates/service-bus/service-bus.deploy.json \
    --parameters @../templates/service-bus/service-bus.parameters.json \
    --parameters serviceBusNamespaceName="$environment-nmspc" location=$location tags=$tags \
        serviceBusQueueName=$serviceBusQueueName serviceBusSku=$serviceBusSku \
        resourceGroupName=$resourceGroupName \
        virtualNetworkName=$virtualNetworkName subnetName=$subnetName \
        zoneRedundant=true

echo "Service Bus - END"

echo "Private Endpoint for Service Bus namespace - START"
# Service Bus namespace and queue(s)
az deployment group create \
    --resource-group $resourceGroupName \
    --name private-endpoint-service-bus \
    --template-file ../templates/private-endpoint/private-endpoint.deploy.json \
    --parameters @../templates/private-endpoint/private-endpoint.parameters.json \
    --parameters privateEndpointName="$environment-prvendpnt01" resourceGroupName=$resourceGroupName location=$location tags=$tags \
        privateLinkResourceType="Microsoft.ServiceBus/namespaces" privateLinkResourceName="$environment-nmspc" targetSubResource="['namespace']" \
        virtualNetworkName=$virtualNetworkName subnetName=$subnetName virtualNetworkResourceGroup=$resourceGroupName \
        networkInterfaceName=$networkInterfaceName networkInterfaceIpConfigName=$networkInterfaceIpConfigName \
        subscriptionId=$currentSubscriptionId

echo "Private Endpoint for Service Bus namespace - END"

echo "App Service - START"
# App Service Plan and App(s)
az deployment group create \
    --resource-group $resourceGroupName \
    --name app-service \
    --template-file ../templates/app-service/app-service.deploy.json \
    --parameters @../templates/app-service/app-service.parameters.json \
    --parameters name="$environment-webapp01" location=$location tags=$tags \
        subscriptionId=$currentSubscriptionId \
        hostingPlanName="$environment-appsvcplan" \
        serverFarmResourceGroup=$resourceGroupName \
        virtualNetworkName=$virtualNetworkName subnetName="app-svc-vnet-integ-subnet"

echo "App Service - END"

echo "Azure Function App - START"
# Azure Function App
az deployment group create \
    --resource-group $resourceGroupName \
    --name azure-function \
    --template-file ../templates/azure-function/azure-function.deploy.json \
    --parameters @../templates/azure-function/azure-function.parameters.json \
    --parameters name="$environment-func01" location=$location tags=$tags \
        subscriptionId=$currentSubscriptionId \
        hostingPlanName="$environment-appsvcplan" \
        serverFarmResourceGroup=$resourceGroupName \
        storageAccountName=$functionStorageAccountName

echo "Azure Function App - END"

echo "API Management - START"
# API Management
appInsightsInstrumentationKey=$(az resource show -g $resourceGroupName -n "$environment-appinsights" --resource-type "microsoft.insights/components" --query properties.InstrumentationKey -o tsv)
az deployment group create \
    --resource-group $resourceGroupName \
    --name api-management \
    --template-file ../templates/api-management/api-management.deploy.json \
    --parameters @../templates/api-management/api-management.parameters.json \
    --parameters apimName=$apimName location=$location tagsByResource=$tags \
        organizationName=$organizationName adminEmail=$adminEmail \
        appInsightsName=$appInsightsName appInsightsInstrumentationKey=$appInsightsInstrumentationKey \
        virtualNetworkName=$virtualNetworkName subnetName='apim-subnet' virtualNetworkResourceGroup=$resourceGroupName

echo "API Management - END"

echo "Application Gateway - START"
# Application Gateway
az deployment group create \
    --resource-group $resourceGroupName \
    --name application-gateway \
    --template-file ../templates/application-gateway/application-gateway.deploy.json \
    --parameters @../templates/application-gateway/application-gateway.parameters.json \
    --parameters appGatewayName="$environment-appgtway" location=$location \
        virtualNetworkName=$virtualNetworkName apimName=$apimName \
        domainNameLabel=$environment publicIpAddressForAppGatewayName="$environment-appgtway-pip" \
        logAnalyticsWorkspaceName=$logAnalyticsWorkspaceName

echo "Application Gateway - END"

echo "Environment Setup Complete!"