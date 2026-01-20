#!/bin/bash

# Get number of CPU cores for normalization
NUM_CORES=$(nproc)

# Run the Python script in the background
./build_RelWithDebInfo/simple_gtsam_deserialize &
PYTHON_PID=$!

echo "Monitoring PID: $PYTHON_PID (System has $NUM_CORES CPU cores)"
echo "Time(s)    CPU(%)    CPU(%/core)    Memory(MB)"
echo "---------------------------------------------------"

# Arrays to store values
CPU_VALUES=()
CPU_NORMALIZED_VALUES=()
MEM_VALUES=()

# Monitor until the process finishes
while kill -0 $PYTHON_PID 2>/dev/null; do
    # Get CPU and memory usage using ps
    STATS=$(ps -p $PYTHON_PID -o %cpu,rss --no-headers 2>/dev/null)
    
    if [ -n "$STATS" ]; then
        CPU=$(echo $STATS | awk '{print $1}')
        # Normalize CPU usage by number of cores (for multi-threaded processes)
        CPU_NORMALIZED=$(awk "BEGIN {printf \"%.2f\", $CPU / $NUM_CORES}")
        MEM_KB=$(echo $STATS | awk '{print $2}')
        MEM_MB=$(awk "BEGIN {printf \"%.2f\", $MEM_KB / 1024}")
        echo "$(date +%s)    $CPU    $CPU_NORMALIZED    $MEM_MB"
        
        # Store values for statistics
        CPU_VALUES+=($CPU)
        CPU_NORMALIZED_VALUES+=($CPU_NORMALIZED)
        MEM_VALUES+=($MEM_MB)
    fi
    
    sleep 2
done

wait $PYTHON_PID
EXIT_CODE=$?
echo "Process finished with exit code: $EXIT_CODE"
echo ""

# Calculate and print statistics
if [ ${#CPU_VALUES[@]} -gt 0 ]; then
    # Calculate max CPU (raw, can exceed 100% for multi-threaded)
    MAX_CPU=$(printf '%s\n' "${CPU_VALUES[@]}" | awk 'BEGIN{max=0} {if($1>max) max=$1} END{print max}')
    
    # Calculate mean CPU (raw)
    MEAN_CPU=$(printf '%s\n' "${CPU_VALUES[@]}" | awk '{sum+=$1; count++} END{if(count>0) print sum/count; else print 0}')
    
    # Calculate max CPU normalized (per core, 0-100%)
    MAX_CPU_NORM=$(printf '%s\n' "${CPU_NORMALIZED_VALUES[@]}" | awk 'BEGIN{max=0} {if($1>max) max=$1} END{print max}')
    
    # Calculate mean CPU normalized
    MEAN_CPU_NORM=$(printf '%s\n' "${CPU_NORMALIZED_VALUES[@]}" | awk '{sum+=$1; count++} END{if(count>0) print sum/count; else print 0}')
    
    # Calculate max Memory
    MAX_MEM=$(printf '%s\n' "${MEM_VALUES[@]}" | awk 'BEGIN{max=0} {if($1>max) max=$1} END{print max}')
    
    # Calculate mean Memory
    MEAN_MEM=$(printf '%s\n' "${MEM_VALUES[@]}" | awk '{sum+=$1; count++} END{if(count>0) print sum/count; else print 0}')
    
    echo "Statistics:"
    echo "-----------"
    echo "CPU (raw, sum across cores) - Max: ${MAX_CPU}%, Mean: $(awk "BEGIN {printf \"%.2f\", $MEAN_CPU}")%"
    echo "CPU (normalized per core) - Max: $(awk "BEGIN {printf \"%.2f\", $MAX_CPU_NORM}")%, Mean: $(awk "BEGIN {printf \"%.2f\", $MEAN_CPU_NORM}")%"
    echo "Memory - Max: $(awk "BEGIN {printf \"%.2f\", $MAX_MEM}") MB, Mean: $(awk "BEGIN {printf \"%.2f\", $MEAN_MEM}") MB"
fi

