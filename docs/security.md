# Security controls

- Terraform and AzureRM versions are pinned. The root provider uses Azure CLI/OIDC identity; no client secrets are stored in code.
- The SQL logical server is Entra-authentication-only, public access is disabled, and TLS 1.2 is required. Backend and ADF SQL users must be created in each database using the Entra administrator and the included post-deployment script. Review/replace database roles with application-specific least-privilege grants.
- Key Vault uses Azure RBAC, private endpoints, soft delete, 90-day recovery, and purge protection. Runtime identities receive `Key Vault Secrets User` rather than vault administration permissions.
- App Services and Functions require HTTPS, disable FTP/WebDeploy basic publishing authentication, use TLS 1.2+, and run with managed identities. App Services enable HTTP/2, HTTP logging, detailed errors, and failed-request tracing; HTTP logs are limited to 35 MB and seven days. Built-in App Service authentication and client-certificate requirements remain deployment-specific. Secret values are not accepted as Terraform input; application secret settings are Key Vault references.
- Function storage uses managed identity and private endpoints. Its identity receives storage data-plane roles scoped to the storage account; adjust the role set if the Function runtime or extensions need fewer permissions.
- Storage enforces HTTPS/TLS 1.2, disables shared-key authentication and public blob access, and enables blob/container soft-delete and versioning. State storage separately uses private blob access, Azure AD backend auth, versioning, delete retention, and 30-day queue request logging.
- High-priority alerts use Action Group email receivers. Populate valid environment-specific recipient addresses; an empty recipient list creates alerts without notifications. Keep alert recipients and identity IDs environment-scoped and review Azure RBAC assignments regularly.
- Terraform state and plan files can contain sensitive infrastructure metadata. Restrict access, retain plans briefly, and never commit state, plans, credentials, or secret values.

## Email provider

The Function App module does not create an email vendor account or an unverified Communication Services domain. Configure the application integration with `function_app_settings` and Key Vault references (for example provider name, endpoint, sender, and an API-key secret setting). The application code must implement the selected provider. For Azure Communication Services Email, provision/verify the domain and sender separately, then grant the Function identity only the required Communication Services role.
