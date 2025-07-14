#!/bin/bash

# Crypto Trading Setup Analyzer - Installation Script
# For Ubuntu/Debian VPS

set -e

echo "🚀 Installing Crypto Trading Setup Analyzer..."

# Update system
echo "📦 Updating system packages..."
sudo apt-get update
sudo apt-get upgrade -y

# Install required packages
echo "🛠️ Installing system dependencies..."
sudo apt-get install -y \
    curl \
    wget \
    git \
    python3 \
    python3-pip \
    python3-venv \
    build-essential \
    libssl-dev \
    libffi-dev \
    python3-dev \
    nginx \
    redis-server \
    supervisor \
    ufw \
    certbot \
    python3-certbot-nginx

# Install Docker
echo "🐳 Installing Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Install Docker Compose
echo "🔧 Installing Docker Compose..."
sudo curl -L "https://github.com/docker/compose/releases/download/v2.21.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Install Node.js and npm (for React build)
echo "📱 Installing Node.js..."
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Create application directory
echo "📁 Setting up application directory..."
sudo mkdir -p /opt/crypto-analyzer
sudo chown $USER:$USER /opt/crypto-analyzer
cd /opt/crypto-analyzer

# Create React build directory
echo "⚛️ Setting up React build environment..."
mkdir -p static
mkdir -p logs
mkdir -p ssl

# Create React package.json
cat > package.json << 'EOF'
{
  "name": "crypto-analyzer-frontend",
  "version": "1.0.0",
  "private": true,
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-scripts": "5.0.1",
    "lucide-react": "^0.263.1",
    "web-vitals": "^3.3.2"
  },
  "scripts": {
    "start": "react-scripts start",
    "build": "react-scripts build && cp build/* ../static/",
    "test": "react-scripts test",
    "eject": "react-scripts eject"
  },
  "eslintConfig": {
    "extends": [
      "react-app",
      "react-app/jest"
    ]
  },
  "browserslist": {
    "production": [
      ">0.2%",
      "not dead",
      "not op_mini all"
    ],
    "development": [
      "last 1 chrome version",
      "last 1 firefox version",
      "last 1 safari version"
    ]
  }
}
EOF

# Create React public directory with PWA files
mkdir -p public
cat > public/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8" />
    <link rel="icon" href="%PUBLIC_URL%/favicon.ico" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <meta name="theme-color" content="#000000" />
    <meta name="description" content="Crypto Trading Setup Analyzer - Real-time analysis" />
    <link rel="apple-touch-icon" href="%PUBLIC_URL%/logo192.png" />
    <link rel="manifest" href="%PUBLIC_URL%/manifest.json" />
    <title>Crypto Trading Setup Analyzer</title>
    <script src="https://cdn.tailwindcss.com"></script>
</head>
<body>
    <noscript>You need to enable JavaScript to run this app.</noscript>
    <div id="root"></div>
</body>
</html>
EOF

# Create PWA manifest
cat > public/manifest.json << 'EOF'
{
  "short_name": "Crypto Analyzer",
  "name": "Crypto Trading Setup Analyzer",
  "icons": [
    {
      "src": "favicon.ico",
      "sizes": "64x64 32x32 24x24 16x16",
      "type": "image/x-icon"
    }
  ],
  "start_url": ".",
  "display": "standalone",
  "theme_color": "#000000",
  "background_color": "#ffffff"
}
EOF

# Create React source directory
mkdir -p src
cat > src/index.js << 'EOF'
import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';

const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
EOF

# Create systemd service
echo "⚙️ Creating systemd service..."
sudo tee /etc/systemd/system/crypto-analyzer.service > /dev/null << 'EOF'
[Unit]
Description=Crypto Trading Setup Analyzer
After=network.target redis.service

[Service]
Type=simple
User=root
WorkingDirectory=/opt/crypto-analyzer
ExecStart=/usr/local/bin/docker-compose up
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Configure firewall
echo "🔒 Configuring firewall..."
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force enable

# Configure Redis
echo "🗄️ Configuring Redis..."
sudo systemctl enable redis-server
sudo systemctl start redis-server

# Create environment file
cat > .env << 'EOF'
ENVIRONMENT=production
REDIS_URL=redis://redis:6379
LOG_LEVEL=INFO
PYTHONUNBUFFERED=1
EOF

# Create build script
cat > build.sh << 'EOF'
#!/bin/bash
echo "Building React frontend..."
npm install
npm run build

echo "Building Docker containers..."
docker-compose build

echo "Starting services..."
docker-compose up -d

echo "✅ Build completed successfully!"
EOF

chmod +x build.sh

# Create deployment script
cat > deploy.sh << 'EOF'
#!/bin/bash
echo "🚀 Deploying Crypto Trading Setup Analyzer..."

# Pull latest changes
git pull origin main

# Rebuild and restart
docker-compose down
docker-compose build --no-cache
docker-compose up -d

# Check health
sleep 10
curl -f http://localhost:8000/api/health || echo "❌ Health check failed"

echo "✅ Deployment completed!"
EOF

chmod +x deploy.sh

# Create backup script
cat > backup.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/opt/crypto-analyzer/backups"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

echo "📦 Creating backup..."
docker-compose exec redis redis-cli BGSAVE
tar -czf $BACKUP_DIR/backup_$DATE.tar.gz logs/ static/

# Keep only last 7 days of backups
find $BACKUP_DIR -name "backup_*.tar.gz" -mtime +7 -delete

echo "✅ Backup created: backup_$DATE.tar.gz"
EOF

chmod +x backup.sh

# Create log rotation
sudo tee /etc/logrotate.d/crypto-analyzer > /dev/null << 'EOF'
/opt/crypto-analyzer/logs/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0644 root root
    postrotate
        docker-compose restart crypto-analyzer
    endscript
}
EOF

# Create monitoring script
cat > monitor.sh << 'EOF'
#!/bin/bash
echo "🔍 Crypto Analyzer Status:"
echo "=========================="

# Check Docker containers
echo "📦 Docker Containers:"
docker-compose ps

# Check system resources
echo -e "\n💻 System Resources:"
echo "CPU: $(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1"%"}')"
echo "Memory: $(free -h | awk 'NR==2{printf "%.1f%%", $3*100/$2 }')"
echo "Disk: $(df -h / | awk 'NR==2{print $5}')"

# Check service health
echo -e "\n🏥 Health Check:"
curl -s http://localhost:8000/api/health | python3 -m json.tool || echo "❌ Health check failed"

# Check logs
echo -e "\n📋 Recent Logs:"
docker-compose logs --tail=5 crypto-analyzer
EOF

chmod +x monitor.sh

# Set up cron jobs
echo "⏰ Setting up cron jobs..."
(crontab -l 2>/dev/null; echo "0 2 * * * /opt/crypto-analyzer/backup.sh") | crontab -
(crontab -l 2>/dev/null; echo "*/5 * * * * /opt/crypto-analyzer/monitor.sh > /tmp/crypto-analyzer-status.log 2>&1") | crontab -

echo "✅ Installation completed!"
echo ""
echo "📋 Next steps:"
echo "1. Copy your React component to src/App.js"
echo "2. Run: ./build.sh"
echo "3. Access your application at http://your-server-ip"
echo ""
echo "🔧 Useful commands:"
echo "- Start: docker-compose up -d"
echo "- Stop: docker-compose down"
echo "- Monitor: ./monitor.sh"
echo "- Backup: ./backup.sh"
echo "- Deploy: ./deploy.sh"
echo "- Logs: docker-compose logs -f crypto-analyzer"
echo ""
echo "🌐 SSL Setup (optional):"
echo "sudo certbot --nginx -d your-domain.com"
echo ""
echo "🚀 The application will be available at:"
echo "- HTTP: http://your-server-ip"
echo "- WebSocket: ws://your-server-ip/ws"
echo "- API: http://your-server-ip/api/"