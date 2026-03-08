#!/bin/bash
# setup.sh

ENV_FILE=".env.jclaw"

echo "=== JCLAW Agent Skills Setup ==="

# Check for Jules CLI
if ! command -v jules &> /dev/null; then
    echo "⚠ Jules CLI not found in PATH."
    read -p "Would you like to install it via npm? (y/N) " install_cli
    if [[ "$install_cli" =~ ^[Yy]$ ]]; then
        npm install -g @google/jules
        if [ $? -eq 0 ]; then
            echo "✓ Jules CLI installed successfully."
        else
            echo "✗ Failed to install Jules CLI."
        fi
    else
        echo "ℹ Continuing without Jules CLI (API mode only)."
    fi
else
    echo "✓ Jules CLI is available."
fi

# Authenticate
API_KEY=""
if [ -n "$PROJECT_JULES_API_KEY" ]; then
    echo "✓ Found project-specific JULES_API_KEY."
    API_KEY="$PROJECT_JULES_API_KEY"
elif [ -n "$JULES_API_KEY" ]; then
    echo "✓ Found general JULES_API_KEY."
    API_KEY="$JULES_API_KEY"
else
    echo "⚠ No JULES_API_KEY found in environment."
    read -p "Please enter your Jules API Key (PAT): " input_key
    API_KEY="$input_key"
fi

# Save to env file
if [ -n "$API_KEY" ]; then
    echo "JULES_API_KEY=\"$API_KEY\"" > "$ENV_FILE"
    echo "✓ Saved credentials to $ENV_FILE."

    # Add to gitignore if not already present
    if [ -f .gitignore ]; then
        if ! grep -q "$ENV_FILE" .gitignore; then
            echo "$ENV_FILE" >> .gitignore
            echo "✓ Added $ENV_FILE to .gitignore"
        fi
    fi
else
    echo "✗ No credentials provided. Scripts requiring API access will fail."
fi

echo "=== Setup Complete ==="
