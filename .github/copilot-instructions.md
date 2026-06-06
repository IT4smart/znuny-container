# Copilot Instructions for znuny-container
Znuny is an Open-Source Ticketing system which based on OTRS. This repository contains a Docker container image for Znuny, along with related scripts and configuration files.
Sources: https://www.znuny.org/de
Documentation: https://doc.znuny.org/

Currently we only support non LTS releases of Znuny.

## Issue and Pull Request Workflow

### Issue Handling Policy

**Every issue must be accompanied by a pull request.** Issues serve as tracking and discussion points, but all changes must be submitted through pull requests.

### Pull Request Requirements

1. **Link to Issue**: Every pull request must reference the related issue in the description
2. **Branch Naming**: Use descriptive branch names that relate to the issue content
3. **Testing**: Ensure that all changes pass the `container-image-test` workflow before review

### Copilot Review Role

Copilot is authorized to:
- Review pull requests for code quality and consistency
- Verify that changes follow project conventions
- Check for common issues (permission problems, backup failures, Docker configuration)
- Request changes or improvements to the implementation
- Provide feedback on code structure and best practices
- Test proposed changes against the container image test workflow

### Copilot Restrictions

Copilot **MUST NOT**:
- Approve pull requests for merging
- Merge pull requests into any branch
- Mark pull requests as "ready for merge"
- Override human decision-making on merge eligibility

**Only human reviewers can approve and merge pull requests.**

### Merge Decision Process

1. Copilot reviews the pull request and provides feedback
2. Author addresses Copilot feedback if requested
3. **A human reviewer** evaluates the pull request
4. **A human reviewer** approves the pull request
5. **A human** merges the pull request

### Important Notes

- All code changes must address an existing issue
- Pull request titles should be clear and descriptive
- Update relevant documentation when making changes to:
  - Container configuration (Dockerfile)
  - Scripts (backup, entrypoint, utility functions)
  - GitHub workflows
  - Docker Compose setup
- Ensure backward compatibility unless explicitly changing API/interface

### Non-Root Container Requirement (Key Feature)

**The Znuny container must run entirely as a non-root user.** This is a critical security feature and fundamental architectural requirement.

**Requirements for all pull requests:**

1. **No root processes** - All services (Apache, Cron, Supervisord, Znuny Daemon) must run as the `znuny` user
2. **No root entrypoint** - The container should not stay running as root after initialization
3. **Privilege separation** - Only privileged setup operations (certificate generation, permission fixing) may run as root, but must immediately switch to `znuny` user via `su` or `exec`
4. **Testing verification** - All PRs must include evidence that:
   - The container runs as non-root: `docker exec <container> whoami` returns `znuny`
   - All services are owned by znuny: `docker exec <container> ps aux` shows znuny user for Apache, Cron, Supervisord, etc.
   - No root processes remain: `docker exec <container> ps aux | grep root` should show minimal system processes only

**Common violations to avoid:**
- Using `USER root` in Dockerfile without switching back to `znuny`
- Running supervisord as root (must run as znuny)
- Apache/Cron processes started as root instead of znuny
- Scripts that require root without proper privilege escalation/drop

---

**Last Updated**: 2026-06-06
