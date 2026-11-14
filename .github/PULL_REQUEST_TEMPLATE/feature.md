name: PR Feature
description: Add a new resource, module, or infrastructure capability

body:
  - type: input
    id: summary
    name: Summary
    description: What is this adding?
    required: true

  - type: textarea
    id: context
    name: Context
    attributes:
      label: Why is this needed?
    validations:
      required: true

  - type: textarea
    id: scope
    name: Scope
    attributes:
      label: Affected resources / modules
      description: List everything touched by this PR
    validations:
      required: true

  - type: textarea
    id: checklist
    name: Checklist
    attributes:
      label: Pre-merge checklist
      value: "- [ ] `make all` passes\n- [ ] Conventional commit format used (feat:)\n- [ ] CHANGELOG updated\n- [ ] Terraform files formatted\n- [ ] No drift expected on existing state"
    validations:
      required: true
