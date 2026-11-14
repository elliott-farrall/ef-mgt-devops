locals {
  env_dir = "${path.root}/../environments/${var.environment}"

  # One file per platform concern; alphabetical merge keeps this order stable.
  config = merge([for f in sort(fileset(local.env_dir, "*.yaml")) : yamldecode(file("${local.env_dir}/${f}"))]...)

  gcp = local.config.gcp
  tfc = local.config.tfc
  cf  = local.config.cf
  gh  = local.config.gh

  # GCP folder tree -> flat keyed nodes (name -> parent folder, "" = org
  # root). HCL has no recursion, so the tree is unrolled per depth level and
  # merged; the depth guard fails any plan that nests beyond 4 folder levels.
  folder_nodes_1 = { for f in local.gcp.folders : f.name => "" }

  folder_nodes_2 = merge(
    [for f in local.gcp.folders :
      { for c in try(f.folders, []) : c.name => f.name }
    ]...
  )

  folder_nodes_3 = merge(
    [for f in local.gcp.folders : merge(
      [for c in try(f.folders, []) :
        { for g in try(c.folders, []) : g.name => c.name }
      ]...
    )]...
  )

  folder_nodes_4 = merge(
    [for f in local.gcp.folders : merge(
      [for c in try(f.folders, []) : merge(
        [for g in try(c.folders, []) :
          { for d in try(g.folders, []) : d.name => g.name }
        ]...
      )]...
    )]...
  )

  project_nodes_1 = merge(
    [for f in local.gcp.folders :
      { for p in try(f.projects, []) : p => f.name }
    ]...
  )

  project_nodes_2 = merge(
    [for f in local.gcp.folders : merge(
      [for c in try(f.folders, []) :
        { for p in try(c.projects, []) : p => c.name }
      ]...
    )]...
  )

  project_nodes_3 = merge(
    [for f in local.gcp.folders : merge(
      [for c in try(f.folders, []) : merge(
        [for g in try(c.folders, []) :
          { for p in try(g.projects, []) : p => g.name }
        ]...
      )]...
    )]...
  )

  project_nodes_4 = merge(
    [for f in local.gcp.folders : merge(
      [for c in try(f.folders, []) : merge(
        [for g in try(c.folders, []) : merge(
          [for d in try(g.folders, []) :
            { for p in try(d.projects, []) : p => d.name }
          ]...
        )]...
      )]...
    )]...
  )

  gcp_folder_nodes = {
    for k, v in merge(
      local.folder_nodes_1, local.folder_nodes_2,
      local.folder_nodes_3, local.folder_nodes_4,
    ) : k => { parent = v }
  }

  gcp_project_nodes = {
    for k, v in merge(
      local.project_nodes_1, local.project_nodes_2,
      local.project_nodes_3, local.project_nodes_4,
    ) : k => { parent = v }
  }

  # True when a 5th folder level exists anywhere in the tree.
  gcp_tree_too_deep = length(flatten(
    [for f in local.gcp.folders : flatten(
      [for c in try(f.folders, []) : flatten(
        [for g in try(c.folders, []) : flatten(
          [for d in try(g.folders, []) : try(d.folders, [])]
        )]
      )]
    )],
  )) > 0

  repository      = basename(abspath("${path.root}/.."))
  landing_project = local.gcp.landing_project
  gcp_region      = local.gcp.region
  tfc_hostname    = local.tfc.hostname

  tfc_plane_project = "ef-${var.environment}"

  # TFC: flatten the nested project -> workspaces declarations into keyed
  # nodes. Depth is fixed at two levels (the platform's own limit).
  tfc_project_names = [for p in local.tfc.projects : p.name]

  tfc_workspace_list = flatten([for p in local.tfc.projects : [for ws in try(p.workspaces, []) : { name = ws.name, project = p.name, repo = ws.repo, working_directory = ws.working_directory, auto_apply = ws.auto_apply }]])

  tfc_workspace_nodes = { for w in local.tfc_workspace_list : w.name => w }

  # GitHub platform defaults; registry entries override via optional
  # settings: (repository) and protection: (branch rule) blocks.
  gh_repository_defaults = {
    visibility             = "private"
    has_issues             = true
    has_projects           = false
    has_wiki               = false
    allow_merge_commit     = false
    allow_squash_merge     = true
    allow_rebase_merge     = false
    allow_auto_merge       = false
    delete_branch_on_merge = true
  }

  gh_protection_defaults = {
    pattern                         = "main"
    enforce_admins                  = true
    allows_force_pushes             = false
    allows_deletions                = false
    require_conversation_resolution = true
    required_approving_review_count = 0
    dismiss_stale_reviews           = true
    strict_status_checks            = true
    status_checks                   = ["ci / terraform (pull_request)"]
  }

  gh_repositories = {
    for r in local.gh.repositories : r.name => merge(
      local.gh_repository_defaults,
      try(r.settings, {}),
      { name = r.name, description = r.description },
    )
  }

  gh_protections = {
    for r in local.gh.repositories : r.name => merge(
      local.gh_protection_defaults,
      try(r.protection, {}),
    )
  }

  labels = {
    environment = var.environment
    managed_by  = "terraform"
    repository  = local.repository
    tfc_project = local.tfc_plane_project
  }
}
