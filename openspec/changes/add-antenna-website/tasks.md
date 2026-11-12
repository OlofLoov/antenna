# Tasks

## 1. Site files and publishing

- [ ] 1.1 Add `Web/.well-known/apple-app-site-association` with the placeholder app id and one `/setup` component; `WebsiteTests` checks its JSON shape
- [ ] 1.2 Add `Web/CNAME` and `Web/.nojekyll`; `WebsiteTests` checks the CNAME matches the host of the app's legal links
- [ ] 1.3 Add `scripts/publish-web.sh` that copies `Web/` and fills the team id, failing with no id or a malformed one; `WebsiteTests` runs it three ways
- [ ] 1.4 Add `.github/workflows/pages.yml` that runs the script and deploys to GitHub Pages on pushes to main touching `Web/**`; `WebsiteTests` checks its trigger

## 2. Legal pages

- [ ] 2.1 Write `Web/terms/index.html` from what the app does, with the sections the spec lists, a "Last updated" date and a link to the Privacy Policy; `WebsiteTests` checks headings, phrases and the link
- [ ] 2.2 Write `Web/privacy/index.html` the same way; `WebsiteTests` checks headings, phrases and the link
- [ ] 2.3 Style both pages after the setup page with a light-mode block and a phone-width column; `WebsiteTests` checks the viewport, the light-scheme block and that nothing else loads
- [ ] 2.4 Describe the whole site under `Web/` in CLAUDE.md's Layout

## 3. Verify

- [ ] 3.1 Each requirement in `antenna-website` has a test citing `antenna-website/<requirement-slug>`, and `scripts/check-spec-refs.sh` passes
- [ ] 3.2 `SetupPageTests` still pass, and `scripts/fast-checks.sh` passes
- [ ] 3.3 `/opsx:verify` passes

## Workflow follow-up

- The owner sets the `APPLE_TEAM_ID` repository variable, enables Pages with GitHub Actions as the source, adds the DNS record, confirms the contact address and has the legal text reviewed.
- After the first deploy, check the association file's response with `curl -sI` and that a setup link opens Antenna on a device.
- Archive the change once the site is live.
