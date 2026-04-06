# ADR 0007: Design System (Vuetify 4)

## Status
Accepted

## Context
We need a consistent, accessible, responsive design language across multiple apps. A shared design system will reduce duplication, improve UX quality, and accelerate development.

## Decision
Adopt **Vuetify 4** as our primary UI component library. Vuetify provides Material Design components built for Vue 3 with comprehensive theming, accessibility, and responsive design out of the box.

## Scope
- **Component Library**: Vuetify 4 provides all essential components: buttons, inputs, selects, date/time pickers, dialogs, drawers, tabs, tables, pagination, cards, alerts, snackbars, steppers, breadcrumbs, navigation, menus, etc.
- **Theming**: Use Vuetify's theming system with CSS variables for light/dark themes and tenant branding; configure primary/secondary/accent colors per tenant.
- **Design Tokens**: Leverage Vuetify's built-in token system (colors, typography, spacing, elevation, border radius) with customization via theme configuration.
- **Patterns**: Implement common patterns (list→detail, wizard/stepper, filter panels, bulk actions, inline editing, sticky action bars) using Vuetify components and composition.
- **Accessibility**: Vuetify 4 includes WCAG 2.2 compliance, ARIA semantics, keyboard navigation, focus management, and reduced motion support by default.
- **Responsiveness**: All Vuetify components are mobile-first and responsive; use Vuetify's grid system and breakpoint utilities.
- **Customization**: Create custom component wrappers when needed for specific business logic or extended functionality.

## Implementation Notes
- Install Vuetify 4 via npm: `npm install vuetify@next`
- Configure Vuetify plugin in main app with custom theme (colors, typography, defaults)
- Use Vuetify's Material Design Icons (mdi) or Material Symbols
- Theme configuration exposed as TypeScript interfaces for type safety
- Components use Composition API and take advantage of Vuetify's props, slots, and events
- Custom styles use Vuetify's SASS variables and mixins for consistency

## Consequences
- **Pros**: 
  - Battle-tested, mature component library with comprehensive documentation
  - Material Design compliance provides professional, familiar UX
  - Extensive theming and customization options
  - Active community and regular updates
  - Faster development with pre-built, accessible components
  - Reduced maintenance burden compared to custom components
  - Better accessibility out of the box
- **Cons**: 
  - Bundle size larger than custom minimal components (mitigated by tree-shaking)
  - Learning curve for team members unfamiliar with Vuetify
  - Customization constraints within Material Design paradigm
  - Dependency on third-party library updates
