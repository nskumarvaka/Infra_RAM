variable "name_prefix" {
  type = string
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "app_service_plan_sku" {
  type = string
}

variable "app_subnet_id" {
  type = string
}

variable "public_network_access_enabled" {
  type = bool
}

variable "public_ip_rules" {
  type = list(object({
    name       = string
    ip_address = string
    priority   = number
  }))
}

variable "frontend_identity_id" {
  type = string
}

variable "backend_identity_id" {
  type = string
}

variable "key_vault_uri" {
  type = string
}

variable "app_insights_connection_string" {
  type = string
}

variable "log_analytics_workspace_id" {
  type = string
}

variable "frontend_health_check_path" {
  type = string
}

variable "backend_health_check_path" {
  type = string
}

variable "frontend_app_settings" {
  type    = map(string)
  default = {}
}

variable "backend_app_settings" {
  type    = map(string)
  default = {}
}

variable "key_vault_secret_names" {
  type    = map(string)
  default = {}
}

variable "tags" {
  type    = map(string)
  default = {}
}

locals {
  vault_references = {
    for setting, secret in var.key_vault_secret_names :
    setting => "@Microsoft.KeyVault(SecretUri=${var.key_vault_uri}secrets/${secret})"
  }
}

resource "azurerm_service_plan" "frontend" {
  name                = "plan-${var.name_prefix}-frontend"
  location            = var.location
  resource_group_name = var.resource_group_name
  os_type             = "Linux"
  sku_name            = var.app_service_plan_sku
  tags                = var.tags
}

resource "azurerm_service_plan" "backend" {
  name                = "plan-${var.name_prefix}-backend"
  location            = var.location
  resource_group_name = var.resource_group_name
  os_type             = "Linux"
  sku_name            = var.app_service_plan_sku
  tags                = var.tags
}

resource "azurerm_linux_web_app" "frontend" {
  name                                           = "app-${var.name_prefix}-frontend"
  location                                       = var.location
  resource_group_name                            = var.resource_group_name
  service_plan_id                                = azurerm_service_plan.frontend.id
  virtual_network_subnet_id                      = var.app_subnet_id
  public_network_access_enabled                  = var.public_network_access_enabled
  https_only                                     = true
  ftp_publish_basic_authentication_enabled       = false
  webdeploy_publish_basic_authentication_enabled = false
  key_vault_reference_identity_id                = var.frontend_identity_id
  app_settings = merge(var.frontend_app_settings, local.vault_references, {
    APPLICATIONINSIGHTS_CONNECTION_STRING = var.app_insights_connection_string
    WEBSITE_RUN_FROM_PACKAGE              = "1"
  })
  logs {
    detailed_error_messages = true
    failed_request_tracing  = true

    http_logs {
      file_system {
        retention_in_days = 7
        retention_in_mb   = 35
      }
    }
  }
  tags = var.tags

  identity {
    type         = "SystemAssigned, UserAssigned"
    identity_ids = [var.frontend_identity_id]
  }

  site_config {
    always_on                     = true
    ftps_state                    = "Disabled"
    health_check_path             = var.frontend_health_check_path
    http2_enabled                 = true
    minimum_tls_version           = "1.2"
    ip_restriction_default_action = "Deny"

    application_stack {
      dotnet_version = "8.0"
    }

    dynamic "ip_restriction" {
      for_each = var.public_ip_rules
      content {
        name       = ip_restriction.value.name
        ip_address = ip_restriction.value.ip_address
        priority   = ip_restriction.value.priority
        action     = "Allow"
      }
    }
  }
}

resource "azurerm_linux_web_app" "backend" {
  name                                           = "app-${var.name_prefix}-backend"
  location                                       = var.location
  resource_group_name                            = var.resource_group_name
  service_plan_id                                = azurerm_service_plan.backend.id
  virtual_network_subnet_id                      = var.app_subnet_id
  public_network_access_enabled                  = var.public_network_access_enabled
  https_only                                     = true
  ftp_publish_basic_authentication_enabled       = false
  webdeploy_publish_basic_authentication_enabled = false
  key_vault_reference_identity_id                = var.backend_identity_id
  app_settings = merge(var.backend_app_settings, local.vault_references, {
    APPLICATIONINSIGHTS_CONNECTION_STRING = var.app_insights_connection_string
    WEBSITE_RUN_FROM_PACKAGE              = "1"
  })
  logs {
    detailed_error_messages = true
    failed_request_tracing  = true

    http_logs {
      file_system {
        retention_in_days = 7
        retention_in_mb   = 35
      }
    }
  }
  tags = var.tags

  identity {
    type         = "SystemAssigned, UserAssigned"
    identity_ids = [var.backend_identity_id]
  }

  site_config {
    always_on                     = true
    ftps_state                    = "Disabled"
    health_check_path             = var.backend_health_check_path
    http2_enabled                 = true
    minimum_tls_version           = "1.2"
    ip_restriction_default_action = "Deny"

    application_stack {
      dotnet_version = "8.0"
    }

    dynamic "ip_restriction" {
      for_each = var.public_ip_rules
      content {
        name       = ip_restriction.value.name
        ip_address = ip_restriction.value.ip_address
        priority   = ip_restriction.value.priority
        action     = "Allow"
      }
    }
  }
}

resource "azurerm_monitor_diagnostic_setting" "frontend" {
  name                       = "app-frontend-diagnostics"
  target_resource_id         = azurerm_linux_web_app.frontend.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  dynamic "enabled_log" {
    for_each = ["AppServiceHTTPLogs", "AppServiceConsoleLogs", "AppServiceAppLogs", "AppServicePlatformLogs"]
    content {
      category = enabled_log.value
    }
  }

  metric {
    category = "AllMetrics"
  }
}

resource "azurerm_monitor_diagnostic_setting" "backend" {
  name                       = "app-backend-diagnostics"
  target_resource_id         = azurerm_linux_web_app.backend.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  dynamic "enabled_log" {
    for_each = ["AppServiceHTTPLogs", "AppServiceConsoleLogs", "AppServiceAppLogs", "AppServicePlatformLogs"]
    content {
      category = enabled_log.value
    }
  }

  metric {
    category = "AllMetrics"
  }
}

output "frontend_id" {
  value = azurerm_linux_web_app.frontend.id
}

output "frontend_name" {
  value = azurerm_linux_web_app.frontend.name
}

output "frontend_url" {
  value = "https://${azurerm_linux_web_app.frontend.default_hostname}"
}

output "frontend_principal_id" {
  value = azurerm_linux_web_app.frontend.identity[0].principal_id
}

output "backend_id" {
  value = azurerm_linux_web_app.backend.id
}

output "backend_name" {
  value = azurerm_linux_web_app.backend.name
}

output "backend_url" {
  value = "https://${azurerm_linux_web_app.backend.default_hostname}"
}

output "backend_principal_id" {
  value = azurerm_linux_web_app.backend.identity[0].principal_id
}
