# README — create_users.sh

## Purpose

`create_users.sh` automates Linux user creation from a simple text file. It:

* Parses lines in the form `username; group1,group2`.
* Ignores blank lines and lines beginning with `#` (comments).
* Creates groups if missing, creates users (or updates existing ones), ensures home directories exist with secure permissions, generates a 12-character random password, sets it for the user, and stores `username:password` in `/var/secure/user_passwords.txt`.
* Logs all actions to `/var/log/user_management.log`.

## Design highlights

* Requires root privileges (user management needs root).
* Safe handling of existing users and groups.
* Passwords stored in a restricted file (`/var/secure/user_passwords.txt`, mode 600).
* Log file is `/var/log/user_management.log` with mode 600 to limit access.
* Uses `openssl` when available for random generation, falls back to `/dev/urandom` otherwise.
* Uses `chpasswd` to set password, and `usermod`/`useradd` to manage accounts.

## Step-by-step explanation

1. **Argument parse & root check**: The script expects one argument — the input file. It exits if not run as root.
2. **Prepare files**: Creates/ensures `/var/log/user_management.log` and `/var/secure/user_passwords.txt` exist and have `600` permissions.
3. **Read input file** line-by-line:

   * Skip blank lines and lines starting with `#`.
   * Strip inline comments after `#`.
   * Split by `;` into `username` and the group list.
   * Normalize the group list (remove spaces), create groups if missing.
4. **User handling**:

   * If user exists: append supplementary groups with `usermod -a -G` and ensure home directory exists and has `700` perms.
   * If user doesn't exist: create with `useradd -m -s /bin/bash` and set supplementary groups.
5. **Password generation & storage**:

   * Generate a 12-character password using `openssl` or `/dev/urandom`.
   * Set password via `chpasswd`.
   * Append `username:password` to `/var/secure/user_passwords.txt` (protected with `flock` if available).
6. **Logging**: All important steps (creation, errors, skips) are logged to `/var/log/user_management.log` with timestamps.

## Example input file (`users.txt`)

```
# New hires
light; sudo,dev,www-data
siyoni; sudo
manoj; dev,www-data

# contractor; temp
```

## Example usage

1. Copy the `create_users.sh` script to a Linux machine and mark it executable:

```bash
sudo cp create_users.sh /usr/local/bin/create_users.sh
sudo chmod +x /usr/local/bin/create_users.sh
```

2. Run the script as root (example):

```bash
sudo /usr/local/bin/create_users.sh /path/to/users.txt
```

3. After the script completes:

* Check `/var/log/user_management.log` for details.
* Check `/var/secure/user_passwords.txt` for `username:password` entries (file mode 600).

## Security considerations

* **Password storage**: This script stores plain-text passwords in `/var/secure/user_passwords.txt` for initial distribution. This is sometimes necessary for large onboarding, but it's a sensitive file. Consider these alternatives for production:

  * Use temporary passwords and require `chage -d 0` to force password change at first login.
  * Use a secret manager (HashiCorp Vault, AWS Secrets Manager) to store credentials instead of a plain file.
  * Use SSH key provisioning rather than passwords.
* **Access control**: Ensure only authorized admins can read `/var/secure/user_passwords.txt` and `/var/log/user_management.log` (both are created with `600`).
* **Transport**: Do not email these passwords in cleartext. Use secure channels (e.g., have users retrieve a temporary password from a secure portal).
* **Audit**: Keep logs and rotate them; avoid leaving passwords in logs. This script does not write passwords to the log.

rary password via a secure SMTP server.
* Add an option to force password-change on first login.
