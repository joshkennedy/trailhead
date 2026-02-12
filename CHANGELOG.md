# Changelog

All notable changes to Trailhead will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial Trailhead template release
- Rails 8.1.2 base application
- Devise authentication with passwordless and 2FA support
- Pay gem + Stripe integration for subscriptions
- Pundit authorization
- Multi-tenancy via acts_as_tenant
- Avo admin interface
- Solid Queue, Solid Cache, and Solid Cable (database-backed)
- Kamal 2 deployment configuration
- Tailwind CSS styling
- Hotwire (Turbo + Stimulus) for reactive UIs
- RSpec testing setup with FactoryBot
- Security tools (Rubocop, Brakeman, bundler-audit)
- Complete documentation (setup, customization, deployment, architecture)
- AGENTS.md guide for AI coding assistants

### Changed
- N/A

### Deprecated
- N/A

### Removed
- N/A

### Fixed
- N/A

### Security
- N/A

## [1.0.0] - 2026-02-12

### Added
- Initial release of Trailhead Rails 8 starter template

---

## How to Update This Changelog

When you make changes to your Trailhead-based project:

1. **Add entries under [Unreleased]** for ongoing development
2. **Use categories**: Added, Changed, Deprecated, Removed, Fixed, Security
3. **Write for humans**: Explain what changed and why it matters
4. **Include links**: Reference PRs, issues, or commits if applicable
5. **Release a version**: When ready, create a new version section and move unreleased items there

### Example Entry

```markdown
## [Unreleased]

### Added
- Two-factor authentication for admin users (#42)
- Export users to CSV feature in admin panel
- New onboarding email sequence

### Changed
- Updated Stripe integration to use latest API version
- Improved dashboard loading performance by 40%

### Fixed
- Fixed bug where inactive users could still access dashboard
- Corrected timezone handling for scheduled reports
```
