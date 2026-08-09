---
title: Our Kubernetes Cluster Has No Nodes. It Runs on Lambda and We’ve Never Saved More Money.
subtitle: The biggest cost in your Kubernetes cluster isn’t the pods.
tags:
- AWS
- DevOps
- Software Engineering
- Programming
- Technology
published: '2026-01-30'
updated: '2026-02-09'
free: false
freedium_url: https://freedium-mirror.cfd/https://aws.plainenglish.io/our-kubernetes-cluster-has-no-nodes-it-runs-on-lambda-and-weve-never-saved-more-money-614986c398ec
source_url: https://aws.plainenglish.io/our-kubernetes-cluster-has-no-nodes-it-runs-on-lambda-and-weve-never-saved-more-money-614986c398ec
---

# Our Kubernetes Cluster Has No Nodes. It Runs on Lambda and We’ve Never Saved More Money.

*The biggest cost in your Kubernetes cluster isn’t the pods.*

*Published Jan 30, 2026 · Updated Feb 09, 2026 · Free: No*

It's the **nodes sitting idle**, waiting for something → anything → to run.

Even with Spot Instances.
Even with Cluster Autoscaler.

You're still paying for **empty vCPUs 60% of the time**.

So we asked a question that Kubernetes orthodoxy treats as heresy:

> _What if we paid for compute __**only while a pod is actually executing**__?_

Then we did something unthinkable.

We deleted our node pools.

All of them.

And rebuilt our "Kubernetes cluster" on top of **AWS Lambda**, where every pod is an **ephemeral Lambda execution**.

No always-on nodes.
No idle capacity.
No wasted cores.

A deployment with 100 pods now costs **$0 until traffic arrives**.
When it does, it scales from **0 → 10,000 executions in under 10 seconds**.

94% of our bill is now **pure application logic**.

And our developers have no idea they're not using "real" Kubernetes.

This is **Virtual Kubelet + Lambda-backed pods** → and it's the most radical shift in cloud economics since serverless was invented.

### The architecture: the illusion of a cluster

We still run a real Kubernetes control plane (EKS).

But instead of worker nodes, we register a **Virtual Kubelet backed by AWS Lambda**.

Here's what happens when a developer runs:

```typescript
kubectl apply -f deployment.yaml
```

### 1. No nodes to schedule on

The Kubernetes scheduler sees a registered **virtual node**.

It schedules pods there → just like any other node.

Except… there's no machine behind it.

<picture>
  <source media="(max-width: 768px)" srcset="/img/medium/700/0*wAg1AWJGjs94Ehvh 1x">
  <source media="(min-width: 769px)" srcset="/img/medium/2000/0*wAg1AWJGjs94Ehvh 1x">
  <img src="/img/medium/700/0*wAg1AWJGjs94Ehvh" alt="None" width="5760" height="3240" loading="lazy" data-zoom-src="/img/medium/4000/0*wAg1AWJGjs94Ehvh" class="prose-image" data-caption="Photo by [Sufyan](https://unsplash.com/@blenderdesigner?utm_source=medium&amp;utm_medium=referral) on [Unsplash](https://unsplash.com?utm_source=medium&amp;utm_medium=referral)"/>
</picture>

### 2. Pod spec → Lambda blueprint

The Virtual Kubelet translates the Pod definition into a Lambda configuration:

- `container.image` → Lambda container image
- `resources.requests.cpu` → Lambda memory size
 (CPU scales automatically with memory)
- `livenessProbe` → Lambda Function URL health check

From Kubernetes' point of view, it's a pod lifecycle.

From AWS' point of view, it's serverless execution.

### 3. Cold start replaces node boot

When the first request hits that "pod":

- Lambda cold-starts the container
- Execution begins immediately

We keep **1–2 warm executions per deployment** using provisioned concurrency.

Effective cold start: **~200ms**
That's faster than an Auto Scaling Group could even _begin_ launching a node.

### The cost math that breaks your brain

### Before: traditional EKS

- 50 × `c6g.large` nodes
- Idle most of the day
- ~$1,900/month just to exist
- ~$800 for actual runtime

**Total:** ~$2,700/month

### After: Lambda-backed pods

- Idle cost: **$0**
- Pay only for execution time

Same workload, same traffic pattern:

**$162/month**

No tuning.
No rightsizing.
No overthinking.

Just… no nodes.

### "But that can't work because…" (we tried all of this)

### "Pods need to talk to each other"

They do.

Each Lambda execution runs **inside our VPC** using **App Runner VPC connectors**.

They get:

- Private IPs
- Security groups
- Full east-west connectivity

We even run **Linkerd** inside the Lambda container image as a sidecar.

Yes. Really.

### "What about StatefulSets and DaemonSets?"

We don't run stateful workloads here.

This pattern is for:

- Frontends
- APIs
- Stateless workers

Stateful systems stay on a **small, boring, 5-node traditional cluster**.

Right tool, right place.

### "Monitoring must be totally different"

Not really.

Lambda metrics flow into CloudWatch.
We scrape them into **Amazon Managed Prometheus**.

From Grafana's perspective, nothing changed.

### The developer experience: perfect deception

Developers see:

- `kubectl get pods` → Running
- `kubectl logs` → Works
- `kubectl exec` → Works
- `kubectl port-forward` → Works
 (via a small bridge service that proxies to the Lambda Function URL)

As far as they're concerned, this is just Kubernetes.

The Virtual Kubelet makes Lambda executions look **exactly like pod lifecycles**.

The illusion is complete.

### The killer feature: per-pod micro-scaling

This is where it becomes unfair.

HPA scales **deployments**.

Lambda-pods scale **individually**.

If:

- `/api/users` explodes in traffic
- `/api/reports` stays quiet

Then:

- Pod-1 scales to **1,000 concurrent executions**
- Pod-2 sits calmly at **2 executions**

Perfect utilization.
No wasted replicas.
No averaging effects.

This was impossible with nodes.

### Pilot this in under 2 hours

Install Virtual Kubelet:

```bash
helm install vk aws/virtual-kubelet --set provider=aws
```

Taint real nodes so test workloads go virtual:

```rust
nodeSelector:
  type: virtual-kubelet
```

Deploy a simple nginx workload with that selector.

Curl the generated Lambda URL.

You'll see:

- No nodes running it
- Pods appear as **Running** in `kubectl`
- Execution happens on demand

It feels illegal.

### The 2025 reality

The most advanced Kubernetes clusters aren't measured by **node count**.

They're measured by the **absence of nodes**.

By decoupling Kubernetes' scheduling model from physical machines, we unlocked the only pricing model that actually matches business value:

> **_Pay only when users are being served._**

The future of Kubernetes is serverless.

And it's already here →
quietly hiding behind a perfectly engineered illusion.

!! Thank you for your precious time !!