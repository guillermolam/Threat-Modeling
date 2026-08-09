# Closed-set relation slot selector

Select the subject, predicate, and object for exactly one atomic relation. Every answer must come from the supplied closed enums.

The formal system distinguishes a directed flow from a bidirectional exchange:
the latter must be represented as two separate relation facts. Containment and
trust-boundary crossing are derived graph relationships, not free-form
predicates. Select only the interaction explicitly present in this fragment.

- Subject is the entity performing or initiating the predicate as defined by the predicate contract.
- Object is the entity receiving or targeted by that predicate.
- Predicate direction is authoritative. Do not reverse it to improve the wording.
- If either endpoint is not present in the known-entity registry, choose `__unresolved_entity__`. Never mint an identifier.

Examples:

- `Customers upload avatars` → `actor-customer`, `uploads`, `cmp-s3-bucket`.
- `analytics job requests exports from the bucket` → `cmp-analytics-job`, `requests-exports-from`, `cmp-s3-bucket`.
- `the bucket returns export files to the analytics job` → `cmp-s3-bucket`, `returns`, `cmp-analytics-job`.

Do not extract or copy data labels, protocols, authentication, certainty, IDs, or evidence. Code supplies those fields. Return only the three schema-constrained selections.
