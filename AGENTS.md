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
Database: PostgreSQL (primary data)
Cache: Solid Cache (database-backed)
Jobs: Solid Queue (database-backed, runs in Puma by default)
Realtime: Solid Cable (database-backed Action Cable)
Frontend: Hotwire (Turbo + Stimulus) + Tailwind CSS
Auth: Devise (password, passwordless, 2FA)
Payments: Pay gem + Stripe
Authorization: Pundit
Multi-tenancy: acts_as_tenant
Admin: Avo
Testing: RSpec + FactoryBot
Deploy: Kamal 2 (Docker)
```

## Code Generation Guidelines

### Models

**Always include:**
- Multi-tenancy scoping: `acts_as_tenant(:account)` for tenant-scoped models
- Pundit policy: Generate with `bin/rails generate policy ModelName`
- Proper associations with `dependent:` options
- Validations for required fields
- Database indexes for foreign keys and frequently queried fields

**Example:**
```ruby
# app/models/post.rb
class Post < ApplicationRecord
  acts_as_tenant(:account)  # Multi-tenancy
  
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
- Authenticate: `before_action :authenticate_user!`
- Authorize with Pundit: `authorize @resource`
- Scope queries: `policy_scope(Model)` (automatically tenant-scoped)
- Strong parameters
- Respond with Turbo Streams for dynamic updates

**Example:**
```ruby
# app/controllers/posts_controller.rb
class PostsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_post, only: [:show, :edit, :update, :destroy]

  def index
    @posts = policy_scope(Post).includes(:user).recent
  end

  def show
    authorize @post
  end

  def new
    @post = Post.new
    authorize @post
  end

  def create
    @post = current_account.posts.build(post_params)
    @post.user = current_user
    authorize @post

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
    authorize @post
    
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
    authorize @post
    @post.destroy
    
    respond_to do |format|
      format.html { redirect_to posts_path, notice: 'Post deleted.' }
      format.turbo_stream
    end
  end

  private

  def set_post
    @post = Post.find(params[:id])
  end

  def post_params
    params.require(:post).permit(:title, :body, :published)
  end
end
```

### Pundit Policies

**Standard policy structure:**

```ruby
# app/policies/post_policy.rb
class PostPolicy < ApplicationPolicy
  def index?
    true  # Anyone signed in can list (scoped to their account)
  end

  def show?
    # Can view if in same account
    record.account_id == user.account_id
  end

  def create?
    true  # Any authenticated user can create
  end

  def update?
    # Can edit own posts or if admin
    user.admin? || record.user_id == user.id
  end

  def destroy?
    user.admin? || record.user_id == user.id
  end

  class Scope < Scope
    def resolve
      # Automatically scoped to current account via acts_as_tenant
      scope.all
    end
  end
end
```

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
- Use `acts_as_tenant(:account)` on tenant-scoped models
- Set tenant in controller: `set_current_tenant(current_account)`
- Test tenant isolation in specs
- Never query across tenants (use `unscoped` only with extreme caution)

**ApplicationController should have:**

```ruby
class ApplicationController < ActionController::Base
  include Pundit::Authorization
  
  before_action :set_current_tenant
  
  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private

  def set_current_tenant
    set_current_tenant(current_account) if user_signed_in?
  end

  def current_account
    current_user&.account
  end
  helper_method :current_account

  def user_not_authorized
    flash[:alert] = "You are not authorized to perform this action."
    redirect_to(request.referrer || root_path)
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

❌ **Don't:**
- Add Redis when Solid Cache/Queue/Cable work fine
- Build a separate API unless you actually need one
- Introduce microservices prematurely
- Use N+1 queries (use `includes`, `preload`, or `eager_load`)
- Skip authorization checks
- Query across tenants without explicit intent
- Add JavaScript when Turbo can handle it
- Nest resources more than 1 level deep in routes

✅ **Do:**
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
bin/rails generate policy Post
bin/rails db:migrate
```

### Add a background job:
```bash
bin/rails generate job ProcessReport
```

### Add a mailer:
```bash
bin/rails generate mailer UserMailer welcome_email
```

### Add an Avo resource:
```bash
bin/rails generate avo:resource Post
```

### Run tests:
```bash
bin/rspec
bin/rspec spec/models/post_spec.rb  # Single file
bin/rspec spec/models/post_spec.rb:15  # Single test line
```

### Deploy:
```bash
kamal deploy  # Full deploy
kamal app logs  # View logs
kamal console  # Rails console on server
```

## Questions to Ask Before Generating Code

1. **Does this need to be tenant-scoped?** → Use `acts_as_tenant`
2. **Who can access this?** → Write Pundit policy
3. **Should this be async?** → Create a background job
4. **Does the UI need to be dynamic?** → Use Turbo Frames/Streams
5. **Will this query be slow?** → Add database indexes
6. **Is this a common Rails pattern?** → Follow Rails conventions

## Resources

- [Rails Guides](https://guides.rubyonrails.org/)
- [Hotwire Docs](https://hotwired.dev/)
- [Tailwind Docs](https://tailwindcss.com/)
- [Kamal Docs](https://kamal-deploy.org/)
- [Pundit README](https://github.com/varvet/pundit)
- [Solid Queue](https://github.com/rails/solid_queue)

---

**Remember**: Trailhead is designed to be simple, conventional, and productive. When in doubt, choose the Rails way.
