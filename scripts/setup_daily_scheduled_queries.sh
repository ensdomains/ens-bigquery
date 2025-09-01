#!/bin/bash

# ENS BigQuery Daily Maintenance Setup - Properly Staggered
# Creates scheduled queries with realistic time intervals based on query complexity
# Usage: ./setup_daily_maintenance_staggered.sh [--project-id=PROJECT_ID]

set -e

PROJECT_ID="web3-publicgoods"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DDL_DIR="$(dirname "$SCRIPT_DIR")/ddl"

# Parse command line arguments
for arg in "$@"; do
    case $arg in
        --project-id=*)
            PROJECT_ID="${arg#*=}"
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [--project-id=PROJECT_ID]"
            echo ""
            echo "Creates daily scheduled queries with proper time intervals"
            echo ""
            echo "Staggered Schedule (allows sufficient runtime):"
            echo "  Tier 1 - Event Decoding (2:00-2:45 AM):"
            echo "    - 2:00 AM: Controller events (small, ~2 min)"
            echo "    - 2:10 AM: Base registrar events (small, ~2 min)"
            echo "    - 2:20 AM: Resolver events (large, ~5 min)"
            echo "    - 2:30 AM: Registry events (medium, ~3 min)"
            echo "    - 2:40 AM: Historical traces (medium, ~3 min)"
            echo ""
            echo "  Tier 2 - State Computation (3:00-3:30 AM):"
            echo "    - 3:00 AM: State resolver (large, ~5 min)"
            echo "    - 3:10 AM: State registry (medium, ~3 min)"
            echo "    - 3:20 AM: Aggregated resolver (medium, ~3 min)"
            echo "    - 3:25 AM: Aggregated registry (small, ~2 min)"
            echo ""
            echo "  Tier 3 - Production Tables (4:00-4:30 AM):"
            echo "    - 4:00 AM: Resolver table (medium, ~3 min)"
            echo "    - 4:05 AM: Registry table (small, ~2 min)"
            echo "    - 4:10 AM: Registration periods (large, ~5 min)"
            echo "    - 4:20 AM: Reverse records (medium, ~3 min)"
            echo "    - 4:25 AM: Resolutions (small, ~2 min)"
            exit 0
            ;;
        *)
            echo "Unknown option: $arg"
            exit 1
            ;;
    esac
done

echo "🗓️  Setting up ENS BigQuery Daily Maintenance (Properly Staggered)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Project ID: $PROJECT_ID"
echo ""
echo "Strategy: Staggered intervals based on query complexity"
echo "         10-minute gaps for large queries, 5-minute for small ones"
echo ""

# Clean up existing queries (except working incremental)
echo "🗑️  Cleaning up existing queries..."
EXISTING_CONFIGS=$(bq ls --transfer_config --transfer_location=us --format=csv 2>/dev/null | grep "ENS:" | cut -d',' -f1 || true)

if [ ! -z "$EXISTING_CONFIGS" ]; then
    for config in $EXISTING_CONFIGS; do
        if [[ $config == *"Raw Resolver Events"* ]]; then
            echo "   ✅ Keeping: Raw Resolver Events (Incremental)"
            continue
        fi
        echo "   🗑️  Deleting: $config"
        echo "y" | bq rm --transfer_config "$config" 2>/dev/null || true
    done
fi
echo ""

# Define queries with proper intervals based on complexity
# Format: "filename|schedule|display_name|estimated_runtime"
queries=(
    # Tier 1: Event Decoding (2:00-2:45 AM)
    "create_controller_event_tables.sql|every day 02:00|ENS: Controller Events|2min"
    "create_base_registrar_events.sql|every day 02:10|ENS: Base Registrar Events|2min"
    "create_resolver_event_tables.sql|every day 02:20|ENS: Resolver Events|5min"
    "create_registry_event_tables.sql|every day 02:30|ENS: Registry Events|3min"
    "create_historical_reverse_traces.sql|every day 02:40|ENS: Historical Traces|3min"
    
    # Tier 2: State Computation (3:00-3:30 AM) 
    "create_state_resolver.sql|every day 03:00|ENS: State Resolver|5min"
    "create_state_registry.sql|every day 03:10|ENS: State Registry|3min"
    "create_aggregated_resolver.sql|every day 03:20|ENS: Aggregated Resolver|3min"
    "create_aggregated_registry.sql|every day 03:25|ENS: Aggregated Registry|2min"
    
    # Tier 3: Production Tables (4:00-4:30 AM)
    "create_resolver_table.sql|every day 04:00|ENS: Resolver Table|3min"
    "create_registry_table.sql|every day 04:05|ENS: Registry Table|2min"
    "create_registration_periods_table.sql|every day 04:10|ENS: Registration Periods|5min"
    "create_reverse_records_table.sql|every day 04:20|ENS: Reverse Records|3min"
    "create_resolutions_table.sql|every day 04:25|ENS: Resolutions Table|2min"
)

# Create scheduled queries
echo "📅 Creating scheduled queries with proper intervals..."
echo ""

for query_def in "${queries[@]}"; do
    IFS='|' read -r file schedule display_name runtime <<< "$query_def"
    
    if [[ ! -f "$DDL_DIR/$file" ]]; then
        echo "⚠️  Skipping missing file: $file"
        continue
    fi
    
    echo "⏰ $schedule - $display_name"
    echo "   File: $file"
    echo "   Est. runtime: $runtime"
    
    bq query --display_name="$display_name" \
             --schedule="$schedule" \
             --use_legacy_sql=false \
             --project_id="$PROJECT_ID" \
             --location="us" < "$DDL_DIR/$file"
    
    if [ $? -eq 0 ]; then
        echo "   ✅ Created successfully"
    else
        echo "   ❌ Failed to create"
    fi
    echo ""
done

echo ""
echo "🎉 STAGGERED DAILY MAINTENANCE SETUP COMPLETED!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📊 Schedule Summary:"
echo ""
echo "  🕐 2:00-2:45 AM: Event Decoding (5 queries)"
echo "     10-minute gaps for safety"
echo ""
echo "  🕒 3:00-3:30 AM: State Computation (4 queries)"
echo "     Mixed 5-10 minute gaps based on complexity"
echo ""
echo "  🕓 4:00-4:30 AM: Production Tables (5 queries)"
echo "     5-10 minute gaps based on table size"
echo ""
echo "✅ Benefits:"
echo "   - No overlapping queries"
echo "   - Sufficient time for each query to complete"
echo "   - Clear dependency order maintained"
echo "   - Can track individual query performance"
echo ""
echo "💰 Cost: ~$1.20/day (same as before)"
echo ""
echo "📊 Monitor at:"
echo "   https://console.cloud.google.com/bigquery/scheduled-queries?project=$PROJECT_ID"
echo ""
echo "💡 Tips:"
echo "   - Check job history to verify actual runtimes"
echo "   - Adjust schedules if queries consistently overlap"
echo "   - Consider running heavy queries less frequently"