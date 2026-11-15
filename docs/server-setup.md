# Server setup

## Ansible

- Repository: `devops-course-2026`; Ansible project: `ansible/` in the WSL home filesystem.
- Control node: Ubuntu on WSL with Ansible Core 2.16 and the collections in `ansible/requirements.yml`.
- Managed node: Ubuntu Server 24.04 amd64 at its Host-only address. Keep the machine-specific address in the local inventory files; do not commit it to this public repository.
- Bootstrap access: `sa` over SSH password authentication. This snapshot's console account is `sa`; the method sheet's example uses `student`. The local `inventory/bootstrap.ini` is copied from `inventory/bootstrap.ini.example`.
- Production access: `devops` over SSH key `~/.ssh/devops_vm`, using the local `inventory/prod.ini` copied from `inventory/prod.ini.example`; `sudo -n true` must succeed.
- Roles: `base` installs common packages and Docker Engine from Docker's official repository; `ssh` installs the automation key, sudo policy, SSH hardening, and UFW rules; `nginx` configures the HTTP reverse proxy; `app` pulls and runs the application by immutable tag.
- GHCR image: `ghcr.io/hegatnb/devops-ci-app`.
- Image tag: `d56d7eac2991426bb5a989e1284e738f646aa1e2` (full commit SHA; `latest` is not used for deployment).
- Application bind: `127.0.0.1:5000`; Nginx listens on port 80. Health endpoint: `/health`.
- Bootstrap: `ansible-playbook -i inventory/bootstrap.ini site.yml --ask-pass --ask-become-pass`.
- Repeat deploy: `ansible-playbook site.yml`.
- Read-only audit: `ansible-playbook verify.yml`.

The GHCR package is public for read access. Passwords and the private SSH key are kept outside the repository.

Before running Ansible, copy both `*.ini.example` files to the corresponding `.ini` names and replace `REPLACE_WITH_HOST_ONLY_IP` with the address shown by `ip -brief address` in the VM console. The actual `.ini` files are ignored by Git because they contain local connection details.
