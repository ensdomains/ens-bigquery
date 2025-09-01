#!/bin/bash

# Backup ENS dataset to ens_backup
# Usage: ./backup_dataset.sh [PROJECT_ID]

PROJECT_ID="${1:-web3-publicgoods}"

echo "🔄 Backing up ENS dataset..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Project: $PROJECT_ID"
echo "Source: ${PROJECT_ID}:ens"
echo "Destination: ${PROJECT_ID}:ens_backup"
echo ""

# Get list of tables
echo "📋 Getting list of tables..."
TABLES=$(bq ls --max_results=1000 ${PROJECT_ID}:ens | tail -n +3 | awk '{print $1}')

if [ -z "$TABLES" ]; then
    echo "❌ No tables found in ${PROJECT_ID}:ens"
    exit 1
fi

TABLE_COUNT=$(echo "$TABLES" | wc -l)
echo "✅ Found $TABLE_COUNT tables to backup"

# Backup each table
echo ""
echo "📦 Starting backup process..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

CURRENT=0
for table in $TABLES; do
    CURRENT=$((CURRENT + 1))
    echo "[$CURRENT/$TABLE_COUNT] Backing up $table..."
    
    if bq cp ${PROJECT_ID}:ens.$table ${PROJECT_ID}:ens_backup.$table; then
    else
        echo "❌ Failed to backup $table"
        exit 1
    fi
done

echo ""
echo "🎉 Backup completed successfully!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Backed up $TABLE_COUNT tables to ${PROJECT_ID}:ens_backup"
echo ""
echo "🔍 Verify backup:"
echo "   bq ls ${PROJECT_ID}:ens_backup"
echo ""
echo "📊 Compare table counts:"
echo "   bq query 'SELECT \"original\" as source, COUNT(*) as table_count FROM \\\`${PROJECT_ID}.ens.__TABLES__\\\` 
             UNION ALL SELECT \"backup\", COUNT(*) FROM \\\`${PROJECT_ID}.ens_backup.__TABLES__\\\`'"