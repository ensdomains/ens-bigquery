#!/bin/bash

# ENS BigQuery Pipeline Runner
# Runs DDL files in correct order and stops on first error
# Usage: ./run_pipeline.sh [--project-id=PROJECT_ID] [--dry-run]

set -e  # Exit immediately on error

# Default values
PROJECT_ID="web3-publicgoods"
DRY_RUN=false
SKIP_SETUP=false
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
        --skip-setup)
            SKIP_SETUP=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [--project-id=PROJECT_ID] [--dry-run] [--skip-setup]"
            echo ""
            echo "Options:"
            echo "  --project-id=ID    BigQuery project ID (default: web3-publicgoods)"
            echo "  --dry-run          Validate queries without executing them"
            echo "  --skip-setup       Skip create_tables.sql and load_labels_from_preimages.sql"
            echo "  --help             Show this help message"
            echo ""
            echo "Pipeline stages:"
            echo ""
            echo "Setup phase (automatic if needed, or use --skip-setup):"
            echo "  - create_tables.sql (create empty table structures)"
            echo "  - load_labels_from_preimages.sql (load 133M+ label preimages)"
            echo ""
            echo "Main pipeline (13 stages in order):"
            echo "  1. create_functions.sql (all UDF functions - must be first!)"
            echo "  2. create_ens_raw_events.sql"
            echo "  3. create_controller_event_tables.sql"
            echo "  4. create_base_registrar_event_tables.sql"
            echo "  5. create_resolver_event_tables.sql" 
            echo "  6. create_state_resolver.sql"
            echo "  7. create_aggregated_resolver.sql"
            echo "  8. create_resolver_table.sql"
            echo "  9. create_aggregated_registry.sql"
            echo " 10. create_registry_table.sql"
            echo " 11. create_registration_periods_table.sql"
            echo " 12. create_reverse_records_table.sql"
            echo " 13. create_resolutions_table.sql"
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
# Note: Assumes tables and functions already exist. 
# If starting fresh, run create_tables.sql and create_functions.sql first
PIPELINE_FILES=(
    "create_functions.sql"                    # All UDF functions (must be first!)
    "create_ens_raw_events.sql"              # Extract raw events from Ethereum logs
    "create_controller_event_tables.sql"      # Decode NameRegistered/NameRenewed events
    "create_base_registrar_event_tables.sql"  # Decode NameMigrated events
    "create_resolver_event_tables.sql"        # Decode all resolver events
    "create_state_resolver.sql"               # Compute latest state per node
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
        echo ""
        echo "💡 To debug this file:"
        echo "   bq query --use_legacy_sql=false --project_id=$PROJECT_ID < $file_path"
        echo ""
        echo "💡 To run from this point forward:"
        echo "   # Fix the issue in $file, then run remaining files manually"
        exit $exit_code
    fi
}

# Print pipeline header
echo "🚀 ENS BigQuery Pipeline Runner"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Project ID: $PROJECT_ID"
echo "DDL Directory: $DDL_DIR"
echo "Mode: $(if [[ "$DRY_RUN" == "true" ]]; then echo "DRY RUN (validation only)"; else echo "EXECUTION"; fi)"
echo "Total files: ${#PIPELINE_FILES[@]}"
echo "Start time: $(date '+%Y-%m-%d %H:%M:%S')"

# Verify all files exist before starting
echo ""
echo "📋 Checking pipeline files..."
for file in "${PIPELINE_FILES[@]}"; do
    if [[ -f "$DDL_DIR/$file" ]]; then
        echo "✅ $file"
    else
        echo "❌ $file (NOT FOUND)"
        echo ""
        echo "❌ PIPELINE ABORTED: Missing files detected"
        exit 1
    fi
done

# Run initial setup if not skipped
if [[ "$SKIP_SETUP" == "false" ]]; then
    echo ""
    echo "🔧 Running initial setup..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Check if labels table exists and has data
    LABELS_COUNT=$(bq query --use_legacy_sql=false --format=csv --project_id=$PROJECT_ID "SELECT COUNT(*) FROM \`$PROJECT_ID.ens_temp2.labels\`" 2>/dev/null | tail -1 || echo "0")
    
    if [[ "$LABELS_COUNT" == "0" ]] || [[ -z "$LABELS_COUNT" ]]; then
        echo ""
        echo "📋 Creating tables and loading labels..."
        
        # Create tables if they don't exist
        if [[ -f "$DDL_DIR/create_tables.sql" ]]; then
            echo "🎯 SETUP: create_tables.sql"
            run_ddl_file "create_tables.sql"
        fi
        
        # Load labels if table is empty
        if [[ -f "$DDL_DIR/load_labels_from_preimages.sql" ]]; then
            echo ""
            echo "🎯 SETUP: load_labels_from_preimages.sql"
            echo "⚠️  This will load 133M+ records from preimagedb and may take several minutes..."
            run_ddl_file "load_labels_from_preimages.sql"
        fi
    else
        echo "✅ Labels table exists with $LABELS_COUNT records"
    fi
else
    echo ""
    echo "⚠️  Skipping initial setup (--skip-setup flag provided)"
fi

# Run pipeline files in order
echo ""
echo "🎯 Starting pipeline execution..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

for i in "${!PIPELINE_FILES[@]}"; do
    file_num=$((i + 1))
    total=${#PIPELINE_FILES[@]}
    file=${PIPELINE_FILES[$i]}
    
    echo ""
    echo "🎯 STAGE $file_num/$total: $file"
    run_ddl_file "$file"
done

# Pipeline completed successfully
echo ""
echo "🎉 PIPELINE COMPLETED SUCCESSFULLY!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Total files processed: ${#PIPELINE_FILES[@]}"
echo "End time: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""
echo "📊 Check your tables:"
echo "   bq ls $PROJECT_ID:ens_temp2"
echo ""
echo "🔍 Key production tables:"
echo "   bq query \"SELECT COUNT(*) FROM \\\`$PROJECT_ID.ens_temp2.registry\\\`\""
echo "   bq query \"SELECT COUNT(*) FROM \\\`$PROJECT_ID.ens_temp2.resolvers\\\`\""
echo "   bq query \"SELECT COUNT(*) FROM \\\`$PROJECT_ID.ens_temp2.reverse_records\\\`\""
echo "   bq query \"SELECT COUNT(*) FROM \\\`$PROJECT_ID.ens_temp2.registration_periods\\\`\""
echo "   bq query \"SELECT COUNT(*) FROM \\\`$PROJECT_ID.ens_temp2.resolutions\\\`\""