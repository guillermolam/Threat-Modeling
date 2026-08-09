# ---------------------------------------------------------------------------
# TARGET STATE — 04 §4.10 (L1-E), the system as it should look.
#
# "Drawing the target state next to current state makes the remediation gap
# concrete and gives you something to verify against later."
#
# What changed and why (04 §4.10):
#   - three buckets in three accounts        → blast-radius containment
#   - scan-and-re-encode gate before UGC     → kills F-12
#   - CMK + Object Lock + versioning         → kills F-11, enables the F-07 fix
#   - conditional pinned reads               → kills F-07
#
# ⚠️  ACCOUNT SEPARATION IS THE ONE THING THIS LAB CANNOT EMULATE.
#     Floci is single-account. Three buckets with three CMKs and three role
#     sets gets you the policy separation and none of the account boundary.
#     See infra/README.md "Emulation gaps" — do not read a green run here as
#     evidence that the containment design works.
#
# Sequencing follows 13 §13.5: versioning → CMK → key policy → lifecycle →
# Object Lock → MFA Delete. Terragrunt's dependency graph enforces the first
# four; the last two are documented in scripts/mfa-delete-breakglass.md.
# ---------------------------------------------------------------------------

locals {
  env     = "target-state"
  short   = "ts"
  posture = "hardened"
}
