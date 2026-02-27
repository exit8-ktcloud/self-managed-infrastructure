# Exit8 Ansible Configuration

## Directory Structure

```
ansible/
├── inventory/
│   └── hosts.ini        # Target hosts
├── group_vars/
│   └── all.yml          # Global variables
├── roles/
│   ├── docker/
│   │   ├── tasks/main.yml
│   │   └── handlers/main.yml
│   ├── exit8-app/
│   │   ├── tasks/main.yml
│   │   ├── handlers/main.yml
│   │   └── templates/
│   │       ├── env.j2
│   │       ├── cloud-sql-proxy.service.j2
│   │       └── backup.sh.j2
│   └── monitoring/
│       ├── tasks/main.yml
│       └── handlers/main.yml
├── site.yml             # Main playbook
└── README.md
```

## Usage

### Prerequisites

1. Ansible installed on control machine:
   ```bash
   pip install ansible
   ```

2. SSH access to target VM configured

3. Terraform outputs available for environment variables

### Setup

1. Update `inventory/hosts.ini` with target VM IP:
   ```ini
   [exit8]
   exit8-vm ansible_host=<VM_EXTERNAL_IP> ansible_user=ubuntu
   ```

2. Create terraform outputs file:
   ```bash
   cd infra/terraform
   terraform output -json > ../ansible/terraform_outputs.json
   ```

3. Set required environment variables:
   ```bash
   export DB_PASSWORD=$(gcloud secrets versions access latest --secret=exit8-db-password)
   export CLOUD_SQL_PRIVATE_IP=$(terraform output -raw cloud_sql_private_ip)
   export REDIS_HOST=$(terraform output -raw redis_host)
   ```

### Run Playbook

Full provisioning:
```bash
ansible-playbook -i inventory/hosts.ini site.yml
```

Run specific roles:
```bash
# Docker only
ansible-playbook -i inventory/hosts.ini site.yml --tags docker

# Application only
ansible-playbook -i inventory/hosts.ini site.yml --tags app

# Monitoring only
ansible-playbook -i inventory/hosts.ini site.yml --tags monitoring
```

### Check Mode (Dry Run)

```bash
ansible-playbook -i inventory/hosts.ini site.yml --check
```

### Verbose Output

```bash
ansible-playbook -i inventory/hosts.ini site.yml -v
```

## Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `app_dir` | `/opt/exit8` | Application directory |
| `db_host` | - | Cloud SQL private IP |
| `db_port` | 5432 | PostgreSQL port |
| `db_name` | exit8_app | Database name |
| `redis_host` | - | Memorystore Redis host |
| `redis_port` | 6379 | Redis port |
| `docker_compose_version` | 2.24.0 | Docker Compose version |

## Post-Provisioning

After running the playbook:

1. SSH into the VM:
   ```bash
   gcloud compute ssh exit8-vm --zone=asia-northeast3-a
   ```

2. Verify services:
   ```bash
   cd /opt/exit8
   docker-compose ps
   docker-compose logs -f
   ```

3. Check monitoring:
   ```bash
   curl http://localhost:9100/metrics
   ```

## Troubleshooting

### Docker permission denied
```bash
sudo usermod -aG docker ubuntu
# Logout and login again
```

### Cloud SQL Proxy not connecting
```bash
# Check service status
sudo systemctl status cloud-sql-proxy
# Check logs
journalctl -u cloud-sql-proxy -f
```

### Application not starting
```bash
cd /opt/exit8
docker-compose logs service-a-backend
docker-compose logs service-b-backend
```
