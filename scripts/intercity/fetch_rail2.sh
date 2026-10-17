#!/bin/bash
# usage: fetch_rail.sh <outdir> ; fetches OSM railway=rail for Java in 4 lon bands (+ Sumatra later)
cd "$1" || exit 1
fetch() { # name south west north east
  printf '[out:json][timeout:240];\nway["railway"="rail"](%s,%s,%s,%s);\nout geom;\n' "$2" "$3" "$4" "$5" > "q_$1.ql"
  for try in 1 2 3 4 5; do
    for u in https://overpass-api.de/api/interpreter https://overpass.kumi.systems/api/interpreter; do
      curl -s -m 280 -A "TemanKereta-research/1.0" --data-urlencode "data@q_$1.ql" "$u" -o "rail_$1.json"
      head -c 1 "rail_$1.json" | grep -q '{' && grep -q '"elements"' "rail_$1.json" && { echo "ok $1 $(stat -c %s rail_$1.json)"; return; }
    done
    sleep 20
  done
  echo "FAILED $1"
}
fetch sum1 -6.2 94.5 -1.0 106.2
fetch sum2 -1.0 94.5 3.0 101.5
fetch sum3 3.0 94.5 5.9 99.8
echo done
