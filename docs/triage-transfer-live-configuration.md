# Private test/live configuration design

This template is a design and go-live preparation aid. It is **not yet read by
the transfer code**: the current code remains explicitly locked to the tested
1091 -> 1090 route.

Before any live access is enabled:

1. copy the template to `$SHG_CONFIG/triage_transfer_environments.json`;
2. create separate least-privilege live tokens outside Git;
3. retain `transfer_enabled: false` until the approved go-live decision;
4. refactor the controller and import script together to consume this file;
5. run and approve a live **preview** before enabling any live transfer.

The live route must not be enabled by editing the test configuration or by
changing a project ID in source code.

