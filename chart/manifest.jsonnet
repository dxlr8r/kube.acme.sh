# SPDX-FileCopyrightText: 2023 Simen Strange <https://github.com/dxlr8r/kube.acme.sh>
# SPDX-License-Identifier: MIT

function(config, lib, mod)
local dx = lib.dx;
local constant = {
  runAsUser: 1000,
  runAsGroup: 1000,
  fsGroup: 1001
};
local manifest = 
{
  Namespace: {
    apiVersion: 'v1',
    kind: 'Namespace',
    metadata: {
      name: config.namespace
    }
  },
  ServiceAccount: {
      apiVersion: 'v1',
      kind: 'ServiceAccount',
      metadata: {
        name: config.name,
      }
  },
  ClusterRole: {
    apiVersion: 'rbac.authorization.k8s.io/v1',
    kind: 'ClusterRole',
    metadata: {
      name: config.name,
    },
    rules: [
      {
        apiGroups: [''],
        verbs: ['get','update'],
        resources: ['secrets'],
        resourceNames: [config.name],
      },
      {
        apiGroups: [''],
        verbs: ['list','create'],
        resources: ['secrets'],
      }
    ],
  },
  ClusterRoleBinding: {
    kind: 'ClusterRoleBinding',
    apiVersion: 'rbac.authorization.k8s.io/v1',
    metadata: {
      name: config.name,
    },
    subjects: [
      {
        kind: 'ServiceAccount',
        name: config.name,
        namespace: config.namespace,
      },
    ],
    roleRef: {
      apiGroup: 'rbac.authorization.k8s.io',
      kind: 'ClusterRole',
      name: config.name,
    },
  },
  PersistentVolumeClaim: {
    apiVersion: 'v1',
    kind: 'PersistentVolumeClaim',
    metadata: {
      name: config.name,
    },
    spec: {
      resources: {
        requests: {
          storage: '10Mi',
        },
      },
      accessModes: [
        'ReadWriteOnce',
      ]
    }
  },
  ConfigMap: {
      apiVersion: 'v1',
      kind: 'ConfigMap',
      metadata: {
        name: config.name,
      },
      data: {
        'entrypoint.sh': importstr 'data/kube.acme.sh'
      }
  },
  Secret: {
      apiVersion: 'v1',
      kind: 'Secret',
      metadata: {
        name: config.name,
      },
      data: {
        acme_env: std.base64(std.manifestJsonMinified(config.acme_sh.env))
      }
  },
  CronJob: {
    apiVersion: 'batch/v1',
    kind: 'CronJob',
    metadata: {
      name: config.name,
    },
    spec: {
      schedule: '%(mm)02d %(hh)02d * * *' % { mm: lib.rand(config, 60), hh: lib.rand(config, 24) },
      concurrencyPolicy: 'Forbid',
      jobTemplate: {
        metadata: {
          name: config.name,
        },
        spec: {
          template: {
            metadata: {
            },
            spec: {
              serviceAccountName: config.name,
              automountServiceAccountToken: true,
              securityContext: {
                runAsUser: constant.runAsUser,
                runAsGroup: constant.runAsGroup,
                fsGroup: constant.fsGroup
              },
              initContainers: [
                {
                  name: 'init',
                  securityContext: {
                    runAsUser: 0
                  },
                  image: 'neilpang/acme.sh',
                  command: ['/bin/sh'],
                  args: ['-c', 'cp -r /root/.acme.sh /workdir; chown -R %d:%d /workdir/' % [constant.runAsUser, constant.runAsGroup]],
                  volumeMounts: [
                    {
                      name: 'workdir',
                      mountPath: '/workdir'
                    }
                  ]
                }
              ],
              containers: [
                {
                  name: config.name,
                  securityContext: {
                    allowPrivilegeEscalation: false
                  },
                  image: 'neilpang/acme.sh',
                  command: ['/bin/sh', '/kube.acme.sh/entrypoint.sh'],
                  env: [
                    {
                      name: 'POD_LABELS',
                      value: std.manifestJsonMinified(config.labels)
                    },
                    { name: 'NAME', value: config.name },
                    { name: 'ACME_EMAIL', value: config.acme_sh.email },
                    { name: 'ACME_ARGS', value: config.acme_sh.args },
                    { name: 'ACME_ENV', valueFrom: { secretKeyRef:
                      {
                        name: config.name,
                        key: 'acme_env'
                      }}
                    },
                    { name: 'TARGETS', value: std.manifestJsonMinified(config.target_namespace) }
                  ],
                  volumeMounts: [
                    {
                      name: 'config',
                      mountPath: '/acme.sh',
                    },
                    {
                      name: 'entrypoint',
                      mountPath: '/kube.acme.sh'
                    },
                    {
                      name: 'workdir',
                      mountPath: '/workdir'
                    }
                  ]
                },
              ],
              volumes: [
                {
                  name: 'config',
                  persistentVolumeClaim: {
                    claimName: config.name
                  }
                },
                {
                  name: 'entrypoint',
                  configMap: {
                    name: config.name
                  }
                },
                {
                  name: 'workdir',
                  emptyDir: {}
                }
              ],
              restartPolicy: 'OnFailure'
            },
          }
        }
      }
    }
  }
};
dx.obj.forEach(function(f,v) {
   [f]: v + { metadata+: { labels+: config.labels }}
}, manifest) // apply labels to all resources
