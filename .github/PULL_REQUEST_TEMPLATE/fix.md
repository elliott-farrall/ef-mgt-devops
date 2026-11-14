name: PR Fix
description: Submit a bug fix for an existing issue or defect

body:
  - type: input
    id: summary
    name: Summary
    description: What bug does this fix?
    required: true

  - type: textarea
    id: root_cause
    name: Root Cause
    attributes:
      label: What was causing the problem?
    validations:
      required: true

  - type: textarea
    id: scope
    name: Scope
    attributes:
      label: Affected resources
      description: Which terraform resources are impacted? Any state drift expected?
    validations:
      required: true

  - type: textarea
    id: checklist
    name: Checklist
    attributes:
      label: Pre-merge checklist
      value: "- [ ] `make all` passes\n- [ ] Conventional commit format used (fix:)\n- [ ] CHANGELOG updated\n- [ ] Terraform files formatted\n- [ ] No destructive changes to state"
    validations:
      required: true
