# PrecisionCal — Supabase Migration Runbook

Use this when Sanctuary (the only feature using Supabase) grows enough that you want to own the data, or if the shared Rork-managed Supabase instance starts showing strain (rate limits, latency, moderation needs).

**Owner:** you (founder)
**Estimated time to execute:** ~45–60 min end-to-end
**App downtime required:** none (Sanctuary tab will show a brief "refreshing" state on first launch after the swap)

---

## When to run this

Run the migration when **any one** of these is true:

- Sanctuary DAU > ~1,000 actively posting users
- You see Supabase 429 / rate-limit errors in logs
- You need custom moderation tools (delete posts at scale, ban users, audit trail)
- You want analytics on Sanctuary (post volume, retention, top posters)
- You're raising / due-diligence and need to show data ownership
- A privacy / DSAR (data subject access request) requires you to export a user's posts

If none of these apply: **do nothing.** The shared instance is fine.

---

## Pre-flight checklist

- [ ] You have a Supabase account (https://supabase.com) — free tier is enough to start
- [ ] You have access to this repo and can edit env vars in Rork
- [ ] You have access to App Store Connect (only needed if shipping a new build, which this migration does NOT require — env-var swap is server-side)
- [ ] You've notified yourself (calendar block) of a ~1 hour window. No user-facing impact, but you want focus.

---

## Step 1 — Create your own Supabase project

1. Go to https://supabase.com/dashboard → **New project**
2. Name: `precisioncal-prod`
3. Region: pick closest to your largest user cohort (US-East is safe default)
4. Database password: generate strong, save to 1Password / your password manager
5. Plan: **Free** to start. Upgrade to **Pro ($25/mo)** once you have >500 MAU on Sanctuary or need daily backups.

Wait ~2 min for provisioning.

---

## Step 2 — Recreate the schema

The Sanctuary feature uses these tables (confirm by reading `ios/PrecisionCal/Services/SanctuaryService.swift` before running — schema may have evolved):

- `sanctuary_posts` — id, user_id, content, image_url, created_at, like_count
- `sanctuary_comments` — id, post_id, user_id, content, created_at
- `sanctuary_likes` — post_id, user_id, created_at (composite PK)
- `sanctuary_reports` — id, post_id, reporter_user_id, reason, created_at

**Action:** Ask the agent to read `SanctuaryService.swift` and generate a fresh `schema.sql` based on what the code actually queries. Run that SQL in Supabase → SQL Editor.

Then enable **Row Level Security** on every table and add policies:

```sql
-- Anyone authenticated can read posts
create policy "posts_read" on sanctuary_posts for select using (true);
-- Only the author can insert/update/delete their own posts
create policy "posts_write" on sanctuary_posts for insert with check (auth.uid() = user_id);
create policy "posts_delete" on sanctuary_posts for delete using (auth.uid() = user_id);
-- Repeat pattern for comments, likes, reports
```

---

## Step 3 — Export data from the shared instance (optional)

Only do this if you have meaningful user-generated content worth preserving.

1. Ask Rork support (or the agent) to export rows from the shared Supabase instance scoped to `project_id = asbn3nozacphqkj444cm6` (or whatever app-scoping column exists).
2. You'll receive CSV / JSON dumps per table.
3. Import via Supabase Dashboard → **Table Editor → Import data from CSV** for each table.
4. **Verify row counts match** before proceeding.

If Sanctuary is still small (< a few hundred posts), it's often cleaner to **start fresh** and tell users "Sanctuary got a fresh start — here's what's new."

---

## Step 4 — Swap the env vars

In Rork → Project Settings → Environment Variables:

| Variable | Old value | New value |
|---|---|---|
| `EXPO_PUBLIC_SUPABASE_URL` | `https://<rork-shared>.supabase.co` | `https://<your-project-ref>.supabase.co` |
| `EXPO_PUBLIC_SUPABASE_ANON_KEY` | `<shared anon key>` | `<your project's anon key>` |

Find your new values in Supabase Dashboard → **Project Settings → API**.

**No app code changes. No App Store resubmission.** The Swift code reads `Config.SUPABASE_URL` / `Config.SUPABASE_ANON_KEY` at runtime, so the next app launch picks up the new endpoint.

---

## Step 5 — Verify

On a TestFlight build (or production after a few minutes of propagation):

- [ ] Open the Sanctuary tab — feed loads (will be empty if you skipped data import; that's expected)
- [ ] Create a test post — appears in your new Supabase `sanctuary_posts` table
- [ ] Like / comment on the post — rows appear in `sanctuary_likes` / `sanctuary_comments`
- [ ] Force-quit and relaunch — post still there (confirms persistence, not cache)
- [ ] Check Supabase Dashboard → **Logs** for any RLS denials or 4xx errors

If all green, you're done.

---

## Step 6 — Post-migration

- [ ] Add a **daily backup** in Supabase Dashboard → Database → Backups (Pro plan)
- [ ] Set up **log drains** if you want centralized observability (Pro plan)
- [ ] Add yourself as `service_role` for moderation queries (never embed `service_role` key in the app — only use from a server / SQL editor)
- [ ] Document the new project ref + dashboard URL in your password manager

---

## Rollback

If something goes wrong in Step 4–5:

1. Revert `EXPO_PUBLIC_SUPABASE_URL` and `EXPO_PUBLIC_SUPABASE_ANON_KEY` to the previous values (keep them saved before you change them — screenshot or paste into a note).
2. Next app launch goes back to the shared instance. No user impact.

There is no scenario where this migration can brick the app — the worst case is Sanctuary tab shows "couldn't load" and the rest of the app keeps working (scan, Cal chat, dashboard, pantry, water, macros all run off local SwiftData).

---

## Contact / handoff

When you're ready to run this, just message the agent: **"Run the Supabase migration runbook."** The agent will:

1. Read `SanctuaryService.swift` to confirm current schema
2. Generate the exact `schema.sql` + RLS policies for you to paste into Supabase
3. Walk you through Steps 3–6 interactively
4. Verify the swap with you on TestFlight before declaring done
