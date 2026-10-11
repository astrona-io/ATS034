---
draft: true
exam_objectives:
- Use appropriate pod security standards
---
# Summary

Pod Security profiles define different levels of permitted workload configuration. Security contexts constrain process identity, capabilities, privilege changes, filesystem behavior and system calls according to supported settings.

A profile-compliant workload still needs correct application permissions, maintained dependencies and safe data handling. Configure images and mounts so applications can operate within the intended restrictions rather than removing all protection when startup fails.
