name: Housekeeping / maintenance
description: CI, build tools, dependencies, cleanup, or other maintenance tasks

body:
  - type: textarea
    id: context
    name: Context
    attributes:
      label: What needs to be done and why?
      placeholder: E.g. update a tool version, clean up deprecated config, pin a dependency version
    validations:
      required: true
