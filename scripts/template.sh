#!/bin/bash

CONFIG_FILE="config.yaml"

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
  echo "Error: $CONFIG_FILE not found"
  exit 1
fi

# Process only YAML files in packages directory
find packages -type f -name "*.yaml" -o -name "*.yml" | while read -r file; do
  # Check if file contains any template pattern {{ .key_name }}
  if grep -q "{{" "$file"; then
    echo "Processing $file"
    
    # Use grep to find lines with templates (excluding commented lines)
    grep -n "{{.*}}" "$file" | grep -v "^[[:space:]]*#" | while IFS=: read -r line_num line_content; do
      # Skip commented lines
      if [[ "$line_content" =~ ^[[:space:]]*# ]]; then
        continue
      fi
      
      # Extract template pattern from the line
      template=$(echo "$line_content" | grep -o "{{[[:space:]]*\.[a-zA-Z0-9_\.]*[[:space:]]*}}")
      
      # Skip if no valid template found
      if [ -z "$template" ]; then
        continue
      fi
      
      # Extract key from template
      key=$(echo "$template" | sed 's/{{[[:space:]]*\.\([a-zA-Z0-9_\.]*\)[[:space:]]*}}/\1/')
      
      # Skip if key is empty
      if [ -z "$key" ]; then
        continue
      fi
      
      # Get value using yq
      value=$(yq eval ".$key" "$CONFIG_FILE" 2>/dev/null)
      if [ "$value" = "null" ] || [ -z "$value" ]; then 
        echo "  Warning: No value found for key '$key' in $CONFIG_FILE"
        continue
      fi
      
      echo "  Replacing '$key' with '$value'"
      # Replace template with value (escape special characters in template and value)
      escaped_template=$(echo "$template" | sed 's/[\/&]/\\&/g')
      escaped_value=$(echo "$value" | sed 's/[\/&]/\\&/g')
      sed -i "s/$escaped_template/$escaped_value/" "$file"
    done
  fi
done

echo "Done!"