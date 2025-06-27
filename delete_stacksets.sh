#!/bin/bash

function check_operation() {
    local stackset=$1
    local operation_id=$2
    
    echo "Checking operation for $stackset..."
    status=$(aws cloudformation describe-stack-set-operation --stack-set-name $stackset --operation-id $operation_id --region us-west-2 --query "StackSetOperation.Status" --output text 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        echo "Error checking operation status for $stackset. It might have been deleted already."
        return 0
    fi
    
    echo "Status: $status"
    if [ "$status" == "SUCCEEDED" ] || [ "$status" == "FAILED" ] || [ "$status" == "STOPPED" ]; then
        return 0
    else
        return 1
    fi
}

function delete_stackset() {
    local stackset=$1
    
    echo "Deleting StackSet $stackset..."
    aws cloudformation delete-stack-set --stack-set-name $stackset --region us-west-2
    
    if [ $? -eq 0 ]; then
        echo "Successfully deleted StackSet $stackset"
    else
        echo "Failed to delete StackSet $stackset"
    fi
}

# Define the StackSets and their operation IDs
declare -A stacksets=(
    ["AWS-QuickSetup-PatchPolicy-LA-66c4g"]="46a2ea39-473d-4a1b-8434-dab9025bb2c7"
    ["AWS-QuickSetup-PatchPolicy-LA-bkt1x"]="48fb3456-c16b-44f4-a389-92755675154f"
    ["AWS-QuickSetup-PatchPolicy-LA-dl6fl"]="74d64447-c8a5-467d-9739-826335df6099"
    ["AWS-QuickSetup-PatchPolicy-TA-w909z"]="e7a6091b-4581-467b-8c06-21d7b1fbc63a"
)

# Wait for all operations to complete
echo "Waiting for all operations to complete..."
while true; do
    all_complete=true
    
    for stackset in "${!stacksets[@]}"; do
        operation_id=${stacksets[$stackset]}
        
        if ! check_operation "$stackset" "$operation_id"; then
            all_complete=false
        fi
    done
    
    if $all_complete; then
        echo "All operations have completed."
        break
    else
        echo "Waiting for 60 seconds..."
        sleep 60
    fi
done

# Delete all StackSets
echo "Deleting all StackSets..."
for stackset in "${!stacksets[@]}"; do
    delete_stackset "$stackset"
done

echo "All StackSets with 'AWS-QuickSetup-PatchPolicy' in the name have been deleted."
