# Deploy this site to AWS EC2 with GitHub Actions

This repo includes a GitHub Actions workflow that deploys the static site to an EC2 instance, installs nginx, and serves the app. Follow these steps **before** pushing to GitHub.

## 1. Create an EC2 instance

1. In **AWS Console** → EC2 → **Launch instance**.
2. **Name:** e.g. `daynight-admin`.
3. **AMI:** **Ubuntu Server** (choose the latest version; workflow installs nginx via `apt`).
4. **Instance type:** e.g. `t2.micro` (free tier).
5. **Key pair:** Create or select an existing key pair and **download the `.pem` file** (you’ll use it for GitHub and for SSH).
6. **Network / Security group:**
   - Allow **SSH (22)** from your IP or from `0.0.0.0/0` if you’re okay with GitHub’s IPs (see [GitHub IP ranges](https://api.github.com/meta) or use a self-hosted runner later).
   - Allow **HTTP (80)** from `0.0.0.0/0` so the site is reachable.
7. Launch the instance and note its **public IP** or **public DNS** (e.g. `ec2-xx-xx-xx-xx.compute-1.amazonaws.com`).

## 2. Prepare the EC2 instance for deployment

SSH into the instance (replace key and host; Ubuntu user is `ubuntu`):

```bash
ssh -i /path/to/your-key.pem ubuntu@<EC2_PUBLIC_IP_OR_DNS>
```

No need to install nginx manually; the workflow will install it via `apt` and configure `/var/www/html`.

## 3. Create a GitHub repo and add secrets

1. Create a **new repository** on GitHub (e.g. `daynight-admin`).
2. In the repo: **Settings** → **Secrets and variables** → **Actions** → **New repository secret**. Add:

   | Secret name       | Value |
   |-------------------|--------|
   | `EC2_HOST`        | EC2 public IP or public DNS (e.g. `ec2-xx-xx-xx-xx.compute-1.amazonaws.com`). No `ssh://` or port. |
   | `SSH_USER`        | `ubuntu` (Ubuntu AMI default user). |
   | `SSH_PRIVATE_KEY` | Full contents of your `.pem` file (the private key you downloaded). Copy-paste including `-----BEGIN ... KEY-----` and `-----END ... KEY-----`. |

3. Push your local repo to GitHub (main branch):

   ```bash
   git init
   git add .
   git commit -m "Initial commit"
   git branch -M main
   git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO.git
   git push -u origin main
   ```

## 4. What the workflow does

- **Trigger:** Runs on every **push to `main`** (change `branches` in `deploy.yml` if you use another branch).
- **Steps:**
  1. Checkout the repo.
  2. Configure SSH using `SSH_PRIVATE_KEY` and `EC2_HOST`.
  3. SSH into EC2 and **install nginx** (if not already installed), create `/var/www/html`, set ownership, point nginx’s default config at `/var/www/html`, and start nginx.
  4. **Rsync** the project files (excluding `.git` and `.github`) to `/var/www/html/` on the instance.
  5. **Reload nginx** so the new files are served.

After a successful run, open `http://<EC2_PUBLIC_IP_OR_DNS>` in a browser to see the site.

## 5. Optional: restrict SSH to GitHub IPs

To allow only GitHub Actions (and optionally your IP) to SSH:

- In the EC2 security group, replace “any” for port 22 with:
  - Your IP for manual SSH, and/or
  - GitHub’s IP ranges (from the [API meta](https://api.github.com/meta) – “actions” or “hooks” list). These change occasionally, so some people use a small CIDR or a self-hosted runner in a fixed VPC instead.

## 6. Troubleshooting

- **Permission denied (publickey):** Check that `SSH_PRIVATE_KEY` is the full `.pem` content and that `SSH_USER` matches your AMI (`ec2-user` for Amazon Linux, `ubuntu` for Ubuntu).
- **Connection timed out:** Security group must allow TCP 22 from the IPs GitHub Actions uses (or from anywhere for testing).
- **Site not loading:** Ensure port 80 is open in the security group and that the “Install nginx and prepare docroot” and “Reload nginx” steps completed without errors in the workflow log.
