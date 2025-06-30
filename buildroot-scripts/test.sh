#!/bin/bash
set -e
set -x
ARTIFACTS="$1"

if ! [[ -d "$ARTIFACTS" ]]; then
  echo "Artifacts folder does not exist."
  exit 1
fi

# Create a named pipe for QEMU serial output
rm -f qemu_output.pipe || true
mkfifo qemu_output.pipe

KERNEL_FILE="$ARTIFACTS"/zebrafish-kernel
INITRD_FILE="$ARTIFACTS"/zebrafish-initrd

# Choose which QEMU binary to use based on the kernel architecture
if file "$KERNEL_FILE" | grep -q "Linux kernel x86"; then
    QEMU_BINARY="qemu-system-x86_64"
    QEMU_FLAGS=""
else
    QEMU_BINARY="qemu-system-aarch64"
    QEMU_FLAGS="-cpu neoverse-n1 -machine virt -bios ovmf_aarch64.fd"
    exit 0
fi

# Start QEMU in background with serial output to pipe
"$QEMU_BINARY" \
  $QEMU_FLAGS \
  -kernel "$KERNEL_FILE" \
  -initrd "$INITRD_FILE" \
  -nographic \
  -serial pipe:qemu_output.pipe \
  -append "console=ttyS0" \
  -m 1G \
  -smp 1 \
  -no-reboot \
  -no-shutdown &

QEMU_PID=$!
echo "QEMU started with PID: $QEMU_PID"

# Monitor the output with timeout
timeout 120 bash -c '
  echo "Monitoring QEMU output for boot message..."
  while IFS= read -r line; do
    echo "QEMU: $line"
    if [[ "$line" == *"Successfully started Crony daemon"* ]]; then
      exit 0
    fi
  done < qemu_output.pipe
  exit 1
'

if [[ $? -eq 0 ]]; then
  SUCCESS="true"
else
  SUCCESS="false"
fi

# Clean up QEMU process
echo "Stopping QEMU..."
kill $QEMU_PID 2>/dev/null || true
wait $QEMU_PID 2>/dev/null || true

# Clean up pipe
rm -f qemu_output.pipe

# Check result
if [ "$SUCCESS" = "true" ]; then
  echo "✓ Boot test PASSED"
  exit 0
else
  echo "✗ Boot test FAILED"
  exit 1
fi