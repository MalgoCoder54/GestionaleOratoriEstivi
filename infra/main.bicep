targetScope = 'subscription'

@description('Regione Azure per tutte le risorse.')
param location string = 'westeurope'

@description('Resource group della landing zone applicativa.')
param resourceGroupName string = 'rg-oratorio-estivo-${uniqueString(subscription().id)}'

@description('Nome globale del logical server Azure SQL.')
param sqlServerName string = 'sql-oratorio-${uniqueString(subscription().id)}'

@description('Nome globale dell\'app ragazzi.')
param ragazziWebAppName string = 'app-oratorio-ragazzi-${uniqueString(subscription().id)}'

@description('Nome globale dell\'app animatori.')
param animatoriWebAppName string = 'app-oratorio-animatori-${uniqueString(subscription().id)}'

param sqlDatabaseName string = 'oratorio-estivo'
param sqlAdminLogin string = 'sqladmin'
param ragazziDisplayName string = 'Oratorio Estivo - Ragazzi'
param animatoriDisplayName string = 'Oratorio Estivo - Animatori'
param organizationName string = 'Nome oratorio'
param organizationLocation string = ''
param defaultEventId string = 'EVENTO_ESEMPIO'

@secure()
param sqlAdminPassword string

@description('Utente contained usato dalle app e da Power Automate.')
param appSqlUser string = 'oratorio_app_rw'

@secure()
param appSqlPassword string

@secure()
param flaskSecretKey string

param appServicePlanSkuName string = 'B1'
param sqlDatabaseSkuName string = 'S0'
param sqlAllowAzureServices bool = true
param sqlClientIpStart string = ''
param sqlClientIpEnd string = ''

param enableEasyAuth bool = false
param entraTenantId string = subscription().tenantId
param entraClientId string = ''

@secure()
param entraClientSecret string = ''

resource resourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: resourceGroupName
  location: location
  tags: {
    solution: 'oratorio-estivo'
    managedBy: 'bicep'
  }
}

module appStack './modules/app-stack.bicep' = {
  name: 'oratorio-estivo-app-stack'
  scope: resourceGroup
  params: {
    location: location
    sqlServerName: sqlServerName
    sqlDatabaseName: sqlDatabaseName
    sqlAdminLogin: sqlAdminLogin
    sqlAdminPassword: sqlAdminPassword
    appSqlUser: appSqlUser
    appSqlPassword: appSqlPassword
    flaskSecretKey: flaskSecretKey
    ragazziWebAppName: ragazziWebAppName
    animatoriWebAppName: animatoriWebAppName
    ragazziDisplayName: ragazziDisplayName
    animatoriDisplayName: animatoriDisplayName
    organizationName: organizationName
    organizationLocation: organizationLocation
    defaultEventId: defaultEventId
    appServicePlanSkuName: appServicePlanSkuName
    sqlDatabaseSkuName: sqlDatabaseSkuName
    sqlAllowAzureServices: sqlAllowAzureServices
    sqlClientIpStart: sqlClientIpStart
    sqlClientIpEnd: sqlClientIpEnd
    enableEasyAuth: enableEasyAuth
    entraTenantId: entraTenantId
    entraClientId: entraClientId
    entraClientSecret: entraClientSecret
  }
}

output resourceGroupName string = resourceGroup.name
output sqlServerName string = sqlServerName
output ragazziWebAppName string = ragazziWebAppName
output animatoriWebAppName string = animatoriWebAppName
