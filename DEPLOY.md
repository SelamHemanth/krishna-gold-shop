# Deploying Krishna Gold Shop to AWS

The shop runs on one small Linux server in AWS (EC2). Customers' data never leaves that server
except in the backups you download. Everything is installed and updated from this computer with
the scripts in [`deploy/`](deploy).

## What is running now

| | |
|---|---|
| Website | https://krishnagoldshop.duckdns.org |
| Old address (redirects to the website) | https://16-178-98-76.sslip.io |
| AWS region | Asia Pacific (Sydney) `ap-southeast-2` |
| Server | EC2 `t3.micro` (2 vCPU, 1 GB RAM + 2 GB swap), 20 GB gp3 disk, Ubuntu 26.04 LTS |
| Fixed IP (Elastic IP) | `16.178.98.76` |
| SSH key on this computer | `~/.ssh/krishna-gold-shop.pem` (original in Windows `Downloads`) |
| Login user on the server | `ubuntu` |

Keep `krishna-gold-shop.pem` safe and private. It is the only way into the server and AWS cannot
send it again. Never commit it, and never commit anything from `data/` (database, photos and the
local HTTPS key in `data/certs/`).

## How it fits together

```
Phone / PC browser
   │  https://krishnagoldshop.duckdns.org   (DuckDNS: name -> 16.178.98.76)
   ▼
Caddy  (ports 80 + 443, free Let's Encrypt certificate, renews itself, http -> https)
   │  http://127.0.0.1:8787   (not reachable from the internet)
   ▼
App  (systemd service "krishna-gold-shop", Node.js 22 + tsx, runs as user "kgs")
   │
   ▼
/var/lib/krishna-gold-shop/data      database (shop.db) and photos
/var/lib/krishna-gold-shop/backups   automatic database backups (last 30)
```

| On the server | What it is |
|---|---|
| `/opt/krishna-gold-shop` | The app (replaced on every deploy) |
| `/var/lib/krishna-gold-shop` | Data and backups (kept on every deploy) |
| `/etc/krishna-gold-shop.env` | App settings (`HOST=127.0.0.1`, `TRUST_PROXY`, `COOKIE_SECURE`, paths) |
| `/etc/krishna-gold-shop.domain` | The website name, remembered for later deploys |
| `/etc/caddy/Caddyfile` | HTTPS and the redirect from the old address |
| `/etc/systemd/system/krishna-gold-shop.service` | Starts the app at boot and restarts it if it stops |

## First-time setup (what was done)

### 1. AWS account

1. Sign up at [aws.amazon.com](https://aws.amazon.com) and choose the **Free plan** (card and
   phone are needed for verification).
2. Optional but recommended: search **Budgets** → **Create budget** → **Zero spend budget**, enter
   your email. AWS then emails you before anything costs money.

### 2. The server (EC2)

1. Top-right region menu: pick the region (Mumbai `ap-south-1` is closest to India; the current
   server is in Sydney).
2. Search **EC2** → **Launch instance**:
   - Name: `krishna-gold-shop`
   - Image: **Ubuntu Server** LTS (24.04 or newer), 64-bit (x86)
   - Instance type: **t3.micro** (Free tier eligible)
   - Key pair: **Create new key pair** → name `krishna-gold-shop`, **RSA**, **.pem** →
     **Create key pair**. The browser downloads `krishna-gold-shop.pem` (only this once).
   - Network settings: **Allow SSH traffic from Anywhere**, tick **Allow HTTPS traffic from the
     internet** and **Allow HTTP traffic from the internet**. (SSH still needs the key file.)
   - Storage: **20 GiB gp3**
   - **Launch instance**, then wait until **Instance state** is **Running**.
3. Fixed address: left menu **Network & Security → Elastic IPs** → **Allocate Elastic IP
   address** → **Allocate**. Select it → **Actions → Associate Elastic IP address** → Instance
   `krishna-gold-shop` → **Associate**. Without this the IP changes whenever the server stops.

### 3. The website name (DuckDNS, free)

1. Open [duckdns.org](https://www.duckdns.org) and sign in with Google or GitHub.
2. Sub domain `krishnagoldshop` → **add domain**.
3. In its row set **current ip** to the Elastic IP (`16.178.98.76`) → **update ip**.

The Elastic IP never changes, so this never needs updating. Do not share the DuckDNS token.

### 4. Install

From this folder on this computer (WSL):

```bash
./deploy/deploy.sh 16.178.98.76 /mnt/c/Users/hemselam/Downloads/krishna-gold-shop.pem krishnagoldshop.duckdns.org
```

The script:

1. Copies the key to `~/.ssh/krishna-gold-shop.pem` with private permissions (SSH refuses keys
   under `/mnt/c` because Windows files cannot be made private).
2. Builds the web app here (`npm run build`).
3. Uploads the code with `rsync` (without `node_modules`, `.git`, `data`, `backups`, `logs`, `.env`).
4. Runs [`deploy/server-setup.sh`](deploy/server-setup.sh) on the server as root (safe to repeat):
   2 GB swap file, system packages and automatic security updates, Node.js 22 (NodeSource),
   Caddy, the `kgs` user, the data folders, `/etc/krishna-gold-shop.env`, the systemd service
   and the Caddyfile.
5. Runs [`deploy/server-install.sh`](deploy/server-install.sh): copies the code to
   `/opt/krishna-gold-shop`, `npm ci`, restarts the app and waits until it answers.
6. Prints the website address and, on the very first install, the owner's one-time password.

The first install takes about 2 minutes. Caddy gets the certificate within seconds of starting.

### 5. First sign-in

Sign in as `owner` with the one-time password printed by the script. The app asks for a new
password straight away. After that the one-time password is deleted from the server, and the
next deploy deletes the leftover copy in `/root/krishna-gold-shop-first-password`.

Then open **Settings → Configuration** and set the shop name and interest rules. The cloud shop
started empty; data from the shop PC was not copied.

## Everyday tasks

### Update the website after code changes

```bash
./deploy/deploy.sh 16.178.98.76 ~/.ssh/krishna-gold-shop.pem
```

The data is kept and the name is remembered. The app is down for a few seconds while it restarts.

### Download backups and photos to this computer

```bash
./deploy/download-backup.sh 16.178.98.76 ~/.ssh/krishna-gold-shop.pem
```

Saves `backups/cloud-<date>.tar.gz` (database backups + photos). Do this regularly: if the
server or the AWS account is lost, the backups on the server are lost with it.

### Forgotten password

```bash
./deploy/reset-password.sh 16.178.98.76 ~/.ssh/krishna-gold-shop.pem          # owner
./deploy/reset-password.sh 16.178.98.76 ~/.ssh/krishna-gold-shop.pem <user>   # another user
```

It asks for the new password twice (hidden) and sends it over SSH. No restart is needed.

### Look at the server

```bash
ssh -i ~/.ssh/krishna-gold-shop.pem ubuntu@16.178.98.76
sudo systemctl status krishna-gold-shop caddy     # are both running?
sudo journalctl -u krishna-gold-shop -f           # app log (Ctrl+C to stop)
sudo journalctl -u caddy -n 50                    # HTTPS / certificate log
sudo systemctl restart krishna-gold-shop          # restart the app
```

### Change the website name

Point the new name at `16.178.98.76` (DuckDNS or your own domain's DNS **A record**), then:

```bash
./deploy/deploy.sh 16.178.98.76 ~/.ssh/krishna-gold-shop.pem new-name.example.com
```

Caddy gets a certificate for the new name automatically. A bought domain (`.in`, `.com`,
`.shop`, about ₹100–1,000 a year) works the same way.

## Costs

- New AWS accounts on the **Free plan** get credits for 6 months; this server costs nothing
  during that time.
- After that the account must be upgraded to a paid plan or AWS closes it. This setup then costs
  roughly **$12–15 a month** (server, disk and the public IPv4 address). Download a backup first.
- Cheaper later options: AWS Lightsail's smallest plan, or running it again on the shop PC
  (`./run.sh start`).
- To stop all charges: **EC2 → Instances → Terminate**, then **Elastic IPs → Release**. An Elastic
  IP that is not attached to a running server is charged.

## Troubleshooting

| Problem | Cause and fix |
|---|---|
| Website does not open from the office network | The company's Zscaler filter blocks `duckdns.org` names. It works on mobile data, home Wi-Fi and the shop's internet. |
| `ssh: connect ... timed out` | The EC2 security group must allow SSH (port 22). Some office networks block outgoing SSH; try another network. |
| `UNPROTECTED PRIVATE KEY FILE` | Use `~/.ssh/krishna-gold-shop.pem` (mode 600), not the copy under `/mnt/c`. |
| Certificate error in the browser | The name must point to `16.178.98.76` (check on duckdns.org) and ports 80 and 443 must be open in the security group. See `sudo journalctl -u caddy -n 50`. |
| Website shows "502" | The app is not running: `sudo journalctl -u krishna-gold-shop -n 50`, then `sudo systemctl restart krishna-gold-shop`. |
| Server is slow or out of memory | `free -m`. The 2 GB swap file normally covers it; a `t3.small` has 2 GB RAM. |

## Moving to another region (for example Mumbai)

1. Download a backup (above).
2. Create the new server and Elastic IP in the new region, update DuckDNS to the new IP and run
   `deploy.sh` with the new IP and the name.
3. To bring the data along: on the new server `sudo systemctl stop krishna-gold-shop`, delete
   `/var/lib/krishna-gold-shop/data/shop.db*`, copy the newest `shop-*.db` from the backup there
   as `shop.db` and the photos to `/var/lib/krishna-gold-shop/data/photos/`, run
   `sudo chown -R kgs:kgs /var/lib/krishna-gold-shop`, then `sudo systemctl start krishna-gold-shop`.
   Sign in with the old shop's password.
4. Terminate the old server and release its Elastic IP.
