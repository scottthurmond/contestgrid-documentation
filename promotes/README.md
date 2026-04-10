# Environment Promotion Documentation

This folder contains environment-specific promotion checklists and seed data requirements.

| Folder | Purpose |
|--------|---------|
| `toDev/` | Promote from local lab to shared Dev environment |
| `toTest/` | Promote from Dev to Test/QA environment |
| `toProd/` | Promote from Test to Production |

Each folder should contain:
- **CHECKLIST.md** — Step-by-step promotion checklist
- **seed-data.sql** — Required reference/seed data for that environment
- Any environment-specific configuration notes
