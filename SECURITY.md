# Security Policy

## Supported Versions

All tagged versions are supported with security updates, unless otherwise mentioned in the release notes, changelog and README.

## Reporting a Vulnerability

Create an issue using 'Report a security vulnerability' template. We will try to fix it as soon as possible.

## Security Updates

We will try to fix the vulnerability as soon as possible. We will release a new version with the fix and publish it to the marketplace. We will also update the changelog and release notes with the details of the vulnerability and the fix.

Following the semantic versioning as per [semver.org](https://semver.org/), we will release a new patch version for each major.minor version. For example, if the current version is 1.2.3, we will release a new version 1.2.4 with the fix. If the current version is 1.2.0, we will release a new version 1.2.1 with the fix.

If the vulnerability is critical, we will release a new minor version. For example, if the current version is 1.2.3, we will release a new version 1.3.0 with the fix. If the current version is 1.2.0, we will release a new version 1.3.0 with the fix.

If the vulnerability is critical and the fix is not backward compatible, we will release a new major version. For example, if the current version is 1.2.3, we will release a new version 2.0.0 with the fix. If the current version is 1.2.0, we will release a new version 2.0.0 with the fix.

Below is are the examples of released versions and the next version after the fix, assuming the current version is 3.5.0, and the vulnerability is reported after 2.5.0 is released.

| Vulnerability type                | Current Version | Fixed Version |
| --------------------------------- | --------------- | ------------- |
| Critical(Backward compatible)     | 3.5.0           | 3.6.0         |
| Critical(Not backward compatible) | 3.5.0           | 4.0.0         |
| Non-critical                      | 3.5.0           | 3.5.1         |
| Non-critical                      | 2.5.0           | 2.5.1         |
| Non-critical                      | 1.5.0           | no fix        |
| Non-critical                      | 2.4.9           | no fix        |

## Responsible Disclosure

We will try to fix the vulnerability as soon as possible. We will release a new version with the fix and publish it to the marketplace. We will also update the changelog and release notes with the details of the vulnerability and the fix.

## Report abuse of the Code of Conduct

If you believe someone is violating the Code of Conduct, we ask that you report it by emailing at admin@codevedas.com
