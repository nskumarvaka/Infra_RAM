variable "name" {
  type = string
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "administrator_name" {
  type = string
}

variable "administrator_object_id" {
  type = string
}

variable "administrator_tenant_id" {
  type = string
}

variable "log_analytics_workspace_id" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

resource "azurerm_mssql_server" "this" {
  name                          = var.name
  resource_group_name           = var.resource_group_name
  location                      = var.location
  version                       = "12.0"
  minimum_tls_version           = "1.2"
  public_network_access_enabled = false
  tags                          = var.tags

  azuread_administrator {
    login_username              = var.administrator_name
    object_id                   = var.administrator_object_id
    tenant_id                   = var.administrator_tenant_id
    azuread_authentication_only = true
  }
}

resource "azurerm_monitor_diagnostic_setting" "this" {
  name                       = "${var.name}-diagnostics"
  target_resource_id         = azurerm_mssql_server.this.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  dynamic "enabled_log" {
    for_each = ["SQLSecurityAuditEvents", "Errors", "Timeouts", "Deadlocks", "Blocks"]
    content {
      category = enabled_log.value
    }
  }

  metric {
    category = "AllMetrics"
  }
}

resource "azurerm_mssql_server_extended_auditing_policy" "this" {
  server_id              = azurerm_mssql_server.this.id
  log_monitoring_enabled = true
  retention_in_days      = 91
  audit_actions_and_groups = [
    "BATCH_COMPLETED_GROUP",
    "SUCCESSFUL_DATABASE_AUTHENTICATION_GROUP",
    "FAILED_DATABASE_AUTHENTICATION_GROUP",
  ]
}

output "id" {
  value = azurerm_mssql_server.this.id
}

output "name" {
  value = azurerm_mssql_server.this.name
}

output "fqdn" {
  value = azurerm_mssql_server.this.fully_qualified_domain_name
}
