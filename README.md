# suwalski-platform

A single-node **k3s cluster on Proxmox**, defined entirely in Terraform. Point it at your
Proxmox host, run one command, and a few minutes later you have a working Kubernetes
cluster you can deploy to — and delete and recreate without ceremony.

Built for a homelab: small enough to understand end to end, close enough to how it is done
in the cloud that the habits transfer.

## What you get

- A Debian VM, created from a cloud image that Proxmox downloads itself — no ISO to fetch,
  no installer to click through.
- k3s installed on first boot by cloud-init, at a **pinned version**.
- Traefik, CoreDNS, metrics-server and a local storage class, all of which k3s brings along.
- A kubeconfig ready to use from your laptop, and scripts for the everyday bits.

Nothing is clicked in the Proxmox UI. If you change something there by hand, the next
`apply` will put it back.

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

**2. Tell Terraform about your setup.** Two files, split by whether the contents are
secret:

```sh
cd terraform
cp secrets.auto.tfvars.example secrets.auto.tfvars   # API token + your SSH public key
$EDITOR proxmox.auto.tfvars                          # node name, storage, IP address
```

`proxmox.auto.tfvars` is committed on purpose — it is a description of the environment,
not a personal setting. `secrets.auto.tfvars` is not, and never should be.

**3. Build it.**

```sh
tofu init      # download the provider
tofu plan      # see what it intends to do — changes nothing
tofu apply     # do it (asks before touching anything)
```

The first run takes a few minutes: Proxmox downloads the image, the VM boots, and
cloud-init installs k3s in the background.

## Check that it worked

```sh
./scripts/kubeconfig.sh                 # fetch the kubeconfig and test it
source ./scripts/kubectl/setup.sh       # point kubectl at this cluster
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

## Everyday commands

| Command | What it does |
| --- | --- |
| `./scripts/tofu/plan.sh` | Show what would change |
| `./scripts/tofu/apply.sh` | Apply it. `--yes-man` skips the confirmation |
| `./scripts/tofu/validate-and-format.sh` | Format and check the files — offline, quick |
| `./scripts/kubeconfig.sh` | Fetch the kubeconfig and verify it works |
| `./scripts/kubectl/setup.sh` | Set `KUBECONFIG`, for now and for good |
| `./scripts/kubectl/list-nodes.sh` | Nodes and how busy they are |

## Making it yours

Most of what you will want to change lives in `terraform/proxmox.auto.tfvars` — the node
name, which storage to use, the IP address, the VM id. Sizing (memory, cores, disk) and
the k3s version have sensible defaults in `terraform/variables.tf`; override them in the
same file if you disagree.

## Digging deeper

- [`AGENTS.md`](AGENTS.md) — conventions: where values belong, when to extract a module,
  how the files are split.
- [`docs/multiple_env.md`](docs/multiple_env.md) — what to do when a second environment
  appears, and why a directory beats a workspace.

Both are written in Polish; the code and this page are not.

## Related

Applications live separately, in
[`suwalski-investing-tools`](https://github.com/Manomenu/suwalski-investing-tools). That
repo publishes container images; this one decides what runs.

## License

MIT — see [`LICENSE`](LICENSE).
