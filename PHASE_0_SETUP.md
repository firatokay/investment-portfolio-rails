# Phase 0 Setup - Final Steps

## Current Status: 90% Complete ✅

All dependencies and configurations are in place. Only PostgreSQL database setup remains.

---

## What's Already Done ✅

- ✅ Rails 8.0.4 application created
- ✅ PostgreSQL configured in `config/database.yml`
- ✅ All required gems installed (devise, pundit, sidekiq, rspec, etc.)
- ✅ RSpec testing framework configured with SimpleCov and shoulda-matchers
- ✅ Redis initializer created
- ✅ Environment variables configured in `.env`
- ✅ Port changed to 3001 to avoid conflicts

---

## PostgreSQL Setup Required ⚠️

Your PostgreSQL is configured to require password authentication. You have **two options**:

### **Option 1: Set a PostgreSQL Password (Recommended)**

1. **Open a terminal and run:**
   ```bash
   psql -d postgres
   ```

2. **If it prompts for a password**, try without specifying username:
   ```bash
   psql postgres
   ```

3. **Once in psql, run this command** (replace `your_password` with your chosen password):
   ```sql
   ALTER USER firatokay WITH PASSWORD 'your_password';
   \q
   ```

4. **Update the `.env` file** (line 3):
   ```env
   POSTGRES_PASSWORD=your_password
   ```

5. **Create the databases:**
   ```bash
   rails db:create
   ```

---

### **Option 2: Configure PostgreSQL to Trust Local Connections**

This allows connections without a password for local development.

1. **Find your `pg_hba.conf` file:**
   ```bash
   # On macOS with Homebrew:
   /opt/homebrew/var/postgresql@14/pg_hba.conf
   # or
   /usr/local/var/postgresql@14/pg_hba.conf
   # or look for it with:
   locate pg_hba.conf
   ```

2. **Edit `pg_hba.conf`** (requires sudo):
   ```bash
   sudo nano /path/to/pg_hba.conf
   ```

3. **Find lines that look like this:**
   ```
   local   all   all   md5
   # or
   local   all   all   scram-sha-256
   ```

4. **Change `md5` or `scram-sha-256` to `trust`:**
   ```
   local   all   all   trust
   ```

5. **Reload PostgreSQL:**
   ```bash
   # On macOS with Homebrew:
   brew services restart postgresql
   # or
   pg_ctl reload -D /path/to/data/directory
   ```

6. **Create the databases:**
   ```bash
   rails db:create
   ```

---

## After Database Setup

Once databases are created, verify everything works:

### 1. **Test Database Connection**
```bash
rails db:version
```

### 2. **Run RSpec (should show 0 examples)**
```bash
rspec
```
Expected output:
```
No examples found.

Finished in 0.00001 seconds (files took 0.5 seconds to load)
0 examples, 0 failures
```

### 3. **Start the Rails Server**
```bash
# Option A: Using foreman (runs Rails + Tailwind CSS)
bin/dev

# Option B: Just Rails
rails server -p 3001
```

### 4. **Visit the Application**
Open your browser to: **http://localhost:3001**

You should see the Rails welcome page!

---

## Quick Reference

### Environment Variables (`.env`)
- `POSTGRES_USER=firatokay`
- `POSTGRES_PASSWORD=` (set this if using Option 1)
- `POSTGRES_HOST=localhost`
- `PORT=3001`
- `REDIS_URL=redis://localhost:6379/1`
- `ALPHA_VANTAGE_API_KEY=demo`

### Key Files Modified
- `Gemfile` - Added all Phase 0 gems
- `config/database.yml` - Configured for environment variables
- `config/initializers/redis.rb` - Redis connection
- `spec/spec_helper.rb` - SimpleCov configuration
- `spec/rails_helper.rb` - shoulda-matchers & FactoryBot
- `Procfile.dev` - Changed port to 3001
- `.env` - Environment variables

### Installed Gems
**Authentication & Authorization:**
- devise, pundit

**Background Jobs:**
- sidekiq, sidekiq-scheduler, redis

**HTTP Clients:**
- httparty, faraday

**Testing:**
- rspec-rails, factory_bot_rails, faker, pry-rails
- shoulda-matchers, vcr, webmock, simplecov

**Production:**
- rack-timeout, rack-attack

---

## Troubleshooting

### "connection refused" error
- Ensure PostgreSQL is running: `pg_isready`
- Start if needed: `brew services start postgresql`

### "fe_sendauth: no password supplied"
- Follow Option 1 or Option 2 above

### Redis not available
- Redis is optional for Phase 0 (Rails 8 uses Solid Queue)
- To install: `brew install redis`
- To start: `brew services start redis`

### Port 3000 already in use
- Already fixed! App runs on port 3001

---

## Next Steps After Phase 0

Once Phase 0 is complete (databases created, server running), you can proceed to:

**Phase 1: User Authentication**
- Install and configure Devise
- Create User model
- Add authentication views

See `RAILS_PROJECT_PLAN.md` for detailed instructions on Phase 1 and beyond.

---

## Need Help?

Run the interactive setup script:
```bash
./setup_postgres.sh
```

Or manually follow the PostgreSQL setup options above.
