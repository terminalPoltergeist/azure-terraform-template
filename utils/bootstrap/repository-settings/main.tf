# set some sensible default branch protections

resource "github_branch_protection_v3" "rules" {
  repository     = var.repository
  branch         = var.default_branch
  enforce_admins = true
  required_pull_request_reviews {
    dismiss_stale_reviews           = true
    required_approving_review_count = 1
    require_last_push_approval      = true
  }
  required_status_checks {
    strict = true
    # checks = 
  }
}
