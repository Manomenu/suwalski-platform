# suwalski-platform

A single-node **k3s cluster on Proxmox**, and everything that runs on it — all of it defined
in Terraform and in git. Point it at your Proxmox host, run two commands, and a few minutes
later you have a working Kubernetes cluster that deploys applications by itself.

Built for a homelab: small enough to understand end to end, close enough to how it is done
in the cloud that the habits transfer.

## Two layers

The repo is split in two, because the two halves change at completely different speeds. The
cluster is built once and then largely left alone; what runs on it changes every time an
application is released.

| Layer | Directory | What it is |
| --- | --- | --- |
| **cluster** | `terraform/cluster/` | The machine. A Debian VM on Proxmox with k3s on it. |
| **platform** | `terraform/platform/` | What lives inside the cluster. Argo CD, and through it every application. |

Nothing is clicked in the Proxmox UI, and nothing is deployed by running `kubectl apply` by
hand. If you change either by hand, the next `apply` puts it back.

## What you get

- A Debian VM, created from a cloud image that Proxmox downloads itself — no ISO to fetch,
  no installer to click through.
- k3s installed on first boot by cloud-init, at a **pinned version**.
- Traefik, CoreDNS, metrics-server and a local storage class, all of which k3s brings along.
- **Argo CD**, which watches this repo and makes the cluster match it — see below.
- A kubeconfig ready to use from your laptop, and scripts for the everyday bits.

## Requirements

| You need | Why |
| --- | --- |
| A Proxmox host | Reachable over the network. Tested on Proxmox VE 9 |
| An API token | Terraform talks to Proxmox with it. One command to create — see below |
| SSH access to the host as `root` | Some operations go over SSH rather than the API |
| [OpenTofu](https://opentofu.org/) or Terraform | `tofu` in the examples; the `.tf` files are the same either way |
| [kubectl](https://kubernetes.io/docs/reference/kubectl/) | Talking to the cluster once it is up |
| [k9s](https://k9scli.io/) *(optional)* | A much nicer way to look around than typing commands |

The repo installs none of these — it describes the cluster, not your workstation.

## Quick start

**1. Create an API token on the Proxmox host.** It is printed once, so copy it somewhere
safe right away.

```sh
ssh root@your-proxmox 'pveum user token add root@pam terraform --privsep 0'
```

**2. Fill in your secrets.** One interactive script asks for each one and writes it
everywhere it is needed:

```sh
./scripts/setup.sh
```

Run it as often as you like — it is idempotent, and pressing Enter keeps whatever you
gave it last time. Secrets live in `.secrets.env` at the root, outside git; the copies it
generates are never edited by hand.

**3. Describe your environment.** This part is *not* secret and is committed on purpose —
it is a description of where things stand, not a personal setting:

```sh
$EDITOR terraform/cluster/proxmox.auto.tfvars   # node name, storage, IP address
```

**4. Build the cluster, then the platform.**

```sh
(cd terraform/cluster && tofu init)     # download providers, once
./scripts/cluster/tofu-plan.sh          # see what it intends to do — changes nothing
./scripts/cluster/tofu-apply.sh         # do it (asks before touching anything)

source ./scripts/cluster/kubectl-setup.sh   # fetch the kubeconfig, point kubectl at it

(cd terraform/platform && tofu init)
./scripts/platform/tofu-apply.sh        # Argo CD, and everything it pulls in
```

The first run takes a few minutes: Proxmox downloads the image, the VM boots, and
cloud-init installs k3s in the background. Each `apply` finishes by printing what to do
next, so you do not have to remember any of this.

## Check that it worked

```sh
kubectl get nodes
```

```
NAME    STATUS   ROLES           VERSION
k3s-1   Ready    control-plane   v1.36.4+k3s1
```

If the node has not appeared yet, cloud-init is probably still working. It leaves a marker
behind when it finishes:

```sh
ssh you@your-vm 'ls /var/lib/cloud/k3s-ready'
```

Argo CD then answers at the address in `terraform/platform/platform.auto.tfvars`
(`argocd.k8s.suwalski.internal` here). The initial admin password is stored in the cluster;
`./scripts/platform/argocd-password.sh` decodes it for you.

## How a deploy happens

No one pushes to this cluster. Argo CD sits inside it, watches git, and pulls — so the
answer to "what is running?" is always "whatever git says", and you find out by reading a
file rather than by interrogating the cluster.

[`argocd/apps/`](argocd/apps) holds one file per application. Each names the repo that has
the application's Helm chart, and pins the exact image tag to run:

```yaml
helm:
  parameters:
    - name: image.tag
      value: sha-1c52a77     # ← this one line is the deployment
```

Changing that line and committing *is* the release. The git history of that file is the
deployment history — who deployed what, when, and what to roll back to.

![Argo CD's view of a deployed application: an Ingress, two Services, two Deployments, four ReplicaSets, two running Pods and a cache volume, all marked Healthy and Synced](docs/images/argocd-application-tree.png)

That is Argo CD's own view of one application after a sync. It knows every object it
created and how each one is doing, which is why the failure question is answerable at a
glance. Two ReplicaSets per Deployment is normal and not a leak: the previous one is kept
at zero replicas so that a rollback takes seconds instead of a rebuild.

The split of responsibility is deliberate. The application repo publishes images and
describes the *shape* of a deployment (its chart); this repo decides *which version* runs.

## Everyday commands

| Command | What it does |
| --- | --- |
| `./scripts/setup.sh` | Ask for the secrets and distribute them. Safe to re-run |
| `./scripts/cluster/tofu-plan.sh` | Show what would change on Proxmox |
| `./scripts/cluster/tofu-apply.sh` | Apply it. Extra arguments go straight to `tofu`, so `-auto-approve` skips the prompt |
| `./scripts/cluster/tofu-validate.sh` | Format and check the files — offline, quick |
| `source ./scripts/cluster/kubectl-setup.sh` | Fetch the kubeconfig, point `kubectl` at it, make it stick |
| `./scripts/platform/tofu-plan.sh` | The same three, for what runs *inside* the cluster |
| `./scripts/platform/tofu-apply.sh` | |
| `./scripts/platform/tofu-validate.sh` | |
| `./scripts/platform/argocd-password.sh` | Argo CD's initial admin password, decoded |
| `./scripts/k9s/logs.sh` | k9s's own log — the only place it explains itself |

Looking *at* the cluster is k9s's job, not a script's: `:po`, `:ing`, `:applications`.

## Making it yours

Most of what you will want to change lives in `terraform/cluster/proxmox.auto.tfvars` — the
node name, which storage to use, the IP address, the VM id. Sizing (memory, cores, disk) and
the k3s version have sensible defaults in `terraform/cluster/variables.tf`; override them in
the same `.auto.tfvars` file if you disagree. The cluster's own settings — the Argo CD
hostname, chiefly — are in `terraform/platform/platform.auto.tfvars`.

To deploy an application of your own, drop a file into `argocd/apps/` next to the one that
is there. Argo CD picks it up on its own.

## Digging deeper

- [`argocd/README.md`](argocd/README.md) — how the application definitions are organised.
- [`AGENTS.md`](AGENTS.md) — conventions: where values belong, when to extract a module,
  how the files are split.
- [`docs/multiple_env.md`](docs/multiple_env.md) — what to do when a second environment
  appears, and why a directory beats a workspace.
- [`docs/cheatsheet.md`](docs/cheatsheet.md) — every command this repo uses, in one
  place: tofu, kubectl, k9s, Proxmox.
- [`TODO.md`](TODO.md) — ideas parked for later, with the reasoning behind them.

Those are written in Polish; the code and this page are not.

## Related

Applications live separately, in
[`suwalski-investing-tools`](https://github.com/Manomenu/suwalski-investing-tools). That
repo publishes container images and carries the Helm chart; this one decides what runs.

## License

MIT — see [`LICENSE`](LICENSE). Do what you like with it.

Nothing third-party is redistributed here: this repo is configuration, and the providers,
charts and images it names are downloaded at run time under their own licences.
