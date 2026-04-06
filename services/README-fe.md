# Contest Schedule Frontend

A large-scale Vue 3 application for managing contest schedules, built with TypeScript, Vite, Vue Router, and Pinia.

## Documentation

- **[Local Development Setup](docs/LOCAL-DEVELOPMENT-SETUP.md)** — Complete step-by-step guide to set up Rancher Desktop with K8s, Istio, Flux, PostgreSQL for local development (mirrors production EKS)
- **[Feature Overview](docs/OVERVIEW.md)** — High-level summary for external stakeholders
- **[MVP Scope](docs/MVP-SCOPE.md)** — v1.0 feature checklist, week-by-week implementation plan (3–5 weeks engineering), resource allocation, and success criteria
- **[Implementation Quickstart](docs/IMPLEMENTATION-QUICKSTART.md)** — Day-by-day breakdown for Phase 1–4, task assignment, and getting started
- **[API Security & Infrastructure Quick Reference](docs/API-SECURITY-QUICKREF.md)** — Checklists for HTTPS/TLS, JWT tokens, rate limiting, secrets management, Kubernetes/Istio/Helm/Flux best practices
- **[Flyway Database Migrations Quick Reference](../flyway/docs/FLYWAY-QUICKREF.md)** — Complete guide to database-as-code with Flyway (installation, migration commands, CI/CD, best practices)
- **[Database Modeling Workflow](docs/DB-MODELING-WORKFLOW.md)** — Standard open source/free toolchain and team workflow for ER design, migrations, and schema documentation
- **[Roadmap](docs/roadmap.md)** — Detailed requirements and planned features
- **[Architecture Decisions (ADRs)](docs/adr/)** — 32 architectural decision records covering auth, RBAC, data storage, billing, assignments, scoring, location tracking, rules, reports, compliance, and **modern infrastructure (Kubernetes, service mesh, GitOps)**
- **[Session Summary](docs/SESSION-SUMMARY.md)** — Completion status of MVP planning, completed this session, next steps

## Tech Stack

- **Vue 3** - Progressive JavaScript framework
- **TypeScript** - Type-safe JavaScript
- **Vite** - Next-generation frontend build tool (with experimental Rolldown)
- **Vue Router** - Official routing library
- **Pinia** - State management (to be configured)
- **Vuetify 4** - Material Design component framework
- **Axios** - HTTP client for API calls

## Project Structure

```
src/
├── assets/          # Static assets (images, fonts, etc.)
├── components/      # Reusable Vue components
│   ├── common/      # Generic UI components
│   ├── forms/       # Form-specific components
│   └── layout/      # Layout components (header, footer, etc.)
├── composables/     # Vue 3 composables (reusable logic)
├── constants/       # Application constants
├── router/          # Vue Router configuration
├── services/        # API services and external integrations
├── stores/          # Pinia state stores
├── types/           # TypeScript type definitions
├── utils/           # Helper functions and utilities
├── views/           # Page-level components
├── App.vue          # Root component
├── main.ts          # Application entry point
└── style.css        # Global styles
```

## Getting Started

### Prerequisites

- Node.js (v18 or higher recommended)
- npm or yarn
- **For Kubernetes Development**: Rancher Desktop (see [Local Development Setup](docs/LOCAL-DEVELOPMENT-SETUP.md))

### Local Frontend Development (Vue only)

```bash
npm install
```

### Development

Start the development server:

```bash
npm run dev
```

The application will be available at `http://localhost:5173`

### Full Stack Development (Kubernetes)

For full-stack development with backend services, database, and service mesh:

1. **Set up Rancher Desktop**: Follow the [Local Development Setup Guide](docs/LOCAL-DEVELOPMENT-SETUP.md) for complete instructions
2. **Deploy to local K8s**: Use Helm charts in `infrastructure/` directory
3. **Benefits**: 
   - Complete production-like environment on your laptop
   - Test with Istio service mesh (mTLS between services)
   - Identical setup to AWS EKS production environment
   - Work offline without AWS costs

### Build for Production

```bash
npm run build
```

The built files will be in the `dist/` directory.

### Preview Production Build

```bash
npm run preview
```

## Configuration

### Environment Variables

Copy `.env.example` to `.env` and update the values:

```bash
cp .env.example .env
```

Available variables:
- `VITE_API_BASE_URL` - Backend API base URL

## Development Guidelines

- Use Vue 3 Composition API with `<script setup>` syntax
- Follow TypeScript best practices
- Keep components small and focused
- Extract reusable logic into composables
- Use Pinia for global state management
- Follow the established directory structure

## Path Aliases

The `@` alias is configured to point to the `src/` directory:

```typescript
import { something } from '@/utils/helpers'
import MyComponent from '@/components/common/MyComponent.vue'
```

## Next Steps

1. Configure Pinia store in `main.ts`
2. Set up additional routes in `src/router/index.ts`
3. Create reusable components in `src/components/`
4. Define API services in `src/services/`
5. Add view components in `src/views/`

## Resources

- [Vue 3 Documentation](https://vuejs.org/)
- [Vite Documentation](https://vitejs.dev/)
- [Vue Router Documentation](https://router.vuejs.org/)
- [Pinia Documentation](https://pinia.vuejs.org/)
- [TypeScript Documentation](https://www.typescriptlang.org/)

## Roadmap

- See the project roadmap and next phases in [docs/roadmap.md](docs/roadmap.md)

## Dependency Notes

- `npm run doctor:deps` shows `inflight@1.0.6` via pact-core (glob@8/rimraf@2) and artillery (glob@7); these are dev-only and low risk for short CLI runs. Avoid forcing overrides until upstream bumps to glob ≥9/rimraf ≥5.
- Unit tests run with Vitest + Vite 5; MSW is disabled for unit runs. Use integration/e2e for MSW if needed.
- Minimum engines: Node >=18.18, npm >=9 (see package.json).

