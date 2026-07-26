#!/bin/sh
# Cloudflare IP Access Rules helper for fail2ban.
#
# This logic lives in a script rather than inline in action.d/cloudflare-api.conf
# for a concrete reason: fail2ban's config parser treats a semicolon *preceded by
# whitespace* as the start of an inline comment and silently truncates the rest of
# the line. An inline `case "<ip>" in *:*) target=ip6 ;; *) target=ip ;; esac` was
# therefore delivered to sh as `case "1.2.3.4" in *:*) target=ip6` — an
# unterminated case statement, a syntax error, and every ban failing while the
# config still passed `fail2ban-client -t`.
#
# Keeping the shell in a .sh file removes that whole class of hazard, and makes
# the logic directly testable:
#   docker exec fail2ban sh /data/bin/cloudflare.sh ban 192.0.2.1 manual-test
#
# Usage: cloudflare.sh <ban|unban|verify> [ip] [jail]
# Env:   CLOUDFLARE_API_TOKEN, CLOUDFLARE_ACCOUNT_ID

set -u

action="${1:-}"
ip="${2:-}"
jail="${3:-fail2ban}"

if [ -z "${CLOUDFLARE_API_TOKEN:-}" ] || [ -z "${CLOUDFLARE_ACCOUNT_ID:-}" ]; then
	echo "cloudflare.sh: CLOUDFLARE_API_TOKEN / CLOUDFLARE_ACCOUNT_ID not set" >&2
	exit 1
fi

API="https://api.cloudflare.com/client/v4/accounts/${CLOUDFLARE_ACCOUNT_ID}/firewall/access_rules/rules"
AUTH_H="Authorization: Bearer ${CLOUDFLARE_API_TOKEN}"
TYPE_H="Content-Type: application/json"

# Cloudflare answers HTTP 200 with {"success":false,...} for an expired token, a
# missing permission, or a token blocked by client-IP filtering. Discarding the
# body would make all of those look like successful bans in fail2ban's log while
# nothing was actually blocked, so every response is inspected.
ok() {
	compact=$(printf '%s' "$1" | tr -d ' \n')
	case "$compact" in
		*'"success":true'*) return 0 ;;
		# Re-banning an address that already has a rule is not an error.
		*duplicate_of_existing*) return 0 ;;
	esac
	return 1
}

case "$action" in
	verify)
		resp=$(curl -sS -X GET "${API}?per_page=1" -H "$AUTH_H" -H "$TYPE_H")
		if ok "$resp"; then
			echo "cloudflare.sh: credentials OK"
			exit 0
		fi
		echo "cloudflare.sh: credential check FAILED: $resp" >&2
		exit 1
		;;

	ban)
		[ -n "$ip" ] || { echo "cloudflare.sh: ban needs an ip" >&2; exit 1; }
		# Cloudflare rejects the request when target does not match the address
		# family: IPv4 must be "ip", IPv6 must be "ip6". Most real traffic to this
		# homelab is IPv6, so the family is chosen per-address.
		case "$ip" in
			*:*) target=ip6 ;;
			*)   target=ip ;;
		esac
		payload="{\"mode\":\"block\",\"configuration\":{\"target\":\"${target}\",\"value\":\"${ip}\"},\"notes\":\"fail2ban ${jail}\"}"
		resp=$(curl -sS -X POST "$API" -H "$AUTH_H" -H "$TYPE_H" --data "$payload")
		if ok "$resp"; then
			exit 0
		fi
		echo "cloudflare.sh: ban ${ip} (${target}) FAILED: $resp" >&2
		exit 1
		;;

	unban)
		[ -n "$ip" ] || { echo "cloudflare.sh: unban needs an ip" >&2; exit 1; }
		# There is no delete-by-value endpoint, so the rule id must be looked up
		# first. Rule ids are 32 hex chars; grep -o stops a greedy match from
		# swallowing the whole result array and returning the wrong id.
		resp=$(curl -sS -X GET "${API}?configuration.value=${ip}&page=1&per_page=1" -H "$AUTH_H" -H "$TYPE_H")
		if ! ok "$resp"; then
			echo "cloudflare.sh: unban lookup for ${ip} FAILED: $resp" >&2
			exit 1
		fi
		id=$(printf '%s' "$resp" | grep -o '"id" *: *"[0-9a-f]\{32\}"' | head -n 1 | cut -d'"' -f4)
		if [ -z "$id" ]; then
			# Already gone — possibly removed by hand in the dashboard. Report
			# success so fail2ban's own state does not drift out of sync.
			exit 0
		fi
		resp=$(curl -sS -X DELETE "${API}/${id}" -H "$AUTH_H" -H "$TYPE_H")
		if ok "$resp"; then
			exit 0
		fi
		echo "cloudflare.sh: unban ${ip} FAILED: $resp" >&2
		exit 1
		;;

	*)
		echo "cloudflare.sh: unknown action '${action}' (want ban|unban|verify)" >&2
		exit 1
		;;
esac
