#!/usr/bin/env python3
import json
import subprocess
import sys

def get_document_content(document_name):
    """Get the content of an SSM document."""
    try:
        result = subprocess.run(
            ["aws", "ssm", "get-document", "--name", document_name],
            capture_output=True, text=True, check=True
        )
        return json.loads(result.stdout)
    except subprocess.CalledProcessError as e:
        print(f"Error getting document {document_name}: {e}", file=sys.stderr)
        return None

def check_python_runtime(document_name):
    """Check if a document uses aws:executeScript with Python 3.6-3.9 runtimes."""
    doc_content = get_document_content(document_name)
    if not doc_content:
        return None
    
    content = doc_content.get("Content")
    if not content:
        return None
    
    # Try to parse the content as JSON
    try:
        content_json = json.loads(content)
    except json.JSONDecodeError:
        # If it's not JSON (might be YAML), skip it
        return None
    
    # Check for aws:executeScript actions with Python runtimes
    python_scripts = []
    
    # Handle different document structures
    if "mainSteps" in content_json:
        steps = content_json["mainSteps"]
        for step in steps:
            if step.get("action") == "aws:executeScript":
                inputs = step.get("inputs", {})
                runtime = inputs.get("Runtime")
                if runtime and runtime.startswith("python3.") and runtime in ["python3.6", "python3.7", "python3.8", "python3.9"]:
                    python_scripts.append({
                        "step_name": step.get("name", "Unknown"),
                        "runtime": runtime
                    })
    
    if python_scripts:
        return {
            "document_name": document_name,
            "python_scripts": python_scripts
        }
    return None

def main():
    # Get list of documents owned by the current account
    result = subprocess.run(
        ["aws", "ssm", "list-documents", "--filters", "Key=Owner,Values=Self"],
        capture_output=True, text=True, check=True
    )
    
    documents = json.loads(result.stdout).get("DocumentIdentifiers", [])
    
    print(f"Found {len(documents)} documents to check")
    
    results = []
    for doc in documents:
        doc_name = doc["Name"]
        print(f"Checking document: {doc_name}")
        result = check_python_runtime(doc_name)
        if result:
            results.append(result)
    
    if results:
        print("\nDocuments using aws:executeScript with Python 3.6-3.9 runtimes:")
        for result in results:
            print(f"\nDocument: {result['document_name']}")
            for script in result['python_scripts']:
                print(f"  - Step: {script['step_name']}, Runtime: {script['runtime']}")
    else:
        print("\nNo documents found using aws:executeScript with Python 3.6-3.9 runtimes.")

if __name__ == "__main__":
    main()
