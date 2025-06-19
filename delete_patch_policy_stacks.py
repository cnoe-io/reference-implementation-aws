#!/usr/bin/env python3
import boto3
import time
import sys

def list_patch_policy_stacks(region):
    """List all stacks that start with 'StackSet-AWS-QuickSetup-PatchPolicy' in the specified region."""
    cf_client = boto3.client('cloudformation', region_name=region)
    stacks = []
    
    paginator = cf_client.get_paginator('list_stacks')
    for page in paginator.paginate(StackStatusFilter=[
        'CREATE_COMPLETE', 'UPDATE_COMPLETE', 'UPDATE_ROLLBACK_COMPLETE', 'ROLLBACK_COMPLETE'
    ]):
        for stack in page['StackSummaries']:
            if stack['StackName'].startswith('StackSet-AWS-QuickSetup-PatchPolicy'):
                stacks.append(stack['StackName'])
    
    return stacks

def delete_stack(region, stack_name):
    """Delete a CloudFormation stack."""
    cf_client = boto3.client('cloudformation', region_name=region)
    print(f"Deleting stack {stack_name} in {region}...")
    try:
        cf_client.delete_stack(StackName=stack_name)
        return True
    except Exception as e:
        print(f"Error deleting stack {stack_name} in {region}: {e}")
        return False

def wait_for_stack_deletion(region, stack_name, timeout=300):
    """Wait for a stack to be deleted."""
    cf_client = boto3.client('cloudformation', region_name=region)
    start_time = time.time()
    
    while time.time() - start_time < timeout:
        try:
            stack = cf_client.describe_stacks(StackName=stack_name)
            status = stack['Stacks'][0]['StackStatus']
            
            if status.endswith('_IN_PROGRESS'):
                print(f"Stack {stack_name} in {region} is being deleted... Status: {status}")
                time.sleep(10)
            else:
                print(f"Stack {stack_name} in {region} is in state {status}, which is not a deletion state.")
                return False
        except cf_client.exceptions.ClientError as e:
            if 'does not exist' in str(e):
                print(f"Stack {stack_name} in {region} has been deleted successfully.")
                return True
            else:
                print(f"Error checking stack {stack_name} in {region}: {e}")
                return False
    
    print(f"Timeout waiting for stack {stack_name} in {region} to be deleted.")
    return False

def main():
    regions = ['us-east-1', 'us-east-2', 'us-west-1', 'us-west-2']
    
    for region in regions:
        print(f"\nChecking region {region}...")
        stacks = list_patch_policy_stacks(region)
        
        if not stacks:
            print(f"No 'StackSet-AWS-QuickSetup-PatchPolicy' stacks found in {region}.")
            continue
        
        print(f"Found {len(stacks)} 'StackSet-AWS-QuickSetup-PatchPolicy' stacks in {region}:")
        for stack in stacks:
            print(f"  - {stack}")
        
        for stack in stacks:
            if delete_stack(region, stack):
                wait_for_stack_deletion(region, stack)

if __name__ == "__main__":
    main()
