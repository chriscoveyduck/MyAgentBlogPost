// Main Bicep file for deploying Azure Function, Event Hub, Storage, App Insights, Log Analytics, and Key Vault
// Resource names use resourceToken for uniqueness
param environmentName string
param location string = resourceGroup().location
param resourceGroupName string
param twilioAccountSid string
param twilioAuthToken string
param twilioFromNumber string

var resourceToken = toLower(replace('${environmentName}', '_', ''))

resource storage 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: 'st${resourceToken}${uniqueString(resourceGroup().id)}'
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: 'appi-${resourceToken}${uniqueString(resourceGroup().id)}'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
  }
}

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: 'log-${resourceToken}${uniqueString(resourceGroup().id)}'
  location: location
  sku: {
    name: 'PerGB2018'
  }
  properties: {
    retentionInDays: 30
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: 'kv-${resourceToken}${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    accessPolicies: []
    enabledForDeployment: true
    enabledForTemplateDeployment: true
    enabledForDiskEncryption: true
    enableSoftDelete: true
    enablePurgeProtection: true
    publicNetworkAccess: 'Enabled'
  }
}

resource eventHubNamespace 'Microsoft.EventHub/namespaces@2023-01-01-preview' = {
  name: 'ehns-${resourceToken}${uniqueString(resourceGroup().id)}'
  location: location
  sku: {
    name: 'Standard'
    tier: 'Standard'
  }
  properties: {
    isAutoInflateEnabled: true
    maximumThroughputUnits: 1
  }
}

resource eventHub 'Microsoft.EventHub/namespaces/eventhubs@2023-01-01-preview' = {
  parent: eventHubNamespace
  name: 'orders-stream'
  properties: {
    messageRetentionInDays: 1
    partitionCount: 2
  }
}

resource eventHubAuthRule 'Microsoft.EventHub/namespaces/authorizationRules@2023-01-01-preview' = {
  name: '${eventHubNamespace.name}/RootManageSharedAccessKey'
  properties: {
    rights: [
      'Listen'
      'Send'
      'Manage'
    ]
  }
}

resource functionApp 'Microsoft.Web/sites@2022-09-01' = {
  name: 'func-${resourceToken}${uniqueString(resourceGroup().id)}'
  location: location
  kind: 'functionapp'
  properties: {
    serverFarmId: functionPlan.id
    siteConfig: {
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: storage.properties.primaryEndpoints.blob
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'python'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsights.properties.InstrumentationKey
        }
        {
          name: 'EventHubConnectionString'
          value: listKeys(resourceId('Microsoft.EventHub/namespaces/authorizationRules', eventHubNamespace.name, 'RootManageSharedAccessKey'), '2023-01-01-preview').primaryConnectionString
        }
        {
          name: 'TWILIO_ACCOUNT_SID'
          value: twilioAccountSid
        }
        {
          name: 'TWILIO_AUTH_TOKEN'
          value: twilioAuthToken
        }
        {
          name: 'TWILIO_FROM_NUMBER'
          value: twilioFromNumber
        }
      ]
    }
  }
  identity: {
    type: 'SystemAssigned'
  }
  dependsOn: [storage, appInsights, eventHub]
}

resource functionPlan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: 'plan-${resourceToken}${uniqueString(resourceGroup().id)}'
  location: location
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
}

output functionAppName string = functionApp.name
output eventHubName string = eventHub.name
output eventHubNamespaceName string = eventHubNamespace.name
output storageAccountName string = storage.name
output keyVaultName string = keyVault.name
output appInsightsName string = appInsights.name
output logAnalyticsName string = logAnalytics.name
