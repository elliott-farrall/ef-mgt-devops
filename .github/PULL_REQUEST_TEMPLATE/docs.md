name: PR Documentation
description: Update docs, runbooks, resource maps, or other documentation

body:
  - type: input
    id: summary
    name: Summary
    description: What documentation is being changed?
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
      value: "- [ ] Conventional commit format used (docs:)\n- [ ] CHANGELOG updated\n- [ ] No unintended infrastructure changes"
    validations:
      required: true
