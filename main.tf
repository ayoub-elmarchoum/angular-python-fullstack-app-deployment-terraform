terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "aws" {
  region = "ap-south-1"
}

# =====================

# Variables

# =====================

variable "vpc_id" {
  description = "L'ID du VPC"
  type        = string
  default     = "vpc-0c9864c9862bd09e0"
}

variable "igw_id" {
  description = "L'ID de l'Internet Gateway"
  type        = string
  default     = "igw-0ca642130344299c7"
}

# =====================

# Key Pair

# =====================

resource "tls_private_key" "at-devops-key-ayoub-elmarchoum" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "at-devops-key-ayoub-elmarchoum" {
  key_name   = "at-devops-key-ayoub-elmarchoum"
  public_key = tls_private_key.at-devops-key-ayoub-elmarchoum.public_key_openssh
}

# =====================

# Subnets

# =====================

resource "aws_subnet" "at-devops-public-subnet-ayoub-elmarchoum" {
  vpc_id                  = var.vpc_id
  cidr_block              = "50.20.10.0/24"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true
  tags                    = { Name = "at-devops-public-subnet-ayoub-elmarchoum" }
}

resource "aws_subnet" "at-devops-private-subnet-ayoub-elmarchoum" {
  vpc_id            = var.vpc_id
  cidr_block        = "50.20.20.0/24"
  availability_zone = "ap-south-1b"
  tags              = { Name = "at-devops-private-subnet-ayoub-elmarchoum" }
}

# =====================

# NAT Gateway + EIP

# =====================

resource "aws_eip" "at-devops-nat-eip-ayoub-elmarchoum" {
  domain = "vpc"
}

resource "aws_nat_gateway" "at-devops-nat-ayoub-elmarchoum" {
  allocation_id = aws_eip.at-devops-nat-eip-ayoub-elmarchoum.id
  subnet_id     = aws_subnet.at-devops-public-subnet-ayoub-elmarchoum.id
}

# =====================

# Route Tables

# =====================

resource "aws_route_table" "at-devops-public-rt-ayoub-elmarchoum" {
  vpc_id = var.vpc_id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = var.igw_id
  }
}

resource "aws_route_table_association" "at-devops-public-assoc-ayoub-elmarchoum" {
  subnet_id      = aws_subnet.at-devops-public-subnet-ayoub-elmarchoum.id
  route_table_id = aws_route_table.at-devops-public-rt-ayoub-elmarchoum.id
}

resource "aws_route_table" "at-devops-private-rt-ayoub-elmarchoum" {
  vpc_id = var.vpc_id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.at-devops-nat-ayoub-elmarchoum.id
  }
}

resource "aws_route_table_association" "at-devops-private-assoc-ayoub-elmarchoum" {
  subnet_id      = aws_subnet.at-devops-private-subnet-ayoub-elmarchoum.id
  route_table_id = aws_route_table.at-devops-private-rt-ayoub-elmarchoum.id
}

# =====================

# Security Groups

# =====================

resource "aws_security_group" "at-devops-public-sg-ayoub-elmarchoum" {
  name   = "at-devops-public-sg-ayoub-elmarchoum"
  vpc_id = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "at-devops-private-sg-ayoub-elmarchoum" {
  name   = "at-devops-private-sg-ayoub-elmarchoum"
  vpc_id = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.at-devops-public-sg-ayoub-elmarchoum.id]
  }
  ingress {
    from_port       = 8081
    to_port         = 8081
    protocol        = "tcp"
    security_groups = [aws_security_group.at-devops-public-sg-ayoub-elmarchoum.id]
  }
  ingress {
    from_port   = 8081
    to_port     = 8081
    protocol    = "tcp"
    cidr_blocks = ["50.20.10.0/24"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["50.20.10.0/24"]
  }


}

# =====================

# Backend EC2 (Private)

# =====================
resource "aws_instance" "at-devops-backend-ec2-ayoub-elmarchoum" {
  ami             = "ami-02b8269d5e85954ef"
  instance_type   = "t2.micro"
  subnet_id       = aws_subnet.at-devops-private-subnet-ayoub-elmarchoum.id
  key_name        = aws_key_pair.at-devops-key-ayoub-elmarchoum.key_name
  security_groups = [aws_security_group.at-devops-private-sg-ayoub-elmarchoum.id]

  tags = {
    Name    = "at-devops-backend-ec2-ayoub-elmarchoum"
    Project = "at-devops-resource-ayoub-elmarchoum"
  }

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  user_data = <<EOF
#!/bin/bash
set -e

# Chemin du script qui sera exécuté par root
DEPLOY_SCRIPT=/tmp/deploy.sh 

echo "=== Démarrage du user_data (Création et exécution de deploy.sh) ==="

# 1. Création du script deploy.sh dans /tmp avec le contenu exact fourni
cat > "$DEPLOY_SCRIPT" <<'SCRIPT'
#!/bin/bash
set -e

PROJECT_DIR=/home/ubuntu/employee-backend
SWAPFILE=/swapfile

echo "=== Exécution de deploy.sh (Démarrage du déploiement) ==="

# Création / activation swap si nécessaire
if [ ! -f "$SWAPFILE" ]; then
    echo "Création du swapfile..."
    # Utilisation de dd à la place de fallocate pour une meilleure compatibilité
    sudo dd if=/dev/zero of="$SWAPFILE" bs=1M count=2048
    sudo chmod 600 "$SWAPFILE"
    sudo mkswap "$SWAPFILE"
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
fi
sudo swapon --show || sudo swapon "$SWAPFILE"

# Mise à jour du système
echo "Mise à jour et installation des dépendances système..."
sudo apt-get clean
sudo apt update -y
sudo apt upgrade -y

# Installation des dépendances
sudo apt install -y git python3 python3-venv python3-pip build-essential python3-dev

# 3. Clonage ou mise à jour du projet (Exécuté en tant que ubuntu)
echo "Clonage, Venv, et Installation des dépendances Python par l'utilisateur 'ubuntu'..."

# Assurer que le répertoire existe et appartient à ubuntu pour le clone
sudo mkdir -p "$PROJECT_DIR"
sudo chown ubuntu:ubuntu "$PROJECT_DIR"

if [ ! -d "$PROJECT_DIR/.git" ]; then
    sudo -u ubuntu git clone https://gitlab.com/imad-omar-nabi-projects/employee-backend.git "$PROJECT_DIR"
else
    # S'assurer que les commandes cd et git pull sont exécutées dans le bon contexte et répertoire
    sudo -u ubuntu bash -c "cd \"$PROJECT_DIR\" && git pull"
fi

cd "$PROJECT_DIR"

# Création de l'environnement virtuel Python (Exécuté en tant que ubuntu)
sudo -u ubuntu python3 -m venv venv
sudo -u ubuntu ./venv/bin/pip install --upgrade pip
sudo -u ubuntu ./venv/bin/pip install -r requirements.txt

# Patch app.py pour écouter sur toutes les interfaces (Exécuté en tant que ubuntu, modifie un fichier ubuntu)
sudo -u ubuntu sed -i 's|app.run(.*)|app.run(host="0.0.0.0", port=8081)|' app.py

# Création du service systemd (Root)
echo "Création du service systemd..."
sudo tee /etc/systemd/system/employee-backend.service > /dev/null <<'SERVICE'
[Unit]
Description=Employee Backend
After=network.target

[Service]
User=ubuntu
WorkingDirectory=/home/ubuntu/employee-backend
ExecStart=/home/ubuntu/employee-backend/venv/bin/python3 app.py
Restart=always

[Install]
WantedBy=multi-user.target
SERVICE

# Activation et démarrage du service (Root)
echo "Activation et démarrage du service..."
sudo systemctl daemon-reload
sudo systemctl enable employee-backend
sudo systemctl start employee-backend
sudo systemctl status employee-backend --no-pager

echo "=== Déploiement terminé ==="
SCRIPT

# 2. Rendre le script exécutable
chmod +x "$DEPLOY_SCRIPT"

# 3. Exécuter le script généré en tant que root
bash "$DEPLOY_SCRIPT"

echo "=== Déploiement Backend terminé (user_data principal) ==="
EOF
}

# =====================

# Frontend EC2 (Public) avec NVM/Angular

# =====================

resource "aws_instance" "at-devops-frontend-ec2-ayoub-elmarchoum" {
  ami             = "ami-02b8269d5e85954ef"
  instance_type   = "t2.micro"
  subnet_id       = aws_subnet.at-devops-public-subnet-ayoub-elmarchoum.id
  key_name        = aws_key_pair.at-devops-key-ayoub-elmarchoum.key_name
  security_groups = [aws_security_group.at-devops-public-sg-ayoub-elmarchoum.id]

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }
  tags = {
    Name    = "at-devops-frontend-ec2-ayoub-elmarchoum"
    Project = "at-devops-resource-ayoub-elmarchoum"
  }
  #Copier la clé privée
  provisioner "file" {
    source      = "${path.module}/at-devops-key-ayoub-elmarchoum.pem"
    destination = "/home/ubuntu/at-devops-key-ayoub-elmarchoum.pem"
    connection {
      type        = "ssh"
      host        = self.public_ip
      user        = "ubuntu"
      private_key = tls_private_key.at-devops-key-ayoub-elmarchoum.private_key_pem
    }
  }

  #Chmod de la clé
  provisioner "remote-exec" {
    inline = ["chmod 600 /home/ubuntu/at-devops-key-ayoub-elmarchoum.pem"]
    connection {
      type        = "ssh"
      host        = self.public_ip
      user        = "ubuntu"
      private_key = tls_private_key.at-devops-key-ayoub-elmarchoum.private_key_pem
    }
  }

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = tls_private_key.at-devops-key-ayoub-elmarchoum.private_key_pem
      host        = self.public_ip
    }


    inline = [
      "#!/bin/bash",
      "set -e",
      "# Ajouter un swapfile de 4 Go",
      "sudo fallocate -l 4G /swapfile",
      "sudo chmod 600 /swapfile",
      "sudo mkswap /swapfile",
      "sudo swapon /swapfile",
      "echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab",

      "# Mettre à jour le système",
      "sudo apt update -y",
      "sudo apt upgrade -y",
      "sudo apt install -y git curl build-essential nginx",

      "# Installer NVM et Node 14",
      "export NVM_DIR=\"$HOME/.nvm\"",
      "if [ ! -d \"$NVM_DIR\" ]; then",
      "  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash",
      "fi",
      "[ -s \"$NVM_DIR/nvm.sh\" ] && source \"$NVM_DIR/nvm.sh\"",
      "nvm install 14",
      "nvm use 14",
      "nvm alias default 14",

      "# Installer Angular CLI 12 non interactif",
      "export NG_CLI_ANALYTICS=ci",
      "npm install -g @angular/cli@12 --no-optional --no-fund --silent",

      "# Cloner ou mettre à jour le projet frontend",
      "PROJECT_DIR=\"/home/ubuntu/employee-frontend\"",
      "if [ ! -d \"$PROJECT_DIR\" ]; then",
      "  git clone https://gitlab.com/imad-omar-nabi-projects/employee-frontend.git $PROJECT_DIR",
      "else",
      "  cd $PROJECT_DIR",
      "  git pull",
      "fi",
      "cd $PROJECT_DIR",

      "# Configurer l'URL du backend",
      "BACKEND_PRIVATE_IP=\"${aws_instance.at-devops-backend-ec2-ayoub-elmarchoum.private_ip}\"",
      "sed -i 's|private baseURL = \"http://localhost:8081/api/v1/employees\";|private baseURL = \"/api/v1/employees\";|' src/app/employee.service.ts || true",

      "# Installer les dépendances Angular et builder le projet",
      "npm install --silent",
      "npx ng build --configuration production --verbose=false",

      "# Détecter le sous-dossier dist généré par Angular",
      "DIST_SUBDIR=$(ls dist/ | head -n 1)",
      "echo \"Detected Angular build folder: $DIST_SUBDIR\"",

      "# Déployer sur Nginx",
      "sudo rm -rf /var/www/html/*",
      "sudo cp -r dist/$DIST_SUBDIR/* /var/www/html/",
      "sudo chown -R www-data:www-data /var/www/html",

      "# Config Nginx avec sudo tee",
      "sudo tee /etc/nginx/sites-available/employee-frontend > /dev/null << 'NGINX_CONF'",
      "server {",
      "    listen 80;",
      "    server_name ${aws_eip.at-devops-frontend-eip-ayoub-elmarchoum.public_ip};",
      "    root /var/www/html;",
      "    index index.html;",
      "    location / {",
      "        try_files $uri $uri/ /index.html;",
      "    }",
      "    location /api/ {",
      "        proxy_pass http://${aws_instance.at-devops-backend-ec2-ayoub-elmarchoum.private_ip}:8081;",
      "        proxy_http_version 1.1;",
      "        proxy_set_header Upgrade $http_upgrade;",
      "        proxy_set_header Connection 'upgrade';",
      "        proxy_set_header Host $host;",
      "        proxy_cache_bypass $http_upgrade;",
      "    }",
      "}",
      "NGINX_CONF",

      "sudo ln -sf /etc/nginx/sites-available/employee-frontend /etc/nginx/sites-enabled/",
      "sudo nginx -t",
      "sudo systemctl restart nginx"
    ]
  }
}

# =====================

# Elastic IP Frontend

# =====================

resource "aws_eip" "at-devops-frontend-eip-ayoub-elmarchoum" {
  domain = "vpc"
}
resource "aws_eip_association" "frontend_eip_assoc" {
  instance_id   = aws_instance.at-devops-frontend-ec2-ayoub-elmarchoum.id
  allocation_id = aws_eip.at-devops-frontend-eip-ayoub-elmarchoum.id
}

# =====================

# Outputs

# =====================

output "frontend_public_ip" {
  value = aws_eip.at-devops-frontend-eip-ayoub-elmarchoum.public_ip
}

output "private_key_pem" {
  value     = tls_private_key.at-devops-key-ayoub-elmarchoum.private_key_pem
  sensitive = true
}
