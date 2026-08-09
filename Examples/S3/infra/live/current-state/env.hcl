# ---------------------------------------------------------------------------
# CURRENT STATE — the system as it exists after the session in 03.
#
# This is 04 §4.9 (L1-D) built for real: one bucket, three classifications,
# public policy, no versioning, no data events, an unverified deploy role, a
# compute tier nobody drew, and a partner who can reach further than intended.
#
# ⚠️  Every finding in Appendix A that can be expressed in infrastructure is
#     DELIBERATELY OPEN here. This stack exists so the findings are
#     demonstrable, not theoretical. Never point it at real AWS credentials.
# ---------------------------------------------------------------------------

locals {
  env     = "current-state"
  short   = "cs"
  posture = "vulnerable"
}
