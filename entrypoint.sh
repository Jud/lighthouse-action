#!/bin/bash

set -e

# Check if we're being triggered by a pull request.
PULL_REQUEST_NUMBER=$(jq .number "$GITHUB_EVENT_PATH")

# If this is a PR and Netlify is configured, plan to check the deploy preview and generate its unique URL.
# Otherwise, simply check the provided live URL.
if [ -n "$INPUT_NETLIFY_SITE" ] && [ -n "$PULL_REQUEST_NUMBER" ] && [ "$PULL_REQUEST_NUMBER" != "null" ]; then
  REPORT_URL="https://deploy-preview-$PULL_REQUEST_NUMBER--$INPUT_NETLIFY_SITE"
else
  REPORT_URL=$INPUT_URL
fi

# Prepare directory for audit results and sanitize URL to a valid and unique filename.
OUTPUT_FOLDER="report"

BASE_REPORT_URL=""
BASE_OUTPUT_PATH=""
if [ -n "$INPUT_NETLIFY_SITE" ] && [ -n "$INPUT_NETLIFY_BASE_BRANCH" ]; then
  BASE_REPORT_URL="https://$INPUT_NETLIFY_BASE_BRANCH--$INPUT_NETLIFY_SITE"
  # shellcheck disable=SC2001
  BASE_OUTPUT_FILENAME=$(echo "$BASE_REPORT_URL" | sed 's/[^a-zA-Z0-9]/_/g')
  BASE_OUTPUT_PATH="$GITHUB_WORKSPACE/$OUTPUT_FOLDER/$BASE_OUTPUT_FILENAME"
fi

# shellcheck disable=SC2001
OUTPUT_FILENAME=$(echo "$REPORT_URL" | sed 's/[^a-zA-Z0-9]/_/g')
OUTPUT_PATH="$GITHUB_WORKSPACE/$OUTPUT_FOLDER/$OUTPUT_FILENAME"
mkdir -p "$OUTPUT_FOLDER"

# Clarify in logs which URL we're auditing.
printf "* Beginning audit of %s ...\n\n" "$REPORT_URL"

# Run Lighthouse!
URL="${REPORT_URL}" BASE_URL="${BASE_REPORT_URL}" BASE_REPORT_PATH="${BASE_OUTPUT_PATH}" REPORT_PATH="${OUTPUT_PATH}" NETLIFY_BASE_AUTH="${INPUT_NETLIFY_BASE_PASSWORD}" NETLIFY_AUTH="${INPUT_NETLIFY_PASSWORD}" node /lighthouse.js

# Parse individual scores from JSON output.
# Unorthodox jq syntax because of dashes -- https://github.com/stedolan/jq/issues/38
SCORE_PERFORMANCE=$(jq '.categories["performance"].score' "$OUTPUT_PATH".report.json)
SCORE_ACCESSIBILITY=$(jq '.categories["accessibility"].score' "$OUTPUT_PATH".report.json)
SCORE_PRACTICES=$(jq '.categories["best-practices"].score' "$OUTPUT_PATH".report.json)
SCORE_SEO=$(jq '.categories["seo"].score' "$OUTPUT_PATH".report.json)
SCORE_PWA=$(jq '.categories["pwa"].score' "$OUTPUT_PATH".report.json)
BUNDLE_SIZE=$(cat "$OUTPUT_PATH".report.json | jq '.audits."network-requests".details.items[] | select(.url|test("netlify.app/.*js$")) | .resourceSize' | awk '{ SUM += $1} END { print SUM }' | awk '{$1/=1024;printf "%.2fKB\n",$1}' | awk '{$1/=1024;printf "%.2fMB\n",$1}')

# Print scores to standard output (0 to 100 instead of 0 to 1).
# Using hacky bc b/c bash hates floating point arithmetic...
printf '\n* Completed audit of %s ! Scores are printed below:\n\n' "$REPORT_URL"
printf -v RUN_OUTPUT '+-------------------------------+\n'
printf -v RUN_OUTPUT '%s|  Performance:         %.0f\t|\n' "$RUN_OUTPUT" "$(echo "$SCORE_PERFORMANCE*100" | bc -l)"
printf -v RUN_OUTPUT '%s|  Branch Bundle Size:  %s\t|\n' "$RUN_OUTPUT" "$(echo "$BUNDLE_SIZE")"

if [ -n "$INPUT_NETLIFY_BASE_BRANCH" ]; then
  BASE_BUNDLE_SIZE=$(cat "$BASE_OUTPUT_PATH".report.json | jq '.audits."network-requests".details.items[] | select(.url|test("netlify.app/.*js$")) | .resourceSize' | awk '{ SUM += $1} END { print SUM }' | awk '{$1/=1024;printf "%.2fKB\n",$1}' | awk '{$1/=1024;printf "%.2fMB\n",$1}')
  printf -v RUN_OUTPUT '%s|  Develop Bundle Size: %s\t|\n' "$RUN_OUTPUT" "$(echo "$BASE_BUNDLE_SIZE")"
  printf -v RUN_OUTPUT '%s|  Size Difference:     %.2fMB\t|\n' "$RUN_OUTPUT" "$(echo "$(echo "$BUNDLE_SIZE" | sed 's/[^0-9\.]*//g')-$(echo "$BASE_BUNDLE_SIZE" | sed 's/[^0-9\.]*//g')" | bc)"
fi

#printf "|  Accessibility:         %.0f\t|\n" "$(echo "$SCORE_ACCESSIBILITY*100" | bc -l)"
#printf "|  Best Practices:        %.0f\t|\n" "$(echo "$SCORE_PRACTICES*100" | bc -l)"
#printf "|  SEO:                   %.0f\t|\n" "$(echo "$SCORE_SEO*100" | bc -l)"
#printf "|  Progressive Web App:   %.0f\t|\n" "$(echo "$SCORE_PWA*100" | bc -l)"
printf -v RUN_OUTPUT '%s+-------------------------------+' "$RUN_OUTPUT"
echo "$RUN_OUTPUT"
echo $'\n\n'

printf "* Detailed results are saved here, use https://github.com/actions/upload-artifact to retrieve them:\n"
printf "    %s\n" "$OUTPUT_PATH.report.html"
printf "    %s\n\n\n" "$OUTPUT_PATH.report.json"

RUN_OUTPUT="${RUN_OUTPUT//'%'/'%25'}"
RUN_OUTPUT="${RUN_OUTPUT//$'\n'/'%0A'}"
RUN_OUTPUT="${RUN_OUTPUT//$'\r'/'%0D'}"
echo "::set-output name=content::$RUN_OUTPUT"

exit 0
