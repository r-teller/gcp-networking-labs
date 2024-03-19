
output "gcr_chisel" {
  value = google_cloud_run_v2_service.gcr_chisel["us-central1"].uri
}

output "gsql_demo" {
  value = google_sql_database_instance.gsql_postgres["us-central1"].ip_address.0.ip_address 
}