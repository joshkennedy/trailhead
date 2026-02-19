# AGENTS.md

Notes for AI coding assistants working on Trailhead-based projects.

## About This File

This file helps AI agents (Claude, Cursor, Copilot, etc.) understand the conventions, design decisions, and patterns used in Trailhead so they can generate better code that fits the existing architecture.

## Project Philosophy

**Trailhead is opinionated Rails 8 starter template focused on:**
- **Convention over configuration** – follow Rails defaults unless there's a good reason not to
- **Database-first architecture** – Solid Queue, Solid Cache, Solid Cable (no Redis required)
- **Hotwire over JavaScript** – use Turbo Frames/Streams before reaching for JavaScript
- **Deploy simplicity** – Kamal to any server, minimal infrastructure
- **Monolith first** – scale vertically, split services only when necessary

When generating code, **prefer simpler solutions that fit these patterns** over introducing new dependencies or architectural complexity.

## Tech Stack Reference

```yaml
Framework: Rails 8.1.2
Database: PostgreSQL or SQLite (auto-detected from DATABASE_URL)
Cache: Solid Cache (database-backed)
Jobs: Solid Queue (database-backed, runs in Puma by default)
Realtime: Solid Cable (database-backed Action Cable)
Frontend: Hotwire (Turbo + Stimulus) + Tailwind CSS
Auth: Devise (password, passwordless, 2FA)
Payments: Pay gem + Stripe
Authorization: Role-based (Membership model)
Multi-tenancy: Custom AccountScoped concern
Admin: Madmin
Testing: RSpec + FactoryBot
Deploy: Kamal 2 (Docker)
```

## Code Generation Guidelines

### Models

**Always include:**
- Multi-tenancy scoping: `include AccountScoped` for tenant-scoped models
- Proper associations with `dependent:` options
- Validations for required fields
- Database indexes for foreign keys and frequently queried fields
- Use `t.json` instead of `t.jsonb` and `t.string` instead of `t.inet` in migrations (database-portable)

**Example:**
```ruby
# app/models/post.rb
class Post < ApplicationRecord
  include AccountScoped  # Multi-tenancy (adds belongs_to :account, .current scope)

  belongs_to :user
  has_many :comments, dependent: :destroy

  validates :title, presence: true, length: { maximum: 255 }
  validates :body, presence: true

  scope :published, -> { where(published: true) }
  scope :recent, -> { order(created_at: :desc) }
end
```

**Migration:**
```ruby
class CreatePosts < ActiveRecord::Migration[8.0]
  def change
    create_table :posts do |t|
      t.references :account, null: false, foreign_key: true, index: true
      t.references :user, null: false, foreign_key: true, index: true
      t.string :title, null: false
      t.text :body, null: false
      t.boolean :published, default: false, null: false

      t.timestamps
    end

    add_index :posts, [:account_id, :created_at]
    add_index :posts, [:account_id, :published]
  end
end
```

### Controllers

**Standard pattern:**
- Authenticate: `before_action :authenticate_user!` (inherited from ApplicationController)
- Scope queries: `Model.current` (scopes to `Current.account`)
- Authorize with role checks: `require_admin!` before_action for restricted actions
- Strong parameters
- Respond with Turbo Streams for dynamic updates

**Example:**
```ruby
# app/controllers/posts_controller.rb
class PostsController < ApplicationController
  before_action :require_admin!, only: [:destroy]
  before_action :set_post, only: [:show, :edit, :update, :destroy]

  def index
    @posts = Post.current.includes(:user).recent
  end

  def show
  end

  def new
    @post = Post.new
  end

  def create
    @post = current_account.posts.build(post_params)
    @post.user = current_user

    if @post.save
      respond_to do |format|
        format.html { redirect_to @post, notice: 'Post created.' }
        format.turbo_stream
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @post.update(post_params)
      respond_to do |format|
        format.html { redirect_to @post, notice: 'Post updated.' }
        format.turbo_stream
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @post.destroy

    respond_to do |format|
      format.html { redirect_to posts_path, notice: 'Post deleted.' }
      format.turbo_stream
    end
  end

  private

  def set_post
    @post = Post.current.find(params[:id])
  end

  def post_params
    params.require(:post).permit(:title, :body, :published)
  end

  def require_admin!
    return if current_user.admin_of?(current_account)

    redirect_to posts_path, alert: "Access denied."
  end
end
```

### Authorization

Authorization is role-based, using the `Membership` model. Roles are: `owner` > `admin` > `member`.

**In controllers**, define a `require_admin!` (or similar) before_action:
```ruby
before_action :require_admin!, only: [:destroy]

def require_admin!
  return if current_user.admin_of?(current_account)

  redirect_to root_path, alert: "Access denied."
end
```

**For billing/owner-only actions**, use Membership permission methods:
```ruby
def require_billing_access!
  return if Current.membership&.can_manage_billing?

  redirect_to dashboard_path, alert: "Only account owners can manage billing."
end
```

**Available role checks:**
- `current_user.admin_of?(account)` — owner or admin
- `current_user.owner_of?(account)` — owner only
- `current_user.member_of?(account)` — any active member
- `Current.membership.can_manage_billing?` — owner only
- `Current.membership.can_invite_members?` — admin or owner

### Views (ERB + Tailwind)

**Prefer Turbo Frames for modals, inline editing:**

```erb
<!-- app/views/posts/index.html.erb -->
<div class="space-y-4">
  <%= turbo_frame_tag "modal" %>

  <div class="flex justify-between items-center">
    <h1 class="text-2xl font-bold">Posts</h1>
    <%= link_to "New Post", new_post_path,
        data: { turbo_frame: "modal" },
        class: "btn btn-primary" %>
  </div>

  <%= turbo_frame_tag "posts" do %>
    <div class="space-y-4">
      <%= render @posts %>
    </div>
  <% end %>
</div>

<!-- app/views/posts/_post.html.erb -->
<%= turbo_frame_tag dom_id(post), class: "block p-4 bg-white rounded-lg shadow" do %>
  <h3 class="text-lg font-semibold">
    <%= link_to post.title, post %>
  </h3>
  <p class="text-gray-600 mt-2"><%= truncate(post.body, length: 200) %></p>

  <div class="mt-4 flex gap-2">
    <%= link_to "Edit", edit_post_path(post),
        data: { turbo_frame: "modal" },
        class: "text-indigo-600 hover:text-indigo-800" %>
    <%= button_to "Delete", post,
        method: :delete,
        data: { turbo_confirm: "Are you sure?" },
        class: "text-red-600 hover:text-red-800" %>
  </div>
<% end %>
```

**Turbo Stream responses:**

```erb
<!-- app/views/posts/create.turbo_stream.erb -->
<%= turbo_stream.prepend "posts", @post %>
<%= turbo_stream.update "modal", "" %>  <!-- Close modal -->

<!-- app/views/posts/update.turbo_stream.erb -->
<%= turbo_stream.replace dom_id(@post), @post %>
<%= turbo_stream.update "modal", "" %>

<!-- app/views/posts/destroy.turbo_stream.erb -->
<%= turbo_stream.remove dom_id(@post) %>
```

### Background Jobs

**Use for:**
- Email sending
- External API calls
- File processing
- Long-running operations

**Pattern:**

```ruby
# app/jobs/send_welcome_email_job.rb
class SendWelcomeEmailJob < ApplicationJob
  queue_as :default

  retry_on Net::OpenTimeout, wait: :exponentially_longer, attempts: 5
  discard_on ActiveJob::DeserializationError

  def perform(user_id)
    user = User.find(user_id)
    UserMailer.welcome_email(user).deliver_now
  end
end

# Enqueue
SendWelcomeEmailJob.perform_later(user.id)
```

**For recurring tasks:**

```yaml
# config/recurring.yml
send_daily_digest:
  class: SendDailyDigestJob
  schedule: "0 9 * * *"  # Every day at 9am
  args: []

cleanup_old_records:
  class: CleanupOldRecordsJob
  schedule: "0 2 * * 0"  # Every Sunday at 2am
```

### Testing (RSpec)

**Model specs:**

```ruby
# spec/models/post_spec.rb
require 'rails_helper'

RSpec.describe Post, type: :model do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }

  describe 'validations' do
    it { should validate_presence_of(:title) }
    it { should validate_presence_of(:body) }
  end

  describe 'associations' do
    it { should belong_to(:account) }
    it { should belong_to(:user) }
    it { should have_many(:comments).dependent(:destroy) }
  end

  describe 'scopes' do
    it 'returns published posts' do
      published = create(:post, published: true, account: account)
      draft = create(:post, published: false, account: account)

      expect(Post.published).to include(published)
      expect(Post.published).not_to include(draft)
    end
  end
end
```

**Request specs:**

```ruby
# spec/requests/posts_spec.rb
require 'rails_helper'

RSpec.describe "Posts", type: :request do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:post) { create(:post, user: user, account: account) }

  before { sign_in user }

  describe "GET /posts" do
    it "returns success" do
      get posts_path
      expect(response).to have_http_status(:success)
    end

    it "scopes to current account" do
      other_account_post = create(:post, account: create(:account))

      get posts_path
      expect(response.body).to include(post.title)
      expect(response.body).not_to include(other_account_post.title)
    end
  end

  describe "POST /posts" do
    it "creates a post" do
      expect {
        post posts_path, params: { post: { title: "Test", body: "Body" } }
      }.to change(Post, :count).by(1)
    end

    it "assigns to current user and account" do
      post posts_path, params: { post: { title: "Test", body: "Body" } }
      new_post = Post.last

      expect(new_post.user).to eq(user)
      expect(new_post.account).to eq(account)
    end
  end
end
```

## Common Patterns & Gotchas

### Multi-Tenancy

**ALWAYS remember:**
- Use `include AccountScoped` on tenant-scoped models
- `AccountScoping` concern sets `Current.account` per-request (included in ApplicationController)
- Use `Model.current` in controllers to scope queries to the current account
- Test tenant isolation in specs
- Never query across tenants (use unscoped `Model.all` only with extreme caution, e.g. admin views)

**ApplicationController:**

```ruby
class ApplicationController < ActionController::Base
  include AccountScoping

  before_action :authenticate_user!

  private

  def after_sign_in_path_for(_resource)
    dashboard_path
  end

  def after_sign_out_path_for(_resource)
    new_user_session_path
  end
end
```

### Hotwire Patterns

**Use Turbo Frames for:**
- Modals/dialogs
- Inline editing
- Lazy-loaded content
- Pagination

**Use Turbo Streams for:**
- Adding/removing items from lists
- Live updates (via Action Cable)
- Form validation feedback

**Avoid:**
- Complex JavaScript SPA patterns
- Heavy client-side state management
- Reimplementing what Turbo already provides

### Form Handling

**Standard form pattern:**

```erb
<%= form_with model: @post, class: "space-y-6" do |f| %>
  <% if @post.errors.any? %>
    <div class="rounded-md bg-red-50 p-4">
      <ul class="list-disc list-inside text-sm text-red-800">
        <% @post.errors.full_messages.each do |message| %>
          <li><%= message %></li>
        <% end %>
      </ul>
    </div>
  <% end %>

  <%= render 'form_fields', f: f %>

  <div class="flex justify-end gap-2">
    <%= link_to "Cancel", posts_path, class: "btn btn-secondary" %>
    <%= f.submit class: "btn btn-primary" %>
  </div>
<% end %>
```

### Stimulus Controllers

**When to use:**
- Client-side interactions (dropdowns, tabs, tooltips)
- Form enhancements (auto-save, character counts)
- DOM manipulation that doesn't need server round-trip

**Pattern:**

```javascript
// app/javascript/controllers/dropdown_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu"]

  toggle() {
    this.menuTarget.classList.toggle("hidden")
  }

  hide(event) {
    if (!this.element.contains(event.target)) {
      this.menuTarget.classList.add("hidden")
    }
  }
}
```

```erb
<div data-controller="dropdown" data-action="click@window->dropdown#hide">
  <button data-action="click->dropdown#toggle">Menu</button>
  <div data-dropdown-target="menu" class="hidden">
    <!-- Menu items -->
  </div>
</div>
```

## Deployment Considerations

### Environment Variables

**Use Rails credentials for secrets:**
```bash
EDITOR="code --wait" bin/rails credentials:edit
```

**Use environment variables for:**
- Server-specific config (DB host, Redis URL)
- Deployment-specific values
- Non-sensitive configuration

**Set in Kamal:**
```yaml
# config/deploy.yml
env:
  secret:
    - RAILS_MASTER_KEY
    - DATABASE_URL
    - STRIPE_SECRET_KEY
  clear:
    RAILS_LOG_LEVEL: info
    SOLID_QUEUE_IN_PUMA: true
```

### Database Migrations

**Always:**
- Make migrations reversible (`def change` or `def up/down`)
- Add indexes for foreign keys and frequently queried columns
- Use `null: false` and database constraints where appropriate
- Test rollback before deploying

**Deploy migrations:**
```bash
kamal app exec "bin/rails db:migrate"
# Or automatic during deploy (Kamal runs migrations by default)
```

## Anti-Patterns to Avoid

**Don't:**
- Add Redis when Solid Cache/Queue/Cable work fine
- Build a separate API unless you actually need one
- Introduce microservices prematurely
- Use N+1 queries (use `includes`, `preload`, or `eager_load`)
- Skip authorization checks
- Query across tenants without explicit intent
- Add JavaScript when Turbo can handle it
- Nest resources more than 1 level deep in routes

**Do:**
- Use database transactions for multi-step operations
- Add indexes for performance-critical queries
- Write tests for business logic
- Use partials to DRY up views
- Cache expensive operations
- Monitor performance (N+1, slow queries)
- Follow Rails conventions

## Common Tasks Reference

### Add a new resource:
```bash
bin/rails generate model Post account:references user:references title:string body:text published:boolean
bin/rails generate controller Posts
bin/rails db:migrate
# Then add `include AccountScoped` to the model
# Madmin resources go in app/madmin/resources/ (see existing resources for examples)
```

### Add a background job:
```bash
bin/rails generate job ProcessReport
```

### Add a mailer:
```bash
bin/rails generate mailer UserMailer welcome_email
```

### Run tests:
```bash
bundle exec rspec
bundle exec rspec spec/models/post_spec.rb  # Single file
bundle exec rspec spec/models/post_spec.rb:15  # Single test line
```

### Deploy:
```bash
kamal deploy  # Full deploy
kamal app logs  # View logs
kamal console  # Rails console on server
```

## Questions to Ask Before Generating Code

1. **Does this need to be tenant-scoped?** → Use `include AccountScoped`
2. **Who can access this?** → Add role check via Membership (`require_admin!`, `can_manage_billing?`)
3. **Should this be async?** → Create a background job
4. **Does the UI need to be dynamic?** → Use Turbo Frames/Streams
5. **Will this query be slow?** → Add database indexes
6. **Is this a common Rails pattern?** → Follow Rails conventions

## Resources

- [Rails Guides](https://guides.rubyonrails.org/)
- [Hotwire Docs](https://hotwired.dev/)
- [Tailwind Docs](https://tailwindcss.com/)
- [Kamal Docs](https://kamal-deploy.org/)
- [Madmin](https://github.com/excid3/madmin)
- [Solid Queue](https://github.com/rails/solid_queue)

---

**Remember**: Trailhead is designed to be simple, conventional, and productive. When in doubt, choose the Rails way.
