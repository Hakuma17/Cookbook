Backend hardening checklist (PHP)

Scope: You asked to avoid touching backend now, but here are the exact files and changes to implement afterward with SQL injection protection and safer inputs.

Priority endpoints to review:

1) login.php
   - Use prepared statements with bound parameters for email/password lookups
   - Rate limit by IP/email, add exponential backoff
   - Return normalized JSON { success, data, message }

2) register.php
   - Validate username/email/password server-side (length, format)
   - Check duplicates with prepared statements
   - Hash passwords with password_hash (BCRYPT/ARGON2I)

3) google_login.php
   - Verify Google ID token with Google API (aud, iss, exp)
   - If creating a new user, sanitize displayName and store external photo URL temporarily

4) get_profile.php
   - Return image_url or relative path_imgProfile (never expose filesystem paths)

5) update_profile.php
   - Accept only: profile_name, profile_info, image_url (or multipart file)
   - If image_url is external: server-side should fetch and store a local copy (curl+mime check) and return relative path
   - Use prepared statements to update fields; whitelist columns

6) upload_profile_image.php
   - Enforce file size and mime-type (image/jpeg/png/webp)
   - Randomized filenames, store under /uploads/users/
   - Return { data: { relative_path: "uploads/users/.." } }

7) search_recipes_unified.php
   - Always bind inputs (q, include/exclude arrays) via prepared statements
   - Implement keyword escaping for LIKE queries (escape % _)
   - Limit page/limit (cap limit <= 50)

8) get_cart_items.php, get_ingredients.php, get_ingredient_groups.php, map_ingredients_to_groups.php
   - Prepared statements for all dynamic parameters
   - Cache where possible to reduce load

Security notes:
- Centralize DB connection and prepared statement helper
- Use PDO with ERRMODE_EXCEPTION
- Set default charset to utf8mb4
- Set Content-Security-Policy headers for images if exposing external URLs
- Regenerate session ID on login; set HttpOnly and SameSite=Lax cookies
- Return only necessary fields; never return password hashes

Input sanitation on backend (complements frontend):
- Trim, remove control characters, normalize whitespace
- Reject overly long inputs early (username<=100 bytes, info<=1000 bytes, q<=200 chars)
- For LIKE: replace % with \% and _ with \_

This checklist complements the frontend guards added in this commit. Apply after FE verification.