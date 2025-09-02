#!/bin/bash

# ENS BigQuery Daily Maintenance Setup - Properly Staggered
# Creates scheduled queries with realistic time intervals based on query complexity
# Usage: ./setup_daily_scheduled_queries.sh [--project-id=PROJECT_ID] [--start-time=HH:MM]

set -e

PROJECT_ID="web3-publicgoods"
START_TIME="02:00"  # Default start time
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DDL_DIR="$(dirname "$SCRIPT_DIR")/ddl"

# Parse command line arguments
for arg in "$@"; do
    case $arg in
        --project-id=*)
            PROJECT_ID="${arg#*=}"
            shift
            ;;
        --start-time=*)
            START_TIME="${arg#*=}"
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [--project-id=PROJECT_ID] [--start-time=HH:MM]"
            echo ""
            echo "Creates daily scheduled queries with proper time intervals"
            echo ""
            echo "Options:"
            echo "  --project-id=ID    BigQuery project ID (default: web3-publicgoods)"
            echo "  --start-time=HH:MM Base start time in 24h format (default: 02:00)"
            echo ""
            echo "Staggered Schedule (allows sufficient runtime):"
            echo "  Tier 0 - Foundation (start + 0-15 min):"
            echo "    - +0 min: UDF Functions (small, ~1 min)"
            echo "    - +2 min: Raw Events Incremental (large, ~10 min)"
            echo "    - +13 min: Base Registrar Incremental (small, ~2 min)"
            echo ""
            echo "  Tier 1 - Event Decoding (start + 20-55 min):"
            echo "    - +20 min: Controller events (small, ~2 min)"
            echo "    - +25 min: Base registrar events (small, ~2 min)"
            echo "    - +30 min: Resolver events (large, ~5 min)"
            echo "    - +40 min: Registry events (medium, ~3 min)"
            echo "    - +50 min: Historical traces (medium, ~3 min)"
            echo ""
            echo "  Tier 2 - State Computation (start + 70-95 min):"
            echo "    - +70 min: State resolver (large, ~5 min)"
            echo "    - +80 min: State registry (medium, ~3 min)"
            echo "    - +85 min: Aggregated resolver (medium, ~3 min)"
            echo "    - +90 min: Aggregated registry (small, ~2 min)"
            echo ""
            echo "  Tier 3 - Production Tables (start + 100-130 min):"
            echo "    - +100 min: Resolver table (medium, ~3 min)"
            echo "    - +105 min: Registry table (small, ~2 min)"
            echo "    - +110 min: Registration periods (large, ~5 min)"
            echo "    - +120 min: Reverse records (medium, ~3 min)"
            echo "    - +125 min: Resolutions (small, ~2 min)"
            echo ""
            echo "Examples:"
            echo "  # Use default 2:00 AM start time"
            echo "  $0 --project-id=web3-publicgoods"
            echo ""
            echo "  # Start at current time + 5 minutes for testing"
            echo "  $0 --project-id=web3-publicgoods --start-time=14:30"
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
echo "Start time: $START_TIME"
echo ""

# Function to calculate time offset from base start time
calculate_time() {
    local base_time="$1"
    local offset_minutes="$2"
    
    # Extract hour and minute from base time
    local base_hour=$(echo "$base_time" | cut -d':' -f1)
    local base_minute=$(echo "$base_time" | cut -d':' -f2)
    
    # Convert to total minutes
    local total_minutes=$((base_hour * 60 + base_minute + offset_minutes))
    
    # Handle overflow to next day
    total_minutes=$((total_minutes % 1440))  # 1440 minutes in a day
    
    # Convert back to HH:MM
    local new_hour=$((total_minutes / 60))
    local new_minute=$((total_minutes % 60))
    
    printf "%02d:%02d" "$new_hour" "$new_minute"
}

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
# Format: "filename|offset_minutes|display_name|estimated_runtime"
queries=(
    # Tier 0: Foundation (start + 0-15 minutes)
    "create_functions.sql|0|ENS: UDF Functions|1min"
    "create_ens_raw_events_incremental_scheduled.sql|2|ENS: Raw Events Incremental|10min"
    "create_base_registrar_events_incremental_scheduled.sql|13|ENS: Base Registrar Incremental|2min"
    
    # Tier 1: Event Decoding (start + 20-55 minutes)
    "create_controller_event_tables.sql|20|ENS: Controller Events|2min"
    "create_base_registrar_events.sql|25|ENS: Base Registrar Events|2min"
    "create_resolver_event_tables.sql|30|ENS: Resolver Events|5min"
    "create_registry_event_tables.sql|40|ENS: Registry Events|3min"
    "create_historical_reverse_traces.sql|50|ENS: Historical Traces|3min"
    
    # Tier 2: State Computation (start + 70-95 minutes) 
    "create_state_resolver.sql|70|ENS: State Resolver|5min"
    "create_state_registry.sql|80|ENS: State Registry|3min"
    "create_aggregated_resolver.sql|85|ENS: Aggregated Resolver|3min"
    "create_aggregated_registry.sql|90|ENS: Aggregated Registry|2min"
    
    # Tier 3: Production Tables (start + 100-130 minutes)
    "create_resolver_table.sql|100|ENS: Resolver Table|3min"
    "create_registry_table.sql|105|ENS: Registry Table|2min"
    "create_registration_periods_table.sql|110|ENS: Registration Periods|5min"
    "create_reverse_records_table.sql|120|ENS: Reverse Records|3min"
    "create_resolutions_table.sql|125|ENS: Resolutions Table|2min"
)

# Create scheduled queries
echo "📅 Creating scheduled queries with proper intervals..."
echo ""

for query_def in "${queries[@]}"; do
    IFS='|' read -r file offset_minutes display_name runtime <<< "$query_def"
    
    if [[ ! -f "$DDL_DIR/$file" ]]; then
        echo "⚠️  Skipping missing file: $file"
        continue
    fi
    
    # Calculate the scheduled time
    scheduled_time=$(calculate_time "$START_TIME" "$offset_minutes")
    schedule="every day $scheduled_time"
    
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
tier0_start=$(calculate_time "$START_TIME" 0)
tier0_end=$(calculate_time "$START_TIME" 15)
tier1_start=$(calculate_time "$START_TIME" 20)
tier1_end=$(calculate_time "$START_TIME" 55)
tier2_start=$(calculate_time "$START_TIME" 70)
tier2_end=$(calculate_time "$START_TIME" 95)
tier3_start=$(calculate_time "$START_TIME" 100)
tier3_end=$(calculate_time "$START_TIME" 130)

echo "  🕐 $tier0_start-$tier0_end: Foundation (3 queries)"
echo "     Functions + Incremental raw events"
echo ""
echo "  🕑 $tier1_start-$tier1_end: Event Decoding (5 queries)"
echo "     5-10 minute gaps for safety"
echo ""
echo "  🕒 $tier2_start-$tier2_end: State Computation (4 queries)"
echo "     5-10 minute gaps based on complexity"
echo ""
echo "  🕓 $tier3_start-$tier3_end: Production Tables (5 queries)"
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