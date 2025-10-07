# Mini Budget Tracker (Multi-VM, Vagrant, AWS Cloud Deployment)

## 1. Overview
The **Mini Budget Tracker** is a lightweight full-stack budgeting application demonstrating how a three-tier architecture can evolve from local virtual machines into a **cloud-native deployment** on **AWS**.

Originally developed using **Vagrant** and **VirtualBox**, the project was extended to include *Dockerized* services hosted on **AWS** **EC2** with a managed **Aurora PostgreSQL** database.
The goal is to showcase **secure multi-tier design**, **network isolation**, and **infrastructure migration** from local to cloud.

The idea of this project was to experiment with:

- Migrations from local VMs → containerized AWS services.
- Initialising EC2/RDS (Aurora PostgreSQL) instances. 
- A method of pulling from a built Docker image stored in Docker Hub.
- Secure networking using layered access control (Web → API → DB).

Manual deployment documentation for maintainability and reproducibility.

---

## 2. Cloud Architecture

| Component | AWS Service | Purpose | Access |
|------------|--------------|----------|--------|
| **Web Tier** | EC2 (Amazon Linux 2023) | Runs Nginx container serving static frontend | Public (port 80) |
| **API Tier** | EC2 (Amazon Linux 2023) | Runs Node.js Express API container | Private (port 3000) |
| **Database** | Amazon Aurora (PostgreSQL Compatible) | Persistent data store | Private subnet only |
| **Container Registry** | Docker Hub | Stores and distributes container images | Public |

### Network Layout
```
User → [Web EC2:80] → [API EC2:3000] → [Aurora RDS:5432]
```

Security groups enforce one‑directional communication (Web → API → DB).

---

## 4. 3-VM Architecture

**Request path:**

```
Browser → web (Nginx, :80)
                |
                --- /api/* (proxy) → api (Express, :3000)
                                          |
                                          ---→ db (PostgreSQL, :5432)
```

| VM/Hostname | Private IP         | Services       | Host Port-Forwards       |
| ----------- | ------------------ | -------------- | ------------------------ |
| `web`       | `<WEB_PRIVATE_IP>` | Nginx :80      | `localhost:8080 → 80`    |
| `api`       | `<API_PRIVATE_IP>` | Express :3000  | *(none)* (via web proxy) |
| `db`        | `<DB_PRIVATE_IP>`  | Postgres :5432 | *(none)* (private only)  |

---

## Prerequisites - 
Local 3-VM Setup:
- Host OS: Windows 11 (tested), macOS(tested)
    - Note that Linux has not been tested with this system and may misbehave.
- Virtualisation: VirtualBox 7.x 
- Vagrant: 2.4+
- Git

### Storage Footprint (*measured 08/09/2020*): 
VirtualBox VMs (per-VM folders):
- **api** - 3.07 GB
- **db** - 3.01 GB
- **web** - 2.69 GB
Active project VMs subtotal: **8.77 GB**

Vagrant base box
- ubuntu/focal64 - **0.57 GB**

**Total project storage: ~9.35GB** 
*note that this figure will increase with additional data being written to the database, as well as other additions to source code* 

### Cloud Hosting Cost Estimation (us‑east‑1)

| Resource | Type | Monthly Est. |
|-----------|------|--------------|
| EC2 Web | t2.micro | $7.50 |
| EC2 API | t2.micro | $7.50 |
| Aurora PostgreSQL | db.t3.micro | $15–18 |
| **Total** |  | **≈ $30–35 / month** |

---

### Windows notes
If VMs won’t start or are slow: disable Hyper-V / WSL2 features for VirtualBox.
**Helpful plugin (prevents shared-folder quirks)**
```
vagrant plugin install vagrant-vbguest
```

### Apple notes
If using a system with arm64 (Apple Silicon): note that VirtualBox support is flaky. Online resources suggest to use an ARM64 base box or a different provider (Parallels/UTM), otherwise x86_64 (Intel) should be good with defined box (***ubuntu/focal64***). 
*Note that the focal64 box is provided in the Vagrantfile and is not needed to be installed externally for this to run*


---

## 4) Quick Start
```
git clone <REPO_URL>
cd <REPO_DIR>
vagrant up            # unattended; creates & provisions 3 VMs
```

Open http://localhost:8080
- You should see seeded transactions.
- Add a transaction in the form; it should appear immediately.
- You can remove transactions and this happens immediately.

### Health checks:
**front-end (Nginx serving index)**
```
curl http://localhost:8080/
```
**API health (proxied via web → api)**
```
curl http://localhost:8080/api/health
```

---

## Repository Structure
```
.
├─ Vagrantfile
├─ provision/
│  ├─ web.sh             # Nginx + reverse proxy for /api/*
│  ├─ api.sh             # Node install, deploy to /srv/api
│  └─ db.sh              # Postgres install, create db/user, seed
├─ scripts/
│  ├─ db-migrate.sh      # Script to migrate new changes into the existing db
│  ├─ verify-db.sh       # Smoke test script for ensuring db integrity
│  └─ verify-network.sh  # Smoke test script for testing firewall and routes
├─ web/
│  ├─ Dockerfile             
│  ├─ app.js             # Script for handling frontend user interaction
│  ├─ index.html         # Static UI (fetches /api/transactions)
│  ├─ nginx.conf         # Config file for Nginx
|  └─ styles.css         # Simple css styling for the page
├─ api/
│  ├─ package-lock.json       
│  ├─ package.json       
│  ├─ Dockerfile         
│  └─ server.js          # Express routes: /health, /transactions (GET/POST/DELETE)
├─ doc/
│  └─ seqDiagram.puml    # Sequence diagram explaining logic flow
├─ env/
│  └─ prod.api.env       # Here is where you would define your environment variables
├─ db/
│  ├─ init_local.sql     # Schema + seeds applied on boot
│  ├─ init_prod.sql      # Schema + seeds applied on AWS deployment
│  └─ migrations/        # Idempotent SQL, ran using db-migrate script
└─ README.md             # What you're reading right now
```
---


## Configuration
**Networking**
- web → api: Nginx proxy to *<WEB_PRIVATE_IP>*:3000
- api → db: *<API_PRIVATE_IP>*:5432 (private subnet)

### Verification

Test connectivity after deployment:
```bash
curl http://<CHANGE THIS TO WEB IP>/api/health
curl http://<CHANGE THIS TO WEB IP>/api/version
```
Expected output:
```json
{"status":"ok"}
{"version":"0.1.0"}
```

**Isolation**
- DB is not exposed to the host; reachable only on the private network.
- Optional hardening with UFW (allow only required ports).

---

## Operational Runbook
**3-VM Setup**
These commands can be used to start the virtual machines as well as checking statuses/health of the various systems
### Lifecycle
```
vagrant up
vagrant halt
vagrant destroy -f
```

### SSH
```
vagrant ssh web
vagrant ssh api
vagrant ssh db
```

### Logs & health
```
vagrant ssh api -c "journalctl -u budget-api -f"
vagrant ssh api -c "curl -s http://localhost:3000/health"
vagrant ssh db  -c "sudo -u postgres psql -d budget -c 'select count(*) from transactions'"
```

### Restart API without full reprovision
```
vagrant ssh api -c "sudo systemctl restart budget-api"
```

**AWS Cloud Deployment**


---

## 8) Troubleshooting
With a blank install, there is a chance that the API and DB VMs don't connect, I found that reloading and provisioning both of these VMs using vagrant commands fixes it.
```
vagrant reload api db --provision
```
### Additional Issues that arose:
- **Blank UI or 502:** Nginx proxy IP/port mismatch with API; ensure **your own defined IP** is correct.
- **API unreachable:** Check service status and logs:
```
vagrant ssh api -c "systemctl status budget-api --no-pager"
vagrant ssh api -c "journalctl -u budget-api -n 200 --no-pager"
```
- **DB connection errors:** Verify Postgres is listening on private interface UFW firewall allows the API VM connection.
- **VirtualBox + Hyper-V conflicts (Windows):** Disable Hyper-V / WSL2 features or run inside WSL with a different provider.

---

## 9) Attribution

Some sections of the code in this project was adapted and inspired by sources found online, these are listed below.

**Nginx reverse proxy block** adapted from [user3003510 on Stack Overflow](https://stackoverflow.com/questions/42452101/nginx-reverse-proxy-config) and [hillefied on ProxMox](https://forum.proxmox.com/threads/using-nginx-as-reverse-proxy-externally.116127)
**Multiple VM routing skeleton** inspired by [David Eyers Lab Example](https://altitude.otago.ac.nz/cosc349/vagrant-multivm)
**UFW Firewall implementation** inspired by [Tony Teaches Techs' tutorial](https://www.youtube.com/watch?v=68GTL7djIMI&t=81s)
**Docker Setup Boilerplate** adapted from [Sloth](https://www.youtube.com/watch?v=DQdB7wFEygo&t=418s)

Additionally large language models (such as [ChatGPT 5.0](https://chatgpt.com/), and [VSC's Copilot](https://code.visualstudio.com/docs/copilot/overview) were used in debugging multiple syntax errors due to the fact that this technology is still relatively new to me, and the need to apply specific modifiers to certain commands is not something I know offhand. Though largely in whole this project was developed myself.

---

## Future Work

- Add CloudWatch monitoring & logs.  
- Use S3 + CloudFront for static hosting.
---

## 10) Support
For support or to report bugs, [open an issue](github.com/BrooklynT101/Mini-Budget-Tracker-App/issues) at the github issue tracker.

