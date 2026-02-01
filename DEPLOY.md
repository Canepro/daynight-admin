# Deploy daynight-admin to AWS

This repo has two workflows:

1. **CI** – Builds the Docker image and pushes it to ECR (tags: `:run_number`, `:latest`).
2. **Deploy to EC2** – Runs after CI on `main` (or manually), SSHs to EC2, pulls `:latest` from ECR, and runs the container on port 80.

---

## GitHub secrets

**Settings → Secrets and variables → Actions** – add:

| Secret | Used by | Value |
|--------|---------|--------|
| `AWS_ACCESS_KEY_ID` | CI (build + push to ECR) | Your AWS access key |
| `AWS_SECRET_ACCESS_KEY` | CI | Your AWS secret key |
| `EC2_HOST` | Deploy | EC2 public IP or DNS (e.g. `ec2-xx-xx.compute-1.amazonaws.com`) |
| `SSH_USER` | Deploy | `ubuntu` (Ubuntu AMI) |
| `SSH_PRIVATE_KEY` | Deploy | Full contents of your `.pem` file |

---

## ECR

Create the repository (once) in **us-east-1**:

```bash
aws ecr create-repository --repository-name daynight-admin --region us-east-1
```

Attach the policy in `ecr-policy.json` to the IAM user used by CI (e.g. `remote-user`).

---

## EC2 instance (for Deploy workflow)

1. **Launch** – Ubuntu, latest; key pair (save `.pem` for `SSH_PRIVATE_KEY`); security group: **SSH (22)** and **HTTP (80)**.
2. **IAM instance profile** – Attach a role that can pull from ECR, e.g. policy:

   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Action": "ecr:GetAuthorizationToken",
         "Resource": "*"
       },
       {
         "Effect": "Allow",
         "Action": [
           "ecr:BatchCheckLayerAvailability",
           "ecr:GetDownloadUrlForLayer",
           "ecr:BatchGetImage"
         ],
         "Resource": "arn:aws:ecr:us-east-1:534208808141:repository/daynight-admin"
       }
     ]
   }
   ```

   Create a role with this policy and attach it to the EC2 instance (Instance → Actions → Security → Modify IAM role).

3. **Docker on EC2** – After first login:

   ```bash
   ssh -i your-key.pem ubuntu@<EC2_HOST>
   sudo apt-get update && sudo apt-get install -y docker.io
   sudo usermod -aG docker ubuntu
   # Log out and back in so `docker` works without sudo
   ```

   (Or use an AMI / user data that installs Docker.)

4. **AWS CLI on EC2** (for ECR login):

   ```bash
   sudo apt-get install -y awscli
   ```

   The instance profile supplies credentials; no keys on the host.

---

## Flow

- **Push to `main`** → CI runs → image pushed to ECR (`:run_number`, `:latest`) → Deploy runs → EC2 pulls `:latest` and restarts the container.
- **Manual deploy** → Actions → “Deploy to EC2” → Run workflow → EC2 pulls `:latest` and restarts.

After a successful deploy, open `http://<EC2_HOST>` in a browser.

---

## Troubleshooting

- **Deploy: Permission denied (publickey)** – Check `SSH_PRIVATE_KEY` (full `.pem`) and `SSH_USER` (e.g. `ubuntu`).
- **Deploy: Connection timed out** – Security group must allow TCP 22 from GitHub Actions IPs (or your IP / `0.0.0.0/0` for testing).
- **EC2: Cannot pull image / access denied** – Instance must have an IAM role with ECR pull permission for `daynight-admin`.
- **Site not loading** – Port 80 must be open in the security group; on EC2 run `docker ps` and `docker logs daynight-admin`.
