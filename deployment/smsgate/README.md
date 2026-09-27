# SMSGate bridge

A standalone process using the deployed Chatwoot image and Rails models. It does not patch the application or require restarting Rails/Sidekiq. Keep its image aligned with Chatwoot during upgrades, including the Enterprise overlay.

The dedicated API inbox has no external channel webhook and requires HMAC for public contact APIs. The bridge receives SMSGate callbacks over HTTPS on `/smsgate/events/<random-token>` and polls only public outgoing messages in its configured inbox. Credentials are supplied through a private, mode-0600 environment file outside Git.

Required environment: existing Chatwoot database/Redis environment plus `SMSGATE_INBOX_ID`, `SMSGATE_USERNAME`, `SMSGATE_PASSWORD`, `SMSGATE_DEVICE_ID`, and `SMSGATE_WEBHOOK_TOKEN` (at least 32 random bytes). Never commit the environment file, callback URL, or device credentials.

Run `bundle exec ruby /bridge/bridge.rb` from `/app` in the deployed Chatwoot image. Mount this file read-only. Use the Chatwoot Docker network, map port 3010 only to host loopback, and proxy `/smsgate/` through the existing HTTPS host. Configure automatic restart and bounded Docker logs. Register device-specific `sms:received` callbacks at the public endpoint. Optional `system:ping` callbacks are accepted for diagnostics.

Inbound callbacks validate the private URL token and device ID, then deduplicate message IDs under an inbox lock. Contacts with valid phone numbers reuse the account's existing contact. Numeric Egyptian local numbers are normalized with the existing telephone_number library; alphanumeric senders remain receive-only. Conversations are separated by sender/SIM. SMS callbacks use ordinary Rails model callbacks so native notifications and automation continue to apply.

Replies are polled every five seconds. Only text messages to E.164 numbers are supported; attachments fail visibly. Private notes and deleted messages are never sent. The received SIM is reused; new conversations use the Android default SMS SIM. Stable gateway IDs prevent duplicate sends during network retries. Chatwoot's explicit retry action creates a new attempt ID after a terminal failure. Gateway acceptance does not imply carrier delivery; delivery is confirmed through the gateway's aggregate message state, including multipart delivery. API-channel messages show Chatwoot's normal initial sent state while submission is pending.

Deployment for this installation lives at `/opt/chatwood-smsgate` on the existing server. The compose service uses the same pinned image as Chatwoot, inbox 4, loopback port 3110, and the existing OpenLiteSpeed host. `GET /smsgate/health` checks process/poll-loop liveness, not mobile carrier delivery. The callback bearer token must stay private; the bridge logs event types and internal message IDs only, never message bodies or credentials.

Operational checks:

- `docker compose -f /opt/chatwood-smsgate/compose.json ps`
- `curl -f https://chat.maktabaa.com/smsgate/health`
- `docker logs --tail 30 chatwood-smsgate-bridge-1`

Stop just this service to disable forwarding. Remove the device callback registrations when decommissioning. Keep the inbox and its history. A copy of the previous virtual-host configuration is stored privately beside the deployment for rollback.

Validation used a rolled-back database transaction with a stubbed gateway transport: inbound creation, duplicate callback, outbound recipient/SIM mapping, explicit retry, delivered status, and unauthorized callback rejection. A real inbound SMS and a user-authorized reply are still required for carrier-level validation.
