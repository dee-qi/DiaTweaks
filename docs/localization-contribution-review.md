# Contribution review

Scope: feat/multilingual-support against main. Rules: CONTRIBUTING.md and .github/pull_request_template.md.

| Requirement | Result |
| --- | --- |
| One change per PR | One shared localization feature; upstream commits remain in main. No unrelated feature added. |
| Complete PR template | Draft: localization-pr.md. No PR has been opened. |
| Visible proof | Cropped before/after error-page screenshots committed; original screenshots were user supplied or captured locally. Transition/hover recording remains a submission gap. |
| Sidebar/top and tweaks on/off | 115 scenarios / 0 problems in each layout after adapter split; final class-name centralization also tested in the top run. |
| make/install/check/test | make, install.sh, make check and both live layouts passed; final results in localization-validation.txt. |
| Patch registration and isolation | No new DP_PATCH. Language selection is shared settings/runtime infrastructure, so the new-patch folder-only and .verify/.classes rules are not directly applicable. Existing patch keys and manifests preserved. |
| Files about 100 lines | Split 331-line native adapter by responsibility. Production localization files now have at most 99 lines. Catalog data and test cases are not patch implementation files. |
| Wiki and previews | No new patch page needed. scripts/check-tweak-docs passes for all 81 existing tweaks. Maintainer owns wiki/previews. |
| Conventional, lowercase, short commits | Historical title correction / removal of reverted signing experiment awaits user's history preference. |
| No attribution trailers | None in development commits. |
| No Dia bundle or third-party certificate | No new bundle binaries or certificates tracked. Static translation text and UUID/call-site compatibility constants only. Proof images are UI captures, not bundled assets. Existing upstream icon assets are unchanged. |
| Releases | N/A: no tag, release, push or PR publication requested. |

This is a readiness review, not a claim that every conditional Dia screen has been reached. Do not mark remaining proof or coverage gaps passed merely because a catalog contains the strings.
