```bash
docker run --rm -it -p 9001:9001 -p 9002:9002 jpillora/chisel client \
    -v --header "Authorization: Bearer $(gcloud auth print-identity-token)" \
    https://gcr-chisel-usc1-708c-s2jepqga4a-uc.a.run.app \
    9001:10.64.2.3:5432 \
    9002:socks
```

```powershell
docker run --rm -it -p 9001:9001 -p 9002:9002 jpillora/chisel client `
    -v --header "Authorization: Bearer $(gcloud auth print-identity-token)" `
    https://gcr-chisel-usc1-708c-s2jepqga4a-uc.a.run.app `
    9001:10.64.2.3:5432 `
    9002:socks
```