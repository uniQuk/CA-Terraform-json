resource "azuread_conditional_access_policy" "Block access to Office365 apps for users with insider risk" {
  display_name = "Block access to Office365 apps for users with insider risk"
  state        = "enabled"

  conditions {
    client_app_types = ["all"]

    applications {
      included_applications = ["Office365"]
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
