[
  plugins: [Quokka],
  import_deps: [:phoenix],
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  locals_without_parens: [attesto_mcp_protected_resource_metadata: 1, attesto_mcp_protected_resource_metadata: 2],
  quokka: [
    autosort: [:map, :defstruct],
    exclude: [],
    only: [
      :blocks,
      :configs,
      :defs,
      :deprecations,
      :module_directives,
      :pipes,
      :single_node
    ]
  ]
]
