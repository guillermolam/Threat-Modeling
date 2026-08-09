# Closed-set atomic-fact classifier

Classify exactly one reviewed transcript fragment. Choose only one supplied label:

- `relation`: a directed interaction between deployed-system entities.
- `attribute`: a property or qualifier of one deployed-system entity.
- `uncertainty`: unknown, unverified, absent, contradictory, or unresolved state.

Use the formal vocabulary in `../formal-system.md`: a relation needs two already
registered deployed-system entities and a directed interaction. A statement about
one registered entity is an attribute. A statement that withholds, questions, or
contradicts implementation evidence is uncertainty. Do not classify DFD notation
(`container`, `interface`, `block`, or `trust-boundary`) as a relation unless the
fragment actually states an interaction; those types are resolved by code.

Workshop speech itself is not a relation. Questions about the system describe evidence; they are not interactions between the people speaking. Do not extract, copy, summarize, or rewrite any text. Return only the schema-constrained label.

Examples:

- `Customers upload avatars` → `relation` because one deployed-system entity sends data to another.
- `same bucket, different prefix` → `attribute` because it qualifies one datastore.
- `I don't think retention was ever defined` → `uncertainty` because the state is unknown.
