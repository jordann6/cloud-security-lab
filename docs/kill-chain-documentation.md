# Cloud Security Lab: Kill Chain Documentation

## MITRE ATT&CK Mapped Attack Narrative

This document maps the full attack lifecycle executed against the cloud-security-lab AWS environment using Pacu (the AWS exploitation framework) and the AWS CLI. Each phase is mapped to the corresponding MITRE ATT&CK tactic and technique, with evidence captured from tool output.

---

## Attack Overview

| Field | Detail |
|-------|--------|
| Target Account | 692859913278 |
| Compromised Identity | cloud-security-lab-compromised-user |
| Access Key Used | AKIA2CUNLIQ7NRWN6VJL |
| Tools Used | Pacu v1.x, AWS CLI |
| Attack Duration | Single session |
| Outcome | Full administrative access, sensitive data exfiltration, lateral movement to pivot role |

---

## Phase 1: Initial Access

**MITRE ATT&CK Tactic:** Initial Access (TA0001)
**Technique:** Valid Accounts: Cloud Accounts (T1078.004)

**Narrative:**
The attacker obtained valid IAM credentials (access key and secret key) for the user `cloud-security-lab-compromised-user`. These credentials represent a realistic scenario where long lived IAM access keys have been leaked through a code repository, phishing attack, or insider threat.

**Evidence:**
- IAM User: `cloud-security-lab-compromised-user`
- Access Key ID: `AKIA2CUNLIQ7NRWN6VJL`
- Key Status: Active
- Key Created: 2026-04-11T08:34:10Z

---

## Phase 2: Discovery / Reconnaissance

**MITRE ATT&CK Tactic:** Discovery (TA0007)
**Techniques:**
- Cloud Infrastructure Discovery (T1580)
- Account Discovery: Cloud Account (T1087.004)
- Permission Groups Discovery: Cloud Groups (T1069.003)

**Narrative:**
Using Pacu, the attacker enumerated the compromised user's permissions and discovered the full IAM landscape of the account. Initial reconnaissance revealed 1,039 confirmed permissions under an overprivileged policy named `cloud-security-lab-overprivileged-policy`. A second enumeration pass discovered 2 IAM users, 27 roles, 3 policies, and 0 groups.

**Pacu Modules Executed:**
- `iam__enum_permissions`: Returned 1,039 confirmed permissions
- `iam__enum_users_roles_policies_groups`: Enumerated 2 users, 27 roles, 3 policies, 0 groups

**Key Findings:**
- The compromised user had broad access across IAM, S3, EC2, STS, CloudTrail, and CloudWatch Logs
- Critical IAM permissions included `iam:PutUserPolicy`, `iam:AttachUserPolicy`, `iam:UpdateRole`, `iam:CreateInstanceProfile`, and `iam:DetachUserPolicy`
- S3 permissions included `s3:ListBucket`, `s3:GetObjectAttributes`, `s3:ReplicateObject`, and `s3:ReplicateDelete`
- EC2 permissions included `ec2:RunInstances`, `ec2:CreateKeyPair`, and `ec2:AuthorizeSecurityGroupIngress`
- A pivot role (`cloud-security-lab-pivot-role`) was identified with a trust policy allowing the compromised user to assume it

---

## Phase 3: Privilege Escalation

**MITRE ATT&CK Tactic:** Privilege Escalation (TA0004)
**Technique:** Valid Accounts: Cloud Accounts (T1078.004), Account Manipulation: Additional Cloud Roles (T1098.003)

**Narrative:**
Pacu's `iam__privesc_scan` module identified 14 confirmed privilege escalation vectors available to the compromised user. The module automatically executed the `AttachUserPolicy` method, successfully attaching the AWS managed `AdministratorAccess` policy to the compromised user. This escalated the user from 1,039 permissions to 15,319 permissions, granting full administrative control of the AWS account.

**Pacu Module Executed:**
- `iam__privesc_scan`

**Confirmed Escalation Vectors (14 total):**
1. AddUserToGroup
2. AttachGroupPolicy
3. AttachRolePolicy
4. AttachUserPolicy (successfully exploited)
5. CreateAccessKey
6. CreateEC2WithExistingIP
7. CreateLoginProfile
8. CreateNewPolicyVersion
9. PutGroupPolicy
10. PutRolePolicy
11. PutUserPolicy
12. SetExistingDefaultPolicyVersion
13. UpdateLoginProfile
14. UpdateRolePolicyToAssumeIt

**Result:**
- Before escalation: 1,039 confirmed permissions
- After escalation: 15,319 confirmed permissions
- Method used: AdministratorAccess policy attached to compromised user
- Impact: Full administrative access to the AWS account

---

## Phase 4: Collection and Exfiltration

**MITRE ATT&CK Tactic:** Collection (TA0009) / Exfiltration (TA0010)
**Techniques:**
- Data from Cloud Storage (T1530)
- Exfiltration Over Web Service: Exfiltration to Cloud Storage (T1567.002)

**Narrative:**
The attacker enumerated S3 buckets in the account and discovered four buckets. The target bucket `cloud-security-lab-sensitive-data-bc4b66b4` contained a `confidential/` prefix with a file named `customer-records.csv`. The attacker successfully accessed and read the contents of this file, which contained personally identifiable information (PII) including full names, email addresses, and Social Security numbers.

**S3 Buckets Discovered:**
1. `cloud-security-lab-cloudtrail-880a85d9` (CloudTrail logs)
2. `cloud-security-lab-sensitive-data-bc4b66b4` (sensitive data target)
3. `jordandesigns.io` (unrelated)
4. `tf-backend-jord-projs` (unrelated)

**Exfiltrated Data:**
- Bucket: `cloud-security-lab-sensitive-data-bc4b66b4`
- Path: `confidential/customer-records.csv`
- Size: 141 bytes
- Contents: 3 customer records with id, name, email, and SSN fields

**Evidence (file contents read via AWS CLI):**

```
id,name,email,ssn
1,John Doe,john@example.com,123-45-6789
2,Jane Smith,jane@example.com,987-65-4321
3,Bob Wilson,bob@example.com,555-12-3456
```

**Impact:** Complete exfiltration of sensitive customer PII. In a production environment, this would constitute a data breach requiring regulatory notification under frameworks such as GDPR, CCPA, and HIPAA.

---

## Phase 5: Lateral Movement

**MITRE ATT&CK Tactic:** Lateral Movement (TA0008)
**Technique:** Use Alternate Authentication Material: Application Access Token (T1550.001)

**Narrative:**
The attacker identified the `cloud-security-lab-pivot-role` during the discovery phase. This role's trust policy explicitly allowed the compromised user to assume it via `sts:AssumeRole`. The attacker successfully assumed the pivot role and obtained temporary session credentials, enabling movement to a different identity context within the same account.

**Command Executed:**
```
aws sts assume-role \
  --role-arn arn:aws:iam::692859913278:role/cloud-security-lab-pivot-role \
  --role-session-name pacu-pivot
```

**Result:**
- Assumed Role ARN: `arn:aws:sts::692859913278:assumed-role/cloud-security-lab-pivot-role/pacu-pivot`
- Temporary Access Key: `ASIA2CUNLIQ7PSA6S332`
- Session Expiration: 2026-04-11T11:06:54+00:00
- Impact: Attacker obtained a second identity context with the pivot role's permissions, enabling further actions under a different principal

---

## Kill Chain Summary

| Phase | MITRE Tactic | MITRE Technique | Action | Result |
|-------|-------------|----------------|--------|--------|
| 1. Initial Access | TA0001 Initial Access | T1078.004 Valid Accounts: Cloud | Obtained leaked IAM credentials | Active access key for compromised user |
| 2. Discovery | TA0007 Discovery | T1580, T1087.004, T1069.003 | Enumerated permissions, users, roles | 1,039 permissions, 27 roles, pivot role identified |
| 3. Privilege Escalation | TA0004 Privilege Escalation | T1078.004, T1098.003 | Attached AdministratorAccess policy | Escalated from 1,039 to 15,319 permissions |
| 4. Exfiltration | TA0009 Collection / TA0010 Exfiltration | T1530 | Accessed S3 sensitive data bucket | Exfiltrated customer PII (names, SSNs, emails) |
| 5. Lateral Movement | TA0008 Lateral Movement | T1550.001 | Assumed pivot role via STS | Obtained temporary credentials under new identity |

---

## Detection Opportunities

Each phase of this attack generates artifacts that defensive tooling should detect:

**Phase 1 (Initial Access):**
- CloudTrail: `GetCallerIdentity` API call from unfamiliar IP or user agent
- GuardDuty: `UnauthorizedAccess:IAMUser/InstanceCredentialExfiltration` if keys used outside expected environment

**Phase 2 (Discovery):**
- CloudTrail: High volume of `iam:List*`, `iam:Get*` API calls in short timeframe
- CloudWatch Metrics: Spike in IAM read operations
- GuardDuty: `Recon:IAMUser/UserPermissions` finding

**Phase 3 (Privilege Escalation):**
- CloudTrail: `iam:AttachUserPolicy` with `AdministratorAccess` ARN
- CloudWatch Alarm: `iam_changes` metric filter (deployed in detection module)
- GuardDuty: `PrivilegeEscalation:IAMUser/AdministrativePermissions`
- Remediation Lambda: `disable_iam_keys` function should trigger via EventBridge rule

**Phase 4 (Exfiltration):**
- CloudTrail: `s3:ListBucket`, `s3:GetObject` on sensitive data bucket
- GuardDuty: `Exfiltration:S3/MaliciousIPCaller` or anomalous S3 access patterns
- VPC Flow Logs: Unusual outbound data transfer patterns

**Phase 5 (Lateral Movement):**
- CloudTrail: `sts:AssumeRole` call targeting pivot role
- GuardDuty: `UnauthorizedAccess:IAMUser/InstanceCredentialExfiltration`
- CloudWatch: Cross reference the assuming principal with known attacker indicators

---

## Remediation Actions Taken

The following remediation infrastructure was deployed as part of the lab to automatically respond to detected threats:

1. **EventBridge Rule** (`guardduty_iam`): Monitors GuardDuty findings for IAM related threats
2. **Lambda Function** (`disable_iam_keys`): Automatically disables compromised IAM access keys when triggered
3. **CloudWatch Alarm** (`iam_changes`): Alerts on IAM configuration changes detected via CloudTrail log metric filters
4. **CloudTrail**: Full API logging enabled with log delivery to S3 and CloudWatch Logs
5. **OpenSearch Dashboards**: Kill chain correlation dashboard with 5 visualizations for real time monitoring

---

## Tools and References

| Tool | Purpose |
|------|---------|
| Pacu | AWS exploitation framework for simulating attacker TTPs |
| AWS CLI | Direct API interaction for targeted enumeration and exfiltration |
| ScoutSuite | Multi cloud security auditing (completed in Step 10) |
| MITRE ATT&CK Cloud Matrix | Framework for mapping attacker tactics and techniques |
| OpenSearch | SIEM platform for log aggregation and kill chain visualization |

---

*Document generated as part of the cloud-security-lab case study. All activities were performed in a controlled lab environment against intentionally vulnerable infrastructure.*
