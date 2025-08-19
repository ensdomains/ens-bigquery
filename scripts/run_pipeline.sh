#!/bin/bash

# ENS BigQuery Pipeline Runner
# Runs DDL files in correct order and stops on first error
# Usage: ./run_pipeline.sh [--project-id=PROJECT_ID] [--dry-run]

set -e  # Exit immediately on error

# Default values
PROJECT_ID="web3-publicgoods"
DRY_RUN=false
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
        -h|--help)
            echo "Usage: $0 [--project-id=PROJECT_ID] [--dry-run]"
            echo ""
            echo "Options:"
            echo "  --project-id=ID    BigQuery project ID (default: web3-publicgoods)"
            echo "  --dry-run          Validate queries without executing them"
            echo "  --help             Show this help message"
            echo ""
            echo "Pipeline stages (in execution order):"
            echo "  1. create_ens_raw_events.sql"
            echo "  2. create_resolver_event_tables.sql" 
            echo "  3. create_state_resolver.sql"
            echo "  4. create_aggregated_resolver.sql"
            echo "  5. create_resolver_table.sql"
            echo "  6. create_reverse_records_table.sql"
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
    "create_ens_raw_events.sql"
    "create_resolver_event_tables.sql"
    "create_state_resolver.sql" 
    "create_aggregated_resolver.sql"
    "create_resolver_table.sql"
    "create_reverse_records_table.sql"
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
echo "🔍 Production tables:"
echo "   bq query \"SELECT COUNT(*) FROM \\\`$PROJECT_ID.ens_temp2.resolvers\\\`\""
echo "   bq query \"SELECT COUNT(*) FROM \\\`$PROJECT_ID.ens_temp2.reverse_records\\\`\""