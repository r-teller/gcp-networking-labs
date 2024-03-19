```bash
docker run --rm -it -p 127.0.0.1:9001:9001 jpillora/chisel client -v --header "Authorization: Bearer $(gcloud auth print-identity-token)" https://gcr-chisel-usc1-708c-s2jepqga4a-uc.a.run.app 9000:1.2.3.4:5432
```