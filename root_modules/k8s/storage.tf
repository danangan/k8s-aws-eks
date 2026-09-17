# Explicit gp3 storage class for dynamically-provisioned EBS volumes (the
# observability stack's Prometheus/Grafana/Loki/Tempo PVCs). Not marked as
# the cluster default to avoid conflicting with whatever default storage
# class the cluster/AMI may already provide - callers set storageClassName
# explicitly instead. Provisioned by the aws-ebs-csi-driver addon, which is
# set up in root_modules/infra.
resource "kubernetes_storage_class_v1" "gp3" {
  metadata {
    name = "gp3"
  }

  storage_provisioner = "ebs.csi.aws.com"
  reclaim_policy      = "Delete"
  volume_binding_mode = "WaitForFirstConsumer"

  parameters = {
    type      = "gp3"
    encrypted = "true"
  }
}
