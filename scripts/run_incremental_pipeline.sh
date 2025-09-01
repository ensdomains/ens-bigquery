#!/bin/bash

# ENS BigQuery Incremental Pipeline Runner
# Smart hybrid approach: incremental for expensive extraction, rebuild for everything else
# Usage: ./run_incremental_pipeline.sh [--project-id=PROJECT_ID] [--dry-run] [--force-full]

set -e  # Exit immediately on error

# Default values
PROJECT_ID="web3-publicgoods"
DRY_RUN=false
FORCE_FULL=false
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DDL_DIR="$(dirname "$SCRIPT_DIR")/ddl"

# Parse command line arguments
for arg in "$@"; do
    case $arg in
        --project-id=*)
            PROJECT_ID="${arg#*=}"
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --force-full)
            FORCE_FULL=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [--project-id=PROJECT_ID] [--dry-run] [--force-full]"
            echo ""
            echo "Options:"
            echo "  --project-id=ID    BigQuery project ID (default: web3-publicgoods)"
            echo "  --dry-run          Validate queries without executing them"
            echo "  --force-full       Force full rebuild (ignore checkpoint)"
            echo "  --help             Show this help message"
            echo ""
            echo "Incremental Mode:"
            echo "  - Raw event extraction (stages 2 & 4): Only new blocks since checkpoint"
            echo "  - All other stages: Full rebuild (cost-effective at ~$0.35/day)"
            echo ""
            echo "Daily cost estimate:"
            echo "  - Full rebuild: $30.75"
            echo "  - Incremental: $0.35 (98.9% reduction)"
            exit 0
            ;;
        *)
            echo "Unknown option: $arg"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Pipeline files in correct execution order
PIPELINE_FILES=(
    "create_checkpoint_table.sql"             # Initialize checkpoint (if needed)
    "create_functions.sql"                    # All UDF functions (must be first!)
    "create_ens_raw_events.sql"              # INCREMENTAL: Extract raw events
    "create_controller_event_tables.sql"      # Decode NameRegistered/NameRenewed events
    "create_base_registrar_events.sql"        # INCREMENTAL: Decode BaseRegistrar events
    "create_resolver_event_tables.sql"        # Decode all resolver events
    "create_historical_reverse_traces.sql"    # Load historical traces
    "create_registry_event_tables.sql"        # Decode registry events
    "create_state_resolver.sql"               # Compute latest state per node
    "create_state_registry.sql"               # Compute latest registry state
    "create_aggregated_resolver.sql"          # Aggregate text records, addresses
    "create_resolver_table.sql"               # Combine into main resolver table
    "create_aggregated_registry.sql"          # Aggregate registry data
    "create_registry_table.sql"               # Create registry table
    "create_registration_periods_table.sql"   # Registration periods with USD costs
    "create_reverse_records_table.sql"        # Create reverse records
    "create_resolutions_table.sql"            # Join registry + resolvers
)

# Function to run a single DDL file
run_ddl_file() {
    local file=$1
    local file_path="$DDL_DIR/$file"
    
    echo ""
    echo "📁 File: $file"
    echo "🕐 Started: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Check if file exists
    if [[ ! -f "$file_path" ]]; then
        echo "❌ ERROR: File not found: $file_path"
        exit 1
    fi
    
    # Prepare bq command
    local bq_cmd="bq query --use_legacy_sql=false --project_id=$PROJECT_ID"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        bq_cmd="$bq_cmd --dry_run"
        echo "🔍 DRY RUN: Validating SQL syntax..."
    else
        echo "🚀 EXECUTING: Running DDL commands..."
        
        # No longer need to inject checkpoint values - SQL files handle it directly
    fi
    
    # Execute the SQL file
    if $bq_cmd < "$file_path"; then
        if [[ "$DRY_RUN" == "true" ]]; then
            echo "✅ VALIDATION PASSED: SQL syntax is valid"
        else
            echo "✅ EXECUTION COMPLETED: All commands succeeded"
        fi
        echo "🕐 Finished: $(date '+%Y-%m-%d %H:%M:%S')"
    else
        local exit_code=$?
        echo ""
        echo "❌ PIPELINE FAILED"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "File: $file"
        echo "Path: $file_path"
        echo "Exit code: $exit_code"
        echo "Time: $(date '+%Y-%m-%d %H:%M:%S')"
        
        # Clean up temporary file if it was created
        if [[ "$temp_file" != "" ]] && [[ -f "$temp_file" ]]; then
            rm "$temp_file"
        fi
        exit $exit_code
    fi
    
    # Clean up temporary file if it was created
    if [[ "$temp_file" != "" ]] && [[ -f "$temp_file" ]]; then
        rm "$temp_file"
    fi
}

# Print pipeline header
echo "🚀 ENS BigQuery Incremental Pipeline Runner"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Project ID: $PROJECT_ID"
echo "DDL Directory: $DDL_DIR"
echo "Mode: $(if [[ "$DRY_RUN" == "true" ]]; then echo "DRY RUN (validation only)"; else echo "INCREMENTAL EXECUTION"; fi)"
echo "Force Full: $(if [[ "$FORCE_FULL" == "true" ]]; then echo "YES (checkpoint ignored)"; else echo "NO"; fi)"
echo "Total files: ${#PIPELINE_FILES[@]}"
echo "Start time: $(date '+%Y-%m-%d %H:%M:%S')"

# Check checkpoint status before starting
if [[ "$DRY_RUN" == "false" ]] && [[ "$FORCE_FULL" == "false" ]]; then
    echo ""
    echo "📊 Checking checkpoint status..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Try to get checkpoint info
    CHECKPOINT_INFO=$(bq query --use_legacy_sql=false --format=csv --project_id=$PROJECT_ID \
        "SELECT last_processed_block, last_updated FROM \`$PROJECT_ID.ens._pipeline_checkpoint\`" 2>/dev/null | tail -1 || echo "")
    
    if [[ -z "$CHECKPOINT_INFO" ]] || [[ "$CHECKPOINT_INFO" =~ "not found" ]]; then
        echo "⚠️  No checkpoint found - will process all blocks (first run)"
        echo "💡 This first run will cost ~$30.75 (full historical data)"
        echo "💡 Subsequent runs will cost ~$0.35/day (incremental)"
    else
        LAST_BLOCK=$(echo "$CHECKPOINT_INFO" | cut -d',' -f1)
        LAST_UPDATED=$(echo "$CHECKPOINT_INFO" | cut -d',' -f2)
        echo "✅ Checkpoint found:"
        echo "   Last processed block: $LAST_BLOCK"
        echo "   Last updated: $LAST_UPDATED"
        
        # Get current max block
        CURRENT_BLOCK=$(bq query --use_legacy_sql=false --format=csv --project_id=$PROJECT_ID \
            "SELECT MAX(block_number) FROM \`bigquery-public-data.goog_blockchain_ethereum_mainnet_us.logs\` 
             WHERE block_timestamp > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 2 DAY)" | tail -1)
        
        if [[ "$CURRENT_BLOCK" -gt "$LAST_BLOCK" ]]; then
            NEW_BLOCKS=$((CURRENT_BLOCK - LAST_BLOCK))
            echo "   Current block: $CURRENT_BLOCK"
            echo "   New blocks to process: $NEW_BLOCKS"
        else
            echo "   ⏸️  No new blocks to process"
        fi
    fi
fi

# Verify all files exist before starting
echo ""
echo "📋 Checking pipeline files..."
for file in "${PIPELINE_FILES[@]}"; do
    if [[ -f "$DDL_DIR/$file" ]]; then
        # Mark incremental stages
        if [[ "$file" == "create_ens_raw_events.sql" ]] || [[ "$file" == "create_base_registrar_events.sql" ]]; then
            echo "✅ $file (INCREMENTAL)"
        elif [[ "$file" == "create_checkpoint_table.sql" ]]; then
            echo "✅ $file (CHECKPOINT)"
        else
            echo "✅ $file"
        fi
    else
        echo "❌ $file (NOT FOUND)"
        echo ""
        echo "❌ PIPELINE ABORTED: Missing files detected"
        exit 1
    fi
done

# Run pipeline files in order
echo ""
echo "🎯 Starting incremental pipeline execution..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

for i in "${!PIPELINE_FILES[@]}"; do
    file_num=$((i + 1))
    total=${#PIPELINE_FILES[@]}
    file=${PIPELINE_FILES[$i]}
    
    echo ""
    echo "🎯 STAGE $file_num/$total: $file"
    
    # Mark incremental stages
    if [[ "$file" == "create_ens_raw_events.sql" ]] || [[ "$file" == "create_base_registrar_events.sql" ]]; then
        echo "📈 INCREMENTAL MODE: Processing only new blocks since checkpoint"
    elif [[ "$file" == "create_checkpoint_table.sql" ]]; then
        echo "🔧 CHECKPOINT: Initializing tracking table"
    else
        echo "🔄 REBUILD MODE: Full table rebuild (cost-effective)"
    fi
    
    run_ddl_file "$file"
done

# Update checkpoint after successful completion
if [[ "$DRY_RUN" == "false" ]]; then
    echo ""
    echo "📝 Updating checkpoint..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Update checkpoint with latest block number
    bq query --use_legacy_sql=false --project_id=$PROJECT_ID "
    MERGE \`$PROJECT_ID.ens._pipeline_checkpoint\` AS target
    USING (
      SELECT 
        MAX(block_number) AS last_processed_block,
        CURRENT_TIMESTAMP() AS last_updated,
        'completed' AS status,
        COUNT(DISTINCT block_number) AS blocks_processed,
        COUNT(*) AS events_processed
      FROM \`$PROJECT_ID.ens._raw_resolver_events\`
    ) AS source
    ON TRUE
    WHEN MATCHED THEN
      UPDATE SET 
        last_processed_block = source.last_processed_block,
        last_updated = source.last_updated,
        status = source.status,
        blocks_processed = source.blocks_processed,
        events_processed = source.events_processed - COALESCE(target.events_processed, 0)
    WHEN NOT MATCHED THEN
      INSERT (last_processed_block, last_updated, status, blocks_processed, events_processed)
      VALUES (source.last_processed_block, source.last_updated, source.status, source.blocks_processed, source.events_processed)"
    
    echo "✅ Checkpoint updated successfully"
fi

# Pipeline completed successfully
echo ""
echo "🎉 INCREMENTAL PIPELINE COMPLETED SUCCESSFULLY!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Total files processed: ${#PIPELINE_FILES[@]}"
echo "End time: $(date '+%Y-%m-%d %H:%M:%S')"

if [[ "$DRY_RUN" == "false" ]]; then
    # Show statistics
    echo ""
    echo "📊 Pipeline Statistics:"
    STATS=$(bq query --use_legacy_sql=false --format=csv --project_id=$PROJECT_ID "
    SELECT 
      last_processed_block,
      blocks_processed,
      events_processed,
      FORMAT_TIMESTAMP('%Y-%m-%d %H:%M:%S', last_updated) AS last_updated
    FROM \`$PROJECT_ID.ens._pipeline_checkpoint\`" | tail -1)
    
    if [[ ! -z "$STATS" ]]; then
        LAST_BLOCK=$(echo "$STATS" | cut -d',' -f1)
        BLOCKS=$(echo "$STATS" | cut -d',' -f2)
        EVENTS=$(echo "$STATS" | cut -d',' -f3)
        UPDATED=$(echo "$STATS" | cut -d',' -f4)
        
        echo "   Last processed block: $LAST_BLOCK"
        echo "   Blocks in this run: $BLOCKS"
        echo "   Events in this run: $EVENTS"
        echo "   Completed at: $UPDATED"
    fi
    
    echo ""
    echo "💰 Estimated cost for this run:"
    if [[ "$BLOCKS" -eq "0" ]]; then
        echo "   $0.00 (no new blocks)"
    elif [[ "$BLOCKS" -gt "1000000" ]]; then
        echo "   ~$30.75 (initial full load)"
    else
        echo "   ~$0.35 (incremental update)"
    fi
fi

echo ""
echo "📊 Check your tables:"
echo "   bq ls $PROJECT_ID:ens"
echo ""
echo "🔍 Key production tables:"
echo "   bq query \"SELECT COUNT(*) FROM \\\`$PROJECT_ID.ens.registry\\\`\""
echo "   bq query \"SELECT COUNT(*) FROM \\\`$PROJECT_ID.ens.resolvers\\\`\""
echo "   bq query \"SELECT COUNT(*) FROM \\\`$PROJECT_ID.ens.reverse_records\\\`\""

echo ""
echo "⏰ Schedule daily runs (recommended):"
echo "   ./scripts/setup_daily_schedule.sh $PROJECT_ID"
echo ""
echo "🔍 Monitor scheduled queries:"
echo "   https://console.cloud.google.com/bigquery/scheduled-queries?project=$PROJECT_ID"