<div align="center">

# Host Your CV on AWS

### 23L-3065 · Jabeen Zahra

[![AWS](https://img.shields.io/badge/AWS-232F3E?style=for-the-badge&logo=amazonwebservices&logoColor=FF9900)](https://aws.amazon.com)
[![EC2](https://img.shields.io/badge/Amazon_EC2-FF9900?style=for-the-badge&logo=amazonec2&logoColor=white)](https://aws.amazon.com/ec2/)
[![Lambda](https://img.shields.io/badge/AWS_Lambda-FF9900?style=for-the-badge&logo=awslambda&logoColor=white)](https://aws.amazon.com/lambda/)
[![S3](https://img.shields.io/badge/Amazon_S3-569A31?style=for-the-badge&logo=amazons3&logoColor=white)](https://aws.amazon.com/s3/)
[![IAM](https://img.shields.io/badge/IAM-DD344C?style=for-the-badge&logo=amazoniam&logoColor=white)](https://aws.amazon.com/iam/)

[![Status](https://img.shields.io/badge/Status-Live-success?style=flat-square)]()
[![Region](https://img.shields.io/badge/Region-ap--southeast--2-blue?style=flat-square)]()
[![Python](https://img.shields.io/badge/Python-3.13-3776AB?style=flat-square&logo=python&logoColor=white)]()
[![License](https://img.shields.io/badge/Course-Cloud_Computing-informational?style=flat-square)]()

BS Software Engineering · FAST NUCES Lahore

</div>

A CV served two ways from one private S3 bucket — once by an **EC2** web server, once by a **Lambda** function — with IAM roles doing all the authorization work.

---

## Live Endpoints

<div align="center">

[![EC2 Endpoint](https://img.shields.io/badge/EC2_Site-Open_Live-FF9900?style=for-the-badge&logo=amazonec2&logoColor=white)](http://3.26.62.242/)
[![Lambda Endpoint](https://img.shields.io/badge/Lambda_Site-Open_Live-FF9900?style=for-the-badge&logo=awslambda&logoColor=white)](https://xl3poul5yjinuk2bhlyq77s3au0kmkdm.lambda-url.ap-southeast-2.on.aws/)

</div>

| Path | URL |
|---|---|
| **EC2** | http://3.26.62.242/ |
| **Lambda** | https://xl3poul5yjinuk2bhlyq77s3au0kmkdm.lambda-url.ap-southeast-2.on.aws/ |

---

## Architecture

<img src="https://img.shields.io/badge/-System_Design-6366F1?style=flat-square" alt="System Design"/>

```mermaid
flowchart TB
    S3[("S3 Bucket (private)<br/>cv-23l-3065/site/<br/>index.html · style.css · cv.pdf")]

    EC2["EC2 Instance<br/>cv-ec2-23l-3065<br/>IAM Role attached<br/>Apache httpd<br/>synced every 5 min"]
    Lambda["Lambda Function<br/>cv-func-23l-3065<br/>IAM Role attached<br/>Python 3.13<br/>reads S3 per request"]

    BrowserA(["Browser"])
    BrowserB(["Browser"])

    S3 -- "GetObject + ListBucket<br/>(prefix: site/)" --> EC2
    S3 -- "GetObject only<br/>(no ListBucket)" --> Lambda

    EC2 -- "Public IP · HTTP" --> BrowserA
    Lambda -- "Public Function URL · HTTPS" --> BrowserB
```

**EC2 path:** A browser request hits the instance's public IP on port 80. Apache serves static files that a systemd timer syncs from the private S3 bucket every 5 minutes, using the EC2 IAM role.

**Lambda path:** A browser request hits the public Function URL, invoking the function. The function reads the requested object straight from S3 on every call, using the Lambda IAM role, and returns it with the correct content type.

---

## Evidence

<img src="https://img.shields.io/badge/-Verified_Proofs-22C55E?style=flat-square" alt="Verified Proofs"/>

<details>
<summary><strong>Access Denied Proof (Section 4)</strong></summary>

Attempted from inside the EC2 instance via SSH, using the attached IAM role — not the admin user. The role only grants `s3:GetObject` and `s3:ListBucket` (with a `site/` prefix condition), so a delete attempt is rejected.

![Access denied proof](screenshots/access-denied.png)

</details>

<details>
<summary><strong>/var/log/cv-sync.log — last 10 lines</strong></summary>

The systemd timer fires every 5 minutes and every run has succeeded.

![Sync log](screenshots/sync-log.png)

</details>

<details>
<summary><strong>EC2 site loading</strong></summary>

![EC2 site](screenshots/ec2-site.png)

</details>

<details>
<summary><strong>Lambda site loading</strong></summary>

![Lambda site](screenshots/lambda-site.png)

</details>

<details>
<summary><strong>Direct S3 access denied</strong></summary>

![S3 direct access denied](screenshots/s3-direct-denied.png)

</details>

<details>
<summary><strong>IAM roles</strong></summary>

![IAM roles](screenshots/iam-roles.png)

</details>

---

## Written Answers

<img src="https://img.shields.io/badge/-Q%26A-F59E0B?style=flat-square" alt="Q and A"/>

<table>
<tr><td>

**1. Why roles instead of access keys? What could go wrong with keys in user data?**

Roles hand out short-lived, auto-rotated credentials scoped exactly to the attached policy, with no secret ever stored anywhere. If long-lived access keys were placed in the user data instead, anyone with read access to the instance metadata, the EC2 console, or a copy of the script could extract and reuse those keys indefinitely — even after the instance is gone. They could also leak into logs, AMIs, or snapshots. Roles remove the secret entirely, so there's nothing to steal.

</td></tr>
<tr><td>

**2. Someone pastes the S3 address of index.html into a browser. What do they see, and which setting causes that?**

They see an Access Denied (403) error instead of the page. This is caused by the bucket's four Block Public Access settings being enabled, combined with having no bucket policy or ACL that grants public read — so only the two IAM roles can ever read the objects.

</td></tr>
<tr><td>

**3. Explain the function URL permission that lets anyone call it. Why is that acceptable for the function but not for the bucket?**

The function carries a resource-based policy allowing principal `*` to invoke it via `lambda:InvokeFunctionUrl` / `lambda:InvokeFunction`, scoped to this one function only. This is safe because the function can only ever return the three static files it already has read access to — no write, no delete, no raw storage exposure. Making the S3 bucket itself public would hand out unrestricted storage access with no logic controlling what's read, written, or deleted, and no per-request logging.

</td></tr>
<tr><td>

**4. Compare the two paths. What do you pay for when nobody visits? What happens at 100x traffic?**

EC2 bills for the running t3.micro every hour regardless of traffic. Lambda bills only per invocation and per millisecond of execution, so zero traffic costs next to nothing. At 100x traffic, the single EC2 instance would need manual resizing or a load balancer with auto scaling, while Lambda scales automatically with no intervention required, up to account concurrency limits.

</td></tr>
<tr><td>

**5. You delete the EC2 instance. What do you lose and what do you still have?**

You lose the running web server and its public IP — the EC2 path goes down entirely. You keep the S3 bucket and all three files, the Lambda function and its URL, both IAM roles, and the security group. The Lambda path is completely unaffected, and a new EC2 instance could be relaunched from the same role, security group, and user-data script to restore the EC2 path.

</td></tr>
</table>

---

## Repository Layout

<img src="https://img.shields.io/badge/-File_Structure-64748B?style=flat-square" alt="File Structure"/>

```
README.md
collect-evidence.sh
evidence.txt
site/            index.html, style.css, cv.pdf
ec2/             user-data.sh, sync-cv.sh
lambda/          lambda_function.py
iam/             ec2-trust-policy.json, ec2-permission-policy.json,
                 lambda-trust-policy.json, lambda-permission-policy.json
screenshots/     access-denied.png, sync-log.png, ec2-site.png,
                 lambda-site.png, s3-direct-denied.png, iam-roles.png
```

Region used throughout: `ap-southeast-2` (Sydney)