# Sign-up with email OTP: setup

The app now verifies a new account with a 6 digit code (`/account/verify-otp`,
`lib/features/account/presentation/verify_otp_page.dart`). The code only
arrives if the Supabase "Confirm signup" email template prints `{{ .Token }}`.
The default template prints a link (`{{ .ConfirmationURL }}`) and no code, so
the hosted project must be changed by hand.

## Flow

1. App calls `auth.signUp(email, password, data: {display_name})`.
2. With **Confirm email** on, Auth returns the user but **no session**. The
   router gate (`currentUser != null`) therefore keeps the person out of the
   app until the code is verified.
3. Auth emails the "Confirm signup" template. The app opens the code screen.
4. App calls `auth.verifyOTP(type: OtpType.signup, email, token)`. On success
   a session is issued, then the app goes to `/account/set-username` (no
   username yet) or home.
5. Existing but unverified account signing in: Auth answers
   `email_not_confirmed`; the app opens the code screen and requests a new
   code (`auth.resend(type: OtpType.signup)`).

If **Confirm email** is off, `signUp` returns a session immediately and there
is no verification at all: the app then skips the code screen. Turn it on.

## Hosted project: dashboard steps

Supabase Dashboard, project of Teman Kereta:

1. **Authentication > Sign In / Providers > Email**
   - Enable the Email provider.
   - **Confirm email**: ON.
   - **Minimum password length**: 8 (the app validates 8 for new passwords;
     sign-in does not enforce a minimum, so older 6 character passwords still
     work).
   - **Email OTP Expiration**: 3600 seconds (or shorter, for example 900).
   - **Email OTP Length**: 6.
2. **Authentication > Emails > Templates > Confirm signup**
   - Subject: `Kode verifikasi Teman Kereta: {{ .Token }}`
   - Body: paste the contents of `supabase/templates/confirmation.html`.
     Whatever the layout, the body must contain `{{ .Token }}`.
   - Save.
3. **Authentication > Rate Limits**: keep "Rate limit for sending emails" and
   "Rate limit for sign-ups and sign-ins" at defaults or stricter. The server
   allows one verification email per 60 seconds per address; the app shows the
   same 60 second countdown.
4. **Authentication > URL Configuration**: leave `site_url` and the redirect
   URLs as they are. The password-reset email still uses
   `temankereta://app/account/reset-password` (see below).
5. **Project Settings > Authentication > SMTP Settings**: the built-in mailer
   is capped at a few emails per hour and only delivers to team members.
   Before release, configure a custom SMTP provider (for example Cloudflare
   Email Service, Resend, or Brevo) with a sender on `temankereta.web.id`,
   otherwise real users will not receive codes.

Do **not** set the "Recovery" template to the OTP style: reset password still
works through the link (`{{ .ConfirmationURL }}`) that opens the app.

## Local stack

`supabase/config.toml` already has `enable_confirmations = true` and
`[auth.email.template.confirmation]` pointing at
`supabase/templates/confirmation.html`. Restart the local stack for it to take
effect (`npx supabase stop && npx supabase start`). Codes appear in Inbucket
(`http://127.0.0.1:54324`).

## What was checked about the existing deep link flow

- Password reset: `resetPasswordForEmail(redirectTo:
  temankereta://app/account/reset-password)` is unchanged. The recovery email
  opens the app, Auth emits `passwordRecovery`, and `app_router.dart` pushes
  `/account/reset-password`. That route is in `_authGateExemptRoutes`.
- `admin/app/confirm/page.tsx` is a web page ("Email berhasil dikonfirmasi")
  for link based confirmation. With the OTP template it is no longer reached
  for sign-up; leaving it in place is harmless and it was not modified.
- If someone taps an old confirmation link instead of typing a code, Auth
  signs them in; the code screen listens for the session and continues on its
  own.

## Error handling in the app

| Situation | What the user sees |
|---|---|
| Wrong or expired code (Auth returns `otp_expired` for both) | "Kode salah atau sudah kedaluwarsa..." |
| Too many attempts / emails (`429`, `over_*_rate_limit`) | "Terlalu banyak percobaan..." |
| Email already registered | Switches to Masuk with the email kept, notice explains |
| No network | "Tidak ada koneksi internet..." |
| Resend inside 60 seconds | Button disabled with a visible countdown |
