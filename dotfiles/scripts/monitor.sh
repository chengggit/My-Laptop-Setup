echo "timestamp,cpu_util,cpu_temp,gpu_util,gpu_temp" > ~/noall.csv

for i in $(seq 60); do
  TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
  CPU_UTIL=$(top -bn1 | grep "Cpu(s)" | grep -oP '[\d.]+(?=\s*us)' | head -1)
  CPU_TEMP=$(sensors | grep "Package id 0" | grep -oP '\+\K[\d.]+' | head -1)
  GPU=$(nvidia-smi --query-gpu=utilization.gpu,temperature.gpu --format=csv,noheader,nounits)
  GPU_UTIL=$(echo $GPU | cut -d',' -f1 | tr -d ' ')
  GPU_TEMP=$(echo $GPU | cut -d',' -f2 | tr -d ' ')
  echo "$TIMESTAMP,$CPU_UTIL,$CPU_TEMP,$GPU_UTIL,$GPU_TEMP" >> ~/noall.csv
  sleep 1
done
