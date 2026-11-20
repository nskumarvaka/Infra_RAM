variable "name" {
  type = string
}

variable "server_id" {
  type = string
}

variable "sku_name" {
  type = string
}

variable "short_term_retention_days" {
  type    = number
  default = 14
}

variable "enable_long_term_backup_retention" {
  type    = bool
  default = false
}

variable "weekly_backup_retention" {
  type    = string
  default = "P4W"
}

variable "monthly_backup_retention" {
  type    = string
  default = "P12M"
}

variable "yearly_backup_retention" {
  type    = string
  default = "P1Y"
}

variable "week_of_year" {
  type    = number
  default = 1
}

variable "tags" {
  type    = map(string)
  default = {}
}

resource "azurerm_mssql_database" "this" {
  name           = var.name
  server_id      = var.server_id
  sku_name       = var.sku_name
  collation      = "SQL_Latin1_General_CP1_CI_AS"
  zone_redundant = startswith(var.sku_name, "GP_") || startswith(var.sku_name, "BC_")
  tags           = var.tags

  short_term_retention_policy {
    retention_days = var.short_term_retention_days
  }

  dynamic "long_term_retention_policy" {
    for_each = var.enable_long_term_backup_retention ? [true] : []
    content {
      weekly_retention  = var.weekly_backup_retention
      monthly_retention = var.monthly_backup_retention
      yearly_retention  = var.yearly_backup_retention
      week_of_year      = var.week_of_year
    }
  }
}

output "id" {
  value = azurerm_mssql_database.this.id
}

output "name" {
  value = azurerm_mssql_database.this.name
}
