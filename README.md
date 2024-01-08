# gcp-networking-labs

# List of Reserved IP Ranges for Google Services
- **AlloyDB** --> https://cloud.google.com/alloydb/docs/about-private-services-access#limitations
- **Anthos** --> https://cloud.google.com/anthos/clusters/docs/on-prem/latest/how-to/ip-block-file
- **Backup and DR** --> https://cloud.google.com/backup-disaster-recovery/docs/deployment/deployment-guide#deployment-wizard
- **Docker** --> I cannot find any formal documentation but my observed experience is that 172.17.0.0/16 is the default range used and that if the GCE instance belongs to 172.17.0.0/16 than it uses 172.18.0.0/16 for Docker
- **DMS / Cloud** SQL --> https://cloud.google.com/database-migration/docs/mysql/debugging-connectivity#private_ip_addresses
- **Cloud Build** --> https://cloud.google.com/build/docs/private-pools/set-up-private-pool-to-use-in-vpc-network#setup-private-connection
- **Cloud Composer** --> https://cloud.google.com/composer/docs/how-to/managing/configuring-private-ip#choose_a_network_subnetwork_and_network_ranges
- **Filestore** --> https://cloud.google.com/filestore/docs/known-issues#basic_tier_instances_and_clients_cant_have_an_ip_address_from_the_172170016_range
- **GKE** --> https://cloud.google.com/kubernetes-engine/docs/how-to/private-clusters#req_res_lim
- **Memorystore** --> https://cloud.google.com/memorystore/docs/memcached/networking#supported_networks_and_client_ip_ranges


| Service        | CIDR Range                           | Notes                                             |
| -------------- | ------------------------------------ | ------------------------------------------------- |
| Cloud Build    | - 192.168.10.0/24<br>- 172.17.0.0/16 |                                                   |
| Cloud SQL DMS  | - 172.17.0.0/16                      | reserved for the Docker bridge network            |
| Docker         | - 172.17.0.0/16<br>- 172.18.0.0/16   | reserved for the Docker bridge network            |
| Cloud Composer | - 172.17.0.0/16                      | The 172.17.0.0/16 range is reserved in Cloud SQL. |

# Services that **DO** support Private Service Connections
You can access the following services by using Private Service Connect.
https://cloud.google.com/vpc/docs/private-service-connect-compatibility#google-services
- **Apigee** --> https://cloud.google.com/apigee/docs/api-platform/get-started/networking-options
- **Cloud SQL (Postgres)**--> https://cloud.google.com/sql/docs/postgres/about-private-service-connect
- **Cloud SQL (MySql)**--> https://cloud.google.com/sql/docs/mysql/about-private-service-connect
- **Cloud Composer V2** --> https://cloud.google.com/composer/docs/composer-2/configure-private-service-connect
- **Memorystore Redis Cluster** --> https://cloud.google.com/memorystore/docs/cluster/networking


# Services that **DO NOT** support Private Service Connections
- **Cloud SQL (SQL Server)** --> https://cloud.google.com/sql/docs/sqlserver/configure-private-services-access
- **Alloy DB** --> https://cloud.google.com/alloydb/docs/configure-connectivity
- **Cloud Composer V1**
- **Memorystore Redis** --> https://cloud.google.com/memorystore/docs/redis/establish-connection
- **Memorystore Memcached** --> https://cloud.google.com/memorystore/docs/memcached/establish-connection
- **Cloud Build** --> https://cloud.google.com/build/docs/private-pools/use-in-private-network#peered-vpc
- **Vertex AI** --> https://cloud.google.com/vertex-ai/docs/general/vpc-peering
- **Filestore** --> https://cloud.google.com/filestore/docs/network-ip-requirements