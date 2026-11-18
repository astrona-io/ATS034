---
draft: true
---
# Solution

Run these commands inside the VM:

```sh
sudo /usr/local/bin/runsc install --runtime=runsc -- --platform=systrap
sudo systemctl restart docker
sudo docker run -d --name scout --runtime=runsc -p 127.0.0.1:8080:8080 -v /srv/scout:/www:ro busybox:1.37.0 httpd -f -p 8080 -h /www
```

Inspect scout with `sudo docker inspect scout --format '{{.HostConfig.Runtime}}'`, inspect its kernel log with `sudo docker exec scout dmesg`, and request `http://127.0.0.1:8080/`. The response must be `scout-ready`.
