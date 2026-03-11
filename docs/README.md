# Documentation

This `docs/` directory complements the main `README.md` with maintainable technical documentation.

## Recommended reading order

1. `specification.md` for scope, functional requirements, and conventions.
2. `architecture.md` for the repository structure and configuration flow.
3. `deployment.md` for install, rebuild, validation, and rollback procedures.
4. `metrics.md` for optional project metrics and reporting commands.
5. `adr/0001-repo-structure.md` for the repository structure decision record.

## Documentation philosophy

- Keep the root `README.md` focused on overview, screenshots, and quickstart.
- Keep `docs/` focused on decisions, contracts, operations, and maintenance.
- Prefer generated or semi-generated documentation for low-level inventories.
- Avoid hand-written lists of every variable or function unless they express a stable contract.

## Directory layout

```text
docs/
├── README.md
├── specification.md
├── architecture.md
├── deployment.md
├── metrics.md
├── adr/
│   └── 0001-repo-structure.md
└── diagrams/
    └── system-overview.puml
```

## When to use which format

- Use Markdown for architecture notes, specs, and runbooks.
- Use Mermaid for lightweight diagrams rendered directly on GitHub.
- Use PlantUML for diagrams that need stricter structure or are reused outside GitHub.
- Use generated documentation tools for language-level APIs when relevant.
