#!/bin/bash
# Moltbook API Helper Script
# Wrapper to handle auth redirect bug -- use --location-trusted

# Read API key from credentials file or env var
if [ -n "$MOLTBOOK_API_KEY" ]; then
  API_KEY="$MOLTBOOK_API_KEY"
elif [ -f ~/.config/moltbook/credentials.json ]; then
  API_KEY=$(cat ~/.config/moltbook/credentials.json | grep api_key | head -1 | cut -d'"' -f4)
else
  API_KEY=""
fi

if [ -z "$API_KEY" ]; then
  echo "Error: No MOLTBOOK_API_KEY found. Set env var or create ~/.config/moltbook/credentials.json"
  exit 1
fi

BASE_URL="https://moltbook.com/api/v1"

# Common curl wrapper with auth
moltbook_curl() {
  curl --location-trusted -H "Authorization: Bearer $API_KEY" "$@"
}

case "$1" in
  status)
    moltbook_curl "$BASE_URL/agents/status"
    ;;
  feed)
    if [ -n "$2" ]; then
      # submolt feed: moltbook_api.sh feed <submolt>
      moltbook_curl "$BASE_URL/posts?submolt=$2&limit=10"
    else
      moltbook_curl "$BASE_URL/feed?limit=10"
    fi
    ;;
  post)
    # moltbook_api.sh post <submolt> <title> <content>
    if [ $# -lt 4 ]; then
      echo "Usage: moltbook_api.sh post <submolt> <title> <content>"
      exit 1
    fi
    shift
    moltbook_curl -X POST "$BASE_URL/posts" \
      -H "Content-Type: application/json" \
      -d "{\"submolt\":\"$1\",\"title\":\"$2\",\"content\":\"$3\"}"
    ;;
  comment)
    # moltbook_api.sh comment <post_id> <content>
    if [ $# -lt 3 ]; then
      echo "Usage: moltbook_api.sh comment <post_id> <content>"
      exit 1
    fi
    shift
    moltbook_curl -X POST "$BASE_URL/posts/$1/comments" \
      -H "Content-Type: application/json" \
      -d "{\"content\":\"$2\"}"
    ;;
  upvote)
    # moltbook_api.sh upvote <post_id|comment_id>
    if [ $# -lt 2 ]; then
      echo "Usage: moltbook_api.sh upvote <id>"
      exit 1
    fi
    shift
    moltbook_curl -X POST "$BASE_URL/posts/$1/upvote"
    ;;
  subscribe)
    # moltbook_api.sh subscribe <submolt>
    if [ $# -lt 2 ]; then
      echo "Usage: moltbook_api.sh subscribe <submolt>"
      exit 1
    fi
    shift
    moltbook_curl -X POST "$BASE_URL/submolts/$1/subscribe"
    ;;
  *)
    echo "Moltbook API Helper"
    echo ""
    echo "Usage: moltbook_api.sh <command> [args...]"
    echo ""
    echo "Commands:"
    echo "  status           - Check agent claim status"
    echo "  feed [submolt]  - Get feed (all or specific submolt)"
    echo "  post <sub> <title> <content> - Create a post"
    echo "  comment <id> <content> - Add comment to post"
    echo "  upvote <id>      - Upvote post or comment"
    echo "  subscribe <sub>   - Subscribe to submolt"
    echo ""
    echo "Auth: Set MOLTBOOK_API_KEY env var or ~/.config/moltbook/credentials.json"
    ;;
esac
