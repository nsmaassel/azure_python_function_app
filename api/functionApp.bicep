// References:
// Automating function app deployment: https://docs.microsoft.com/en-us/azure/azure-functions/functions-infrastructure-as-code?tabs=linux#customizing-a-deployment

@description('The name of the function app that you wish to create.')
param appName string = 'funcAppDemo-${uniqueString(resourceGroup().id)}'

@description('Storage Account type')
param storageAccountType string = 'Standard_LRS'

@description('Location for all resources.')
param location string = resourceGroup().location

// @description('Location for Application Insights')
// param appInsightsLocation string

@description('The language worker runtime to load in the function app.')
param runtime string = 'python'

@description('The URL for the GitHub repository that contains the project to deploy.')
param repoURL string = 'https://github.com/nsmaassel/azure_python_function_app.git'

@description('The branch of the GitHub repository to use.')
param branch string = 'main'

var functionAppName = appName
var hostingPlanName = appName
// var applicationInsightsName = appName
var storageAccountName = 'funcds${uniqueString(resourceGroup().id)}'
var functionWorkerRuntime = runtime

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-08-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: storageAccountType
  }
  kind: 'Storage'
}

// Consumption Plan: 
// https://github.com/azure-samples/function-app-arm-templates/tree/main/function-app-linux-consumption#comsumption-plan
resource hostingPlan 'Microsoft.Web/serverfarms@2021-03-01' = {
  name: hostingPlanName
  location: location
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
    size: 'Y1'
    family: 'Y'
  }
  kind: 'functionapp,linux'
  properties: {
    perSiteScaling: false
    elasticScaleEnabled: false
    maximumElasticWorkerCount: 1
    isSpot: false
    reserved: true
    isXenon: false
    hyperV: false
    targetWorkerCount: 0
    targetWorkerSizeId: 0
    zoneRedundant: false
  }
}

resource functionApp 'Microsoft.Web/sites@2021-03-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp,linux'
  // Bicep says these are not needed:
  // dependsOn:[
    // hostingPlan
    // storageAccount
    // applicationInsights
  // ]
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: hostingPlan.id
    siteConfig: {
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower(functionAppName)
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~2'
        }
        {
          name: 'WEBSITE_NODE_DEFAULT_VERSION'
          value: '~10'
        }
        // {
        //   name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
        //   value: applicationInsights.properties.InstrumentationKey
        // }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: functionWorkerRuntime
        }
      ]
    }
    httpsOnly: true
  }
}

// resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
//   name: applicationInsightsName
//   location: appInsightsLocation
//   kind: 'web'
//   properties: {
//     Application_Type: 'web'
//     Request_Source: 'rest'
//   }
// }

resource siteName_sourcecontrol 'Microsoft.Web/sites/sourcecontrols@2020-12-01' = {
  parent: functionApp
  name: 'web'
  location: location
  properties: {
    repoUrl: repoURL
    branch: branch
    isManualIntegration: true
  }
  dependsOn: [
    siteName_config
  ]
}

resource siteName_config 'Microsoft.Web/sites/config@2021-03-01' = {
  parent: functionApp
  name: 'appsettings'
  properties: {
    PROJECT: 'api'
    // clientUrl: 'http://${functionAppName}.azurewebsites.net/api'
    // netFrameworkVersion: 'v6.0'
  }
}
