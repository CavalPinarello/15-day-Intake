#!/bin/bash

# Setup script to enable Convex database for local testing

echo "🚀 Setting up Convex database for local testing..."
echo ""

# Create .env file in server directory
SERVER_DIR="server"
ENV_FILE="$SERVER_DIR/.env"

# Check if .env already exists
if [ -f "$ENV_FILE" ]; then
    echo "⚠️  .env file already exists. Backing up to .env.backup"
    cp "$ENV_FILE" "$SERVER_DIR/.env.backup"
fi

# Create .env file
cat > "$ENV_FILE" << EOF
# Use Convex database (online) instead of SQLite (local)
USE_CONVEX=true

# Convex deployment URL (from npx convex dev)
CONVEX_URL=https://enchanted-terrier-633.convex.cloud
NEXT_PUBLIC_CONVEX_URL=https://enchanted-terrier-633.convex.cloud
EOF

echo "✅ Created $ENV_FILE with Convex configuration"
echo ""
echo "📋 Configuration:"
echo "   USE_CONVEX=true"
echo "   CONVEX_URL=https://enchanted-terrier-633.convex.cloud"
echo ""
echo "🎯 Next steps:"
echo "   1. Start the server: cd server && npm run dev"
echo "   2. You should see 'Using Convex database' in the logs"
echo "   3. All data will be stored online in Convex"
echo ""
echo "💡 To switch back to SQLite:"
echo "   - Remove or comment out USE_CONVEX=true in $ENV_FILE"
echo "   - Or delete the .env file"
echo ""



