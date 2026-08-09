# SOURCE-AUDIT.md — threat-modeling skill (VENDOR_SKILL)

Scope: Part 1 §1 "Inspect the source before copying" only. No packaging, chmod, or
smoke test was performed in producing this file.

Audited path: `.cowork/vendor/threat-modeling/`
Audit date: 2026-08-09

## Version

```
3.2.0 (20260512a)
```

Consistent across VERSION, SKILL.md header, WORKFLOW.md header, and the shebang comment
in every scripts/*.py file.

## Required-file presence

| Required item | Present | Notes |
|---|---|---|
| SKILL.md | yes | 22,469 bytes |
| WORKFLOW.md | yes | 15,192 bytes |
| VERSION | yes | `3.2.0 (20260512a)` |
| phases/ | yes | 9 files: P1–P8 + P8R (see below) |
| scripts/ | yes | 5 files (see below) |
| knowledge/ | yes | 22 top-level entries incl. `security_kb.sqlite` (8.4 MB) and `security-controls/` (21 md files + `references/` subfolder) |
| assets/ | yes | `assets/contracts/data-model.yaml` |
| references/ | yes | 3 files |
| kb | yes | executable bit already set (`-rwx------`), no chmod needed |
| skill_path.sh | yes | executable bit already set (`-rwx------`), no chmod needed |

phases/ filenames: P1-PROJECT-UNDERSTANDING.md, P2-DFD-ANALYSIS.md, P3-TRUST-BOUNDARY.md,
P4-SECURITY-DESIGN-REVIEW.md, P5-STRIDE-ANALYSIS.md, P6-RISK-VALIDATION.md,
P7-MITIGATION-PLANNING.md, P8-REPORT-GENERATION.md, P8R-DETAILED-REPORT.md.

scripts/ filenames: module_discovery.py, phase_data.py (only one with +x set already),
report_generator.py, stride_matrix.py, unified_kb_query.py.

**Present but not on the Part 1 §1 required-file list** (carried over by the plain rsync,
will also flow into the packaged ZIP under Part 1 §2 since that step only excludes .git,
.DS_Store, caches, and generated output): `CHANGELOG.md`, `LICENSE`, `README.md`,
`README-cn.md`, `docs/` (8 design docs, EN+CN), `agents/openai.yaml`. All inspected;
none contain credentials, URLs beyond the project's own GitHub link, or executable content.
`agents/openai.yaml` is a 7-line cross-runtime interface declaration
(`display_name`, `default_prompt`, `allow_implicit_invocation: true`) — no network config.

`--help` output confirmed for both required commands, exit 0 in both cases:
- `python3 scripts/phase_data.py --help`
- `./kb --help`

## SHA-256 manifest (151 files, `.DS_Store` excluded)

```
724559a48d04aa8fc68401a43b2980929486957488ec31810b200fd9dff55cf4  ./CHANGELOG.md
b533c35afa1e1ebaef3c32274782093926b4d269422c1fad86c2aa505d791b00  ./LICENSE
e538007b75353a31124ad1e3e849887890c6f627667cc835bba60a381ca46cdc  ./README-cn.md
964d7ee00f59ea6aff4cc8880680c315646f4a2091584090dbfc5d18c200f89b  ./README.md
057584885efcb47d1e8000a9d96bfeb6855b5baeebf0185d682b6e1f1a0a3f11  ./SKILL.md
0b953c2b32b70251256b0fe23e243d488189950c43383f5cd35c1f68812022aa  ./VERSION
ddc6337d5d61bb69b8cd60b3d927ce0920c15d4d43e66b76a4fce8061383a864  ./WORKFLOW.md
912683ddeaf7f8548841bff06f607a47fe22f26924b4a66bb49b3c1730df47f9  ./agents/openai.yaml
bb8db3afe8ce70ebda46c4a9632acb5b119e8b6180dab519b51dcd58ccd1fc9d  ./assets/contracts/data-model.yaml
8a4f2d79eaf788fb4cc9fa4c3827bbcdba361c219f00c6d5d2b51ec1e2cdbca4  ./docs/ARCHITECTURE-WORKFLOW-GUIDE-cn.md
ca471cd99ab598c6e1e230c68ec7adb0338ff49116fa7c6368660bef0afad9ee  ./docs/ARCHITECTURE-WORKFLOW-GUIDE.md
75e9a76d762dc329ce6cdddf027d9a77663c686577c71e460a86cfb031257110  ./docs/KNOWLEDGE-ARCHITECTURE-v5.2-cn.md
4da148fbcd64e7a579156023342a7070b700467551707380341b4d20e35e9004  ./docs/KNOWLEDGE-ARCHITECTURE-v5.2.md
4c7348735918a374a6b73b94507c8d9b7bc8e8029dbaad6d2115a33ef533fafd  ./docs/REPORT-DESIGN.md
3b00aa60a1fab10272803b396b015a07d3a44e385f7f089cd72454ff32558895  ./docs/SKILL-ARCHITECTURE-DESIGN-cn.md
36ab649a908f3018adf112bdfd0cf100096c734f48d141b16fd27520e1fcaba4  ./docs/SKILL-ARCHITECTURE-DESIGN.md
255e17fd260925444d106ab081ce4d01254efc1489b173ba7e8b90e0715ded6c  ./docs/Skillset-threat-modeling-tour-cn-v5.md
76280cc8c1be99327a8f817c34826035ce3e8176734a92b84e95f67039711cb4  ./docs/Skillset-threat-modeling-tour-v5.md
8c51ab19d6dfbecb854ac26b9efb85d69cd43a9986a62c52d5fe698903c2733e  ./kb
ea5ae3a3aae2482a9a53b3270a3672f99067d3112ae4c16740ac683a2e405f22  ./knowledge/agentic-threats.yaml
00ac1be2c9ea84f51956d5fc54124eb8f35f78ea9a03f981d7648f84ca71e7df  ./knowledge/capec-mappings.yaml
c02b7a9740bac41eeefcd128c700c3c8f9f881ed76e512bae3690b94680455ee  ./knowledge/cloud-services.yaml
ea7e27940511a34f22be05f67ee5a7a5277b0c72e33a5c20514b973289ec865c  ./knowledge/compliance-mappings.yaml
e0c2bc526a00f9da61679f53d9d50af1adff3e067cae8260a93939e2805b37f9  ./knowledge/comprehensive-mappings.yaml
d02affbb4a2e2b6bb670814e9cf78065669964f139d885226a3a6297e814f960  ./knowledge/cwe-mappings.yaml
843319ab2300ae3d28ebc92118446f5e07c9379ee2c42792ee71b1b10f07ea79  ./knowledge/llm-threats.yaml
853eb562ce82d11ff46cd9300ab937935c884891256bff02f4875e888c329475  ./knowledge/owasp_cwe_mapping.json
3bd664225636ee9d2543b0150f13c0c475c4cb51ae080b3fb0c736f1a88ca1cb  ./knowledge/phase2/completeness-rules.yaml
a0a2388d415576dff6fe2738ba195c5f9e4adead4eea0d82b907ccfea387b34e  ./knowledge/phase2/data-store-patterns.yaml
ebcf6cfdd8419a3808fa8f7270c0aa0db16f3ffaa02f56670de173a4092a5896  ./knowledge/phase2/framework-routing-patterns.yaml
049e37fd8758886eda3b81d1a5c45f136776e0f65b13ed2b3cab73c102d8279a  ./knowledge/phase2/security-checkpoint-patterns.yaml
9d84872d8f2efe3b937926e808af6f1ac93a15b9af3919e57bf9172d34c37818  ./knowledge/sast-rules.yaml
3f73592b9a5453209e8e107a24e4534d7ad43b3b32764214d1e7582bf2ef26f8  ./knowledge/secure-coding-rules.yaml
e3fec1828ea93e8bb55003f5044e6dcea7b24faecd2cb2cfbb627cc72aee8f93  ./knowledge/security-controls/control-set-01-authentication.md
f4716229fafe7045b1514abd31e5627c87eb4b0b43a5baf17019a5f0dde3534d  ./knowledge/security-controls/control-set-02-authorization.md
e5dc964f2ed65ff667870e0e86d3b8752c78dc1b54aa002b7b11c678f3f39db7  ./knowledge/security-controls/control-set-03-input-validation.md
18bbba95dff524e215f9e7a9df4255113688e4d754fdb59b37799ba20c43848c  ./knowledge/security-controls/control-set-04-output-encoding.md
ac72b12a7a6839c4058f6ae6ec043511180f2829e7f50276aaa13525990ab5d1  ./knowledge/security-controls/control-set-05-client-side.md
02ab48f934510309f0cda1ef21d830ed0f72733ed275204bd90da8baec27eb76  ./knowledge/security-controls/control-set-06-cryptography.md
d3ca326446e20d7af71fede79ab8c8cfc5eeaf32aae18673ae9b46000f98e1a9  ./knowledge/security-controls/control-set-07-logging.md
ebb8559c131fdba45580800c0a478c7b1babbc0e5638c650ba03f954e79051f8  ./knowledge/security-controls/control-set-08-error-handling.md
831b2e193cfc15150946911d95814038473c3e826c0248867c90b1d4751e1ada  ./knowledge/security-controls/control-set-09-api-security.md
0f0d12a5c91db2f5bf527cea9210baaa54af8cf451b9a51f320187985b2b6aa6  ./knowledge/security-controls/control-set-10-data-protection.md
0c437ba8d24cb181964ee7a59fee73f0e6b5431344099c0e2b126fea1ab405d4  ./knowledge/security-controls/control-set-ext-01_02-auth-patterns.md
27e9a26367318e1d794473f221aa2825be831bace9d7f2c6cd1a140eb3f414c5  ./knowledge/security-controls/control-set-ext-10-hardcoded-credentials.md
870e9cf1acb1182aa528022c8c8cf9eb7ccbc9defa303cb0c6015b21a937d1ed  ./knowledge/security-controls/control-set-ext-11-infrastructure.md
cca158c959a8cf1b22da15561ec4bc2d4d13e337d9a221a4910c7dd6a92bfb77  ./knowledge/security-controls/control-set-ext-12-supply-chain.md
2cb4fc376cf56126e3bb2a0e42c49a908dd5742acf51dc30300a6763524e4ed2  ./knowledge/security-controls/control-set-ext-13-ai-llm.md
40f0e189e29712acfcc8aafe97c7cb9053e23337b6311904bc3ae90a2ddf3fc3  ./knowledge/security-controls/control-set-ext-14-mobile.md
87060b6f4c202aa1b6984927c41c57539e6f21b943cfc27d202f3ddc58e96637  ./knowledge/security-controls/control-set-ext-15-cloud.md
b3373c0b5c54e10866f43fb021c5029147e96b254045e4f26ceaebe6a588351c  ./knowledge/security-controls/control-set-ext-16-agentic.md
c4229cdbb386c011c52d118a55cf13c80eeed4dccf3c7c8796b1ea82f385f0e5  ./knowledge/security-controls/references/reference-set-01-authentication.md
2cc73338b4fce284af0a2fe5b69c3139ecbaa28177a8800bdf5e3e13d3ad966e  ./knowledge/security-controls/references/reference-set-01-cookie-theft-mitigation.md
5293c6887811efd74c4da26d12357784106a121825a4ae8929c3798f79e64e8d  ./knowledge/security-controls/references/reference-set-01-credential-stuffing-prevention.md
4ab45b21ad8d0f43fbbabaca71ba4dd124237ae29fb73a68f2567e3d75debb55  ./knowledge/security-controls/references/reference-set-01-forgot-password.md
0dd3e0a747c5707494f2c59f43b39b8109cd7073492c3429645c4e8b8ec9b02c  ./knowledge/security-controls/references/reference-set-01-jaas.md
a103d5b1cd83868902b15fae5b3d68a95c388ad96ea6c682906206084d2762a7  ./knowledge/security-controls/references/reference-set-01-jwt-java.md
0789aa0002e0016aa8fce9107a8cf08f442743c5932e440b474174d8fcdb8921  ./knowledge/security-controls/references/reference-set-01-multifactor-authentication.md
11b3991ba5b032d5168591b5a3abbe20937f4e1a172a5441c297b81b81c69ff7  ./knowledge/security-controls/references/reference-set-01-password-storage.md
61aa62804dc65103d5cf38074c2fb55a554f0c28545b519a4000a69b375092cc  ./knowledge/security-controls/references/reference-set-01-saml-security.md
da416afd41299e4ceac55ab2955bf502303713221e28bd11a1291efa256156a6  ./knowledge/security-controls/references/reference-set-01-security-questions.md
e74bdd35de15e365e448796dbc9480b8ed95ee2514cd21db833746cb0985becc  ./knowledge/security-controls/references/reference-set-01-session-management.md
fd86edce55fc3f736b857851a60ec692fa6c3dec77b35c3817ca79ce998f927c  ./knowledge/security-controls/references/reference-set-02-access-control.md
3d3bdf380a271e09f3d5e292234fc9bf58d22480900f70782c8dab1418139708  ./knowledge/security-controls/references/reference-set-02-authorization.md
94d2ed3bfe9582a6d9f935d5c435ad7291a988fb6b1a2bca3e3852fea50fb91a  ./knowledge/security-controls/references/reference-set-02-idor-prevention.md
d4e149d0c0603e61e0133d8eb19fb04abf85258a474b99e48c61ae5be2506c9c  ./knowledge/security-controls/references/reference-set-02-transaction-authorization.md
a58a3291accf5fce8a55dc70790d5d380892f9776a505a7f458dc24b7f944fe9  ./knowledge/security-controls/references/reference-set-03-bean-validation.md
283b167bd52051801d6720e48fe4cf7cb179fb4cd9aebf3ee78508d5051c2a11  ./knowledge/security-controls/references/reference-set-03-deserialization.md
f5431c1a311ccfdc52fa9cd9dd8ebdb61caf4ad10e24506cf3820605e74a4732  ./knowledge/security-controls/references/reference-set-03-file-upload.md
627c110a83c76a161f607ce67719ba80b7443a0c92ac00ab24ef15d5d473a805  ./knowledge/security-controls/references/reference-set-03-injection-prevention-java.md
07a8558ecfd5833b10ae1180d1a76eddce4e37334765ebf2c5389c620cc69bb6  ./knowledge/security-controls/references/reference-set-03-injection-prevention.md
ea124551d554992d881dd722bc6349d83fc14da71852c7ca979ebb8405e6cdd3  ./knowledge/security-controls/references/reference-set-03-input-validation.md
ff4bf336e94797ca7f00f30275b79213589537ed71d57935440425263e6b552f  ./knowledge/security-controls/references/reference-set-03-ldap-injection-prevention.md
eacb735598acde6b52df63b49c03b33893d5f12a5c2a31be11a0a33c6c644736  ./knowledge/security-controls/references/reference-set-03-mass-assignment.md
224b12553bd7f5e477342a7422b09030bed764e14eb05a6e7854470ffe315f0f  ./knowledge/security-controls/references/reference-set-03-os-command-injection-defense.md
87f4396cb8c3bd310481f7912ba0a635789cad991c62c62ce062e63c1cc04f07  ./knowledge/security-controls/references/reference-set-03-query-parameterization.md
010e4b3df9e1b689788bc435c0589fa6b6b53d2c201a63fe845c738e12655e97  ./knowledge/security-controls/references/reference-set-03-sql-injection-prevention.md
56e1ac70e008a293016bceb9a9db34e182f1d981605cdd85cc42b811ec64a2d5  ./knowledge/security-controls/references/reference-set-03-ssrf-prevention.md
9574dc62fb100b0620f6f8f9dfff3f7c6f54be9309659bc4ce8f1b3f5e7eca0d  ./knowledge/security-controls/references/reference-set-03-unvalidated-redirects.md
233fd97364a6e5165d3e5eef6508c3c70997a915c33b251d268c78f64e2d6b10  ./knowledge/security-controls/references/reference-set-05-clickjacking-defense.md
045d54c65812f9456913295daa49f64aacd768efc4183a5ccd2422d1985be325  ./knowledge/security-controls/references/reference-set-05-csp.md
2bf6219c2d4cb91a1d7cfd00cfb736d08d1b0af8eb02501545da10af1975ac1b  ./knowledge/security-controls/references/reference-set-05-csrf-prevention.md
39c9043deb76e30b0876c9171da8a811aa9e5bb56adda3b65e376b060461d08a  ./knowledge/security-controls/references/reference-set-05-css-security.md
cf80b46f1635bc9050e9a559c0794ae4da2634d6189bd2c3da74a1348b17f9ff  ./knowledge/security-controls/references/reference-set-05-dom-clobbering-prevention.md
f3db11d5d81176d7dff0d8d7954a724c30d76af7216a8a72d0f8a5ecadb4b949  ./knowledge/security-controls/references/reference-set-05-dom-xss-prevention.md
1a6b726c2c32c0378dd85073d7b9d98059bea56ee67b3d54cc21fdd2d962c0a6  ./knowledge/security-controls/references/reference-set-05-hsts.md
8835de3b9e8a3d3d38a5501b4d324a5146488aa105c5167fee1297d0227937bc  ./knowledge/security-controls/references/reference-set-05-html5-security.md
a084c415f3538c36342ccef02bc2c0ee9755b19762cd19d76fad3b2186b4852e  ./knowledge/security-controls/references/reference-set-05-http-headers.md
d08c3cf538dc51a38128ae5df63c52507a3d051da6b3c3fb71a55a87d7d49bb8  ./knowledge/security-controls/references/reference-set-05-prototype-pollution-prevention.md
f9dd10c041fdbbeb1c23abee1e9646b5901f0e3b583b119c29e795955fac3960  ./knowledge/security-controls/references/reference-set-05-third-party-javascript.md
b51044a09f99691ce8d9c7886f0e616daecd0f0ed124df6bc5f0b4a7bbd2f86c  ./knowledge/security-controls/references/reference-set-05-xss-filter-evasion.md
12bc2038038f608ff5e14e63dff63ab0ca6d482b88bf13e43b875e775c5ca7b4  ./knowledge/security-controls/references/reference-set-05-xss-prevention.md
74e1532e8cdf8ee73b5dd3eb9da65403c1a41b2eadab43caa584885e0c8dfb1f  ./knowledge/security-controls/references/reference-set-06-certificate-pinning.md
43bcd011be3b0307a4fc5691927f48f1c62391910c1c45bc23c0c323e1fe7efc  ./knowledge/security-controls/references/reference-set-06-cryptographic-storage.md
66a6ec752b2c636a90491b7a3fe43bb56bcbb85d5aaf7c3882cfeca32c9a2a75  ./knowledge/security-controls/references/reference-set-06-key-management.md
62085bdfb8f61085ad392faff78326fccdf66e2c0664f4cffb5269fa744ecb6f  ./knowledge/security-controls/references/reference-set-06-tls-cipher-string.md
7a4900991ae692864cec8047530b2243cc8668c3c0214322f650c33905fd6d39  ./knowledge/security-controls/references/reference-set-06-tls.md
613f6bea6142fffebfbfe02ffd20cd5480f25f604f447f9a7fcd2ac15f5f1491  ./knowledge/security-controls/references/reference-set-06-transport-layer-protection.md
2eed141c06b784b94fa3f274ff988b480648d5e885a5455de7cbf76f777bf068  ./knowledge/security-controls/references/reference-set-07-logging-vocabulary.md
4d839188526dfe2b5f68ae294ef29c150ef9eeb978410a68ad3dd65b1ba76fd5  ./knowledge/security-controls/references/reference-set-07-logging.md
d2872a4951c02659f7c4f848111b7552a2359c83c453aae07840d7c8d3e9f70f  ./knowledge/security-controls/references/reference-set-08-error-handling.md
b6990cf1420601f8ccf4c0daee56129a0875f073fd119eaf2fe94fa085be0f32  ./knowledge/security-controls/references/reference-set-08-xs-leaks.md
30593aad9670f103decb1a611b377d949d3b537b6f489009ec629660ab1e3843  ./knowledge/security-controls/references/reference-set-09-ajax-security.md
d167dd2b72225a493699b9d1dc8f32f96b40618e13aa70a71729acc37d8e36ff  ./knowledge/security-controls/references/reference-set-09-dos-prevention.md
3cd4ee8746ef4cb5d2d6a0aa210b8d998b691adc89dbe38ad6e3b56d3d963e44  ./knowledge/security-controls/references/reference-set-09-graphql.md
8a151c6122635a736e4cbdc13841eaf388b3f1f49ebaf2ac561525301d36ebd9  ./knowledge/security-controls/references/reference-set-09-microservices-security.md
0150e7b2402258944af4c4e4ec3da5447618af9983f56363aa858ecab49ce058  ./knowledge/security-controls/references/reference-set-09-rest-assessment.md
f4220211ad7d05df269c25daa95213312d4b69557725cd137e72cf8e9b647329  ./knowledge/security-controls/references/reference-set-09-rest-security.md
c03521b2e0999cb13287227cd4d481cd390a3670e93fdd056fbf150384318e26  ./knowledge/security-controls/references/reference-set-09-web-service-security.md
826ffc0e2d615c27cc26cd63c913724b6e420afc9ffd13d61ecaff0794154761  ./knowledge/security-controls/references/reference-set-10-database-security.md
79a2c0a00e41e4024eca41d76340a21963ed8f27993e57b90216585a7490d6da  ./knowledge/security-controls/references/reference-set-10-secrets-management.md
85311158650104497d5e62b799f3d52c7b6c81b4e0dd921a5a7072d837f265fb  ./knowledge/security-controls/references/reference-set-10-user-privacy.md
3ee740f9ed62d2e5a81cbb6d1bb1d091ce31aef88f2175e0ba79270f8f190d1f  ./knowledge/security-controls/references/reference-set-ext-11-docker-security.md
722cc6beec1fb887f74a225f19442035b5a015aaca3baa1cfee7c382e6dca79a  ./knowledge/security-controls/references/reference-set-ext-11-iac-security.md
aea24d6b8668e21d92a3e0f8b0593ce927ae84382d2497b609984c53a2d49daf  ./knowledge/security-controls/references/reference-set-ext-11-kubernetes-security.md
2ece6670534680533e4341fd77b36f9a42843c2706dd2d4c1499d91bdc0de540  ./knowledge/security-controls/references/reference-set-ext-11-nodejs-docker.md
0a5ab1502f12ece1a3a22d0414b6ba421dfad73cceacd5b428c2a4a6437797bd  ./knowledge/security-controls/references/reference-set-ext-12-cicd-security.md
4adedf1693ffaf3541b5625a1d345f43f7e88a70a073567704c195b993ebc19f  ./knowledge/security-controls/references/reference-set-ext-12-dependency-management.md
cb319250f4fdb147658f199607cd2c834910329e1f7d34c956dec57bf3e24261  ./knowledge/security-controls/references/reference-set-ext-12-npm-security.md
a34cc8b7c338dd165334314aa99516fde581242c4f17c091f2f3a97e8546e250  ./knowledge/security-controls/references/reference-set-ext-12-supply-chain-security.md
bd5e3406dd8979cafff744dcf8da911ed2eca1e3f31afd37e51ea9f09d072e38  ./knowledge/security-controls/references/reference-set-ext-13-ai-agent-security.md
f4a402197e83471c027c309c75b13d32630473618cfcb0148de370ee90d00e56  ./knowledge/security-controls/references/reference-set-ext-14-automotive-security.md
b110f306f35b9a2163c3f52e2255813caae0e3f8f4987d80a80a340f218de533  ./knowledge/security-controls/references/reference-set-ext-14-mobile-security.md
30cd512a98f2218785d26edab596411b1de86c506678d80add84236eb3b4bd13  ./knowledge/security-controls/references/reference-set-ext-15-cloud-architecture.md
da998c7f06c076fa693ec9170d4dea31695b4573993bce25a958e50ebaa7e85f  ./knowledge/security-controls/references/reference-set-ext-16-agentic-security.md
280e28e91947136a22c7163a228f2162ffa4ffef2b2ccf8782b5df01bb32e685  ./knowledge/security-design.yaml
dc3f7a8acb85bca3166f92fd8227e01a0c8f773f79e1c2f6f76cae9dc9bdf811  ./knowledge/security-principles.yaml
43046699c5c05a2caa619e0c95e7855868f34265a35571efbbb7a278fa7e396b  ./knowledge/security_kb.sqlite
341d54b737f0fe50024fad8188e842898597483bdd119bd20336e506b0a66aee  ./knowledge/stride-controls-mapping.yaml
3ea2edf106f909bb2f45587b424dbe78f94d12013ccee03cc41b4d5e2cb60195  ./knowledge/stride-library.yaml
ef9a6377663be63835ee6cb681e8f293d0838c0570f60ab5d680765040845b9a  ./knowledge/stride_cwe_mapping.json
9df707230e67a0bc22f2531cd0c156c5298f3e7f57883780e0cdaedfd43f077b  ./knowledge/tool-capabilities.yaml
a1bd16a7fbdaf07ce7a6b5ceb78538cc5500c6d4f1c0989ad36eddb3630de336  ./knowledge/verification-mappings.yaml
c50ae7167e0abbb35a3c2989f943dccb39c85f9e5bc3c5c8ebf9605710decf92  ./phases/P1-PROJECT-UNDERSTANDING.md
eccb9923f39bc9c4f5749a6292db428635440d127bb49cbedaf64618bd147070  ./phases/P2-DFD-ANALYSIS.md
1a9f38fa3c04199962e32e25757accf72fa3ef537e2bdb737962ecb401533efb  ./phases/P3-TRUST-BOUNDARY.md
05e354c41bdcb48958942365c1938ce5baf503dea3d360b9377848695c355ae2  ./phases/P4-SECURITY-DESIGN-REVIEW.md
dd15333bd8f9cdbcb4b1acaa588a4114c1e1f6af61226c428d913b2f351d41e5  ./phases/P5-STRIDE-ANALYSIS.md
a8bbb43f6b073ae640dcdc45e5e32c5e56b5d4f680545de23292f5397402223d  ./phases/P6-RISK-VALIDATION.md
694ae8737b7b23b37f0bba2932dd51ee3cfc54b5c53abd6e7a0ae934f482ab88  ./phases/P7-MITIGATION-PLANNING.md
9d39d3caa11ded0f4ee3957660abbd0293882515432632a9b0341ab14d4ca0a0  ./phases/P8-REPORT-GENERATION.md
7587af8a3e7807e28208116b57a3978112fe2531d77e4d696985ce4e625dd4a4  ./phases/P8R-DETAILED-REPORT.md
9bd5930c1dace7e0c6e6066fc401cf2e5cd55fb1ab648f0b59a2376ff4a45aa2  ./references/binary-analysis.md
74149127f5880ab068e02383891da19d7e5782a4886cd9dab63e5649871ff879  ./references/complex-system-analysis.md
e48a348cf13a633fac7668ef933566966a88f346783ba39a8c323ee8a25bd664  ./references/tool-integration-guide.md
2bb3861a3c36f4c8b1cadf2cd3cd5e438494e79db7e5c0f5bfbcf833991e608e  ./scripts/module_discovery.py
cfc43cc3192dd52e05ad731b842b12ed1cc1029f96c9bf41f4abf17fc2f0053a  ./scripts/phase_data.py
7694afb9ef9f3349221c63874e618b582611db664d8da048357c274d1898988e  ./scripts/report_generator.py
f6a86c6e7eb55e705030ae465b5eeff342b4bab99b6b3fb1453441fbd75e8694  ./scripts/stride_matrix.py
d50a71e4e05502b6d5791cbb96e6d846806d29bd9434b1c792f66d49feb38682  ./scripts/unified_kb_query.py
c18d9616a0127de317c20a55315573e8968d5ff0a20052cfb1f3b6ed4711c47c  ./skill_path.sh
```

## Documentation / runtime discrepancies

1. **`.phase_working/` location — WORKFLOW.md disagrees with SKILL.md and the actual
   script.** WORKFLOW.md §1.2 "Directory Creation" shows:
   `mkdir -p ".phase_working/${SESSION_ID}/data"` — a path relative to the current
   directory with no `Risk_Assessment_Report/` prefix. SKILL.md §2's directory-structure
   diagram, however, nests `.phase_working/` inside `Risk_Assessment_Report/`. I checked
   the executable source (`scripts/phase_data.py`, `get_phase_working_dir()`):
   ```python
   def get_phase_working_dir(project_root: str) -> Path:
       return Path(project_root) / "Risk_Assessment_Report" / ".phase_working"
   ```
   This confirms SKILL.md's diagram and COWORK-SETUP-PROMPT.md's Part 1 §1.5 assumed
   runtime paths (`Risk_Assessment_Report/.phase_working/...`) are correct. WORKFLOW.md's
   §1.2 code snippet is the stale/incorrect one — per the "executable behavior is
   authoritative" rule, ignore that snippet if writing orchestration logic against it.

2. **NVD live-network path exists but is flag-gated, not default.** `scripts/unified_kb_query.py`
   contains an `NVDClient` class that calls `https://services.nvd.nist.gov/rest/json/cves/2.0`
   via `urllib.request`. It is only instantiated when `--nvd-cve`, `--nvd-cwe`, or
   `--nvd-api-key` is passed on the command line; `--check-kev` uses a separate, local
   `check_kev()` method with no network call. Confirmed `--help` on both `kb` and
   `phase_data.py` exits 0 without reaching any argument-dispatch branch, so no network
   call occurred during this audit. Flag for Part 2/3: the folder instructions' "no
   external scans, live exploitation... network POCs" rule should explicitly name
   `--nvd-cve`/`--nvd-cwe`/`--nvd-api-key` as out of bounds for training runs, since
   they're the one code path in this package that talks to a real external service.

3. **SKILL.md description contains directive language plus CJK trigger keywords.**
   The YAML frontmatter says "MUST be invoked instead of analyzing security yourself"
   and lists Chinese trigger phrases (威胁建模, 安全评估, etc.) alongside the English ones.
   This is legitimate given the skill's documented `--lang=zh` support, not a hidden
   injection vector — but it's exactly what Part 1 §2.3 is written to strip, replacing it
   with the shorter, neutral, English-only upload description. No action needed here;
   confirms that step in the plan is doing real work, not busywork.

4. **Current executable-bit state**: only `kb`, `skill_path.sh`, and `scripts/phase_data.py`
   ship with `+x` from the source. `module_discovery.py`, `report_generator.py`,
   `stride_matrix.py`, and `unified_kb_query.py` do not yet have `+x` — Part 1 §2.4's
   planned `chmod +x scripts/*.py` will not be a no-op when that step is actually run.

No execution-critical references were found unresolved in this pass (full reference
validation against `phases/*.md` is Part 1 §2.5 — packaging — and was not run here).

## Part 1 §2 — Package build results

Scope: `.cowork/package/threat-modeling` built from the audited vendor tree above.
No smoke test, folder-instruction install, ZIP upload, or skill invocation was performed.

- **Copy**: `rsync -a` from VENDOR_SKILL to PACKAGED_SKILL, excluding `.git/`,
  `.DS_Store`, `__pycache__/`, `*.pyc`, `.pytest_cache/`, `.phase_working/`,
  `Risk_Assessment_Report/` (none of the last four were present in the audited tree —
  confirmed by a pre-copy `find`). `diff -rq` between vendor and package showed zero
  differences before the description edit, confirming a byte-identical copy.
- **Description replacement**: packaged `SKILL.md` frontmatter description replaced
  with the exact upload-safe text (157 characters, under the 200-char limit). `diff`
  against the vendor copy confirms this is the *only* change to SKILL.md — every other
  line, including the "MUST be invoked..." language elsewhere in the body and all
  section content, is untouched. `skill_path.sh` was not patched.
- **Executable bits**: `kb`, `skill_path.sh`, and all 5 files under `scripts/*.py` are
  now `-rwx------` in PACKAGED_SKILL. VENDOR_SKILL was re-checked afterward and is
  unchanged (only `phase_data.py` still has `+x` there, as recorded in the original
  audit).
- **Relative-path validation**: extracted every `@path` reference from SKILL.md,
  WORKFLOW.md, and phases/*.md (15 concrete paths + `@phases/P{N}-*.md` /
  `@phases/P{1-8}-*.md` wildcards). All 15 concrete paths resolve inside PACKAGED_SKILL.
  The wildcard resolves for N=1..8. **Zero unresolved execution-critical references.**
  Package validation: **PASS**.
- **ZIP**: `.cowork/dist/threat-modeling-3.2.0.zip`, built with Python's `zipfile`
  (paths written as `threat-modeling/...`, run from inside `.cowork/package/`). Verified:
  151 entries, single top-level directory `threat-modeling/`, no `.DS_Store` or `.git`
  entries, executable bits (`0o700`) preserved in the archive for `kb`, `skill_path.sh`,
  and all `scripts/*.py`. Size: 3,185,419 bytes.

**ZIP SHA-256**: `dfcde11ce2ce5723b8e2666d51eac16ca46ebe8818cb9aa8c61d2f75edeafa69`
