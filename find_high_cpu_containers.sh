#!/bin/bash

# Usage: ./find_high_cpu_containers.sh [process_filter] [cpu_threshold]
# Examples:
# ./find_high_cpu_containers.sh          # All processes, 50% threshold
# ./find_high_cpu_containers.sh python   # Python processes only, 50% threshold
# ./find_high_cpu_containers.sh java 80  # Java processes only, 80% threshold

# Parse command line arguments
PROCESS_FILTER="${1:-}"
HIGH_CPU_THRESHOLD="${2:-50}"

# Show usage help
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    echo "Usage: $0 [process_filter] [cpu_threshold]"
    echo ""
    echo "Arguments:"
    echo "  process_filter   Filter processes by name (e.g., python, java, node)"
    echo "                   If not specified, all processes are analyzed"
    echo "  cpu_threshold    CPU usage percentage threshold (default: 50)"
    echo ""
    echo "Examples:"
    echo "  $0               # All processes with CPU ≥50%"
    echo "  $0 python        # Python processes with CPU ≥50%"
    echo "  $0 java 80       # Java processes with CPU ≥80%"
    exit 0
fi

# Set filter description for display
if [ -z "$PROCESS_FILTER" ]; then
    FILTER_DESC="all processes"
    PROCESS_GREP=""
else
    FILTER_DESC="$PROCESS_FILTER processes"
    PROCESS_GREP="$PROCESS_FILTER"
fi

echo "=== Docker Containers with High CPU $FILTER_DESC ==="
echo ""

# Get all running containers
containers=$(docker ps --filter "status=running" --format "{{.ID}} {{.Names}}")

if [ -z "$containers" ]; then
    echo "No running containers found."
    exit 0
fi

echo "Analyzing containers for high CPU $FILTER_DESC (threshold: ${HIGH_CPU_THRESHOLD}%)..."
echo ""

echo "$containers" | while IFS= read -r container_info; do
    container_id=$(echo $container_info | cut -d' ' -f1)
    container_name=$(echo $container_info | cut -d' ' -f2-)

    echo "--- Container: $container_name (ID: $container_id) ---"

    # Get top processes in the container
    if docker top $container_id >/dev/null 2>&1; then

        # Get full output for analysis
        docker_output=$(docker top $container_id)

        # Check for filtered processes
        if [ -z "$PROCESS_GREP" ]; then
            # Analyze all processes (skip header)
            process_count=$(echo "$docker_output" | tail -n +2 | wc -l)
            if [ "$process_count" -gt 0 ]; then
                echo "Processes found ($process_count total):"
                filter_cmd="tail -n +2"
            else
                echo "  No processes found"
                echo ""
                continue
            fi
        else
            # Check for specific process type
            if echo "$docker_output" | grep -q "$PROCESS_GREP"; then
                echo "$PROCESS_FILTER processes found:"
                filter_cmd="grep $PROCESS_GREP"
            else
                echo "  No $PROCESS_FILTER processes found"
                echo ""
                continue
            fi
        fi

        # Get the header to understand column positions
        header=$(echo "$docker_output" | head -n 1)

        # Find CPU column index (look for %CPU, CPU, or C column)
        cpu_col=$(echo "$header" | tr '\t' ' ' | tr -s ' ' | awk '{
            for(i=1;i<=NF;i++) {
                if ($i ~ /%?CPU/ || $i == "C") {
                    print i;
                    exit;
                }
            }
            # Default to column 4 (standard "C" column)
            print 4;
        }')

        # Find command column index (usually the last few columns)
        cmd_col=$(echo "$header" | tr '\t' ' ' | tr -s ' ' | awk '{
            for(i=1;i<=NF;i++) {
                if ($i == "COMMAND" || $i == "CMD") {
                    print i;
                    exit;
                }
            }
            # If no COMMAND/CMD found, assume it starts from column 12
            print 12;
        }')

        # Process each filtered process
        eval "$filter_cmd" <<< "$docker_output" | while read -r line; do
            # Skip empty lines
            [ -z "$line" ] && continue

            # Extract CPU usage
            cpu_value=$(echo "$line" | tr '\t' ' ' | tr -s ' ' | awk -v cpu_col="$cpu_col" '{print $cpu_col}')

            # Extract command (everything from command column to end)
            command=$(echo "$line" | tr '\t' ' ' | tr -s ' ' | awk -v cmd_col="$cmd_col" '{for(i=cmd_col;i<=NF;i++) printf "%s ", $i; print ""}')

            # Clean up CPU value (remove % if present)
            cpu_clean=$(echo "$cpu_value" | tr -d '%')

            # Check if CPU is a valid number
            if [[ "$cpu_clean" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
                cpu_num=$(echo "$cpu_clean" | cut -d'.' -f1)

                if [ "$cpu_num" -ge "$HIGH_CPU_THRESHOLD" ]; then
                    echo "  ⚠️  HIGH LOAD: $command CPU:${cpu_value}%"
                else
                    echo "  ✓  Normal: $command CPU:${cpu_value}%"
                fi
            else
                echo "  ?  Invalid CPU: $command CPU:${cpu_value}"
            fi
        done
    else
        echo "  Error: Cannot access container processes"
    fi

    echo ""
done

echo "=== Summary ==="
echo "High CPU threshold: ${HIGH_CPU_THRESHOLD}%"
if [ -z "$PROCESS_FILTER" ]; then
    echo "All processes using ≥${HIGH_CPU_THRESHOLD}% CPU are marked with ⚠️"
else
    echo "Containers with $PROCESS_FILTER processes using ≥${HIGH_CPU_THRESHOLD}% CPU are marked with ⚠️"
fi
echo ""

# Create summary data
summary_file=$(mktemp)
> "$summary_file"

echo "$containers" | while IFS= read -r container_info; do
    container_id=$(echo $container_info | cut -d' ' -f1)
    container_name=$(echo $container_info | cut -d' ' -f2-)

    if docker top $container_id >/dev/null 2>&1; then
        docker_output=$(docker top $container_id)

        # Set filter for summary calculation
        if [ -z "$PROCESS_GREP" ]; then
            filter_cmd="tail -n +2"  # All processes, skip header
        else
            filter_cmd="grep $PROCESS_GREP"
        fi

        # Check if there are matching processes
        if eval "$filter_cmd" <<< "$docker_output" | grep -q .; then
            # Get header and find CPU column
            header=$(echo "$docker_output" | head -n 1)
            cpu_col=$(echo "$header" | tr '\t' ' ' | tr -s ' ' | awk '{
                for(i=1;i<=NF;i++) {
                    if ($i ~ /%?CPU/ || $i == "C") {
                        print i;
                        exit;
                    }
                }
                print 4;
            }')

            cmd_col=$(echo "$header" | tr '\t' ' ' | tr -s ' ' | awk '{
                for(i=1;i<=NF;i++) {
                    if ($i == "COMMAND" || $i == "CMD") {
                        print i;
                        exit;
                    }
                }
                print 12;
            }')

            # Calculate total CPU and collect process details
            total_cpu=0

            # Process each filtered process
            eval "$filter_cmd" <<< "$docker_output" | while read -r line; do
                # Skip empty lines
                [ -z "$line" ] && continue

                cpu_value=$(echo "$line" | tr '\t' ' ' | tr -s ' ' | awk -v cpu_col="$cpu_col" '{print $cpu_col}')
                command=$(echo "$line" | tr '\t' ' ' | tr -s ' ' | awk -v cmd_col="$cmd_col" '{for(i=cmd_col;i<=NF;i++) printf "%s ", $i; print ""}')

                cpu_clean=$(echo "$cpu_value" | tr -d '%')
                if [[ "$cpu_clean" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
                    total_cpu=$((total_cpu + cpu_clean))
                    # Format: "cpu|command" for sorting
                    echo "${cpu_clean}|${command}" >> /tmp/processes_${container_id}.tmp
                fi
            done

            # Check if total CPU was calculated (subshell fix)
            if [ -f "/tmp/processes_${container_id}.tmp" ]; then
                # Calculate total from the temp file
                calculated_total=$(awk -F'|' '{sum += $1} END {print sum}' "/tmp/processes_${container_id}.tmp")
                if [ "$calculated_total" -gt 0 ]; then
                    echo "${calculated_total}|${container_id}|${container_name}" >> "$summary_file"
                fi
            fi
        fi
    fi
done

# Display summary table
echo "=== Container CPU Usage Summary (Sorted by Total $FILTER_DESC CPU) ==="
echo ""
printf "%-30s %-15s %-10s %s\n" "Container Name" "Container ID" "Total CPU" "Top 3 Processes"
printf "%-30s %-15s %-10s %s\n" "---------------" "-------------" "---------" "---------------"

# Sort by total CPU (descending) and display top containers
if [ -s "$summary_file" ]; then
    sort -nr "$summary_file" | head -10 | while IFS='|' read -r total_cpu container_id container_name; do
        # Get top 3 processes for this container
        if [ -f "/tmp/processes_${container_id}.tmp" ]; then
            echo ""
            printf "%-30s %-15s %-10s " "${container_name:0:29}" "${container_id:0:14}" "${total_cpu}%"

            # Sort processes by CPU and take top 3
            sort -nr "/tmp/processes_${container_id}.tmp" | head -3 | while IFS='|' read -r process_cpu process_cmd; do
                process_cmd_trim=$(echo "$process_cmd" | cut -c1-50)
                echo ""
                printf "%-57s %-3s%% %s\n" "" "${process_cpu}" "${process_cmd_trim}..."
            done

            # Clean up temp file
            rm -f "/tmp/processes_${container_id}.tmp"
        fi
    done
else
    if [ -z "$PROCESS_FILTER" ]; then
        echo "No containers with processes found."
    else
        echo "No containers with $PROCESS_FILTER processes found."
    fi
fi

echo ""
echo "=== END SUMMARY ==="

# Clean up
rm -f "$summary_file"

# Clean up any remaining temp files
rm -f /tmp/processes_*.tmp