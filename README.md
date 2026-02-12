# Trailhead

**A modern Rails 8 starter template for building SaaS applications**

Trailhead is a production-ready Rails 8 starter template that gives you everything you need to launch a SaaS app: authentication, payments, multi-tenancy, admin interface, and one-command deployment. Built on Rails 8's modern defaults with carefully selected gems for common SaaS features.

## 🚀 Quick Start

```bash
# Clone the template
git clone https://github.com/your-org/trailhead.git my-app
cd my-app

# Install dependencies
bundle install
bin/rails db:create db:migrate db:seed

# Start the dev server
bin/dev
```

Visit `http://localhost:3000` and you're running.

## ✨ Features

### Core Rails 8
- **Rails 8.1.2** with all the latest improvements
- **Turbo & Stimulus** for reactive UIs without heavy JavaScript
- **Tailwind CSS** for utility-first styling
- **Propshaft** for modern asset pipeline
- **PostgreSQL** as the default database

### Authentication & Authorization
- **Devise** with passwordless (magic link) and 2FA support
- **Pundit** for authorization policies
- Multi-tenancy scoping with **acts_as_tenant**

### Payments
- **Pay gem** for subscription management
- **Stripe** integration (easily swap for other providers)

### Background Jobs
- **Solid Queue** (database-backed, no Redis required)
- Runs in-process with Puma for single-server setups
- Easy to scale to dedicated job workers

### Admin
- **Avo** admin interface (beautiful, customizable, Rails-native)

### Deployment
- **Kamal 2** configuration for zero-downtime Docker deployments
- **Thruster** for HTTP caching and SSL termination
- **Solid Cache** and **Solid Cable** (database-backed, production-ready)
- Dockerfile optimized for fast builds and small images

### Developer Experience
- **RSpec** for testing (with FactoryBot and Faker)
- **Rubocop** with Rails Omakase style
- **Brakeman** and **bundler-audit** for security scanning
- **Debug** gem for interactive debugging

## 📦 Tech Stack

| Layer           | Technology          | Why                                    |
|-----------------|---------------------|----------------------------------------|
| Framework       | Rails 8.1           | Modern Rails with all the good stuff  |
| Database        | PostgreSQL          | Reliable, full-featured SQL           |
| Caching         | Solid Cache         | Database-backed, no extra infra       |
| Jobs            | Solid Queue         | Database-backed, simple & reliable    |
| Realtime        | Solid Cable         | Database-backed Action Cable          |
| Frontend        | Hotwire + Tailwind  | Fast UIs without heavy JS             |
| Auth            | Devise              | Battle-tested authentication          |
| Payments        | Pay + Stripe        | Flexible subscription billing         |
| Admin           | Avo                 | Modern admin interface                |
| Deploy          | Kamal 2             | Docker deploy to any server           |
| Testing         | RSpec               | BDD-style testing                     |

## 📖 Documentation

- **[Setup Guide](docs/setup.md)** – Detailed installation and configuration
- **[Customization](docs/customization.md)** – Adapt Trailhead for your project
- **[Deployment](docs/deployment.md)** – Deploy to Hetzner with Kamal
- **[Architecture](docs/architecture.md)** – How Trailhead is structured
- **[RailsBlocks Integration](docs/rails-blocks.md)** – Add UI components
- **[Agent Notes](AGENTS.md)** – Guidance for AI coding assistants

## 🎯 Philosophy

**Get to market fast, but don't accumulate tech debt.**

Trailhead makes opinionated choices:
- **Database-first**: Solid Queue, Solid Cache, Solid Cable eliminate external dependencies
- **Boring tech**: PostgreSQL, Puma, Kamal – proven, reliable tools
- **Modern Rails**: Hotwire over heavy JavaScript, Rails conventions over custom architecture
- **Deploy anywhere**: Kamal lets you deploy to any server, no vendor lock-in

## 🔧 Common Tasks

```bash
# Run tests
bin/rspec

# Run linters
bin/rubocop
bin/brakeman

# Console
bin/rails console

# Database console
bin/rails dbconsole

# Check for security issues
bundle exec bundler-audit check --update

# Deploy to production
bin/kamal deploy
```

## 🚢 Deployment

Trailhead is configured for deployment via **Kamal 2** to any server. See [docs/deployment.md](docs/deployment.md) for a complete guide to deploying on Hetzner.

One-command deploy after initial setup:
```bash
bin/kamal deploy
```

## 🤝 Contributing

This is a starter template – fork it and make it yours! If you find bugs or have ideas for improvements to the template itself, please open an issue or PR.

## 📄 License

MIT License – see [LICENSE](LICENSE) for details.

## 🙏 Acknowledgments

Built on the shoulders of giants:
- Rails team for Rails 8 and the Solid gems
- The Hotwire team
- Kamal and the deployment tooling ecosystem
- All the gem maintainers
