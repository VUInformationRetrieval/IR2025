!/bin/bash

# Script to randomly remove 75% of lines from a text file, needed to get the IR2025 set in correct size
# Usage: ./random_line_remover.sh <input_file> [output_file]

# Function to display usage
usage() {
    echo "Usage: $0 <input_file> [output_file]"
    echo "  input_file:  The text file to process"
    echo "  output_file: Optional. If not provided, will overwrite the input file"
    echo ""
    echo "This script randomly removes 75% of lines, keeping 25% of the original lines."
    exit 1
}

# Check if input file is provided
if [ $# -lt 1 ]; then
    echo "Error: Input file not specified."
    usage
fi

INPUT_FILE="$1"
OUTPUT_FILE="${2:-$INPUT_FILE}"

# Check if input file exists
if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: Input file '$INPUT_FILE' does not exist."
    exit 1
fi

# Check if input file is readable
if [ ! -r "$INPUT_FILE" ]; then
    echo "Error: Cannot read input file '$INPUT_FILE'."
    exit 1
fi

# Count total lines in the file
TOTAL_LINES=$(wc -l < "$INPUT_FILE")

if [ "$TOTAL_LINES" -eq 0 ]; then
    echo "Error: Input file is empty."
    exit 1
fi

# Calculate number of lines to keep (25% of total)
LINES_TO_KEEP=$((TOTAL_LINES / 4))

# Ensure we keep at least 1 line if the file has any content
if [ "$LINES_TO_KEEP" -eq 0 ] && [ "$TOTAL_LINES" -gt 0 ]; then
    LINES_TO_KEEP=1
fi

echo "Total lines: $TOTAL_LINES"
echo "Lines to keep (25%): $LINES_TO_KEEP"
echo "Lines to remove (75%): $((TOTAL_LINES - LINES_TO_KEEP))"

# Show progress for large files
LINES_TO_REMOVE=$((TOTAL_LINES - LINES_TO_KEEP))
if [ "$LINES_TO_REMOVE" -gt 1000 ]; then
    echo "Processing large file - progress will be shown every 1000 removals..."
fi

# Create a temporary file for processing
TEMP_FILE=$(mktemp)

# Generate random line numbers to keep
# Use awk with RANDOM for portable randomization (works on all Unix-like systems)
awk -v total="$TOTAL_LINES" -v keep="$LINES_TO_KEEP" '
BEGIN {
    srand()  # Initialize random seed
    # Generate all line numbers
    for (i = 1; i <= total; i++) {
        lines[i] = i
    }
    
    # Fisher-Yates shuffle algorithm to randomly select lines
    for (i = total; i > total - keep; i--) {
        # Generate random index between 1 and i
        j = int(rand() * i) + 1
        # Swap elements
        temp = lines[i]
        lines[i] = lines[j]
        lines[j] = temp
    }
    
    # Output the last "keep" elements (which are randomly selected)
    for (i = total - keep + 1; i <= total; i++) {
        print lines[i]
    }
}' | sort -n > "$TEMP_FILE.line_numbers"

# Extract the selected lines with progress tracking
# For large files, we'll process line by line to show progress
if [ "$LINES_TO_REMOVE" -gt 1000 ]; then
    # Process with progress counter for large files
    > "$TEMP_FILE.output"  # Clear output file
    
    # Create array of lines to keep for faster lookup
    declare -A keep_lines
    while IFS= read -r line_num; do
        keep_lines[$line_num]=1
    done < "$TEMP_FILE.line_numbers"
    
    # Process file line by line with progress tracking
    current_line=0
    removed_count=0
    kept_count=0
    
    while IFS= read -r line_content; do
        current_line=$((current_line + 1))
        
        if [[ ${keep_lines[$current_line]} ]]; then
            # Keep this line
            echo "$line_content" >> "$TEMP_FILE.output"
            kept_count=$((kept_count + 1))
        else
            # Remove this line (count it)
            removed_count=$((removed_count + 1))
            
            # Show progress every 1000 removals
            if [ $((removed_count % 1000)) -eq 0 ]; then
                progress_percent=$((removed_count * 100 / LINES_TO_REMOVE))
                echo "Progress: Removed $removed_count/$LINES_TO_REMOVE lines (${progress_percent}%)"
            fi
        fi
    done < "$INPUT_FILE"
    
    echo "Final: Kept $kept_count lines, removed $removed_count lines"
    
else
    # For smaller files, use the faster sed approach without progress tracking
    SED_COMMAND=""
    while IFS= read -r line_num; do
        if [ -z "$SED_COMMAND" ]; then
            SED_COMMAND="${line_num}p"
        else
            SED_COMMAND="${SED_COMMAND};${line_num}p"
        fi
    done < "$TEMP_FILE.line_numbers"
    
    sed -n "$SED_COMMAND" "$INPUT_FILE" > "$TEMP_FILE.output"
fi

# Move the result to the output file
mv "$TEMP_FILE.output" "$OUTPUT_FILE"

# Clean up temporary files
rm -f "$TEMP_FILE" "$TEMP_FILE.line_numbers"

echo "Processing complete. Result saved to: $OUTPUT_FILE"
echo "Kept $LINES_TO_KEEP lines out of $TOTAL_LINES original lines."

