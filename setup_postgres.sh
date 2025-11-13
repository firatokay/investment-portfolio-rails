#!/bin/bash

# PostgreSQL Setup Script for Investment Portfolio Rails App
# This script will help you set up PostgreSQL for the application

echo "========================================"
echo "PostgreSQL Setup for Rails Application"
echo "========================================"
echo ""

# Check if PostgreSQL is running
if ! pg_isready > /dev/null 2>&1; then
    echo "❌ PostgreSQL is not running. Please start PostgreSQL first."
    echo "   On macOS with Homebrew: brew services start postgresql"
    exit 1
fi

echo "✅ PostgreSQL is running"
echo ""

# Option 1: Set a password
echo "Option 1: Set a password for your PostgreSQL user"
echo "---------------------------------------------------"
echo "This will allow Rails to connect using password authentication."
echo ""
read -p "Do you want to set a password? (y/n): " SET_PASSWORD

if [ "$SET_PASSWORD" = "y" ] || [ "$SET_PASSWORD" = "Y" ]; then
    echo ""
    echo "Enter a password for the PostgreSQL user 'firatokay':"
    read -s POSTGRES_PASSWORD
    echo ""
    echo "Confirm password:"
    read -s POSTGRES_PASSWORD_CONFIRM

    if [ "$POSTGRES_PASSWORD" != "$POSTGRES_PASSWORD_CONFIRM" ]; then
        echo "❌ Passwords don't match!"
        exit 1
    fi

    # Set the password
    psql -d postgres -c "ALTER USER firatokay WITH PASSWORD '$POSTGRES_PASSWORD';" 2>/dev/null

    if [ $? -eq 0 ]; then
        echo "✅ Password set successfully!"
        echo ""
        echo "Now updating .env file..."

        # Update .env file
        sed -i.bak "s/POSTGRES_PASSWORD=/POSTGRES_PASSWORD=$POSTGRES_PASSWORD/" .env
        rm .env.bak

        echo "✅ .env file updated"
    else
        echo "❌ Failed to set password. Trying alternative method..."
        echo ""
        echo "Please run this command manually:"
        echo "  psql -d postgres"
        echo "  ALTER USER firatokay WITH PASSWORD '$POSTGRES_PASSWORD';"
        echo "  \\q"
        echo ""
        echo "Then update .env file with:"
        echo "  POSTGRES_PASSWORD=$POSTGRES_PASSWORD"
        exit 1
    fi
else
    # Option 2: Configure PostgreSQL to trust local connections
    echo ""
    echo "Option 2: Configure PostgreSQL to allow connections without password"
    echo "---------------------------------------------------------------------"
    echo "This requires editing PostgreSQL's pg_hba.conf file."
    echo ""
    echo "Your pg_hba.conf file is likely located at:"
    PG_HBA_CONF=$(psql -d postgres -t -c "SHOW hba_file;" 2>/dev/null | xargs)

    if [ -n "$PG_HBA_CONF" ]; then
        echo "  $PG_HBA_CONF"
        echo ""
        echo "To allow local connections without password:"
        echo "1. Edit the pg_hba.conf file (requires sudo)"
        echo "2. Find lines that look like:"
        echo "     local   all   all   md5"
        echo "   or"
        echo "     local   all   all   scram-sha-256"
        echo "3. Change 'md5' or 'scram-sha-256' to 'trust'"
        echo "4. Reload PostgreSQL configuration:"
        echo "     pg_ctl reload -D /path/to/data/directory"
        echo "   or"
        echo "     brew services restart postgresql"
    else
        echo "  Could not determine pg_hba.conf location"
    fi

    echo ""
    echo "After making changes, rerun this script or run: rails db:create"
fi

echo ""
echo "========================================"
echo "Next Steps:"
echo "========================================"
echo "1. Run: rails db:create"
echo "2. Run: rails server -p 3001"
echo "3. Visit: http://localhost:3001"
echo ""
