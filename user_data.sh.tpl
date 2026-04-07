#!/bin/bash
# =============================================================================
# Rural Care - EC2 User Data Script
# Automatically deploys the application on instance launch
# =============================================================================

set -e

exec > >(tee /var/log/ruralcare-setup.log) 2>&1
echo "=== Rural Care Setup Started at $(date) ==="

# -----------------------------------------------------------------------------
# System Updates and Dependencies
# -----------------------------------------------------------------------------

echo "Installing system dependencies..."
dnf update -y
dnf install -y git python3.11 python3.11-pip python3.11-devel \
    gcc libpq-devel nginx \
    openssl-devel libffi-devel

# Set Python 3.11 as default
alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1
alternatives --set python3 /usr/bin/python3.11

# -----------------------------------------------------------------------------
# Create Application User
# -----------------------------------------------------------------------------

echo "Creating application user..."
useradd -m -s /bin/bash ruralcare || true

# -----------------------------------------------------------------------------
# Clone Repository
# -----------------------------------------------------------------------------

echo "Cloning repository..."
cd /home/ruralcare
rm -rf Rural_care
sudo -u ruralcare git clone -b ${git_branch} ${git_repo_url} Rural_care
cd Rural_care

# -----------------------------------------------------------------------------
# Setup Python Virtual Environment
# -----------------------------------------------------------------------------

echo "Setting up Python virtual environment..."
sudo -u ruralcare python3 -m venv venv
sudo -u ruralcare /home/ruralcare/Rural_care/venv/bin/pip install --upgrade pip
sudo -u ruralcare /home/ruralcare/Rural_care/venv/bin/pip install -r requirements.txt

# -----------------------------------------------------------------------------
# Environment Configuration
# -----------------------------------------------------------------------------

echo "Configuring environment..."
cat > /home/ruralcare/Rural_care/.env << 'ENVEOF'
# Database Configuration (external database URL)
DATABASE_URL=${database_url}

# Django Settings
SECRET_KEY=${secret_key}
DEBUG=False
ALLOWED_HOSTS=*

# ML Features (disabled for lightweight deployment)
ML_FEATURES_ENABLED=False

# Supabase Configuration
SUPABASE_URL=${supabase_url}
SUPABASE_KEY=${supabase_key}
SUPABASE_SERVICE_KEY=

# AI API
GROQ_API_KEY=${groq_api_key}

# Blockchain
BLOCKCHAIN_ENABLED=${blockchain_enabled}
ALCHEMY_RPC_URL=
BLOCKCHAIN_PRIVATE_KEY=
BLOCKCHAIN_CONTRACT_ADDRESS=
PRESCRIPTION_CONTRACT_ADDRESS=

# Payment (Razorpay)
RAZORPAY_KEY_ID=
RAZORPAY_KEY_SECRET=

# Email
EMAIL_HOST_USER=
EMAIL_HOST_PASSWORD=

# Video Calling (Agora)
AGORA_APP_ID=
AGORA_APP_CERTIFICATE=
ENVEOF

chown ruralcare:ruralcare /home/ruralcare/Rural_care/.env
chmod 600 /home/ruralcare/Rural_care/.env

# -----------------------------------------------------------------------------
# Run Migrations and Collect Static Files
# -----------------------------------------------------------------------------

echo "Running Django setup..."
cd /home/ruralcare/Rural_care
sudo -u ruralcare /home/ruralcare/Rural_care/venv/bin/python manage.py collectstatic --noinput
sudo -u ruralcare /home/ruralcare/Rural_care/venv/bin/python manage.py migrate --noinput || echo "Migration skipped (database may not be configured)"

# -----------------------------------------------------------------------------
# Setup Gunicorn Systemd Service
# -----------------------------------------------------------------------------

echo "Configuring Gunicorn service..."
cat > /etc/systemd/system/ruralcare.service << 'EOF'
[Unit]
Description=Rural Care Django Application
After=network.target

[Service]
User=ruralcare
Group=ruralcare
WorkingDirectory=/home/ruralcare/Rural_care
Environment="PATH=/home/ruralcare/Rural_care/venv/bin"
EnvironmentFile=/home/ruralcare/Rural_care/.env
ExecStart=/home/ruralcare/Rural_care/venv/bin/gunicorn \
    cancer_treatment_system.wsgi:application \
    --bind 127.0.0.1:8000 \
    --workers 3 \
    --threads 2 \
    --timeout 120 \
    --access-logfile /var/log/ruralcare/access.log \
    --error-logfile /var/log/ruralcare/error.log
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Create log directory
mkdir -p /var/log/ruralcare
chown -R ruralcare:ruralcare /var/log/ruralcare

# Enable and start Gunicorn
systemctl daemon-reload
systemctl enable ruralcare
systemctl start ruralcare

# -----------------------------------------------------------------------------
# Configure Nginx
# -----------------------------------------------------------------------------

echo "Configuring Nginx..."
cat > /etc/nginx/conf.d/ruralcare.conf << 'EOF'
server {
    listen 80;
    server_name _;

    client_max_body_size 50M;

    location /static/ {
        alias /home/ruralcare/Rural_care/staticfiles/;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    location /media/ {
        alias /home/ruralcare/Rural_care/media/;
        expires 7d;
    }

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_connect_timeout 300;
        proxy_send_timeout 300;
        proxy_read_timeout 300;
    }
}
EOF

# Remove default nginx config
rm -f /etc/nginx/conf.d/default.conf

# Test and start Nginx
nginx -t
systemctl enable nginx
systemctl restart nginx

# -----------------------------------------------------------------------------
# Setup Auto-Deployment Script
# -----------------------------------------------------------------------------

echo "Setting up deployment script..."
cat > /home/ruralcare/deploy.sh << 'DEPLOY'
#!/bin/bash
# Pull latest code and redeploy

cd /home/ruralcare/Rural_care
git pull origin ${git_branch}
source venv/bin/activate
pip install -r requirements.txt
python manage.py migrate --noinput || echo "Migration skipped"
python manage.py collectstatic --noinput
sudo systemctl restart ruralcare
echo "Deployment complete!"
DEPLOY

chmod +x /home/ruralcare/deploy.sh
chown ruralcare:ruralcare /home/ruralcare/deploy.sh

# -----------------------------------------------------------------------------
# Firewall Configuration
# -----------------------------------------------------------------------------

echo "Configuring firewall..."
systemctl start firewalld || true
systemctl enable firewalld || true
firewall-cmd --permanent --add-service=http || true
firewall-cmd --permanent --add-service=https || true
firewall-cmd --permanent --add-service=ssh || true
firewall-cmd --reload || true

# -----------------------------------------------------------------------------
# Complete
# -----------------------------------------------------------------------------

echo "=== Rural Care Setup Completed at $(date) ==="
echo "Application should be accessible at http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
