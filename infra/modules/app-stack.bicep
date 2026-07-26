targetScope = 'resourceGroup'

param location string
param sqlServerName string
param sqlDatabaseName string
param sqlAdminLogin string

@secure()
param sqlAdminPassword string

param appSqlUser string

@secure()
param appSqlPassword string

@secure()
param flaskSecretKey string

param ragazziWebAppName string
param animatoriWebAppName string
param ragazziDisplayName string
param animatoriDisplayName string
param organizationName string
param organizationLocation string
param defaultEventId string
param appServicePlanSkuName string = 'B1'
param sqlDatabaseSkuName string = 'S0'
param sqlAllowAzureServices bool = true
param sqlClientIpStart string = ''
param sqlClientIpEnd string = ''
param enableEasyAuth bool = false
param entraTenantId string
param entraClientId string = ''

@secure()
param entraClientSecret string = ''

var commonTags = {
  solution: 'oratorio-estivo'
  managedBy: 'bicep'
}
var keyVaultSecretsUserRoleId = '4633458b-17de-408a-b874-0445c86b69e6'
var keyVaultName = 'kv-oratorio-${uniqueString(resourceGroup().id)}'
var logAnalyticsName = 'law-oratorio-${uniqueString(resourceGroup().id)}'
var appInsightsName = 'appi-oratorio-${uniqueString(resourceGroup().id)}'
var appServicePlanName = 'asp-oratorio-${uniqueString(resourceGroup().id)}'
var sqlAppPasswordSecretUri = format('https://{0}{1}/secrets/{2}', keyVault.name, environment().suffixes.keyvaultDns, appSqlPasswordSecret.name)
var flaskSecretKeySecretUri = format('https://{0}{1}/secrets/{2}', keyVault.name, environment().suffixes.keyvaultDns, flaskSecretKeySecret.name)
var easyAuthSecretUri = format('https://{0}{1}/secrets/{2}', keyVault.name, environment().suffixes.keyvaultDns, easyAuthSecret.name)
var commonAppSettings = [
  { name: 'DB_SERVER', value: format('{0}{1}', sqlServer.name, environment().suffixes.sqlServerHostname) }
  { name: 'DB_NAME', value: sqlDatabaseName }
  { name: 'DB_USER', value: appSqlUser }
  { name: 'DB_PASSWORD', value: '@Microsoft.KeyVault(SecretUri=${sqlAppPasswordSecretUri})' }
  { name: 'DB_ODBC_DRIVER', value: 'ODBC Driver 18 for SQL Server' }
  { name: 'DB_ENCRYPT', value: 'true' }
  { name: 'DB_TRUST_SERVER_CERTIFICATE', value: 'false' }
  { name: 'VALIDATE_DB_SCHEMA_ON_STARTUP', value: 'true' }
  { name: 'CONFIG_CACHE_TTL_SECONDS', value: '15' }
  { name: 'FLASK_SECRET_KEY', value: '@Microsoft.KeyVault(SecretUri=${flaskSecretKeySecretUri})' }
  { name: 'SCM_DO_BUILD_DURING_DEPLOYMENT', value: 'true' }
  { name: 'WEBSITE_HTTPLOGGING_RETENTION_DAYS', value: '7' }
]
var easyAuthAppSettings = enableEasyAuth ? [
  { name: 'EASY_AUTH_CLIENT_SECRET', value: '@Microsoft.KeyVault(SecretUri=${easyAuthSecretUri})' }
] : []

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsName
  location: location
  tags: commonTags
  properties: {
    retentionInDays: 30
    sku: { name: 'PerGB2018' }
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  tags: commonTags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
  }
}

resource appServicePlan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: appServicePlanName
  location: location
  tags: commonTags
  sku: {
    name: appServicePlanSkuName
    tier: appServicePlanSkuName == 'B1' ? 'Basic' : 'Standard'
  }
  properties: {
    reserved: true
  }
}

resource sqlServer 'Microsoft.Sql/servers@2022-05-01-preview' = {
  name: sqlServerName
  location: location
  tags: commonTags
  properties: {
    administratorLogin: sqlAdminLogin
    administratorLoginPassword: sqlAdminPassword
    version: '12.0'
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
  }
}

resource sqlDatabase 'Microsoft.Sql/servers/databases@2022-05-01-preview' = {
  parent: sqlServer
  name: sqlDatabaseName
  location: location
  tags: commonTags
  sku: {
    name: sqlDatabaseSkuName
    tier: sqlDatabaseSkuName == 'S0' ? 'Standard' : 'Basic'
  }
  properties: {
    zoneRedundant: false
    readScale: 'Disabled'
  }
}

resource sqlAllowAzure 'Microsoft.Sql/servers/firewallRules@2022-05-01-preview' = if (sqlAllowAzureServices) {
  parent: sqlServer
  name: 'AllowAzureServices'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

resource sqlClientFirewall 'Microsoft.Sql/servers/firewallRules@2022-05-01-preview' = if (!empty(sqlClientIpStart) && !empty(sqlClientIpEnd)) {
  parent: sqlServer
  name: 'AllowedClientIp'
  properties: {
    startIpAddress: sqlClientIpStart
    endIpAddress: sqlClientIpEnd
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: keyVaultName
  location: location
  tags: commonTags
  properties: {
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    enabledForTemplateDeployment: true
    publicNetworkAccess: 'Enabled'
    sku: { family: 'A', name: 'standard' }
  }
}

resource appSqlPasswordSecret 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  parent: keyVault
  name: 'sql-app-password'
  properties: { value: appSqlPassword }
}

resource flaskSecretKeySecret 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  parent: keyVault
  name: 'flask-secret-key'
  properties: { value: flaskSecretKey }
}

resource easyAuthSecret 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = if (enableEasyAuth) {
  parent: keyVault
  name: 'easy-auth-client-secret'
  properties: { value: entraClientSecret }
}

resource ragazziWebApp 'Microsoft.Web/sites@2022-09-01' = {
  name: ragazziWebAppName
  location: location
  tags: union(commonTags, { role: 'ragazzi' })
  identity: { type: 'SystemAssigned' }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'PYTHON|3.11'
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      appCommandLine: 'sh startup_azure.sh'
      appSettings: concat(commonAppSettings, [
        { name: 'APP_DISPLAY_NAME', value: ragazziDisplayName }
        { name: 'APP_ROLE', value: 'ragazzi' }
        { name: 'ORGANIZATION_NAME', value: organizationName }
        { name: 'ORGANIZATION_LOCATION', value: organizationLocation }
        { name: 'REQUIRE_EASY_AUTH', value: string(enableEasyAuth) }
        { name: 'DEFAULT_EVENT_ID', value: defaultEventId }
      ], easyAuthAppSettings)
    }
  }
}

resource animatoriWebApp 'Microsoft.Web/sites@2022-09-01' = {
  name: animatoriWebAppName
  location: location
  tags: union(commonTags, { role: 'animatori' })
  identity: { type: 'SystemAssigned' }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'PYTHON|3.11'
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      appCommandLine: 'sh startup_azure.sh'
      appSettings: concat(commonAppSettings, [
        { name: 'APP_DISPLAY_NAME', value: animatoriDisplayName }
        { name: 'APP_ROLE', value: 'animatori' }
        { name: 'ORGANIZATION_NAME', value: organizationName }
        { name: 'ORGANIZATION_LOCATION', value: organizationLocation }
        { name: 'REQUIRE_EASY_AUTH', value: string(enableEasyAuth) }
        { name: 'DEFAULT_EVENT_ID', value: defaultEventId }
      ], easyAuthAppSettings)
    }
  }
}

resource ragazziKeyVaultRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, ragazziWebApp.id, keyVaultSecretsUserRoleId)
  scope: keyVault
  properties: {
    principalId: ragazziWebApp.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultSecretsUserRoleId)
  }
}

resource animatoriKeyVaultRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, animatoriWebApp.id, keyVaultSecretsUserRoleId)
  scope: keyVault
  properties: {
    principalId: animatoriWebApp.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultSecretsUserRoleId)
  }
}

resource ragazziAuth 'Microsoft.Web/sites/config@2022-09-01' = if (enableEasyAuth) {
  parent: ragazziWebApp
  name: 'authsettingsV2'
  properties: {
    platform: { enabled: true }
    globalValidation: {
      requireAuthentication: true
      unauthenticatedClientAction: 'RedirectToLoginPage'
    }
    identityProviders: {
      azureActiveDirectory: {
        enabled: true
        registration: {
          openIdIssuer: format('{0}{1}/v2.0', environment().authentication.loginEndpoint, entraTenantId)
          clientId: entraClientId
          clientSecretSettingName: 'EASY_AUTH_CLIENT_SECRET'
        }
      }
    }
  }
}

resource animatoriAuth 'Microsoft.Web/sites/config@2022-09-01' = if (enableEasyAuth) {
  parent: animatoriWebApp
  name: 'authsettingsV2'
  properties: {
    platform: { enabled: true }
    globalValidation: {
      requireAuthentication: true
      unauthenticatedClientAction: 'RedirectToLoginPage'
    }
    identityProviders: {
      azureActiveDirectory: {
        enabled: true
        registration: {
          openIdIssuer: format('{0}{1}/v2.0', environment().authentication.loginEndpoint, entraTenantId)
          clientId: entraClientId
          clientSecretSettingName: 'EASY_AUTH_CLIENT_SECRET'
        }
      }
    }
  }
}

output keyVaultName string = keyVault.name
output sqlDatabaseFullyQualifiedDomainName string = format('{0}{1}', sqlServer.name, environment().suffixes.sqlServerHostname)
output ragazziDefaultHostName string = ragazziWebApp.properties.defaultHostName
output animatoriDefaultHostName string = animatoriWebApp.properties.defaultHostName
