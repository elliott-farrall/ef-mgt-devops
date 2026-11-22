name: Add feature
description: Request a new resource, module, or infrastructure capability

body:
  - type: textarea
    id: problem
    name: Problem
    attributes:
      label: What problem does this solve?
      placeholder: Describe the gap you're hitting and what you want to achieve
    validations:
      required: true

  - type: textarea
    id: solution
    name: Proposed Solution
    attributes:
      label: How would you approach it?

  - type: textarea
    id: criteria
    name: Acceptance Criteria
    attributes:
      label: Acceptance criteria
      value: "- [ ] "
    validations:
      required: true
