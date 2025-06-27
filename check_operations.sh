#!/bin/bash

echo "Checking AWS-QuickSetup-PatchPolicy-LA-66c4g operation 46a2ea39-473d-4a1b-8434-dab9025bb2c7"
aws cloudformation describe-stack-set-operation --stack-set-name AWS-QuickSetup-PatchPolicy-LA-66c4g --operation-id 46a2ea39-473d-4a1b-8434-dab9025bb2c7 --region us-west-2 --query "StackSetOperation.Status" --output text

echo "Checking AWS-QuickSetup-PatchPolicy-LA-bkt1x operation 48fb3456-c16b-44f4-a389-92755675154f"
aws cloudformation describe-stack-set-operation --stack-set-name AWS-QuickSetup-PatchPolicy-LA-bkt1x --operation-id 48fb3456-c16b-44f4-a389-92755675154f --region us-west-2 --query "StackSetOperation.Status" --output text

echo "Checking AWS-QuickSetup-PatchPolicy-LA-dl6fl operation 74d64447-c8a5-467d-9739-826335df6099"
aws cloudformation describe-stack-set-operation --stack-set-name AWS-QuickSetup-PatchPolicy-LA-dl6fl --operation-id 74d64447-c8a5-467d-9739-826335df6099 --region us-west-2 --query "StackSetOperation.Status" --output text

echo "Checking AWS-QuickSetup-PatchPolicy-MA-w909z operation 1c598248-270d-4f1f-ad54-adb3aac34e5a"
aws cloudformation describe-stack-set-operation --stack-set-name AWS-QuickSetup-PatchPolicy-MA-w909z --operation-id 1c598248-270d-4f1f-ad54-adb3aac34e5a --region us-west-2 --query "StackSetOperation.Status" --output text

echo "Checking AWS-QuickSetup-PatchPolicy-TA-w909z operation e7a6091b-4581-467b-8c06-21d7b1fbc63a"
aws cloudformation describe-stack-set-operation --stack-set-name AWS-QuickSetup-PatchPolicy-TA-w909z --operation-id e7a6091b-4581-467b-8c06-21d7b1fbc63a --region us-west-2 --query "StackSetOperation.Status" --output text
