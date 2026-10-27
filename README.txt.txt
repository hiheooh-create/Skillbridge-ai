# SkillBridge AI — Admin Dashboard

## Files
- `SkillBridge-Admin.html`: standalone dashboard, uses the same Supabase project and publishable key as the existing app.
- `SkillBridge-Admin-Setup.sql`: creates a private admin allowlist and admin-only RPC functions.
- `README.txt`: this guide.

## Exact setup
1. Back up your working SkillBridge HTML file first. Do not replace it with the admin page.
2. Open Supabase Dashboard → SQL Editor → New query.
3. Paste all of `SkillBridge-Admin-Setup.sql` and click Run. This SQL assumes the existing `profiles`, `skill_requests`, `skill_messages`, and `skill_reviews` tables are already installed.
4. Sign in to your normal SkillBridge app using the account that should be the sole admin.
5. In Supabase → SQL Editor, run this query after replacing the email with your exact login email:

   insert into public.skillbridge_admins(user_id)
   select id from auth.users where lower(email)=lower('YOUR-LOGIN-EMAIL')
   on conflict (user_id) do nothing;

6. Confirm the query inserted one row. To check:

   select a.user_id, u.email
   from public.skillbridge_admins a join auth.users u on u.id=a.user_id;

   Ensure only your account appears. The browser is not allowed to add admins.
7. Save `SkillBridge-Admin.html` in the same folder as your current app.
8. Open it via your existing local server (recommended) at `http://localhost:5500/SkillBridge-Admin.html`. If your server uses another port/folder, use the matching URL. You can also double-click the HTML, but localhost is preferable.
9. Sign in with your existing SkillBridge email/password. You should see totals, students, requests, and reviews. Delete-review asks for confirmation and calls an admin-only database function.

## Security notes
- The page uses the existing Supabase URL and publishable key. A publishable/anon key is designed to be public; never put a `service_role` or secret key in HTML.
- The dashboard is not secured by a secret URL. Supabase checks `auth.uid()` against `skillbridge_admins` for each admin RPC.
- The student/request lists show the fields currently present in the existing schema. User management is read-only in this first version; no account banning/deletion is implemented.
- If the SQL fails, copy the exact Supabase error before trying changes. Most likely cause is that the existing table names differ from the expected names.
- Since this is local-only, do not expose the page publicly until you have tested the policies and reviewed which student data admins should see.
