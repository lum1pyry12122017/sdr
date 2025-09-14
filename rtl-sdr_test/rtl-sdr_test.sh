#!/bin/bash
# Compare RTL-SDR dongles on RPi4
# Ville – SDR Lab

MODE="vhf"   # default

if [ "$1" == "--hf" ]; then
  MODE="hf"
  echo "➡ Running HF test profile"
elif [ "$1" == "--hf20" ]; then
  MODE="hf20"
  echo "➡ Running HF 20m band test profile"
else
  echo "➡ Running VHF/UHF test profile (default)"
fi

# --------- AUTO-DETECT DONGLES ---------
echo "Detecting attached RTL-SDR dongles..."
DONGLES=($(rtl_test -t 2>&1 | grep -oP 'SN: \K\S+'))
if [ ${#DONGLES[@]} -eq 0 ]; then
  echo "❌ No RTL-SDR dongles found. Exiting."
  exit 1
fi
echo "Found dongles: ${DONGLES[@]}"

# --------- TEST FREQUENCIES ---------
if [ "$MODE" == "hf" ]; then
  BEACON_FREQ=10000000   # 10 MHz WWV (ppm test)
  SNR_FREQ=7100000       # 40m band
  SWEEP_RANGE="500k:30M:10k"
elif [ "$MODE" == "hf20" ]; then
  BEACON_FREQ=14074000   # FT8 frequency (ppm test)
  SNR_FREQ=14127000      # SSB calling freq
  SWEEP_RANGE="13M:15M:5k"
else
  FM_FREQ=98700000       # FM station
  WX_FREQ=162550000      # NOAA WX / ATIS
  SWEEP_RANGE="118M:174M:50k"
fi

# Sample rates (leave out 3.2 MS/s)
RATES=(1024000 1200000 1536000 2048000 2400000 2800000)

# Output dir
OUTDIR="$HOME/rtl_compare_results"
mkdir -p "$OUTDIR"

# --------- LOGGING ---------
LOGFILE="$OUTDIR/rtl_compare_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOGFILE") 2>&1
echo "➡ Logging to $LOGFILE"

# --------- FUNCTIONS ---------

test_samplerate() {
  local d=$1
  local outfile="$OUTDIR/${d}_samplerate.csv"
  echo "rate_hz,lost" > "$outfile"
  for r in "${RATES[@]}"; do
    echo "Testing $d @ $r ..."
    lost=$(timeout 60 rtl_test -d "$d" -s $r 2>&1 \
           | grep -ci "lost")
    echo "$r,$lost" >> "$outfile"
  done
}

test_ppm() {
  local d=$1
  local outfile="$OUTDIR/${d}_ppm.csv"
  echo "time_s,center_hz,peak_bin_hz,power_db" > "$outfile"
  if [ "$MODE" == "hf" ] || [ "$MODE" == "hf20" ]; then
    # ±2.5 kHz span, 10 Hz bins
    rtl_power -d "$d" -f $((BEACON_FREQ-2500)):$((BEACON_FREQ+2500)):10 \
              -i 1 -e 60 -g 30 >> "$outfile"
  else
    # ±100 kHz span, 1 kHz bins
    rtl_power -d "$d" -f $((FM_FREQ-100000)):$((FM_FREQ+100000)):1000 \
              -i 1 -e 60 -g 20 >> "$outfile"
  fi
}

test_snr() {
  local d=$1
  local outfile="$OUTDIR/${d}_snr.csv"
  echo "time_s,center_hz,peak_bin_hz,power_db" > "$outfile"
  if [ "$MODE" == "hf" ] || [ "$MODE" == "hf20" ]; then
    # ±5 kHz span, 5 Hz bins
    rtl_power -d "$d" -f $((SNR_FREQ-5000)):$((SNR_FREQ+5000)):5 \
              -i 1 -e 60 -g 30 >> "$outfile"
  else
    # ±100 kHz span, 1 kHz bins
    rtl_power -d "$d" -f $((WX_FREQ-100000)):$((WX_FREQ+100000)):1000 \
              -i 1 -e 60 -g 30 >> "$outfile"
  fi
}

test_spurs() {
  local d=$1
  local outfile="$OUTDIR/${d}_sweep.csv"
  echo "time_s,center_hz,peak_bin_hz,power_db" > "$outfile"
  rtl_power -d "$d" -f $SWEEP_RANGE -i 2 -e 120 -g 20 >> "$outfile"
}

test_adsb() {
  if [ "$MODE" == "hf" ] || [ "$MODE" == "hf20" ]; then
    echo "Skipping ADS-B test in HF mode."
    return
  fi
  local d=$1
  local outfile="$OUTDIR/${d}_adsb.json"
  echo "Testing $d ADS-B for 5 min..."
  timeout 300 readsb --device-type rtlsdr --device-serial "$d" \
         --gain 49.6 --quiet --write-json "$outfile"
}

# --------- MAIN LOOP ---------

for D in "${DONGLES[@]}"; do
  echo "===================="
  echo " Testing dongle: $D"
  echo "===================="

  test_samplerate "$D"
  test_ppm "$D"
  test_snr "$D"
  test_spurs "$D"
  test_adsb "$D"

  echo "Results saved in $OUTDIR for $D"
done

echo "✅ All tests done. Check $OUTDIR for CSV/JSON results."
