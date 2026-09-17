# Grafana observability stack: Prometheus (metrics), Loki (logs), Tempo
# (traces), all pinned to the tainted "observability" node group (created in
# root_modules/infra) and backed by the gp3 storage class in storage.tf.

locals {
  observability_node_selector = {
    role = "observability"
  }

  observability_toleration = {
    key      = "observability-workload"
    operator = "Equal"
    value    = "true"
    effect   = "NoSchedule"
  }

  gpu_toleration = {
    key      = "gpu-workload"
    operator = "Equal"
    value    = "true"
    effect   = "NoSchedule"
  }
}

resource "kubernetes_namespace_v1" "observability" {
  metadata {
    name = "observability"
  }
}

# Prometheus + Grafana + Alertmanager
resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "91.4.1"
  namespace  = kubernetes_namespace_v1.observability.metadata[0].name

  values = [
    yamlencode({
      alertmanager = {
        alertmanagerSpec = {
          nodeSelector = local.observability_node_selector
          tolerations  = [local.observability_toleration]
          storage = {
            volumeClaimTemplate = {
              spec = {
                storageClassName = kubernetes_storage_class_v1.gp3.metadata[0].name
                accessModes      = ["ReadWriteOnce"]
                resources = {
                  requests = {
                    storage = "5Gi"
                  }
                }
              }
            }
          }
        }
      }

      grafana = {
        nodeSelector = local.observability_node_selector
        tolerations  = [local.observability_toleration]
        persistence = {
          enabled          = true
          storageClassName = kubernetes_storage_class_v1.gp3.metadata[0].name
          size             = "5Gi"
        }
        # Loki/Tempo are deployed below into the same namespace, so a
        # same-namespace ClusterIP DNS name reaches them directly.
        additionalDataSources = [
          {
            name   = "Loki"
            type   = "loki"
            access = "proxy"
            url    = "http://loki.${kubernetes_namespace_v1.observability.metadata[0].name}.svc.cluster.local:3100"
          },
          {
            name   = "Tempo"
            type   = "tempo"
            access = "proxy"
            url    = "http://tempo.${kubernetes_namespace_v1.observability.metadata[0].name}.svc.cluster.local:3200"
          }
        ]
      }

      prometheus = {
        prometheusSpec = {
          nodeSelector = local.observability_node_selector
          tolerations  = [local.observability_toleration]
          storageSpec = {
            volumeClaimTemplate = {
              spec = {
                storageClassName = kubernetes_storage_class_v1.gp3.metadata[0].name
                accessModes      = ["ReadWriteOnce"]
                resources = {
                  requests = {
                    storage = "20Gi"
                  }
                }
              }
            }
          }
        }
      }

      # DaemonSet - tolerate both taints so it still scrapes host metrics
      # from the GPU and observability nodes, not just the default group.
      "prometheus-node-exporter" = {
        tolerations = [
          local.observability_toleration,
          local.gpu_toleration,
        ]
      }
    })
  ]

  depends_on = [kubernetes_storage_class_v1.gp3]
}

# Logs
resource "helm_release" "loki" {
  name       = "loki"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki"
  version    = "7.3.0"
  namespace  = kubernetes_namespace_v1.observability.metadata[0].name

  values = [
    yamlencode({
      deploymentMode = "SingleBinary"

      loki = {
        auth_enabled = false
        commonConfig = {
          replication_factor = 1
        }
        storage = {
          type = "filesystem"
        }
        schemaConfig = {
          configs = [
            {
              from         = "2024-01-01"
              store        = "tsdb"
              object_store = "filesystem"
              schema       = "v13"
              index = {
                prefix = "index_"
                period = "24h"
              }
            }
          ]
        }
      }

      singleBinary = {
        replicas = 1
        persistence = {
          enabled      = true
          size         = "10Gi"
          storageClass = kubernetes_storage_class_v1.gp3.metadata[0].name
        }
        nodeSelector = local.observability_node_selector
        tolerations  = [local.observability_toleration]
      }

      # Only the single-binary deployment above is used - disable the
      # simple-scalable-mode components this chart defaults to.
      write   = { replicas = 0 }
      read    = { replicas = 0 }
      backend = { replicas = 0 }
      gateway = { enabled = false }

      # Extras not needed for a demo: memcached-backed caches and the
      # synthetic-traffic canary.
      resultsCache = { enabled = false }
      chunksCache  = { enabled = false }
      test         = { enabled = false }
      lokiCanary   = { enabled = false }
    })
  ]

  depends_on = [kubernetes_storage_class_v1.gp3]
}

# Traces
resource "helm_release" "tempo" {
  name       = "tempo"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "tempo"
  version    = "1.24.4"
  namespace  = kubernetes_namespace_v1.observability.metadata[0].name

  values = [
    yamlencode({
      persistence = {
        enabled          = true
        size             = "10Gi"
        storageClassName = kubernetes_storage_class_v1.gp3.metadata[0].name
      }
      nodeSelector = local.observability_node_selector
      tolerations  = [local.observability_toleration]
    })
  ]

  depends_on = [kubernetes_storage_class_v1.gp3]
}
