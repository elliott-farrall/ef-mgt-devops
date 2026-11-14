name: PR Maintenance
description: CI, build tools, dependencies, cleanup, or other maintenance tasks

body:
  - type: input
    id: summary
    name: Summary
    description: What is being maintained or updated?
    required: true

  - type: textarea
    id: changes
    name: Changes
    attributes:
      label: What's changing and why?
    validations:
      required: true

  - type: textarea
    id: checklist
    name: Checklist
    attributes:
      label: Pre-merge checklist
      value: "- [ ] `make all` passes\n- [ ] Conventional commit format used (ci:/chore:)\n- [ ] No unintended infrastructure changes"
    validations:
      required: true
