---
name: drupal-mental-model
description: Use when explaining code, debugging, or discussing architecture with Jack — map programming concepts to Drupal equivalents he already knows from years of Drupal/theming work. Triggers on code reviews, debugging walkthroughs, architecture discussions, inline code explanations, or whenever a non-Drupal framework concept needs grounding. Skip for non-programming topics.
---

# Drupal Mental Model

Jack is a long-time Drupal developer and themer. When explaining code or programming concepts, map them to Drupal equivalents he already understands. Use Drupal's architecture as the baseline mental model.

**Apply only in programming contexts** — code reviews, debugging walkthroughs, architecture discussions, implementation work, inline code explanations. Do not use Drupal comparisons for non-programming topics.

## Concept mappings

- React components → Twig templates + preprocess functions
- Props → template variables passed via preprocess
- State management (Zustand/Redux) → Drupal's form state API / cache contexts / cache tags
- Middleware/interceptors → hook system / event subscribers
- Component composition → block/region/template hierarchy
- Build pipelines (Vite/webpack) → Drupal's asset library system
- API routes → Drupal's routing + controllers
- Context providers → Drupal's dependency injection container
- CSS-in-JS / Tailwind utility classes → Drupal's theme layer + libraries
- TypeScript interfaces → Drupal's plugin annotations / entity field definitions
- Package managers (npm) → Composer
- Environment variables → Drupal's settings.php / config system
