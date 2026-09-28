#!/usr/bin/env python3
"""
Teams webhook handler for Herdr Nervous System.

Receives Teams messages on port 3978, routes them to the Hermes agent
via the herdr CLI, and relays the response back to Teams.

Environment variables:
  TEAMS_CLIENT_ID     - Azure AD app client ID (required for auth)
  TEAMS_CLIENT_SECRET - Azure AD app client secret (required for auth)
  TEAMS_TENANT_ID     - Azure AD tenant ID (required for auth)
  HERMES_PANE_ID      - herdr pane ID where Hermes agent runs (default: w1:p2)
  PORT                - Webhook listener port (default: 3978)
"""

import json
import os
import subprocess
import time
import requests
from flask import Flask, request, jsonify

app = Flask(__name__)

# Configuration
TEAMS_CLIENT_ID = os.environ.get("TEAMS_CLIENT_ID", "")
TEAMS_CLIENT_SECRET = os.environ.get("TEAMS_CLIENT_SECRET", "")
TEAMS_TENANT_ID = os.environ.get("TEAMS_TENANT_ID", "")
HERMES_PANE_ID = os.environ.get("HERMES_PANE_ID", "w1:p2")
PORT = int(os.environ.get("PORT", "3978"))
HERDR_SOCKET = "/root/.config/herdr/herdr.sock"

# Teams auth cache
_token_cache = {"access_token": None, "expires_at": 0}


def get_teams_token():
    """Get an OAuth2 access token for Microsoft Graph."""
    if _token_cache["access_token"] and time.time() < _token_cache["expires_at"] - 60:
        return _token_cache["access_token"]

    url = f"https://login.microsoftonline.com/{TEAMS_TENANT_ID}/oauth2/v2.0/token"
    data = {
        "grant_type": "client_credentials",
        "client_id": TEAMS_CLIENT_ID,
        "client_secret": TEAMS_CLIENT_SECRET,
        "scope": "https://graph.microsoft.com/.default",
    }
    response = requests.post(url, data=data, timeout=10)
    response.raise_for_status()
    token_data = response.json()
    _token_cache["access_token"] = token_data["access_token"]
    _token_cache["expires_at"] = time.time() + token_data.get("expires_in", 3600)
    return _token_cache["access_token"]


def herdr_cli(args, timeout=120):
    """Run a herdr CLI command and return (stdout, stderr, returncode)."""
    cmd = ["herdr"] + args
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout,
            env={**os.environ, "HERDR_SOCKET": HERDR_SOCKET},
        )
        return result.stdout, result.stderr, result.returncode
    except subprocess.TimeoutExpired:
        return "", "timeout", 1


def send_teams_message(chat_id, message_id, text):
    """Send a reply to a Teams message via Microsoft Graph API."""
    url = f"https://graph.microsoft.com/v1.0/chats/{chat_id}/messages/{message_id}/replies"
    headers = {
        "Authorization": f"Bearer {get_teams_token()}",
        "Content-Type": "application/json",
    }
    body = {"body": {"content": text, "contentType": "text"}}
    try:
        response = requests.post(url, json=body, headers=headers, timeout=30)
        response.raise_for_status()
        return True
    except Exception as e:
        print(f"[ERROR] Failed to send Teams reply: {e}")
        return False


@app.route("/api/messages", methods=["GET", "POST"])
def webhook():
    """Handle Teams webhook messages."""
    if request.method == "GET":
        # Teams verification challenge
        challenge = request.args.get("validationToken")
        if challenge:
            return challenge
        return jsonify({"error": "No validation token"}), 400

    if request.method == "POST":
        body = request.json
        if not body:
            return jsonify({"error": "No JSON body"}), 400

        # Extract message details
        activity_type = body.get("type", "")
        if activity_type == "message":
            # This is a new message
            text = body.get("body", {}).get("content", "")
            chat_id = body.get("conversation", {}).get("id", "")
            message_id = body.get("id", "")
            from_user = body.get("from", {}).get("user", {}).get("displayName", "Unknown")

            print(f"[Teams] Message from {from_user}: {text[:100]}")

            # Prompt Hermes via herdr CLI
            prompt_json = json.dumps([{"role": "user", "content": text}])
            stdout, stderr, rc = herdr_cli([
                "agent", "prompt", HERMES_PANE_ID,
                "--json",
                "--timeout", "300000",  # 5 min timeout for AI response
            ], timeout=300)

            if rc != 0:
                error_msg = f"Error prompting Hermes: {stderr[:200]}"
                print(f"[ERROR] {error_msg}")
                send_teams_message(chat_id, message_id, f"❌ {error_msg}")
                return jsonify({"status": "error", "message": error_msg}), 500

            # Extract Hermes response from herdr output
            response_text = extract_hermes_response(stdout, stderr)

            # Send reply to Teams
            if response_text:
                send_teams_message(chat_id, message_id, response_text)
                print(f"[Teams] Reply sent to {chat_id}/{message_id}")
            else:
                send_teams_message(chat_id, message_id, "Hermes responded but no text could be extracted.")

            return jsonify({"status": "ok"}), 200
        elif activity_type == "event":
            # Handle Teams events (read receipts, etc.)
            return jsonify({"status": "ok"}), 200

    return jsonify({"status": "ok"}), 200


def extract_hermes_response(stdout, stderr):
    """Extract the text response from Hermes agent output."""
    # Try to parse as JSON first
    try:
        data = json.loads(stdout)
        if "result" in data and "message" in data["result"]:
            return data["result"]["message"]
    except (json.JSONDecodeError, KeyError):
        pass

    # Fall back to stderr (Hermes logs there)
    if stderr and "ERROR" not in stderr.upper():
        return stderr.strip()

    return stdout.strip() if stdout.strip() else None


def main():
    print(f"[Webhook] Starting Teams handler on port {PORT}")
    print(f"[Webhook] Hermes pane: {HERMES_PANE_ID}")
    print(f"[Webhook] Herdr socket: {HERDR_SOCKET}")
    print(f"[Webhook] Teams client_id: {TEAMS_CLIENT_ID[:10] + '...' if TEAMS_CLIENT_ID else 'NOT SET'}")

    app.run(host="0.0.0.0", port=PORT, threaded=True)


if __name__ == "__main__":
    main()
