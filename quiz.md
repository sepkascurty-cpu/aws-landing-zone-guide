# Quiz — AWS Landing Zone

Five questions. Answers are collapsed — no peeking until you've committed to an answer. 🟩

---

### 1. Why is a single AWS account a bad home for dev, staging, AND prod?

<details>
<summary>Answer</summary>

One shared **blast radius**: a bad deploy, a compromised key, or a runaway script in dev
can take down prod. You also lose clean cost attribution ("which environment spent this?"),
and security baselines become tribal knowledge instead of enforced policy. Separate
accounts per environment isolate failures, bills, and access.
</details>

---

### 2. What is a Service Control Policy (SCP), and what CAN'T it do?

<details>
<summary>Answer</summary>

An SCP is a **permission ceiling** attached to an OU or account: it defines the maximum
permissions identities inside can use. What it **can't** do is *grant* access — an action
must be allowed by the identity/resource policy AND not denied by any SCP. SCPs also
don't apply to the management account itself, and they don't affect service-linked roles
the way you'd expect — always test in the Sandbox OU first.
</details>

---

### 3. Name the three Control Tower guardrail flavors and give one example of each.

<details>
<summary>Answer</summary>

- **Preventive** (SCP-based, blocks before it happens) — e.g. deny disabling CloudTrail.
- **Detective** (Config rule, flags drift) — e.g. alert when an S3 bucket becomes public.
- **Proactive** (deploy-time check via CloudFormation hooks) — e.g. block a stack that
  creates an unencrypted RDS instance. Preventive is strongest; use it for non-negotiables.
</details>

---

### 4. Which account should hold the organization-wide CloudTrail logs, and why not the workload account?

<details>
<summary>Answer</summary>

The dedicated **Log Archive** account inside the Security OU. Logs must live where the
workload teams can't modify or delete them — a compromised app account shouldn't be able
to erase its own audit trail. The Log Archive account gets an SCP denying all writes
except log delivery, plus S3 Object Lock for immutability.
</details>

---

### 5. Your new SCP accidentally denies `ec2:*` in the Workloads OU and prod goes dark. What's the recovery path, and what should you have done differently?

<details>
<summary>Answer</summary>

**Recovery:** SCPs don't apply to the **management account**, so sign in there (or use the
documented break-glass path) and detach/fix the policy — the deny stops applying
immediately. **Prevention:** test every new SCP in the **Sandbox OU** first, start with
narrow deny rules instead of broad ones, and keep a tested break-glass admin path outside
SCP scope. Broad `Deny` + `*` is how you learn this lesson the exciting way.
</details>
