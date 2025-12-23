#!/bin/bash

# ⚙️ Bash Script: Fully Automated EC2 Node.js Deployment

# > ✅ **What this script does**
# - Updates system packages  
# - Installs Git, NVM, Node.js (LTS)  
# - Clones the Node.js app  
# - Installs dependencies  
# - Installs & configures Nginx  
# - Installs PM2  
# - Starts app via PM2  
# - Enables startup persistence  

set -euo pipefail


echo "🔄 Updating system packages..."
sudo yum update -y


# --- Step 1: Ask for application name ---
read -p "Enter the application name: " APP_NAME </dev/tty

# --- Step 2: Ask for Git repo URL ---
read -p "Enter the Git repository URL: " APP_REPO </dev/tty

# --- Step 3: Determine if repo is private ---
read -p "Is this a private repository? (y/N): " IS_PRIVATE </dev/tty
IS_PRIVATE=${IS_PRIVATE:-N}

# --- Step 4: Set directory name dynamically ---
REPO_NAME=$(basename "$APP_REPO" .git)
APP_DIR="$HOME/$REPO_NAME"

# --- Step 5: Ask for application port ---
read -p "Enter the application port number [default 3000]: " APP_PORT </dev/tty
APP_PORT=${APP_PORT:-3000}

echo
echo "✅ Configuration summary:"
echo "App Name      : $APP_NAME"
echo "Git Repo      : $APP_REPO"
echo "Private Repo? : $IS_PRIVATE"
echo "App Directory : $APP_DIR"
echo "App Port      : $APP_PORT"
echo

# --- Step 6: Clone repository ---
if [[ "$IS_PRIVATE" =~ ^[Yy]$ ]]; then
    SSH_KEY="$HOME/.ssh/${APP_NAME}_deploy_key"

    # Generate SSH key if it doesn't exist
    if [[ ! -f "$SSH_KEY" ]]; then
        echo "🔑 Generating SSH key for deployment..."
        ssh-keygen -t ed25519 -f "$SSH_KEY" -N ""
        echo "Add the following public key as a deploy key in GitHub:"
        cat "${SSH_KEY}.pub"
        read -p "Press ENTER once you've added the key to GitHub..." </dev/tty
    fi

    # Start ssh-agent and add the key
    eval "$(ssh-agent -s)"
    ssh-add "$SSH_KEY"
fi

echo "📦 Installing Git..."
sudo yum install git -y

echo "📦 Installing Nginx..."
sudo yum install nginx -y
sudo systemctl start nginx
sudo systemctl enable nginx

echo "📦 Installing NVM..."
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash

# NEW CHANGE
echo "📦 Installing Node.js (LTS)..."
source ~/.bashrc
nvm -v
nvm install $NODE_VERSION
node -v

# git
echo "📥 Cloning application repository..."
cd ~
git clone "$APP_REPO" "$APP_DIR"

# Dependencies
echo "📦 Installing application dependencies..."
cd $APP_DIR_NAME
npm install

# Application
echo "🚀 Starting application with PM2..."
npm install -g pm2
pm2 start npm --name $APP_NAME -- start
pm2 save

echo "🌐 Configuring Nginx reverse proxy..."
sudo tee /etc/nginx/conf.d/node-app.conf > /dev/null <<EOF
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://localhost:$APP_PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF

echo "🔄 Reloading Nginx..."
sudo nginx -t
sudo systemctl reload nginx


echo "⚙️ Enabling PM2 startup on reboot..."
pm2 startup systemd -u ec2-user --hp /home/ec2-user
sudo env PATH=$PATH:$(dirname "$(nvm which current)") pm2 startup systemd -u ec2-user --hp /home/ec2-user


echo "✅ Deployment completed successfully!"
echo "🌍 Access your app via: http://<PUBLIC_IP>"

