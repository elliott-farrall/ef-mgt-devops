name: Fix bug
description: Something is broken or behaving incorrectly

body:
  - type: textarea
    id: description
    name: Description
    attributes:
      label: What's broken?
      placeholder: Describe what you expected vs what actually happens
    validations:
      required: true

  - type: textarea
    id: steps
    name: Steps to Reproduce
    attributes:
      label: Steps to reproduce
      placeholder: |
        1. 
        2. 
        3. 

  - type: textarea
    id: terraform
    name: Terraform / State Info
    attributes:
      label: Relevant terraform state or error output
