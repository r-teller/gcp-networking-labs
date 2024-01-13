# Verify Redis is enabled
`show system state filter cfg.platform.redis*`

```bash
## Example output
admin@palo-usw1a-01-6b09> show system state filter cfg.platform.redis*

cfg.platform.redis-cfg-update: True
cfg.platform.redis_auth_cfg: True
cfg.platform.redis_endpoint: 192.168.255.147:6378
```