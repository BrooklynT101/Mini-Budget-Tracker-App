# Mini Budget Tracker (Multi-VM, Vagrant)

### A small 3-VM app demostrating portable build & deployment with virtualisation:
Focus: unattended builds, isolation, reproducibility, and a clean developer workflow.
- **web** VM: static frontend via Nginx (serves `/` and proxies `/api/*`)
- **api** VM: Node/Express REST API
- **db** VM: PostgreSQL (persisted data)
---

## 1) Overview

- **Goal:** Show clean, automated provisioning across multiple VMs with data persistence and a minimal testable app.
- **User story:** View/add/remove transactions; data stored in PostgreSQL.
- **Demo Goal:** `vagrant up` → services come online unattended → seeded data visible → simple POST works.

---

## 2) Architecture

Request path:

**Browser** → **web** (Nginx, :80)
**web** → **/api/*** (proxy) → **api** (Express, :3000) 
**api** → **db** (PostgreSQL)

| VM/Hostname | Private IP      | Service6(s)     | Host Port-Forwards       |
| ----------- | --------------- | -------------- | ------------------------ |
| `web`       | `192.168.56.10` | Nginx :80      | `localhost:8080 → 80`    |
| `api`       | `192.168.56.11` | Express :3000  | *(none)* (via web proxy) |
| `db`        | `192.168.56.13` | Postgres :5432 | *(none)* (private only)  |

# Prerequisites 
## Install Vagrant
brew install --cask vagrant
vagrant --version

## Helpful plugin (prevents shared-folder weirdness)
vagrant plugin install vagrant-vbguest

If x86_64 (Intel): should be good with defined box.

If arm64 (Apple Silicon): VirtualBox support is flaky; internet suggests to use an ARM64 base box or a different provider (Parallels/UTM)

## 12) Troubleshooting

Blank UI or 502: Nginx proxy target IP/port mismatch with API; ensure 192.168.56.11:3000 (or your chosen) is correct.

API unreachable: Check service status and logs:

vagrant ssh api -c "systemctl status budget-api --no-pager"
vagrant ssh api -c "journalctl -u budget-api -n 200 --no-pager"


DB connection errors: Verify Postgres is listening on private interface and pg_hba.conf allows the API VM subnet.

Windows CRLF issues: Convert scripts:

dos2unix provision/*.sh


VirtualBox + Hyper-V conflicts (Windows): Disable Hyper-V / WSL2 features or run inside WSL with a different provider.