# Security Policy

## Supported Versions

Only the current main branch and latest releases receive security updates.

| Version | Supported          |
| ------- | ------------------ |
| 0.1.x   | :white_check_mark: |
| < 0.1   | :x:                |

## Reporting a Vulnerability

Security is paramount for **TopMovies**. If you discover a security vulnerability, we appreciate your help in disclosing it to us responsibly.

### How to Report

Please **do not** report security vulnerabilities through public GitHub issues.

Instead, please send an email with the details of the vulnerability to the project maintainers or open a [GitHub Private Vulnerability Report](https://github.com/your-username/topMovies/security/advisories/new) if enabled on the repository.

Please include:
- A description of the vulnerability.
- Steps to reproduce or a proof of concept.
- Potential impact and any suggested mitigations.

### What to Expect

- **Acknowledgment**: We will acknowledge receipt of your vulnerability report within 48 hours.
- **Assessment**: We will evaluate the impact and confirm the issue.
- **Fix & Disclosure**: We will work on a patch and coordinate a public release timeline with you before disclosing the vulnerability publicly.

## Security Architecture Notes

- **Credential Storage**: TMDB API Read Access Tokens are stored securely using macOS Keychain services (`kSecClassGenericPassword`), and are never persisted in plain text, user defaults, or source files.
- **Sandboxing**: TopMovies runs within the macOS App Sandbox with outgoing network access enabled solely for connecting to the user-authorized movie metadata service (TMDB) and CDN image domains.
- **Local Data Only**: All user libraries, favorites, watch history, and filter preferences remain 100% local on the user's Mac and are never tracked or transmitted to external analytical servers.
