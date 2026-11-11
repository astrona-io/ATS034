#!/usr/bin/env bash
set -euo pipefail

sudo python3 /opt/astrona-live/check.py runtime
sudo python3 /opt/astrona-live/check.py workload
sudo docker rm -f scout
restore() {
  sudo docker rm -f scout >/dev/null 2>&1 || true
  sudo docker run -d --name scout --runtime=runsc -p 127.0.0.1:8080:8080 -v /srv/scout:/www:ro busybox:1.37.0 httpd -f -p 8080 -h /www
}
trap restore EXIT
sudo docker run -d --name scout --runtime=runc -p 127.0.0.1:8080:8080 -v /srv/scout:/www:ro busybox:1.37.0 httpd -f -p 8080 -h /www
set +e
output=$(sudo python3 /opt/astrona-live/check.py workload); status=$?
set -e
[[ "$status" == 1 && "$output" == 'FAIL: Run scout with the runsc runtime' ]]
restore
trap - EXIT
sudo python3 /opt/astrona-live/check.py workload
