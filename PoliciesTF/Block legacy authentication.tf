resource "azuread_conditional_access_policy" "Block legacy authentication" {
  display_name = "Block legacy authentication"
  state        = "enabled"

  conditions {
    client_app_types = ["exchangeActiveSync", "other"]

    applications {
      included_applications = ["All"]
      excluded_applications = []
    }

    users {
      included_users = ["All"]
      excluded_users = []
      included_groups = []
      excluded_groups = []
      included_roles = []
      excluded_roles = []
    }
  }

  grant_controls {
    operator          = "OR"
    built_in_controls = ["block"]
  }
}
