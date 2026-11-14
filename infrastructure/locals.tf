locals {
  env_dir = "${path.root}/../environments/${var.environment}"

  config = merge([for f in sort(fileset(local.env_dir, "*.yaml")) : yamldecode(file("${local.env_dir}/${f}"))]...)

  gcp = local.config.gcp
  tfc = local.config.tfc
  cf  = local.config.cf
  gh  = local.config.gh

  cf_zones = { for z in local.config.cf.zones : z.name => merge({ plan = "free" }, z) }

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
      { for p in try(f.projects, []) : try(p.name, p) => f.name }
    ]...
  )

  project_nodes_2 = merge(
    [for f in local.gcp.folders : merge(
      [for c in try(f.folders, []) :
        { for p in try(c.projects, []) : try(p.name, p) => c.name }
      ]...
    )]...
  )

  project_nodes_3 = merge(
    [for f in local.gcp.folders : merge(
      [for c in try(f.folders, []) : merge(
        [for g in try(c.folders, []) :
          { for p in try(g.projects, []) : try(p.name, p) => g.name }
        ]...
      )]...
    )]...
  )

  project_nodes_4 = merge(
    [for f in local.gcp.folders : merge(
      [for c in try(f.folders, []) : merge(
        [for g in try(c.folders, []) : merge(
          [for d in try(g.folders, []) :
            { for p in try(d.projects, []) : try(p.name, p) => d.name }
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
  tfc_hostname    = try(local.tfc.hostname, "app.terraform.io")

  sa_folder_1 = flatten([for x1 in local.gcp.folders : [for sa in try(x1.service_accounts, []) : { name = sa.name, scope = "folder:${x1.name}", roles = sa.roles }]])
  sa_folder_2 = flatten([for x1 in local.gcp.folders : flatten([for x2 in try(x1.folders, []) : [for sa in try(x2.service_accounts, []) : { name = sa.name, scope = "folder:${x2.name}", roles = sa.roles }]])])
  sa_folder_3 = flatten([for x1 in local.gcp.folders : flatten([for x2 in try(x1.folders, []) : flatten([for x3 in try(x2.folders, []) : [for sa in try(x3.service_accounts, []) : { name = sa.name, scope = "folder:${x3.name}", roles = sa.roles }]])])])
  sa_folder_4 = flatten([for x1 in local.gcp.folders : flatten([for x2 in try(x1.folders, []) : flatten([for x3 in try(x2.folders, []) : flatten([for x4 in try(x3.folders, []) : [for sa in try(x4.service_accounts, []) : { name = sa.name, scope = "folder:${x4.name}", roles = sa.roles }]])])])])

  sa_folder_entries = concat(local.sa_folder_1, local.sa_folder_2, local.sa_folder_3, local.sa_folder_4)

  sa_project_1 = flatten([for x1 in local.gcp.folders : [for p in try(x1.projects, []) : [for sa in try(try(p.service_accounts, []), []) : { name = sa.name, scope = "project:${try(p.name, p)}", roles = sa.roles }]]])
  sa_project_2 = flatten([for x1 in local.gcp.folders : flatten([for x2 in try(x1.folders, []) : [for p in try(x2.projects, []) : [for sa in try(try(p.service_accounts, []), []) : { name = sa.name, scope = "project:${try(p.name, p)}", roles = sa.roles }]]])])
  sa_project_3 = flatten([for x1 in local.gcp.folders : flatten([for x2 in try(x1.folders, []) : flatten([for x3 in try(x2.folders, []) : [for p in try(x3.projects, []) : [for sa in try(try(p.service_accounts, []), []) : { name = sa.name, scope = "project:${try(p.name, p)}", roles = sa.roles }]]])])])
  sa_project_4 = flatten([for x1 in local.gcp.folders : flatten([for x2 in try(x1.folders, []) : flatten([for x3 in try(x2.folders, []) : flatten([for x4 in try(x3.folders, []) : [for p in try(x4.projects, []) : [for sa in try(try(p.service_accounts, []), []) : { name = sa.name, scope = "project:${try(p.name, p)}", roles = sa.roles }]]])])])])

  sa_project_entries = concat(local.sa_project_1, local.sa_project_2, local.sa_project_3, local.sa_project_4)

  sa_entries = concat(local.sa_folder_entries, local.sa_project_entries, try(local.gcp.service_accounts, []))

  gcp_service_accounts = [
    for n in distinct([for e in local.sa_entries : e.name]) : {
      name     = n
      bindings = [for e in local.sa_entries : { scope = e.scope, roles = e.roles } if e.name == n]
    }
  ]

  tfc_plane_project = "ef-${var.environment}"

  tfc_project_names = [for p in local.tfc.projects : p.name]

  tfc_workspace_list = flatten([for p in local.tfc.projects : [for ws in try(p.workspaces, []) : { name = ws.name, project = p.name, repo = ws.repo, working_directory = try(ws.working_directory, "infrastructure"), auto_apply = try(ws.auto_apply, false) }]])

  tfc_workspace_nodes = { for w in local.tfc_workspace_list : w.name => w }

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
    required_linear_history         = true
    required_approving_review_count = 0
    dismiss_stale_reviews           = true
    strict_status_checks            = true
    status_checks                   = ["ci / terraform (pull_request)", "ci / branch-name (pull_request)"]
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
